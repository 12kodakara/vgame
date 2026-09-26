<#
.SYNOPSIS
  公開前チェック。初心者向けに、サイトの主要ファイル・リンク切れ・SEO設定漏れなどを
  自動確認します。

.DESCRIPTION
  読み取り専用のチェックです。ファイルは一切書き換えません。

  ERROR(公開を止めた方がよいもの):
    - index.html 等、主要HTMLが無い
    - style.css / common.js / data-core.js 等、必須ファイルが無い
    - HTMLから読み込まれているはずのCSS/JSファイルが実際には無い(壊れた内部リンク)
    - sitemap.xml / robots.txt が無い
    - JavaScriptファイルの括弧([]・()・{})の対応が崩れている(簡易チェック。
      詳しくは下記「JavaScriptチェックについて」を参照)

  WARNING(公開はできるが確認した方がよいもの):
    - example.com が残っている(本番URL未設定)
    - og-image.png が無い
    - favicon の設定が主要ページに無い
    - お問い合わせ・任意画像(apple-touch-icon.png等)が無い
    - GA4タグ(gtag.js)が無い/1ページに複数ある/測定IDが想定と異なる
    - フッターにabout/operator/privacy/contactへのリンクが無いページがある
    - about/operator/privacy/contactのcanonicalが想定と異なる

  ERROR(広告の開示):
    - AdSense のコード(adsbygoogle.js)を読み込むページがあるのに、privacy.html に
      Google AdSense の必須開示(第三者配信事業者の Cookie 利用・広告設定での
      オプトアウト・広告に関する Google のポリシーへのリンク)が揃っていない
    - privacy.html が広告を「今後利用する場合がある」等の未導入前提で書かれたままになっている

  最後に ERROR件数 / WARNING件数 をまとめて表示します。ERRORが0件であれば
  「公開前チェックに重大な問題はありません。」と表示します。

.PARAMETER Path
  チェック対象フォルダ。省略時はこのスクリプトがあるフォルダ(開発用フォルダ)。
  build-public.ps1 で作った public フォルダを確認したい場合は
  ".\check-site.ps1 -Path .\public" のように指定してください。

.EXAMPLE
  .\check-site.ps1

.EXAMPLE
  .\check-site.ps1 -Path .\public

.NOTES
  JavaScriptチェックについて:
  Node.jsを必須にしないため、このスクリプトは完全なJS構文解析ではなく
  「括弧の対応が取れているか」を確認する簡易チェックです(正規表現リテラル・
  テンプレート文字列もある程度考慮していますが、完全ではありません)。
  より確実に確認したい場合は、以下のいずれかを行ってください。
    - Node.js がインストールされていれば: node --check ファイル名.js
    - ブラウザで該当ページを開き、F12キーでDevToolsのコンソールに
      赤いエラーが出ていないか確認する
#>
param(
  [string]$Path = ""
)

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($Path)) {
  $targetDir = $scriptDir
} else {
  $targetDir = (Resolve-Path $Path).Path
}

Write-Output "=== ぶいゲー 公開前チェック (check-site.ps1) ==="
Write-Output "チェック対象フォルダ: $targetDir"
Write-Output ""

$errorList = New-Object System.Collections.Generic.List[string]
$warningList = New-Object System.Collections.Generic.List[string]

function Add-CheckError([string]$Message) { [void]$errorList.Add($Message) }
function Add-CheckWarning([string]$Message) { [void]$warningList.Add($Message) }

function Test-FileExists([string]$RelativePath) {
  return Test-Path (Join-Path $targetDir $RelativePath)
}

# ---- 1. 主要HTMLの存在確認 ----
$requiredHtml = @(
  "index.html", "games.html", "games-row.html", "game.html",
  "streamers.html", "streamer.html", "playlists.html", "singles.html",
  "ranking.html", "new.html", "search.html", "404.html",
  "about.html", "operator.html", "privacy.html", "contact.html"
)
foreach ($f in $requiredHtml) {
  if (-not (Test-FileExists $f)) { Add-CheckError "主要HTMLが見つかりません: $f" }
}

# ---- 2. 必須CSS/JSの存在確認 ----
$requiredAssets = @(
  "style.css", "common.js", "data-core.js", "data-counts.js",
  "data-playlists.js", "data-standalone.js"
)
foreach ($f in $requiredAssets) {
  if (-not (Test-FileExists $f)) { Add-CheckError "必須ファイルが見つかりません: $f" }
}

