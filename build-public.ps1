<#
.SYNOPSIS
  Web公開に必要なファイルだけを public フォルダへコピーします(公開用ビルド)。

.DESCRIPTION
  このフォルダには、サイト表示に実際に必要なファイル(HTML/CSS/JS/データ/
  robots.txt/sitemap.xml)のほかに、サイト運営者がローカルで使うツール
  (*.ps1、README等のMarkdown、データ取得用キャッシュJSON、社内向け管理ツール
  admin-standalone.html/js)が混在しています。

  このスクリプトは「実際にブラウザ表示に必要なファイルだけ」を厳選して
  public フォルダへコピーします。public フォルダの中身だけを、そのまま
  レンタルサーバー・GitHub Pages・Netlify等へアップロードしてください。

  対象ファイルは決め打ちではなく、各HTMLの <script src="..."> / <link href="...">
  を実際に解析して「本当に読み込まれているファイルだけ」を集める方式です。
  ページ側でファイルを追加/削除した場合も、次回このスクリプトを実行すれば
  自動的に反映されます。

  実行しても、このフォルダ(public以外)の中身は一切変更・削除しません。
  public フォルダだけを毎回作り直します(既存の public は削除して作り直します)。

.EXAMPLE
  .\build-public.ps1
#>
param()

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$publicDir = Join-Path $scriptDir "public"

Write-Output "=== ぶいゲー 公開用ビルド (build-public.ps1) ==="
Write-Output ""

# ---- 安全確認: このフォルダが本当にサイトのフォルダかどうかを確認する ----
# (誤って別の場所で実行してプロジェクトルートを壊すことがないよう、
#  目印となるファイルが無ければ即座に中断する)
$markerFile = Join-Path $scriptDir "data-core.js"
if (-not (Test-Path $markerFile)) {
  Write-Error "data-core.js が見つかりません。このスクリプトは「サイト制作」フォルダ内で実行してください。安全のため処理を中断しました。"
  exit 1
}

# ---- 安全確認: 削除対象の public フォルダが、想定どおりの場所であることを確認する ----
# ($publicDir が必ず「このスクリプトのフォルダ\public」になっていることを再確認し、
#  万が一にもプロジェクトルートや親フォルダを削除してしまうことを防ぐ)
$expectedLeaf = "public"
if ((Split-Path $publicDir -Leaf) -ne $expectedLeaf -or -not $publicDir.StartsWith($scriptDir)) {
  Write-Error "public フォルダのパスが想定と異なります。安全のため処理を中断しました: $publicDir"
  exit 1
}

# ---- 公開に必要なファイル一覧(このサイトの構成を解析した実際の依存関係) ----

# ブラウザから直接開かれるHTMLページ(社内向け管理ツール admin-standalone.html は
# 一般公開が不要なため対象外)
$htmlFiles = @(
  "index.html", "games.html", "games-row.html", "game.html",
  "streamers.html", "streamer.html", "playlists.html", "singles.html",
  "ranking.html", "new.html", "search.html", "404.html",
  "about.html", "operator.html", "privacy.html", "contact.html"
)

# 見た目(CSS)
$cssFiles = @("style.css")

# ブラウザで実行されるJavaScript(データ本体 + 各ページ専用スクリプト + 共通処理)
$jsFiles = @(
  "data-core.js", "data-counts.js", "data-home.js", "data-playlists.js", "data-standalone.js",
  "data-game-editorial.js",
  "common.js", "home.js", "games.js", "games-row.js", "game.js",
  "streamers.js", "streamer.js", "playlists.js", "singles.js",
  "ranking.js", "new.js", "search.js"
)

# 検索エンジン向け設定
$seoFiles = @("robots.txt", "sitemap.xml", "ads.txt")

# 存在する場合だけコピーする任意ファイル(無くてもビルド自体は失敗させない)
$optionalFiles = @(
  "og-image.png", "og-image.jpg",
  "favicon.ico", "favicon.png", "favicon.svg",
  "apple-touch-icon.png"
)

# 公開に含めない主な開発・運営専用ファイル(レポート表示用。実際の除外は
# 「上の一覧に無いものはコピーしない」というホワイトリスト方式で行っている)
$excludedForReport = @(
  "*.ps1 (運営者がローカルで実行するツール一式)",
  "README.md / IMPROVEMENTS*.md / SEARCH-UPDATE.md / STANDALONE-TOOL.md (開発者向けドキュメント)",
  "*-cache.json (データ取得スクリプトの再開用キャッシュ)",
  "discovered-playlists.json / standalone-candidates*.json / video-titles-sample.json (登録候補の確認用の中間ファイル)",
  "admin-standalone.html / admin-standalone.js (社内向け管理ツール)",
  "*.txt のうち robots.txt 以外(手順メモ等)"
)

# トップページ用の事前集計(data-home.js)と詳細ページ用の分割データ(data/games・data/streamers)を
# 最新の data-playlists.js から作り直してからコピーする
if (Get-Command node -ErrorAction SilentlyContinue) {
  foreach ($gen in @("generate-home-data.js", "generate-detail-data.js")) {
    & node (Join-Path $scriptDir $gen)
    if ($LASTEXITCODE -ne 0) { Write-Error "$gen が失敗しました。"; exit 1 }
  }
} else {
  Write-Warning "Node.js が見つからないため data-home.js / data/ を再生成できませんでした(既存のファイルをそのまま使います)。"
}

