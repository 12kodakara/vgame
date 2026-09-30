<#
.SYNOPSIS
  単発実況 → 再生リスト移行 audit(audit-standalone-migration.ps1 / Get-StandaloneMigrationStatus)の回帰テスト。
  YouTube API は使わない(audit は -Offline で実行)。Node.js は audit のデータ読み込みで使う。

.DESCRIPTION
  1. 判定関数を小さな固定データで確認する(ケースA〜F ほか)
  2. 作業用フォルダに本番データをコピーし、同じVTuber × game の再生リストを1件足して audit を通しで実行する
  3. 本番データで audit を実行しても、データファイルが変わらないこと(読み取り専用)を確認する
  本番データは変更しない。

.EXAMPLE
  .\test-standalone-migration.ps1
#>
param()
$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir "standalone-matching.ps1")

$script:pass = 0; $script:fail = 0
function Check([string]$name, [bool]$ok, [string]$detail = "") {
  if ($ok) { $script:pass++; Write-Output "  [PASS] $name" } else { $script:fail++; Write-Output "  [FAIL] $name"; if ($detail) { Write-Output "         $detail" } }
}
function Show($r) { if (-not $r) { return "(結果なし)" }; return "$($r.level) / " + (($r.playlists | ForEach-Object { "$($_.source):$($_.playlistId):$($_.videoInPlaylist)" }) -join ",") + " / " + ($r.reasons -join "; ") }

# ---- 固定データ ----
$games = @(
  [pscustomobject]@{ name = "ウツロマユ"; aliases = @("ウツロマユ") },
  [pscustomobject]@{ name = "Minecraft"; aliases = @("Minecraft", "マインクラフト", "マイクラ") },
  [pscustomobject]@{ name = "リズム天国 ミラクルスターズ"; aliases = @("リズム天国 ミラクルスターズ") },
  [pscustomobject]@{ name = "リズム天国シリーズ"; aliases = @("リズム天国シリーズ", "リズム天国") }
)
$play = [pscustomobject]@{ id = "single-900"; streamer = "テストVTuber"; game = "ウツロマユ"; format = "single"; videos = @([pscustomobject]@{ url = "https://www.youtube.com/watch?v=AAAAAAAAAAA" }) }
function PL($id, $title, $streamer, $game, $plId) { [pscustomobject]@{ id = $id; title = $title; streamer = $streamer; game = $game; playlistId = $plId } }
$base = @(PL "t-1" "Minecraft" "テストVTuber" "Minecraft" "PLminecraft")

Write-Output "=== 単発実況 → 再生リスト移行 audit テスト ==="

# ---- A. 単発実況のみ・再生リストなし → NONE ----
$r = Get-StandaloneMigrationStatus $play $base $games @{ "PLminecraft" = @("BBBBBBBBBBB") }
Check "A. 同じVTuber × game の再生リストが無ければ NONE" ($r.level -eq "NONE" -and $r.playlists.Count -eq 0) (Show $r)

# ---- B. 同じVTuber × game の再生リストあり・動画も中にある → STRONG ----
$pls = $base + @(PL "t-2" "ウツロマユ" "テストVTuber" "ウツロマユ" "PLutsuro")
$r = Get-StandaloneMigrationStatus $play $pls $games @{ "PLutsuro" = @("CCCCCCCCCCC", "AAAAAAAAAAA") }
Check "B. 同じVTuber × game の再生リストに動画もある → STRONG" ($r.level -eq "STRONG" -and $r.playlists[0].playlistId -eq "PLutsuro" -and $r.playlists[0].videoInPlaylist -eq $true) (Show $r)

# ---- C. 再生リストあり・動画は外 → MEDIUM(動画を確認していない場合も MEDIUM) ----
$r = Get-StandaloneMigrationStatus $play $pls $games @{ "PLutsuro" = @("CCCCCCCCCCC") }
Check "C. 同じVTuber × game の再生リストはあるが動画は外 → MEDIUM" ($r.level -eq "MEDIUM" -and $r.playlists[0].videoInPlaylist -eq $false) (Show $r)
$r = Get-StandaloneMigrationStatus $play $pls $games @{}
Check "C2. 再生リストの動画を確認していない → MEDIUM(STRONG にしない)" ($r.level -eq "MEDIUM" -and $null -eq $r.playlists[0].videoInPlaylist -and ($r.reasons -join "") -like "*確認していない*") (Show $r)

# ---- D. 別VTuberの同じgame → 候補にしない ----
$pls = $base + @(PL "t-3" "ウツロマユ" "別のVTuber" "ウツロマユ" "PLother")
$r = Get-StandaloneMigrationStatus $play $pls $games @{ "PLother" = @("AAAAAAAAAAA") }
Check "D. 別VTuberの同じgame の再生リスト → NONE(動画が入っていても)" ($r.level -eq "NONE") (Show $r)

