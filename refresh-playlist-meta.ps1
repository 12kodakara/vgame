<#
.SYNOPSIS
  data-playlists.js の updatedDate(最近更新の日付)と、欠けている thumbnailUrl を
  YouTube Data API v3 で「変化があった再生リストだけ」差分更新します。

.DESCRIPTION
  update-dates.ps1 は一度キャッシュした再生リストを -Force なしでは再取得しないため、
  初回取得(2026-09-10頃)以降の更新が反映されず、また後から追加した再生リストには
  updatedDate / thumbnailUrl が入りませんでした。このスクリプトはその差分を埋めます。

    1. 概要フェーズ: playlists.list?part=snippet,contentDetails を 50件ずつ呼び、
       全再生リストの itemCount(収録数)と再生リスト固有サムネイルを取得します。
       6,562件で 132 unit。
    2. 明細フェーズ: 次のいずれかに当たる再生リストだけ playlistItems.list を
       全ページ取得します(1ページ 1 unit)。
         - updatedDate が無い(後から追加した再生リスト)
         - itemCount が前回値(初回は data-playlists.js の videoCount)から変わった
         - thumbnailUrl が無い/YouTubeの no_thumbnail で、固有サムネイルも取れない
       updatedDate は update-dates.ps1 と同じ定義(再生リストに動画が追加された日時
       snippet.publishedAt の最大値、ローカル日付)です。
       代表動画サムネイルは、再生リスト先頭から見て最初に画像を持つ動画(非公開・削除済みは
       画像が無いので自然に除外される)のものを使います。
    3. 反映フェーズ: updatedDate を書き換え/追加し、thumbnailUrl は
       「無い、または no_thumbnail のもの」だけを 固有サムネイル → 代表動画サムネイル の順で
       補います。表示中の正常なサムネイル・videoCount・その他の項目には触れません。

  -MaxUnits を超えそうになったら明細フェーズを打ち切り、残りは次回実行に回します
  (キャッシュは保存済みなので続きから再開します)。APIキーはファイル・ログに出力しません。

.PARAMETER ApiKey
  YouTube Data API v3 のAPIキー。省略時は環境変数 YOUTUBE_API_KEY。
.PARAMETER DataPath
  書き換える data-playlists.js。既定はスクリプトと同じフォルダ。
.PARAMETER CachePath
  差分判定用キャッシュ。既定はスクリプトと同じフォルダの playlist-meta-cache.json。
.PARAMETER MaxUnits
  1回の実行で使うAPI unit の上限(既定 2000。無料枠は1日 10,000)。
.PARAMETER PlanOnly
  概要フェーズ(132 unit)だけ実行し、明細フェーズの対象件数と予定 unit を表示します。
  ファイルは一切書き換えません。
.PARAMETER OnlyMissing
  updatedDate が未設定、または thumbnailUrl が未設定/no_thumbnail の再生リストだけを
  対象にします。概要フェーズも対象分しか呼ばないため、数件なら 2〜3 unit で済みます。
  新しく再生リストを data-playlists.js に追記した直後は、これを実行してください
  (付け忘れると「最近更新された再生リスト」に、実際の更新日ではなく
  サイト追加日で並んだ項目が出てしまいます)。
.PARAMETER ApplyOnly
  API通信をせず、キャッシュの内容だけを data-playlists.js に反映します。

.EXAMPLE
  .\refresh-playlist-meta.ps1 -PlanOnly
.EXAMPLE
  .\refresh-playlist-meta.ps1
.EXAMPLE
  .\refresh-playlist-meta.ps1 -OnlyMissing
  再生リストを追記した直後に、その分だけ updatedDate / thumbnailUrl を取得する
#>
param(
  [string]$ApiKey = $env:YOUTUBE_API_KEY,
  [string]$DataPath = (Join-Path $PSScriptRoot "data-playlists.js"),
  [string]$CachePath = (Join-Path $PSScriptRoot "playlist-meta-cache.json"),
  [int]$MaxUnits = 2000,
  [switch]$PlanOnly,
  [switch]$OnlyMissing,
  [switch]$ApplyOnly
)

