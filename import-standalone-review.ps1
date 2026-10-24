<#
.SYNOPSIS
  確認シート(export-standalone-review.ps1 が書き出した CSV)の判断欄を読み、候補 JSON の status に反映します。
  既定は dry-run(変更予定を表示するだけで、どのファイルも書き換えない)。反映するには -Apply と -CandidatesPath の両方が必要です。
  YouTube API・RSS・Git には接続しません(rss-state への反映・push は別の操作で行う)。

.DESCRIPTION
  判断欄 decision(approve/hold/reject): approve → approved / hold → held / reject → rejected。空欄の行は何も変えない。
  照合は動画ID(videoIds 列)で行う。続き物(series)は、行の動画ID一式が、候補 JSON で同じ seriesKey の確認待ち候補と
  完全に一致することを確かめる(書き出した後に動画が増えた・減ったときは中止する)。excludeVideoIds に書いた動画は変更しない。
  次のどれか1つでもあれば、全体の取り込みを中止する(1件も反映しない):
    必要な列が無い / 判断欄の値が不正 / 行の種類が不正 / 動画IDの形式が不正 / 候補 JSON に無い動画ID /
    同じ動画IDが複数の行にある / 判断済み(pending 以外)の候補に判断を書いた / 行の種類と候補の分類が違う /
    続き物の動画の組が候補 JSON と違う / excludeVideoIds が行の動画に無い・続き物以外に書いてある /
    ゲーム実況でない可能性(non-gameplay)・分類なし(unclassified)の行に approve を書いた(この2種類は hold・reject だけ)
  反映するのは status と、確認の記録(reviewedAt・reviewBatch)だけ。作品名・ジャンル・備考などの下書き欄は書き込まない。
  書き込みは「元のファイルを .before-import-日時.json に残す → 一時ファイルに書く → 置き換え → 読み直して、
  変更した候補以外が元と同じかを確かめる(違えば元に戻す)」。

.PARAMETER CsvPath
  判断を記入した確認シート(CSV)。
.PARAMETER CandidatesPath
  候補 JSON のファイル。-Apply では必須(このファイルを書き換える)。dry-run で省略したときは -StateRef を git show で読む。
.PARAMETER StateRef
  dry-run で -CandidatesPath を省略したときに読む Git の参照(既定 origin/rss-state)。
.PARAMETER Apply
  指定したときだけ -CandidatesPath に反映する。
.EXAMPLE
  .\import-standalone-review.ps1 -CsvPath .\standalone-review-20261019.csv
  変更予定だけを表示する(dry-run)
.EXAMPLE
  .\import-standalone-review.ps1 -CsvPath .\standalone-review-20261019.csv -CandidatesPath ..\rss-state-wt\discovered-standalone-rss.json -Apply
#>
param(
  [Parameter(Mandatory = $true)][string]$CsvPath,
  [string]$CandidatesPath,
  [string]$StateRef = "origin/rss-state",
  [switch]$Apply
)

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
if ($Apply -and -not $CandidatesPath) { throw "-Apply には、書き換える候補 JSON(-CandidatesPath)の指定が必要です。何も変更していません。" }
if (-not (Test-Path -LiteralPath $CsvPath)) { throw "確認シートが見つかりません: $CsvPath" }

