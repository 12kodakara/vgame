<#
.SYNOPSIS
  確認シートの書き出し(export-standalone-review.ps1)と判断の取り込み(import-standalone-review.ps1)のオフラインテスト。
  YouTube API・RSS・Git の書き込みは使わない。候補 JSON は一時フォルダに作り、終わったら消す。登録データは読むだけ。
.EXAMPLE
  .\test-standalone-review.ps1
#>
param()
$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$psExe = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
$export = Join-Path $scriptDir "export-standalone-review.ps1"
$import = Join-Path $scriptDir "import-standalone-review.ps1"
$pass = 0; $fail = 0
function Check([string]$name, [bool]$ok, [string]$detail) {
  if ($ok) { $script:pass++; Write-Output "  [PASS] $name" } else { $script:fail++; Write-Output "  [FAIL] $name`n         $detail" }
}
$work = Join-Path ([IO.Path]::GetTempPath()) ("vgame-review-test-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Path $work -Force | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding($false)
$dataFiles = @("data-core.js", "data-playlists.js", "data-standalone.js") | ForEach-Object { Join-Path $scriptDir $_ }
$hashBefore = @($dataFiles | ForEach-Object { (Get-FileHash $_ -Algorithm SHA256).Hash })

function New-Cand([string]$id, [string]$streamer, [string]$game, [string]$cat, [string]$status = "pending", [string]$key = "", [string]$date = "2026-10-10") {
  [ordered]@{ videoId = $id; url = "https://www.youtube.com/watch?v=$id"; streamer = $streamer; channelId = "UCtestChannelAAAAAAAAAAA"; title = "【$game】テスト $id"
    publishedAt = "${date}T01:00:00Z"; publishedDate = $date; game = $game; confidence = "MEDIUM"; matchType = "bracket-exact"; reasons = @("【】内の名前と一致")
    reviewGroup = $(if ($cat -eq "playlist-review") { "likely-in-site-playlist" } else { "new-standalone" }); status = $status
    firstSeenAt = "2026-10-18T10:00:00"; lastSeenAt = "2026-10-18T10:00:00"; reviewCategory = $cat; episodeMarker = $false; seriesKey = $key; seriesCount = $(if ($key) { 3 } else { 1 }) }
}
$cands = @(
  (New-Cand "RvSingle001" "鷹嶺ルイ" "8番出口" "single"),
  (New-Cand "RvSeries001" "ときのそら" "Minecraft" "series" "pending" "ときのそら|Minecraft" "2026-10-08"),
  (New-Cand "RvSeries002" "ときのそら" "Minecraft" "series" "pending" "ときのそら|Minecraft" "2026-10-09"),
  (New-Cand "RvSeries003" "ときのそら" "Minecraft" "series" "pending" "ときのそら|Minecraft" "2026-10-10"),
  (New-Cand "RvPlayl0001" "鷹嶺ルイ" "Minecraft" "playlist-review"),
  (New-Cand "RvNonGame01" "鷹嶺ルイ" "8番出口" "non-gameplay"),
  (New-Cand "RvDecided01" "鷹嶺ルイ" "8番出口" "single" "approved")
)
$doc = [ordered]@{ generatedAt = "2026-10-18T10:00:00"; source = "youtube-channel-rss"; note = "test"; lastRun = [ordered]@{ stats = [ordered]@{ crawlNextIndex = 75 } }; candidates = $cands; unknownGames = @() }
$candPath = Join-Path $work "candidates.json"
function Reset-Candidates { [IO.File]::WriteAllText($candPath, ($doc | ConvertTo-Json -Depth 8), $utf8) }
Reset-Candidates
function Invoke-Script([string]$path, [string[]]$a) {
  $ErrorActionPreference = "Continue"
  $o = & $psExe @(@("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $path) + $a) 2>&1 | ForEach-Object { "$_" }
  return [pscustomobject]@{ code = $LASTEXITCODE; output = ($o -join "`n") }
}
function Read-Cand() { return ([IO.File]::ReadAllText($candPath, [Text.Encoding]::UTF8)) | ConvertFrom-Json }
$decisionCol = "decision(approve/hold/reject)"; $excludeCol = "excludeVideoIds(series のみ)"
function Write-Sheet($rows, [string]$name) { $p = Join-Path $work $name; $rows | Export-Csv -LiteralPath $p -Encoding UTF8 -NoTypeInformation; return $p }

Write-Output "== 確認シートの書き出し"
$outDir = Join-Path $work "sheets"
$re = Invoke-Script $export @("-CandidatesPath", $candPath, "-OutDir", $outDir)
$sheet = @(Get-ChildItem -LiteralPath $outDir -Filter *.csv)[0].FullName
$rows = @(Import-Csv -LiteralPath $sheet -Encoding UTF8)
$bytes = [IO.File]::ReadAllBytes($sheet)
Check "1a. 単発1行・続き物1行(3本)・再生リスト確認1行。ゲーム実況以外と判断済みは載せない" ($re.code -eq 0 -and $rows.Count -eq 3 -and @($rows | Where-Object rowType -eq "series")[0].videoCount -eq "3" -and -not ($rows.videoIds -match "RvNonGame01|RvDecided01")) ($re.output)
Check "1b. BOM 付き UTF-8・判断欄は空欄" ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF -and @($rows | Where-Object { $_.$decisionCol }).Count -eq 0) ""

Write-Output "== 判断の取り込み(正常)"
$edit = @($rows | ForEach-Object { $_.PSObject.Copy() })
($edit | Where-Object rowType -eq "single").$decisionCol = "approve"
($edit | Where-Object rowType -eq "single").game = "書き換えた作品名"   # 下書き欄は候補 JSON に書き込まないこと
$s = $edit | Where-Object rowType -eq "series"; $s.$decisionCol = "REJECT"; $s.$excludeCol = "RvSeries002"
$okSheet = Write-Sheet $edit "ok.csv"
$hash0 = (Get-FileHash $candPath).Hash
$rd = Invoke-Script $import @("-CsvPath", $okSheet, "-CandidatesPath", $candPath)
Check "2a. 既定は dry-run: 変更予定(approved 1・rejected 2)を表示し、ファイルは変えない" ($rd.code -eq 0 -and $rd.output -match "変更予定: 3 件\(approved 1 / held 0 / rejected 2\)" -and $rd.output -match "dry-run" -and (Get-FileHash $candPath).Hash -eq $hash0) ($rd.output)
Check "2b. 判断欄が空欄の行(再生リスト確認)と、続き物から外した動画は変更予定に入らない" ($rd.output -match "空欄の行 1 行・続き物から外した動画 1 本" -and $rd.output -notmatch "RvPlayl0001 pending" -and $rd.output -notmatch "RvSeries002 pending") ""
$ra = Invoke-Script $import @("-CsvPath", $okSheet, "-CandidatesPath", $candPath, "-Apply")
$j = Read-Cand; $st = { param($id) [string]($j.candidates | Where-Object videoId -eq $id).status }
Check "2c. -Apply で status だけを反映する(承認 → approved・除外 → rejected・外した動画と空欄は pending のまま)" ($ra.code -eq 0 -and (& $st "RvSingle001") -eq "approved" -and (& $st "RvSeries001") -eq "rejected" -and (& $st "RvSeries003") -eq "rejected" -and (& $st "RvSeries002") -eq "pending" -and (& $st "RvPlayl0001") -eq "pending") ($ra.output)
$c1 = $j.candidates | Where-Object videoId -eq "RvSingle001"
Check "2d. 確認の記録(reviewedAt・reviewBatch)を残し、作品名などの下書き欄は書き込まない" ($c1.reviewedAt -and $c1.reviewBatch -eq "ok.csv" -and $c1.game -eq "8番出口") ($c1 | ConvertTo-Json -Compress)
Check "2e. ほかの候補・判断済み・lastRun はそのまま。元のファイルを残す" (@($j.candidates).Count -eq 7 -and (& $st "RvDecided01") -eq "approved" -and (& $st "RvNonGame01") -eq "pending" -and $j.lastRun.stats.crawlNextIndex -eq 75 -and @(Get-ChildItem -LiteralPath $work -Filter "candidates.before-import-*.json").Count -eq 1) ""
$hash1 = (Get-FileHash $candPath).Hash
$rr = Invoke-Script $import @("-CsvPath", $okSheet, "-CandidatesPath", $candPath, "-Apply")
Check "2f. 反映済みのシートをもう一度取り込むと、判断済みとして中止し、ファイルを変えない" ($rr.code -eq 2 -and $rr.output -match "すでに判断済み" -and (Get-FileHash $candPath).Hash -eq $hash1) ($rr.output)

Write-Output "== 判断の取り込み(異常: 全体を中止して何も変えない)"
$cases = @(
  @{ name = "3a. 判断欄の値が不正"; make = { param($e) ($e | Where-Object rowType -eq "single").$decisionCol = "ok" }; expect = "判断欄の値が不正" },
  @{ name = "3b. 候補 JSON に無い動画ID"; make = { param($e) $x = $e | Where-Object rowType -eq "single"; $x.videoIds = "RvUnknown01"; $x.$decisionCol = "approve" }; expect = "候補 JSON に無い動画ID" },
  @{ name = "3c. 同じ動画IDが複数の行にある"; make = { param($e) $x = $e | Where-Object rowType -eq "playlist-review"; $x.videoIds = "RvSingle001"; $x.$decisionCol = "hold" }; expect = "重複" },
  @{ name = "3d. 続き物の動画の組が違う(1本足りない)"; make = { param($e) $x = $e | Where-Object rowType -eq "series"; $x.videoIds = "RvSeries001 RvSeries002"; $x.$decisionCol = "approve" }; expect = "動画の組が候補 JSON と違う" },
  @{ name = "3e. 単発の行に excludeVideoIds"; make = { param($e) $x = $e | Where-Object rowType -eq "single"; $x.$decisionCol = "approve"; $x.$excludeCol = "RvSingle001" }; expect = "続き物\(series\)の行にだけ" },
  @{ name = "3f. 行の種類と候補の分類が違う"; make = { param($e) $x = $e | Where-Object rowType -eq "playlist-review"; $x.rowType = "single"; $x.$decisionCol = "approve" }; expect = "分類が違う" }
)
foreach ($case in $cases) {
  Reset-Candidates; $h = (Get-FileHash $candPath).Hash
  $e = @($rows | ForEach-Object { $_.PSObject.Copy() }); & $case.make $e
  $r = Invoke-Script $import @("-CsvPath", (Write-Sheet $e "bad.csv"), "-CandidatesPath", $candPath, "-Apply")
  Check ($case.name + " → 中止(終了コード 2)し、ファイルを変えない") ($r.code -eq 2 -and $r.output -match $case.expect -and $r.output -match "取り込みを中止" -and (Get-FileHash $candPath).Hash -eq $h) ($r.output)
}
# 書き出した後に続き物へ動画が増えた(巡回で追加された)場合
Reset-Candidates
$grown = ([IO.File]::ReadAllText($candPath, [Text.Encoding]::UTF8)) | ConvertFrom-Json
$grown.candidates += [pscustomobject](New-Cand "RvSeries004" "ときのそら" "Minecraft" "series" "pending" "ときのそら|Minecraft" "2026-10-11")
[IO.File]::WriteAllText($candPath, ($grown | ConvertTo-Json -Depth 8), $utf8); $h = (Get-FileHash $candPath).Hash
$e = @($rows | ForEach-Object { $_.PSObject.Copy() }); ($e | Where-Object rowType -eq "series").$decisionCol = "approve"
$rg = Invoke-Script $import @("-CsvPath", (Write-Sheet $e "grown.csv"), "-CandidatesPath", $candPath, "-Apply")
Check "3g. 書き出した後に続き物の動画が増えたときは中止する" ($rg.code -eq 2 -and $rg.output -match "シート 3 本 / 候補 4 本" -and (Get-FileHash $candPath).Hash -eq $h) ($rg.output)
Reset-Candidates; $h = (Get-FileHash $candPath).Hash
$noCol = Join-Path $work "nocol.csv"; @($rows | Select-Object no, rowType, videoIds, seriesKey) | Export-Csv -LiteralPath $noCol -Encoding UTF8 -NoTypeInformation
$rc = Invoke-Script $import @("-CsvPath", $noCol, "-CandidatesPath", $candPath, "-Apply")
Check "3h. 必要な列(判断欄など)が無いシートは中止する" ($rc.code -eq 2 -and $rc.output -match "必要な列が無い" -and (Get-FileHash $candPath).Hash -eq $h) ($rc.output)
$rn = Invoke-Script $import @("-CsvPath", $okSheet, "-Apply")
Check "3i. -Apply には書き換える候補 JSON の指定が必要" ($rn.code -ne 0 -and $rn.output -match "CandidatesPath" -and (Get-FileHash $candPath).Hash -eq $h) ($rn.output)
$rb = Invoke-Script $import @("-CsvPath", $sheet, "-CandidatesPath", $candPath, "-Apply")
Check "3j. 判断欄がすべて空欄なら何も変えない" ($rb.code -eq 0 -and $rb.output -match "変更予定: 0 件" -and (Get-FileHash $candPath).Hash -eq $h) ($rb.output)

Write-Output "== 保存の書式(5.1 でも 7 と同じ: 2スペース・LF・キーの順序そのまま)"
# 本番の候補 JSON と同じ書式(watch-standalone-rss.ps1 の保存処理)で作った候補に取り込み、差分が判断した候補の分だけになることを確かめる
$watchAst = [Management.Automation.Language.Parser]::ParseFile((Join-Path $scriptDir "watch-standalone-rss.ps1"), [ref]$null, [ref]$null)
foreach ($fn in $watchAst.FindAll({ param($a) $a -is [Management.Automation.Language.FunctionDefinitionAst] -and $a.Name -match '^(ConvertTo|Add)-StandaloneJson' }, $true)) { . ([scriptblock]::Create($fn.Extent.Text)) }
$fmtText = ConvertTo-StandaloneJsonText $doc 8
[IO.File]::WriteAllText($candPath, $fmtText, $utf8)
$rf = Invoke-Script $import @("-CsvPath", $okSheet, "-CandidatesPath", $candPath, "-Apply")
$fmtAfter = [IO.File]::ReadAllText($candPath, $utf8)
# 期待する結果: 元の文字列を読み、判断した3件に status と記録2項目を足して同じ書式で書いたもの(ほかは1文字も変わらない)
$readJson = { param($t) if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey("DateKind")) { $t | ConvertFrom-Json -DateKind String } else { $t | ConvertFrom-Json } }
$got = & $readJson $fmtAfter; $exp = & $readJson $fmtText
$gotById = @{}; foreach ($c in @($got.candidates)) { $gotById[[string]$c.videoId] = $c }
foreach ($c in @($exp.candidates)) { $g = $gotById[[string]$c.videoId]; if ($g.status -ne $c.status) { $c.status = $g.status; $c | Add-Member -NotePropertyName reviewedAt -NotePropertyValue $g.reviewedAt; $c | Add-Member -NotePropertyName reviewBatch -NotePropertyValue $g.reviewBatch } }
Check "4a. 取り込み後も同じ書式で保存し、差分は判断した3件(status の変更と記録2項目の追加)だけ" ($rf.code -eq 0 -and -not $fmtAfter.Contains("`r") -and @($got.candidates | Where-Object { $_.reviewBatch }).Count -eq 3 -and ($fmtAfter -ceq (ConvertTo-StandaloneJsonText $exp 8)) -and ($fmtAfter -split "`n").Count -eq (($fmtText -split "`n").Count + 6)) ($rf.output)

$hashAfter = @($dataFiles | ForEach-Object { (Get-FileHash $_ -Algorithm SHA256).Hash })
Check "9a. 本番の data-core.js / data-playlists.js / data-standalone.js を変更しない" (($hashBefore -join ",") -eq ($hashAfter -join ",")) ""
Remove-Item -LiteralPath $work -Recurse -Force
Write-Output ""
Write-Output "PASS: $pass  FAIL: $fail"
if ($fail -gt 0) { exit 1 }
