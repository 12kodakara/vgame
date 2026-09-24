<#
.SYNOPSIS
  927ゲーム規模から数千ゲーム規模になっても、人間が全件を目視確認しなくて済むよう、
  「どのデータが不足しているか」を自動集計する運用フェーズ用の監査スクリプトです。

.DESCRIPTION
  読み取り専用のチェックです。ファイルは一切書き換えません(-Json / -Csv で
  指定した出力先だけに新規ファイルを書き込みます)。

  内部ID(id)・playlistId・GAMES/STREAMERS/GENRES参照・URL/日付形式などの
  「データ整合性チェック」は validate-data.ps1 が既に実装済みのため、
  ここでは重複実装せず、子プロセスとして validate-data.ps1 を呼び出して
  その結果(ERROR/WARNING件数)をそのまま取り込みます(-SkipValidate で省略可)。

  このスクリプトが新たに行うのは、validate-data.ps1ではカバーしていない
  以下の2種類です。

  1. validate-data.ps1が行っていない整合性チェック(ERROR/WARNING):
     - GAMES内のゲーム名重複(同名エントリが複数あると、gameUrl()が同じURLを
       生成してしまい、どちらのデータか区別できなくなる)
     - STREAMERS内のVTuber名重複(同上の理由)
     - GAMES/STREAMERSのname空欄
     - STANDALONE_PLAYS(data-standalone.js)がGAMES/STREAMERS/GENRESに
       存在しない値を参照している(validate-data.ps1はPLAYLISTSのみ検証対象で
       STANDALONE_PLAYSは対象外のため)
     - GAME_EDITORIAL(data-game-editorial.js)がGAMESに存在しないゲーム名を
       キーにしている(孤立データ、警告扱い)

  2. 運用フェーズで本当に欲しい「データ完全性(カバレッジ)」の集計と、
     拡充候補ランキングの抽出(これはvalidate-data.ps1の対象外の観点)。
     「再生リストが少ない」こと自体はデータ不整合ではないため、
     WARNING/INFOにとどめ、ERRORにはしません。

  検索需要(何のゲームがよく検索されているか等)はこのスクリプト単体では
  分からないため、優先順位を推測しません。拡充候補は内部データ(再生リスト数・
  VTuber紐付け数)だけで抽出します。将来Search Console等の外部データを
  組み合わせたい場合は -DemandCsv に "name,impressions,clicks" 形式のCSVを
  渡すと、拡充候補一覧にその列を追加してソートに反映します(未指定なら
  従来通り内部データのみで判定します)。

.PARAMETER Json
  集計結果をJSON形式でも出力する場合、出力先ファイルパスを指定します
  (省略時はJSON出力なし、コンソール表示のみ)。親ディレクトリが無ければ
  作成します。

.PARAMETER Csv
  拡充候補ランキングをCSV形式でも出力する場合、出力先ファイルパスを
  指定します(省略時はCSV出力なし)。

.PARAMETER Top
  拡充候補ランキングのカテゴリごとの表示件数上限(既定30件)。
  0を指定すると全件出力します。

.PARAMETER DemandCsv
  "name,impressions,clicks" 形式のCSV(例: Search Consoleから手動エクスポート
  したデータ)を指定すると、ゲーム別拡充候補にその列を結合し、
  impressions降順で並び替えます(name列はGAMESのゲーム名と完全一致させてください)。

.PARAMETER SkipValidate
  validate-data.ps1 の呼び出しを省略します(データ整合性チェックは行わず、
  カバレッジ集計・拡充候補ランキングだけを行いたい場合に使用)。

.EXAMPLE
  .\data-audit.ps1

.EXAMPLE
  .\data-audit.ps1 -Json reports/data-audit.json -Csv reports/data-audit-candidates.csv

.EXAMPLE
  .\data-audit.ps1 -DemandCsv search-console-export.csv -Top 50
#>
param(
  [string]$Json,
  [string]$Csv,
  [int]$Top = 30,
  [string]$DemandCsv,
  [switch]$SkipValidate
)

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$corePath = Join-Path $scriptDir "data-core.js"
$playlistsPath = Join-Path $scriptDir "data-playlists.js"
$standalonePath = Join-Path $scriptDir "data-standalone.js"
$editorialPath = Join-Path $scriptDir "data-game-editorial.js"
$validateScript = Join-Path $scriptDir "validate-data.ps1"