function ConvertFrom-ReviewJson([string]$text) {
  $text = $text.TrimStart([char]0xFEFF)
  if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey("DateKind")) { return , ($text | ConvertFrom-Json -DateKind String) }
  return , ($text | ConvertFrom-Json)
}
# 保存は watch-standalone-rss.ps1 と同じ書式にする(5.1 でも 7 と同じ: 2スペース・LF・キーの順序そのまま。差分を変えた候補だけにする)
#   その保存用の関数だけを watch-standalone-rss.ps1 から読み込む(読めなければ、何も変更せずに止める)
$watchPath = Join-Path $scriptDir "watch-standalone-rss.ps1"
if (-not (Test-Path -LiteralPath $watchPath)) { throw "保存処理を読み込めません(何も変更していません): $watchPath" }
$watchAst = [Management.Automation.Language.Parser]::ParseFile($watchPath, [ref]$null, [ref]$null)
foreach ($fn in $watchAst.FindAll({ param($a) $a -is [Management.Automation.Language.FunctionDefinitionAst] -and $a.Name -match '^(ConvertTo|Add)-StandaloneJson' }, $true)) { . ([scriptblock]::Create($fn.Extent.Text)) }
if (-not (Get-Command ConvertTo-StandaloneJsonText -ErrorAction SilentlyContinue)) { throw "保存処理(ConvertTo-StandaloneJsonText)が見つかりません(何も変更していません): $watchPath" }
function Get-GitShowText([string]$spec) {
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = "git"; $psi.Arguments = "-C `"$scriptDir`" show `"$spec`""
  $psi.UseShellExecute = $false; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
  $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
  $p = [Diagnostics.Process]::Start($psi)
  $out = $p.StandardOutput.ReadToEnd(); $err = $p.StandardError.ReadToEnd(); $p.WaitForExit()
  if ($p.ExitCode -ne 0) { throw "git show $spec に失敗しました: $err" }
  return $out
}
function Set-ObjProp($obj, [string]$name, $value) {
  if ($obj.PSObject.Properties[$name]) { $obj.$name = $value } else { $obj | Add-Member -NotePropertyName $name -NotePropertyValue $value }
}

$originalText = if ($CandidatesPath) { [IO.File]::ReadAllText($CandidatesPath, [Text.Encoding]::UTF8) } else { Get-GitShowText "${StateRef}:discovered-standalone-rss.json" }
$sourceLabel = if ($CandidatesPath) { $CandidatesPath } else { "${StateRef}:discovered-standalone-rss.json" }
$data = ConvertFrom-ReviewJson $originalText
$byId = @{}
foreach ($c in @($data.candidates)) { $byId[[string]$c.videoId] = $c }