$ErrorActionPreference = "Stop"
$placeholderRe = '^https?://i\.ytimg\.com/img/no_thumbnail\.jpg$'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# ---- data-playlists.js を読み込み、PLAYLISTS 配列の各オブジェクトを抽出(update-dates.ps1 と同じ方式) ----
$full = [System.IO.File]::ReadAllText($DataPath, [System.Text.Encoding]::UTF8)
$marker = "const PLAYLISTS = ["
$markerIdx = $full.IndexOf($marker)
if ($markerIdx -lt 0) { throw "data-playlists.js 内に `"$marker`" が見つかりません。" }
$bodyStart = $markerIdx + $marker.Length
$rest = $full.Substring($bodyStart)
$closeIdx = $rest.IndexOf("`n];")
if ($closeIdx -lt 0) { throw "PLAYLISTS 配列の終端が見つかりません。" }
$arrayInner = $rest.Substring(0, $closeIdx)
$footer = $rest.Substring($closeIdx)
$header = $full.Substring(0, $bodyStart)
$nl = if ($full.Contains("`r`n")) { "`r`n" } else { "`n" }

$objectMatches = [regex]::Matches($arrayInner, '\{[^{}]*\}')
$idLineCount = [regex]::Matches($arrayInner, '(?m)^\s*id:\s*"').Count
if ($objectMatches.Count -ne $idLineCount) {
  throw "再生リストの抽出件数($($objectMatches.Count))と id 行の数($idLineCount)が一致しません。中断します。"
}
Write-Output "検出したプレイリスト件数: $($objectMatches.Count)"

