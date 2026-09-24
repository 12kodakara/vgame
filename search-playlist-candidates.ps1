<#
.SYNOPSIS
  第15段階で選定済みの15ゲームだけを対象に、YouTube Data API v3(search.list)で
  再生リスト候補を探索し、既存データと照合してFalse Positiveを除外、
  confidence(HIGH/MEDIUM/LOW)を付けて人間確認用の一覧を出力します。

.DESCRIPTION
  data-playlists.js / data-core.js は一切書き換えません。productionへの
  自動投入は行いません。

  APIキーは環境変数 YOUTUBE_API_KEY からのみ取得し、コンソール・ログ・
  出力ファイルのいずれにも表示・保存しません。エラーメッセージに含まれる
  可能性がある場合は必ず伏せ字にしてから表示します。

  1ゲームにつき search.list を1回だけ呼び出します(ページング無し、
  maxResults既定10件)。15ゲーム分=最大15回のsearch.list呼び出し
  (search.listは1回100 quota unit)。既存playlistとの重複・
  ゲーム名/別名の一致・チャンネルが既知VTuberかどうか・切り抜き等の
  キーワードを確認し、確信が持てないものは自動的に採用せずLOW扱いにします。

.PARAMETER MaxResultsPerGame
  1ゲームあたりの検索結果件数上限(既定10、最大でも安全のため25までに制限)。

.PARAMETER Json
  候補一覧の出力先(既定 reports/api-search-candidates.json)。

.EXAMPLE
  .\search-playlist-candidates.ps1
#>
param(
  [int]$MaxResultsPerGame = 10,
  [string]$Json = "reports/api-search-candidates.json"
)

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$corePath = Join-Path $scriptDir "data-core.js"
$playlistsPath = Join-Path $scriptDir "data-playlists.js"

if ($MaxResultsPerGame -gt 25) { $MaxResultsPerGame = 25 }

# ---- 第15段階で選定済みの15ゲームのみ(追加・変更しない) ----
$targetGames = @(
  "ペルソナシリーズ",
  "ポケットモンスター X・Y",
  "ポケットモンスター サン・ムーン",
  "ポケットモンスター 赤・緑",
  "大逆転裁判 成歩堂龍ノ介の冒険",
  "大逆転裁判2 成歩堂龍ノ介の覚悟",
  "龍が如く2",
  "Wii Music",
  "スターフォックス",
  "ナビつき！ つくって、送って、ドライブ",
  "ファイアーエムブレム 蒼炎の軌跡",
  "ファイアーエムブレム 紋章の謎",
  "ルイージマンション2",
  "街へいこうよ どうぶつの森",
  "大乱闘スマッシュブラザーズ"
)

$apiKey = $env:YOUTUBE_API_KEY
if (-not $apiKey) {
  Write-Error "YOUTUBE_API_KEY が環境変数に見つかりません。値を直接指定することはせず、環境変数を設定してから再実行してください。"
  exit 1
}

function Get-RedactedMessage([string]$msg) {
  if ($apiKey -and $msg) { return $msg -replace [regex]::Escape($apiKey), "***REDACTED***" }
  return $msg
}

