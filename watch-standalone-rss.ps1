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

  ■ RSS の取得(-Streamer / -ChannelId を指定したとき)
    YouTube 公式のチャンネルフィード(-FeedUrlTemplate)を1チャンネル1回取得し、-FeedDir に <チャンネルID>.xml で保存してから
    上と同じ解析・照合・重複判定に渡す(このときは今回取得した RSS だけを処理し、-FeedDir にある古いファイルは読まない)。
    HTTP エラー・タイムアウト・通信エラー・XML として読めない応答は、-RetryDelaySeconds 秒あけて1回だけ再試行する。
    それでも失敗したチャンネルは lastRun.errors に理由を記録して次へ進む(既存の候補は消さない)。
    -ChannelMapPath を省略したときは streamer-channel-ids.json を使う。YouTube Data API は使わない。

.PARAMETER FeedDir
  RSS XML(*.xml)を置いたフォルダ。RSS を取得するときは保存先(無ければ作る)。
.PARAMETER Streamer
  RSS を取得する VTuber 名(STREAMERS の name。複数可)。
.PARAMETER ChannelId
  RSS を取得するチャンネルID(UC で始まる24文字。複数可)。
.PARAMETER TimeoutSec
  RSS 取得1回あたりのタイムアウト秒数(既定 30)。
.PARAMETER RetryDelaySeconds
  失敗してから再試行するまでの秒数(既定 3)。
.PARAMETER RequestIntervalMs
  チャンネルごとの取得の間隔(ミリ秒、既定 500)。
.PARAMETER FeedUrlTemplate
  RSS の URL。{0} がチャンネルIDに置き換わる(既定は YouTube 公式のチャンネルフィード)。
.PARAMETER RequestScript
  テスト用。取得関数 Invoke-StandaloneRssRequest を置き換える .ps1(モック)。通常は指定しない。
.PARAMETER OutFile
  候補の保存先(既定 discovered-standalone-rss.json)。相対パスはスクリプトのフォルダから。
.PARAMETER ChannelMapPath
  任意。チャンネルID → VTuber 名の対応表(JSON 配列。各要素に streamer と channelId)。
  discovered-playlists-*.json をそのまま指定できる。STREAMERS が @ハンドルだけのVTuberを対応付けるために使う。
.EXAMPLE
  .\watch-standalone-rss.ps1 -FeedDir .\rss-feeds -ChannelMapPath .\discovered-playlists-20261011.json
.EXAMPLE
  .\watch-standalone-rss.ps1 -FeedDir .\rss-feeds -Streamer "獅白ぼたん"
  獅白ぼたんの RSS を1回取得して候補を抽出する
