<#
.SYNOPSIS
  decrypt-report.ps1(暗号化済みレポートの復号)のテスト。本物の鍵は使わず、テスト用の使い捨ての鍵ペアを一時フォルダに作る。
  age が無い場合はスキップする。
    .\tools\search-console\test_decrypt_report.ps1
#>
$ErrorActionPreference = "Stop"
$script:pass = 0; $script:fail = 0
function Check([string]$name, [bool]$ok, [string]$detail = "") {
  if ($ok) { $script:pass++; Write-Output "  [PASS] $name" } else { $script:fail++; Write-Output "  [FAIL] $name"; if ($detail) { Write-Output "         $detail" } }
}
Write-Output "=== 暗号化済みレポートの復号(decrypt-report.ps1)テスト ==="
if (-not (Get-Command age -ErrorAction SilentlyContinue) -or -not (Get-Command age-keygen -ErrorAction SilentlyContinue)) { Write-Output "  age が無いためスキップ"; exit 0 }

$script = Join-Path $PSScriptRoot "decrypt-report.ps1"
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("decrypt-test-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Path $tmp | Out-Null
function Run-Decrypt([string[]]$argv) {
  $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  try { $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $script @argv 2>&1 | ForEach-Object { "$_" }; return @{ code = $LASTEXITCODE; text = ($out -join "`n") } }
  finally { $ErrorActionPreference = $prev }
}
try {
  # テスト用の鍵ペア(本物の鍵とは無関係)
  $key = Join-Path $tmp "test.key"; $key2 = Join-Path $tmp "other.key"
  $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  & age-keygen -o $key 2>$null | Out-Null; & age-keygen -o $key2 2>$null | Out-Null
  $pub = (& age-keygen -y $key).Trim()
  $ErrorActionPreference = $prev
  # ワークフローと同じ形の暗号化済みレポートを作る(gsc-report/ を tar.gz にして age で暗号化 → Artifacts の zip)
  $src = Join-Path $tmp "runner"; $report = Join-Path $src "gsc-report"
  New-Item -ItemType Directory -Path $report -Force | Out-Null
  '{"site":"sc-domain:example","apiRequests":24,"errors":[],"complete":true}' | Set-Content -LiteralPath (Join-Path $report "summary.json") -Encoding UTF8
  "page,clicks`nhttps://vgame-navi.jp/,1" | Set-Content -LiteralPath (Join-Path $report "28d_pages.csv") -Encoding UTF8
  $tarGz = Join-Path $tmp "r.tar.gz"
  & tar -C $src -czf $tarGz gsc-report
  $up = Join-Path $tmp "upload"; New-Item -ItemType Directory -Path $up | Out-Null
  $age = Join-Path $up "search-console-report-20261012-run7.tar.gz.age"
  & age -r $pub -o $age $tarGz
  Check "0. 暗号文は age の形式(先頭が age-encryption.org/v1)で、平文の内容を含まない" `
    (([Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($age)[0..20])) -eq "age-encryption.org/v1" -and -not ([Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($age))).Contains("vgame-navi.jp"))
  $zip = Join-Path $tmp "search-console-report-7.zip"
  Compress-Archive -Path $age -DestinationPath $zip

  # 1. zip(Artifacts)から復号・展開
  $outRoot = Join-Path $tmp "reports"
  $r = Run-Decrypt @($zip, "-KeyFile", $key, "-OutRoot", $outRoot)
  $dest = Join-Path $outRoot "actions-search-console-report-20261012-run7"
  Check "1. Artifacts の zip を復号して展開できる(CSV・summary.json)" ($r.code -eq 0 -and (Test-Path (Join-Path $dest "summary.json")) -and (Test-Path (Join-Path $dest "28d_pages.csv"))) $r.text
  # 2. .age を直接
  $r2 = Run-Decrypt @($age, "-KeyFile", $key, "-OutRoot", (Join-Path $tmp "reports2"))
  Check "2. .tar.gz.age を直接指定しても復号できる" ($r2.code -eq 0 -and (Test-Path (Join-Path $tmp "reports2\actions-search-console-report-20261012-run7\summary.json"))) $r2.text
  # 3. 既にあれば上書きしない(-Force で上書き)
  $r3 = Run-Decrypt @($zip, "-KeyFile", $key, "-OutRoot", $outRoot)
  $r3b = Run-Decrypt @($zip, "-KeyFile", $key, "-OutRoot", $outRoot, "-Force")
  Check "3. 展開先が既にあれば上書きしない(-Force のときだけ上書き)" ($r3.code -ne 0 -and $r3.text -match "既にあります" -and $r3b.code -eq 0)
  # 4. 鍵が違う
  $r4 = Run-Decrypt @($zip, "-KeyFile", $key2, "-OutRoot", (Join-Path $tmp "reports4"))
  Check "4. 鍵が違うと復号できず、展開先を作らない" ($r4.code -ne 0 -and $r4.text -match "復号できませんでした" -and -not (Test-Path (Join-Path $tmp "reports4\actions-search-console-report-20261012-run7")))
  # 5. リポジトリの中には展開しない
  $r5 = Run-Decrypt @($zip, "-KeyFile", $key, "-OutRoot", (Join-Path $repoRoot "reports\decrypt-test"))
  Check "5. 展開先がリポジトリの中なら止める" ($r5.code -ne 0 -and $r5.text -match "リポジトリの中" -and -not (Test-Path (Join-Path $repoRoot "reports\decrypt-test")))
  # 6. 鍵が無い・zip の中身が違う
  $r6 = Run-Decrypt @($zip, "-KeyFile", (Join-Path $tmp "none.key"), "-OutRoot", (Join-Path $tmp "r6"))
  $badZip = Join-Path $tmp "bad.zip"; Compress-Archive -Path (Join-Path $report "summary.json") -DestinationPath $badZip
  $r6b = Run-Decrypt @($badZip, "-KeyFile", $key, "-OutRoot", (Join-Path $tmp "r6b"))
  Check "6. 秘密鍵が無い・zip に暗号化済みレポートが無いときは止める" ($r6.code -ne 0 -and $r6.text -match "秘密鍵が見つかりません" -and $r6b.code -ne 0 -and $r6b.text -match "1つだけ入っていません")
  # 7. 秘密鍵の内容を表示しない・作業用の一時ファイルを残さない
  $secretLine = (Get-Content -LiteralPath $key | Where-Object { $_ -match '^AGE-SECRET-KEY-' })
  $all = ($r.text, $r2.text, $r3.text, $r4.text, $r5.text, $r6.text, $r6b.text) -join "`n"
  $left = @(Get-ChildItem -LiteralPath ([IO.Path]::GetTempPath()) -Directory -Filter "vgame-gsc-*" -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-5) })
  Check "7. 秘密鍵を表示せず、復号した tar.gz・作業フォルダを残さない" ($secretLine -and -not $all.Contains($secretLine) -and $all -notmatch "AGE-SECRET-KEY" -and $left.Count -eq 0) "残り: $($left.Count)"
} finally {
  Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Output ""
Write-Output "PASS: $script:pass  FAIL: $script:fail"
if ($script:fail -gt 0) { exit 1 } else { exit 0 }
