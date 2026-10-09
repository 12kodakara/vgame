<#
.SYNOPSIS
  単発実況(STANDALONE_PLAYS)→ 通常の再生リスト(PLAYLISTS)の「承認付き移行」の判定・状態管理・適用ロジック
  (migrate-standalone.ps1 / test-standalone-migration-approval.ps1 から dot-source して使う)。
  standalone-matching.ps1 と standalone-followups.ps1 を先に dot-source しておくこと。

.DESCRIPTION
  流れ: 候補検出(report-standalone-followups.ps1 のレポート)→ 内容確認 → 人の承認 → 安全性の再検証 → 移行の適用
    - 候補は「単発実況1件 × 移行先の再生リスト1つ」。状態は pending / approved / rejected / applied / error
    - 承認(approve)と適用(apply)は別の操作。適用できるのは approved だけ。承認していない候補は絶対に適用しない
    - 適用前に、承認時の内容(fingerprint)と現在のデータが同じか・移行先の再生リストの中身を YouTube API で確かめ直す
    - 適用は「バックアップ → 一時フォルダで新しいデータを作って検証 → 置き換え → 置き換え後を検証」。
      途中で失敗したら元のファイルに戻す(データが中途半端な状態で残らない)

  移行の種類(type):
    new-playlist      : 同じVTuberのチャンネルにある、サイト未登録のゲーム名入り再生リストへ移行する
                        (PLAYLISTS に1件追加し、STANDALONE_PLAYS から1件削除する)
    existing-playlist : サイト登録済みの同じVTuber × ゲームの再生リストに、単発実況の動画がすでに入っている
                        (重複の整理。STANDALONE_PLAYS から1件削除するだけ。PLAYLISTS は変えない)

  適用できない(要確認にする)もの:
    企画の再生リスト(PLAYLIST_EVENTS・企画名を含む)/ 企画の疑いがある語を含む / 企画に使われるゲーム /
    単発実況の動画が移行先に全部は入っていない / 中身を確認できない / 移行先が複数ある・他の単発実況と候補を共有 /
    同じVTuber × ゲームの再生リストが別にある(new-playlist)/ 移行先の動画が他の単発実況にも登録されている など

  URL・SEO: 単発実況には個別のページ(URL)が無い(singles.html・ゲーム詳細・VTuber詳細の中に表示するだけ)。
  移行後もそのVTuber・ゲームには再生リストが残るため、ゲーム詳細・VTuber詳細の URL・index・sitemap は変わらない。
  新しい再生リストの id は "sa-<単発実況のid>"(URL には使われない内部ID)。既存の id・slug は作り直さない。
#>

$script:MigrationStateVersion = 1
$script:MigrationStatuses = @('pending', 'approved', 'rejected', 'applied', 'error')
# 企画の疑いがある語(登録済みの企画名に加えて調べる)。当てはまる候補は自動で適用せず「要確認」にする(人が判断してデータを直接直す)
$script:MigrationEventKeywords = @('甲子園', '大会', '杯', 'リーグ', '選手権', 'トーナメント', 'コラボ', '企画', '対抗', '交流戦', 'カップ', 'cup', 'フェス', '祭', 'vs', '運動会', 'チーム戦')

# ---------------------------------------------------------------
# データの読み込み(node の vm で data-*.js を実行して取り出す。非ASCIIは \uXXXX にして受け取る)
# ---------------------------------------------------------------
$script:MigrationLoaderJs = @'
const fs = require("fs"), path = require("path"), vm = require("vm");
const root = process.argv[process.argv.length - 1], ctx = {};
vm.createContext(ctx);
for (const f of ["data-core.js", "data-playlists.js", "data-standalone.js"]) vm.runInContext(fs.readFileSync(path.join(root, f), "utf8"), ctx, { filename: f });
const pick = (n) => vm.runInContext("typeof " + n + " === 'undefined' ? [] : " + n, ctx);
const playlists = pick("PLAYLISTS");
const events = pick("GAME_EVENTS").map((e) => ({ id: e.id, name: e.name }));
const evName = {}; events.forEach((e) => { evName[e.id] = e.name; });
const out = {
  streamers: pick("STREAMERS").map((s) => ({ name: s.name, youtube: s.youtube || "" })),
  games: pick("GAMES").map((g) => ({ name: g.name, aliases: [g.name].concat(g.nameJa ? [g.nameJa] : [], g.aliases || []) })),
  playlists: playlists.map((p) => ({ id: p.id, title: p.title, streamer: p.streamer, game: p.game, playlistId: p.playlistId })),
  standalone: pick("STANDALONE_PLAYS").map((p) => ({ id: p.id, title: p.title || "", streamer: p.streamer, game: p.game, genre: p.genre, format: p.format,
    mixedPlaylistUrl: p.mixedPlaylistUrl || "", videos: (p.videos || []).map((v) => ({ url: v.url, title: v.title || "", publishedDate: v.publishedDate || "" })),
    source: JSON.stringify(p) })),
  eventNames: events.map((e) => e.name),
  playlistEvents: pick("PLAYLIST_EVENTS").map((e) => ({ playlist: e.playlist, event: evName[e.event] || e.event, game: e.game })),
};
const esc = (c) => String.fromCharCode(92) + "u" + c.charCodeAt(0).toString(16).padStart(4, "0");
process.stdout.write(JSON.stringify(out).replace(/[^ -~]/g, esc));
'@

