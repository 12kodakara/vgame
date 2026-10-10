<#
.SYNOPSIS
  GitHub Actions(search-console-weekly)の暗号化済みレポートを、自宅PCの age 秘密鍵で復号して展開する。

.DESCRIPTION
  入力: Actions の Artifacts からダウンロードした zip(search-console-report-<番号>.zip)、または中の .tar.gz.age。
  出力: <OutRoot>\actions-<ファイル名>\ に CSV・JSON・summary.md を展開する(既定は %LOCALAPPDATA%\vgame-seo\reports。リポジトリの外)。
  秘密鍵は age に渡すだけで、内容は読まない・表示しない。復号した tar.gz は展開後に削除する。
  詳しい手順: tools\search-console\ENCRYPTION.md

.PARAMETER Path
  ダウンロードした zip、または .tar.gz.age のパス。
.PARAMETER KeyFile
  age の秘密鍵(既定: %LOCALAPPDATA%\vgame-seo\age\vgame-gsc.key)。
.PARAMETER OutRoot
  展開先の親フォルダ(既定: %LOCALAPPDATA%\vgame-seo\reports)。リポジトリの中は指定できない。
.PARAMETER Force
  展開先が既にあるとき上書きする。

.EXAMPLE
  .\tools\search-console\decrypt-report.ps1 "$env:USERPROFILE\Downloads\search-console-report-12.zip"
#>
param(
  [Parameter(Mandatory = $true)][string]$Path,
  [string]$KeyFile = (Join-Path $env:LOCALAPPDATA "vgame-seo\age\vgame-gsc.key"),
  [string]$OutRoot = (Join-Path $env:LOCALAPPDATA "vgame-seo\reports"),
  [switch]$Force
)
$ErrorActionPreference = "Stop"
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\..")).TrimEnd('\')

function Stop-WithMessage([string]$msg) { Write-Error $msg; exit 1 }

if (-not (Get-Command age -ErrorAction SilentlyContinue)) { Stop-WithMessage "age が見つかりません。winget install --id FiloSottile.age -e でインストールしてください" }
if (-not (Test-Path -LiteralPath $KeyFile -PathType Leaf)) { Stop-WithMessage "age の秘密鍵が見つかりません: $KeyFile" }
if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { Stop-WithMessage "ファイルが見つかりません: $Path" }

$outRootFull = [IO.Path]::GetFullPath($OutRoot).TrimEnd('\')
if ($outRootFull -ieq $repoRoot -or $outRootFull.StartsWith($repoRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
  Stop-WithMessage "展開先がリポジトリの中です。リポジトリの外を指定してください: $OutRoot"
}

$work = Join-Path ([IO.Path]::GetTempPath()) ("vgame-gsc-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Path $work | Out-Null
try {
  # zip(Artifacts)なら展開して中の .tar.gz.age を探す
  $src = (Resolve-Path -LiteralPath $Path).Path
  if ([IO.Path]::GetExtension($src) -ieq ".zip") {
    Expand-Archive -LiteralPath $src -DestinationPath (Join-Path $work "zip")
    $found = @(Get-ChildItem -LiteralPath (Join-Path $work "zip") -Recurse -File -Filter "*.tar.gz.age")
    if ($found.Count -ne 1) { Stop-WithMessage "zip の中に暗号化済みレポート(.tar.gz.age)が1つだけ入っていません(見つかった数: $($found.Count))" }
    $src = $found[0].FullName
  } elseif (-not $src.EndsWith(".tar.gz.age", [StringComparison]::OrdinalIgnoreCase)) {
    Stop-WithMessage "zip か .tar.gz.age を指定してください: $Path"
  }

  $base = [IO.Path]::GetFileName($src) -replace '\.tar\.gz\.age$', ''
  $dest = Join-Path $outRootFull ("actions-" + $base)
  if ((Test-Path -LiteralPath $dest) -and -not $Force) { Stop-WithMessage "展開先が既にあります(上書きするなら -Force): $dest" }

  # 復号(秘密鍵は age に渡すだけ)
  $tarGz = Join-Path $work "report.tar.gz"
  $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  & age -d -i $KeyFile -o $tarGz $src 2>$null
  $code = $LASTEXITCODE; $ErrorActionPreference = $prev
  if ($code -ne 0 -or -not (Test-Path -LiteralPath $tarGz)) { Stop-WithMessage "復号できませんでした(鍵が違うか、ファイルが壊れています)" }

  # 展開(中身は gsc-report\ フォルダ。Windows 標準の tar を使う)
  $extract = Join-Path $work "extract"
  New-Item -ItemType Directory -Path $extract | Out-Null
  & tar -xzf $tarGz -C $extract
  if ($LASTEXITCODE -ne 0) { Stop-WithMessage "展開できませんでした" }
  $inner = Join-Path $extract "gsc-report"
  if (-not (Test-Path -LiteralPath (Join-Path $inner "summary.json"))) { Stop-WithMessage "レポートの形式が違います(summary.json がありません)" }

  if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
  New-Item -ItemType Directory -Path $outRootFull -Force | Out-Null
  Move-Item -LiteralPath $inner -Destination $dest
  $count = @(Get-ChildItem -LiteralPath $dest -File).Count
  Write-Output "復号しました: $dest($count ファイル)"
} finally {
  # 復号した tar.gz と展開途中のファイルを残さない
  if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}
