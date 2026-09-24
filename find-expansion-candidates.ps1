<#
.SYNOPSIS
  再生リスト0件・1件のゲームについて、既存データ(GAMES/STREAMERS/PLAYLISTS/
  GAME_EDITORIAL)だけを使って、外部検索(YouTube API等)を一切使わずに
  安全に分析できる情報を機械的に整理します。

.DESCRIPTION
  読み取り専用です。ファイルは一切書き換えません(-Json / -Csv で指定した
  出力先だけに新規ファイルを書き込みます)。data-audit.ps1 と同じ手法
  (文字列・コメントを認識する簡易パーサ)でデータを読み込みます。

  行うのはあくまで「既存データの整理・機械的な仮説の提示」までです。
  「このVTuberがこのゲームをプレイしているはず」という断定は行いません
  (シリーズ内の類似ゲームでaliasesが重複している等、コード上の事実から
  導ける仮説のみを hypothesis として添えます)。

  STEP1: 再生リスト0件のゲームを一覧化し、以下を添える。
    - series(シリーズ)の兄弟タイトルの再生リスト件数(0件が「本当の空白」か
      「同シリーズの別タイトル/リマスター版に実況が集約されているだけ」かの
      判断材料にする)
    - aliases が他の(再生リストを持つ)ゲームと重複していないか
    - GAME_EDITORIAL(独自編集コンテンツ)の有無

  STEP2: 再生リスト1件のゲームを機械的に整理する(JSON/CSV出力)。
    - ゲーム名・唯一の再生リストのタイトル/実況者/playlist URL/ジャンル/動画数/更新日
    - その実況者が他に何件の再生リストを持っているか(参考情報。多いほど
      「たまたま1回だけ」の可能性、少ないほど「そのVTuber自体が小規模」の
      可能性を示す程度の目安)

  STEP3: 内部データだけで見つかる拡充余地(あくまで人間確認前提の仮説)。
    - 同じseriesの兄弟タイトルの再生リスト件数に大きな差があるゲーム
      (シリーズとしては人気なのに特定タイトルだけ手薄なもの)

.PARAMETER Json
  詳細レポートをJSON形式で出力する場合の出力先パス。

.PARAMETER Csv
  再生リスト1件ゲームの一覧をCSV形式で出力する場合の出力先パス。

.PARAMETER Top
  コンソールに表示する各カテゴリの件数上限(既定20件、0で全件)。

.EXAMPLE
  .\find-expansion-candidates.ps1

.EXAMPLE
  .\find-expansion-candidates.ps1 -Json reports/expansion-candidates.json -Csv reports/expansion-candidates-1count.csv
#>
param(
  [string]$Json,
  [string]$Csv,
  [int]$Top = 20
)

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$corePath = Join-Path $scriptDir "data-core.js"
$playlistsPath = Join-Path $scriptDir "data-playlists.js"
$editorialPath = Join-Path $scriptDir "data-game-editorial.js"

if (-not (Test-Path $corePath)) { Write-Error "data-core.js が見つかりません: $corePath"; exit 1 }
if (-not (Test-Path $playlistsPath)) { Write-Error "data-playlists.js が見つかりません: $playlistsPath"; exit 1 }

# ---- パーサ(data-audit.ps1 と同じ手法。文字列外の // と /* */ を読み飛ばす) ----
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

