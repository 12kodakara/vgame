<#
.SYNOPSIS
  RSS / API 巡回で見つけた確認待ちの単発実況候補を、人が審査するための CSV(確認シート)に書き出します。
  YouTube API・RSS には接続しません。候補・履歴・登録データは読むだけで変更しません。

.DESCRIPTION
  1) 候補 JSON を読む(既定は rss-state ブランチの discovered-standalone-rss.json を git show で読む。-CandidatesPath でファイルも指定可)
  2) status = pending の候補だけを対象にする(承認・保留・除外など判断済みの候補は載せない)
     -IncludeHeld のときだけ、保留(held)の候補も載せる(判断の案の先頭に「[保留中]」と前回の確認の記録を付ける)
  3) watch-standalone-rss.ps1 が付けた確認分類(reviewCategory)で行を作る
       single          : 1動画1行
       series          : 配信者×作品(seriesKey)ごとに1行(動画本数・URL・動画IDをまとめる)。承認すると multi として登録する想定
       playlist-review : 1動画1行(登録済み再生リストに入っている可能性がある回)
       non-gameplay    : 1動画1行(ショート・切り抜きなど。ゲーム実況でない可能性)。取り込みでは保留・除外だけ(承認できない)
       unclassified    : 1動画1行(分類の無い確認待ち候補。既存作品に一致しなくなったものなど)。取り込みでは保留・除外だけ
     non-gameplay・unclassified の行は、ほかの行の後(シートの末尾)に並べる
  4) 作品のジャンル(genre)は、data-playlists.js / data-standalone.js で同じ作品に付いているものから多いものを下書きする
     同じ配信者×作品の登録済み再生リスト数・単発実況 ID も参考に載せる(重複登録の確認用)
  5) Excel で文字化けしない BOM 付き UTF-8・CRLF の CSV を書き出す
  判断欄(decision)は空欄で出す: approve(承認) / hold(保留) / reject(除外) を人が記入する。
  CSV の取り込み(判断の反映・登録)は別の処理で行う(このスクリプトは書き出しだけ)。

.PARAMETER CandidatesPath
  候補 JSON のファイル。省略時は -StateRef の discovered-standalone-rss.json を git show で読む。
.PARAMETER StateRef
  候補 JSON を読む Git の参照(既定 origin/rss-state。事前に git fetch origin しておく)。
.PARAMETER OutDir
  CSV の書き出し先(既定は OS の一時フォルダの vgame-standalone-review。リポジトリの外なので Git の管理対象にならない)。
.PARAMETER PlaylistsPath
  再生リストの登録データ(省略時はこのスクリプトと同じフォルダの data-playlists.js)。判断の案・優先度は、ここにある再生リストの
  最後の追加日(updatedDate)で決めるため、本番(main)の最新データを指定する。省略したときは参照元と最新の日付を表示し、
  origin/main の data-playlists.js と内容が違う(古い可能性がある)・比べられないときは警告する。
  ファイルが無い・再生リストを1件も読めないときは、確認シートを書き出さずに止める(data-standalone.js も同じ)。
.EXAMPLE
  git fetch origin; .\export-standalone-review.ps1 -PlaylistsPath C:\path\to\main\data-playlists.js
#>
param(
  [string]$CandidatesPath,
  [string]$StateRef = "origin/rss-state",
  [string]$OutDir = (Join-Path ([IO.Path]::GetTempPath()) "vgame-standalone-review"),
  [string]$PlaylistsPath,
  [string]$StandalonePath,
  [switch]$IncludeHeld
)

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$playlistsGiven = [bool]$PlaylistsPath
if (-not $PlaylistsPath) { $PlaylistsPath = Join-Path $scriptDir "data-playlists.js" }
if (-not $StandalonePath) { $StandalonePath = Join-Path $scriptDir "data-standalone.js" }