function Read-MigrationSiteData([string]$root) {
  $raw = $script:MigrationLoaderJs | & node - $root
  if ($LASTEXITCODE -ne 0 -or -not $raw) { throw "データの読み込みに失敗しました(node が必要です): $root" }
  $d = ($raw -join "") | ConvertFrom-Json
  $site = [pscustomobject]@{
    streamers = @($d.streamers | ForEach-Object { $_ })
    games = @($d.games | ForEach-Object { [pscustomobject]@{ name = $_.name; aliases = @($_.aliases | ForEach-Object { $_ }) } })
    playlists = @($d.playlists | ForEach-Object { $_ })
    standalone = @($d.standalone | ForEach-Object { $_ })
    eventNames = @($d.eventNames | ForEach-Object { $_ })
    playlistEvents = @($d.playlistEvents | ForEach-Object { $_ })
    eventByPlaylistId = @{}   # YouTube の playlistId → 企画名
    eventGames = @{}          # 企画に使われるゲーム名
  }
  foreach ($e in $site.playlistEvents) {
    $p = @($site.playlists | Where-Object { $_.id -eq $e.playlist })[0]
    if ($p) { $site.eventByPlaylistId[[string]$p.playlistId] = [string]$e.event }
    if ($e.game) { $site.eventGames[[string]$e.game] = $true }
  }
  return $site
}

# 単発実況1件の動画ID(重複なし・URLの順)
function Get-MigrationVideoIds($play) {
  return @(@($play.videos) | ForEach-Object { Get-FollowupVideoId $_.url } | Where-Object { $_ } | Select-Object -Unique)
}

# 承認の対象を表す値(単発実況の中身・移行の種類・移行先)。承認後にどれかが変わったら承認は無効
function Get-MigrationFingerprint([string]$standaloneSource, [string]$type, [string]$playlistId) {
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [Text.Encoding]::UTF8.GetBytes($standaloneSource + "`n" + $type + "`n" + $playlistId)
    return (($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join '')
  } finally { $sha.Dispose() }
}

# 企画名・企画の疑いがある語を探す(照合は standalone-matching.ps1 と同じ正規化)。見つかった語を返す
function Find-MigrationEventWords([string[]]$texts, $eventNames) {
  $found = New-Object System.Collections.Generic.List[string]
  foreach ($t in @($texts | Where-Object { $_ })) {
    $n = Test-FollowupEventName $t $eventNames
    if ($n -and -not $found.Contains("企画名「$n」")) { $found.Add("企画名「$n」") }
    $norm = (Get-StandaloneNorm $t) -replace ' ', ''
    foreach ($k in $script:MigrationEventKeywords) {
      $kn = (Get-StandaloneNorm $k) -replace ' ', ''
      if ($kn -and $norm.Contains($kn) -and -not $found.Contains("語「$k」")) { $found.Add("語「$k」") }
    }
  }
  return $found.ToArray()   # 呼び出し側で @() に包む(0件は空配列)
}

# ---------------------------------------------------------------
# 候補の作成(report-standalone-followups.ps1 のレポート JSON から)
# ---------------------------------------------------------------
function New-MigrationCandidates($report, $site) {
  $cands = New-Object System.Collections.Generic.List[object]
  foreach ($r in @($report.results)) {
    $play = @($site.standalone | Where-Object { $_.id -eq $r.id })[0]
    $targets = @()
    # in = $false(既存の動画が入っていない = 別の実況)は移行先にしない。$true / 未確認($null)は候補にして可否を判定する
    foreach ($p in @($r.playlistCandidates)) { if ($p -and $p.videoInPlaylist -ne $false) { $targets += [pscustomobject]@{ type = 'new-playlist'; playlistId = [string]$p.playlistId; title = [string]$p.title; count = $p.count; channelId = [string]$p.channelId; registeredId = $null; videoInPlaylist = $p.videoInPlaylist; event = $p.event } } }
    foreach ($d in @($r.duplicateCandidates)) { if ($d -and $d.sameGame -eq $true -and $d.videoInPlaylist -ne $false) { $targets += [pscustomobject]@{ type = 'existing-playlist'; playlistId = [string]$d.playlistId; title = [string]$d.title; count = $null; channelId = $null; registeredId = [string]$d.id; videoInPlaylist = $d.videoInPlaylist; event = $d.event } } }
    foreach ($t in $targets) {
      $source = $(if ($play) { [string]$play.source } else { '' })
      $cands.Add([pscustomobject]@{
          key = "$($r.id)|$($t.type)|$($t.playlistId)"; standaloneId = [string]$r.id; type = $t.type; playlistId = $t.playlistId
          streamer = [string]$r.streamer; game = [string]$r.game; rank = [string]$r.rank
          standalone = $(if ($play) { [pscustomobject]@{ title = $play.title; format = $play.format; genre = $play.genre; videoIds = @(Get-MigrationVideoIds $play); videoTitles = @($play.videos | ForEach-Object { $_.title }); mixedPlaylistUrl = $play.mixedPlaylistUrl } } else { $null })
          target = [pscustomobject]@{ title = $t.title; count = $t.count; channelId = $t.channelId; registeredId = $t.registeredId; videoInPlaylist = $t.videoInPlaylist; event = $t.event }
          sharedWith = @($r.sharedWith | ForEach-Object { [string]$_.candidate + ' → ' + (@($_.with) -join ',') })
          targetsForSameStandalone = $targets.Count
          fingerprint = $(if ($play) { Get-MigrationFingerprint $source $t.type $t.playlistId } else { '' })
          newPlaylistId = $(if ($t.type -eq 'new-playlist') { 'sa-' + [string]$r.id } else { $null })
        })
    }
  }
  return , $cands.ToArray()
}

