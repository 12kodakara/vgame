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

  ■ 動画ごとの履歴(-FeedDir\entries\<チャンネルID>.json)
    RSS を読むたびに、動画ID・タイトル・説明欄・公開日時・初回検出日時(firstSeenAt)・最終検出日時(lastSeenAt)を動画単位で記録する。
    同じ動画IDは追加せず、タイトル・説明欄・公開日時と lastSeenAt だけ更新する(検出日時は RSS ファイルの保存日時)。
    新着15本から外れた動画も残る。履歴は自動では削除しない。以前の archive\<チャンネルID>\*.xml も削除しない(一括再判定で取り込む)。
    履歴JSONが読めないときは上書きせず、lastRun.errors に記録してそのチャンネルの履歴の更新だけ飛ばす。
    書き込みは一時ファイル経由で、置き換え前のファイルを .bak に残す。

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
.PARAMETER All
  対応表(streamer-channel-ids.json)の順に巡回する。件数は -MaxChannels(既定3)まで。
  293名を一度に取得するには -MaxChannels 293 のように件数を明示する(指定しなければ3名で止まる)。
  -Streamer / -ChannelId とは同時に指定できない。
.PARAMETER MaxChannels
  -All で巡回するチャンネル数の上限(既定 3)。
.PARAMETER RejudgeOnly
  一括再判定。動画ごとの履歴(-FeedDir\entries\<チャンネルID>.json)と -FeedDir の RSS(以前の archive の XML を含む)を読み、
  既存の候補のうち確認待ち(pending)のものと、未登録作品の候補に記録済みの動画だけを今のロジックで判定し直す。
  新しい動画は候補に追加しない。RSS は取得しない。
  -Streamer / -ChannelId / -All とは同時に指定できない。
.PARAMETER Source
  取得元。Rss(既定。YouTube のチャンネル RSS)か Api(YouTube Data API。取得するときだけ指定できる)。
  Api ではチャンネルID の UC… を UU… にした「アップロード動画の再生リスト」を playlistItems.list で読む(1ページ50本・1 unit)。
  再生リストが見つからないときだけ channels.list で調べ直す。2ページ目は、前回の記録があるのに1ページ目の50本に
  既知の動画が1本も無いときだけ読む(最大2ページ)。API キーは環境変数 YOUTUBE_API_KEY から読み、表示しない。
  利用枠の超過・上限到達では取得をやめて取得できた分だけ判定する。キー・権限のエラーでは取得をやめて終了コード 3。
.PARAMETER MaxApiCalls
  -Source Api で1回の実行に使う API 呼び出しの上限(既定 300。失敗した呼び出しも1回と数える)。
.PARAMETER InitialMaxAgeDays
  -Source Api と一緒に指定。各チャンネルの初回 API 巡回(履歴の apiFirstCrawledAt が無い。RSS の履歴の有無は問わない)だけ、
  公開からこの日数を超えた動画を候補にしない(既定 0 = 制限しない)。その動画は履歴に記録し、candidateSkipped を付けて
  次回以降も候補にしない。初回 API 巡回を終えたチャンネルは履歴に apiFirstCrawledAt を記録する(取得に失敗したチャンネルは記録しない)。
.PARAMETER PriorityChannelId
  -All と一緒に指定。対応表の順の巡回より先に取得するチャンネルID(前回の lastRun.retryChannelIds。カンマ区切り可)。
  -MaxChannels の枠に含める。取得前に止めた・失敗したものは、次回用に lastRun.retryChannelIds に残す。