# JSON は日付を文字列のまま読む(PowerShell 7 の ConvertFrom-Json は日付に見える文字列を日時型に変えるため)
function ConvertFrom-ReviewJson([string]$text) {
  $text = $text.TrimStart([char]0xFEFF)
  if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey("DateKind")) { return , ($text | ConvertFrom-Json -DateKind String) }
  return , ($text | ConvertFrom-Json)
}
# git show の出力を UTF-8 のまま受け取る(コンソールの文字コードに左右されないように)
function Get-GitShowText([string]$spec) {
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = "git"; $psi.Arguments = "-C `"$scriptDir`" show `"$spec`""
  $psi.UseShellExecute = $false; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
  $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
  $p = [Diagnostics.Process]::Start($psi)
  $out = $p.StandardOutput.ReadToEnd(); $err = $p.StandardError.ReadToEnd(); $p.WaitForExit()
  if ($p.ExitCode -ne 0) { throw "git show $spec に失敗しました(git fetch origin を実行しましたか?): $err" }
  return $out
}

if ($CandidatesPath) {
  $sourceLabel = $CandidatesPath
  $data = ConvertFrom-ReviewJson ([IO.File]::ReadAllText($CandidatesPath, [Text.Encoding]::UTF8))
} else {
  $sourceLabel = "${StateRef}:discovered-standalone-rss.json"
  $data = ConvertFrom-ReviewJson (Get-GitShowText $sourceLabel)
}
$all = @($data.candidates)