# ---------------------------------------------------------------
# 可否の判定。$live = 移行先の現在の状態(Get-MigrationLiveTarget の結果)。$null なら レポート時点の情報で判定する
#   返り値: eligible(適用してよいか)/ blockers(適用できない理由)/ warnings / duplicates(重複の確認結果)
# ---------------------------------------------------------------
function Test-MigrationCandidate($cand, $site, $live = $null) {
  $blockers = New-Object System.Collections.Generic.List[string]
  $warnings = New-Object System.Collections.Generic.List[string]
  $dups = New-Object System.Collections.Generic.List[string]
  $play = @($site.standalone | Where-Object { $_.id -eq $cand.standaloneId })
  if ($play.Count -ne 1) { $blockers.Add("単発実況 $($cand.standaloneId) が現在のデータに$(if ($play.Count) { '複数' } else { '無い(適用済み・削除済みの可能性)' })"); return [pscustomobject]@{ eligible = $false; blockers = $blockers.ToArray(); warnings = $warnings.ToArray(); duplicates = $dups.ToArray() } }
  $play = $play[0]
  $videoIds = @(Get-MigrationVideoIds $play)
  if ($play.streamer -ne $cand.streamer -or $play.game -ne $cand.game) { $blockers.Add("単発実況の VTuber・ゲームが候補と違う(現在: $($play.streamer) × $($play.game))") }
  if (-not $videoIds.Count) { $blockers.Add('単発実況の動画URLから動画IDを取り出せない(移行先に入っているか確認できない)') }
  if ($play.format -eq 'mixed-playlist') { $warnings.Add('format が mixed-playlist(雑多な再生リスト)。移行先が同じ実況の専用再生リストか確認が必要') }
  if ($cand.playlistId -notmatch '^[A-Za-z0-9_-]{10,64}$') { $blockers.Add("移行先の再生リストIDの形式が不正: $($cand.playlistId)") }
  if ($cand.fingerprint -and (Get-MigrationFingerprint $play.source $cand.type $cand.playlistId) -ne $cand.fingerprint) { $blockers.Add('単発実況の内容が候補の作成時から変わっている(候補を作り直して再確認する)') }

  # ---- 重複 ----
  $samePl = @($site.playlists | Where-Object { $_.playlistId -eq $cand.playlistId })
  $sameSG = @($site.playlists | Where-Object { $_.streamer -eq $play.streamer -and $_.game -eq $play.game })
  if ($cand.type -eq 'new-playlist') {
    if ($samePl.Count) { $blockers.Add("移行先の再生リスト $($cand.playlistId) は PLAYLISTS に登録済み($(@($samePl | ForEach-Object { $_.id }) -join ', '))。二重登録しない"); $dups.Add('同一再生リストID: 登録済み') } else { $dups.Add('同一再生リストID: なし') }
    if ($sameSG.Count) { $blockers.Add("同じ $($play.streamer) × $($play.game) の再生リストが登録済み($(@($sameSG | ForEach-Object { $_.id }) -join ', '))。どちらの実況か要確認"); $dups.Add('同一VTuber×ゲーム: 登録済み') } else { $dups.Add('同一VTuber×ゲーム: なし') }
    if (@($site.playlists | Where-Object { $_.id -eq $cand.newPlaylistId }).Count) { $blockers.Add("新しい再生リストの id $($cand.newPlaylistId) が既に使われている") }
  } else {
    $reg = @($samePl | Where-Object { $_.id -eq $cand.target.registeredId })
    if ($reg.Count -ne 1) { $blockers.Add("移行先の登録済み再生リスト $($cand.target.registeredId)($($cand.playlistId))が見つからない") }
    elseif ($reg[0].streamer -ne $play.streamer -or $reg[0].game -ne $play.game) { $blockers.Add("登録済み再生リスト $($reg[0].id) の VTuber・ゲームが単発実況と違う($($reg[0].streamer) × $($reg[0].game))") }
    $dups.Add("同一再生リストID: 登録済み $($cand.target.registeredId)(既存の再生リストに整理する)")
    if ($sameSG.Count -gt 1) { $warnings.Add("同じ VTuber × ゲームの再生リストが $($sameSG.Count) 件ある(既存の関連付けは変えない)") }
  }
  $otherStandalone = @{}
  foreach ($o in @($site.standalone | Where-Object { $_.id -ne $play.id })) { foreach ($v in @(Get-MigrationVideoIds $o)) { $otherStandalone[$v] = $o.id } }
  $dupVideos = @($videoIds | Where-Object { $otherStandalone.ContainsKey($_) })
  if ($dupVideos.Count) { $blockers.Add("単発実況の動画が他の単発実況にも登録されている: $(@($dupVideos | ForEach-Object { $_ + '→' + $otherStandalone[$_] }) -join ', ')") }
  if (@($cand.sharedWith).Count) { $blockers.Add("同じ候補が他の単発実況にも出ている(どちらの実況か要確認): $(@($cand.sharedWith) -join ' / ')") }
  if ([int]$cand.targetsForSameStandalone -gt 1) { $blockers.Add("この単発実況の移行先候補が $($cand.targetsForSameStandalone) つある(どれか1つに決められない)") }

  # ---- 企画 ----
  if ($site.eventByPlaylistId.ContainsKey($cand.playlistId)) { $blockers.Add("移行先は企画の再生リスト($($site.eventByPlaylistId[$cand.playlistId]))。通常の実況には移行しない") }
  if ($cand.target.event) { $blockers.Add("移行先は企画の可能性(レポート: $($cand.target.event))") }
  $liveTitle = $(if ($live -and $live.exists) { $live.title } else { $null })
  $words = @(Find-MigrationEventWords (@($cand.target.title, $liveTitle, $play.title) + @($play.videos | ForEach-Object { $_.title })) $site.eventNames)
  if ($words.Count) { $blockers.Add("企画の疑い(要確認): $($words -join '・') を含む") }
  if ($site.eventGames.ContainsKey($play.game)) { $blockers.Add("「$($play.game)」は企画(PLAYLIST_EVENTS)に使われるゲーム。企画かどうか要確認") }

  # ---- 移行先の中身(現在の状態。無ければレポート時点) ----
  if ($null -eq $live) {
    if ($cand.target.videoInPlaylist -eq $true) { $warnings.Add('移行先に既存の動画が入っていることはレポート時点で確認済み(適用時に API で再確認する)') }
    else { $blockers.Add('移行先に単発実況の動画が入っているか確認できていない(レポートで未確認)') }
  } elseif ($live.error) { $blockers.Add("移行先を確認できない: $($live.error)") }
  elseif (-not $live.exists) { $blockers.Add("移行先の再生リスト $($cand.playlistId) が存在しない(削除・非公開の可能性)") }
  else {
    $missing = @($videoIds | Where-Object { @($live.videoIds) -notcontains $_ })
    if ($missing.Count) { $blockers.Add("単発実況の動画が移行先に入っていない: $($missing -join ', ')(移行すると動画の情報が失われる)") }
    if (-not @($live.videoIds).Count) { $blockers.Add('移行先の再生リストに動画が無い') }
    if ($cand.type -eq 'new-playlist') {
      if ($cand.target.channelId -and $live.channelId -ne $cand.target.channelId) { $blockers.Add("移行先の再生リストの所有チャンネルが違う(候補: $($cand.target.channelId) / 現在: $($live.channelId))") }
      if ($cand.target.title -and $live.title -ne $cand.target.title) { $warnings.Add("再生リスト名が承認時から変わった(「$($cand.target.title)」→「$($live.title)」)") }
    }
    $sharedLive = @(@($live.videoIds) | Where-Object { $otherStandalone.ContainsKey($_) })
    if ($sharedLive.Count) { $blockers.Add("移行先の動画が他の単発実況にも登録されている: $(@($sharedLive | ForEach-Object { $_ + '→' + $otherStandalone[$_] }) -join ', ')") }
  }
  return [pscustomobject]@{ eligible = ($blockers.Count -eq 0); blockers = $blockers.ToArray(); warnings = $warnings.ToArray(); duplicates = $dups.ToArray() }
}