# ---- 3. sitemap.xml / robots.txt の存在確認 ----
if (-not (Test-FileExists "sitemap.xml")) { Add-CheckError "sitemap.xml が見つかりません。generate-sitemap.ps1 を実行してください。" }
if (-not (Test-FileExists "robots.txt")) { Add-CheckError "robots.txt が見つかりません。" }

# ---- 4. 壊れた内部リンク確認(HTMLが読み込む script src / link href をチェック) ----
$htmlFilesOnDisk = Get-ChildItem -Path $targetDir -Filter "*.html" -File -ErrorAction SilentlyContinue
foreach ($htmlFile in $htmlFilesOnDisk) {
  $html = [System.IO.File]::ReadAllText($htmlFile.FullName, [System.Text.Encoding]::UTF8)
  $refs = [regex]::Matches($html, '(?:src|href)\s*=\s*"([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
  foreach ($ref in $refs) {
    if ($ref -match '^(https?:)?//' -or $ref -match '^(data|mailto):' -or $ref -match '^#' -or $ref -eq "" ) { continue }
    if ($ref -notmatch '\.(css|js)$') { continue }  # png/jpg等は現状ローカル参照が無いため対象外(将来images/等が増えたら拡張可)
    $refPath = ($ref -split '[?#]')[0]
    $resolved = Join-Path $htmlFile.DirectoryName $refPath
    if (-not (Test-Path $resolved)) {
      Add-CheckError "壊れたリンク: $($htmlFile.Name) が参照する `"$ref`" が見つかりません"
    }
  }
}

# ---- 5. example.com 残存チェック ----
$exampleComFiles = @()
Get-ChildItem -Path $targetDir -Recurse -File -Include "*.html", "*.js", "*.xml", "*.txt" -ErrorAction SilentlyContinue | ForEach-Object {
  $text = [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8)
  if ($text -match "example\.com") {
    $exampleComFiles += $_.FullName.Substring($targetDir.Length).TrimStart("\", "/")
  }
}
if ($exampleComFiles.Count -gt 0) {
  Add-CheckWarning ("本番URLが設定されていません(example.com が " + $exampleComFiles.Count + " ファイルに残っています)")
}

# ---- 6. og-image.png の存在確認 ----
$hasOgImage = (Test-FileExists "og-image.png") -or (Test-FileExists "og-image.jpg")
if (-not $hasOgImage) {
  Add-CheckWarning "og-image.png が見つかりません(SNSシェア時の画像が表示されません。1200x630pxのPNG/JPGを用意してください)"
}

# ---- 7. favicon の設定確認(主要ページに rel=icon があるか) ----
$missingFavicon = @()
foreach ($f in $requiredHtml) {
  $p = Join-Path $targetDir $f
  if (Test-Path $p) {
    $html = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
    if ($html -notmatch 'rel="icon"') { $missingFavicon += $f }
  }
}
if ($missingFavicon.Count -gt 0) {
  Add-CheckWarning ("favicon(rel=`"icon`")の設定が無いページがあります: " + ($missingFavicon -join ", "))
}

# ---- 8. 任意画像(apple-touch-icon.png等)の存在確認 ----
if (-not (Test-FileExists "apple-touch-icon.png")) {
  Add-CheckWarning "apple-touch-icon.png が見つかりません(iPhone/iPad のホーム画面アイコン用。無くても閲覧・検索には影響しません)"
}

# ---- 9. JavaScript構文の簡易チェック(括弧の対応のみ。詳細は末尾の注記を参照) ----
# 文字列("..."/'...'/`...`)・コメント(//, /* */)・正規表現リテラル(/.../)の中身は
# 対象から除外したうえで、() [] {} の対応が取れているかだけを確認する。
function Test-JsBracketBalance {
  param([string]$Text, [string]$FileName)

  $stack = New-Object System.Collections.Generic.Stack[System.Object]
  $len = $Text.Length
  $i = 0
  $lastSignificant = ""
  $line = 1

  while ($i -lt $len) {
    $c = $Text[$i]

    if ($c -eq "`n") { $line++; $i++; continue }

    # 行コメント
    if ($c -eq '/' -and $i + 1 -lt $len -and $Text[$i + 1] -eq '/') {
      while ($i -lt $len -and $Text[$i] -ne "`n") { $i++ }
      continue
    }
    # ブロックコメント
    if ($c -eq '/' -and $i + 1 -lt $len -and $Text[$i + 1] -eq '*') {
      $i += 2
      while ($i + 1 -lt $len -and -not ($Text[$i] -eq '*' -and $Text[$i + 1] -eq '/')) {
        if ($Text[$i] -eq "`n") { $line++ }
        $i++
      }
      $i += 2
      continue
    }
    # 文字列("..." / '...')
    if ($c -eq '"' -or $c -eq "'") {
      $quote = $c
      $i++
      while ($i -lt $len -and $Text[$i] -ne $quote) {
        if ($Text[$i] -eq '\') { $i++ }
        if ($i -lt $len -and $Text[$i] -eq "`n") { $line++ }
        $i++
      }
      $i++
      $lastSignificant = $quote
      continue
    }
    # テンプレート文字列(`...`、${...} の中は簡易的に無視する)
    if ($c -eq '`') {
      $i++
      $mode = "literal"
      $exprDepth = 0
      while ($i -lt $len) {
        $cc = $Text[$i]
        if ($cc -eq "`n") { $line++ }
        if ($mode -eq "literal") {
          if ($cc -eq '\') { $i += 2; continue }
          if ($cc -eq '`') { $i++; break }
          if ($cc -eq '$' -and $i + 1 -lt $len -and $Text[$i + 1] -eq '{') { $mode = "expr"; $exprDepth = 1; $i += 2; continue }
          $i++
        } else {
          if ($cc -eq '{') { $exprDepth++; $i++; continue }
          if ($cc -eq '}') { $exprDepth--; if ($exprDepth -eq 0) { $mode = "literal" }; $i++; continue }
          $i++
        }
      }
      $lastSignificant = '`'
      continue
    }
    # 正規表現リテラル(直前の文字から、割り算の "/" ではなく正規表現の "/" と
    # 推測できる場合のみ。完全な判定ではないが実用上十分な簡易ヒューリスティック)
    if ($c -eq '/' -and $lastSignificant -notmatch '^[A-Za-z0-9_\$\)\]\}]$') {
      $i++
      $inClass = $false
      $closed = $false
      while ($i -lt $len) {
        $cc = $Text[$i]
        if ($cc -eq "`n") { break }
        if ($cc -eq '\') { $i += 2; continue }
        if ($cc -eq '[') { $inClass = $true; $i++; continue }
        if ($cc -eq ']') { $inClass = $false; $i++; continue }
        if ($cc -eq '/' -and -not $inClass) { $i++; $closed = $true; break }
        $i++
      }
      if ($closed) {
        while ($i -lt $len -and $Text[$i] -match '[A-Za-z]') { $i++ }
        $lastSignificant = '/'
        continue
      }
      # 閉じる "/" が見つからなかった場合は正規表現ではなかった可能性が高いので、
      # 割り算の "/" として扱い1文字だけ読み進める(誤検知による誤爆を避けるため)。
      $lastSignificant = '/'
      continue
    }

    if ($c -eq '(' -or $c -eq '[' -or $c -eq '{') {
      $stack.Push([PSCustomObject]@{ Char = $c; Line = $line })
    } elseif ($c -eq ')' -or $c -eq ']' -or $c -eq '}') {
      $expected = @{ ')' = '('; ']' = '['; '}' = '{' }[[string]$c]
      if ($stack.Count -eq 0) {
        return "$FileName : $line 行目付近で閉じ括弧 `"$c`" に対応する開き括弧が見つかりません"
      }
      $top = $stack.Pop()
      if ($top.Char -ne $expected) {
        return "$FileName : $line 行目付近の `"$c`" が $($top.Line) 行目の `"$($top.Char)`" と対応していません"
      }
    }

    if ($c -notmatch '\s') { $lastSignificant = $c }
    $i++
  }

  if ($stack.Count -gt 0) {
    $top = $stack.Pop()
    return "$FileName : $($top.Line) 行目付近の `"$($top.Char)`" が閉じられていません"
  }
  return $null
}

$jsFilesOnDisk = Get-ChildItem -Path $targetDir -Filter "*.js" -File -ErrorAction SilentlyContinue
foreach ($jsFile in $jsFilesOnDisk) {
  $text = [System.IO.File]::ReadAllText($jsFile.FullName, [System.Text.Encoding]::UTF8)
  $result = Test-JsBracketBalance -Text $text -FileName $jsFile.Name
  if ($result) { Add-CheckError "JavaScript構文の疑い: $result" }
}

# ---- 10. GA4(Googleタグ)の設置確認 ----
# 公開HTMLそれぞれに gtag.js が「1つだけ」設置されていること、測定IDが
# 想定どおりであることを確認する(二重計測・タイプミスの検出が目的)。
$expectedGaId = "G-D3FY26G29X"
$gaMissing = @()
$gaDuplicate = @()
$gaWrongId = @()
foreach ($f in $requiredHtml) {
  $p = Join-Path $targetDir $f
  if (-not (Test-Path $p)) { continue }
  $html = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
  $gaMatches = [regex]::Matches($html, 'googletagmanager\.com/gtag/js\?id=([A-Za-z0-9\-]+)')
  if ($gaMatches.Count -eq 0) {
    $gaMissing += $f
  } elseif ($gaMatches.Count -gt 1) {
    $gaDuplicate += $f
  } elseif ($gaMatches[0].Groups[1].Value -ne $expectedGaId) {
    $gaWrongId += ("$f (見つかったID: " + $gaMatches[0].Groups[1].Value + ")")
  }
}
if ($gaMissing.Count -gt 0) {
  Add-CheckWarning ("GA4タグ(gtag.js)が見つからないページがあります: " + ($gaMissing -join ", "))
}
if ($gaDuplicate.Count -gt 0) {
  Add-CheckWarning ("GA4タグ(gtag.js)が1ページに複数設置されています(二重計測の可能性): " + ($gaDuplicate -join ", "))
}
if ($gaWrongId.Count -gt 0) {
  Add-CheckWarning ("GA4測定IDが想定(" + $expectedGaId + ")と異なるページがあります: " + ($gaWrongId -join ", "))
}

# ---- 11. フッターの共通ページリンク確認 ----
# 全公開ページのフッターから「サイトについて/運営者情報/プライバシーポリシー/
# お問い合わせ」へリンクされているかを確認する(信頼性向上ページの実効性チェック)。
$footerRequiredPages = @("about.html", "operator.html", "privacy.html", "contact.html")
$missingFooterLinks = @()
foreach ($f in $requiredHtml) {
  $p = Join-Path $targetDir $f
  if (-not (Test-Path $p)) { continue }
  $html = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
  $footerMatch = [regex]::Match($html, '<footer[^>]*class="wiki-footer"[^>]*>[\s\S]*?</footer>')
  $footerHtml = if ($footerMatch.Success) { $footerMatch.Value } else { "" }
  $missing = @()
  foreach ($page in $footerRequiredPages) {
    if ($footerHtml -notmatch [regex]::Escape('href="' + $page + '"')) { $missing += $page }
  }
  if ($missing.Count -gt 0) {
    $missingFooterLinks += ("$f (" + ($missing -join ", ") + ")")
  }
}
if ($missingFooterLinks.Count -gt 0) {
  Add-CheckWarning ("フッターに主要ページへのリンクが無いページがあります: " + ($missingFooterLinks -join " / "))
}

# ---- 12. サイトについて/運営者情報/プライバシーポリシー/お問い合わせのcanonical確認 ----
$expectedSiteUrl = "https://vgame-navi.jp"
$staticContentPages = @("about.html", "operator.html", "privacy.html", "contact.html")
$wrongCanonical = @()
foreach ($f in $staticContentPages) {
  $p = Join-Path $targetDir $f
  if (-not (Test-Path $p)) { continue }
  $html = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
  $expected = "$expectedSiteUrl/$f"
  $m = [regex]::Match($html, '<link rel="canonical" href="([^"]+)">')
  if (-not $m.Success -or $m.Groups[1].Value -ne $expected) {
    $found = if ($m.Success) { $m.Groups[1].Value } else { "(見つかりません)" }
    $wrongCanonical += "$f (期待値: $expected / 実際: $found)"
  }
}
if ($wrongCanonical.Count -gt 0) {
  Add-CheckWarning ("canonicalが想定と異なるページがあります: " + ($wrongCanonical -join " / "))
}

# ---- AdSense 導入時のプライバシーポリシー開示 ----
#   AdSense のコードを読み込んでいるのに、プライバシーポリシーが必須開示を欠いていると
#   審査・運用上の問題になるため ERROR にする(広告を外した場合はこの検査は何もしない)。
$adsensePages = @()
foreach ($htmlFile in (Get-ChildItem -Path $targetDir -Filter "*.html" -File)) {
  $h = [System.IO.File]::ReadAllText($htmlFile.FullName, [System.Text.Encoding]::UTF8)
  if ($h -match 'pagead2\.googlesyndication\.com/pagead/js/adsbygoogle\.js') { $adsensePages += $htmlFile.Name }
}
$privacyPath = Join-Path $targetDir "privacy.html"
if ($adsensePages.Count -gt 0 -and (Test-Path $privacyPath)) {
  $ph = [System.IO.File]::ReadAllText($privacyPath, [System.Text.Encoding]::UTF8)
  $required = [ordered]@{
    "Google AdSense の利用の明記"                     = 'Google AdSense'
    "第三者配信事業者(Google を含む)による Cookie 利用" = '第三者配信事業者'
    "Google の広告設定(オプトアウト)へのリンク"       = 'https://adssettings\.google\.com'
    "第三者Cookieのオプトアウト(aboutads.info)へのリンク" = 'https://optout\.aboutads\.info'
    "広告に関する Google のポリシーへのリンク"        = 'https://policies\.google\.com/technologies/ads'
  }
  $missingDisclosure = @()
  foreach ($k in $required.Keys) { if ($ph -notmatch $required[$k]) { $missingDisclosure += $k } }
  if ($missingDisclosure.Count -gt 0) {
    Add-CheckError ("AdSense のコードを読み込むページ(" + $adsensePages.Count + "件)があるのに、privacy.html に必須開示がありません: " + ($missingDisclosure -join " / "))
  }
  if ($ph -match '今後、?Google AdSense' -or $ph -match '広告配信サービスを導入した際は') {
    Add-CheckError "privacy.html の広告の説明が「今後利用する場合がある」等の未導入前提のままです(AdSense のコードは読み込み済み)"
  }
}

# ---- トップページ用の事前集計(data-home.js)の鮮度 ----
#   トップページは data-playlists.js の代わりに data-home.js で初期表示するため、
#   data-playlists.js を更新したのに作り直していないと古い「最近更新」等が出る。
#   node が不一致を標準エラーに出すと、$ErrorActionPreference = "Stop" の下では PowerShell 5.1 が
#   それをエラーとして扱い、このスクリプト自体が止まってしまう。判定は終了コードで行うため、
#   ここだけ Continue にして出力を捨てる。
function Test-GeneratedDataFresh([string]$generator) {
  $prev = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try { $null = & node $generator --check 2>&1; return ($LASTEXITCODE -eq 0) }
  finally { $ErrorActionPreference = $prev }
}
$homeGen = Join-Path $targetDir "generate-home-data.js"
if ((Test-Path (Join-Path $targetDir "data-home.js")) -and (Test-Path $homeGen)) {
  if (Get-Command node -ErrorAction SilentlyContinue) {
    if (-not (Test-GeneratedDataFresh $homeGen)) { Add-CheckError "data-home.js が data-playlists.js と一致しません。node generate-home-data.js を実行してください。" }
    $detailGen = Join-Path $targetDir "generate-detail-data.js"
    if (Test-Path $detailGen) {
      if (-not (Test-GeneratedDataFresh $detailGen)) { Add-CheckError "詳細ページ用データ(data/games・data/streamers)が data-playlists.js と一致しません。node generate-detail-data.js を実行してください。" }
    }
    $listGen = Join-Path $targetDir "generate-list-data.js"
    if (Test-Path $listGen) {
      if (-not (Test-GeneratedDataFresh $listGen)) { Add-CheckError "人気ランキング・新着用データ(data-ranking.js / data-new.js)が data-playlists.js と一致しません。node generate-list-data.js を実行してください。" }
    }
    $genreGen = Join-Path $targetDir "generate-genre-data.js"
    if (Test-Path $genreGen) {
      if (-not (Test-GeneratedDataFresh $genreGen)) { Add-CheckError "ジャンル別ページ用データ(data-genres.js)が data-playlists.js と一致しません。node generate-genre-data.js を実行してください。" }
    }
  } else {
    Add-CheckWarning "Node.js が無いため data-home.js の鮮度を確認できませんでした。"
  }
}

# ---- 結果表示 ----
Write-Output "ERROR:"
if ($errorList.Count -gt 0) {
  $errorList | ForEach-Object { Write-Output "  - $_" }
} else {
  Write-Output "  なし"
}
Write-Output ""
Write-Output "WARNING:"
if ($warningList.Count -gt 0) {
  $warningList | ForEach-Object { Write-Output "  - $_" }
} else {
  Write-Output "  なし"
}
Write-Output ""
Write-Output ("ERROR: " + $errorList.Count)
Write-Output ("WARNING: " + $warningList.Count)
Write-Output ""

if ($errorList.Count -eq 0) {
  Write-Output "公開前チェックに重大な問題はありません。"
  exit 0
} else {
  Write-Output "ERRORが解消されるまで、公開は見送ることをおすすめします。"
  exit 1
}
