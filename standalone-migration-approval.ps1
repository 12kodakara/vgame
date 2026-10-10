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
  新しい再生リストの addedDate は単発実況の addedDate を引き継ぐ(新着・「NEW」は addedDate で決まるため、移行した日を新着日にしない)。
  1件以上を正常に適用したときだけ、派生データ(件数バッジ・トップ・新着・ランキング・ジャンル・詳細ページ用)を既存の生成コマンドで作り直す。
#>

$script:MigrationStateVersion = 1
$script:MigrationStatuses = @('pending', 'approved', 'rejected', 'applied', 'error')
# 企画の疑いがある語・共演(本人以外のVTuber名・事務所名)の判定は standalone-followups.ps1 の
# Find-FollowupEventWords / Find-FollowupCollab(レポートと同じ判定)。当てはまる候補は自動で適用せず「要確認」にする

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
  streamers: pick("STREAMERS").map((s) => ({ name: s.name, youtube: s.youtube || "", group: s.group || "" })),
  games: pick("GAMES").map((g) => ({ name: g.name, aliases: [g.name].concat(g.nameJa ? [g.nameJa] : [], g.aliases || []) })),
  playlists: playlists.map((p) => ({ id: p.id, title: p.title, streamer: p.streamer, game: p.game, playlistId: p.playlistId })),
  standalone: pick("STANDALONE_PLAYS").map((p) => ({ id: p.id, title: p.title || "", streamer: p.streamer, game: p.game, genre: p.genre, format: p.format, addedDate: p.addedDate || "",
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
    collabIndex = $null       # 本人以外のVTuber名・事務所名の索引(Find-FollowupCollab)
  }
  $site.collabIndex = New-FollowupCollabIndex $site.streamers
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

# 企画名・企画の疑いがある語を探す(standalone-followups.ps1 の Find-FollowupEventWords と同じ判定)
function Find-MigrationEventWords([string[]]$texts, $eventNames) { return @(Find-FollowupEventWords $texts $eventNames) }

# ---------------------------------------------------------------
# 候補の作成(report-standalone-followups.ps1 のレポート JSON から)
# ---------------------------------------------------------------
function New-MigrationCandidates($report, $site) {
  $cands = New-Object System.Collections.Generic.List[object]
  foreach ($r in @($report.results)) {
    $play = @($site.standalone | Where-Object { $_.id -eq $r.id })[0]
    $targets = @()
    # in = $false(既存の動画が入っていない = 別の実況)は移行先にしない。$true / 未確認($null)は候補にして可否を判定する
    foreach ($p in @($r.playlistCandidates)) { if ($p -and $p.videoInPlaylist -ne $false) { $targets += [pscustomobject]@{ type = 'new-playlist'; playlistId = [string]$p.playlistId; title = [string]$p.title; count = $p.count; channel = [string]$p.channel; channelId = [string]$p.channelId; registeredId = $null; videoInPlaylist = $p.videoInPlaylist; event = $p.event } } }
    foreach ($d in @($r.duplicateCandidates)) { if ($d -and $d.sameGame -eq $true -and $d.videoInPlaylist -ne $false) { $targets += [pscustomobject]@{ type = 'existing-playlist'; playlistId = [string]$d.playlistId; title = [string]$d.title; count = $null; channel = ''; channelId = $null; registeredId = [string]$d.id; videoInPlaylist = $d.videoInPlaylist; event = $d.event } } }
    foreach ($t in $targets) {
      $source = $(if ($play) { [string]$play.source } else { '' })
      $cands.Add([pscustomobject]@{
          key = "$($r.id)|$($t.type)|$($t.playlistId)"; standaloneId = [string]$r.id; type = $t.type; playlistId = $t.playlistId
          streamer = [string]$r.streamer; game = [string]$r.game; rank = [string]$r.rank
          standalone = $(if ($play) { [pscustomobject]@{ title = $play.title; format = $play.format; genre = $play.genre; videoIds = @(Get-MigrationVideoIds $play); videoTitles = @($play.videos | ForEach-Object { $_.title }); mixedPlaylistUrl = $play.mixedPlaylistUrl } } else { $null })
          target = [pscustomobject]@{ title = $t.title; count = $t.count; channel = $t.channel; channelId = $t.channelId; registeredId = $t.registeredId; videoInPlaylist = $t.videoInPlaylist; event = $t.event }
          sharedWith = @($r.sharedWith | ForEach-Object { [string]$_.candidate + ' → ' + (@($_.with) -join ',') })
          reportFlags = @($r.reviewFlags | Where-Object { $_ })   # レポートでの要確認の印(参考表示。可否は Test-MigrationCandidate で判定し直す)
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
  # 同じVTuber × ゲームの単発実況が他にもあると、1件だけ移行しても残りが再生リストと一緒に表示される(validate-data のエラーにもなる)
  $sameSGStandalone = @($site.standalone | Where-Object { $_.id -ne $play.id -and $_.streamer -eq $play.streamer -and $_.game -eq $play.game } | ForEach-Object { $_.id })
  if ($sameSGStandalone.Count) { $blockers.Add("同じ $($play.streamer) × $($play.game) の単発実況が他にもある($($sameSGStandalone -join ', '))。1件だけ移行すると残りが再生リストと重複して表示されるため、まとめて整理する(要確認)") }
  if (@($cand.sharedWith).Count) { $blockers.Add("同じ候補が他の単発実況にも出ている(どちらの実況か要確認): $(@($cand.sharedWith) -join ' / ')") }
  if ([int]$cand.targetsForSameStandalone -gt 1) { $blockers.Add("この単発実況の移行先候補が $($cand.targetsForSameStandalone) つある(どれか1つに決められない)") }

  # ---- 企画 ----
  if ($site.eventByPlaylistId.ContainsKey($cand.playlistId)) { $blockers.Add("移行先は企画の再生リスト($($site.eventByPlaylistId[$cand.playlistId]))。通常の実況には移行しない") }
  if ($cand.target.event) { $blockers.Add("移行先は企画の可能性(レポート: $($cand.target.event))") }
  $liveTitle = $(if ($live -and $live.exists) { $live.title } else { $null })
  $words = @(Find-MigrationEventWords (@($cand.target.title, $liveTitle, $play.title) + @($play.videos | ForEach-Object { $_.title })) $site.eventNames)
  if ($words.Count) { $blockers.Add("企画の疑い(要確認): $($words -join '・') を含む") }
  if ($site.eventGames.ContainsKey($play.game)) { $blockers.Add("「$($play.game)」は企画(PLAYLIST_EVENTS)に使われるゲーム。企画かどうか要確認") }

  # ---- 共演(コラボ)・別VTuber・別チャンネル ----
  $collabIndex = $(if ($site.PSObject.Properties['collabIndex']) { $site.collabIndex } else { $null })
  $collab = @(Find-FollowupCollab (@($play.title) + @($play.videos | ForEach-Object { $_.title })) $collabIndex $play.streamer | ForEach-Object { "単発実況: $_" }) +
    @(Find-FollowupCollab @($cand.target.title, $liveTitle) $collabIndex $play.streamer | ForEach-Object { "移行先「$($cand.target.title)」: $_" })
  if ($collab.Count) { $blockers.Add("共演・他事務所の疑い(要確認。文字列だけで移行を確定しない): $($collab -join ' / ')") }
  if ($cand.type -eq 'new-playlist') {
    if ($cand.target.PSObject.Properties['channel'] -and $cand.target.channel -and $cand.target.channel -ne $play.streamer) { $blockers.Add("移行先は別のVTuber($($cand.target.channel))のチャンネルの再生リスト") }
    $st = @($site.streamers | Where-Object { $_.name -eq $play.streamer })[0]
    $m = [regex]::Match([string]$(if ($st) { $st.youtube } else { '' }), '/channel/(UC[A-Za-z0-9_-]{22})')
    if ($m.Success -and $cand.target.channelId -and $cand.target.channelId -ne $m.Groups[1].Value) { $blockers.Add("移行先の再生リストのチャンネル($($cand.target.channelId))が、$($play.streamer) のチャンネル($($m.Groups[1].Value))と違う") }
    if (-not $cand.target.channelId) { $blockers.Add('移行先の再生リストの所有チャンネルが分からない(要確認)') }
  }

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
  // after: the same streamer x game must not remain in STANDALONE_PLAYS (no double listing), and the playlist must exist exactly once
  if (exp.streamer && sa1.some((p) => p.streamer === exp.streamer && p.game === exp.game)) fail("STANDALONE_PLAYS: the same streamer x game is still listed (would be shown with the playlist)");
  if (exp.addPlaylist && pl1.filter((p) => p.playlistId === exp.addPlaylist.playlistId).length !== 1) fail("PLAYLISTS: the target playlistId is not exactly one");
  if (!exp.addPlaylist && exp.registeredId && pl1.filter((p) => p.id === exp.registeredId && p.streamer === exp.streamer && p.game === exp.game).length !== 1) fail("PLAYLISTS: the registered target playlist is missing");
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

# 新しい再生リストの addedDate(サイトに追加した日)。新着ページの並び順と「NEW」(追加から14日以内)はこの日付で決まる。
# 中身は単発実況としてすでに載っていた実況なので、移行した日ではなく、単発実況の addedDate(最初に載せた日)を引き継ぐ。
# 単発実況に addedDate が無い・形式が違うときだけ移行した日にする。動画が増えたことは updatedDate(update-dates.ps1・日次の自動更新)が表す
function Get-MigrationAddedDate($play, [datetime]$now) {
  $d = $(if ($play -and $play.PSObject.Properties['addedDate']) { [string]$play.addedDate } else { '' })
  $parsed = [datetime]::MinValue
  if ($d -match '^\d{4}-\d{2}-\d{2}$' -and [datetime]::TryParseExact($d, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$parsed) -and $parsed -le $now) { return $d }
  return $now.ToString('yyyy-MM-dd')
}

# ---------------------------------------------------------------
# 派生データの作り直し(移行を適用した後だけ呼ぶ)。既存の生成コマンドをそのまま使う:
#   generate-counts.ps1(件数バッジ data-counts.js)/ generate-home-data.js(トップ data-home.js)/ generate-detail-data.js(data\)/
#   generate-list-data.js(新着 data-new.js・ランキング data-ranking.js)/ generate-genre-data.js(data-genres.js)
#   作り直した後に node の各 --check で最新かを確かめる。どれも「内容が同じなら書き換えない」ので、再実行しても変わらない
#   返り値: ok / steps(name・ok・output)/ changed(内容が変わったファイル)
# ---------------------------------------------------------------
$script:MigrationDerivedFiles = @('data-counts.js', 'data-home.js', 'data-new.js', 'data-ranking.js', 'data-genres.js')
function Get-MigrationDerivedHashes([string]$root) {
  $h = @{}
  foreach ($f in $script:MigrationDerivedFiles) { $p = Join-Path $root $f; if (Test-Path -LiteralPath $p) { $h[$f] = Get-MigrationFileHash $p } }
  $dataDir = Join-Path $root 'data'
  if (Test-Path -LiteralPath $dataDir) { foreach ($x in Get-ChildItem -LiteralPath $dataDir -Recurse -File) { $h['data\' + $x.FullName.Substring($dataDir.Length + 1)] = Get-MigrationFileHash $x.FullName } }
  return $h
}
function Invoke-MigrationDerivedUpdate([string]$root) {
  $steps = New-Object System.Collections.Generic.List[object]
  $before = Get-MigrationDerivedHashes $root
  $run = {
    param($name, [scriptblock]$cmd)
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try { $out = (& $cmd 2>&1 | Out-String).Trim(); $code = $LASTEXITCODE } catch { $out = $_.Exception.Message; $code = 1 } finally { $ErrorActionPreference = $prev }
    $steps.Add([pscustomobject]@{ name = $name; ok = ($code -eq 0); output = $out })
  }
  & $run 'generate-counts.ps1' { & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'generate-counts.ps1') }
  foreach ($g in 'generate-home-data.js', 'generate-detail-data.js', 'generate-list-data.js', 'generate-genre-data.js') { & $run $g ([scriptblock]::Create("& node '$((Join-Path $root $g).Replace("'", "''"))'")) }
  foreach ($g in 'generate-home-data.js', 'generate-detail-data.js', 'generate-list-data.js', 'generate-genre-data.js') { & $run "$g --check" ([scriptblock]::Create("& node '$((Join-Path $root $g).Replace("'", "''"))' --check")) }
  $after = Get-MigrationDerivedHashes $root
  $changed = @(@($before.Keys) + @($after.Keys) | Select-Object -Unique | Where-Object { $before[$_] -ne $after[$_] } | Sort-Object)
  return [pscustomobject]@{ ok = (@($steps | Where-Object { -not $_.ok }).Count -eq 0); steps = $steps.ToArray(); changed = $changed }
}

# ---------------------------------------------------------------
# 書き換え後のデータを一時フォルダ($staging)に作り、node で「単発実況1件削除・再生リスト1件追加(new-playlist のとき)だけ」か確かめる。
# 元のデータファイルは変えない。$title / $videoCount は新しい再生リストに書く値(適用時は API で取り直した値)
#   返り値: ok / message / errors / plPath / saPath / plHash / saHash / newPl / newSa / entry / expFile / verify
# ---------------------------------------------------------------
function New-MigrationStagedChange($cand, $site, [string]$root, [string]$staging, [string]$title, [int]$videoCount, [datetime]$now) {
  $r = [ordered]@{ ok = $false; message = ''; errors = @(); plPath = (Join-Path $root 'data-playlists.js'); saPath = (Join-Path $root 'data-standalone.js'); plHash = $null; saHash = $null; newPl = $null; newSa = $null; entry = $null; expFile = $null; verify = $null }
  foreach ($f in $r.plPath, $r.saPath) { if (-not (Test-Path -LiteralPath $f)) { $r.message = "データファイルが無い: $f"; $r.errors = @($r.message); return [pscustomobject]$r } }
  $plText = Read-MigrationText $r.plPath; $saText = Read-MigrationText $r.saPath
  $r.plHash = Get-MigrationFileHash $r.plPath; $r.saHash = Get-MigrationFileHash $r.saPath
  $nl = $(if ($plText.Contains("`r`n")) { "`r`n" } else { "`n" })
  $play = @($site.standalone | Where-Object { $_.id -eq $cand.standaloneId })[0]
  if (-not $play) { $r.message = "単発実況 $($cand.standaloneId) が現在のデータに無い"; $r.errors = @($r.message); return [pscustomobject]$r }
  if ($cand.type -eq 'new-playlist') {
    $r.entry = [ordered]@{ id = $cand.newPlaylistId; title = $title; streamer = [string]$play.streamer; game = [string]$play.game; genre = [string]$play.genre
      playlistId = [string]$cand.playlistId; videoCount = $videoCount; addedDate = (Get-MigrationAddedDate $play $now) }
  }
  try {
    $r.newSa = Remove-MigrationStandaloneText $saText $cand.standaloneId
    $r.newPl = $(if ($r.entry) { Add-MigrationPlaylistText $plText $r.entry $nl } else { $plText })
  } catch { $r.message = "書き換えるテキストを作れない: $($_.Exception.Message)"; $r.errors = @($r.message); return [pscustomobject]$r }
  New-Item -ItemType Directory -Path $staging -Force | Out-Null
  [IO.File]::WriteAllText((Join-Path $staging 'data-playlists.js'), $r.newPl, (New-Object System.Text.UTF8Encoding($false)))
  [IO.File]::WriteAllText((Join-Path $staging 'data-standalone.js'), $r.newSa, (New-Object System.Text.UTF8Encoding($false)))
  $r.expFile = Join-Path $staging 'expected.json'
  [IO.File]::WriteAllText($r.expFile, ([ordered]@{ removeStandaloneId = $cand.standaloneId; addPlaylist = $r.entry; streamer = [string]$play.streamer; game = [string]$play.game
        registeredId = $(if ($cand.type -eq 'existing-playlist') { [string]$cand.target.registeredId } else { $null }) } | ConvertTo-Json -Depth 5), (New-Object System.Text.UTF8Encoding($false)))
  $r.verify = Test-MigrationDataChange $root $staging $r.expFile
  if (-not $r.verify.ok) { $r.message = '書き換え後のデータが想定と違うため中止(元のファイルは変えていない)'; $r.errors = @($r.verify.errors); return [pscustomobject]$r }
  $r.ok = $true
  return [pscustomobject]$r
}

# ---------------------------------------------------------------
# 適用前の確認(-Action check)。API を使わず、状態ファイル・データを変えない。一時ファイルは $tempRoot の下に作り、終わったら片付ける
#   確認すること: 状態(approved か)・承認時の内容との一致・データとの整合(Test-MigrationCandidate。移行先の中身はレポート時点)・
#   書き換えのシミュレーション(node で全件比較)・実行すると変わるファイル
#   返り値: ok / status / problems / warnings / changes(変わるファイルと内容)
# ---------------------------------------------------------------
function Test-MigrationPlan($cand, $site, [string]$root, [string]$tempRoot, [datetime]$now) {
  $problems = New-Object System.Collections.Generic.List[string]
  $warnings = New-Object System.Collections.Generic.List[string]
  $changes = New-Object System.Collections.Generic.List[string]
  if ($cand.status -ne 'approved') { $problems.Add("status が $($cand.status)(適用の対象は approved だけ)") }
  elseif (-not $cand.approvedFingerprint -or $cand.approvedFingerprint -ne $cand.fingerprint) { $problems.Add('承認時の内容と候補の内容が一致しない(再承認が必要)') }
  $chk = Test-MigrationCandidate $cand $site $null
  foreach ($b in @($chk.blockers)) { $problems.Add($b) }
  foreach ($w in @($chk.warnings)) { $warnings.Add($w) }
  $title = [string]$cand.target.title
  $count = $(if ($null -ne $cand.target.count) { [int]$cand.target.count } else { @($cand.standalone.videoIds).Count })
  $staging = Join-Path $tempRoot ('check-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
  try {
    $chg = New-MigrationStagedChange $cand $site $root $staging $title $count $now
    if (-not $chg.ok) { foreach ($e in @($chg.errors)) { $problems.Add("書き換えのシミュレーション: $e") } }
    else {
      if ($chg.entry) { $changes.Add("data-playlists.js: 末尾に1件追加 id=$($chg.entry.id) playlistId=$($cand.playlistId)「$title」(名前・動画数は仮。適用時は API で取り直した値)") }
      else { $changes.Add("data-playlists.js: 変更なし(登録済みの $($cand.target.registeredId) に整理)") }
      $changes.Add("data-standalone.js: 1件削除 id=$($cand.standaloneId)(単発実況 $($chg.verify.counts.standalone[0])→$($chg.verify.counts.standalone[1]) 件 / 再生リスト $($chg.verify.counts.playlists[0])→$($chg.verify.counts.playlists[1]) 件)")
    }
  } finally { if ($staging -and (Test-Path -LiteralPath $staging)) { Get-ChildItem -LiteralPath $staging -File | ForEach-Object { $_.Delete() }; [IO.Directory]::Delete($staging) } }
  return [pscustomobject]@{ key = $cand.key; ok = ($problems.Count -eq 0); status = $cand.status; problems = $problems.ToArray(); warnings = $warnings.ToArray(); changes = $changes.ToArray() }
}

# ---------------------------------------------------------------
# 適用(1件)。$opts: root(データのフォルダ)/ workDir(バックアップ・一時ファイル。reports\ の下)/ now / dryRun / live(移行先の現在の状態)
#   / failAfterFirstWrite(テスト用: 1つ目のファイルを書いた直後に失敗させる)
#   返り値: ok / applied / message / blockers / backupDir / newPlaylist / record(適用したときの移行前後の記録)
# ---------------------------------------------------------------
function Invoke-MigrationApply($cand, $site, $opts) {
  $res = [ordered]@{ key = $cand.key; ok = $false; applied = $false; dryRun = [bool]$opts.dryRun; message = ''; blockers = @(); warnings = @(); backupDir = $null; newPlaylist = $null; record = $null }
  if ($cand.status -ne 'approved') { $res.message = "status が $($cand.status)(approved 以外は適用しない)"; $res.blockers = @($res.message); return [pscustomobject]$res }
  if (-not $cand.approvedFingerprint -or $cand.approvedFingerprint -ne $cand.fingerprint) { $res.message = '承認時の内容と候補の内容が一致しない(再承認が必要)'; $res.blockers = @($res.message); return [pscustomobject]$res }
  if ($null -eq $opts.live) { $res.message = '移行先の現在の状態を確認していない(YouTube API が必要)'; $res.blockers = @($res.message); return [pscustomobject]$res }
  $check = Test-MigrationCandidate $cand $site $opts.live
  $res.warnings = @($check.warnings)
  if (-not $check.eligible) { $res.message = '再検証で適用できない理由が見つかった'; $res.blockers = @($check.blockers); return [pscustomobject]$res }

  # 一時フォルダで新しいデータを作り、変更が想定どおり(1件削除・1件追加だけ)か確かめる
  $stamp = $opts.now.ToString('yyyyMMdd-HHmmss') + '-' + $cand.standaloneId
  $chg = New-MigrationStagedChange $cand $site $opts.root (Join-Path $opts.workDir ("staging\" + $stamp)) ([string]$opts.live.title) ([int]@($opts.live.videoIds).Count) $opts.now
  if ($chg.entry) { $res.newPlaylist = [pscustomobject]$chg.entry }
  if (-not $chg.ok) { $res.message = $chg.message; $res.blockers = @($chg.errors); return [pscustomobject]$res }
  $plPath = $chg.plPath; $saPath = $chg.saPath; $plHash = $chg.plHash; $saHash = $chg.saHash
  $newPl = $chg.newPl; $newSa = $chg.newSa; $entry = $chg.entry; $expFile = $chg.expFile; $v = $chg.verify
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
  # 移行の記録(移行前の単発実況の内容・移行先・件数・ファイルのハッシュ)。状態ファイルとログに残し、移行前後を追えるようにする
  $play = @($site.standalone | Where-Object { $_.id -eq $cand.standaloneId })[0]
  $res.record = [pscustomobject]([ordered]@{
      key = $cand.key; type = $cand.type; appliedAt = $opts.now.ToString('s')
      before = [pscustomobject]@{ standalone = $(if ($play) { $play.source | ConvertFrom-Json } else { $null }) }
      after = [pscustomobject]@{ playlistId = $cand.playlistId; addedPlaylist = $(if ($entry) { [pscustomobject]$entry } else { $null }); registeredPlaylist = $(if ($entry) { $null } else { $cand.target.registeredId })
        addedDateFrom = $(if (-not $entry) { $null } elseif ($play -and $entry.addedDate -eq [string]$play.addedDate) { 'standalone' } else { 'migration' }) }
      counts = [pscustomobject]@{ standalone = @($v2.counts.standalone); playlists = @($v2.counts.playlists) }
      sha256 = [pscustomobject]@{ before = [pscustomobject]@{ playlists = $plHash; standalone = $saHash }; after = [pscustomobject]@{ playlists = (Get-MigrationFileHash $plPath); standalone = (Get-MigrationFileHash $saPath) } }
      backupDir = $backup })
  return [pscustomobject]$res
}

# ---------------------------------------------------------------
# 承認済みの候補の適用(dry-run を含む)を1件ずつ行う(migrate-standalone.ps1 -Action apply の中身)。
#   $opts: root / workDir / now / apply(true のときだけ書き換える。false は dry-run)/ getLive(移行先の現在の状態を返す
#          スクリプトブロック。$null なら移行先を確認しない = 適用しない)/ stateFile / logFile / failAfterFirstWrite(テスト用)
#   - 1件ごとにデータを読み直して再検証する。適用できなかった候補が出たら error にしてそこで止める
#   - この実行で1件以上を正常に適用したときだけ、派生データを作り直す(dry-run・未承認・失敗だけなら作り直さない)
#   返り値: lines(表示する行)/ results / appliedNow(この実行で適用した件数)/ derived(Invoke-MigrationDerivedUpdate の結果。作り直していなければ $null)
# ---------------------------------------------------------------
function Invoke-MigrationApplyRun($state, $targets, $opts) {
  $lines = New-Object System.Collections.Generic.List[string]
  $results = New-Object System.Collections.Generic.List[object]
  $appliedNow = 0
  foreach ($c in @($targets)) {
    $site = Read-MigrationSiteData $opts.root   # 1件ごとに読み直す(前の適用の結果を反映する)
    $live = $(if ($opts.getLive) { & $opts.getLive $c.playlistId } else { $null })
    if (-not $live) {
      $chk = Test-MigrationCandidate $c $site $null
      $lines.Add("- $($c.key): API なしのため移行先は再確認していない。データだけの確認: $(if ($chk.eligible) { '問題なし' } else { @($chk.blockers) -join ' / ' })")
      Write-MigrationLog $opts.logFile $opts.now 'apply-check-offline' ([ordered]@{ key = $c.key; eligible = $chk.eligible; blockers = @($chk.blockers) })
      continue
    }
    $res = Invoke-MigrationApply $c $site @{ root = $opts.root; workDir = $opts.workDir; now = $opts.now; dryRun = (-not $opts.apply); live = $live; failAfterFirstWrite = $opts.failAfterFirstWrite }
    $results.Add($res)
    $lines.Add("- $($c.key): $($res.message)")
    foreach ($b in @($res.blockers)) { $lines.Add("    理由: $b") }
    foreach ($w in @($res.warnings)) { $lines.Add("    注意: $w") }
    Write-MigrationLog $opts.logFile $opts.now $(if ($opts.apply) { 'apply' } else { 'apply-dry-run' }) ([ordered]@{ key = $c.key; ok = $res.ok; applied = $res.applied; message = $res.message; blockers = @($res.blockers); backupDir = $res.backupDir; newPlaylist = $res.newPlaylist; record = $res.record })
    if ($opts.apply) {
      if ($res.applied) {
        $appliedNow++
        Set-MigrationProp $c 'status' 'applied'; Set-MigrationProp $c 'appliedAt' $opts.now.ToString('s'); Set-MigrationProp $c 'backupDir' $res.backupDir; Set-MigrationProp $c 'error' $null
        Set-MigrationProp $c 'appliedRecord' $res.record   # 移行前の単発実況の内容と移行先(移行前後を追うため)
        Add-MigrationHistory $c $opts.now 'applied' $res.message
        if ($opts.stateFile) { Write-MigrationState $state $opts.stateFile $opts.now }
      } else {
        Set-MigrationProp $c 'status' 'error'; Set-MigrationProp $c 'error' ($res.message + ': ' + (@($res.blockers) -join ' / '))
        Add-MigrationHistory $c $opts.now 'error' $c.error
        if ($opts.stateFile) { Write-MigrationState $state $opts.stateFile $opts.now }
        $lines.Add('適用できない候補があったため、ここで止めました(以降の候補は処理していません)')
        break
      }
    }
  }
  $derived = $null
  if ($opts.apply -and $appliedNow -gt 0) {
    $lines.Add('派生データを作り直しました(generate-counts.ps1 / generate-home-data.js / generate-detail-data.js / generate-list-data.js / generate-genre-data.js と各 --check):')
    $derived = Invoke-MigrationDerivedUpdate $opts.root
    foreach ($st in $derived.steps) { $lines.Add("  [$(if ($st.ok) { 'OK' } else { 'NG' })] $($st.name)$(if (-not $st.ok) { ': ' + $st.output })") }
    $lines.Add("  内容が変わった派生データ: $(if (@($derived.changed).Count) { @($derived.changed) -join ', ' } else { 'なし' })")
    Write-MigrationLog $opts.logFile $opts.now 'regenerate-derived' ([ordered]@{ ok = $derived.ok; changed = @($derived.changed); failed = @($derived.steps | Where-Object { -not $_.ok } | ForEach-Object { $_.name }) })
  }
  return [pscustomobject]@{ lines = $lines.ToArray(); results = $results.ToArray(); appliedNow = $appliedNow; derived = $derived }
}