# ---- 確認シートを読んで検証する(問題が1つでもあれば中止) ----
$decisionCol = "decision(approve/hold/reject)"; $excludeCol = "excludeVideoIds(series のみ)"
$rows = @(Import-Csv -LiteralPath $CsvPath -Encoding UTF8)
$problems = New-Object System.Collections.Generic.List[string]
if ($rows.Count -eq 0) { $problems.Add("確認シートに行が無い") }
else {
  foreach ($col in @("no", "rowType", $decisionCol, "videoIds", "seriesKey", $excludeCol)) {
    if (-not $rows[0].PSObject.Properties[$col]) { $problems.Add("必要な列が無い: $col") }
  }
}
$statusOf = @{ approve = "approved"; hold = "held"; reject = "rejected" }
$seenIds = @{}
$changes = New-Object System.Collections.Generic.List[object]
$blankRows = 0; $excludedKept = 0
if ($problems.Count -eq 0) {
  foreach ($r in $rows) {
    $rowNo = [string]$r.no
    $decision = ([string]$r.$decisionCol).Trim().ToLowerInvariant()
    $type = ([string]$r.rowType).Trim()
    $ids = @(([string]$r.videoIds).Trim() -split '\s+' | Where-Object { $_ })
    $exclude = @(([string]$r.$excludeCol).Trim() -split '[\s,]+' | Where-Object { $_ })
    if ($type -notin @("single", "series", "playlist-review", "non-gameplay", "unclassified")) { $problems.Add("行 ${rowNo}: 行の種類が不正($type)"); continue }
    if ($decision -and -not $statusOf.ContainsKey($decision)) { $problems.Add("行 ${rowNo}: 判断欄の値が不正($decision。approve / hold / reject のどれか、または空欄)"); continue }
    # ゲーム実況でない可能性・分類なしの候補は、誤登録を防ぐため承認できない(保留か除外だけ)
    if ($decision -eq "approve" -and $type -in @("non-gameplay", "unclassified")) { $problems.Add("行 ${rowNo}: $type の行は承認できない(hold か reject のどちらか)"); continue }
    if ($ids.Count -eq 0) { $problems.Add("行 ${rowNo}: 動画IDが無い"); continue }
    foreach ($id in $ids) {
      if ($id -notmatch '^[A-Za-z0-9_-]{11}$') { $problems.Add("行 ${rowNo}: 動画IDの形式が不正($id)"); continue }
      if ($seenIds.ContainsKey($id)) { $problems.Add("行 ${rowNo}: 動画ID $id が行 $($seenIds[$id]) と重複") } else { $seenIds[$id] = $rowNo }
      if (-not $byId.ContainsKey($id)) { $problems.Add("行 ${rowNo}: 候補 JSON に無い動画ID($id)") }
    }
    if (@($ids | Where-Object { -not $byId.ContainsKey($_) }).Count -gt 0) { continue }
    if ($type -ne "series") {
      if ($ids.Count -ne 1) { $problems.Add("行 ${rowNo}: $type の行に動画が $($ids.Count) 本ある(1本のはず)") }
      if ($exclude.Count -gt 0) { $problems.Add("行 ${rowNo}: excludeVideoIds は続き物(series)の行にだけ書ける") }
    } else {
      $key = ([string]$r.seriesKey).Trim()
      $group = @($data.candidates | Where-Object { [string]$_.status -eq "pending" -and [string]$_.reviewCategory -eq "series" -and [string]$_.seriesKey -eq $key } | ForEach-Object { [string]$_.videoId })
      $a = ($ids | Sort-Object) -join ","; $b = ($group | Sort-Object) -join ","
      if (-not $key) { $problems.Add("行 ${rowNo}: 続き物の行に seriesKey が無い") }
      elseif ($a -ne $b) { $problems.Add("行 ${rowNo}: 続き物 $key の動画の組が候補 JSON と違う(シート $($ids.Count) 本 / 候補 $($group.Count) 本。書き出し後に変わった可能性)") }
      foreach ($x in $exclude) { if ($ids -notcontains $x) { $problems.Add("行 ${rowNo}: excludeVideoIds の $x はこの行の動画ではない") } }
    }
    if (-not $decision) {
      $blankRows++
      if ($exclude.Count -gt 0) { $problems.Add("行 ${rowNo}: 判断欄が空欄なのに excludeVideoIds が書いてある") }
      continue
    }
    foreach ($id in $ids) {
      $c = $byId[$id]
      if ([string]$c.status -ne "pending") { $problems.Add("行 ${rowNo}: $id はすでに判断済み(status=$($c.status))。シートが古い可能性"); continue }
      $expect = $(if ($type -eq "unclassified") { "" } else { $type })   # unclassified の行は分類の無い候補だけ
      if ([string]$c.reviewCategory -ne $expect) { $problems.Add("行 ${rowNo}: $id の分類が違う(シート $type / 候補 $($c.reviewCategory))"); continue }
      if ($exclude -contains $id) { $excludedKept++; continue }   # 続き物から外した動画は変更しない
      $changes.Add([pscustomobject]@{ row = $rowNo; rowType = $type; videoId = $id; from = [string]$c.status; to = $statusOf[$decision]; streamer = [string]$c.streamer; game = [string]$c.game })
    }
  }
}

$byTo = @{}; foreach ($ch in $changes) { $byTo[$ch.to] = 1 + [int]$byTo[$ch.to] }
Write-Output ("確認シート: $CsvPath($($rows.Count) 行)  候補 JSON: $sourceLabel(全 $(@($data.candidates).Count) 件)")
if ($problems.Count -gt 0) {
  Write-Output "問題が $($problems.Count) 件あるため、取り込みを中止しました(1件も反映していません):"
  $problems | Select-Object -First 30 | ForEach-Object { Write-Output "  - $_" }
  if ($problems.Count -gt 30) { Write-Output "  …ほか $($problems.Count - 30) 件" }
  exit 2
}
Write-Output ("変更予定: $($changes.Count) 件(approved $([int]$byTo['approved']) / held $([int]$byTo['held']) / rejected $([int]$byTo['rejected']))  判断欄が空欄の行 $blankRows 行・続き物から外した動画 $excludedKept 本は変更しない")
foreach ($ch in $changes) { Write-Output ("  行 $($ch.row) [$($ch.rowType)] $($ch.videoId) $($ch.from) → $($ch.to)  $($ch.streamer) / $($ch.game)") }