$allTargets = New-Object System.Collections.Generic.List[string]
foreach ($f in $htmlFiles) { [void]$allTargets.Add($f) }
foreach ($f in $cssFiles) { [void]$allTargets.Add($f) }
foreach ($f in $jsFiles) { [void]$allTargets.Add($f) }
foreach ($f in $seoFiles) { [void]$allTargets.Add($f) }

# ---- 必須ファイルの存在チェック(1つでも無ければ中断) ----
$missingRequired = @()
foreach ($f in $allTargets) {
  $path = Join-Path $scriptDir $f
  if (-not (Test-Path $path)) { $missingRequired += $f }
}
if ($missingRequired.Count -gt 0) {
  Write-Error ("公開に必要な以下のファイルが見つかりません。処理を中断しました:`n  - " + ($missingRequired -join "`n  - "))
  exit 1
}

# ---- public フォルダを安全に作り直す ----
if (Test-Path $publicDir) {
  Write-Output "既存の public フォルダを削除して作り直します: $publicDir"
  Remove-Item -Path $publicDir -Recurse -Force -Confirm:$false
}
New-Item -ItemType Directory -Path $publicDir | Out-Null

# ---- コピー実行 ----
$copiedCount = 0
foreach ($f in $allTargets) {
  Copy-Item -Path (Join-Path $scriptDir $f) -Destination (Join-Path $publicDir $f) -Force
  $copiedCount++
}

$copiedOptional = @()
foreach ($f in $optionalFiles) {
  $src = Join-Path $scriptDir $f
  if (Test-Path $src) {
    Copy-Item -Path $src -Destination (Join-Path $publicDir $f) -Force
    $copiedCount++
    $copiedOptional += $f
  }
}

# 詳細ページ用の分割データ(data/games・data/streamers)。ゲーム詳細・VTuber詳細ページが読み込む。
$detailDataSrc = Join-Path $scriptDir "data"
foreach ($kind in @("games", "streamers")) {
  $src = Join-Path $detailDataSrc $kind
  if (-not (Test-Path $src)) { Write-Error "詳細ページ用データ data\$kind が見つかりません。node generate-detail-data.js を実行してください。"; exit 1 }
  $dst = Join-Path $publicDir ("data\" + $kind)
  New-Item -ItemType Directory -Path $dst -Force | Out-Null
  Get-ChildItem -Path $src -Filter "*.js" -File | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination (Join-Path $dst $_.Name) -Force
    $copiedCount++
  }
}

# サイト内でローカル画像を置く場合の慣例(例: images/streamers/○○.jpg)に備えて、
# images フォルダが存在する場合はまるごとコピーする(現状は無くてもエラーにしない)。
$imagesSrc = Join-Path $scriptDir "images"
if (Test-Path $imagesSrc) {
  Copy-Item -Path $imagesSrc -Destination (Join-Path $publicDir "images") -Recurse -Force
  Write-Output "images フォルダをコピーしました。"
}

# ---- example.com 残存チェック(本番URL未設定の警告) ----
$exampleComFiles = @()
Get-ChildItem -Path $publicDir -Recurse -File -Include "*.html", "*.js", "*.xml", "*.txt" | ForEach-Object {
  $text = [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8)
  if ($text -match "example\.com") {
    $exampleComFiles += $_.FullName.Substring($publicDir.Length + 1)
  }
}

# ---- 結果表示(初心者向けに日本語でわかりやすく) ----
Write-Output ""
Write-Output "=== ビルド完了 ==="
Write-Output "コピーしたファイル数     : $copiedCount"
Write-Output "public フォルダの場所    : $publicDir"
Write-Output ""
if ($copiedOptional.Count -gt 0) {
  Write-Output ("見つかったので含めた任意ファイル: " + ($copiedOptional -join ", "))
} else {
  Write-Output "og-image.png / favicon.ico 等の任意ファイルは見つからなかったため含めていません(無くてもサイトは動作します)。"
}
Write-Output ""
Write-Output "公開対象外にした主な開発・運営用ファイル:"
foreach ($item in $excludedForReport) { Write-Output "  - $item" }

Write-Output ""
if ($exampleComFiles.Count -gt 0) {
  Write-Warning "本番URLが設定されていません。公開前に SITE_URL を設定してください。"
  Write-Warning ("example.com が残っているファイル(" + $exampleComFiles.Count + "件):")
  $exampleComFiles | Select-Object -First 20 | ForEach-Object { Write-Warning "  - $_" }
  if ($exampleComFiles.Count -gt 20) { Write-Warning ("  ...ほか " + ($exampleComFiles.Count - 20) + " 件") }
  Write-Output "(SITE_URL の設定方法は README.md の「ドメインの設定」を参照してください。設定後、generate-sitemap.ps1 → build-public.ps1 の順に再実行してください)"
} else {
  Write-Output "example.com の残存チェック: 問題ありません。"
}

Write-Output ""
Write-Output "次に行う作業:"
Write-Output "  1. .\check-site.ps1 を実行して、公開前チェックにエラーが無いか確認してください。"
Write-Output "  2. public フォルダの中身を GitHub 等へアップロードしてください(public フォルダ自体ではなく中身をアップロードします)。"
Write-Output "  詳しい手順は README.md の「サイト公開までの手順」を参照してください。"