# 移行先の現在の状態を YouTube API で取る(playlists 1ユニット + playlistItems 50件ごとに1ユニット。キャッシュは使わない = 適用直前の最新を見る)
function Get-MigrationLiveTarget($client, [string]$playlistId) {
  try {
    $r = Invoke-FollowupApi $client 'playlists' ("part=snippet,contentDetails&id=" + [uri]::EscapeDataString($playlistId))
    if (-not @($r.items).Count) { return [pscustomobject]@{ exists = $false; error = $null } }
    $it = @($r.items)[0]
    $ids = @((Get-FollowupPlaylistItems $client $playlistId 'contentDetails' 0).items | ForEach-Object { [string]$_.contentDetails.videoId } | Where-Object { $_ })
    return [pscustomobject]@{ exists = $true; error = $null; title = [string]$it.snippet.title; channelId = [string]$it.snippet.channelId; itemCount = $it.contentDetails.itemCount; videoIds = $ids }
  } catch { return [pscustomobject]@{ exists = $false; error = (Protect-FollowupSecret ([string]$_.Exception.Message) $client.secret) } }
}

# ---------------------------------------------------------------
# 状態ファイル(承認の記録)。git 管理外の reports\ に置く。一時ファイルに書いてから置き換える
# ---------------------------------------------------------------
function Read-MigrationState([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) { return [pscustomobject]@{ version = $script:MigrationStateVersion; updatedAt = $null; reportGeneratedAt = $null; candidates = @() } }
  $j = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8) | ConvertFrom-Json
  if ($j.version -ne $script:MigrationStateVersion) { throw "状態ファイルの形式が違う(version $($j.version)): $path" }
  foreach ($c in @($j.candidates)) { if ($script:MigrationStatuses -notcontains $c.status) { throw "状態ファイルに不明な状態がある: $($c.key) = $($c.status)" } }
  return [pscustomobject]@{ version = $j.version; updatedAt = $j.updatedAt; reportGeneratedAt = $j.reportGeneratedAt; candidates = @($j.candidates | ForEach-Object { $_ }) }
}
function Write-MigrationState($state, [string]$path, [datetime]$now) {
  $state.updatedAt = $now.ToString('s')
  $text = [ordered]@{ version = $script:MigrationStateVersion; note = '単発実況 → 再生リストの移行候補と承認状態(migrate-standalone.ps1)。git 管理外'; updatedAt = $state.updatedAt; reportGeneratedAt = $state.reportGeneratedAt; candidates = [object[]]@($state.candidates) } | ConvertTo-Json -Depth 10
  $dir = Split-Path -Parent $path
  if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $tmp = $path + '.tmp'
  [IO.File]::WriteAllText($tmp, $text, (New-Object System.Text.UTF8Encoding($false)))
  Move-Item -LiteralPath $tmp -Destination $path -Force
}
function Add-MigrationHistory($cand, [datetime]$now, [string]$action, [string]$detail) {
  $h = @($cand.history) + @([pscustomobject]@{ at = $now.ToString('s'); action = $action; by = "$env:USERNAME@$env:COMPUTERNAME"; detail = $detail })
  $cand | Add-Member -NotePropertyName history -NotePropertyValue $h -Force
}
function Set-MigrationProp($obj, [string]$name, $value) { $obj | Add-Member -NotePropertyName $name -NotePropertyValue $value -Force }
function Write-MigrationLog([string]$path, [datetime]$now, [string]$action, $data) {
  if (-not $path) { return }
  $dir = Split-Path -Parent $path
  if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $line = ([ordered]@{ at = $now.ToString('s'); action = $action; by = "$env:USERNAME@$env:COMPUTERNAME"; data = $data } | ConvertTo-Json -Depth 8 -Compress)
  [IO.File]::AppendAllText($path, $line + "`n", (New-Object System.Text.UTF8Encoding($false)))
}