# ---- 登録データから、作品ごとのジャンルと、配信者×作品の登録状況を集める(1項目1行の書式を前提に読む) ----
$genreByGame = @{}      # 作品 → @{ ジャンル → 件数 }
$playlistCount = @{}    # 配信者|作品 → 登録済み再生リスト数
$standaloneIds = @{}    # 配信者|作品 → 単発実況 ID の一覧
$playlistLatest = @{}   # 配信者|作品 → 再生リストに最後に動画が追加された日(updatedDate の最大。refresh-playlist-meta.ps1 が毎日更新)
$playlistThumbs = @{}   # 配信者|作品 → 再生リストの代表サムネイルの動画ID
foreach ($src in @(@{ path = $PlaylistsPath; kind = "playlist" }, @{ path = $StandalonePath; kind = "standalone" })) {
  if (-not (Test-Path -LiteralPath $src.path -PathType Leaf)) { throw "登録データが見つかりません(確認シートは書き出していません): $($src.path)" }
  $id = ""; $streamer = ""; $game = ""
  foreach ($line in [IO.File]::ReadAllLines($src.path, [Text.Encoding]::UTF8)) {
    if ($line -match '^\s*//') { continue }
    if ($line -match '^\s*\{\s*$') { $id = ""; $streamer = ""; $game = ""; continue }
    if ($line -match '^\s*id:\s*"([^"]*)"') { $id = $Matches[1]; continue }
    if ($line -match '^\s*streamer:\s*"([^"]*)"') { $streamer = $Matches[1]; continue }
    if ($line -match '^\s*game:\s*"([^"]*)"') {
      $game = $Matches[1]; $k = "$streamer|$game"
      if ($src.kind -eq "playlist") { $playlistCount[$k] = 1 + [int]$playlistCount[$k] }
      elseif ($id) { if (-not $standaloneIds.ContainsKey($k)) { $standaloneIds[$k] = New-Object System.Collections.Generic.List[string] }; $standaloneIds[$k].Add($id) }
      continue
    }
    if ($src.kind -eq "playlist" -and $game) {
      $k = "$streamer|$game"
      if ($line -match '^\s*updatedDate:\s*"(\d{4}-\d{2}-\d{2})') { if ([string]::CompareOrdinal($Matches[1], [string]$playlistLatest[$k]) -gt 0) { $playlistLatest[$k] = $Matches[1] }; continue }
      if ($line -match '^\s*thumbnailUrl:\s*"[^"]*/vi/([A-Za-z0-9_-]{11})/') { if (-not $playlistThumbs.ContainsKey($k)) { $playlistThumbs[$k] = @{} }; $playlistThumbs[$k][$Matches[1]] = 1; continue }
    }
    if ($line -match '^\s*genre:\s*"([^"]*)"' -and $game) {
      if (-not $genreByGame.ContainsKey($game)) { $genreByGame[$game] = @{} }
      $genreByGame[$game][$Matches[1]] = 1 + [int]$genreByGame[$game][$Matches[1]]
    }
  }
}
# 再生リストの参照元の確認(古いデータで判断の案を作らないように)
$playlistTotal = ($playlistCount.Values | Measure-Object -Sum).Sum
if (-not $playlistTotal) { throw "再生リストを1件も読めません(確認シートは書き出していません): $PlaylistsPath" }
$latestAll = @($playlistLatest.Values | Sort-Object -Property @{ Expression = { [string]$_ } } | Select-Object -Last 1)
$plNotes = New-Object System.Collections.Generic.List[string]
$plNotes.Add("再生リストの参照元: $PlaylistsPath(再生リスト $playlistTotal 件・最後の追加日の最新 $(if ($latestAll) { $latestAll[0] } else { 'なし' }))")
if (-not $playlistsGiven) {
  $mainText = $null; try { $mainText = Get-GitShowText "origin/main:data-playlists.js" } catch { }
  $localText = [IO.File]::ReadAllText($PlaylistsPath, [Text.Encoding]::UTF8)
  if ($null -eq $mainText) { $plNotes.Add("警告: origin/main(本番)の data-playlists.js と比べられません。本番の再生リストで判定するには -PlaylistsPath で指定してください") }
  elseif (($mainText -replace "`r`n", "`n").TrimStart([char]0xFEFF) -cne ($localText -replace "`r`n", "`n").TrimStart([char]0xFEFF)) { $plNotes.Add("警告: 参照元の data-playlists.js は origin/main(本番)と内容が違います(古い可能性があります)。本番の再生リストで判定するには -PlaylistsPath で指定してください") }
  else { $plNotes.Add("参照元は origin/main(本番)の data-playlists.js と同じ内容です") }
}
function Get-GenreSuggestion([string]$game) {
  if (-not $genreByGame.ContainsKey($game)) { return @{ genre = ""; note = "登録データに同じ作品なし(要記入)" } }
  $sorted = @($genreByGame[$game].GetEnumerator() | Sort-Object @{ Expression = { $_.Value }; Descending = $true }, @{ Expression = { [string]$_.Key } })
  $note = ($sorted | ForEach-Object { "$($_.Key) $($_.Value)" }) -join " / "
  if ($sorted.Count -gt 1 -and $sorted[0].Value -eq $sorted[1].Value) { return @{ genre = ""; note = "候補が同数: $note(要記入)" } }
  return @{ genre = [string]$sorted[0].Key; note = $note }
}