# ---- パーサ(既存スクリプトと同じ手法) ----
function Get-ArrayInner([string]$name, [string]$text) {
  $marker = "const $name = ["
  $start = $text.IndexOf($marker)
  if ($start -lt 0) { return $null }
  $i = $start + $marker.Length
  $depth = 1; $inString = $false; $escape = $false
  for ($p = $i; $p -lt $text.Length; $p++) {
    $ch = $text[$p]
    if ($inString) {
      if ($escape) { $escape = $false; continue }
      if ($ch -eq '\') { $escape = $true; continue }
      if ($ch -eq '"') { $inString = $false }
      continue
    }
    if ($ch -eq '"') { $inString = $true; continue }
    if ($ch -eq '/' -and $p + 1 -lt $text.Length -and $text[$p + 1] -eq '/') {
      while ($p -lt $text.Length -and $text[$p] -ne "`n") { $p++ }
      continue
    }
    if ($ch -eq '[') { $depth++ }
    elseif ($ch -eq ']') {
      $depth--
      if ($depth -eq 0) { return $text.Substring($i, $p - $i) }
    }
  }
  throw "$name 配列の終端が見つかりません。"
}

function Get-Objects([string]$inner) {
  $results = @(); $depth = 0; $start = -1; $inString = $false; $escape = $false
  for ($i = 0; $i -lt $inner.Length; $i++) {
    $ch = $inner[$i]
    if ($inString) {
      if ($escape) { $escape = $false; continue }
      if ($ch -eq '\') { $escape = $true; continue }
      if ($ch -eq '"') { $inString = $false }
      continue
    }
    if ($ch -eq '"') { $inString = $true; continue }
    if ($ch -eq '{') { if ($depth -eq 0) { $start = $i }; $depth++ }
    elseif ($ch -eq '}') { $depth--; if ($depth -eq 0 -and $start -ge 0) { $results += $inner.Substring($start, $i - $start + 1); $start = -1 } }
  }
  return $results
}

function Field([string]$obj, [string]$name) {
  $m = [regex]::Match($obj, [regex]::Escape($name) + '\s*:\s*"((?:\\.|[^"])*)"')
  if ($m.Success) { return ($m.Groups[1].Value -replace '\\"', '"' -replace '\\\\', '\') }
  return ""
}

function FieldArray([string]$obj, [string]$name) {
  $m = [regex]::Match($obj, [regex]::Escape($name) + '\s*:\s*\[([^\]]*)\]')
  if (-not $m.Success) { return @() }
  return @([regex]::Matches($m.Groups[1].Value, '"((?:\\.|[^"])*)"') | ForEach-Object { $_.Groups[1].Value })
}

function ConvertTo-Hiragana([string]$s) {
  $sb = New-Object System.Text.StringBuilder
  foreach ($ch in $s.ToCharArray()) {
    if ($ch -ge [char]0x30A1 -and $ch -le [char]0x30F6) { [void]$sb.Append([char]([int]$ch - 0x60)) } else { [void]$sb.Append($ch) }
  }
  return $sb.ToString()
}
function Normalize-Text([string]$s) {
  if (-not $s) { return "" }
  return (ConvertTo-Hiragana ($s.Normalize([System.Text.NormalizationForm]::FormKC))).ToLowerInvariant().Trim()
}

$nonGameKeywords = @("切り抜き", "きりぬき", "まとめ", "shorts", "ショート", "pv", "トレーラー", "trailer", "体験版", "デモ版", "宣伝", "告知", "予告", "cm")

# ---- 既存データ読み込み(読み取り専用) ----
$coreText = [System.IO.File]::ReadAllText($corePath, [System.Text.Encoding]::UTF8)
$playlistsText = [System.IO.File]::ReadAllText($playlistsPath, [System.Text.Encoding]::UTF8)
$gameObjs = Get-Objects (Get-ArrayInner "GAMES" $coreText)
$streamerObjs = Get-Objects (Get-ArrayInner "STREAMERS" $coreText)
$playlistObjs = Get-Objects (Get-ArrayInner "PLAYLISTS" $playlistsText)

$existingPlaylistIds = @{}
foreach ($o in $playlistObjs) { $v = Field $o "playlistId"; if ($v) { $existingPlaylistIds[$v] = $true } }

$gameInfo = @{}
foreach ($o in $gameObjs) {
  $name = Field $o "name"
  if (-not $name) { continue }
  $gameInfo[$name] = [PSCustomObject]@{
    name       = $name
    series     = Field $o "series"
    aliases    = @(FieldArray $o "aliases")
    isUmbrella = ($name -eq (Field $o "series"))
  }
}

# 既知VTuberチャンネルの検証用(無料でできる範囲): channel/UCxxx形式は直接ID比較、
# @handle形式は名前の正規化一致で近似確認する(追加のAPI呼び出しはしない=quota節約)。
$knownChannelIds = @{}
$knownStreamerNormNames = @{}
foreach ($o in $streamerObjs) {
  $name = Field $o "name"
  $yt = Field $o "youtube"
  if ($name) { $knownStreamerNormNames[(Normalize-Text $name)] = $name }
  if ($yt -match '/channel/(UC[A-Za-z0-9_-]+)') { $knownChannelIds[$Matches[1]] = $name }
}

# ---- API呼び出し(ゲームごとに1回だけ。ページングなし) ----
$allItems = New-Object System.Collections.Generic.List[object]
$gamesSearched = 0
$gamesFailed = New-Object System.Collections.Generic.List[string]
$stopAll = $false

foreach ($game in $targetGames) {
  if ($stopAll) { break }
  $query = "$game 実況"
  $url = "https://www.googleapis.com/youtube/v3/search?part=snippet&type=playlist&maxResults=$MaxResultsPerGame&relevanceLanguage=ja&q=" + [uri]::EscapeDataString($query) + "&key=$apiKey"
  try {
    $resp = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop
    $gamesSearched++
    foreach ($item in $resp.items) {
      $allItems.Add([PSCustomObject]@{
        targetGame  = $game
        playlistId  = $item.id.playlistId
        title       = $item.snippet.title
        description = $item.snippet.description
        channelId   = $item.snippet.channelId
        channelTitle = $item.snippet.channelTitle
        publishedAt = $item.snippet.publishedAt
      })
    }
    Write-Output "[$game] 検索完了: $($resp.items.Count)件"
  } catch {
    $safeMsg = Get-RedactedMessage $_.Exception.Message
    $gamesFailed.Add($game)
    Write-Warning "[$game] 検索に失敗しました: $safeMsg"
    if ($safeMsg -match "quotaExceeded|dailyLimitExceeded|rateLimitExceeded") {
      Write-Error "API quota上限に達した可能性があるため、以降の探索を中止します(無限リトライはしません)。"
      $stopAll = $true
    }
  }
}

# ---- 自動検証・False Positive除外・confidence分類 ----
$dedupExcluded = 0
$results = New-Object System.Collections.Generic.List[object]

foreach ($item in $allItems) {
  if ($item.playlistId -and $existingPlaylistIds.ContainsKey($item.playlistId)) { $dedupExcluded++; continue }

  $normTitle = Normalize-Text $item.title
  $normDesc = Normalize-Text $item.description
  $g = $gameInfo[$item.targetGame]

  $nameHit = $normTitle.Contains((Normalize-Text $g.name))
  $aliasHit = $false
  foreach ($a in $g.aliases) { if ($a -and $normTitle.Contains((Normalize-Text $a))) { $aliasHit = $true } }
  if (-not $nameHit -and -not $aliasHit) { continue } # ゲーム名/別名がタイトルに無いものは対象外(検索エンジン側の緩い関連結果を除外)

  $isNonGame = $false
  foreach ($kw in $nonGameKeywords) { if ($normTitle.Contains($kw) -or $normDesc.Contains($kw)) { $isNonGame = $true; break } }

  $channelKnown = $knownChannelIds.ContainsKey($item.channelId)
  $channelNameMatch = $knownStreamerNormNames.ContainsKey((Normalize-Text $item.channelTitle))
  $knownStreamerName = if ($channelKnown) { $knownChannelIds[$item.channelId] } elseif ($channelNameMatch) { $knownStreamerNormNames[(Normalize-Text $item.channelTitle)] } else { $null }

  $ambiguous = ($aliasHit -and $g.aliases.Count -gt 0 -and (@($gameInfo.Values | Where-Object { $_.aliases -contains ($g.aliases | Select-Object -First 1) }).Count -gt 1))

  $warnings = New-Object System.Collections.Generic.List[string]
  if ($isNonGame) { $warnings.Add("タイトル/説明文に切り抜き・宣伝等を示す語を含む") }
  if ($g.isUmbrella) { $warnings.Add("シリーズ集約名への一致") }
  if (-not $knownStreamerName) { $warnings.Add("STREAMERSに登録済みの既知VTuberチャンネルと確認できない") }
  if ($ambiguous) { $warnings.Add("別名が他ゲームと共有されており曖昧") }
  if (-not $item.publishedAt) { $warnings.Add("公開日時が取得できない(削除/非公開の可能性)") }

  $confidence =
    if ($isNonGame -or $g.isUmbrella -or $ambiguous -or -not $knownStreamerName) { "LOW" }
    elseif ($aliasHit -and -not $nameHit) { "MEDIUM" }
    elseif ($nameHit -and $knownStreamerName) { "HIGH" }
    else { "MEDIUM" }

  $results.Add([PSCustomObject][ordered]@{
    game          = $item.targetGame
    streamer      = $knownStreamerName
    channelTitle  = $item.channelTitle
    channelVerified = [bool]$knownStreamerName
    playlistTitle = $item.title
    playlistId    = $item.playlistId
    playlistUrl   = "https://www.youtube.com/playlist?list=" + $item.playlistId
    publishedAt   = $item.publishedAt
    confidence    = $confidence
    matchVia      = if ($nameHit) { "ゲーム名一致" } else { "別名一致" }
    warning       = ($warnings -join " / ")
  })
}

$results = @($results | Sort-Object @{Expression = { switch ($_.confidence) { "HIGH" {0} "MEDIUM" {1} default {2} } } }, game)

# 件数(HIGH/MEDIUM/LOW)は表示上限30件で切り詰める前の、実際に見つかった全候補で数える
$highCount = @($results | Where-Object { $_.confidence -eq "HIGH" }).Count
$medCount = @($results | Where-Object { $_.confidence -eq "MEDIUM" }).Count
$lowCount = @($results | Where-Object { $_.confidence -eq "LOW" }).Count
$noMatchOrOther = $allItems.Count - $dedupExcluded - ($highCount + $medCount + $lowCount)
$totalCandidates = $results.Count

if ($results.Count -gt 30) { $results = @($results | Select-Object -First 30) }

$searchedButNoCandidate = @($targetGames | Where-Object { $g = $_; -not (@($results | Where-Object { $_.game -eq $g }).Count) })

Write-Output ""
Write-Output "=== ぶいゲー APIによる再生リスト候補探索 (search-playlist-candidates.ps1) ==="
Write-Output "対象ゲーム数: $($targetGames.Count)  探索成功: $gamesSearched  探索失敗: $($gamesFailed.Count)"
Write-Output "API取得件数(全ゲーム合計): $($allItems.Count)"
Write-Output "既存playlist重複除外: $dedupExcluded"
Write-Output "ゲーム名/別名不一致等でのその他除外: $noMatchOrOther"
Write-Output "候補件数(全体): $totalCandidates  HIGH:$highCount MEDIUM:$medCount LOW:$lowCount  (表示/出力は先頭$($results.Count)件までに制限)"
Write-Output ""
foreach ($r in $results) {
  Write-Output ("  [{0}] {1} / {2}(検証:{3}) <- 「{4}」 {5}" -f $r.confidence, $r.game, $(if ($r.streamer) { $r.streamer } else { $r.channelTitle + "(未検証)" }), $r.channelVerified, $r.playlistTitle, $(if ($r.warning) { "⚠ " + $r.warning } else { "" }))
}
Write-Output ""
if ($searchedButNoCandidate.Count -gt 0) {
  Write-Output "候補が0件だったゲーム:"
  foreach ($g in $searchedButNoCandidate) { Write-Output "  - $g" }
}
Write-Output ""
Write-Output "重要: HIGH判定でも自動的にproductionへは投入されません。人間による実在確認・"
Write-Output "本編プレイであることの確認を経てから、承認したものだけ手動で反映してください。"

$jsonDir = Split-Path -Parent $Json
if ($jsonDir -and -not (Test-Path $jsonDir)) { New-Item -ItemType Directory -Path $jsonDir -Force | Out-Null }
$report = [ordered]@{
  generatedAt  = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
  targetGames  = $targetGames
  gamesSearched = $gamesSearched
  gamesFailed  = $gamesFailed
  apiItemsTotal = $allItems.Count
  dedupExcluded = $dedupExcluded
  candidatesTotal = $totalCandidates
  candidates   = $results
  noCandidateGames = $searchedButNoCandidate
}
($report | ConvertTo-Json -Depth 8) | Set-Content -Path $Json -Encoding UTF8
Write-Output "候補一覧をJSONで出力しました: $Json"

exit 0