function Get-Field([string]$block, [string]$name) {
  $m = [regex]::Match($block, "(?m)^\s*$($name):\s*`"([^`"]*)`"")
  if ($m.Success) { return $m.Groups[1].Value } else { return $null }
}

$entries = foreach ($m in $objectMatches) {
  $vc = [regex]::Match($m.Value, '(?m)^\s*videoCount:\s*(\d+)')
  [PSCustomObject]@{
    PlaylistId   = Get-Field $m.Value "playlistId"
    UpdatedDate  = Get-Field $m.Value "updatedDate"
    ThumbnailUrl = Get-Field $m.Value "thumbnailUrl"
    VideoCount   = if ($vc.Success) { [int]$vc.Groups[1].Value } else { -1 }
  }
}

# 収録動画がすべて非公開・削除済みなどで、サムネイルをどうやっても取得できない
# 再生リストがある。毎回取りにいくと無駄なので、一度空振りしたら30日は再試行しない。
function Test-ThumbRetryDue($c) {
  if (-not $c) { return $true }
  $last = $c["thumbTriedAt"]
  if (-not $last) { return $true }
  try { return ([datetime]::ParseExact([string]$last, "yyyy-MM-dd", $null) -lt (Get-Date).AddDays(-30)) } catch { return $true }
}

function Test-NeedsThumb($e) {
  return (-not $e.ThumbnailUrl) -or ($e.ThumbnailUrl -match $placeholderRe)
}

# medium > standard > high > default(fetch-thumbnails.ps1 と同じ優先順)。no_thumbnail は採用しない。
function Select-Thumb($thumbs) {
  if (-not $thumbs) { return $null }
  foreach ($k in @("medium", "standard", "high", "default")) {
    $t = $thumbs.$k
    if ($t -and $t.url -and ($t.url -notmatch $placeholderRe)) { return [string]$t.url }
  }
  return $null
}

# ---- キャッシュ ----
$cache = @{}
if (Test-Path $CachePath) {
  $loaded = Get-Content -Raw -Encoding UTF8 $CachePath | ConvertFrom-Json
  foreach ($p in $loaded.PSObject.Properties) {
    $h = @{}
    foreach ($q in $p.Value.PSObject.Properties) { $h[$q.Name] = $q.Value }
    $cache[$p.Name] = $h
  }
  Write-Output "既存キャッシュ: $($cache.Count) 件"
}
function Save-Cache {
  ($cache | ConvertTo-Json -Depth 5 -Compress) | Set-Content -Path $CachePath -Encoding UTF8
}

# API呼び出し。例外メッセージにはURL(APIキー入り)が含まれ得るため、外へは
# HTTPステータスだけを返す。429 / 5xx / タイムアウト / ネットワーク障害のような
# 一時的な失敗のみ、間隔を空けて最大3回試す(400/403/404は再試行しない)。
# Windows PowerShell 5.1 と PowerShell 7 の両方で動くように例外の読み方を分けている。
function Invoke-YouTube([string]$url) {
  $attempt = 0
  while ($true) {
    $attempt++
    try {
      return @{ ok = $true; resp = (Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 60) }
    } catch {
      $status = $null; $body = ""
      $resp = $_.Exception.Response
      if ($resp) {
        try { $status = [int]$resp.StatusCode } catch {}
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
          $body = [string]$_.ErrorDetails.Message           # PowerShell 7
        } elseif ($resp | Get-Member -Name GetResponseStream -MemberType Method -ErrorAction SilentlyContinue) {
          try {                                             # Windows PowerShell 5.1
            $s = $resp.GetResponseStream(); $s.Position = 0
            $body = (New-Object System.IO.StreamReader($s)).ReadToEnd()
          } catch {}
        }
      }
      $quota = ($status -eq 403) -and ($body -match "quotaExceeded|dailyLimitExceeded")
      $retryable = (-not $quota) -and (($null -eq $status) -or ($status -eq 429) -or ($status -ge 500))
      if ($retryable -and $attempt -lt 3) {
        Start-Sleep -Seconds (5 * $attempt)
        continue
      }
      return @{ ok = $false; status = $status; quota = $quota; retryable = $retryable }
    }
  }
}

# publishedAt(UTC)を日本時間の日付にする。PowerShell 7 の ConvertFrom-Json は
# 日時文字列を DateTime に変換してしまうため、実行環境のタイムゾーン(GitHub
# Actions は UTC)に左右されないよう、必ずUTCを経由して +9時間で日付を決める。
function ConvertTo-JstDate($value) {
  if ($value -is [datetime]) {
    $utc = ([datetime]$value).ToUniversalTime()
  } elseif ($value -is [datetimeoffset]) {
    $utc = ([datetimeoffset]$value).UtcDateTime
  } else {
    $utc = [datetimeoffset]::Parse([string]$value, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind).UtcDateTime
  }
  return $utc.AddHours(9).ToString("yyyy-MM-dd")
}

$units = 0
$today = (Get-Date).ToString("yyyy-MM-dd")

if (-not $ApplyOnly) {
  if (-not $ApiKey) { throw "APIキーがありません。-ApiKey か環境変数 YOUTUBE_API_KEY を設定してください。" }

  # ---- 1. 概要フェーズ ----
  # 既定は全件(132 unit)。-OnlyMissing のときは updatedDate 未設定 / サムネイル欠落の
  # 再生リストだけに絞る(取り込み直後に数 unit で埋めるための入口)。
  $info = @{}
  if ($OnlyMissing) {
    $ids = @($entries | Where-Object { (-not $_.UpdatedDate) -or ((Test-NeedsThumb $_) -and (Test-ThumbRetryDue $cache[$_.PlaylistId])) } | ForEach-Object { $_.PlaylistId } | Select-Object -Unique)
    Write-Output "[OnlyMissing] updatedDate 未設定 / サムネイル欠落の $($ids.Count) 件だけを対象にします。"
    if ($ids.Count -eq 0) {
      Write-Output "対象がありません。APIを呼ばずに終了します(data-playlists.js は変更していません)。"
      exit 0
    }
  } else {
    $ids = @($entries | ForEach-Object { $_.PlaylistId } | Select-Object -Unique)
  }
  for ($i = 0; $i -lt $ids.Count; $i += 50) {
    $batch = $ids[$i..([Math]::Min($i + 49, $ids.Count - 1))]
    $url = "https://www.googleapis.com/youtube/v3/playlists?part=snippet,contentDetails&maxResults=50&id=$($batch -join ',')&key=$ApiKey"
    $r = Invoke-YouTube $url
    $units++
    if (-not $r.ok) {
      if ($r.quota) { throw "APIクォータ上限のため中断しました(概要フェーズ)。data-playlists.js は変更していません。" }
      throw "playlists.list が HTTP $($r.status) で失敗しました。data-playlists.js は変更していません。"
    }
    foreach ($it in $r.resp.items) {
      $info[$it.id] = @{ itemCount = [int]$it.contentDetails.itemCount; thumb = (Select-Thumb $it.snippet.thumbnails) }
    }
  }
  $notFound = @($ids | Where-Object { -not $info.ContainsKey($_) })
  Write-Output "概要フェーズ完了: $($info.Count) 件取得 / 見つからない $($notFound.Count) 件 / $units unit"

  # ---- 明細フェーズの対象を決める ----
  $targets = New-Object System.Collections.ArrayList
  foreach ($e in $entries) {
    $pid_ = $e.PlaylistId
    if (-not $info.ContainsKey($pid_)) { continue }
    $inf = $info[$pid_]
    $c = $cache[$pid_]
    if (-not $c) { $c = @{}; $cache[$pid_] = $c }
    if ($inf.thumb) { $c["playlistThumb"] = $inf.thumb }
    $baseline = if ($null -ne $c["itemCount"]) { [int]$c["itemCount"] } else { $e.VideoCount }
    $reasons = @()
    if (-not $e.UpdatedDate -and -not $c["date"]) { $reasons += "noDate" }
    if ($inf.itemCount -ne $baseline) { $reasons += "count" }
    if ((Test-NeedsThumb $e) -and -not $inf.thumb -and -not $c["videoThumb"] -and (Test-ThumbRetryDue $c)) { $reasons += "thumb" }
    if ($reasons.Count -gt 0) {
      $pri = if ($reasons -contains "noDate" -or $reasons -contains "thumb") { 0 } else { 1 }
      [void]$targets.Add([PSCustomObject]@{ PlaylistId = $pid_; ItemCount = $inf.itemCount; Reasons = ($reasons -join ","); Pri = $pri })
    } else {
      $c["itemCount"] = $inf.itemCount
    }
  }
  $targets = @($targets | Sort-Object Pri)
  $planned = ($targets | ForEach-Object { [Math]::Max(1, [Math]::Ceiling($_.ItemCount / 50)) } | Measure-Object -Sum).Sum
  if (-not $planned) { $planned = 0 }
  $byReason = $targets | Group-Object Reasons | ForEach-Object { "$($_.Name)=$($_.Count)" }
  Write-Output "明細フェーズ対象: $($targets.Count) 件 ($($byReason -join ' ')) / 予定 $planned unit / 上限 $MaxUnits unit"

  if ($PlanOnly) {
    Write-Output "[PlanOnly] ここで終了します。ファイルは変更していません。使用 $units unit"
    exit 0
  }

  # ---- 2. 明細フェーズ ----
  $done = 0; $failed = 0; $stopped = $false
  foreach ($t in $targets) {
    $need = [Math]::Max(1, [Math]::Ceiling($t.ItemCount / 50))
    if ($units + $need -gt $MaxUnits) { $stopped = $true; break }
    $latest = $null; $rep = $null; $pageToken = $null; $ok = $true
    do {
      $url = "https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&maxResults=50&playlistId=$([uri]::EscapeDataString($t.PlaylistId))&key=$ApiKey"
      if ($pageToken) { $url += "&pageToken=$([uri]::EscapeDataString($pageToken))" }
      $r = Invoke-YouTube $url
      $units++
      if (-not $r.ok) {
        $ok = $false
        if ($r.quota) { $stopped = $true }
        Write-Warning "$($t.PlaylistId) の明細取得に失敗 (HTTP $($r.status))"
        break
      }
      foreach ($item in $r.resp.items) {
        $d = ConvertTo-JstDate $item.snippet.publishedAt
        if (-not $latest -or $d -gt $latest) { $latest = $d }
        if (-not $rep) { $rep = Select-Thumb $item.snippet.thumbnails }
      }
      $pageToken = $r.resp.nextPageToken
    } while ($pageToken)
    if ($stopped -and -not $ok) { break }
    if (-not $ok) { $failed++; continue }
    $c = $cache[$t.PlaylistId]
    $c["itemCount"] = $t.ItemCount
    $c["checkedAt"] = $today
    if ($latest) { $c["date"] = $latest }   # 既に "yyyy-MM-dd"(JST)
    if ($rep) { $c["videoThumb"] = $rep }
    # サムネイルを埋められなかった再生リストは、30日間は再試行しない(上の Test-ThumbRetryDue)
    if (-not $rep -and -not $c["playlistThumb"]) { $c["thumbTriedAt"] = $today }
    $done++
    if ($done % 50 -eq 0) { Save-Cache; Write-Output "  $done/$($targets.Count) 件  $units unit" }
  }
  Save-Cache
  Write-Output "明細フェーズ: 完了 $done 件 / 失敗 $failed 件 / 残り $($targets.Count - $done - $failed) 件(次回実行で再開) / 合計 $units unit"
}

# ---- 3. 反映フェーズ ----
$sb = New-Object System.Text.StringBuilder
$prevEnd = 0
$stat = @{ dateChanged = 0; dateAdded = 0; thumbReplaced = 0; thumbAdded = 0; thumbFromVideo = 0 }
foreach ($m in $objectMatches) {
  [void]$sb.Append($arrayInner.Substring($prevEnd, $m.Index - $prevEnd))
  $block = $m.Value
  $pid_ = Get-Field $block "playlistId"
  $c = $cache[$pid_]
  if ($c) {
    if ($c["date"]) {
      $um = [regex]::Match($block, 'updatedDate:\s*"([^"]*)"')
      if ($um.Success) {
        $g = $um.Groups[1]
        if ($g.Value -ne $c["date"]) {
          $block = $block.Substring(0, $g.Index) + $c["date"] + $block.Substring($g.Index + $g.Length)
          $stat.dateChanged++
        }
      } else {
        $am = [regex]::Match($block, 'addedDate:\s*"[^"]*",')
        if (-not $am.Success) { throw "addedDate が見つかりません: $pid_" }
        $at = $am.Index + $am.Length
        $block = $block.Substring(0, $at) + "$nl    updatedDate: `"$($c["date"])`"," + $block.Substring($at)
        $stat.dateAdded++
      }
    }
    $cur = Get-Field $block "thumbnailUrl"
    if ((-not $cur) -or ($cur -match $placeholderRe)) {
      $newThumb = if ($c["playlistThumb"]) { $c["playlistThumb"] } else { $c["videoThumb"] }
      if ($newThumb) {
        if (-not $c["playlistThumb"]) { $stat.thumbFromVideo++ }
        if ($cur) {
          $tm = [regex]::Match($block, 'thumbnailUrl:\s*"([^"]*)"')
          $g = $tm.Groups[1]
          $block = $block.Substring(0, $g.Index) + $newThumb + $block.Substring($g.Index + $g.Length)
          $stat.thumbReplaced++
        } else {
          $pm = [regex]::Match($block, 'playlistId:\s*"[^"]*",')
          $at = $pm.Index + $pm.Length
          $block = $block.Substring(0, $at) + "$nl    thumbnailUrl: `"$newThumb`"," + $block.Substring($at)
          $stat.thumbAdded++
        }
      }
    }
  }
  [void]$sb.Append($block)
  $prevEnd = $m.Index + $m.Length
}
[void]$sb.Append($arrayInner.Substring($prevEnd))
$newFull = $header + $sb.ToString() + $footer
if ($newFull -ne $full) {
  [System.IO.File]::WriteAllText($DataPath, $newFull, $utf8NoBom)
}
Write-Output ("反映: updatedDate 更新 {0} / 追加 {1}、thumbnailUrl 置換 {2} / 追加 {3}(うち代表動画 {4})" -f $stat.dateChanged, $stat.dateAdded, $stat.thumbReplaced, $stat.thumbAdded, $stat.thumbFromVideo)