# ---- E. 同じVTuberの別game → 候補にしない ----
$pls = $base + @(PL "t-4" "ホラゲまとめ" "テストVTuber" "Minecraft" "PLmc2")
$r = Get-StandaloneMigrationStatus $play $pls $games @{ "PLmc2" = @("BBBBBBBBBBB") }
Check "E. 同じVTuberの別game(タイトルにゲーム名なし)→ NONE" ($r.level -eq "NONE") (Show $r)

# ---- F. タイトルだけ似ている → STRONG にしない ----
$pls = $base + @(PL "t-5" "【ウツロマユ】ほか ホラー詰め合わせ" "テストVTuber" "Minecraft" "PLmixed")
$r = Get-StandaloneMigrationStatus $play $pls $games @{ "PLmixed" = @("AAAAAAAAAAA") }
Check "F. 同じVTuberの別game の再生リストのタイトルにゲーム名がある → WEAK(動画が入っていても STRONG にしない)" ($r.level -eq "WEAK" -and ($r.reasons -join "") -like "*タイトルにゲーム名*") (Show $r)
$rhythm = [pscustomobject]@{ id = "single-901"; streamer = "テストVTuber"; game = "リズム天国 ミラクルスターズ"; format = "single"; videos = @([pscustomobject]@{ url = "https://www.youtube.com/watch?v=DDDDDDDDDDD" }) }
$pls = $base + @(PL "t-6" "リズム天国" "テストVTuber" "リズム天国シリーズ" "PLrhythm")
$r = Get-StandaloneMigrationStatus $rhythm $pls $games @{ "PLrhythm" = @("EEEEEEEEEEE") }
Check "F2. 名前が似ている別game(リズム天国シリーズ)の再生リスト → STRONG / MEDIUM にしない" ($r.level -in @("NONE", "WEAK")) (Show $r)

# ---- その他 ----
$pls = $base + @(PL "t-7" "ホラゲ" "テストVTuber" "Minecraft" "PLhorror")
$r = Get-StandaloneMigrationStatus $play $pls $games @{ "PLhorror" = @("AAAAAAAAAAA") }
Check "G. 動画が別game で登録された再生リストに入っている → WEAK" ($r.level -eq "WEAK" -and ($r.reasons -join "") -like "*別 game*") (Show $r)
$channel = @([pscustomobject]@{ id = "PLchannelUtsuro"; title = "ウツロマユ 実況"; count = 2 }, [pscustomobject]@{ id = "PLminecraft"; title = "Minecraft"; count = 20 })
$r = Get-StandaloneMigrationStatus $play $base $games @{} $channel
Check "H. チャンネル側にサイト未登録のゲーム名入り再生リスト → WEAK(自動移行の対象外)" ($r.level -eq "WEAK" -and $r.playlists[0].source -eq "channel" -and $r.playlists[0].playlistId -eq "PLchannelUtsuro") (Show $r)
$r = Get-StandaloneMigrationStatus $play $base $games @{} @([pscustomobject]@{ id = "PLminecraft"; title = "ウツロマユ"; count = 1 })
Check "H2. サイト登録済みの再生リストはチャンネル側の WEAK として重ねて数えない" ($r.level -eq "NONE") (Show $r)
$pls = $base + @(PL "t-2" "ウツロマユ" "テストVTuber" "ウツロマユ" "PLutsuro")
$r = Get-StandaloneMigrationStatus $play $pls $games @{ "PLutsuro" = @("AAAAAAAAAAA") } $channel
Check "I. STRONG はチャンネル側の結果に左右されない" ($r.level -eq "STRONG") (Show $r)

