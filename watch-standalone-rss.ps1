<#
.SYNOPSIS
  登録済みVTuberの YouTube チャンネル RSS(新着15本)から、未登録の単発実況候補を抽出します。
  YouTube Data API は使いません。第1段階では、保存済みの RSS XML ファイルを読むだけです(RSS の取得は行わない)。

.DESCRIPTION
  1) data-core.js の STREAMERS / GAMES、data-playlists.js の PLAYLISTS、data-standalone.js を読み取る
  2) -FeedDir の *.xml(YouTube チャンネル RSS)から 動画ID・タイトル・説明欄・公開日時・チャンネルID を取り出す
     チャンネルID → VTuber は STREAMERS の youtube(/channel/UC…)と、-ChannelMapPath(任意)で対応付ける
  3) STANDALONE_PLAYS 登録済みの動画、出力ファイルに検出済みの動画は除外する(動画IDで判定)
     サイト登録済み再生リストの中身は API を呼ばないと分からないため照合しない。
     候補には playlistVideoCheck = "unverified" を付け、同じVTuber×ゲームの再生リストが登録済みなら印を付ける
  4) standalone-matching.ps1 の Get-StandaloneMatch でゲームと信頼度(HIGH / MEDIUM / LOW)を判定する
     ゲームが特定できない動画は候補にしない。候補はすべて status = "pending"(登録データへの反映は人が承認してから)
  5) 候補を -OutFile(既定 discovered-standalone-rss.json。Git 管理外)に追記する。
     同じ RSS を何度処理しても、同じ動画IDの候補は増えない(lastSeenAt だけ更新)

  ■ 失敗時の扱い
    RSS が XML として読めない・チャンネルIDが無い・未登録チャンネル → lastRun.errors に記録して、そのファイルだけ飛ばす
    RSS に動画が1件も無い → lastRun.warnings に記録
    既存の出力ファイルが壊れている(JSONとして読めない) → 上書きせずに中止する(既存候補を失わないため)
    出力は一時ファイルに書いてから置き換える(書き込み途中で止まっても既存の候補は残る)

  data-core.js / data-playlists.js / data-standalone.js は読み取りのみで、変更しません。

.PARAMETER FeedDir
  RSS XML(*.xml)を置いたフォルダ。
.PARAMETER OutFile
  候補の保存先(既定 discovered-standalone-rss.json)。相対パスはスクリプトのフォルダから。
.PARAMETER ChannelMapPath
  任意。チャンネルID → VTuber 名の対応表(JSON 配列。各要素に streamer と channelId)。
  discovered-playlists-*.json をそのまま指定できる。STREAMERS が @ハンドルだけのVTuberを対応付けるために使う。
.EXAMPLE
  .\watch-standalone-rss.ps1 -FeedDir .\rss-feeds -ChannelMapPath .\discovered-playlists-20261011.json
#>
param(
  [Parameter(Mandatory = $true)][string]$FeedDir,
  [string]$OutFile = "discovered-standalone-rss.json",
  [string]$ChannelMapPath,
  [string]$CorePath,
  [string]$PlaylistsPath,
  [string]$StandalonePath
)

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
if (-not $CorePath) { $CorePath = Join-Path $scriptDir "data-core.js" }
if (-not $PlaylistsPath) { $PlaylistsPath = Join-Path $scriptDir "data-playlists.js" }
if (-not $StandalonePath) { $StandalonePath = Join-Path $scriptDir "data-standalone.js" }
$outPath = if ([IO.Path]::IsPathRooted($OutFile)) { $OutFile } else { Join-Path $scriptDir $OutFile }
if (-not (Test-Path $FeedDir -PathType Container)) { throw "RSS のフォルダが見つかりません: $FeedDir" }

. (Join-Path $scriptDir "standalone-matching.ps1")

