<#
.SYNOPSIS
  YouTube Data API v3 を使って、data-playlists.js の各プレイリストについて
  「プレイリスト内で最も新しく追加された動画の追加日」を取得し、
  updatedDate フィールドとして data-playlists.js に書き込みます。

.DESCRIPTION
  2段階で動作します。
    1. 取得フェーズ: 各プレイリストの playlistItems.list を呼び出し、
       各動画がプレイリストに追加された日時 (snippet.publishedAt) の
       最大値を求めて update-dates-cache.json に保存します。
       (中断しても再実行すれば未取得分だけ再開されます)
    2. 反映フェーズ: キャッシュの内容を data-playlists.js の該当エントリに
       updatedDate: "YYYY-MM-DD" として書き込みます。

.PARAMETER ApiKey
  YouTube Data API v3 のAPIキー。省略時は環境変数 YOUTUBE_API_KEY を使用します。

.PARAMETER Force
  既にキャッシュ済み(取得成功済み)のプレイリストも再取得します。

.PARAMETER Limit
  先頭 N 件だけ取得します(動作確認用)。

.PARAMETER Group
  STREAMERS の group が指定した値と一致する実況者の再生リストだけを対象にします
  (例: "ぶいすぽ")。

.PARAMETER Streamer
  指定した実況者名の再生リストだけを対象にします(例: "花芽すみれ")。

.PARAMETER ApplyOnly
  API取得を行わず、既存のキャッシュ内容だけを data-playlists.js に反映します。

.PARAMETER DryRun
  data-playlists.js への書き込みを行わず、反映件数のみ表示します。

.EXAMPLE
  .\update-dates.ps1 -ApiKey "AIza..." -Limit 5 -DryRun
  まず5件だけ試して結果を確認する

.EXAMPLE
  $env:YOUTUBE_API_KEY = "AIza..."
  .\update-dates.ps1
  全件取得してdata-playlists.jsに反映する

.EXAMPLE
  .\update-dates.ps1 -ApiKey "AIza..." -Group "ぶいすぽ"
  ぶいすぽ所属メンバーの再生リストだけ取得・反映する
#>
param(
  [string]$ApiKey = $env:YOUTUBE_API_KEY,
  [switch]$Force,
  [int]$Limit = 0,
  [string]$Group,
  [string]$Streamer,
  [switch]$ApplyOnly,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$scriptDir = $PSScriptRoot
$dataPath = Join-Path $scriptDir "data-playlists.js"
$corePath = Join-Path $scriptDir "data-core.js"
$cachePath = Join-Path $scriptDir "update-dates-cache.json"

if (-not (Test-Path $dataPath)) {
  Write-Error "data-playlists.js が見つかりません: $dataPath"
  exit 1
}

# ---- data-playlists.js を読み込み、PLAYLISTS 配列の各オブジェクトを抽出 ----
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$full = [System.IO.File]::ReadAllText($dataPath, [System.Text.Encoding]::UTF8)

$marker = "const PLAYLISTS = ["
$markerIdx = $full.IndexOf($marker)
if ($markerIdx -lt 0) {
  Write-Error "data-playlists.js 内に `"$marker`" が見つかりません。"
  exit 1
}
$bodyStart = $markerIdx + $marker.Length
$rest = $full.Substring($bodyStart)
$closeIdx = $rest.IndexOf("`n];")
if ($closeIdx -lt 0) {
  Write-Error "PLAYLISTS 配列の終端 `"];`" が見つかりません。"
  exit 1
}
$arrayInner = $rest.Substring(0, $closeIdx)
$footer = $rest.Substring($closeIdx)
$header = $full.Substring(0, $bodyStart)

$objectMatches = [regex]::Matches($arrayInner, '\{[^{}]*\}')
Write-Output "検出したプレイリスト件数: $($objectMatches.Count)"

$entries = foreach ($m in $objectMatches) {
  $idMatch = [regex]::Match($m.Value, 'id:\s*"([^"]*)"')
  $pidMatch = [regex]::Match($m.Value, 'playlistId:\s*"([^"]*)"')
  $streamerMatch = [regex]::Match($m.Value, 'streamer:\s*"([^"]*)"')
  [PSCustomObject]@{
    Id         = $idMatch.Groups[1].Value
    PlaylistId = $pidMatch.Groups[1].Value
    Streamer   = $streamerMatch.Groups[1].Value
  }
}

# ---- STREAMERS 配列(data-core.js)から 実況者名 -> group の対応表を作成(-Group 絞り込み用) ----
$streamerGroup = @{}
$streamersMarker = "const STREAMERS = ["
$coreFull = if (Test-Path $corePath) { [System.IO.File]::ReadAllText($corePath, [System.Text.Encoding]::UTF8) } else { "" }
$streamersIdx = $coreFull.IndexOf($streamersMarker)
if ($streamersIdx -ge 0) {
  $streamersBodyStart = $streamersIdx + $streamersMarker.Length
  $streamersRest = $coreFull.Substring($streamersBodyStart)
  $streamersCloseIdx = $streamersRest.IndexOf("`n];")
  if ($streamersCloseIdx -ge 0) {
    $streamersInner = $streamersRest.Substring(0, $streamersCloseIdx)
    foreach ($sm in [regex]::Matches($streamersInner, '\{[^{}]*\}')) {
      $nameMatch = [regex]::Match($sm.Value, 'name:\s*"([^"]*)"')
      $groupMatch = [regex]::Match($sm.Value, 'group:\s*"([^"]*)"')
      if ($nameMatch.Success) {
        $streamerGroup[$nameMatch.Groups[1].Value] = $groupMatch.Groups[1].Value
      }
    }
  }
}