if (-not (Test-Path $corePath)) { Write-Error "data-core.js が見つかりません: $corePath"; exit 1 }
if (-not (Test-Path $playlistsPath)) { Write-Error "data-playlists.js が見つかりません: $playlistsPath"; exit 1 }

# ============================================================
# JS配列/オブジェクトの簡易パーサ
# (validate-data.ps1 / generate-counts.ps1 / generate-sitemap.ps1 と同じ手法:
#  文字列中の [{}] は無視し、ネストした {} も深さで正しく数える。
#  このスクリプト独自の拡張として、文字列外の // 行コメント・/* */ ブロック
#  コメントも読み飛ばす(data-standalone.js の登録例コメントに { } が
#  含まれるため、コメントを無視しないと誤ってオブジェクトとして
#  検出してしまう)。)
# ============================================================
function Get-ArrayInner([string]$name, [string]$text) {
  $marker = "const $name = ["
  $start = $text.IndexOf($marker)
  if ($start -lt 0) { return $null }
  $i = $start + $marker.Length
  $depth = 1; $inString = $false; $escape = $false
  for ($p = $i; $p -lt $text.Length; $p++) {
    $ch = $text[$p]
    if ($inString) {
      if ($escape) { $escape = $false; continue }
      if ($ch -eq '\') { $escape = $true; continue }
      if ($ch -eq '"') { $inString = $false }
      continue
    }
    if ($ch -eq '"') { $inString = $true; continue }
    if ($ch -eq '/' -and $p + 1 -lt $text.Length -and $text[$p + 1] -eq '/') {
      while ($p -lt $text.Length -and $text[$p] -ne "`n") { $p++ }
      continue
    }
    if ($ch -eq '/' -and $p + 1 -lt $text.Length -and $text[$p + 1] -eq '*') {
      $p += 2
      while ($p + 1 -lt $text.Length -and -not ($text[$p] -eq '*' -and $text[$p + 1] -eq '/')) { $p++ }
      $p++
      continue
    }
    if ($ch -eq '[') { $depth++ }
    elseif ($ch -eq ']') {
      $depth--
      if ($depth -eq 0) { return $text.Substring($i, $p - $i) }
    }
  }
  throw "$name 配列の終端が見つかりません。"
}

function Get-Objects([string]$inner) {
  $results = @(); $depth = 0; $start = -1; $inString = $false; $escape = $false
  for ($i = 0; $i -lt $inner.Length; $i++) {
    $ch = $inner[$i]
    if ($inString) {
      if ($escape) { $escape = $false; continue }
      if ($ch -eq '\') { $escape = $true; continue }
      if ($ch -eq '"') { $inString = $false }
      continue
    }
    if ($ch -eq '"') { $inString = $true; continue }
    if ($ch -eq '/' -and $i + 1 -lt $inner.Length -and $inner[$i + 1] -eq '/') {
      while ($i -lt $inner.Length -and $inner[$i] -ne "`n") { $i++ }
      continue
    }
    if ($ch -eq '/' -and $i + 1 -lt $inner.Length -and $inner[$i + 1] -eq '*') {
      $i += 2
      while ($i + 1 -lt $inner.Length -and -not ($inner[$i] -eq '*' -and $inner[$i + 1] -eq '/')) { $i++ }
      $i++
      continue
    }
    if ($ch -eq '{') { if ($depth -eq 0) { $start = $i }; $depth++ }
    elseif ($ch -eq '}') { $depth--; if ($depth -eq 0 -and $start -ge 0) { $results += $inner.Substring($start, $i - $start + 1); $start = -1 } }
  }
  return $results
}

# フィールド名ごとに正規表現をキャッシュする(数千件規模のPLAYLISTSを走査する際、
# 同じパターンをオブジェクトの数だけ毎回コンパイルし直すのを避けるため)。
$script:fieldRegexCache = @{}
function Field([string]$obj, [string]$name) {
  if (-not $script:fieldRegexCache.ContainsKey($name)) {
    $script:fieldRegexCache[$name] = [regex]::new([regex]::Escape($name) + '\s*:\s*"((?:\\.|[^"])*)"')
  }
  $m = $script:fieldRegexCache[$name].Match($obj)
  if ($m.Success) { return ($m.Groups[1].Value -replace '\\"', '"' -replace '\\\\', '\') }
  return ""
}

# ============================================================
# データ読み込み
# ============================================================
$coreText = [System.IO.File]::ReadAllText($corePath, [System.Text.Encoding]::UTF8)
$playlistsText = [System.IO.File]::ReadAllText($playlistsPath, [System.Text.Encoding]::UTF8)

$gameObjs = Get-Objects (Get-ArrayInner "GAMES" $coreText)
$streamerObjs = Get-Objects (Get-ArrayInner "STREAMERS" $coreText)
$genreObjs = Get-Objects (Get-ArrayInner "GENRES" $coreText)
$playlistObjs = Get-Objects (Get-ArrayInner "PLAYLISTS" $playlistsText)

$standaloneObjs = @()
if (Test-Path $standalonePath) {
  $standaloneText = [System.IO.File]::ReadAllText($standalonePath, [System.Text.Encoding]::UTF8)
  $inner = Get-ArrayInner "STANDALONE_PLAYS" $standaloneText
  if ($null -ne $inner) { $standaloneObjs = Get-Objects $inner }
}

$editorialKeys = @()
if (Test-Path $editorialPath) {
  $editorialText = [System.IO.File]::ReadAllText($editorialPath, [System.Text.Encoding]::UTF8)
  # GAME_EDITORIAL は配列ではなくオブジェクト直下({ "ゲーム名": {...}, ... })なので
  # 専用の軽いパースにとどめる(トップレベルのキーだけ拾えれば十分なため)。
  $editorialKeys = [regex]::Matches($editorialText, '(?m)^\s*"((?:\\.|[^"])*)"\s*:\s*\{') | ForEach-Object { $_.Groups[1].Value -replace '\\"', '"' }
}

$genreSet = @{}
foreach ($o in $genreObjs) { $v = Field $o "id"; if ($v) { $genreSet[$v] = $true } }

# ============================================================
# ERROR / WARNING / INFO 集計
# ============================================================
$errors = [ordered]@{}
$warnings = [ordered]@{}
$errorDetails = New-Object System.Collections.Generic.List[string]
$warningDetails = New-Object System.Collections.Generic.List[string]

function Add-Issue {
  param([System.Collections.Specialized.OrderedDictionary]$Bucket, [string]$Key, [System.Collections.Generic.List[string]]$DetailList, [string]$Detail)
  if (-not $Bucket.Contains($Key)) { $Bucket[$Key] = 0 }
  $Bucket[$Key] = $Bucket[$Key] + 1
  if ($null -ne $DetailList -and $Detail) { [void]$DetailList.Add($Detail) }
}

# ---- 1. validate-data.ps1 の再利用(重複実装しない) ----
$validateSummary = $null
if (-not $SkipValidate) {
  if (Test-Path $validateScript) {
    $tmpJson = Join-Path ([System.IO.Path]::GetTempPath()) ("vgame-validate-" + [Guid]::NewGuid().ToString("N") + ".json")
    try {
      & powershell.exe -NoProfile -File $validateScript -Json $tmpJson | Out-Null
      if (Test-Path $tmpJson) {
        $validateSummary = Get-Content $tmpJson -Raw -Encoding UTF8 | ConvertFrom-Json
      }
    } finally {
      if (Test-Path $tmpJson) { Remove-Item $tmpJson -Force }
    }
  } else {
    Add-Issue $warnings "validate-data.ps1が見つからない" $warningDetails "validate-data.ps1 が見つからないため、整合性チェックをスキップしました。"
  }
  if ($validateSummary) {
    foreach ($p in $validateSummary.errors.PSObject.Properties) { $errors[$p.Name] = [int]$p.Value }
    foreach ($p in $validateSummary.warnings.PSObject.Properties) { $warnings[$p.Name] = [int]$p.Value }
    foreach ($d in $validateSummary.errorDetails) { [void]$errorDetails.Add([string]$d) }
    foreach ($d in $validateSummary.warningDetails) { [void]$warningDetails.Add([string]$d) }
  }
} else {
  Add-Issue $warnings "validate-data.ps1をスキップ" $warningDetails "-SkipValidate が指定されたため、データ整合性チェック(id/playlistId重複・参照整合性等)は実行していません。"
}

# ---- 2. validate-data.ps1が行っていない整合性チェック ----

# GAMES/STREAMERS の name 重複・空欄(同じURLを複数エントリが生成してしまうため)
$gameNameCount = @{}
$gameNames = New-Object System.Collections.Generic.List[string]
foreach ($o in $gameObjs) {
  $name = Field $o "name"
  if (-not $name) {
    Add-Issue $errors "GAMESのname空欄" $errorDetails "GAMESにnameが空のエントリがあります。"
    continue
  }
  $gameNames.Add($name)
  if (-not $gameNameCount.ContainsKey($name)) { $gameNameCount[$name] = 0 }
  $gameNameCount[$name] = $gameNameCount[$name] + 1
}
foreach ($k in $gameNameCount.Keys) {
  if ($gameNameCount[$k] -gt 1) {
    Add-Issue $errors "GAMESのname重複" $errorDetails "GAMESに同じゲーム名が$($gameNameCount[$k])件登録されています(同じURLを生成してしまいます): $k"
  }
}

$streamerNameCount = @{}
$streamerNames = New-Object System.Collections.Generic.List[string]
foreach ($o in $streamerObjs) {
  $name = Field $o "name"
  if (-not $name) {
    Add-Issue $errors "STREAMERSのname空欄" $errorDetails "STREAMERSにnameが空のエントリがあります。"
    continue
  }
  $streamerNames.Add($name)
  if (-not $streamerNameCount.ContainsKey($name)) { $streamerNameCount[$name] = 0 }
  $streamerNameCount[$name] = $streamerNameCount[$name] + 1
}
foreach ($k in $streamerNameCount.Keys) {
  if ($streamerNameCount[$k] -gt 1) {
    Add-Issue $errors "STREAMERSのname重複" $errorDetails "STREAMERSに同じVTuber名が$($streamerNameCount[$k])件登録されています(同じURLを生成してしまいます): $k"
  }
}

$gameSet = @{}
foreach ($n in $gameNames) { $gameSet[$n] = $true }
$streamerSet = @{}
foreach ($n in $streamerNames) { $streamerSet[$n] = $true }

# STANDALONE_PLAYS の参照整合性(validate-data.ps1 は対象外のためここで実施)
foreach ($obj in $standaloneObjs) {
  $id = Field $obj "id"
  $game = Field $obj "game"
  $streamer = Field $obj "streamer"
  $genre = Field $obj "genre"
  $label = if ($id) { $id } else { "(id空)" }
  if ($game -and -not $gameSet.ContainsKey($game)) {
    Add-Issue $errors "STANDALONE: 未登録ゲーム参照" $errorDetails "[$label] GAMESに存在しないゲーム名です: $game"
  }
  if ($streamer -and -not $streamerSet.ContainsKey($streamer)) {
    Add-Issue $errors "STANDALONE: 未登録VTuber参照" $errorDetails "[$label] STREAMERSに存在しない実況者名です: $streamer"
  }
  if ($genre -and -not $genreSet.ContainsKey($genre)) {
    Add-Issue $errors "STANDALONE: 未登録ジャンル参照" $errorDetails "[$label] GENRESに存在しないジャンルIDです: $genre"
  }
}

# GAME_EDITORIAL の孤立データ(参照先ゲームが存在しない。表示は壊れないため警告)
foreach ($k in $editorialKeys) {
  if (-not $gameSet.ContainsKey($k)) {
    Add-Issue $warnings "GAME_EDITORIALの孤立データ" $warningDetails "data-game-editorial.js のキー `"$k`" はGAMESに存在しません(表示されない孤立データです)。"
  }
}

# ============================================================
# 3. カバレッジ集計(Map/Setを使ったO(n)処理。数千件規模でも高速)
# ============================================================
$gamePlaylistCount = @{}
$gameStreamerSets = @{}
$streamerPlaylistCount = @{}
$streamerGameSets = @{}
$pairSet = @{}

foreach ($n in $gameNames) { $gamePlaylistCount[$n] = 0; $gameStreamerSets[$n] = @{} }
foreach ($n in $streamerNames) { $streamerPlaylistCount[$n] = 0; $streamerGameSets[$n] = @{} }

foreach ($obj in $playlistObjs) {
  $game = Field $obj "game"
  $streamer = Field $obj "streamer"
  if ($game -and $gamePlaylistCount.ContainsKey($game)) {
    $gamePlaylistCount[$game] = $gamePlaylistCount[$game] + 1
    if ($streamer) { $gameStreamerSets[$game][$streamer] = $true }
  }
  if ($streamer -and $streamerPlaylistCount.ContainsKey($streamer)) {
    $streamerPlaylistCount[$streamer] = $streamerPlaylistCount[$streamer] + 1
    if ($game) { $streamerGameSets[$streamer][$game] = $true }
  }
  if ($game -and $streamer) { $pairSet["$game|||$streamer"] = $true }
}

$gamesZero = @($gameNames | Where-Object { $gamePlaylistCount[$_] -eq 0 } | Sort-Object -Culture "ja-JP")
$gamesOne = @($gameNames | Where-Object { $gamePlaylistCount[$_] -eq 1 } | Sort-Object -Culture "ja-JP")
$gamesTwoPlus = @($gameNames | Where-Object { $gamePlaylistCount[$_] -ge 2 })
# 再生リストが2件以上あるのにVTuberが1人しかいない=「候補B(1件)」とは別の
# 観点(量はあるが視点が偏っている)を拾うため、1件のゲームはここでは除外する。
$gamesSingleStreamer = @($gameNames | Where-Object { $gamePlaylistCount[$_] -ge 2 -and $gameStreamerSets[$_].Count -eq 1 } | Sort-Object -Culture "ja-JP")

$streamersZero = @($streamerNames | Where-Object { $streamerPlaylistCount[$_] -eq 0 } | Sort-Object -Culture "ja-JP")
$streamersOneGame = @($streamerNames | Where-Object { $streamerPlaylistCount[$_] -ge 1 -and $streamerGameSets[$_].Count -eq 1 } | Sort-Object -Culture "ja-JP")

if ($gamesZero.Count -gt 0) { $warnings["再生リスト0件のゲーム"] = $gamesZero.Count }
if ($streamersZero.Count -gt 0) { $warnings["再生リスト0件のVTuber"] = $streamersZero.Count }

# ============================================================
# 4. 拡充候補ランキング(内部データのみ。検索需要は推測しない)
# ============================================================
$demandByName = @{}
if ($DemandCsv) {
  if (Test-Path $DemandCsv) {
    Import-Csv $DemandCsv | ForEach-Object { $demandByName[$_.name] = $_ }
  } else {
    Add-Issue $warnings "DemandCsvが見つからない" $warningDetails "-DemandCsv で指定されたファイルが見つかりません: $DemandCsv"
  }
}

function New-CandidateList([string[]]$Names, [string]$Category) {
  $list = $Names | ForEach-Object {
    $row = [ordered]@{
      category       = $Category
      type           = "game"
      name           = $_
      playlistCount  = $gamePlaylistCount[$_]
      streamerCount  = $gameStreamerSets[$_].Count
      impressions    = $null
      clicks         = $null
    }
    if ($demandByName.ContainsKey($_)) {
      $row.impressions = [int]$demandByName[$_].impressions
      $row.clicks = [int]$demandByName[$_].clicks
    }
    [PSCustomObject]$row
  }
  if ($demandByName.Count -gt 0) {
    $list = $list | Sort-Object -Property @{Expression = { if ($null -ne $_.impressions) { $_.impressions } else { -1 } }; Descending = $true }, name
  }
  if ($Top -gt 0) { $list = $list | Select-Object -First $Top }
  return @($list)
}

$candidateA = New-CandidateList $gamesZero "A_再生リスト0件"
$candidateB = New-CandidateList $gamesOne "B_再生リスト1件"
$candidateC = New-CandidateList $gamesSingleStreamer "C_再生リスト2件以上だがVTuber1人のみ"

$streamerCandidates = @($streamersOneGame | ForEach-Object {
  [PSCustomObject][ordered]@{
    category      = "VTuber_ゲーム紐付け1件のみ"
    type          = "streamer"
    name          = $_
    playlistCount = $streamerPlaylistCount[$_]
    gameCount     = $streamerGameSets[$_].Count
  }
})
if ($Top -gt 0) { $streamerCandidates = @($streamerCandidates | Select-Object -First $Top) }

# ============================================================
# コンソール出力
# ============================================================
Write-Output "=== ぶいゲー データ監査 (data-audit.ps1) ==="
Write-Output ""
Write-Output "[全体]"
Write-Output "  ゲーム総数: $($gameNames.Count)"
Write-Output "  VTuber総数: $($streamerNames.Count)"
Write-Output "  再生リスト総数: $($playlistObjs.Count)"
Write-Output "  単発実況(STANDALONE_PLAYS)件数: $($standaloneObjs.Count)"
Write-Output "  ゲーム×VTuberの関連数(ユニークペア): $($pairSet.Count)"
Write-Output ""

Write-Output "[ゲーム]"
Write-Output "  再生リスト0件: $($gamesZero.Count)"
Write-Output "  再生リスト1件: $($gamesOne.Count)"
Write-Output "  再生リスト2件以上: $($gamesTwoPlus.Count)"
Write-Output "  再生リスト2件以上あるがVTuberが1人のみ: $($gamesSingleStreamer.Count)"
Write-Output ""

Write-Output "[VTuber]"
Write-Output "  再生リスト0件(=ゲーム紐付け0件): $($streamersZero.Count)"
Write-Output "  ゲーム紐付けが1件のみ: $($streamersOneGame.Count)"
Write-Output ""

Write-Output "ERROR"
if ($errors.Count -gt 0) {
  $errors.GetEnumerator() | Sort-Object Name | ForEach-Object { Write-Output ("  {0}: {1}" -f $_.Key, $_.Value) }
} else {
  Write-Output "  なし"
}
Write-Output ""

Write-Output "WARNING"
if ($warnings.Count -gt 0) {
  $warnings.GetEnumerator() | Sort-Object Name | ForEach-Object { Write-Output ("  {0}: {1}" -f $_.Key, $_.Value) }
} else {
  Write-Output "  なし"
}
Write-Output ""

$errorTotal = 0; foreach ($v in $errors.Values) { $errorTotal += $v }
$warningTotal = 0; foreach ($v in $warnings.Values) { $warningTotal += $v }
Write-Output ("ERROR合計: {0}  WARNING合計: {1}" -f $errorTotal, $warningTotal)
Write-Output ""

Write-Output "[拡充候補ランキング(内部データのみ。検索需要は含みません)]"
Write-Output ("  優先候補A(再生リスト0件、上位{0}件表示): {1}件中" -f $Top, $gamesZero.Count)
$candidateA | ForEach-Object { Write-Output ("    - {0}" -f $_.name) }
Write-Output ("  優先候補B(再生リスト1件、上位{0}件表示): {1}件中" -f $Top, $gamesOne.Count)
$candidateB | ForEach-Object { Write-Output ("    - {0} (VTuber{1}組)" -f $_.name, $_.streamerCount) }
Write-Output ("  優先候補C(再生リスト2件以上・VTuber1人のみ、上位{0}件表示): {1}件中" -f $Top, $gamesSingleStreamer.Count)
$candidateC | ForEach-Object { Write-Output ("    - {0} (再生リスト{1}件)" -f $_.name, $_.playlistCount) }
Write-Output ""

# ============================================================
# JSON / CSV 出力
# ============================================================
if ($Json) {
  $report = [ordered]@{
    generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
    totals      = [ordered]@{
      games              = $gameNames.Count
      streamers          = $streamerNames.Count
      playlists          = $playlistObjs.Count
      standalonePlays    = $standaloneObjs.Count
      gameStreamerPairs  = $pairSet.Count
    }
    games       = [ordered]@{
      zeroPlaylists     = $gamesZero.Count
      onePlaylist       = $gamesOne.Count
      twoPlusPlaylists  = $gamesTwoPlus.Count
      singleStreamerOnly = $gamesSingleStreamer.Count
    }
    streamers   = [ordered]@{
      zeroPlaylists  = $streamersZero.Count
      singleGameOnly = $streamersOneGame.Count
    }
    errors         = $errors
    warnings       = $warnings
    errorDetails   = $errorDetails
    warningDetails = $warningDetails
    errorTotal     = $errorTotal
    warningTotal   = $warningTotal
    candidates     = [ordered]@{
      gamesZeroPlaylists     = $candidateA
      gamesOnePlaylist       = $candidateB
      gamesSingleStreamer    = $candidateC
      streamersSingleGame    = $streamerCandidates
    }
  }
  $jsonDir = Split-Path -Parent $Json
  if ($jsonDir -and -not (Test-Path $jsonDir)) { New-Item -ItemType Directory -Path $jsonDir -Force | Out-Null }
  ($report | ConvertTo-Json -Depth 6) | Set-Content -Path $Json -Encoding UTF8
  Write-Output "詳細をJSONで出力しました: $Json"
}

if ($Csv) {
  $csvDir = Split-Path -Parent $Csv
  if ($csvDir -and -not (Test-Path $csvDir)) { New-Item -ItemType Directory -Path $csvDir -Force | Out-Null }
  $allCandidates = @()
  $allCandidates += $candidateA
  $allCandidates += $candidateB
  $allCandidates += $candidateC
  $allCandidates | Select-Object category, type, name, playlistCount, streamerCount, impressions, clicks |
    Export-Csv -Path $Csv -Encoding UTF8 -NoTypeInformation
  Write-Output "拡充候補ランキングをCSVで出力しました: $Csv"
}

if ($errorTotal -gt 0) {
  exit 1
} else {
  exit 0
}