$script:fieldRegexCache = @{}
function Field([string]$obj, [string]$name) {
  if (-not $script:fieldRegexCache.ContainsKey($name)) {
    $script:fieldRegexCache[$name] = [regex]::new([regex]::Escape($name) + '\s*:\s*"((?:\\.|[^"])*)"')
  }
  $m = $script:fieldRegexCache[$name].Match($obj)
  if ($m.Success) { return ($m.Groups[1].Value -replace '\\"', '"' -replace '\\\\', '\') }
  return ""
}

function FieldArray([string]$obj, [string]$name) {
  $m = [regex]::Match($obj, [regex]::Escape($name) + '\s*:\s*\[([^\]]*)\]')
  if (-not $m.Success) { return @() }
  return @([regex]::Matches($m.Groups[1].Value, '"((?:\\.|[^"])*)"') | ForEach-Object { $_.Groups[1].Value })
}

# ---- データ読み込み ----
$coreText = [System.IO.File]::ReadAllText($corePath, [System.Text.Encoding]::UTF8)
$playlistsText = [System.IO.File]::ReadAllText($playlistsPath, [System.Text.Encoding]::UTF8)

$gameObjs = Get-Objects (Get-ArrayInner "GAMES" $coreText)
$playlistObjs = Get-Objects (Get-ArrayInner "PLAYLISTS" $playlistsText)

$editorialKeys = @{}
if (Test-Path $editorialPath) {
  $editorialText = [System.IO.File]::ReadAllText($editorialPath, [System.Text.Encoding]::UTF8)
  [regex]::Matches($editorialText, '(?m)^\s*"((?:\\.|[^"])*)"\s*:\s*\{') | ForEach-Object { $editorialKeys[$_.Groups[1].Value -replace '\\"', '"'] = $true }
}

# ---- ゲーム情報の構築 ----
$games = [ordered]@{}
$gameOrder = New-Object System.Collections.Generic.List[string]
$aliasOwner = @{}
foreach ($o in $gameObjs) {
  $name = Field $o "name"
  if (-not $name) { continue }
  $aliases = @(FieldArray $o "aliases")
  $games[$name] = [ordered]@{
    name        = $name
    series      = Field $o "series"
    aliases     = $aliases
    hasEditorial = $editorialKeys.ContainsKey($name)
    playlists   = New-Object System.Collections.Generic.List[object]
  }
  $gameOrder.Add($name)
  foreach ($a in $aliases) { if ($a) { if (-not $aliasOwner.ContainsKey($a)) { $aliasOwner[$a] = New-Object System.Collections.Generic.List[string] }; $aliasOwner[$a].Add($name) } }
}

$streamerPlaylistCount = @{}
foreach ($obj in $playlistObjs) {
  $game = Field $obj "game"
  $streamer = Field $obj "streamer"
  if ($streamer) {
    if (-not $streamerPlaylistCount.ContainsKey($streamer)) { $streamerPlaylistCount[$streamer] = 0 }
    $streamerPlaylistCount[$streamer] = $streamerPlaylistCount[$streamer] + 1
  }
  if ($game -and $games.Contains($game)) {
    $games[$game].playlists.Add([PSCustomObject][ordered]@{
      id          = Field $obj "id"
      title       = Field $obj "title"
      streamer    = $streamer
      genre       = Field $obj "genre"
      playlistId  = Field $obj "playlistId"
      playlistUrl = if (Field $obj "playlistId") { "https://www.youtube.com/playlist?list=" + (Field $obj "playlistId") } else { "" }
      videoCount  = Field $obj "videoCount"
      updatedDate = Field $obj "updatedDate"
      addedDate   = Field $obj "addedDate"
    })
  }
}

# 実況者ごとの合計件数は全playlist走査後でないと確定しないため、ここで反映する
foreach ($name in $gameOrder) {
  foreach ($p in $games[$name].playlists) {
    Add-Member -InputObject $p -NotePropertyName "streamerTotalPlaylists" -NotePropertyValue ($streamerPlaylistCount[$p.streamer]) -Force
  }
}

# ---- series(シリーズ)単位の集計 ----
$seriesTotals = @{}
$seriesMax = @{}
foreach ($name in $gameOrder) {
  $s = $games[$name].series
  if (-not $s) { continue }
  $count = $games[$name].playlists.Count
  if (-not $seriesTotals.ContainsKey($s)) { $seriesTotals[$s] = 0; $seriesMax[$s] = 0 }
  $seriesTotals[$s] = $seriesTotals[$s] + $count
  if ($count -gt $seriesMax[$s]) { $seriesMax[$s] = $count }
}

# ============================================================
# STEP1: 再生リスト0件のゲーム
# ============================================================
$zeroGames = @($gameOrder | Where-Object { $games[$_].playlists.Count -eq 0 } | Sort-Object -Culture "ja-JP")

$zeroReport = @($zeroGames | ForEach-Object {
  $g = $games[$_]
  $siblingMax = if ($g.series -and $seriesMax.ContainsKey($g.series)) { $seriesMax[$g.series] } else { 0 }
  $aliasHits = @()
  foreach ($a in $g.aliases) {
    if ($aliasOwner.ContainsKey($a)) {
      foreach ($other in $aliasOwner[$a]) {
        if ($other -ne $g.name -and $games[$other].playlists.Count -gt 0) { $aliasHits += "$other(同じ別名`"$a`"を使用、再生リスト$($games[$other].playlists.Count)件)" }
      }
    }
  }
  $hypothesis = New-Object System.Collections.Generic.List[string]
  if ($aliasHits.Count -gt 0) { $hypothesis.Add("別名が重複している別タイトルに実況が集約されている可能性: " + ($aliasHits -join " / ")) }
  if ($g.series -and $siblingMax -ge 10) { $hypothesis.Add("同シリーズ(`"$($g.series)`")の他タイトルは最大${siblingMax}件の実況があり、シリーズ自体は既にカバーされている") }
  if ($g.name -eq $g.series) { $hypothesis.Add("このエントリ自体がシリーズ全体を表す集約用の名称である可能性(個別タイトル側に実況が付く設計と考えられる)") }
  if ($hypothesis.Count -eq 0) { $hypothesis.Add("コード上から明確な理由は判断できません(純粋に未着手の可能性)") }

  [PSCustomObject][ordered]@{
    name              = $g.name
    slug              = $null   # このデータモデルにはslugの概念が無く、name自体をURLエンコードして識別子に使う
    url               = "game.html?game=" + [uri]::EscapeDataString($g.name)
    series            = $g.series
    aliases           = $g.aliases
    hasEditorial      = $g.hasEditorial
    streamerLinkCount = 0
    seriesSiblingMax  = $siblingMax
    hypothesis        = $hypothesis -join " / "
  }
})

# ============================================================
# STEP2: 再生リスト1件のゲーム
# ============================================================
$oneGames = @($gameOrder | Where-Object { $games[$_].playlists.Count -eq 1 } | Sort-Object -Culture "ja-JP")
$oneReport = @($oneGames | ForEach-Object {
  $g = $games[$_]
  $p = $g.playlists[0]
  $siblingMax = if ($g.series -and $seriesMax.ContainsKey($g.series)) { $seriesMax[$g.series] } else { 0 }
  [PSCustomObject][ordered]@{
    name                   = $g.name
    url                    = "game.html?game=" + [uri]::EscapeDataString($g.name)
    series                 = $g.series
    playlistTitle          = $p.title
    streamer               = $p.streamer
    streamerUrl            = "streamer.html?streamer=" + [uri]::EscapeDataString($p.streamer)
    playlistUrl            = $p.playlistUrl
    genre                  = $p.genre
    videoCount             = $p.videoCount
    updatedDate            = $p.updatedDate
    streamerTotalPlaylists = $p.streamerTotalPlaylists
    seriesSiblingMax       = $siblingMax
  }
})

# ============================================================
# STEP3: シリーズ内の偏りが大きいゲーム(2件以上あるゲームのうち、
#        兄弟タイトルの最大値に比べて著しく少ないもの。あくまで参考情報)
# ============================================================
$biasedGames = @($gameOrder | Where-Object {
  $g = $games[$_]
  $c = $g.playlists.Count
  $g.series -and $c -ge 1 -and $seriesMax.ContainsKey($g.series) -and $seriesMax[$g.series] -ge 20 -and $c -le [Math]::Max(1, [Math]::Floor($seriesMax[$g.series] * 0.1))
} | Sort-Object -Culture "ja-JP")
$biasedReport = @($biasedGames | ForEach-Object {
  $g = $games[$_]
  [PSCustomObject][ordered]@{
    name             = $g.name
    series           = $g.series
    playlistCount    = $g.playlists.Count
    seriesSiblingMax = $seriesMax[$g.series]
  }
})

# ============================================================
# 出力
# ============================================================
Write-Output "=== ぶいゲー 拡充候補分析 (find-expansion-candidates.ps1) ==="
Write-Output "※外部検索(YouTube API等)は一切使用していません。既存データのみの機械的整理です。"
Write-Output ""
Write-Output "[STEP1] 再生リスト0件のゲーム: $($zeroReport.Count)件"
foreach ($r in $zeroReport) {
  Write-Output ("  - {0}" -f $r.name)
  Write-Output ("      series: {0}" -f $(if ($r.series) { $r.series } else { "(未設定)" }))
  Write-Output ("      根拠/仮説: {0}" -f $r.hypothesis)
}
Write-Output ""

Write-Output ("[STEP2] 再生リスト1件のゲーム: $($oneReport.Count)件 (先頭{0}件のみ表示。全件は-Csv/-Json参照)" -f $Top)
$shown = if ($Top -gt 0) { $oneReport | Select-Object -First $Top } else { $oneReport }
foreach ($r in $shown) {
  Write-Output ("  - {0} / {1} (実況者{2}の他playlist数:{3})" -f $r.name, $r.streamer, $r.streamer, $r.streamerTotalPlaylists)
}
Write-Output ""

Write-Output "[STEP3] シリーズ内で著しく手薄なゲーム(シリーズ最大件数の10%以下、シリーズ最大20件以上が対象): $($biasedReport.Count)件"
foreach ($r in $biasedReport) {
  Write-Output ("  - {0} (このタイトル{1}件 / シリーズ`"{2}`"最大{3}件)" -f $r.name, $r.playlistCount, $r.series, $r.seriesSiblingMax)
}
Write-Output ""
Write-Output "重要: 上記はいずれも既存データからの機械的な仮説・整理であり、実際にそのVTuberが"
Write-Output "そのゲームを実況しているという確認済みの事実ではありません。本番データへの反映は"
Write-Output "人間による実際の確認(YouTube上での実在確認)を経てから行ってください。"

if ($Json) {
  $report = [ordered]@{
    generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
    note        = "外部検索は使用していません。既存データのみの機械的整理・仮説です。"
    zeroPlaylistGames = $zeroReport
    onePlaylistGames  = $oneReport
    seriesBiasedGames = $biasedReport
  }
  $jsonDir = Split-Path -Parent $Json
  if ($jsonDir -and -not (Test-Path $jsonDir)) { New-Item -ItemType Directory -Path $jsonDir -Force | Out-Null }
  ($report | ConvertTo-Json -Depth 6) | Set-Content -Path $Json -Encoding UTF8
  Write-Output ""
  Write-Output "詳細をJSONで出力しました: $Json"
}

if ($Csv) {
  $csvDir = Split-Path -Parent $Csv
  if ($csvDir -and -not (Test-Path $csvDir)) { New-Item -ItemType Directory -Path $csvDir -Force | Out-Null }
  $oneReport | Export-Csv -Path $Csv -Encoding UTF8 -NoTypeInformation
  Write-Output "再生リスト1件ゲームの一覧をCSVで出力しました: $Csv"
}

exit 0