# ---- 確認シートの対象: 確認待ち(pending)だけ。判断済みは載せない ----
# -IncludeHeld のときは保留も対象(続き物は確認待ちと保留を合わせて1行。取り込みは -AllowReconsiderHeld で照合する)
$targetStatuses = @("pending") + $(if ($IncludeHeld) { @("held") } else { @() })
$pending = @($all | Where-Object { [string]$_.status -in $targetStatuses })
$decided = $all.Count - $pending.Count
$confRank = @{ HIGH = 0; MEDIUM = 1; LOW = 2 }
$rows = New-Object System.Collections.Generic.List[object]
# 判断の案と優先度(参考。判断欄には書き込まない。自動で承認・保留・除外はしない)
#   watch-standalone-rss.ps1 が付けた判定結果(likelyNonGame・otherGames・siteHasGamePlaylist・matchType・confidence)だけから決める
#   single          : 案は「要確認」(1本ずつ人が見る)。優先度 A〜E(目印の強いものから順に当てはめる)
#                     E ゲーム実況でない可能性 / C 別の作品名あり / D 同じ作品の再生リストが登録済み(重複の疑い) /
#                     C 概要欄だけで判定・信頼度 LOW(ゲーム名の確認が必要) / A 目印なし・HIGH / B 目印なし・MEDIUM
#   playlist-review と、同じ作品の再生リストが登録済みの series は、再生リストに最後に動画が追加された日(data-playlists.js の
#   updatedDate)と動画の公開日を比べる(API は使わない。再生リストに入っているかは確かめていない):
#     全動画が代表サムネイルの動画と一致、または公開日が最後の追加日以前 → hold 案(一括保留候補)
#     公開日が最後の追加日より後の動画を含む → 「要確認」(個別確認: まだ入っていない・単発の可能性)
#     同じ作品の再生リストが見つからない・日付が無い/不正 → 「要確認」(安全側で個別確認)
#   同じ作品の再生リストが無い series は「要確認」(新しい再生リストの候補。別段階)
#   series / playlist-review でも、ゲーム実況でない可能性・別の作品名がある動画を含めば「要確認」(個別確認)
#   non-gameplay・unclassified: 「要確認」(個別確認)。ショート・切り抜きなどの理由だけで除外の案にはしない
function Get-ReviewSuggestion([string]$type, $items) {
  if ($type -eq "non-gameplay") {
    if (@($items | Where-Object { @($_.reasons) -contains "非ゲーム語: shorts" }).Count -gt 0) { return @{ suggestion = "要確認: ショート(#shorts)と判定。ゲーム実況のショートでないか確認して保留か除外"; priority = "ショート確認" } }
    return @{ suggestion = "要確認: 切り抜き・同時視聴・歌ってみたなどと判定。ゲーム実況でないか確認して保留か除外"; priority = "その他のゲーム実況判定" }
  }
  if ($type -eq "unclassified") { return @{ suggestion = "要確認"; priority = "個別確認(既存作品に一致しなくなった。保留か除外)" } }
  $nonGame = @($items | Where-Object { $_.likelyNonGame -eq $true }).Count -gt 0
  $otherGame = @($items | Where-Object { @($_.otherGames | Where-Object { $_ }).Count -gt 0 }).Count -gt 0   # 項目が無い候補(null)を「あり」と数えない
  $sitePlaylist = @($items | Where-Object { $_.siteHasGamePlaylist -eq $true }).Count -gt 0
  if ($type -eq "single") {
    $c = $items[0]
    if ($nonGame) { $p = "E(ゲーム実況でない可能性)" }
    elseif ($otherGame) { $p = "C(ゲーム名の確認: 別の作品名あり)" }
    elseif ($sitePlaylist) { $p = "D(同じ作品の再生リストが登録済み: 重複の疑い)" }
    elseif ([string]$c.matchType -like "description*" -or [string]$c.confidence -notin @("HIGH", "MEDIUM")) { $p = "C(ゲーム名の確認: 概要欄だけ・信頼度 LOW)" }
    elseif ([string]$c.confidence -eq "HIGH") { $p = "A(目印なし・HIGH)" }
    else { $p = "B(目印なし・MEDIUM)" }
    return @{ suggestion = "要確認"; priority = $p }
  }
  if ($nonGame -or $otherGame) { return @{ suggestion = "要確認: ゲーム実況でない可能性・別の作品名あり"; priority = "個別確認(作品名・目印など)" } }
  if ($type -ne "playlist-review" -and -not $sitePlaylist) { return @{ suggestion = "要確認"; priority = "別段階(新しい再生リストの候補)" } }
  $k = [string]$items[0].streamer + "|" + [string]$items[0].game
  $latest = [string]$playlistLatest[$k]
  if (-not $playlistCount.ContainsKey($k)) { return @{ suggestion = "要確認: 同じ配信者×作品の再生リストが登録データに見つからない"; priority = "個別確認(作品名・目印など)" } }
  if ($latest -notmatch '^\d{4}-\d{2}-\d{2}$') { return @{ suggestion = "要確認: 再生リストの最後の追加日が無く、比べられない"; priority = "個別確認(日付不明)" } }
  $thumbs = $playlistThumbs[$k]; $byThumb = 0; $after = 0
  foreach ($c in $items) {
    $d = [string]$c.publishedDate
    if ($thumbs -and $thumbs.ContainsKey([string]$c.videoId)) { $byThumb++; continue }
    if ($d -notmatch '^\d{4}-\d{2}-\d{2}$') { return @{ suggestion = "要確認: 動画の公開日が無く、比べられない"; priority = "個別確認(日付不明)" } }
    if ([string]::CompareOrdinal($d, $latest) -gt 0) { $after++ }
  }
  if ($after -gt 0) { return @{ suggestion = "要確認: 再生リストの最後の追加日($latest)より後に公開された動画が $after 本。再生リストに未収録・単発の可能性"; priority = "個別確認(追加日より後)" } }
  if ($byThumb -eq $items.Count) { return @{ suggestion = "hold(案): 再生リストの代表サムネイルの動画と一致"; priority = "一括保留候補" } }
  return @{ suggestion = "hold(案): 公開日が再生リストの最後の追加日($latest)以前。再生リストへの収録は未確認"; priority = "一括保留候補" }
}
function New-ReviewRow([string]$type, $items, [string]$seriesKey) {
  $items = @($items | Sort-Object @{ Expression = { [string]$_.publishedAt } }, @{ Expression = { [string]$_.videoId } })
  $first = $items[0]; $k = [string]$first.streamer + "|" + [string]$first.game
  $g = Get-GenreSuggestion ([string]$first.game)
  $confs = @($items | Group-Object { [string]$_.confidence } | Sort-Object { $confRank[$_.Name] } | ForEach-Object { if ($items.Count -eq 1) { $_.Name } else { "$($_.Name) $($_.Count)" } }) -join " / "
  $reasons = @($items | ForEach-Object { @($_.reasons) } | ForEach-Object { [string]$_ } | Where-Object { $_ } | Select-Object -Unique) -join " / "
  $sg = Get-ReviewSuggestion $type $items
  $heldItems = @($items | Where-Object { [string]$_.status -eq "held" })
  if ($heldItems.Count -gt 0) { $sg.suggestion = "[保留中 $($heldItems.Count) 本・前回 $([string]$heldItems[0].reviewedAt) $([string]$heldItems[0].reviewBatch)] " + $sg.suggestion }
  return [pscustomobject][ordered]@{
    rowType = $type
    "decision(approve/hold/reject)" = ""
    game = [string]$first.game
    genre = $g.genre
    genreNote = $g.note
    streamer = [string]$first.streamer
    videoCount = $items.Count
    publishedFrom = [string]$items[0].publishedDate
    publishedTo = [string]$items[-1].publishedDate
    confidence = $confs
    episodeMarker = @($items | Where-Object { $_.episodeMarker -eq $true }).Count
    urls = @($items | ForEach-Object { [string]$_.url }) -join " "
    titles = @($items | ForEach-Object { [string]$_.title }) -join " ｜ "
    reasons = $reasons
    sitePlaylistsSameGame = [int]$playlistCount[$k]
    existingStandaloneIds = $(if ($standaloneIds.ContainsKey($k)) { $standaloneIds[$k] -join " " } else { "" })
    "excludeVideoIds(series のみ)" = ""
    note = ""
    videoIds = @($items | ForEach-Object { [string]$_.videoId }) -join " "
    seriesKey = $seriesKey
    # 末尾の2列は参考(取り込みでは読まない)。案を使うときは、人が確かめてから判断欄に hold などの値だけを書く
    "suggestion(判断の案・参考)" = $sg.suggestion
    "priority(優先度・参考)" = $sg.priority
  }
}
foreach ($c in @($pending | Where-Object { $_.reviewCategory -eq "single" } | Sort-Object @{ Expression = { $confRank[[string]$_.confidence] } }, @{ Expression = { [string]$_.streamer } }, @{ Expression = { [string]$_.publishedAt } })) {
  $rows.Add((New-ReviewRow "single" @($c) ""))
}
foreach ($grp in @($pending | Where-Object { $_.reviewCategory -eq "series" } | Group-Object { [string]$_.seriesKey } | Sort-Object @{ Expression = { $_.Count }; Descending = $true }, @{ Expression = { $_.Name } })) {
  $rows.Add((New-ReviewRow "series" $grp.Group $grp.Name))
}
foreach ($c in @($pending | Where-Object { $_.reviewCategory -eq "playlist-review" } | Sort-Object @{ Expression = { [string]$_.streamer } }, @{ Expression = { [string]$_.game } }, @{ Expression = { [string]$_.publishedAt } })) {
  $rows.Add((New-ReviewRow "playlist-review" @($c) ""))
}
# 末尾: ゲーム実況でない可能性がある候補と、分類の無い候補(既存の行の番号・順序は変えない)
foreach ($c in @($pending | Where-Object { $_.reviewCategory -eq "non-gameplay" } | Sort-Object @{ Expression = { [string]$_.streamer } }, @{ Expression = { [string]$_.game } }, @{ Expression = { [string]$_.publishedAt } })) {
  $rows.Add((New-ReviewRow "non-gameplay" @($c) ""))
}
foreach ($c in @($pending | Where-Object { -not [string]$_.reviewCategory } | Sort-Object @{ Expression = { [string]$_.streamer } }, @{ Expression = { [string]$_.publishedAt } })) {
  $rows.Add((New-ReviewRow "unclassified" @($c) ""))
}