if ($Group -or $Streamer) {
  $entries = $entries | Where-Object {
    (-not $Group -or $streamerGroup[$_.Streamer] -eq $Group) -and
    (-not $Streamer -or $_.Streamer -eq $Streamer)
  }
  Write-Output "絞り込み後のプレイリスト件数: $($entries.Count)"
}

# ---- キャッシュ読み込み ----
$cache = @{}
if (Test-Path $cachePath) {
  $loaded = Get-Content -Raw -Encoding UTF8 $cachePath | ConvertFrom-Json
  foreach ($prop in $loaded.PSObject.Properties) {
    $cache[$prop.Name] = $prop.Value
  }
  Write-Output "既存キャッシュを読み込みました: $($cache.Count) 件"
}

function Save-Cache {
  ($cache | ConvertTo-Json -Depth 5) | Set-Content -Path $cachePath -Encoding UTF8
}

# ---- 取得フェーズ ----
if (-not $ApplyOnly) {
  if (-not $ApiKey) {
    Write-Error "APIキーが指定されていません。-ApiKey パラメータか環境変数 YOUTUBE_API_KEY を設定してください。"
    exit 1
  }

  $targets = $entries | Where-Object {
    $Force -or -not $cache.ContainsKey($_.PlaylistId) -or $cache[$_.PlaylistId].error
  }
  if ($Limit -gt 0) { $targets = $targets | Select-Object -First $Limit }
  Write-Output "取得対象: $($targets.Count) 件"

  $i = 0
  $startTime = Get-Date
  $quotaHit = $false
  foreach ($t in $targets) {
    $i++
    try {
      $latest = $null
      $pageToken = $null
      do {
        $url = "https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&maxResults=50&playlistId=$([uri]::EscapeDataString($t.PlaylistId))&key=$ApiKey"
        if ($pageToken) { $url += "&pageToken=$([uri]::EscapeDataString($pageToken))" }
        $resp = Invoke-RestMethod -Uri $url -Method Get
        foreach ($item in $resp.items) {
          $d = [datetime]$item.snippet.publishedAt
          if (-not $latest -or $d -gt $latest) { $latest = $d }
        }
        $pageToken = $resp.nextPageToken
      } while ($pageToken)

      if ($latest) {
        $cache[$t.PlaylistId] = @{ date = $latest.ToString("yyyy-MM-dd") }
      } else {
        $cache[$t.PlaylistId] = @{ error = "動画が0件でした" }
      }
    } catch {
      $statusCode = $null
      $bodyText = $null
      if ($_.Exception.Response) {
        $statusCode = [int]$_.Exception.Response.StatusCode
        try {
          $stream = $_.Exception.Response.GetResponseStream()
          $stream.Position = 0
          $reader = New-Object System.IO.StreamReader($stream)
          $bodyText = $reader.ReadToEnd()
        } catch {}
      }
      $cache[$t.PlaylistId] = @{ error = $_.Exception.Message }
      $isQuota = $statusCode -eq 403 -and $bodyText -match "quotaExceeded|dailyLimitExceeded|rateLimitExceeded"
      if ($isQuota) {
        Write-Warning "APIクォータ上限に達しました。$($t.Id) : $($_.Exception.Message)"
        Write-Warning "ここで処理を中断します。キャッシュは保存済みのため、時間を置いて再実行すれば続きから取得できます。"
        $quotaHit = $true
      } else {
        Write-Warning "$($t.Id) ($($t.PlaylistId)) の取得に失敗(スキップして続行): $($_.Exception.Message)"
      }
    }

    if ($i % 20 -eq 0 -or $quotaHit) {
      Save-Cache
      $elapsed = (Get-Date) - $startTime
      Write-Output ("{0}/{1} 件処理  経過:{2:mm\:ss}" -f $i, $targets.Count, $elapsed)
    }

    if ($quotaHit) { break }
  }
  Save-Cache
  Write-Output "取得フェーズ完了。data-playlists.js への反映に進みます..."
}