# 新しいレポートの候補を状態に取り込む。判断済み(approved / rejected / applied / error)は fingerprint が同じなら残す。
# 内容が変わった候補は pending に戻す(承認を取り消す)。レポートから消えた候補は inLatestReport = false にする(状態は変えない)
function Merge-MigrationCandidates($state, $cands, $site, [datetime]$now, [string]$reportGeneratedAt) {
  $byKey = @{}; foreach ($c in @($state.candidates)) { $byKey[$c.key] = $c }
  $seen = @{}
  $merged = New-Object System.Collections.Generic.List[object]
  foreach ($n in @($cands)) {
    $seen[$n.key] = $true
    $check = Test-MigrationCandidate $n $site $null
    foreach ($p in 'eligible', 'blockers', 'warnings', 'duplicates') { Set-MigrationProp $n $p $check.$p }
    Set-MigrationProp $n 'inLatestReport' $true
    $old = $byKey[$n.key]
    if (-not $old) {
      Set-MigrationProp $n 'status' 'pending'; Set-MigrationProp $n 'history' @(); Add-MigrationHistory $n $now 'detected' "レポート $reportGeneratedAt の候補"
    } elseif ($old.status -eq 'applied') {
      $merged.Add($old); continue   # 適用済みはそのまま(記録として残す)
    } else {
      Set-MigrationProp $n 'history' @($old.history)
      Set-MigrationProp $n 'approvedFingerprint' $old.approvedFingerprint
      if ($old.fingerprint -ne $n.fingerprint) {
        Set-MigrationProp $n 'status' 'pending'; Set-MigrationProp $n 'approvedFingerprint' $null
        Add-MigrationHistory $n $now 'invalidated' "内容が変わったため $($old.status) を取り消して pending に戻した"
      } else { Set-MigrationProp $n 'status' $old.status; if ($old.error) { Set-MigrationProp $n 'error' $old.error } }
    }
    $merged.Add($n)
  }
  foreach ($o in @($state.candidates)) { if (-not $seen.ContainsKey($o.key)) { Set-MigrationProp $o 'inLatestReport' $false; $merged.Add($o) } }
  $state.candidates = $merged.ToArray()
  $state.reportGeneratedAt = $reportGeneratedAt
  return $state
}

# 承認・却下・pending に戻す(状態ファイルだけを変える。データは変えない)
function Set-MigrationDecision($state, [string]$key, [string]$decision, [datetime]$now, [string]$note = '') {
  $cand = @($state.candidates | Where-Object { $_.key -eq $key })
  if ($cand.Count -ne 1) { throw "候補が見つからない: $key" }
  $cand = $cand[0]
  switch ($decision) {
    'approve' {
      if ($cand.status -eq 'applied') { throw "$key は適用済み" }
      if ($cand.status -eq 'approved') { throw "$key は承認済み" }
      if (-not $cand.eligible) { throw "$key は適用できない候補のため承認できない: $(@($cand.blockers) -join ' / ')" }
      if ($cand.inLatestReport -eq $false) { throw "$key は最新のレポートに無い(候補を作り直して確認する)" }
      $other = @($state.candidates | Where-Object { $_.standaloneId -eq $cand.standaloneId -and $_.key -ne $key -and @('approved', 'applied') -contains $_.status })
      if ($other.Count) { throw "同じ単発実況の別の候補が $($other[0].status): $($other[0].key)" }
      Set-MigrationProp $cand 'status' 'approved'; Set-MigrationProp $cand 'approvedFingerprint' $cand.fingerprint
    }
    'reject' {
      if ($cand.status -eq 'applied') { throw "$key は適用済みのため却下できない(元に戻すときはバックアップから復元する)" }
      Set-MigrationProp $cand 'status' 'rejected'; Set-MigrationProp $cand 'approvedFingerprint' $null
    }
    'reset' {
      if ($cand.status -eq 'applied') { throw "$key は適用済み" }
      Set-MigrationProp $cand 'status' 'pending'; Set-MigrationProp $cand 'approvedFingerprint' $null; Set-MigrationProp $cand 'error' $null
    }
    default { throw "不明な操作: $decision" }
  }
  Add-MigrationHistory $cand $now $decision $note
  return $cand
}

