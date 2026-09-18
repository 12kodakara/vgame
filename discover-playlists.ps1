<#
.SYNOPSIS
  YouTube Data API v3 を使って、STREAMERS に登録されている実況者の
  YouTubeチャンネルが持つ再生リスト一覧を取得し、確認用のJSONファイルに
  書き出します(data-core.js への追加はこのスクリプトでは行いません)。

.DESCRIPTION
  STREAMERS の youtube フィールド(https://www.youtube.com/channel/UCxxxx 形式、
  または https://www.youtube.com/@handle 形式)からチャンネルを特定し、各チャンネルの
  playlists.list を呼び出して再生リストのタイトル・件数・説明文などを
  discovered-playlists.json に出力します。@handle 形式の場合は channels.list で
  チャンネルIDに解決してから取得します。ゲーム別・ジャンル別の仕分けは人の目で
  確認して data-core.js に手動(またはAIに依頼して)追加してください。

.PARAMETER ApiKey
  YouTube Data API v3 のAPIキー。省略時は環境変数 YOUTUBE_API_KEY を使用します。

.PARAMETER Group
  STREAMERS の group が指定した値と一致する実況者だけを対象にします(例: "ぶいすぽ")。

.PARAMETER Streamer
  指定した実況者名だけを対象にします。

.PARAMETER OutFile
  出力先JSONファイル名。省略時は discovered-playlists.json。

.EXAMPLE
  .\discover-playlists.ps1 -ApiKey "AIza..." -Group "ぶいすぽ"
#>
param(
  [string]$ApiKey = $env:YOUTUBE_API_KEY,
  [string]$Group,
  [string]$Streamer,
  [string]$OutFile = "discovered-playlists.json"
)

$ErrorActionPreference = "Stop"

# ---- エラー情報のヘルパー(第5回データ拡充で追加) ----
# APIキーがメッセージに混入するのを防ぐため、必ず伏せ字にしてから扱う。
function Get-RedactedText([string]$text) {
  if ($ApiKey -and $text) { return ($text -replace [regex]::Escape($ApiKey), "***REDACTED***") }
  return $text
}

# 例外から、レポートに残す errorType を機械的に決める。
# 個別のメッセージ文字列に依存しすぎないよう、HTTPステータスとGoogle APIの
# reason を優先し、どちらも取れない場合のみ汎用の分類にする。
function Get-ApiErrorType($errorRecord) {
  $body = ""
  $httpStatus = 0
  try {
    $resp = $errorRecord.Exception.Response
    if ($resp) {
      try { $httpStatus = [int]$resp.StatusCode } catch { $httpStatus = 0 }
      $sr = New-Object System.IO.StreamReader($resp.GetResponseStream())
      $body = $sr.ReadToEnd()
    }
  } catch { }
  if ($body) {
    if ($body -match '"reason"\s*:\s*"([A-Za-z_]+)"') {
      $reason = $Matches[1]
      switch -Regex ($reason) {
        '^API_KEY_INVALID$'            { return "API_KEY_INVALID" }
        '^(quotaExceeded|dailyLimitExceeded|rateLimitExceeded|userRateLimitExceeded)$' { return "QUOTA_ERROR" }
        default                        { return "API_ERROR_$reason" }
      }
    }
    if ($body -match 'API key not valid') { return "API_KEY_INVALID" }
  }
  if ($httpStatus -ge 400) { return "HTTP_$httpStatus" }
  if ($errorRecord.Exception -is [System.Management.Automation.RuntimeException] -and $errorRecord.Exception.Message -match 'JSON|Json') { return "JSON_PARSE_ERROR" }
  return "API_REQUEST_FAILED"
}

if (-not $ApiKey) {
  Write-Error "APIキーが指定されていません。-ApiKey パラメータか環境変数 YOUTUBE_API_KEY を設定してください。"
  exit 1
}

$scriptDir = $PSScriptRoot
$dataPath = Join-Path $scriptDir "data-core.js"
$outPath = Join-Path $scriptDir $OutFile

$full = [System.IO.File]::ReadAllText($dataPath, [System.Text.Encoding]::UTF8)

$marker = "const STREAMERS = ["
$markerIdx = $full.IndexOf($marker)
if ($markerIdx -lt 0) { Write-Error "STREAMERS 配列が見つかりません。"; exit 1 }
$bodyStart = $markerIdx + $marker.Length
$rest = $full.Substring($bodyStart)
$closeIdx = $rest.IndexOf("`n];")
if ($closeIdx -lt 0) { Write-Error "STREAMERS 配列の終端が見つかりません。"; exit 1 }
$inner = $rest.Substring(0, $closeIdx)

$streamers = foreach ($m in [regex]::Matches($inner, '\{[^{}]*\}')) {
  $nameMatch = [regex]::Match($m.Value, 'name:\s*"([^"]*)"')
  $groupMatch = [regex]::Match($m.Value, 'group:\s*"([^"]*)"')
  $ytMatch = [regex]::Match($m.Value, 'youtube:\s*"([^"]*)"')
  if ($nameMatch.Success) {
    [PSCustomObject]@{
      Name    = $nameMatch.Groups[1].Value
      Group   = $groupMatch.Groups[1].Value
      Youtube = $ytMatch.Groups[1].Value
    }
  }
}

if ($Group) { $streamers = $streamers | Where-Object { $_.Group -eq $Group } }
if ($Streamer) { $streamers = $streamers | Where-Object { $_.Name -eq $Streamer } }
$streamers = $streamers | Where-Object { $_.Youtube -match '/channel/UC[A-Za-z0-9_-]+' -or $_.Youtube -match '/@([^/?"]+)' }

Write-Output "対象実況者数(チャンネル特定済みのみ): $($streamers.Count)"
if ($streamers.Count -eq 0) {
  Write-Warning "対象が0件です。-Group / -Streamer の指定、または STREAMERS の youtube フィールド(channel/UCxxxx または @handle 形式)を確認してください。"
  exit 0
}

$results = @()
$i = 0
foreach ($s in $streamers) {
  $i++

  # status / errorType は「API探索が成立したか」を呼び出し側(run-playlist-cycle.ps1)が
  # 判別するための情報。探索が成立しなかったVTuberを「探索済み」として
  # search-history.json に記録しない(=30日再探索抑制の対象にしない)ために使う。
  $status = "success"
  $errorType = ""
  $errorDetail = ""

  $channelId = $null
  if ($s.Youtube -match '/channel/(UC[A-Za-z0-9_-]+)') {
    $channelId = $Matches[1]
  } elseif ($s.Youtube -match '/@([^/?"]+)') {
    $handle = $Matches[1]
    try {
      $resolveUrl = "https://www.googleapis.com/youtube/v3/channels?part=id&forHandle=$([uri]::EscapeDataString('@' + $handle))&key=$ApiKey"
      $resolveResp = Invoke-RestMethod -Uri $resolveUrl -Method Get
      if ($resolveResp.items -and $resolveResp.items.Count -gt 0) {
        $channelId = $resolveResp.items[0].id
      } else {
        Write-Warning "[$i/$($streamers.Count)] $($s.Name) (@$handle): チャンネルが見つかりませんでした。"
        $status = "failed"; $errorType = "CHANNEL_NOT_FOUND"
        $errorDetail = "channels.list(forHandle)が0件を返しました"
      }
    } catch {
      $status = "failed"; $errorType = Get-ApiErrorType $_
      $errorDetail = Get-RedactedText $_.Exception.Message
      Write-Warning "[$i/$($streamers.Count)] $($s.Name) (@$handle) のチャンネルID解決に失敗[$errorType]: $errorDetail"
    }
  } else {
    $status = "failed"; $errorType = "NO_CHANNEL_URL"
    $errorDetail = "youtubeフィールドから channel/UCxxxx も @handle も取り出せませんでした"
    Write-Warning "[$i/$($streamers.Count)] $($s.Name): $errorDetail"
  }

  if (-not $channelId) {
    if ($status -eq "success") { $status = "failed"; $errorType = "CHANNEL_RESOLVE_FAILED"; $errorDetail = "チャンネルIDを解決できませんでした" }
    $results += [PSCustomObject]@{ streamer = $s.Name; group = $s.Group; channelId = $null; playlists = @(); status = $status; errorType = $errorType; errorDetail = $errorDetail }
    continue
  }

  Write-Output "[$i/$($streamers.Count)] $($s.Name) ($channelId) の再生リストを取得中..."

  $playlists = @()
  $pageToken = $null
  try {
    do {
      $url = "https://www.googleapis.com/youtube/v3/playlists?part=snippet,contentDetails&channelId=$channelId&maxResults=50&key=$ApiKey"
      if ($pageToken) { $url += "&pageToken=$([uri]::EscapeDataString($pageToken))" }
      $resp = Invoke-RestMethod -Uri $url -Method Get
      foreach ($item in $resp.items) {
        $playlists += [PSCustomObject]@{
          playlistId  = $item.id
          title       = $item.snippet.title
          description = if ($item.snippet.description.Length -gt 200) { $item.snippet.description.Substring(0,200) } else { $item.snippet.description }
          itemCount   = $item.contentDetails.itemCount
          publishedAt = $item.snippet.publishedAt
        }
      }
      $pageToken = $resp.nextPageToken
    } while ($pageToken)
  } catch {
    # ページングの途中で失敗した場合、取得済みの分は不完全なので
    # 「成立した探索」として扱わない(部分的な結果で探索済み扱いにしない)。
    $status = "failed"; $errorType = Get-ApiErrorType $_
    $errorDetail = Get-RedactedText $_.Exception.Message
    Write-Warning "$($s.Name) の再生リスト取得に失敗[$errorType]: $errorDetail"
  }

  if ($status -eq "success") {
    Write-Output "  -> $($playlists.Count) 件の再生リストを取得"
  } else {
    Write-Output "  -> 取得失敗($errorType)。このVTuberは探索成立扱いにしません。"
  }
  $results += [PSCustomObject]@{
    streamer  = $s.Name
    group     = $s.Group
    channelId = $channelId
    playlists = $playlists
    status    = $status
    errorType = $errorType
    errorDetail = $errorDetail
  }
}

($results | ConvertTo-Json -Depth 6) | Set-Content -Path $outPath -Encoding UTF8
Write-Output "`n完了しました。結果を書き出しました: $outPath"