# ---- 元データの読み取り(discover-standalone.ps1 と同じ書式を前提に、1件1行の項目を拾う) ----
$full = ([IO.File]::ReadAllText($CorePath, [Text.Encoding]::UTF8)) + "`n" + ([IO.File]::ReadAllText($PlaylistsPath, [Text.Encoding]::UTF8))
function Get-ArrayBlock([string]$name) {
  $start = $full.IndexOf("const $name = [")
  if ($start -lt 0) { throw "$name 配列が見つかりません。" }
  $end = $full.IndexOf("`n];", $start)
  if ($end -lt 0) { throw "$name 配列の終端が見つかりません。" }
  return $full.Substring($start, $end - $start)
}
function Get-JsObjects([string]$block) {
  # { … } を1件として切り出す(文字列中の括弧は数えない)
  $results = New-Object System.Collections.Generic.List[string]
  $depth = 0; $start = -1; $inString = $false; $escape = $false
  for ($i = 0; $i -lt $block.Length; $i++) {
    $ch = $block[$i]
    if ($inString) {
      if ($escape) { $escape = $false; continue }
      if ($ch -eq '\') { $escape = $true; continue }
      if ($ch -eq '"') { $inString = $false }
      continue
    }
    if ($ch -eq '"') { $inString = $true; continue }
    if ($ch -eq '{') { if ($depth -eq 0) { $start = $i }; $depth++ }
    elseif ($ch -eq '}') { $depth--; if ($depth -eq 0 -and $start -ge 0) { $results.Add($block.Substring($start, $i - $start + 1)); $start = -1 } }
  }
  return $results
}
function Get-JsField([string]$obj, [string]$name) {
  $m = [regex]::Match($obj, '(?<![A-Za-z])' + [regex]::Escape($name) + '\s*:\s*"((?:\\.|[^"])*)"')
  if ($m.Success) { return ($m.Groups[1].Value -replace '\\"', '"' -replace '\\\\', '\') }
  return ""
}
function Get-JsArrayField([string]$obj, [string]$name) {
  $m = [regex]::Match($obj, '(?<![A-Za-z])' + [regex]::Escape($name) + '\s*:\s*\[([^\]]*)\]')
  if (-not $m.Success) { return @() }
  return @([regex]::Matches($m.Groups[1].Value, '"((?:\\.|[^"])*)"') | ForEach-Object { $_.Groups[1].Value })
}

$streamers = @(foreach ($obj in Get-JsObjects (Get-ArrayBlock "STREAMERS")) {
  $name = Get-JsField $obj "name"; if (-not $name) { continue }
  [pscustomobject]@{ name = $name; youtube = (Get-JsField $obj "youtube") }
})
$games = @(foreach ($obj in Get-JsObjects (Get-ArrayBlock "GAMES")) {
  $name = Get-JsField $obj "name"; if (-not $name) { continue }
  $aliases = @($name, (Get-JsField $obj "nameJa"), (Get-JsArrayField $obj "aliases")) | ForEach-Object { $_ } | Where-Object { $_ }
  [pscustomobject]@{ name = $name; aliases = @($aliases | Select-Object -Unique) }
})
$registered = @(foreach ($obj in Get-JsObjects (Get-ArrayBlock "PLAYLISTS")) {
  [pscustomobject]@{ streamer = (Get-JsField $obj "streamer"); game = (Get-JsField $obj "game") }
})
$gameIndex = New-StandaloneGameIndex $games @($streamers | ForEach-Object { $_.name })
$standaloneVideoIds = Get-StandaloneRegisteredVideoIds $(if (Test-Path $StandalonePath) { [IO.File]::ReadAllText($StandalonePath, [Text.Encoding]::UTF8) } else { "" })
$siteGamePairs = New-Object System.Collections.Generic.HashSet[string]
foreach ($p in $registered) { [void]$siteGamePairs.Add($p.streamer + "`t" + $p.game) }

# ---- チャンネルID → VTuber ----
$channelToStreamer = @{}
foreach ($s in $streamers) {
  if ($s.youtube -match '/channel/(UC[A-Za-z0-9_-]{22})') { $channelToStreamer[$Matches[1]] = $s.name }
}
if ($ChannelMapPath) {
  $knownNames = New-Object System.Collections.Generic.HashSet[string]
  foreach ($s in $streamers) { [void]$knownNames.Add($s.name) }
  $map = ([IO.File]::ReadAllText($ChannelMapPath, [Text.Encoding]::UTF8)).TrimStart([char]0xFEFF) | ConvertFrom-Json
  foreach ($row in @($map)) {
    if ($row.channelId -and $row.streamer -and $knownNames.Contains([string]$row.streamer) -and -not $channelToStreamer.ContainsKey([string]$row.channelId)) {
      $channelToStreamer[[string]$row.channelId] = [string]$row.streamer
    }
  }
}

# ---- 既存の候補(壊れていたら上書きしない) ----
$candidates = New-Object System.Collections.Generic.List[object]
$byVideo = @{}
if (Test-Path $outPath) {
  try {
    $existing = ([IO.File]::ReadAllText($outPath, [Text.Encoding]::UTF8)).TrimStart([char]0xFEFF) | ConvertFrom-Json
  } catch {
    throw "既存の候補ファイルが JSON として読めないため中止しました(上書きしていません): $outPath"
  }
  foreach ($c in @($existing.candidates)) {
    if ($c -and $c.videoId -and -not $byVideo.ContainsKey([string]$c.videoId)) { $candidates.Add($c); $byVideo[[string]$c.videoId] = $c }
  }
}

# ---- RSS の読み取り ----
$ns = @{ a = "http://www.w3.org/2005/Atom"; yt = "http://www.youtube.com/xml/schemas/2015"; media = "http://search.yahoo.com/mrss/" }
function ConvertTo-JstDateText([string]$iso) {
  $d = [DateTimeOffset]::Parse($iso, [Globalization.CultureInfo]::InvariantCulture)
  return $d.ToOffset([TimeSpan]::FromHours(9)).ToString("yyyy-MM-dd")
}
$now = (Get-Date).ToString("s")
$stat = [ordered]@{ feeds = 0; feedsRead = 0; entries = 0; newCandidates = 0; alreadyCandidate = 0; registeredStandalone = 0; noGame = 0 }
$errors = New-Object System.Collections.Generic.List[object]
$warnings = New-Object System.Collections.Generic.List[object]

foreach ($file in @(Get-ChildItem -Path $FeedDir -Filter *.xml -File | Sort-Object Name)) {
  $stat.feeds++
  try {
    $doc = New-Object System.Xml.XmlDocument
    $doc.XmlResolver = $null
    $doc.LoadXml([IO.File]::ReadAllText($file.FullName, [Text.Encoding]::UTF8))
  } catch {
    $errors.Add([pscustomobject]@{ file = $file.Name; reason = "XMLとして読めない" }); continue
  }
  $nsm = New-Object System.Xml.XmlNamespaceManager($doc.NameTable)
  foreach ($k in $ns.Keys) { $nsm.AddNamespace($k, $ns[$k]) }
  $feed = $doc.SelectSingleNode("/a:feed", $nsm)
  if (-not $feed) { $errors.Add([pscustomobject]@{ file = $file.Name; reason = "YouTube RSS(Atom feed)ではない" }); continue }
  $channelNode = $feed.SelectSingleNode("yt:channelId", $nsm)
  $channelId = if ($channelNode) { $channelNode.InnerText.Trim() } else { "" }
  if ($channelId -and $channelId -notmatch '^UC') { $channelId = "UC" + $channelId }   # RSS の yt:channelId は UC を省くことがある
  if (-not $channelId) { $errors.Add([pscustomobject]@{ file = $file.Name; reason = "チャンネルIDが無い" }); continue }
  if (-not $channelToStreamer.ContainsKey($channelId)) { $errors.Add([pscustomobject]@{ file = $file.Name; channelId = $channelId; reason = "登録済みVTuberのチャンネルではない(対応付けできない)" }); continue }
  $streamer = $channelToStreamer[$channelId]
  $stat.feedsRead++
  $entries = @($feed.SelectNodes("a:entry", $nsm))
  if ($entries.Count -eq 0) { $warnings.Add([pscustomobject]@{ file = $file.Name; streamer = $streamer; reason = "動画が1件も無い" }); continue }

  foreach ($e in $entries) {
    $stat.entries++
    $vidNode = $e.SelectSingleNode("yt:videoId", $nsm)
    $videoId = if ($vidNode) { $vidNode.InnerText.Trim() } else { "" }
    if ($videoId -notmatch '^[A-Za-z0-9_-]{11}$') { $warnings.Add([pscustomobject]@{ file = $file.Name; streamer = $streamer; reason = "動画IDが読めない項目を飛ばした" }); continue }
    if ($standaloneVideoIds.Contains($videoId)) { $stat.registeredStandalone++; continue }
    if ($byVideo.ContainsKey($videoId)) { $stat.alreadyCandidate++; $byVideo[$videoId].lastSeenAt = $now; continue }

    $titleNode = $e.SelectSingleNode("a:title", $nsm)
    $title = if ($titleNode) { $titleNode.InnerText } else { "" }
    $descNode = $e.SelectSingleNode("media:group/media:description", $nsm)
    $description = if ($descNode) { $descNode.InnerText } else { "" }
    $pubNode = $e.SelectSingleNode("a:published", $nsm)
    $published = if ($pubNode) { $pubNode.InnerText.Trim() } else { "" }
    $publishedDate = ""
    if ($published) { try { $publishedDate = ConvertTo-JstDateText $published } catch { $publishedDate = "" } }

    $pairKey = $streamer
    $hasGamePlaylist = { param($gameName) $siteGamePairs.Contains($pairKey + "`t" + $gameName) }.GetNewClosure()
    $m = Get-StandaloneMatch $gameIndex $title $description @{ siteHasGamePlaylist = $hasGamePlaylist }
    if (-not $m) { $stat.noGame++; continue }
    $reasons = @($m.reasons)
    if (-not $publishedDate) { $reasons += "公開日時が読めない" }
    $c = [pscustomobject]@{
      videoId = $videoId; url = ("https://www.youtube.com/watch?v=" + $videoId)
      streamer = $streamer; channelId = $channelId
      title = $title; publishedAt = $published; publishedDate = $publishedDate
      game = $m.game; confidence = $m.confidence; matchType = $m.matchType; matchedAlias = $m.matchedAlias
      reasons = @($reasons); otherGames = @($m.otherGames)
      likelyNonGame = (@($m.reasons | Where-Object { $_ -like '非ゲーム語*' }).Count -gt 0)
      siteHasGamePlaylist = [bool](& $hasGamePlaylist $m.game)
      playlistVideoCheck = "unverified"   # 登録済み再生リストの中身は API を使わないと確認できない
      status = "pending"                  # 登録データへの反映は人が承認してから
      source = "rss"; firstSeenAt = $now; lastSeenAt = $now
    }
    $candidates.Add($c); $byVideo[$videoId] = $c; $stat.newCandidates++
  }
}

# ---- 書き出し(一時ファイル → 置き換え) ----
$result = [pscustomobject]@{
  generatedAt = $now
  source = "youtube-channel-rss"
  note = "自動判定結果です(status=pending)。登録前に動画内容・再生リスト状況・single/multi を人が確認してください。playlistVideoCheck=unverified は、サイト登録済み再生リストに含まれるかを確認していないことを表します。"
  # List を @() で包むと Windows PowerShell 5.1 では空のときに "Argument types do not match" になるため ToArray() を使う
  lastRun = [pscustomobject]@{ stats = [pscustomobject]$stat; errors = $errors.ToArray(); warnings = $warnings.ToArray() }
  candidates = @($candidates | Sort-Object @{ Expression = { [string]$_.publishedAt }; Descending = $true }, videoId)
}
$tmp = $outPath + ".tmp"
[IO.File]::WriteAllText($tmp, ($result | ConvertTo-Json -Depth 8), (New-Object System.Text.UTF8Encoding($false)))
Move-Item -LiteralPath $tmp -Destination $outPath -Force

Write-Output ("完了: $outPath  RSS $($stat.feeds) 件(読めた $($stat.feedsRead))・動画 $($stat.entries) 本 → 新規候補 $($stat.newCandidates) / 検出済み $($stat.alreadyCandidate) / 登録済み単発 $($stat.registeredStandalone) / ゲーム不明 $($stat.noGame)  候補合計 $($candidates.Count)")
if ($errors.Count -gt 0) { Write-Output ("エラー $($errors.Count) 件: " + (($errors | ForEach-Object { "$($_.file)=$($_.reason)" }) -join " / ")) }
if ($warnings.Count -gt 0) { Write-Output ("警告 $($warnings.Count) 件: " + (($warnings | ForEach-Object { "$($_.file)=$($_.reason)" }) -join " / ")) }