.PARAMETER StartIndex
  -All で巡回を始める対応表の位置(0 始まり、既定 0)。結果の lastRun.stats.crawlNextIndex が次回の開始位置。
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
  [string]$RequestScript,
  [switch]$All,
  [int]$MaxChannels = 3,
  [int]$StartIndex = 0,
  [switch]$RejudgeOnly,
  [ValidateSet("Rss", "Api")][string]$Source = "Rss",
  [int]$MaxApiCalls = 300,
  [int]$InitialMaxAgeDays = 0,
  [string[]]$PriorityChannelId
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
if ($All -and ($Streamer.Count + $ChannelId.Count) -gt 0) { throw "-All と -Streamer / -ChannelId は同時に指定できません。" }
if ($All -and $MaxChannels -lt 1) { throw "-MaxChannels には1以上の件数を指定してください。" }
if ($All -and $StartIndex -lt 0) { throw "-StartIndex には0以上を指定してください。" }
if ($RejudgeOnly -and ($All -or ($Streamer.Count + $ChannelId.Count) -gt 0)) { throw "-RejudgeOnly は -Streamer / -ChannelId / -All と同時に指定できません(一括再判定は RSS を取得しません)。" }
$fetchMode = (($Streamer.Count + $ChannelId.Count) -gt 0) -or [bool]$All
$PriorityChannelId = @($PriorityChannelId | ForEach-Object { "$_" -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
if ($PriorityChannelId.Count -gt 0 -and -not $All) { throw "-PriorityChannelId は -All と一緒に指定してください(巡回の前に取り直すチャンネル)。" }
if ($InitialMaxAgeDays -lt 0) { throw "-InitialMaxAgeDays には0以上を指定してください。" }
if ($InitialMaxAgeDays -gt 0 -and $Source -ne "Api") { throw "-InitialMaxAgeDays は -Source Api と一緒に指定してください(各チャンネルの初回 API 巡回だけに使う)。" }
if ($Source -eq "Api") {
  if (-not $fetchMode) { throw "-Source Api は取得するとき(-All / -Streamer / -ChannelId)だけ指定できます。" }
  if ($MaxApiCalls -lt 1) { throw "-MaxApiCalls には1以上を指定してください。" }
  # API キーは環境変数からだけ読む(引数・ログ・出力ファイルには出さない)
  $apiKey = [string]$env:YOUTUBE_API_KEY
  if (-not $apiKey) { throw "環境変数 YOUTUBE_API_KEY が設定されていません(-Source Api では必須)。何も取得していません。" }
}
if ($fetchMode) {
  if (-not (Test-Path $FeedDir)) { New-Item -ItemType Directory -Path $FeedDir -Force | Out-Null }
  if (-not $ChannelMapPath) { $defaultMap = Join-Path $scriptDir "streamer-channel-ids.json"; if (Test-Path $defaultMap) { $ChannelMapPath = $defaultMap } }
}
if (-not (Test-Path $FeedDir -PathType Container)) { throw "RSS のフォルダが見つかりません: $FeedDir" }
$feedDirFull = (Resolve-Path -LiteralPath $FeedDir).ProviderPath

. (Join-Path $scriptDir "standalone-matching.ps1")

# ---- Windows PowerShell 5.1 / PowerShell 7(Windows・Ubuntu)で同じ結果にするための共通処理 ----
# JSON の読み込み: PowerShell 7 の ConvertFrom-Json は日付に見える文字列を日時型に変えてしまうため、文字列のまま読む
#   5.1: ConvertFrom-Json(日付を変換しない) / 7.5 以降: -DateKind String / 7.0〜7.4: Newtonsoft.Json で日付を解釈せずに読む
$jsonHasDateKind = (Get-Command ConvertFrom-Json).Parameters.ContainsKey("DateKind")
function ConvertFrom-StandaloneJToken($t) {
  switch ([string]$t.Type) {
    "Object" { $o = [ordered]@{}; foreach ($p in $t.Properties()) { $o[$p.Name] = ConvertFrom-StandaloneJToken $p.Value }; return [pscustomobject]$o }
    "Array" { $items = New-Object System.Collections.Generic.List[object]; foreach ($x in $t) { $items.Add((ConvertFrom-StandaloneJToken $x)) }; return , $items.ToArray() }
    "Null" { return $null }
    default { return $t.Value }
  }
}
function ConvertFrom-StandaloneJson([string]$text) {
  $text = $text.TrimStart([char]0xFEFF)
  if ($PSVersionTable.PSVersion.Major -lt 6) { return , ($text | ConvertFrom-Json) }
  if ($jsonHasDateKind) { return , ($text | ConvertFrom-Json -DateKind String -NoEnumerate) }
  if (-not ("Newtonsoft.Json.JsonTextReader" -as [type])) { [void]("{}" | ConvertFrom-Json) }   # PowerShell 7 に同梱の Newtonsoft.Json を読み込む
  $reader = [Newtonsoft.Json.JsonTextReader]::new([IO.StringReader]::new($text))
  $reader.DateParseHandling = [Newtonsoft.Json.DateParseHandling]::None
  return , (ConvertFrom-StandaloneJToken ([Newtonsoft.Json.Linq.JToken]::ReadFrom($reader)))
}
# 日時の記録: OS のタイムゾーンに関係なく日本時間(+09:00)で、従来と同じ書式(yyyy-MM-ddTHH:mm:ss)にする
function Get-StandaloneJstStamp([DateTime]$utc) {
  return ([DateTimeOffset]$utc.ToUniversalTime()).ToOffset([TimeSpan]::FromHours(9)).ToString("yyyy-MM-dd'T'HH:mm:ss", [Globalization.CultureInfo]::InvariantCulture)
}
# 並べ替え: 言語設定で順序が変わらないよう、文字列は序数(Ordinal)で比べる
function Get-StandaloneOrdinalSorted($items, [scriptblock]$compare) {
  $arr = [object[]]@()
  if ($null -ne $items) { $arr = [object[]]$items }
  if ($arr.Count -gt 1) { [Array]::Sort($arr, [Comparison[object]]$compare) }
  return , $arr
}
function Get-StandaloneFilesByName($files) { return , (Get-StandaloneOrdinalSorted $files { param($x, $y) [string]::CompareOrdinal($x.Name, $y.Name) }) }
function Get-StandaloneOrdinalKeys($hashtable) { [string[]]$k = @($hashtable.Keys); [Array]::Sort($k, [StringComparer]::Ordinal); return , $k }

# ---- 元データの読み取り(discover-standalone.ps1 と同じ書式を前提に、1件1行の項目を拾う) ----
$full = ([IO.File]::ReadAllText($CorePath, [Text.Encoding]::UTF8)) + "`n" + ([IO.File]::ReadAllText($PlaylistsPath, [Text.Encoding]::UTF8))
function Get-ArrayBlock([string]$name) {
  $start = $full.IndexOf("const $name = [", [StringComparison]::Ordinal)
  if ($start -lt 0) { throw "$name 配列が見つかりません。" }
  $end = $full.IndexOf("`n];", $start, [StringComparison]::Ordinal)
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
  $map = ConvertFrom-StandaloneJson ([IO.File]::ReadAllText($ChannelMapPath, [Text.Encoding]::UTF8))
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
    $existing = ConvertFrom-StandaloneJson ([IO.File]::ReadAllText($outPath, [Text.Encoding]::UTF8))
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
$rjEvidence = @{}    # 一括再判定: 新しい動画から集めた「未登録作品名 → 配信者」(候補には追加しない)
$weakUnknown = @{}   # ゲームを表す語が無い未登録作品名(key → 動画の一覧)。全RSSを読み終えてから判定する
# オブジェクトの項目を書き換える(JSON から読んだ古い候補に項目が無ければ追加する)
function Set-ObjProp($obj, [string]$name, $value) {
  if ($obj.PSObject.Properties[$name]) { $obj.$name = $value } else { $obj | Add-Member -NotePropertyName $name -NotePropertyValue $value }
}
# 作品名ごとの信頼度・理由を、再判定で外れた動画を除いて計算し直す(どれかが MEDIUM か、2本以上なら MEDIUM。HIGH にはしない)
function Update-UnknownGroupSummary($g) {
  $active = @($g.videos | Where-Object { [string]$_.rejudged -ne "not-candidate" })
  Set-ObjProp $g "videoCount" $active.Count
  if ($active.Count -eq 0) {
    Set-ObjProp $g "confidence" "NONE"
    Set-ObjProp $g "reviewGroup" "rejudged-not-candidate"   # 削除はしない(確認待ちのまま印だけ付ける)
    return
  }
  Set-ObjProp $g "reviewGroup" "unknown-game"
  Set-ObjProp $g "streamers" @($active | ForEach-Object { $_.streamer } | Select-Object -Unique)
  Set-ObjProp $g "confidence" $(if (@($active | Where-Object { $_.confidence -eq "MEDIUM" }).Count -gt 0 -or $active.Count -ge 2) { "MEDIUM" } else { "LOW" })
  Set-ObjProp $g "reasons" @(@($active | ForEach-Object { $_.reasons }) + $(if ($active.Count -ge 2) { "2本以上の動画に出てくる" }) | Where-Object { $_ } | Select-Object -Unique)
}
# 未登録作品の候補に記録済みの動画を判定し直す。今の判定でその作品名が出なくなった動画には rejudged = not-candidate を付ける
#   人が確認した(status が pending 以外の)作品名は変えない
function Update-UnknownVideoJudgement([string]$videoId, $newCands) {
  # ゲームを表す語が無い名前(weak)はここでは残さない(全RSSを読み終えてから、2人以上の配信者に出てくるときだけ元に戻す)
  $newKeys = New-Object System.Collections.Generic.HashSet[string]([StringComparer]::Ordinal)
  foreach ($u in $newCands) { if ($u -and $u.key -and -not $u.weak) { [void]$newKeys.Add([string]$u.key) } }
  foreach ($g in $unknownGames) {
    if ([string]$g.status -ne "pending") { continue }
    $v = @($g.videos | Where-Object { $_.videoId -eq $videoId }) | Select-Object -First 1
    if (-not $v) { continue }
    $was = [string]$v.rejudged
    if ($newKeys.Contains([string]$g.key)) {
      $u = @($newCands | Where-Object { $_.key -eq $g.key })[0]
      Set-ObjProp $v "confidence" $u.confidence; Set-ObjProp $v "reasons" @($u.reasons); Set-ObjProp $v "rejudged" ""
    } else {
      Set-ObjProp $v "rejudged" "not-candidate"
      Set-ObjProp $v "reasons" @("再判定で未登録作品の候補にならなくなった")
      if ($was -ne "not-candidate") { $stat.unknownRejudgedNotCandidate++ }
    }
    Set-ObjProp $g "lastSeenAt" $now
    Update-UnknownGroupSummary $g
  }
}
function Add-UnknownGameVideo($cand, $video) {
  if ($unknownByKey.ContainsKey($cand.key)) {
    $g = $unknownByKey[$cand.key]
    if (@($g.videos | Where-Object { $_.videoId -eq $video.videoId }).Count -gt 0) { return $false }
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
  Update-UnknownGroupSummary $g
  return $true
}

# ---- RSS の読み取り ----
$ns = @{ a = "http://www.w3.org/2005/Atom"; yt = "http://www.youtube.com/xml/schemas/2015"; media = "http://search.yahoo.com/mrss/" }
function ConvertTo-JstDateText([string]$iso) {
  $d = [DateTimeOffset]::Parse($iso, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal)   # 時差の無い表記は UTC とみなす(OS のタイムゾーンに依存しない)
  return $d.ToOffset([TimeSpan]::FromHours(9)).ToString("yyyy-MM-dd")
}
$now = Get-StandaloneJstStamp ([DateTime]::UtcNow)
$stat = [ordered]@{ feeds = 0; feedsRead = 0; entries = 0; newCandidates = 0; alreadyCandidate = 0; registeredStandalone = 0; noGame = 0; unknownGameVideos = 0; unknownGameVideoRows = 0; likelyInSitePlaylist = 0; templateLines = 0; rejudged = 0; rejudgeChanged = 0; rejudgeNotMatched = 0; unknownRejudgedNotCandidate = 0; rejudgeSkippedNew = 0; rejudgeNotInRss = 0; historyChannels = 0; historyAdded = 0; historyVideos = 0 }
$errors = New-Object System.Collections.Generic.List[object]
# 再判定の件数は動画ごとに数える(一括再判定では同じ動画が履歴の複数のRSSに出てくるため)
$rjIds = New-Object System.Collections.Generic.HashSet[string]; $rjChangedIds = New-Object System.Collections.Generic.HashSet[string]
$rjNotMatchedIds = New-Object System.Collections.Generic.HashSet[string]; $rjSeenIds = New-Object System.Collections.Generic.HashSet[string]
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
# YouTube Data API の GET(1回 = 1 unit)。@{ ok; status; content } か @{ ok = $false; status; reason; apiReason } を返す。
# URL(API キーを含む)は返さない・表示しない。エラーの理由は HTTP ステータスと API の reason(quotaExceeded など)だけを残す
function Invoke-StandaloneApiRequest([string]$url, [int]$timeoutSec) {
  try {
    $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec $timeoutSec
    return @{ ok = $true; status = [int]$r.StatusCode; content = [Text.Encoding]::UTF8.GetString($r.RawContentStream.ToArray()) }
  } catch {
    $status = $null; $body = ""
    if ($_.Exception.Response) { try { $status = [int]$_.Exception.Response.StatusCode } catch { $status = $null } }
    if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $body = [string]$_.ErrorDetails.Message }
    elseif ($_.Exception.Response -and $_.Exception.Response.PSObject.Methods["GetResponseStream"]) {
      try { $sr = New-Object IO.StreamReader($_.Exception.Response.GetResponseStream()); $body = $sr.ReadToEnd(); $sr.Close() } catch { $body = "" }
    }
    $apiReason = ""
    if ($body) { try { $apiReason = [string]@((ConvertFrom-StandaloneJson $body).error.errors)[0].reason } catch { $apiReason = "" } }
    $isTimeout = ($_.Exception -is [System.Net.WebException]) -and ($_.Exception.Status -eq [System.Net.WebExceptionStatus]::Timeout)
    $reason = if ($status) { "HTTP $status" } elseif ($isTimeout) { "タイムアウト" } else { "通信エラー" }
    return @{ ok = $false; status = $status; reason = $reason; apiReason = $apiReason }
  }
}
if ($RequestScript) { . $RequestScript }

# ---- API 方式(-Source Api)の取得 ----
# 失敗の種類: quota = 利用枠の超過(その時点で取得をやめる) / fatal = キーの誤り・権限など(取得をやめ、終了コード 3)
#             notFound = そのチャンネルの再生リストが無い / transient = 一時的(5xx・タイムアウト・回数制限。1回だけ再試行)
function Get-StandaloneApiFailureKind($res) {
  $r = [string]$res.apiReason; $st = 0; if ($res.status) { $st = [int]$res.status }
  if ($r -eq "quotaExceeded" -or $r -eq "dailyLimitExceeded") { return "quota" }
  if ($r -eq "playlistNotFound" -or $r -eq "playlistItemsNotAccessible" -or $st -eq 404) { return "notFound" }
  if ($r -eq "rateLimitExceeded" -or $r -eq "userRateLimitExceeded" -or $r -eq "backendError" -or $st -ge 500 -or $st -eq 0) { return "transient" }
  return "fatal"   # 400(keyInvalid など)・401・その他の 403(accessNotConfigured・forbidden など)
}
$apiState = @{ calls = 0; stopped = "" }   # stopped: limit(呼び出しの上限) / quota / fatal
# API の呼び出し(失敗した呼び出しも1回として数え、-MaxApiCalls を超えて呼ばない)
function Invoke-StandaloneApiCall([string]$query) {
  if ($apiState.stopped) { return @{ ok = $false; skipped = $true } }
  if ($apiState.calls -ge $MaxApiCalls) { $apiState.stopped = "limit"; return @{ ok = $false; skipped = $true } }
  $apiState.calls++
  $res = Invoke-StandaloneApiRequest ("https://www.googleapis.com/youtube/v3/" + $query + "&key=" + [uri]::EscapeDataString($apiKey)) $TimeoutSec
  if (-not $res.ok) {
    $res.kind = Get-StandaloneApiFailureKind $res
    if ($res.kind -eq "quota" -or $res.kind -eq "fatal") { $apiState.stopped = $res.kind }
  }
  return $res
}
function Get-StandaloneApiFailureText($res) {
  if ($res.apiReason) { return "$($res.reason)($($res.apiReason))" } else { return [string]$res.reason }
}
# アップロード動画の再生リストを1ページ(最新50本・1 unit)取得する。一時的な失敗だけ1回再試行する
function Invoke-StandaloneApiPage([string]$playlistId, [string]$pageToken, $log) {
  $res = $null
  for ($i = 1; $i -le 2; $i++) {
    if ($i -eq 2) { $stat.retried++; if ($RetryDelaySeconds -gt 0) { Start-Sleep -Seconds $RetryDelaySeconds } }
    $q = "playlistItems?part=snippet,contentDetails&maxResults=50&playlistId=" + [uri]::EscapeDataString($playlistId)
    if ($pageToken) { $q += "&pageToken=" + [uri]::EscapeDataString($pageToken) }
    $res = Invoke-StandaloneApiCall $q
    if ($res.ok -or $res.skipped) { return $res }
    $log.Add((Get-StandaloneApiFailureText $res))
    if ($res.kind -ne "transient") { return $res }
  }
  return $res
}
# API の結果を RSS と同じ形(videoId / title / description / published)にする。非公開・削除済み(videoPublishedAt が無い)は除く
function ConvertFrom-StandaloneApiItems($data) {
  $list = New-Object System.Collections.Generic.List[object]
  foreach ($it in @($data.items)) {
    $vid = [string]$it.contentDetails.videoId; $pub = [string]$it.contentDetails.videoPublishedAt
    if (-not $vid -or -not $pub) { continue }
    $list.Add([pscustomobject]@{ videoId = $vid; title = [string]$it.snippet.title; description = [string]$it.snippet.description; published = $pub })
  }
  return , $list.ToArray()
}
# 前回までに記録した動画(動画ごとの履歴)。無い・読めないときは $null(初めてのチャンネルとして扱う)
function Get-StandaloneHistoryVideoIds([string]$cid) {
  $path = Join-Path (Join-Path $feedDirFull "entries") ($cid + ".json")
  if (-not (Test-Path -LiteralPath $path)) { return $null }
  try {
    $set = New-Object System.Collections.Generic.HashSet[string]
    foreach ($v in @((ConvertFrom-StandaloneJson ([IO.File]::ReadAllText($path, [Text.Encoding]::UTF8))).videos)) { if ($v.videoId) { [void]$set.Add([string]$v.videoId) } }
    return , $set
  } catch { return $null }
}
# 1チャンネル分: UC… → UU… の再生リストを読む。無ければ channels.list で調べ直して1回だけ取り直す。
# 2ページ目は「前回の記録があるのに、1ページ目の50本に既知の動画が1本も無い(取りこぼしの恐れ)」ときだけ読む
function Get-StandaloneApiUploads($t) {
  $log = New-Object System.Collections.Generic.List[string]
  $callsBefore = $apiState.calls
  $playlistId = "UU" + $t.channelId.Substring(2)
  $res = Invoke-StandaloneApiPage $playlistId "" $log
  if (-not $res.ok -and -not $res.skipped -and $res.kind -eq "notFound") {
    $ch = Invoke-StandaloneApiCall ("channels?part=contentDetails&id=" + [uri]::EscapeDataString($t.channelId))
    if ($ch.ok) {
      $up = ""; try { $up = [string]@((ConvertFrom-StandaloneJson $ch.content).items)[0].contentDetails.relatedPlaylists.uploads } catch { $up = "" }
      if ($up -and $up -ne $playlistId) { $stat.apiResolvedUploads++; $playlistId = $up; $res = Invoke-StandaloneApiPage $playlistId "" $log }
      else { $log.Add("アップロード動画の再生リストが見つからない") }
    } elseif (-not $ch.skipped) { $log.Add((Get-StandaloneApiFailureText $ch)); $res = $ch }
  }
  $calls = $apiState.calls - $callsBefore
  if (-not $res.ok) {
    return @{ ok = $false; attempted = ($calls -gt 0); calls = $calls; log = $log.ToArray(); reason = $(if ($res.skipped) { "API の呼び出しを止めたため取得できなかった($($apiState.stopped))" } else { Get-StandaloneApiFailureText $res }); status = $res.status; apiReason = [string]$res.apiReason }
  }
  $data = ConvertFrom-StandaloneJson $res.content
  $entries = New-Object System.Collections.Generic.List[object]
  $ids = New-Object System.Collections.Generic.HashSet[string]
  foreach ($e in (ConvertFrom-StandaloneApiItems $data)) { if ($ids.Add($e.videoId)) { $entries.Add($e) } }
  $pages = 1
  if ($data.nextPageToken -and $entries.Count -gt 0) {
    $known = Get-StandaloneHistoryVideoIds $t.channelId
    if ($null -ne $known -and @($entries | Where-Object { $known.Contains($_.videoId) }).Count -eq 0) {
      $res2 = Invoke-StandaloneApiPage $playlistId ([string]$data.nextPageToken) $log
      if ($res2.ok) {
        $pages = 2
        foreach ($e in (ConvertFrom-StandaloneApiItems (ConvertFrom-StandaloneJson $res2.content))) { if ($ids.Add($e.videoId)) { $entries.Add($e) } }
      } else {
        $warnings.Add([pscustomobject]@{ channelId = $t.channelId; streamer = $t.streamer; reason = "2ページ目を取得できなかった(1ページ目の50本だけで判定した)"; stage = "fetch" })
      }
    }
  }
  $stat.apiPages += $pages
  return @{ ok = $true; attempted = $true; calls = ($apiState.calls - $callsBefore); log = $log.ToArray(); entries = $entries.ToArray(); pages = $pages }
}
# 説明欄の定型部分(告知欄・宣伝など): 話題の違う3本以上の動画の説明欄に共通して出てくる行
#   (前後の空白を除いて完全一致、2文字未満の行は数えない)。話題はタイトルの最初の【】の中身(無ければタイトルの先頭)で見る。
#   同じシリーズの動画にだけ出てくる行(例: 続き物の作品名の行)は話題が1つなので定型部分にしない
function Get-FeedTemplateLines($items) {
  $set = New-Object System.Collections.Generic.HashSet[string]([StringComparer]::Ordinal)
  if (@($items).Count -lt 3) { return , $set }
  $topics = New-Object 'System.Collections.Generic.Dictionary[string,System.Collections.Generic.HashSet[string]]'([StringComparer]::Ordinal)
  foreach ($it in $items) {
    $br = @(Get-StandaloneBrackets ([string]$it.title))
    $topic = if ($br.Count -gt 0) { Get-StandaloneLooseKey $br[0] } else { $k = Get-StandaloneLooseKey ([string]$it.title); $k.Substring(0, [Math]::Min(10, $k.Length)) }
    $seen = New-Object System.Collections.Generic.HashSet[string]([StringComparer]::Ordinal)
    foreach ($line in ([string]$it.description -split "`r?`n")) {
      $t = $line.Trim()
      if ($t.Length -lt 2 -or -not $seen.Add($t)) { continue }
      if (-not $topics.ContainsKey($t)) { $topics[$t] = New-Object System.Collections.Generic.HashSet[string]([StringComparer]::Ordinal) }
      [void]$topics[$t].Add($topic)
    }
  }
  foreach ($k in $topics.Keys) { if ($topics[$k].Count -ge 3) { [void]$set.Add($k) } }
  return , $set
}
function Remove-FeedTemplateLines([string]$description, $templateLines) {
  if (-not $description -or -not $templateLines -or $templateLines.Count -eq 0) { return $description }
  return ((([string]$description -split "`r?`n") | Where-Object { -not $templateLines.Contains($_.Trim()) }) -join "`n")
}

function Test-StandaloneRssXml([string]$text) {
  try {
    $d = New-Object System.Xml.XmlDocument; $d.XmlResolver = $null; $d.LoadXml($text)
    return ($d.DocumentElement -and $d.DocumentElement.LocalName -eq "feed" -and $d.DocumentElement.NamespaceURI -eq "http://www.w3.org/2005/Atom")
  } catch { return $false }
}

$feedFiles = @()
$apiUnits = New-Object System.Collections.Generic.List[object]   # API 方式で取得したチャンネル(RSS と同じ形の動画一覧)
$retryChannelIds = New-Object System.Collections.Generic.List[string]   # 次回に取り直すチャンネル(失敗・取得前に止めた取り直し分)
if ($fetchMode) {
  [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
  $stat.fetchTargets = 0; $stat.fetched = 0; $stat.fetchFailed = 0; $stat.retried = 0
  $stat.source = $Source
  if ($Source -eq "Api") { $stat.apiCalls = 0; $stat.maxApiCalls = $MaxApiCalls; $stat.apiPages = 0; $stat.apiResolvedUploads = 0; $stat.apiStopped = ""; $stat.fetchNotAttempted = 0 }
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
  if ($All) {
    # 対応表の並び順で、StartIndex から MaxChannels 件だけ巡回する(STREAMERS に無い名前・形式の正しくないIDは対象外)
    if (-not $ChannelMapPath -or -not (Test-Path $ChannelMapPath)) { throw "-All には対応表(streamer-channel-ids.json または -ChannelMapPath)が必要です。" }
    $knownForCrawl = New-Object System.Collections.Generic.HashSet[string]
    foreach ($s in $streamers) { [void]$knownForCrawl.Add($s.name) }
    $crawlRows = @(ConvertFrom-StandaloneJson ([IO.File]::ReadAllText($ChannelMapPath, [Text.Encoding]::UTF8)) | ForEach-Object { $_ } |
      Where-Object { $_.streamer -and $knownForCrawl.Contains([string]$_.streamer) -and ([string]$_.channelId -match '^UC[A-Za-z0-9_-]{22}$') })
    $stat.crawlTotal = $crawlRows.Count
    $stat.crawlStartIndex = $StartIndex
    # 前回取得できなかったチャンネル(-PriorityChannelId)を先に取得し、残りの枠で対応表の順に巡回する
    $prio = New-Object System.Collections.Generic.List[object]
    $prioSeen = New-Object System.Collections.Generic.HashSet[string]
    foreach ($prioId in $PriorityChannelId) {
      if ($prioId -notmatch '^UC[A-Za-z0-9_-]{22}$') { $errors.Add([pscustomobject]@{ channelId = $prioId; reason = "取り直すチャンネルIDの形式が正しくない"; stage = "fetch" }); continue }
      if (-not $channelToStreamer.ContainsKey($prioId)) { $errors.Add([pscustomobject]@{ channelId = $prioId; reason = "取り直すチャンネルが登録済みVTuberではない"; stage = "fetch" }); continue }
      if (-not $prioSeen.Add($prioId)) { continue }
      if ($prio.Count -ge $MaxChannels) { $retryChannelIds.Add($prioId); continue }   # 枠を超えた分は次回に回す
      $prio.Add([pscustomobject]@{ channelId = $prioId; streamer = $channelToStreamer[$prioId]; seq = $false })
    }
    foreach ($p in $prio) { $targets.Add($p) }
    $picked = @($crawlRows | Select-Object -Skip $StartIndex -First ([Math]::Max(0, $MaxChannels - $prio.Count)))
    foreach ($row in $picked) { $targets.Add([pscustomobject]@{ channelId = [string]$row.channelId; streamer = [string]$row.streamer; seq = $true }) }
    $stat.priorityTargets = $prio.Count
  }
  $seenTargets = New-Object System.Collections.Generic.HashSet[string]
  $first = $true
  $seqHandled = 0; $seqOpen = $true   # 巡回位置: 対応表の順のうち、実際に試したところまで進める(取得前に止めた分は次回に残す)
  foreach ($t in $targets) {
    if (-not $seenTargets.Add($t.channelId)) { if ($t.seq -and $seqOpen) { $seqHandled++ }; continue }   # 取り直しで取得済み
    if ($Source -eq "Api") {
      if (-not $channelToStreamer.ContainsKey($t.channelId)) { $errors.Add([pscustomobject]@{ channelId = $t.channelId; reason = "登録済みVTuberのチャンネルではない(対応付けできない)"; stage = "fetch" }); if ($t.seq -and $seqOpen) { $seqHandled++ }; continue }
      if ($apiState.stopped -or $apiState.calls -ge $MaxApiCalls) {
        # 取得前に止めた: 呼び出しはしない。取り直し分は次回の取り直しに、巡回分は巡回位置を進めずに残す
        if (-not $apiState.stopped) { $apiState.stopped = "limit" }
        $stat.fetchNotAttempted++; if ($t.seq) { $seqOpen = $false } else { $retryChannelIds.Add($t.channelId) }
        continue
      }
      $stat.fetchTargets++
      if (-not $first -and $RequestIntervalMs -gt 0) { Start-Sleep -Milliseconds $RequestIntervalMs }
      $first = $false
      $ar = Get-StandaloneApiUploads $t
      if (-not $ar.attempted) { $stat.fetchTargets--; $stat.fetchNotAttempted++; if ($t.seq) { $seqOpen = $false } else { $retryChannelIds.Add($t.channelId) }; continue }
      if ($t.seq -and $seqOpen) { $seqHandled++ }
      if ($ar.ok) {
        $stat.fetched++
        $apiUnits.Add([pscustomobject]@{ label = "api:" + $t.channelId; channelId = $t.channelId; entries = $ar.entries })
        if (@($ar.log).Count -gt 0) { $warnings.Add([pscustomobject]@{ channelId = $t.channelId; streamer = $t.streamer; reason = "途中で失敗したが取得できた(" + (@($ar.log) -join " → ") + ")"; attemptReasons = @($ar.log); attempts = $ar.calls; stage = "fetch" }) }
      } else {
        $stat.fetchFailed++; $retryChannelIds.Add($t.channelId)
        $errors.Add([pscustomobject]@{ channelId = $t.channelId; streamer = $t.streamer; reason = $ar.reason; status = $(if ($ar.status) { [int]$ar.status } else { $null }); apiReason = $ar.apiReason; attemptReasons = @($ar.log); attempts = $ar.calls; stage = "fetch" })
      }
      continue
    }
    $stat.fetchTargets++
    if ($t.seq -and $seqOpen) { $seqHandled++ }
    if (-not $first -and $RequestIntervalMs -gt 0) { Start-Sleep -Milliseconds $RequestIntervalMs }
    $first = $false
    $url = $FeedUrlTemplate -f $t.channelId
    $saved = $null; $reason = $null; $status = $null
    $attemptReasons = New-Object System.Collections.Generic.List[string]   # 失敗した試行ごとの理由(どのチャンネルがどう失敗したかを後から確認するため)
    for ($attempt = 1; $attempt -le 2; $attempt++) {
      if ($attempt -eq 2) { $stat.retried++; if ($RetryDelaySeconds -gt 0) { Start-Sleep -Seconds $RetryDelaySeconds } }
      $res = Invoke-StandaloneRssRequest $url $TimeoutSec
      $status = $res.status
      if (-not $res.ok) { $reason = [string]$res.reason; $attemptReasons.Add($reason); continue }
      if (-not (Test-StandaloneRssXml ([string]$res.content))) { $reason = "XMLとして読めない応答"; $attemptReasons.Add($reason); continue }
      $saved = Join-Path $FeedDir ($t.channelId + ".xml")
      [IO.File]::WriteAllText($saved, [string]$res.content, (New-Object System.Text.UTF8Encoding($false)))
      # 新着15本から外れた動画は、RSS 全体ではなく動画ごとの履歴(entries\<チャンネルID>.json)に残す(下の解析で記録)
      break
    }
    if ($saved) {
      $stat.fetched++
      $feedFiles += Get-Item -LiteralPath $saved
      if ($attempt -eq 2) { $warnings.Add([pscustomobject]@{ channelId = $t.channelId; streamer = $t.streamer; reason = "1回目の取得に失敗し、再試行で取得した(" + $reason + ")"; attemptReasons = $attemptReasons.ToArray(); attempts = 2; stage = "fetch" }) }
    } else {
      $stat.fetchFailed++; $retryChannelIds.Add($t.channelId)
      $errors.Add([pscustomobject]@{ channelId = $t.channelId; streamer = $t.streamer; reason = $reason; status = $(if ($status) { [int]$status } else { $null }); attemptReasons = $attemptReasons.ToArray(); attempts = 2; stage = "fetch" })
    }
  }
  if ($All) {
    $next = $StartIndex + $seqHandled
    $stat.crawlNextIndex = $(if ($next -ge $crawlRows.Count) { 0 } else { $next })   # 最後まで巡回したら次回は先頭から
  }
  if ($Source -eq "Api") {
    $stat.apiCalls = $apiState.calls; $stat.apiStopped = $apiState.stopped
    if ($apiState.stopped -eq "quota") { $warnings.Add([pscustomobject]@{ reason = "API の利用枠を超えたため、途中で取得をやめた(残りは次回)"; stage = "fetch" }) }
    elseif ($apiState.stopped -eq "limit") { $warnings.Add([pscustomobject]@{ reason = "API の呼び出しが上限($MaxApiCalls 回)に達したため、途中で取得をやめた(残りは次回)"; stage = "fetch" }) }
    elseif ($apiState.stopped -eq "fatal") { $errors.Add([pscustomobject]@{ reason = "API キーまたは権限のエラーのため取得をやめた(保存しないこと)"; stage = "fetch" }) }
  }
} elseif ($RejudgeOnly) {
  # 一括再判定: 以前の archive の XML も含めて古い順に読み、履歴に取り込む(判定は下でチャンネルごとの履歴を使う)
  $feedFiles = Get-StandaloneOrdinalSorted @(Get-ChildItem -Path $FeedDir -Filter *.xml -File -Recurse) { param($x, $y)
    $c = $x.LastWriteTimeUtc.CompareTo($y.LastWriteTimeUtc); if ($c -ne 0) { $c } else { [string]::CompareOrdinal($x.FullName, $y.FullName) } }
} else {
  $feedFiles = Get-StandaloneFilesByName @(Get-ChildItem -Path $FeedDir -Filter *.xml -File)
}

# RSS XML → @{ ok; reason; channelId; entries = 動画の配列(videoId / title / description / published) }
function Read-StandaloneFeedXml([string]$path) {
  try {
    $doc = New-Object System.Xml.XmlDocument
    $doc.XmlResolver = $null
    $doc.LoadXml([IO.File]::ReadAllText($path, [Text.Encoding]::UTF8))
  } catch { return @{ ok = $false; reason = "XMLとして読めない" } }
  $nsm = New-Object System.Xml.XmlNamespaceManager($doc.NameTable)
  foreach ($k in $ns.Keys) { $nsm.AddNamespace($k, $ns[$k]) }
  $feed = $doc.SelectSingleNode("/a:feed", $nsm)
  if (-not $feed) { return @{ ok = $false; reason = "YouTube RSS(Atom feed)ではない" } }
  $channelNode = $feed.SelectSingleNode("yt:channelId", $nsm)
  $cid = if ($channelNode) { $channelNode.InnerText.Trim() } else { "" }
  if ($cid -and $cid -notmatch '^UC') { $cid = "UC" + $cid }   # RSS の yt:channelId は UC を省くことがある
  if (-not $cid) { return @{ ok = $false; reason = "チャンネルIDが無い" } }
  $list = New-Object System.Collections.Generic.List[object]
  foreach ($e in @($feed.SelectNodes("a:entry", $nsm))) {
    $n = $e.SelectSingleNode("yt:videoId", $nsm); $vid = if ($n) { $n.InnerText.Trim() } else { "" }
    $n = $e.SelectSingleNode("a:title", $nsm); $title = if ($n) { $n.InnerText } else { "" }
    $n = $e.SelectSingleNode("media:group/media:description", $nsm); $desc = if ($n) { $n.InnerText } else { "" }
    $n = $e.SelectSingleNode("a:published", $nsm); $pub = if ($n) { $n.InnerText.Trim() } else { "" }
    $list.Add([pscustomobject]@{ videoId = $vid; title = $title; description = $desc; published = $pub })
  }
  return @{ ok = $true; channelId = $cid; entries = $list.ToArray() }
}

# ---- 動画ごとの履歴(-FeedDir\entries\<チャンネルID>.json)。削除はしない ----
$entriesDir = Join-Path $feedDirFull "entries"
$historyStores = @{}
function Get-HistoryStore([string]$cid) {
  if ($historyStores.ContainsKey($cid)) { return $historyStores[$cid] }
  $path = Join-Path $entriesDir ($cid + ".json")
  # apiFirstCrawledAt: このチャンネルの初回 API 巡回を終えた日時(RSS の履歴とは別の項目。空なら未実施)
  $h = @{ path = $path; list = (New-Object System.Collections.Generic.List[object]); byId = @{}; dirty = $false; broken = $false; added = 0; apiFirstCrawledAt = "" }
  if (Test-Path -LiteralPath $path) {
    try {
      $data = ConvertFrom-StandaloneJson ([IO.File]::ReadAllText($path, [Text.Encoding]::UTF8))
      if (-not $data -or [string]$data.channelId -ne $cid -or $null -eq $data.videos) { throw "履歴の形式ではない" }
      $h.apiFirstCrawledAt = [string]$data.apiFirstCrawledAt
      foreach ($v in @($data.videos)) {
        if ([string]$v.videoId -notmatch '^[A-Za-z0-9_-]{11}$') { throw "動画IDの正しくない項目がある" }
        if ($h.byId.ContainsKey([string]$v.videoId)) { continue }
        $h.list.Add($v); $h.byId[[string]$v.videoId] = $v
      }
    } catch {
      $h.broken = $true; $h.list.Clear(); $h.byId = @{}
      $errors.Add([pscustomobject]@{ file = "entries\" + $cid + ".json"; channelId = $cid; reason = "履歴JSONが読めないため、このチャンネルの履歴は更新しない(既存ファイルはそのまま): " + $_.Exception.Message; stage = "history" })
    }
  }
  $historyStores[$cid] = $h
  return $h
}
# 同じ動画IDは追加しない。検出日時($seenAt)が最終検出日時以降なら、タイトル・説明欄・公開日時と lastSeenAt を更新する
function Add-HistoryEntries($h, $items, [string]$seenAt) {
  if ($h.broken) { return }
  foreach ($x in $items) {
    $id = [string]$x.videoId
    if ($id -notmatch '^[A-Za-z0-9_-]{11}$') { continue }
    if ($h.byId.ContainsKey($id)) {
      $v = $h.byId[$id]
      if ([string]::CompareOrdinal([string]$v.firstSeenAt, $seenAt) -gt 0) { Set-ObjProp $v "firstSeenAt" $seenAt; $h.dirty = $true }   # 古い archive を後から取り込んだとき
      if ([string]::CompareOrdinal([string]$v.lastSeenAt, $seenAt) -le 0) {
        foreach ($f in @("title", "description", "published")) {
          if ([string]$v.$f -cne [string]$x.$f) { Set-ObjProp $v $f ([string]$x.$f); $h.dirty = $true }
        }
        if ([string]$v.lastSeenAt -ne $seenAt) { Set-ObjProp $v "lastSeenAt" $seenAt; $h.dirty = $true }
      }
    } else {
      $v = [pscustomobject][ordered]@{ videoId = $id; title = [string]$x.title; description = [string]$x.description; published = [string]$x.published; firstSeenAt = $seenAt; lastSeenAt = $seenAt }
      $h.list.Add($v); $h.byId[$id] = $v; $h.dirty = $true; $h.added++
    }
  }
}
function Save-HistoryStores {
  foreach ($cid in (Get-StandaloneOrdinalKeys $historyStores)) {
    $h = $historyStores[$cid]
    if (-not $h.broken) { $stat.historyVideos += $h.list.Count }
    if ($h.broken -or -not $h.dirty) { continue }
    try {
      if (-not (Test-Path -LiteralPath $entriesDir)) { New-Item -ItemType Directory -Path $entriesDir -Force | Out-Null }
      $videos = Get-StandaloneOrdinalSorted $h.list.ToArray() { param($x, $y)
        $c = [string]::CompareOrdinal([string]$y.published, [string]$x.published); if ($c -ne 0) { $c } else { [string]::CompareOrdinal([string]$x.videoId, [string]$y.videoId) } }
      $docMap = [ordered]@{ channelId = $cid; streamer = [string]$channelToStreamer[$cid]; updatedAt = $now }
      if ($h.apiFirstCrawledAt) { $docMap["apiFirstCrawledAt"] = $h.apiFirstCrawledAt }   # 一度記録したら消さない
      $docMap["videoCount"] = $videos.Count; $docMap["videos"] = $videos
      $doc = [pscustomobject]$docMap
      $tmp = $h.path + ".tmp"
      [IO.File]::WriteAllText($tmp, ($doc | ConvertTo-Json -Depth 4), (New-Object System.Text.UTF8Encoding($false)))
      if (Test-Path -LiteralPath $h.path) { [IO.File]::Replace($tmp, $h.path, $h.path + ".bak") } else { [IO.File]::Move($tmp, $h.path) }
      $stat.historyChannels++; $stat.historyAdded += $h.added
    } catch {
      $errors.Add([pscustomobject]@{ file = "entries\" + $cid + ".json"; channelId = $cid; reason = "履歴JSONを書き込めなかった(既存ファイルはそのまま): " + $_.Exception.Message; stage = "history" })
    }
  }
}

# ---- 判定する単位: 通常・取得は RSS 1件ずつ、一括再判定はチャンネルごとの履歴(同じ動画は1回だけ判定) ----
$feedUnits = New-Object System.Collections.Generic.List[object]
$rjXmlByChannel = @{}   # 一括再判定で履歴JSONが読めないチャンネルの代わり(読んだ RSS の内容。後のものが優先)
foreach ($file in $feedFiles) {
  $stat.feeds++
  $p = Read-StandaloneFeedXml $file.FullName
  if (-not $p.ok) { $errors.Add([pscustomobject]@{ file = $file.Name; reason = $p.reason }); continue }
  $cid = $p.channelId
  if (-not $channelToStreamer.ContainsKey($cid)) { $errors.Add([pscustomobject]@{ file = $file.Name; channelId = $cid; reason = "登録済みVTuberのチャンネルではない(対応付けできない)" }); continue }
  $stat.feedsRead++
  Add-HistoryEntries (Get-HistoryStore $cid) $p.entries (Get-StandaloneJstStamp $file.LastWriteTimeUtc)
  if ($RejudgeOnly) {
    if ($p.entries.Count -eq 0) { $warnings.Add([pscustomobject]@{ file = $file.Name; streamer = $channelToStreamer[$cid]; reason = "動画が1件も無い" }) }
    if (-not $rjXmlByChannel.ContainsKey($cid)) { $rjXmlByChannel[$cid] = [ordered]@{} }
    foreach ($x in $p.entries) { $rjXmlByChannel[$cid][[string]$x.videoId] = $x }
  } else {
    $feedUnits.Add([pscustomobject]@{ label = $file.Name; channelId = $cid; entries = $p.entries })
  }
}
# API 方式で取得したチャンネル: RSS と同じく履歴に記録してから、同じ判定に渡す(検出日時は今回の実行日時)
# 初回 API 巡回(-InitialMaxAgeDays。RSS の履歴の有無に関係なく、apiFirstCrawledAt の無いチャンネル):
#   公開から指定日数を超えた動画は候補にしない。履歴に記録し、candidateSkipped を付けて次回以降も候補にしない。
#   取得に失敗したチャンネルはここに来ないので記録しない。保存しなかったとき(検証で中止など)は履歴ごと残らないので、次回も初回として扱う
$initialSkipIds = New-Object System.Collections.Generic.HashSet[string]   # 履歴JSONが読めず印を付けられないときの代わり(今回だけ)
if ($InitialMaxAgeDays -gt 0) { $stat.initialApiChannels = 0; $stat.initialApiSkipped = 0; $stat.initialMaxAgeDays = $InitialMaxAgeDays }
$stat.skippedByHistoryMark = 0
$initialCutoff = [DateTimeOffset]::UtcNow.AddDays(-$InitialMaxAgeDays)
foreach ($au in $apiUnits) {
  $stat.feeds++; $stat.feedsRead++
  $h = Get-HistoryStore $au.channelId
  Add-HistoryEntries $h $au.entries $now
  if ($InitialMaxAgeDays -gt 0 -and -not $h.apiFirstCrawledAt) {
    $stat.initialApiChannels++
    foreach ($x in $au.entries) {
      $vid = [string]$x.videoId
      if ($standaloneVideoIds.Contains($vid) -or $byVideo.ContainsKey($vid) -or $unknownVideoIds.Contains($vid)) { continue }   # 既存の候補・登録済みは従来どおり
      $pub = $null; try { $pub = [DateTimeOffset]::Parse([string]$x.published, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal) } catch { $pub = $null }
      if ($null -eq $pub -or $pub -ge $initialCutoff) { continue }   # 公開日が読めない・指定日数以内は従来どおり判定する
      $stat.initialApiSkipped++
      if ($h.broken) { [void]$initialSkipIds.Add($vid); continue }
      $hv = $h.byId[$vid]
      if ($hv -and -not [string]$hv.candidateSkipped) { Set-ObjProp $hv "candidateSkipped" "initial-api-older-than-$($InitialMaxAgeDays)d"; Set-ObjProp $hv "candidateSkippedAt" $now; $h.dirty = $true }
    }
    if (-not $h.broken) { $h.apiFirstCrawledAt = $now; $h.dirty = $true }
  }
  $feedUnits.Add($au)
}
if ($RejudgeOnly) {
  if (Test-Path -LiteralPath $entriesDir) {
    foreach ($jf in (Get-StandaloneFilesByName @(Get-ChildItem -LiteralPath $entriesDir -Filter *.json -File))) {
      if ($jf.BaseName -match '^UC[A-Za-z0-9_-]{22}$' -and $channelToStreamer.ContainsKey($jf.BaseName)) { [void](Get-HistoryStore $jf.BaseName) }
    }
  }
  foreach ($cid in (Get-StandaloneOrdinalKeys $historyStores)) {
    $h = $historyStores[$cid]
    $list =New-Object System.Collections.Generic.List[object]
    if (-not $h.broken) { foreach ($v in $h.list) { $list.Add($v) } }
    elseif ($rjXmlByChannel.ContainsKey($cid)) { foreach ($v in $rjXmlByChannel[$cid].Values) { $list.Add($v) } }
    if ($list.Count -eq 0) { continue }
    $feedUnits.Add([pscustomobject]@{ label = "entries\" + $cid + ".json"; channelId = $cid; entries = $list.ToArray() })
  }
}

foreach ($unit in $feedUnits) {
  $feedLabel = $unit.label
  $feedChannelId = $unit.channelId
  $feedStreamer = $channelToStreamer[$feedChannelId]
  $entries = $unit.entries
  if ($entries.Count -eq 0) { $warnings.Add([pscustomobject]@{ file = $feedLabel; streamer = $feedStreamer; reason = "動画が1件も無い" }); continue }
  # 説明欄の定型部分(告知欄など): このRSS(一括再判定では履歴)で話題の違う3本以上の動画の説明欄に同じ行があれば、照合に使わない
  $templateLines = Get-FeedTemplateLines $entries
  if ($templateLines.Count -gt 0) { $stat.templateLines += $templateLines.Count }

  foreach ($e in $entries) {
    $stat.entries++
    $videoId = [string]$e.videoId
    if ($videoId -notmatch '^[A-Za-z0-9_-]{11}$') { $warnings.Add([pscustomobject]@{ file = $feedLabel; streamer = $feedStreamer; reason = "動画IDが読めない項目を飛ばした" }); continue }
    if ($standaloneVideoIds.Contains($videoId)) { $stat.registeredStandalone++; continue }
    # 既存の候補: 人が確認した(status が pending 以外)ものは判定を変えない。pending のものは今のロジックで判定し直す
    $existingCand = if ($byVideo.ContainsKey($videoId)) { $byVideo[$videoId] } else { $null }
    if ($existingCand) { $stat.alreadyCandidate++; Set-ObjProp $existingCand "lastSeenAt" $now }
    if ($existingCand -and [string]$existingCand.status -ne "pending") { continue }
    # 初回 API 巡回で候補にしなかった古い動画(履歴の candidateSkipped)は、次回以降も候補にしない(既存の候補は従来どおり)
    if (-not $existingCand -and -not $unknownVideoIds.Contains($videoId)) {
      $hsk = if ($historyStores.ContainsKey($feedChannelId)) { $historyStores[$feedChannelId] } else { $null }
      $hvk = if ($hsk -and $hsk.byId.ContainsKey($videoId)) { $hsk.byId[$videoId] } else { $null }
      if ($initialSkipIds.Contains($videoId) -or ($hvk -and [string]$hvk.candidateSkipped)) { $stat.skippedByHistoryMark++; continue }
    }
    # 一括再判定: 新しい動画は候補に追加しない(未登録作品名が「2人以上の配信者に出てくる」かの証拠としてだけ数える)
    $rjNewVideo = $false
    if ($RejudgeOnly) {
      [void]$rjSeenIds.Add($videoId)
      if (-not $existingCand -and -not $unknownVideoIds.Contains($videoId)) { $rjNewVideo = $true; $stat.rejudgeSkippedNew++ }
    }

    $title = [string]$e.title
    $description = Remove-FeedTemplateLines ([string]$e.description) $templateLines
    $published = [string]$e.published
    $publishedDate = ""
    if ($published) { try { $publishedDate = ConvertTo-JstDateText $published } catch { $publishedDate = "" } }

    $pairKey = $feedStreamer
    $hasGamePlaylist = { param($gameName) $siteGamePairs.Contains($pairKey + "`t" + $gameName) }.GetNewClosure()
    $m = Get-StandaloneMatch $gameIndex $title $description @{ siteHasGamePlaylist = $hasGamePlaylist }
    $inUnknown = $unknownVideoIds.Contains($videoId)   # 未登録作品の候補に記録済みの動画(pending の作品名は判定し直す)
    if (-not $m) {
      $stat.noGame++
      # 既存作品の候補(pending)だったが、今のロジックでは一致しない → 削除せず印を付ける
      if ($existingCand) {
        [void]$rjIds.Add($videoId)
        if ([string]$existingCand.reviewGroup -ne "rejudged-not-matched") {   # 前回までに印を付けたものは数え直さない
          $prevGame = [string]$existingCand.game
          Set-ObjProp $existingCand "confidence" "NONE"
          Set-ObjProp $existingCand "reviewGroup" "rejudged-not-matched"
          Set-ObjProp $existingCand "reasons" @("再判定で既存作品に一致しなくなった(前回の判定: $prevGame)")
          Set-ObjProp $existingCand "rejudgedAt" $now
          [void]$rjChangedIds.Add($videoId); [void]$rjNotMatchedIds.Add($videoId)
        }
      }
      # 既存作品に一致しない動画から、未登録作品の候補を取り出す(作品マスタには登録しない)
      # 関数は配列を1つの値として返す(, $out)ので、@() で包まずに変数で受ける(0件のとき空配列が1件として数えられるのを防ぐ)
      $unknownCands = Get-StandaloneUnknownGameCandidates $gameIndex $title $description -IncludeWeak
      if ($rjNewVideo) {
        foreach ($u in $unknownCands) { if ($u -and $u.key) { if (-not $rjEvidence.ContainsKey($u.key)) { $rjEvidence[$u.key] = New-Object System.Collections.Generic.HashSet[string] }; [void]$rjEvidence[$u.key].Add($feedStreamer) } }
        continue
      }
      if ($inUnknown) { Update-UnknownVideoJudgement $videoId $unknownCands }
      $added = $false
      foreach ($u in $unknownCands) {
        if (-not $u -or -not $u.key) { continue }
        $uv = [pscustomobject]@{
          videoId = $videoId; url = ("https://www.youtube.com/watch?v=" + $videoId)
          streamer = $feedStreamer; channelId = $feedChannelId; title = $title; publishedDate = $publishedDate
          source = $u.source; confidence = $u.confidence; reasons = @($u.reasons); firstSeenAt = $now; rejudged = ""
        }
        # ゲームを表す語が無い名前は、全RSSを読み終えてから「2人以上の配信者に出てくる」ときだけ候補にする
        if ($u.weak) {
          if (-not $weakUnknown.ContainsKey($u.key)) { $weakUnknown[$u.key] = New-Object System.Collections.Generic.List[object] }
          $weakUnknown[$u.key].Add([pscustomobject]@{ cand = $u; video = $uv })
          continue
        }
        if (-not $RejudgeOnly -and (Add-UnknownGameVideo $u $uv)) { $added = $true; $stat.unknownGameVideoRows++ }   # 作品別の延べ件数(1本が複数の作品名に入ることがある)
      }
      if ($added) { [void]$unknownVideoIds.Add($videoId); $stat.unknownGameVideos++ }   # 動画の実数
      continue
    }
    # 既存作品に一致した: 未登録作品の候補に記録済みなら、その作品名からは外れたことを記録する
    if ($inUnknown) { Update-UnknownVideoJudgement $videoId @() }
    if ($rjNewVideo) { continue }   # 一括再判定では新しい動画を候補に追加しない
    $reasons = @($m.reasons)
    if (-not $publishedDate) { $reasons += "公開日時が読めない" }
    # 同じVTuber×ゲームの再生リストが登録済みで連番の動画は、その再生リストに入っている可能性が高い。
    # 収録は API を使わないと確認できないので、削除せず確認待ちのまま別グループに分ける
    $siteHas = [bool](& $hasGamePlaylist $m.game)
    $likelyInPlaylist = $siteHas -and (Test-StandaloneSequel $title)
    if ($likelyInPlaylist) { $reasons += "登録済み再生リストに収録されている可能性が高い(連番・収録は未確認)"; $stat.likelyInSitePlaylist++ }
    # 自動判定で付ける項目(再判定ではこれだけを書き換える)
    $judged = [ordered]@{
      game = $m.game; confidence = $m.confidence; matchType = $m.matchType; matchedAlias = $m.matchedAlias
      reasons = @($reasons); otherGames = @($m.otherGames)
      likelyNonGame = (@($m.reasons | Where-Object { $_ -like '非ゲーム語*' }).Count -gt 0)
      siteHasGamePlaylist = $siteHas
      playlistVideoCheck = "unverified"   # 登録済み再生リストの中身は API を使わないと確認できない
      reviewGroup = $(if ($likelyInPlaylist) { "likely-in-site-playlist" } else { "new-standalone" })
    }
    if ($existingCand) {
      # 確認待ちの既存候補を判定し直す(動画ID・配信者・タイトル・公開日・初回検出日時・status は変えない)
      $before = ([string]$existingCand.game) + "|" + ([string]$existingCand.confidence) + "|" + ([string]$existingCand.reviewGroup) + "|" + (@($existingCand.reasons) -join ";")
      foreach ($k in $judged.Keys) { Set-ObjProp $existingCand $k $judged[$k] }
      $after = ([string]$existingCand.game) + "|" + ([string]$existingCand.confidence) + "|" + ([string]$existingCand.reviewGroup) + "|" + (@($existingCand.reasons) -join ";")
      [void]$rjIds.Add($videoId)
      if ($before -ne $after) { [void]$rjChangedIds.Add($videoId); Set-ObjProp $existingCand "rejudgedAt" $now }
      continue
    }
    $c = [pscustomobject]@{
      videoId = $videoId; url = ("https://www.youtube.com/watch?v=" + $videoId)
      streamer = $feedStreamer; channelId = $feedChannelId
      title = $title; publishedAt = $published; publishedDate = $publishedDate
    }
    foreach ($k in $judged.Keys) { $c | Add-Member -NotePropertyName $k -NotePropertyValue $judged[$k] }
    $c | Add-Member -NotePropertyName status -NotePropertyValue "pending"   # 登録データへの反映は人が承認してから
    $c | Add-Member -NotePropertyName source -NotePropertyValue "rss"
    $c | Add-Member -NotePropertyName firstSeenAt -NotePropertyValue $now
    $c | Add-Member -NotePropertyName lastSeenAt -NotePropertyValue $now
    $candidates.Add($c); $byVideo[$videoId] = $c; $stat.newCandidates++
  }
}

# ---- ゲームを表す語が無い未登録作品名: 2人以上の配信者に出てくるものだけ候補にする(既存の候補の配信者も数える) ----
foreach ($key in @($weakUnknown.Keys)) {
  $items = $weakUnknown[$key].ToArray()   # List を @() で包むと Windows PowerShell 5.1 で例外になるため ToArray() を使う
  $who = New-Object System.Collections.Generic.HashSet[string]
  foreach ($it in $items) { [void]$who.Add([string]$it.video.streamer) }
  if ($unknownByKey.ContainsKey($key)) { foreach ($s in @($unknownByKey[$key].streamers)) { if ($s) { [void]$who.Add([string]$s) } } }
  if ($rjEvidence.ContainsKey($key)) { foreach ($s in $rjEvidence[$key]) { [void]$who.Add([string]$s) } }   # 一括再判定で読んだ新しい動画の配信者
  if ($who.Count -lt 2) { continue }
  foreach ($it in $items) {
    $it.video.reasons = @(@($it.video.reasons) + "2人以上の配信者のタイトルに出てくる")
    # 再判定でいったん外した記録済みの動画は、元に戻す
    if ($unknownByKey.ContainsKey($key) -and [string]$unknownByKey[$key].status -eq "pending") {
      $g = $unknownByKey[$key]
      $v = @($g.videos | Where-Object { $_.videoId -eq $it.video.videoId }) | Select-Object -First 1
      if ($v) {
        if ([string]$v.rejudged -eq "not-candidate") {
          Set-ObjProp $v "rejudged" ""; Set-ObjProp $v "confidence" $it.video.confidence; Set-ObjProp $v "reasons" @($it.video.reasons)
          $stat.unknownRejudgedNotCandidate--
          Update-UnknownGroupSummary $g
        }
        continue
      }
    }
    # 同じ作品名に記録済みの動画は Add-UnknownGameVideo が二重に追加しない
    if ($RejudgeOnly) { continue }   # 一括再判定では新しい動画を加えない
    if (Add-UnknownGameVideo $it.cand $it.video) {
      $stat.unknownGameVideoRows++
      if ($unknownVideoIds.Add([string]$it.video.videoId)) { $stat.unknownGameVideos++ }
    }
  }
}

# ---- 動画ごとの履歴を書き出す(変更のあったチャンネルだけ。読めなかった履歴JSONは上書きしない) ----
Save-HistoryStores

# ---- 再判定の件数(動画ごと)。一括再判定では、履歴にも RSS にも見つからない確認待ちの候補も数える ----
$stat.rejudged = $rjIds.Count; $stat.rejudgeChanged = $rjChangedIds.Count; $stat.rejudgeNotMatched = $rjNotMatchedIds.Count
$pendingIds = @($candidates | Where-Object { [string]$_.status -eq "pending" } | ForEach-Object { [string]$_.videoId })
if ($RejudgeOnly) { $stat.rejudgeNotInRss = @($pendingIds | Where-Object { -not $rjSeenIds.Contains($_) }).Count }

# ---- 確認分類(確認用の情報を追加するだけ。判定・履歴・保存条件は変えない) ----
#   reviewCategory: non-gameplay(タイトルにショート・切り抜き等の明確な表現) / playlist-review(登録済み再生リストに入っている可能性)
#                   / series(同じVTuber×作品の確認待ち候補が2本以上 = multi 候補) / single(単発実況候補)
#   seriesKey・seriesCount: series のまとまり(VTuber|作品)と本数。episodeMarker: #5・DAY9・最終回 などの番号表現(除外には使わない)
#   人が確認した候補(status が pending 以外)と、既存作品に一致しなくなった候補(rejudged-not-matched)は分類しない
$script:StandaloneNonGameplayTitlePattern = '(?i)#shorts|(?<![a-z])shorts(?![a-z])|切り抜き|切抜き|歌ってみた|(?<![a-z])covered?(?![a-z])|(?<![a-z])mv(?![a-z])|music\s*video|original\s*song|同時視聴'
function Test-StandaloneEpisodeMarker([string]$title) {
  return ((Test-StandaloneSequel $title) -or ([string]$title -match '最終回|\d+\s*日目|[前中後]編|続き'))
}
function Get-StandaloneReviewCategory($c) {
  if ([string]$c.title -match $script:StandaloneNonGameplayTitlePattern) { return "non-gameplay" }
  if ([string]$c.reviewGroup -eq "likely-in-site-playlist") { return "playlist-review" }
  return ""   # series か single かは、同じVTuber×作品の本数で決める
}
function Update-StandaloneReviewCategories($list) {
  $targets = @($list | Where-Object { [string]$_.status -eq "pending" -and [string]$_.reviewGroup -ne "rejudged-not-matched" -and $_.game })
  $pairCount = @{}
  foreach ($c in $targets) {
    $cat = Get-StandaloneReviewCategory $c
    Set-ObjProp $c "reviewCategory" $cat
    Set-ObjProp $c "episodeMarker" (Test-StandaloneEpisodeMarker ([string]$c.title))
    if (-not $cat) { $k = [string]$c.streamer + "|" + [string]$c.game; $pairCount[$k] = 1 + [int]$pairCount[$k] }
  }
  foreach ($c in $targets) {
    if ([string]$c.reviewCategory) { Set-ObjProp $c "seriesKey" ""; Set-ObjProp $c "seriesCount" 0; continue }
    $k = [string]$c.streamer + "|" + [string]$c.game
    if ($pairCount[$k] -ge 2) { Set-ObjProp $c "reviewCategory" "series"; Set-ObjProp $c "seriesKey" $k; Set-ObjProp $c "seriesCount" $pairCount[$k] }
    else { Set-ObjProp $c "reviewCategory" "single"; Set-ObjProp $c "seriesKey" ""; Set-ObjProp $c "seriesCount" 1 }
  }
  $byCat = [ordered]@{ single = 0; series = 0; "playlist-review" = 0; "non-gameplay" = 0 }
  foreach ($c in $targets) { $byCat[[string]$c.reviewCategory]++ }
  $stat.reviewSingle = $byCat["single"]; $stat.reviewSeriesVideos = $byCat["series"]
  $stat.reviewSeriesGroups = @($targets | Where-Object { $_.reviewCategory -eq "series" } | ForEach-Object { $_.seriesKey } | Sort-Object -Unique).Count
  $stat.reviewPlaylist = $byCat["playlist-review"]; $stat.reviewNonGameplay = $byCat["non-gameplay"]; $stat.reviewCategorized = $targets.Count
}
Update-StandaloneReviewCategories $candidates.ToArray()

# ---- 書き出し(一時ファイル → 置き換え) ----
$result = [pscustomobject]@{
  generatedAt = $now
  source = "youtube-channel-rss"
  note = "自動判定結果です(status=pending)。登録前に動画内容・再生リスト状況・single/multi を人が確認してください。playlistVideoCheck=unverified は、サイト登録済み再生リストに含まれるかを確認していないことを表します。"
  # List を @() で包むと Windows PowerShell 5.1 では空のときに "Argument types do not match" になるため ToArray() を使う
  # retryChannelIds: 次回に先に取り直すチャンネル(取得に失敗したもの・取得前に止めた取り直し分。成功したものは入れない)
  lastRun = [pscustomobject]@{ stats = [pscustomobject]$stat; errors = $errors.ToArray(); warnings = $warnings.ToArray(); retryChannelIds = [string[]]@($retryChannelIds | Select-Object -Unique) }
  candidates = Get-StandaloneOrdinalSorted $candidates.ToArray() { param($x, $y)
    $c = [string]::CompareOrdinal([string]$y.publishedAt, [string]$x.publishedAt); if ($c -ne 0) { $c } else { [string]::CompareOrdinal([string]$x.videoId, [string]$y.videoId) } }
  # 作品マスタに無い作品の候補(すべて status=pending。登録するかは人が判断する)
  unknownGames = Get-StandaloneOrdinalSorted $unknownGames.ToArray() { param($x, $y)
    $c = ([int]$y.videoCount).CompareTo([int]$x.videoCount); if ($c -ne 0) { $c } else { [string]::CompareOrdinal([string]$x.key, [string]$y.key) } }
}
$tmp = $outPath + ".tmp"
[IO.File]::WriteAllText($tmp, ($result | ConvertTo-Json -Depth 8), (New-Object System.Text.UTF8Encoding($false)))
Move-Item -LiteralPath $tmp -Destination $outPath -Force

if ($fetchMode) {
  $crawlInfo = $(if ($All) { "  (対応表 $($stat.crawlTotal) 件の $($StartIndex) 番目から。次回の開始位置 $($stat.crawlNextIndex))" } else { "" })
  Write-Output ("巡回: 対象 $($stat.fetchTargets) チャンネル / 成功 $($stat.fetched) / 失敗 $($stat.fetchFailed)(再試行 $($stat.retried))  新規候補 $($stat.newCandidates) / 未登録作品の候補 $($stat.unknownGameVideos) 本" + $crawlInfo)
  if ($InitialMaxAgeDays -gt 0) {
    Write-Output ("初回 API 巡回: $($stat.initialApiChannels) チャンネル・公開から $InitialMaxAgeDays 日を超えた $($stat.initialApiSkipped) 本は候補にせず履歴に記録  (履歴の印で候補にしなかった動画 $($stat.skippedByHistoryMark) 本)")
  }
  if ($Source -eq "Api") {
    Write-Output ("API: 呼び出し $($stat.apiCalls) 回(上限 $MaxApiCalls)・読んだページ $($stat.apiPages)・再生リストを調べ直した $($stat.apiResolvedUploads) チャンネル・取得前に止めた $($stat.fetchNotAttempted) チャンネル" + $(if ($stat.apiStopped) { "  停止: $($stat.apiStopped)" } else { "" }) + "  次回に取り直す $(@($retryChannelIds | Select-Object -Unique).Count) チャンネル")
  }
}
Write-Output ("完了: $outPath  RSS $($stat.feeds) 件(読めた $($stat.feedsRead))・動画 $($stat.entries) 本 → 新規候補 $($stat.newCandidates) / 検出済み $($stat.alreadyCandidate) / 登録済み単発 $($stat.registeredStandalone) / ゲーム不明 $($stat.noGame)(うち未登録作品の候補 $($stat.unknownGameVideos) 本・作品別の延べ $($stat.unknownGameVideoRows))  候補合計 $($candidates.Count)・未登録作品の候補 $($unknownGames.Count) 作品")
if ($RejudgeOnly) {
  Write-Output ("一括再判定: 確認待ちの候補 $($pendingIds.Count) 件のうち履歴・RSS にあった $($pendingIds.Count - $stat.rejudgeNotInRss) 件を判定し直した(見つからない $($stat.rejudgeNotInRss) 件はそのまま)。新しい動画 $($stat.rejudgeSkippedNew) 本は追加していない")
}
Write-Output ("確認分類(確認待ち $($stat.reviewCategorized) 件): 単発 $($stat.reviewSingle) / 続き物 $($stat.reviewSeriesGroups) 組・$($stat.reviewSeriesVideos) 本 / 再生リスト確認 $($stat.reviewPlaylist) / ゲーム実況以外 $($stat.reviewNonGameplay)")
Write-Output ("履歴: 更新 $($stat.historyChannels) チャンネル・新しく記録した動画 $($stat.historyAdded) 本(読み込んだ履歴の動画 合計 $($stat.historyVideos) 本)")
if ($stat.rejudged -gt 0 -or $stat.unknownRejudgedNotCandidate -gt 0) {
  Write-Output ("再判定: 確認待ちの既存候補 $($stat.rejudged) 件(変更 $($stat.rejudgeChanged)・既存作品に一致しなくなった $($stat.rejudgeNotMatched))・未登録作品の候補から外れた動画 $($stat.unknownRejudgedNotCandidate) 本")
}
# 項目の見出し: ファイル名が無いもの(RSS の取得など)は「VTuber名(チャンネルID)」で示す。公開のチャンネル情報だけを出す(URL・認証情報は出さない)
function Get-IssueLabel($x) {
  if ($x.file) { return [string]$x.file }
  $id = [string]$x.channelId; $name = [string]$x.streamer
  if ($name -and $id) { return "$name($id)" } elseif ($id) { return $id } else { return $name }
}
if ($errors.Count -gt 0) { Write-Output ("エラー $($errors.Count) 件: " + (($errors | ForEach-Object { "$(Get-IssueLabel $_)=$($_.reason)" }) -join " / ")) }
if ($warnings.Count -gt 0) { Write-Output ("警告 $($warnings.Count) 件: " + (($warnings | ForEach-Object { "$(Get-IssueLabel $_)=$($_.reason)" }) -join " / ")) }
# RSS の取得に失敗したチャンネル(1チャンネル1行)
foreach ($x in @($errors | Where-Object { $_.stage -eq "fetch" -and $_.channelId -and $_.attempts })) {
  Write-Output ("取得失敗: $(Get-IssueLabel $x)  $($x.reason)  試行 $($x.attempts) 回(" + (@($x.attemptReasons) -join " → ") + ")")
}
# API キー・権限のエラーで止めたときは終了コード 3(ワークフローは保存しない)。利用枠の超過・上限到達は取得できた分を残して 0
if ($Source -eq "Api" -and $apiState.stopped -eq "fatal") { exit 3 }
