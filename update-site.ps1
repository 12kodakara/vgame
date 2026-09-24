<#
.SYNOPSIS
  データ更新に関わる各スクリプトをまとめて実行する統合スクリプトです。

.DESCRIPTION
  以下の順番で実行します。
    1. 新規再生リスト取得   (discover-playlists.ps1)  … 確認用JSON出力のみ。data-playlists.js は変更しません。
    2. 動画タイトル取得     (fetch-video-titles.ps1)   … 確認用JSON出力のみ。data-playlists.js は変更しません。
    3. サムネイル取得       (fetch-thumbnails.ps1)     … data-playlists.js の thumbnailUrl を更新します。
    4. 更新日取得           (update-dates.ps1)         … data-playlists.js の updatedDate を更新します。
    5. 件数再集計           (generate-counts.ps1)      … data-counts.js を再生成します。
    6. sitemap再生成        (generate-sitemap.ps1)     … sitemap.xml と robots.txt を更新します。
    7. データ検証           (validate-data.ps1)        … 最後に整合性をチェックして結果を表示します。

  1・2は「新しく追加すべき再生リスト・タイトル調査に使えそうな下調べ」を
  JSONに書き出すだけで、data-playlists.js への反映は行いません(既存の
  実況をAIやレビューなしに自動で追加しないための安全策です)。実際に
  追加する場合は、出力されたJSONを確認したうえで手動でdata-playlists.jsに
  追記してください。

  各ステップは子プロセス(powershell.exe -File)として実行します。各スクリプトは
  エラー時に exit で終了しますが、そのまま `&` で呼び出すとこのスクリプト自身の
  セッションまで終了してしまうため、子プロセスに分離して終了コードだけを
  受け取るようにしています。あるステップが失敗しても他のステップの実行は
  継続し、最後に「どのステップが失敗したか」をまとめて表示します。

.PARAMETER ApiKey
  YouTube Data API v3 のAPIキー。省略時は環境変数 YOUTUBE_API_KEY を使用します。
  API通信が必要なステップ(1〜4)で使う場合のみ必要です。このスクリプトは
  APIキーをファイルへ保存せず、ログにも出力しません(子プロセスへは環境変数
  経由で渡すため、コマンドライン引数には含まれません)。

.PARAMETER Limit
  サムネイル取得・更新日取得の対象件数を絞ります(動作確認用)。0=無制限。

.PARAMETER Force
  サムネイル取得・更新日取得で、キャッシュ済みの内容も再取得します。

.PARAMETER DryRun
  サムネイル取得・更新日取得を実際には書き込まず、予定件数のみ表示します
  (件数再集計・sitemap再生成・データ検証は通常どおり実行されます)。

.PARAMETER SkipDiscover
.PARAMETER SkipTitles
.PARAMETER SkipThumbnails
.PARAMETER SkipDates
.PARAMETER SkipCounts
.PARAMETER SkipSitemap
.PARAMETER SkipValidate
  それぞれのステップをスキップします。

.EXAMPLE
  .\update-site.ps1
  APIキーが環境変数にあれば全ステップを実行します。無ければ1・2は自動スキップし、
  3・4は既存キャッシュの反映のみ(-ApplyOnly相当)を行います。

.EXAMPLE
  .\update-site.ps1 -ApiKey "AIza..." -Limit 50
  50件だけ試しに新規取得しつつ全ステップを実行します。

.EXAMPLE
  .\update-site.ps1 -SkipDiscover -SkipTitles -DryRun
  API調査系(1・2)を省き、3・4は書き込みせず予定件数だけ確認します。
#>
param(
  [string]$ApiKey = $env:YOUTUBE_API_KEY,
  [int]$Limit = 0,
  [switch]$Force,
  [switch]$DryRun,
  [switch]$SkipDiscover,
  [switch]$SkipTitles,
  [switch]$SkipThumbnails,
  [switch]$SkipDates,
  [switch]$SkipCounts,
  [switch]$SkipSitemap,
  [switch]$SkipValidate
)

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot

# 子プロセスにだけAPIキーを渡す(このプロセス自身のコマンドライン引数には
# APIキーを含めない。子プロセスは各スクリプト側の `$env:YOUTUBE_API_KEY` 既定値で
# 自動的に読み取る)。
if ($ApiKey) { $env:YOUTUBE_API_KEY = $ApiKey }
$hasApiKey = [bool]$ApiKey

$results = New-Object System.Collections.Generic.List[object]