# ---------------------------------------------------------------
# データファイルの書き換え(テキストを最小限だけ変える。整形・他の項目は触らない)
# ---------------------------------------------------------------
function ConvertTo-MigrationJsString([string]$s) {
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.Append('"')
  foreach ($ch in $s.ToCharArray()) {
    switch ($ch) {
      '"' { [void]$sb.Append('\"') } '\' { [void]$sb.Append('\\') }
      default { if ([int]$ch -lt 0x20 -or [int]$ch -eq 0x2028 -or [int]$ch -eq 0x2029) { [void]$sb.Append(('\u{0:x4}' -f [int]$ch)) } else { [void]$sb.Append($ch) } }
    }
  }
  [void]$sb.Append('"')
  return $sb.ToString()
}

# $text の $open 位置の括弧({ / [)に対応する閉じ括弧の位置(文字列・コメントは読み飛ばす)
function Find-MigrationClose([string]$text, [int]$open) {
  $depth = 0; $i = $open; $n = $text.Length
  while ($i -lt $n) {
    $c = $text[$i]
    if ($c -eq '"' -or $c -eq "'" -or $c -eq '`') {
      $q = $c; $i++
      while ($i -lt $n -and $text[$i] -ne $q) { if ($text[$i] -eq '\') { $i++ }; $i++ }
    } elseif ($c -eq '/' -and $i + 1 -lt $n -and $text[$i + 1] -eq '/') { while ($i -lt $n -and $text[$i] -ne "`n") { $i++ } }
    elseif ($c -eq '/' -and $i + 1 -lt $n -and $text[$i + 1] -eq '*') { $i += 2; while ($i + 1 -lt $n -and -not ($text[$i] -eq '*' -and $text[$i + 1] -eq '/')) { $i++ }; $i++ }
    elseif ($c -eq '{' -or $c -eq '[') { $depth++ }
    elseif ($c -eq '}' -or $c -eq ']') { $depth--; if ($depth -eq 0) { return $i } }
    $i++
  }
  throw "対応する閉じ括弧が見つからない(位置 $open)"
}

# STANDALONE_PLAYS から id の項目(行単位)を取り除いたテキスト
function Remove-MigrationStandaloneText([string]$text, [string]$id) {
  $arrStart = $text.IndexOf('const STANDALONE_PLAYS = [')
  if ($arrStart -lt 0) { throw 'STANDALONE_PLAYS が見つからない' }
  $arrOpen = $text.IndexOf('[', $arrStart); $arrClose = Find-MigrationClose $text $arrOpen
  $ms = @([regex]::Matches($text, '(?m)^[ \t]*id:[ \t]*"' + [regex]::Escape($id) + '",?[ \t]*\r?$') | Where-Object { $_.Index -gt $arrOpen -and $_.Index -lt $arrClose })
  if ($ms.Count -ne 1) { throw "単発実況 id `"$id`" の行が $($ms.Count) 件(1件のときだけ書き換える)" }
  $objOpen = $text.LastIndexOf('{', $ms[0].Index)
  $lineStart = $text.LastIndexOf("`n", $objOpen) + 1
  if ($text.Substring($lineStart, $objOpen - $lineStart).Trim()) { throw "単発実況 $id の項目の始まりが想定の形({ だけの行)ではない" }
  $objClose = Find-MigrationClose $text $objOpen
  $end = $objClose + 1
  if ($end -lt $text.Length -and $text[$end] -eq ',') { $end++ }
  $eol = $text.IndexOf("`n", $end)
  if ($eol -lt 0) { throw "単発実況 $id の項目の終わりが想定の形ではない" }
  if ($text.Substring($end, $eol - $end).Trim()) { throw "単発実況 $id の項目の後ろに同じ行の続きがある(想定の形ではない)" }
  return $text.Substring(0, $lineStart) + $text.Substring($eol + 1)
}

# PLAYLISTS の末尾に1件追加したテキスト。$entry は ordered hashtable(id, title, ... の順で書く)
function Add-MigrationPlaylistText([string]$text, $entry, [string]$nl) {
  $arrStart = $text.IndexOf('const PLAYLISTS = [')
  if ($arrStart -lt 0) { throw 'PLAYLISTS が見つからない' }
  # data-playlists.js は数MBあり1文字ずつ数えると遅いため、配列の終わりは「行頭の ];」で探す
  # (正しく書き換えられたかは Test-MigrationDataChange が node で全件を比べて確かめる)
  $m = [regex]::new('(?m)^\][ \t]*;').Match($text, $arrStart)
  if (-not $m.Success) { throw 'PLAYLISTS の終わり(行頭の ];)が見つからない' }
  $lineStart = $m.Index
  $lines = @('  {')
  foreach ($k in $entry.Keys) { $v = $entry[$k]; $lines += "    ${k}: " + $(if ($v -is [int]) { [string]$v } else { ConvertTo-MigrationJsString ([string]$v) }) + ',' }
  $lines += '  },'
  $block = ($lines -join $nl) + $nl
  # 直前の項目の後ろにカンマが無ければ足す
  $before = $text.Substring(0, $lineStart).TrimEnd()
  if ($before.EndsWith('}')) { $text = $before + ',' + $nl + $text.Substring($lineStart); $lineStart = $before.Length + 1 + $nl.Length }
  return $text.Substring(0, $lineStart) + $block + $text.Substring($lineStart)
}

# 書き換え前後のデータを比べる(node)。単発実況が1件だけ消え、PLAYLISTS が $added だけ末尾に増えて、他はすべて同じなら ok
$script:MigrationVerifyJs = @'
const fs = require("fs"), path = require("path"), vm = require("vm");
const [beforeDir, afterDir, expFile] = process.argv.slice(-3);
const load = (dir, file, name) => { const ctx = {}; vm.createContext(ctx); vm.runInContext(fs.readFileSync(path.join(dir, file), "utf8"), ctx, { filename: file }); return vm.runInContext(name, ctx); };
const out = { ok: true, errors: [] };
const fail = (m) => { out.ok = false; out.errors.push(m); };
try {
  const exp = JSON.parse(fs.readFileSync(expFile, "utf8"));
  const sa0 = load(beforeDir, "data-standalone.js", "STANDALONE_PLAYS"), sa1 = load(afterDir, "data-standalone.js", "STANDALONE_PLAYS");
  const pl0 = load(beforeDir, "data-playlists.js", "PLAYLISTS"), pl1 = load(afterDir, "data-playlists.js", "PLAYLISTS");
  if (sa0.filter((p) => p.id === exp.removeStandaloneId).length !== 1) fail("before: standalone " + exp.removeStandaloneId + " is not exactly one");
  if (JSON.stringify(sa1) !== JSON.stringify(sa0.filter((p) => p.id !== exp.removeStandaloneId))) fail("STANDALONE_PLAYS: other entries changed or the entry was not removed");
  const want = exp.addPlaylist ? pl0.concat([exp.addPlaylist]) : pl0;
  if (JSON.stringify(pl1) !== JSON.stringify(want)) fail("PLAYLISTS: differs from expected (" + pl0.length + " -> " + pl1.length + ")");
  out.counts = { standalone: [sa0.length, sa1.length], playlists: [pl0.length, pl1.length] };
} catch (e) { fail("exception: " + e.message); }
process.stdout.write(JSON.stringify(out));
'@
function Test-MigrationDataChange([string]$beforeDir, [string]$afterDir, [string]$expFile) {
  $raw = $script:MigrationVerifyJs | & node - $beforeDir $afterDir $expFile
  if (-not $raw) { return [pscustomobject]@{ ok = $false; errors = @('検証の実行に失敗(node)') } }
  return (($raw -join '') | ConvertFrom-Json)
}

function Get-MigrationFileHash([string]$path) { return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
function Read-MigrationText([string]$path) { return [IO.File]::ReadAllText($path, (New-Object System.Text.UTF8Encoding($false))) }
function Write-MigrationText([string]$path, [string]$text) {
  $tmp = $path + '.migrate.tmp'
  [IO.File]::WriteAllText($tmp, $text, (New-Object System.Text.UTF8Encoding($false)))
  Move-Item -LiteralPath $tmp -Destination $path -Force
}

# ---------------------------------------------------------------
# 適用(1件)。$opts: root(データのフォルダ)/ workDir(バックアップ・一時ファイル。reports\ の下)/ now / dryRun / live(移行先の現在の状態)
#   / failAfterFirstWrite(テスト用: 1つ目のファイルを書いた直後に失敗させる)
#   返り値: ok / applied / message / blockers / backupDir / newPlaylist
# ---------------------------------------------------------------
function Invoke-MigrationApply($cand, $site, $opts) {
  $res = [ordered]@{ key = $cand.key; ok = $false; applied = $false; dryRun = [bool]$opts.dryRun; message = ''; blockers = @(); warnings = @(); backupDir = $null; newPlaylist = $null }
  if ($cand.status -ne 'approved') { $res.message = "status が $($cand.status)(approved 以外は適用しない)"; $res.blockers = @($res.message); return [pscustomobject]$res }
  if (-not $cand.approvedFingerprint -or $cand.approvedFingerprint -ne $cand.fingerprint) { $res.message = '承認時の内容と候補の内容が一致しない(再承認が必要)'; $res.blockers = @($res.message); return [pscustomobject]$res }
  if ($null -eq $opts.live) { $res.message = '移行先の現在の状態を確認していない(YouTube API が必要)'; $res.blockers = @($res.message); return [pscustomobject]$res }
  $check = Test-MigrationCandidate $cand $site $opts.live
  $res.warnings = @($check.warnings)
  if (-not $check.eligible) { $res.message = '再検証で適用できない理由が見つかった'; $res.blockers = @($check.blockers); return [pscustomobject]$res }

  $plPath = Join-Path $opts.root 'data-playlists.js'; $saPath = Join-Path $opts.root 'data-standalone.js'
  $plText = Read-MigrationText $plPath; $saText = Read-MigrationText $saPath
  $plHash = Get-MigrationFileHash $plPath; $saHash = Get-MigrationFileHash $saPath
  $nl = $(if ($plText.Contains("`r`n")) { "`r`n" } else { "`n" })
  $play = @($site.standalone | Where-Object { $_.id -eq $cand.standaloneId })[0]
  $entry = $null
  if ($cand.type -eq 'new-playlist') {
    $entry = [ordered]@{ id = $cand.newPlaylistId; title = [string]$opts.live.title; streamer = [string]$play.streamer; game = [string]$play.game; genre = [string]$play.genre
      playlistId = [string]$cand.playlistId; videoCount = [int]@($opts.live.videoIds).Count; addedDate = $opts.now.ToString('yyyy-MM-dd') }
    $res.newPlaylist = [pscustomobject]$entry
  }
  try {
    $newSa = Remove-MigrationStandaloneText $saText $cand.standaloneId
    $newPl = $(if ($entry) { Add-MigrationPlaylistText $plText $entry $nl } else { $plText })
  } catch { $res.message = "書き換えるテキストを作れない: $($_.Exception.Message)"; $res.blockers = @($res.message); return [pscustomobject]$res }

  # 一時フォルダで新しいデータを作り、変更が想定どおり(1件削除・1件追加だけ)か確かめる
  $stamp = $opts.now.ToString('yyyyMMdd-HHmmss') + '-' + $cand.standaloneId
  $staging = Join-Path $opts.workDir ("staging\" + $stamp)
  New-Item -ItemType Directory -Path $staging -Force | Out-Null
  [IO.File]::WriteAllText((Join-Path $staging 'data-playlists.js'), $newPl, (New-Object System.Text.UTF8Encoding($false)))
  [IO.File]::WriteAllText((Join-Path $staging 'data-standalone.js'), $newSa, (New-Object System.Text.UTF8Encoding($false)))
  $expFile = Join-Path $staging 'expected.json'
  [IO.File]::WriteAllText($expFile, ([ordered]@{ removeStandaloneId = $cand.standaloneId; addPlaylist = $entry } | ConvertTo-Json -Depth 5), (New-Object System.Text.UTF8Encoding($false)))
  $v = Test-MigrationDataChange $opts.root $staging $expFile
  if (-not $v.ok) { $res.message = '書き換え後のデータが想定と違うため中止(元のファイルは変えていない)'; $res.blockers = @($v.errors); return [pscustomobject]$res }
  if ($opts.dryRun) { $res.ok = $true; $res.message = "dry-run: 適用できる(単発実況 $($v.counts.standalone[0])→$($v.counts.standalone[1]) 件 / 再生リスト $($v.counts.playlists[0])→$($v.counts.playlists[1]) 件)。データは変更していない"; return [pscustomobject]$res }

  # 本番の書き換え: バックアップ → 置き換え → 検証。失敗したらバックアップから戻す
  $backup = Join-Path $opts.workDir ("backups\" + $stamp)
  New-Item -ItemType Directory -Path $backup -Force | Out-Null
  Copy-Item -LiteralPath $plPath -Destination (Join-Path $backup 'data-playlists.js')
  Copy-Item -LiteralPath $saPath -Destination (Join-Path $backup 'data-standalone.js')
  [IO.File]::WriteAllText((Join-Path $backup 'manifest.json'), ([ordered]@{ key = $cand.key; at = $opts.now.ToString('s'); sha256 = [ordered]@{ 'data-playlists.js' = $plHash; 'data-standalone.js' = $saHash } } | ConvertTo-Json), (New-Object System.Text.UTF8Encoding($false)))
  $res.backupDir = $backup
  if ((Get-MigrationFileHash (Join-Path $backup 'data-playlists.js')) -ne $plHash -or (Get-MigrationFileHash (Join-Path $backup 'data-standalone.js')) -ne $saHash) { $res.message = 'バックアップを正しく作れないため中止(元のファイルは変えていない)'; $res.blockers = @($res.message); return [pscustomobject]$res }
  if ((Get-MigrationFileHash $plPath) -ne $plHash -or (Get-MigrationFileHash $saPath) -ne $saHash) { $res.message = '確認中にデータファイルが変更されたため中止'; $res.blockers = @($res.message); return [pscustomobject]$res }
  try {
    if ($entry) { Write-MigrationText $plPath $newPl }
    if ($opts.failAfterFirstWrite) { throw 'テスト用の失敗(1つ目のファイルを書いた直後)' }
    Write-MigrationText $saPath $newSa
    $v2 = Test-MigrationDataChange $backup $opts.root $expFile
    if (-not $v2.ok) { throw ('置き換え後の検証に失敗: ' + (@($v2.errors) -join ' / ')) }
  } catch {
    $err = $_.Exception.Message
    Copy-Item -LiteralPath (Join-Path $backup 'data-playlists.js') -Destination $plPath -Force
    Copy-Item -LiteralPath (Join-Path $backup 'data-standalone.js') -Destination $saPath -Force
    $restored = ((Get-MigrationFileHash $plPath) -eq $plHash -and (Get-MigrationFileHash $saPath) -eq $saHash)
    $res.message = "適用に失敗したため元に戻した($(if ($restored) { '復元を確認済み' } else { '復元を確認できない。バックアップ ' + $backup + ' から手で戻すこと' })): $err"
    $res.blockers = @($err)
    return [pscustomobject]$res
  }
  $res.ok = $true; $res.applied = $true
  $res.message = "適用した(単発実況 $($cand.standaloneId) を削除$(if ($entry) { '・再生リスト ' + $entry.id + ' を追加' } else { '。登録済みの再生リスト ' + $cand.target.registeredId + ' に整理' }))"
  return [pscustomobject]$res
}