# ---- 通しテスト(作業用フォルダ。本番データはコピーして使う) ----
$work = Join-Path ([IO.Path]::GetTempPath()) ("vgame-migration-test-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work -Force | Out-Null
try {
  foreach ($f in @("audit-standalone-migration.ps1", "standalone-matching.ps1", "data-core.js", "data-playlists.js", "data-standalone.js")) { Copy-Item (Join-Path $scriptDir $f) (Join-Path $work $f) }
  # 本番の STANDALONE_PLAYS の1件目について、同じVTuber × game の再生リストが後日登録された状態を作る
  $sa = [IO.File]::ReadAllText((Join-Path $work "data-standalone.js"), [Text.Encoding]::UTF8)
  $firstStreamer = [regex]::Match(($sa -split "`n" | Where-Object { $_ -notmatch '^\s*//' }) -join "`n", 'streamer:\s*"([^"]+)"').Groups[1].Value
  $firstGame = [regex]::Match(($sa -split "`n" | Where-Object { $_ -notmatch '^\s*//' }) -join "`n", 'game:\s*"([^"]+)"').Groups[1].Value
  $plPath = Join-Path $work "data-playlists.js"
  $pl = [IO.File]::ReadAllText($plPath, [Text.Encoding]::UTF8)
  $entry = "  {`n    id: `"migration-test-1`",`n    title: `"$firstGame`",`n    streamer: `"$firstStreamer`",`n    game: `"$firstGame`",`n    genre: `"other`",`n    playlistId: `"PLmigrationTest0000000000000000000`",`n    videoCount: 1,`n    addedDate: `"2026-10-01`",`n  },`n"
  $idx = $pl.IndexOf("const PLAYLISTS = [")
  $idx = $pl.IndexOf("`n", $idx) + 1
  [IO.File]::WriteAllText($plPath, $pl.Substring(0, $idx) + $entry + $pl.Substring($idx), (New-Object Text.UTF8Encoding($false)))
  $jsonPath = Join-Path $work "out.json"
  $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $work "audit-standalone-migration.ps1") -Offline -Json $jsonPath
  $code = $LASTEXITCODE
  $res = Get-Content $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $target = @($res.results | ForEach-Object { $_ } | Where-Object { $_.streamer -eq $firstStreamer -and $_.game -eq $firstGame })
  Check "J. 通し: 後日登録された同じVTuber × game の再生リストを MEDIUM で検出(オフラインは動画未確認)" ($code -eq 0 -and $target.Count -ge 1 -and $target[0].level -eq "MEDIUM" -and $target[0].playlists[0].playlistId -eq "PLmigrationTest0000000000000000000") "exit=$code $($target | ConvertTo-Json -Depth 4 -Compress)"
  Check "J2. 通し: JSON に総件数と各判定の件数がある" ($res.total -ge 1 -and $null -ne $res.counts.STRONG -and $null -ne $res.counts.MEDIUM -and $null -ne $res.counts.WEAK -and $null -ne $res.counts.NONE -and ($res.counts.STRONG + $res.counts.MEDIUM + $res.counts.WEAK + $res.counts.NONE) -eq $res.total)
  Check "J3. 通し: 通常出力は NONE の詳細を出さない" (@($out | Where-Object { $_ -like "*[[]NONE]*" }).Count -eq 0 -and @($out | Where-Object { $_ -like "*[[]MEDIUM]*" }).Count -ge 1) ($out -join " | ")
  # 拒否時は audit が stderr にエラーを書くため、この呼び出しの間だけ Stop を外す
  $ErrorActionPreference = "Continue"
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $work "audit-standalone-migration.ps1") -Offline -Json (Join-Path $work "data\x.json") 2>$null | Out-Null
  $refusedCode = $LASTEXITCODE
  $ErrorActionPreference = "Stop"
  Check "J4. -Json に data\ の中を指定すると拒否する" ($refusedCode -eq 1 -and -not (Test-Path (Join-Path $work "data\x.json")))
} finally {
  Remove-Item -Recurse -Force $work
}

# ---- 本番データで実行しても何も変わらない(読み取り専用) ----
$watched = @("data-core.js", "data-playlists.js", "data-standalone.js", "data-home.js", "data-new.js", "data-ranking.js", "data-genres.js", "data-counts.js", "sitemap.xml") | ForEach-Object { Join-Path $scriptDir $_ } | Where-Object { Test-Path $_ }
$watched += @(Get-ChildItem (Join-Path $scriptDir "data") -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
$before = @{}; foreach ($f in $watched) { $before[$f] = (Get-FileHash $f -Algorithm SHA256).Hash }
$out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptDir "audit-standalone-migration.ps1") -Offline
$code = $LASTEXITCODE
$changed = @($watched | Where-Object { (Get-FileHash $_ -Algorithm SHA256).Hash -ne $before[$_] })
Check "K. 本番データで実行: exit 0・データ/生成物($($watched.Count) ファイル)に変更なし" ($code -eq 0 -and $changed.Count -eq 0) "exit=$code changed=$($changed -join ',')"
$src = [IO.File]::ReadAllText((Join-Path $scriptDir "audit-standalone-migration.ps1"), [Text.Encoding]::UTF8)
Check "L. audit は STANDALONE_PLAYS / PLAYLISTS を書き換える処理を持たない" (-not ($src -match '(Set-Content|Out-File|WriteAll\w+|Add-Content)[^\r\n]*(data-|\$standalone|\$playlists)'))

Write-Output ""
Write-Output "PASS: $script:pass  FAIL: $script:fail"
if ($script:fail -gt 0) { exit 1 }
