<#
.SYNOPSIS
  YouTube Data API v3 (playlists.list) を使って、data-playlists.js の各再生リストの
  サムネイルURLを取得し、thumbnailUrl フィールドとして data-playlists.js に書き込みます。

.DESCRIPTION
  update-dates.ps1 と同じ2段階構成です。
    1. 取得フェーズ: playlistId を重複排除したうえで最大50件ずつまとめて
       playlists.list?part=snippet&id=ID1,ID2,...,ID50 を呼び出し、
       snippet.thumbnails から medium > standard > high > default の優先順位で
       サムネイルURLを選んで thumbnails-cache.json に保存します。
       (中断しても再実行すれば未取得分だけ再開されます)
    2. 反映フェーズ: キャッシュの成功結果(status: "success")を
       data-playlists.js の該当エントリに thumbnailUrl として書き込みます。

  再生リスト単位の playlistItems.list は使いません(1リストにつき1回のAPI呼び出しが
  必要になり、6,500件では非常に高コストになるため)。playlists.list はIDを指定して
  複数件を1回のリクエストでまとめて取得できるため、6,500件でも最大約131回の
  APIリクエストで済みます。

  サムネイル未取得のデータがあってもサイトの表示は壊れません(VTuberアイコン→
  実況者名の頭文字の順にフォールバック表示されます)。このスクリプトは
  ローカルで手動実行する管理用ツールで、サイト閲覧者のブラウザからは
  一切実行されません(APIキーはサイトの成果物に含まれません)。

.PARAMETER ApiKey
  YouTube Data API v3 のAPIキー。省略時は環境変数 YOUTUBE_API_KEY を使用します。
  -ApplyOnly / -DryRun のみを使う場合は不要です。
  このスクリプトはAPIキーをファイルへ保存せず、ログにも出力しません。

.PARAMETER Force
  既にキャッシュ済み(success / notFound / noThumbnail)の再生リストも再取得します。
  一時的なエラー(temporaryError)は -Force を付けなくても常に再試行対象になります。

.PARAMETER Limit
  取得対象を先頭 N 件(重複排除後のplaylistId基準)だけに制限します(動作確認用)。

.PARAMETER ApplyOnly
  API通信を行わず、既存の thumbnails-cache.json の内容だけを
  data-playlists.js に反映します。

.PARAMETER DryRun
  API通信・ファイル書き込みのいずれも行わず、取得予定件数・APIリクエスト予定回数・
  (現在のキャッシュを反映した場合の)反映予定件数だけを表示します。

.EXAMPLE
  .\fetch-thumbnails.ps1 -ApiKey "AIza..." -Limit 100 -DryRun
  まず100件分の取得予定・反映予定を確認する(通信もファイル変更もしない)

.EXAMPLE
  $env:YOUTUBE_API_KEY = "AIza..."
  .\fetch-thumbnails.ps1 -Limit 100
  実際に100件だけ取得・反映して動作確認する

.EXAMPLE
  .\fetch-thumbnails.ps1
  未取得分(重複排除後の全件)を取得・反映する

.EXAMPLE
  .\fetch-thumbnails.ps1 -ApplyOnly
  API通信せず、既存キャッシュの内容だけを data-playlists.js に反映し直す