# ---- 反映フェーズ: キャッシュの内容を data-playlists.js のテキストに書き戻す ----
$sb = New-Object System.Text.StringBuilder
$prevEnd = 0
$updated = 0
foreach ($m in $objectMatches) {
  $sb.Append($arrayInner.Substring($prevEnd, $m.Index - $prevEnd)) | Out-Null
  $block = $m.Value

  $pidMatch = [regex]::Match($block, 'playlistId:\s*"([^"]*)"')
  $playlistIdValue = $pidMatch.Groups[1].Value
  $cacheEntry = $cache[$playlistIdValue]

  if ($cacheEntry -and $cacheEntry.date) {
    $updatedMatch = [regex]::Match($block, 'updatedDate:\s*"([^"]*)"')
    if ($updatedMatch.Success) {
      $g = $updatedMatch.Groups[1]
      if ($g.Value -ne $cacheEntry.date) {
        $block = $block.Substring(0, $g.Index) + $cacheEntry.date + $block.Substring($g.Index + $g.Length)
        $updated++
      }
    } else {
      $addedMatch = [regex]::Match($block, 'addedDate:\s*"[^"]*",?')
      if ($addedMatch.Success) {
        $insertAt = $addedMatch.Index + $addedMatch.Length
        $block = $block.Substring(0, $insertAt) + "`n    updatedDate: `"$($cacheEntry.date)`"," + $block.Substring($insertAt)
        $updated++
      } else {
        Write-Warning "addedDate が見つからず updatedDate を追加できませんでした: $playlistIdValue"
      }
    }
  }

  $sb.Append($block) | Out-Null
  $prevEnd = $m.Index + $m.Length
}
$sb.Append($arrayInner.Substring($prevEnd)) | Out-Null
$newFull = $header + $sb.ToString() + $footer

if ($DryRun) {
  Write-Output "[DryRun] data-playlists.js は書き換えていません。反映対象件数: $updated"
} else {
  [System.IO.File]::WriteAllText($dataPath, $newFull, $utf8NoBom)
  Write-Output "data-playlists.js を更新しました。updatedDate 反映/更新件数: $updated"
}

$errCount = ($cache.Values | Where-Object { $_.error }).Count
if ($errCount -gt 0) {
  Write-Output "取得失敗のまま残っている件数: $errCount (詳細は update-dates-cache.json を参照。再実行すると自動的に再取得を試みます)"
}