#>
param(
  [Parameter(Mandatory = $true)][string]$FeedDir,
  [string]$OutFile = "discovered-standalone-rss.json",
  [string]$ChannelMapPath,
  [string]$CorePath,
  [string]$PlaylistsPath,
  [string]$StandalonePath,
  [string[]]$Streamer,
  [string[]]$ChannelId,
  [int]$TimeoutSec = 30,
  [int]$RetryDelaySeconds = 3,
  [int]$RequestIntervalMs = 500,
  [string]$FeedUrlTemplate = "https://www.youtube.com/feeds/videos.xml?channel_id={0}",
  [string]$RequestScript
)

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
if (-not $CorePath) { $CorePath = Join-Path $scriptDir "data-core.js" }
if (-not $PlaylistsPath) { $PlaylistsPath = Join-Path $scriptDir "data-playlists.js" }
if (-not $StandalonePath) { $StandalonePath = Join-Path $scriptDir "data-standalone.js" }
$outPath = if ([IO.Path]::IsPathRooted($OutFile)) { $OutFile } else { Join-Path $scriptDir $OutFile }
# powershell -File では配列を渡せないため、"A,B" のようなカンマ区切りも受け付ける
$Streamer = @($Streamer | ForEach-Object { "$_" -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$ChannelId = @($ChannelId | ForEach-Object { "$_" -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$fetchMode = ($Streamer.Count + $ChannelId.Count) -gt 0
if ($fetchMode) {
  if (-not (Test-Path $FeedDir)) { New-Item -ItemType Directory -Path $FeedDir -Force | Out-Null }
  if (-not $ChannelMapPath) { $defaultMap = Join-Path $scriptDir "streamer-channel-ids.json"; if (Test-Path $defaultMap) { $ChannelMapPath = $defaultMap } }
}
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
# 未登録作品の候補(作品名ごと)。既存分を引き継ぎ、記録済みの動画IDは二度追加しない
$unknownGames = New-Object System.Collections.Generic.List[object]
$unknownByKey = @{}
$unknownVideoIds = New-Object System.Collections.Generic.HashSet[string]
if ($existing) {
  foreach ($u in @($existing.unknownGames)) {
    if (-not $u -or -not $u.key -or $unknownByKey.ContainsKey([string]$u.key)) { continue }
    $unknownGames.Add($u); $unknownByKey[[string]$u.key] = $u
    foreach ($v in @($u.videos)) { if ($v -and $v.videoId) { [void]$unknownVideoIds.Add([string]$v.videoId) } }
  }
}
function Add-UnknownGameVideo($cand, $video) {
  if ($unknownByKey.ContainsKey($cand.key)) {
    $g = $unknownByKey[$cand.key]
    if (@($g.videos | Where-Object { $_.videoId -eq $video.videoId }).Count -gt 0) { return }
    $g.videos = @(@($g.videos) + $video)
    $g.streamers = @(@($g.streamers) + $video.streamer | Select-Object -Unique)
    $g.possibleExisting = @(@($g.possibleExisting) + @($cand.possibleExisting) | Where-Object { $_ } | Select-Object -Unique)
    $g.lastSeenAt = $video.firstSeenAt
  } else {
    $g = [pscustomobject]@{
      name = $cand.name; key = $cand.key; confidence = $cand.confidence; videoCount = 0
      streamers = @($video.streamer); possibleExisting = @($cand.possibleExisting); reasons = @()
      status = "pending"; videos = @($video); firstSeenAt = $video.firstSeenAt; lastSeenAt = $video.firstSeenAt
    }
    $unknownGames.Add($g); $unknownByKey[$cand.key] = $g
  }
  $g.videoCount = @($g.videos).Count
  # 作品名ごとの信頼度: どれかの動画が MEDIUM、または2本以上の動画に出てくれば MEDIUM(HIGH にはしない)
  $g.confidence = $(if (@($g.videos | Where-Object { $_.confidence -eq "MEDIUM" }).Count -gt 0 -or $g.videoCount -ge 2) { "MEDIUM" } else { "LOW" })
  $g.reasons = @(@($g.videos | ForEach-Object { $_.reasons }) + $(if ($g.videoCount -ge 2) { "2本以上の動画に出てくる" }) | Where-Object { $_ } | Select-Object -Unique)
}

# ---- RSS の読み取り ----
$ns = @{ a = "http://www.w3.org/2005/Atom"; yt = "http://www.youtube.com/xml/schemas/2015"; media = "http://search.yahoo.com/mrss/" }
function ConvertTo-JstDateText([string]$iso) {
  $d = [DateTimeOffset]::Parse($iso, [Globalization.CultureInfo]::InvariantCulture)
  return $d.ToOffset([TimeSpan]::FromHours(9)).ToString("yyyy-MM-dd")
}
$now = (Get-Date).ToString("s")
$stat = [ordered]@{ feeds = 0; feedsRead = 0; entries = 0; newCandidates = 0; alreadyCandidate = 0; registeredStandalone = 0; noGame = 0; unknownGameVideos = 0 }
$errors = New-Object System.Collections.Generic.List[object]
$warnings = New-Object System.Collections.Generic.List[object]

# ---- RSS の取得(-Streamer / -ChannelId を指定したときだけ) ----
# 取得関数。戻り値は @{ ok; status; content } / 失敗時 @{ ok = $false; status; reason }。テストでは -RequestScript で置き換える
function Invoke-StandaloneRssRequest([string]$url, [int]$timeoutSec) {
  try {
    $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec $timeoutSec -Headers @{ "User-Agent" = "Mozilla/5.0 (compatible; vgame-navi-rss-watch)" }
    $text = [Text.Encoding]::UTF8.GetString($r.RawContentStream.ToArray())   # 文字コードの推測に頼らず UTF-8 で読む
    return @{ ok = $true; status = [int]$r.StatusCode; content = $text }
  } catch {
    $status = $null
    if ($_.Exception.Response) { try { $status = [int]$_.Exception.Response.StatusCode } catch { $status = $null } }
    $isTimeout = ($_.Exception -is [System.Net.WebException]) -and ($_.Exception.Status -eq [System.Net.WebExceptionStatus]::Timeout)
    $reason = if ($status) { "HTTP $status" } elseif ($isTimeout) { "タイムアウト" } else { "通信エラー" }
    return @{ ok = $false; status = $status; reason = $reason }
  }
}
if ($RequestScript) { . $RequestScript }
function Test-StandaloneRssXml([string]$text) {
  try {
    $d = New-Object System.Xml.XmlDocument; $d.XmlResolver = $null; $d.LoadXml($text)
    return ($d.DocumentElement -and $d.DocumentElement.LocalName -eq "feed" -and $d.DocumentElement.NamespaceURI -eq "http://www.w3.org/2005/Atom")
  } catch { return $false }
}

$feedFiles = @()
if ($fetchMode) {
  [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
  $stat.fetchTargets = 0; $stat.fetched = 0; $stat.fetchFailed = 0; $stat.retried = 0
  $nameToChannel = @{}
  foreach ($k in $channelToStreamer.Keys) { $nameToChannel[$channelToStreamer[$k]] = $k }
  $targets = New-Object System.Collections.Generic.List[object]
  foreach ($n in @($Streamer | Where-Object { $_ })) {
    if ($nameToChannel.ContainsKey($n)) { $targets.Add([pscustomobject]@{ channelId = $nameToChannel[$n]; streamer = $n }) }
    else { $errors.Add([pscustomobject]@{ streamer = $n; reason = "チャンネルIDが分からないVTuber(対応表・STREAMERS に無い)"; stage = "fetch" }) }
  }
  foreach ($cid in @($ChannelId | Where-Object { $_ })) {
    if ($cid -notmatch '^UC[A-Za-z0-9_-]{22}$') { $errors.Add([pscustomobject]@{ channelId = $cid; reason = "チャンネルIDの形式が正しくない"; stage = "fetch" }); continue }
    $targets.Add([pscustomobject]@{ channelId = $cid; streamer = $(if ($channelToStreamer.ContainsKey($cid)) { $channelToStreamer[$cid] } else { "" }) })
  }
  $seenTargets = New-Object System.Collections.Generic.HashSet[string]
  $first = $true
  foreach ($t in $targets) {
    if (-not $seenTargets.Add($t.channelId)) { continue }
    $stat.fetchTargets++
    if (-not $first -and $RequestIntervalMs -gt 0) { Start-Sleep -Milliseconds $RequestIntervalMs }
    $first = $false
    $url = $FeedUrlTemplate -f $t.channelId
    $saved = $null; $reason = $null
    for ($attempt = 1; $attempt -le 2; $attempt++) {
      if ($attempt -eq 2) { $stat.retried++; if ($RetryDelaySeconds -gt 0) { Start-Sleep -Seconds $RetryDelaySeconds } }
      $res = Invoke-StandaloneRssRequest $url $TimeoutSec
      if (-not $res.ok) { $reason = [string]$res.reason; continue }
      if (-not (Test-StandaloneRssXml ([string]$res.content))) { $reason = "XMLとして読めない応答"; continue }
      $saved = Join-Path $FeedDir ($t.channelId + ".xml")
      [IO.File]::WriteAllText($saved, [string]$res.content, (New-Object System.Text.UTF8Encoding($false)))
      break
    }
    if ($saved) {
      $stat.fetched++
      $feedFiles += Get-Item -LiteralPath $saved
      if ($attempt -eq 2) { $warnings.Add([pscustomobject]@{ channelId = $t.channelId; streamer = $t.streamer; reason = "1回目の取得に失敗し、再試行で取得した(" + $reason + ")"; stage = "fetch" }) }
    } else {
      $stat.fetchFailed++
      $errors.Add([pscustomobject]@{ channelId = $t.channelId; streamer = $t.streamer; reason = $reason; attempts = 2; stage = "fetch" })
    }
  }
} else {
  $feedFiles = @(Get-ChildItem -Path $FeedDir -Filter *.xml -File | Sort-Object Name)
}

foreach ($file in $feedFiles) {
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
  $feedChannelId = if ($channelNode) { $channelNode.InnerText.Trim() } else { "" }
  if ($feedChannelId -and $feedChannelId -notmatch '^UC') { $feedChannelId = "UC" + $feedChannelId }   # RSS の yt:channelId は UC を省くことがある
  if (-not $feedChannelId) { $errors.Add([pscustomobject]@{ file = $file.Name; reason = "チャンネルIDが無い" }); continue }
  if (-not $channelToStreamer.ContainsKey($feedChannelId)) { $errors.Add([pscustomobject]@{ file = $file.Name; channelId = $feedChannelId; reason = "登録済みVTuberのチャンネルではない(対応付けできない)" }); continue }
  $feedStreamer = $channelToStreamer[$feedChannelId]
  $stat.feedsRead++
  $entries = @($feed.SelectNodes("a:entry", $nsm))
  if ($entries.Count -eq 0) { $warnings.Add([pscustomobject]@{ file = $file.Name; streamer = $feedStreamer; reason = "動画が1件も無い" }); continue }

  foreach ($e in $entries) {
    $stat.entries++
    $vidNode = $e.SelectSingleNode("yt:videoId", $nsm)
    $videoId = if ($vidNode) { $vidNode.InnerText.Trim() } else { "" }
    if ($videoId -notmatch '^[A-Za-z0-9_-]{11}$') { $warnings.Add([pscustomobject]@{ file = $file.Name; streamer = $feedStreamer; reason = "動画IDが読めない項目を飛ばした" }); continue }
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

    $pairKey = $feedStreamer
    $hasGamePlaylist = { param($gameName) $siteGamePairs.Contains($pairKey + "`t" + $gameName) }.GetNewClosure()
    $m = Get-StandaloneMatch $gameIndex $title $description @{ siteHasGamePlaylist = $hasGamePlaylist }
    if (-not $m) {
      $stat.noGame++
      # 既存作品に一致しない動画から、未登録作品の候補を取り出す(作品マスタには登録しない)
      if (-not $unknownVideoIds.Contains($videoId)) {
        $added = $false
        # 関数は配列を1つの値として返す(, $out)ので、@() で包まずに変数で受ける(0件のとき空配列が1件として数えられるのを防ぐ)
        $unknownCands = Get-StandaloneUnknownGameCandidates $gameIndex $title $description
        foreach ($u in $unknownCands) {
          if (-not $u -or -not $u.key) { continue }
          Add-UnknownGameVideo $u ([pscustomobject]@{
            videoId = $videoId; url = ("https://www.youtube.com/watch?v=" + $videoId)
            streamer = $feedStreamer; channelId = $feedChannelId; title = $title; publishedDate = $publishedDate
            source = $u.source; confidence = $u.confidence; reasons = @($u.reasons); firstSeenAt = $now
          })
          $added = $true
        }
        if ($added) { [void]$unknownVideoIds.Add($videoId); $stat.unknownGameVideos++ }
      }
      continue
    }
    $reasons = @($m.reasons)
    if (-not $publishedDate) { $reasons += "公開日時が読めない" }
    $c = [pscustomobject]@{
      videoId = $videoId; url = ("https://www.youtube.com/watch?v=" + $videoId)
      streamer = $feedStreamer; channelId = $feedChannelId
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
  # 作品マスタに無い作品の候補(すべて status=pending。登録するかは人が判断する)
  unknownGames = @($unknownGames | Sort-Object @{ Expression = { [int]$_.videoCount }; Descending = $true }, key)
}
$tmp = $outPath + ".tmp"
[IO.File]::WriteAllText($tmp, ($result | ConvertTo-Json -Depth 8), (New-Object System.Text.UTF8Encoding($false)))
Move-Item -LiteralPath $tmp -Destination $outPath -Force

Write-Output ("完了: $outPath  RSS $($stat.feeds) 件(読めた $($stat.feedsRead))・動画 $($stat.entries) 本 → 新規候補 $($stat.newCandidates) / 検出済み $($stat.alreadyCandidate) / 登録済み単発 $($stat.registeredStandalone) / ゲーム不明 $($stat.noGame)(うち未登録作品の候補 $($stat.unknownGameVideos) 本)  候補合計 $($candidates.Count)・未登録作品の候補 $($unknownGames.Count) 作品")
if ($errors.Count -gt 0) { Write-Output ("エラー $($errors.Count) 件: " + (($errors | ForEach-Object { "$($_.file)=$($_.reason)" }) -join " / ")) }
if ($warnings.Count -gt 0) { Write-Output ("警告 $($warnings.Count) 件: " + (($warnings | ForEach-Object { "$($_.file)=$($_.reason)" }) -join " / ")) }