if (-not $Apply) { Write-Output "dry-run のため、どのファイルも変更していません(反映するには -CandidatesPath と -Apply を指定)。"; exit 0 }
if ($changes.Count -eq 0) { Write-Output "変更する候補が無いため、ファイルは変更していません。"; exit 0 }

# ---- 反映(元のファイルを残す → 一時ファイル → 置き換え → 読み直して確認) ----
$stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
$reviewedAt = [DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(9)).ToString("yyyy-MM-dd'T'HH:mm:ss")
$batch = [IO.Path]::GetFileName($CsvPath)
foreach ($ch in $changes) {
  $c = $byId[$ch.videoId]
  Set-ObjProp $c "status" $ch.to; Set-ObjProp $c "reviewedAt" $reviewedAt; Set-ObjProp $c "reviewBatch" $batch
}
$full = (Resolve-Path -LiteralPath $CandidatesPath).Path
$backup = $full -replace '\.json$', ".before-import-$stamp.json"
[IO.File]::WriteAllText($backup, $originalText, (New-Object System.Text.UTF8Encoding($false)))
$tmp = $full + ".tmp"
[IO.File]::WriteAllText($tmp, (ConvertTo-StandaloneJsonText $data 10), (New-Object System.Text.UTF8Encoding($false)))
Move-Item -LiteralPath $tmp -Destination $full -Force

# 読み直して、変更した候補の status 以外が元と同じかを確かめる(違えば元に戻す)
$before = ConvertFrom-ReviewJson $originalText; $after = ConvertFrom-ReviewJson ([IO.File]::ReadAllText($full, [Text.Encoding]::UTF8))
$changedIds = New-Object System.Collections.Generic.HashSet[string]; foreach ($ch in $changes) { [void]$changedIds.Add($ch.videoId) }
$bad = New-Object System.Collections.Generic.List[string]
if (@($before.candidates).Count -ne @($after.candidates).Count) { $bad.Add("候補の件数が変わった") }
if (@($before.unknownGames).Count -ne @($after.unknownGames).Count) { $bad.Add("未登録作品の候補の件数が変わった") }
if (($before.lastRun | ConvertTo-Json -Depth 8 -Compress) -ne ($after.lastRun | ConvertTo-Json -Depth 8 -Compress)) { $bad.Add("lastRun が変わった") }
$afterById = @{}; foreach ($c in @($after.candidates)) { $afterById[[string]$c.videoId] = $c }
foreach ($c in @($before.candidates)) {
  $id = [string]$c.videoId; $a = $afterById[$id]
  if (-not $a) { $bad.Add("候補 $id が無くなった"); continue }
  if ($changedIds.Contains($id)) {
    $exp = $byId[$id]
    if ([string]$a.status -ne [string]$exp.status) { $bad.Add("候補 $id の status が予定と違う") }
    foreach ($p in $c.PSObject.Properties) { if ($p.Name -ne "status" -and (($p.Value | ConvertTo-Json -Depth 6 -Compress) -ne ($a.($p.Name) | ConvertTo-Json -Depth 6 -Compress))) { $bad.Add("候補 $id の $($p.Name) が変わった") } }
  } elseif (($c | ConvertTo-Json -Depth 6 -Compress) -ne ($a | ConvertTo-Json -Depth 6 -Compress)) { $bad.Add("変更しない候補 $id が変わった") }
}
if ($bad.Count -gt 0) {
  [IO.File]::WriteAllText($full, $originalText, (New-Object System.Text.UTF8Encoding($false)))
  Write-Output "書き込み後の確認で問題が見つかったため、元の内容に戻しました: $(($bad | Select-Object -First 5) -join ' / ')"
  exit 3
}
Write-Output "反映しました: $full($($changes.Count) 件)。元のファイル: $backup"
