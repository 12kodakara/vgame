<#
.SYNOPSIS
  YouTube Data API v3 を使って、data-playlists.js の各再生リストに含まれる動画の
  タイトルを数件ずつ取得し、確認用のJSONファイルに書き出します。
  (game/genre の自動判定が正しいかをAIが検証するための下調べ用スクリプトです。
   data-playlists.js の書き換えはこのスクリプトでは行いません。)

.PARAMETER ApiKey
  YouTube Data API v3 のAPIキー。省略時は環境変数 YOUTUBE_API_KEY を使用します。

.PARAMETER IdPrefix
  id がこの文字列で始まる再生リストだけを対象にします(例: "vspo-", "niji-")。
  省略時は全件が対象です。

.PARAMETER SampleSize
  1つの再生リストにつき取得する動画タイトルの件数(先頭から)。省略時は5。

.PARAMETER OutFile
  出力先JSONファイル名。省略時は video-titles-sample.json。

.EXAMPLE
  .\fetch-video-titles.ps1 -ApiKey "AIza..." -IdPrefix "niji-"
#>
param(
  [string]$ApiKey = $env:YOUTUBE_API_KEY,
  [string]$IdPrefix,
  [int]$SampleSize = 5,
  [string]$OutFile = "video-titles-sample.json"
)

$ErrorActionPreference = "Stop"

if (-not $ApiKey) {
  Write-Error "APIキーが指定されていません。-ApiKey パラメータか環境変数 YOUTUBE_API_KEY を設定してください。"
  exit 1
}

$scriptDir = $PSScriptRoot
$dataPath = Join-Path $scriptDir "data-playlists.js"
$outPath = Join-Path $scriptDir $OutFile
$cachePath = Join-Path $scriptDir "video-titles-cache.json"

$full = [System.IO.File]::ReadAllText($dataPath, [System.Text.Encoding]::UTF8)

$marker = "const PLAYLISTS = ["
$markerIdx = $full.IndexOf($marker)
if ($markerIdx -lt 0) { Write-Error "PLAYLISTS 配列が見つかりません。"; exit 1 }
$bodyStart = $markerIdx + $marker.Length
$rest = $full.Substring($bodyStart)
$closeIdx = $rest.IndexOf("`n];")
if ($closeIdx -lt 0) { Write-Error "PLAYLISTS 配列の終端が見つかりません。"; exit 1 }
$arrayInner = $rest.Substring(0, $closeIdx)

$objectMatches = [regex]::Matches($arrayInner, '\{[^{}]*\}')
$entries = foreach ($m in $objectMatches) {
  $idMatch = [regex]::Match($m.Value, 'id:\s*"([^"]*)"')
  $pidMatch = [regex]::Match($m.Value, 'playlistId:\s*"([^"]*)"')
  $gameMatch = [regex]::Match($m.Value, 'game:\s*"([^"]*)"')
  $streamerMatch = [regex]::Match($m.Value, 'streamer:\s*"([^"]*)"')
  [PSCustomObject]@{
    Id         = $idMatch.Groups[1].Value
    PlaylistId = $pidMatch.Groups[1].Value
    Game       = $gameMatch.Groups[1].Value
    Streamer   = $streamerMatch.Groups[1].Value
  }
}

if ($IdPrefix) { $entries = $entries | Where-Object { $_.Id.StartsWith($IdPrefix) } }
Write-Output "対象件数: $($entries.Count)"

$cache = @{}
if (Test-Path $cachePath) {
  $loaded = Get-Content -Raw -Encoding UTF8 $cachePath | ConvertFrom-Json
  foreach ($prop in $loaded.PSObject.Properties) { $cache[$prop.Name] = $prop.Value }
  Write-Output "既存キャッシュ: $($cache.Count) 件"
}

function Save-Cache {
  ($cache | ConvertTo-Json -Depth 6) | Set-Content -Path $cachePath -Encoding UTF8
}

$i = 0
$startTime = Get-Date
$quotaHit = $false
foreach ($e in $entries) {
  $i++
  if ($cache.ContainsKey($e.PlaylistId) -and -not $cache[$e.PlaylistId].error) { continue }

  try {
    $url = "https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&maxResults=$SampleSize&playlistId=$([uri]::EscapeDataString($e.PlaylistId))&key=$ApiKey"
    $resp = Invoke-RestMethod -Uri $url -Method Get
    $titles = @($resp.items | ForEach-Object { $_.snippet.title })
    $cache[$e.PlaylistId] = @{ titles = $titles }
  } catch {
    $statusCode = $null
    if ($_.Exception.Response) { $statusCode = [int]$_.Exception.Response.StatusCode }
    $cache[$e.PlaylistId] = @{ error = $_.Exception.Message }
    if ($statusCode -eq 403) {
      Write-Warning "403エラー(クォータ上限の可能性)。中断します。"
      $quotaHit = $true
    }
  }

  if ($i % 50 -eq 0 -or $quotaHit) {
    Save-Cache
    $elapsed = (Get-Date) - $startTime
    Write-Output ("{0}/{1} 件処理  経過:{2:mm\:ss}" -f $i, $entries.Count, $elapsed)
  }
  if ($quotaHit) { break }
}
Save-Cache

$results = foreach ($e in $entries) {
  $c = $cache[$e.PlaylistId]
  [PSCustomObject]@{
    id       = $e.Id
    streamer = $e.Streamer
    game     = $e.Game
    titles   = if ($c -and $c.titles) { $c.titles } else { @() }
  }
}
($results | ConvertTo-Json -Depth 6) | Set-Content -Path $outPath -Encoding UTF8
Write-Output "`n完了しました: $outPath"