function Invoke-Step {
  param(
    [string]$Name,
    [string]$ScriptFile,
    [string[]]$ScriptArgs = @()
  )
  Write-Output ""
  Write-Output "===== $Name ====="
  $scriptPath = Join-Path $scriptDir $ScriptFile
  if (-not (Test-Path $scriptPath)) {
    Write-Warning "$ScriptFile が見つかりません。スキップします。"
    $results.Add([PSCustomObject]@{ Step = $Name; Status = "MISSING" })
    return
  }
  try {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath @ScriptArgs
    if ($LASTEXITCODE -ne 0) {
      throw "終了コード $LASTEXITCODE"
    }
    $results.Add([PSCustomObject]@{ Step = $Name; Status = "OK" })
  } catch {
    $results.Add([PSCustomObject]@{ Step = $Name; Status = "FAILED"; Detail = $_.Exception.Message })
    Write-Warning "[$Name] でエラーが発生しました: $($_.Exception.Message)"
  }
}

function Add-Skipped {
  param([string]$Name, [string]$Reason)
  Write-Output ""
  Write-Output "===== $Name ====="
  Write-Output "(スキップ: $Reason)"
  $results.Add([PSCustomObject]@{ Step = $Name; Status = "SKIP"; Detail = $Reason })
}

# ---- 1. 新規再生リスト取得(確認用JSON出力のみ) ----
if ($SkipDiscover) {
  Add-Skipped "1. 新規再生リスト取得" "-SkipDiscover"
} elseif (-not $hasApiKey) {
  Add-Skipped "1. 新規再生リスト取得" "APIキー未指定のため実行不可"
} else {
  Invoke-Step "1. 新規再生リスト取得" "discover-playlists.ps1"
}

# ---- 2. 動画タイトル取得(確認用JSON出力のみ) ----
if ($SkipTitles) {
  Add-Skipped "2. 動画タイトル取得" "-SkipTitles"
} elseif (-not $hasApiKey) {
  Add-Skipped "2. 動画タイトル取得" "APIキー未指定のため実行不可"
} else {
  Invoke-Step "2. 動画タイトル取得" "fetch-video-titles.ps1"
}

# ---- 3. サムネイル取得(data-playlists.js を更新) ----
if ($SkipThumbnails) {
  Add-Skipped "3. サムネイル取得" "-SkipThumbnails"
} else {
  $thumbArgs = @()
  if ($DryRun) { $thumbArgs += "-DryRun" }
  if ($Force) { $thumbArgs += "-Force" }
  if ($Limit -gt 0) { $thumbArgs += "-Limit"; $thumbArgs += $Limit }
  if (-not $hasApiKey) { $thumbArgs += "-ApplyOnly" }
  Invoke-Step "3. サムネイル取得" "fetch-thumbnails.ps1" $thumbArgs
}

# ---- 4. 更新日取得(data-playlists.js を更新) ----
if ($SkipDates) {
  Add-Skipped "4. 更新日取得" "-SkipDates"
} else {
  $dateArgs = @()
  if ($DryRun) { $dateArgs += "-DryRun" }
  if ($Force) { $dateArgs += "-Force" }
  if ($Limit -gt 0) { $dateArgs += "-Limit"; $dateArgs += $Limit }
  if (-not $hasApiKey) { $dateArgs += "-ApplyOnly" }
  Invoke-Step "4. 更新日取得" "update-dates.ps1" $dateArgs
}

# ---- 5. 件数再集計 ----
if ($SkipCounts) {
  Add-Skipped "5. 件数再集計" "-SkipCounts"
} else {
  Invoke-Step "5. 件数再集計" "generate-counts.ps1"
}

# ---- 6. sitemap再生成 ----
if ($SkipSitemap) {
  Add-Skipped "6. sitemap再生成" "-SkipSitemap"
} else {
  Invoke-Step "6. sitemap再生成" "generate-sitemap.ps1"
}

# ---- 7. データ検証 ----
if ($SkipValidate) {
  Add-Skipped "7. データ検証" "-SkipValidate"
} else {
  Invoke-Step "7. データ検証" "validate-data.ps1"
}

# ---- 実行結果まとめ ----
Write-Output ""
Write-Output "===== 実行結果まとめ ====="
foreach ($r in $results) {
  $detail = if ($r.Detail) { " - $($r.Detail)" } else { "" }
  Write-Output ("{0,-20} {1}{2}" -f $r.Step, $r.Status, $detail)
}

$failed = @($results | Where-Object { $_.Status -eq "FAILED" })
if ($failed.Count -gt 0) {
  Write-Output ""
  Write-Warning "失敗したステップがあります:"
  foreach ($f in $failed) { Write-Warning ("  [$($f.Step)] $($f.Detail)") }
  exit 1
}

Write-Output ""
Write-Output "すべてのステップが完了しました(SKIPを除く)。"
exit 0