# ---- CSV(BOM 付き UTF-8・CRLF。すべての値を "" で囲む) ----
if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }
$stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
$outPath = Join-Path $OutDir "standalone-review-$stamp.csv"
$q = { param($v) '"' + ([string]$v).Replace('"', '""') + '"' }
$lines = New-Object System.Collections.Generic.List[string]
$headers = @("no") + @($rows[0].PSObject.Properties.Name)
$lines.Add(($headers | ForEach-Object { & $q $_ }) -join ",")
$no = 0
foreach ($r in $rows) { $no++; $lines.Add(((@($no) + @($r.PSObject.Properties | ForEach-Object { $_.Value })) | ForEach-Object { & $q $_ }) -join ",") }
[IO.File]::WriteAllText($outPath, (($lines -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($true)))

$cnt = @{}; foreach ($r in $rows) { $cnt[$r.rowType] = 1 + [int]$cnt[$r.rowType] }
$seriesVideos = (@($rows | Where-Object rowType -eq "series") | Measure-Object videoCount -Sum).Sum
Write-Output "確認シート: $outPath"
foreach ($n in $plNotes) { Write-Output $n }
Write-Output ("読んだ候補: $sourceLabel  全 $($all.Count) 件(対象 $($pending.Count) 件$(if ($IncludeHeld) { "(確認待ち・保留)" } else { "(確認待ち)" })・それ以外の判断済み $decided 件は載せない)")
Write-Output ("行: 合計 $($rows.Count) 行 = 単発 $([int]$cnt['single']) 行 / 続き物 $([int]$cnt['series']) 行(動画 $([int]$seriesVideos) 本) / 再生リスト確認 $([int]$cnt['playlist-review']) 行 / ゲーム実況でない可能性 $([int]$cnt['non-gameplay']) 行 / 分類なし $([int]$cnt['unclassified']) 行")
$priCol = "priority(優先度・参考)"
Write-Output ("優先度(動画の本数): " + ((@($rows | Group-Object { ([string]$_.$priCol) -replace '\(.*$', '' } | Sort-Object Name) | ForEach-Object { "$($_.Name) $(($_.Group | Measure-Object videoCount -Sum).Sum)" }) -join " / "))