#>
param(
  [string]$ApiKey = $env:YOUTUBE_API_KEY,
  [switch]$Force,
  [int]$Limit = 0,
  [switch]$ApplyOnly,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$scriptDir = $PSScriptRoot
$dataPath = Join-Path $scriptDir "data-playlists.js"
$cachePath = Join-Path $scriptDir "thumbnails-cache.json"
$batchSize = 50

if (-not (Test-Path $dataPath)) {
  Write-Error "data-playlists.js が見つかりません: $dataPath"
  exit 1
}

if (-not $ApplyOnly -and -not $DryRun -and -not $ApiKey) {
  Write-Error "APIキーが指定されていません。-ApiKey パラメータか環境変数 YOUTUBE_API_KEY を設定してください(-ApplyOnly のみを使う場合は不要です)。"
  exit 1
}

# ---- data-playlists.js を読み込み、PLAYLISTS 配列の各オブジェクトを抽出 ----
# (update-dates.ps1 と同じ手法: PLAYLISTS はネストした {} を持たないオブジェクトの
#  配列なので、単純な \{[^{}]*\} で1件ずつ取り出せる)
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
Write-Output "PLAYLISTS 件数: $($objectMatches.Count)"

$entries = foreach ($m in $objectMatches) {
  $idMatch = [regex]::Match($m.Value, 'id:\s*"([^"]*)"')
  $pidMatch = [regex]::Match($m.Value, 'playlistId:\s*"([^"]*)"')
  [PSCustomObject]@{
    Id         = $idMatch.Groups[1].Value
    PlaylistId = $pidMatch.Groups[1].Value
  }
}

# ---- playlistId を重複排除(先に出てきた順を維持) ----
$uniqueIds = New-Object System.Collections.Generic.List[string]
$seenIds = @{}
foreach ($e in $entries) {
  if ($e.PlaylistId -and -not $seenIds.ContainsKey($e.PlaylistId)) {
    $seenIds[$e.PlaylistId] = $true
    [void]$uniqueIds.Add($e.PlaylistId)
  }
}
Write-Output "重複排除後の playlistId 件数: $($uniqueIds.Count)"

# ---- キャッシュ読み込み(PSCustomObjectのプロパティをハッシュテーブルへ詰め替え) ----
$cache = @{}
if (Test-Path $cachePath) {
  $loaded = Get-Content -Raw -Encoding UTF8 $cachePath | ConvertFrom-Json
  if ($loaded) {
    foreach ($prop in $loaded.PSObject.Properties) {
      $cache[$prop.Name] = $prop.Value
    }
  }
  Write-Output "既存キャッシュを読み込みました: $($cache.Count) 件"
}

function Save-Cache {
  ($cache | ConvertTo-Json -Depth 5) | Set-Content -Path $cachePath -Encoding UTF8
}

function Get-NowIso {
  return (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
}

# temporaryError(一時的な通信エラー・クォータ超過)は通常実行でも常に再試行対象にする。
# success / notFound / noThumbnail は「解決済み」とみなし、-Force が無ければ再取得しない。
function Test-NeedsFetch([string]$playlistId) {
  if ($Force) { return $true }
  if (-not $cache.ContainsKey($playlistId)) { return $true }
  $entryStatus = $cache[$playlistId].status
  return ($entryStatus -eq "temporaryError")
}

if ($ApplyOnly) {
  $targets = @()
  $totalBatches = 0
} else {
  $targets = @($uniqueIds | Where-Object { Test-NeedsFetch $_ })
  if ($Limit -gt 0) { $targets = @($targets | Select-Object -First $Limit) }
  $totalBatches = if ($targets.Count -gt 0) { [Math]::Ceiling($targets.Count / $batchSize) } else { 0 }
}

# ---- DryRun: 通信・書き込みを行わず、予定件数だけ表示して終了 ----
if ($DryRun) {
  $plannedApply = 0
  foreach ($m in $objectMatches) {
    $pidMatch = [regex]::Match($m.Value, 'playlistId:\s*"([^"]*)"')
    $playlistIdValue = $pidMatch.Groups[1].Value
    if (-not $cache.ContainsKey($playlistIdValue)) { continue }
    $cacheEntry = $cache[$playlistIdValue]
    if ($cacheEntry.status -ne "success" -or -not $cacheEntry.thumbnailUrl) { continue }
    $thumbMatch = [regex]::Match($m.Value, 'thumbnailUrl:\s*"([^"]*)"')
    if (-not $thumbMatch.Success -or $thumbMatch.Groups[1].Value -ne $cacheEntry.thumbnailUrl) {
      $plannedApply++
    }
  }

  Write-Output "----"
  Write-Output "[DryRun] ファイルは変更していません。"
  if ($ApplyOnly) {
    Write-Output "[DryRun] -ApplyOnly のためAPI取得は行いません(APIリクエスト予定回数: 0)"
  } else {
    Write-Output "[DryRun] 取得予定件数(playlistId): $($targets.Count)"
    Write-Output "[DryRun] APIリクエスト予定回数: $totalBatches (最大 $batchSize 件/回)"
  }
  Write-Output "[DryRun] 反映予定件数(既存キャッシュ基準、data-playlists.js への書き込み): $plannedApply"
  exit 0
}

# ---- 取得フェーズ ----
if (-not $ApplyOnly) {
  Write-Output "取得対象: $($targets.Count) 件 / APIリクエスト予定回数: $totalBatches"

  $sizePriority = @("medium", "standard", "high", "default")
  function Get-BestThumbnailUrl($thumbnails) {
    if (-not $thumbnails) { return $null }
    foreach ($size in $sizePriority) {
      $t = $thumbnails.$size
      if ($t -and $t.url) { return $t.url }
    }
    return $null
  }

  $batchCount = 0
  $startTime = Get-Date
  $quotaHit = $false

  for ($start = 0; $start -lt $targets.Count; $start += $batchSize) {
    $endIdx = [Math]::Min($start + $batchSize - 1, $targets.Count - 1)
    $batchIds = $targets[$start..$endIdx]
    $batchCount++

    try {
      $idsParam = ($batchIds | ForEach-Object { [uri]::EscapeDataString($_) }) -join ","
      $url = "https://www.googleapis.com/youtube/v3/playlists?part=snippet&id=$idsParam&maxResults=$batchSize&key=$ApiKey"
      $resp = Invoke-RestMethod -Uri $url -Method Get

      $byId = @{}
      if ($resp.items) {
        foreach ($item in $resp.items) {
          if ($item.id) { $byId[$item.id] = $item }
        }
      }

      foreach ($plId in $batchIds) {
        $now = Get-NowIso
        if ($byId.ContainsKey($plId)) {
          $thumbUrl = Get-BestThumbnailUrl $byId[$plId].snippet.thumbnails
          if ($thumbUrl) {
            $cache[$plId] = @{ thumbnailUrl = $thumbUrl; fetchedAt = $now; status = "success" }
          } else {
            $cache[$plId] = @{ thumbnailUrl = $null; fetchedAt = $now; status = "noThumbnail" }
          }
        } else {
          # 50件リクエストしてレスポンスに含まれなかったID(非公開・削除済み等)。
          # 恒久的な欠落として記録するが、既存の thumbnailUrl があれば反映フェーズ側で
          # 削除はしない(このキャッシュには notFound とだけ記録する)。
          $cache[$plId] = @{ thumbnailUrl = $null; fetchedAt = $now; status = "notFound" }
        }
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
      $isQuota = $statusCode -eq 403 -and $bodyText -match "quotaExceeded|dailyLimitExceeded|rateLimitExceeded"
      $now = Get-NowIso
      foreach ($plId in $batchIds) {
        $cache[$plId] = @{ thumbnailUrl = $null; fetchedAt = $now; status = "temporaryError" }
      }
      if ($isQuota) {
        Write-Warning "APIクォータ上限に達しました(このバッチの $($batchIds.Count) 件は temporaryError として記録し、時間を置いて再実行してください)。"
        $quotaHit = $true
      } else {
        Write-Warning "バッチ $batchCount 件目の取得に失敗(temporaryErrorとして記録し、次のバッチへ進みます): $($_.Exception.Message)"
      }
    }

    Save-Cache
    $elapsed = (Get-Date) - $startTime
    Write-Output ("バッチ {0}/{1} 完了  累計 {2}/{3} 件  経過:{4:mm\:ss}" -f $batchCount, $totalBatches, [Math]::Min($start + $batchSize, $targets.Count), $targets.Count, $elapsed)

    if ($quotaHit) { break }
  }

  Write-Output "取得フェーズ完了。data-playlists.js への反映に進みます..."
}

# ---- 反映フェーズ: キャッシュの成功結果を data-playlists.js のテキストに書き戻す ----
function Get-JsEscapedString([string]$s) {
  return $s -replace '\\', '\\\\' -replace '"', '\"'
}

$sb = New-Object System.Text.StringBuilder
$prevEnd = 0
$updated = 0
foreach ($m in $objectMatches) {
  [void]$sb.Append($arrayInner.Substring($prevEnd, $m.Index - $prevEnd))
  $block = $m.Value

  $pidMatch = [regex]::Match($block, 'playlistId:\s*"([^"]*)"')
  $playlistIdValue = $pidMatch.Groups[1].Value
  $cacheEntry = if ($cache.ContainsKey($playlistIdValue)) { $cache[$playlistIdValue] } else { $null }

  if ($cacheEntry -and $cacheEntry.status -eq "success" -and $cacheEntry.thumbnailUrl) {
    $escapedUrl = Get-JsEscapedString $cacheEntry.thumbnailUrl
    $thumbMatch = [regex]::Match($block, 'thumbnailUrl:\s*"([^"]*)"')
    if ($thumbMatch.Success) {
      $g = $thumbMatch.Groups[1]
      if ($g.Value -ne $escapedUrl) {
        $block = $block.Substring(0, $g.Index) + $escapedUrl + $block.Substring($g.Index + $g.Length)
        $updated++
      }
    } else {
      $pidFullMatch = [regex]::Match($block, 'playlistId:\s*"[^"]*",?')
      if ($pidFullMatch.Success) {
        $insertAt = $pidFullMatch.Index + $pidFullMatch.Length
        $block = $block.Substring(0, $insertAt) + "`n    thumbnailUrl: `"$escapedUrl`"," + $block.Substring($insertAt)
        $updated++
      } else {
        Write-Warning "playlistId が見つからず thumbnailUrl を追加できませんでした: $playlistIdValue"
      }
    }
  }

  [void]$sb.Append($block)
  $prevEnd = $m.Index + $m.Length
}
[void]$sb.Append($arrayInner.Substring($prevEnd))
$newFull = $header + $sb.ToString() + $footer

[System.IO.File]::WriteAllText($dataPath, $newFull, $utf8NoBom)
Write-Output "data-playlists.js を更新しました。thumbnailUrl 反映/更新件数: $updated"

$statusCounts = @{}
foreach ($v in $cache.Values) {
  $st = if ($v.status) { $v.status } else { "unknown" }
  if (-not $statusCounts.ContainsKey($st)) { $statusCounts[$st] = 0 }
  $statusCounts[$st] = $statusCounts[$st] + 1
}
Write-Output "キャッシュ内訳: $(($statusCounts.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', ')"

$retryCount = ($cache.Values | Where-Object { $_.status -eq "temporaryError" }).Count
if ($retryCount -gt 0) {
  Write-Output "一時的なエラーで再取得が必要な件数: $retryCount (次回の通常実行時に自動的に再試行されます)"
}
