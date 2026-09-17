<#
.SYNOPSIS
  ぶいゲー定常運用の入口コマンド。「探索対象選定 → API探索 → 候補抽出 →
  重複/ゲーム照合 → 自動分類 → dry-run → 人間確認用レポート生成」までを
  1コマンドで実行する。production(data-playlists.js等)は一切変更しない。

.DESCRIPTION
  新しい探索・判定ロジックは実装していません。すべて既存スクリプトを
  子プロセスとして呼び出す薄いオーケストレーターです。

    discover-playlists.ps1        … VTuberの公式チャンネルからplaylistを取得(既存)
    match-playlist-candidates.ps1 … ゲーム名照合・重複除外・confidence判定(既存、
                                     第1サイクルの知見でitemCount=0対応を追加済み)
    data-audit.ps1 / validate-data.ps1 … 状態確認・dry-run検証(既存)

  このスクリプト自身が新たに行うのは、
    - 探索対象VTuberの選定(既存データのカウントだけを使う単純な並び替え)
    - 複数VTuberの discover 結果のJSONマージ(単純な配列結合)
    - HIGH/MEDIUM/LOW を import-ready(A) / manual-review(B) / reject(C) へ
      対応付けること(閾値を緩めない固定ルール)
    - dry-run用の隔離コピーへの一時挿入(本番ファイルには一切書き込まない)
    - レポート・探索履歴の保存
  だけです。判定ロジック自体は match-playlist-candidates.ps1 側にある
  ものをそのまま使い、二重実装していません。

  安全機構:
    - production(data-playlists.js等)への書き込みは一切行わない
    - commit / push / deploy は一切行わない
    - 1回の実行で探索するVTuber数の上限(既定 $script:DefaultMaxVtubers 件、
      -MaxVtubers で変更可)
    - 直近 $script:DefaultSuppressDays 日以内に探索済みのVTuberは既定で除外
      (-Force で無視可能。マジックナンバーにせず下記の名前付き定数で管理)
    - dry-runでERRORが1件でもあれば、該当候補はimport-readyのまま出力しない
      (自動でproductionへ投入する経路はこのスクリプトには存在しない)

.PARAMETER MaxVtubers
  1回の実行で探索するVTuber数の上限。

.PARAMETER SuppressDays
  直近何日以内に探索したVTuberを除外するか。

.PARAMETER Force
  SuppressDaysを無視してVTuberを選び直す(過去の探索履歴を無視する)。

.PARAMETER FetchVideoSamples
  manual-review候補について、代表動画タイトル(最大5件)を追加のAPI呼び出しで
  取得する(既定でON。manual-review件数が少ない前提でquota影響は小さいが、
  -FetchVideoSamples:$false で無効化できる)。

.PARAMETER TestDiscoveredJson
  指定すると、YouTube APIを一切呼び出さず、指定したJSON(discover-playlists.ps1
  と同じ形式)を探索結果として使う動作確認用モード(quota消費ゼロ)。

.PARAMETER MaxResultsPerGame
  未使用(将来のsearch.list方式向けに予約。現在の既定経路では使用しない)。

.EXAMPLE
  .\run-playlist-cycle.ps1
.EXAMPLE
  .\run-playlist-cycle.ps1 -MaxVtubers 10
.EXAMPLE
  .\run-playlist-cycle.ps1 -Force
.EXAMPLE
  .\run-playlist-cycle.ps1 -TestDiscoveredJson reports/discovered-merged-cycle2b.json
#>
param(
  [int]$MaxVtubers = 6,
  [int]$SuppressDays = 30,
  [switch]$Force,
  [bool]$FetchVideoSamples = $true,
  [string]$TestDiscoveredJson
)

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$corePath = Join-Path $scriptDir "data-core.js"
$playlistsPath = Join-Path $scriptDir "data-playlists.js"
$discoverScript = Join-Path $scriptDir "discover-playlists.ps1"
$matchScript = Join-Path $scriptDir "match-playlist-candidates.ps1"
$auditScript = Join-Path $scriptDir "data-audit.ps1"
$validateScript = Join-Path $scriptDir "validate-data.ps1"

# ---- 名前付き定数(マジックナンバー回避) ----
$script:DefaultMaxVtubers = 6
$script:DefaultSuppressDays = 30
$script:MaxVideoSampleCalls = 10   # manual-review向け追加API呼び出しの安全弁(念のための上限)

$opsDir = Join-Path $scriptDir "reports\playlist-operations"
$historyPath = Join-Path $opsDir "search-history.json"
$cycleId = "cycle-" + (Get-Date).ToString("yyyyMMdd-HHmm")
$cycleDir = Join-Path $opsDir $cycleId
New-Item -ItemType Directory -Path $cycleDir -Force | Out-Null

$apiKey = $env:YOUTUBE_API_KEY
$usingLiveApi = -not $TestDiscoveredJson
if ($usingLiveApi -and -not $apiKey) {
  Write-Error "YOUTUBE_API_KEY が環境変数に見つかりません。値を直接指定せず、環境変数を設定するか -TestDiscoveredJson でテストモードを使ってください。"
  exit 1
}
function Get-RedactedMessage([string]$msg) {
  if ($apiKey -and $msg) { return $msg -replace [regex]::Escape($apiKey), "***REDACTED***" }
  return $msg
}

Write-Output "=============================="
Write-Output "ぶいゲー 定常データ拡充 (run-playlist-cycle.ps1)"
Write-Output "cycleId: $cycleId"
Write-Output "=============================="
Write-Output ""

# ============================================================
# STEP1: 現在状態確認(既存 data-audit.ps1 を子プロセスとして再利用)
# ============================================================
Write-Output "[STEP1] 現在状態を確認しています(data-audit.ps1)..."
$auditJsonPath = Join-Path $cycleDir "pre-audit.json"
& powershell.exe -NoProfile -File $auditScript -Json $auditJsonPath | Out-Null
$preAudit = Get-Content $auditJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
Write-Output ("  ゲーム: {0}  VTuber: {1}  再生リスト: {2}  ERROR合計: {3}" -f $preAudit.totals.games, $preAudit.totals.streamers, $preAudit.totals.playlists, $preAudit.errorTotal)
if ($preAudit.errorTotal -gt 0) {
  Write-Error "現在のproductionデータに既にERRORが存在します。安全のためここで停止します(自動修正はしません)。"
  exit 1
}
Write-Output ""

# ============================================================
# パーサ(既存の他スクリプトと同じ手法。判定ロジックの二重実装ではなく
# 「選定に必要な件数集計」だけを行う専用の最小限の読み取り)
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
    if ($ch -eq '[') { $depth++ }
    elseif ($ch -eq ']') { $depth--; if ($depth -eq 0) { return $text.Substring($i, $p - $i) } }
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
    if ($ch -eq '{') { if ($depth -eq 0) { $start = $i }; $depth++ }
    elseif ($ch -eq '}') { $depth--; if ($depth -eq 0 -and $start -ge 0) { $results += $inner.Substring($start, $i - $start + 1); $start = -1 } }
  }
  return $results
}
function Field([string]$obj, [string]$name) {
  $m = [regex]::Match($obj, [regex]::Escape($name) + '\s*:\s*"((?:\\.|[^"])*)"')
  if ($m.Success) { return ($m.Groups[1].Value -replace '\\"', '"' -replace '\\\\', '\') }
  return ""
}

# ============================================================
# STEP2: 探索対象選定
#   優先順位(シンプルな2キーソートで説明可能にする):
#     1. 再生リスト数が少ない(0件優先)
#     2. 同数なら、最後に探索してからの経過日数が長い(未探索は最優先)
#   ゲーム側からの補完(優先順位5)は、未探索VTuberとゲームを推測で
#   紐付けることになり安全性を損なうため、今回は選定に含めない
#   (find-expansion-candidates.ps1 側で別途、内部データだけのゲーム側分析は
#   既に提供済みのためそちらを参照してください)。
# ============================================================
Write-Output "[STEP2] 探索対象VTuberを選定しています..."

$coreText = [System.IO.File]::ReadAllText($corePath, [System.Text.Encoding]::UTF8)
$playlistsText = [System.IO.File]::ReadAllText($playlistsPath, [System.Text.Encoding]::UTF8)
$streamerObjs = Get-Objects (Get-ArrayInner "STREAMERS" $coreText)
$playlistObjs = Get-Objects (Get-ArrayInner "PLAYLISTS" $playlistsText)

$playlistCountByStreamer = @{}
foreach ($o in $playlistObjs) {
  $s = Field $o "streamer"
  if ($s) { if (-not $playlistCountByStreamer.ContainsKey($s)) { $playlistCountByStreamer[$s] = 0 }; $playlistCountByStreamer[$s] = $playlistCountByStreamer[$s] + 1 }
}

$history = @{}
if (Test-Path $historyPath) {
  $historyArr = Get-Content $historyPath -Raw -Encoding UTF8 | ConvertFrom-Json
  foreach ($h in $historyArr) { $history[$h.streamerName] = $h }
}

$candidatesForSelection = New-Object System.Collections.Generic.List[object]
foreach ($o in $streamerObjs) {
  $name = Field $o "name"
  if (-not $name) { continue }
  $yt = Field $o "youtube"
  $count = if ($playlistCountByStreamer.ContainsKey($name)) { $playlistCountByStreamer[$name] } else { 0 }
  $daysSince = [double]::MaxValue
  if ($history.ContainsKey($name) -and $history[$name].lastSearchedAt) {
    $last = [DateTime]::Parse($history[$name].lastSearchedAt)
    $daysSince = (Get-Date) - $last | Select-Object -ExpandProperty TotalDays
  }
  if (-not $Force -and $daysSince -lt $SuppressDays) { continue } # 直近探索済みは除外
  $candidatesForSelection.Add([PSCustomObject]@{ name = $name; youtube = $yt; playlistCount = $count; daysSinceSearch = $daysSince })
}

$selected = @($candidatesForSelection | Sort-Object playlistCount, @{Expression = { -$_.daysSinceSearch } } | Select-Object -First $MaxVtubers)

if ($selected.Count -eq 0 -and $usingLiveApi) {
  Write-Output "  探索対象が0件でした(直近${SuppressDays}日以内に対象VTuberが探索済みの可能性)。-Force で再探索するか、対象を増やしてください。"
  Write-Output ""
  Write-Output "=============================="
  Write-Output "本番データは変更していません"
  Write-Output "=============================="
  exit 0
}
Write-Output "  (選定結果はAPI探索/テストモード確定後にまとめて表示します)"
Write-Output ""

# ============================================================
# STEP3: API探索(既存 discover-playlists.ps1 を再利用)
# ============================================================
$rawDir = Join-Path $cycleDir "raw-discover"
# discover-playlists.ps1 は内部で "$scriptDir\$OutFile" のように結合するため、
# -OutFile には絶対パスではなく $scriptDir からの相対パスを渡す必要がある
# (絶対パスを渡すとパス結合が壊れ、コロンがNTFSの代替データストリーム区切りと
# 誤認識されるエラーになることを実機で確認したための対応)。
$rawDirRelative = "reports\playlist-operations\$cycleId\raw-discover"
New-Item -ItemType Directory -Path $rawDir -Force | Out-Null
$allDiscovered = @()
$searchedNames = New-Object System.Collections.Generic.List[string]
$apiCallCount = 0

if (-not $usingLiveApi) {
  Write-Output "[STEP3] テストモード(-TestDiscoveredJson指定): APIを呼び出さず既存JSONを使用します。"
  $allDiscovered = Get-Content $TestDiscoveredJson -Raw -Encoding UTF8 | ConvertFrom-Json
  foreach ($e in $allDiscovered) { $searchedNames.Add($e.streamer) }
  # テストモードではSTEP2の選定結果ではなく、実際にテストJSONに含まれる
  # streamerで表示・履歴を揃える(選定リストとテストデータの不一致を防ぐため)。
  $selected = @($searchedNames | Select-Object -Unique | ForEach-Object {
    $n = $_
    $yt = ""
    foreach ($o in $streamerObjs) { if ((Field $o "name") -eq $n) { $yt = Field $o "youtube"; break } }
    [PSCustomObject]@{ name = $n; youtube = $yt; playlistCount = $(if ($playlistCountByStreamer.ContainsKey($n)) { $playlistCountByStreamer[$n] } else { 0 }); daysSinceSearch = [double]::MaxValue }
  })
} else {
  Write-Output "[STEP3] discover-playlists.ps1でAPI探索しています..."
  $i = 0
  foreach ($s in $selected) {
    $i++
    $outRelative = "$rawDirRelative\discover-$i.json"
    $out = Join-Path $rawDir "discover-$i.json"
    try {
      $output = & powershell.exe -NoProfile -File $discoverScript -Streamer $s.name -OutFile $outRelative 2>&1 | Out-String
      $safe = Get-RedactedMessage $output
      Write-Output ("  [{0}/{1}] {2}: {3}" -f $i, $selected.Count, $s.name, ($safe.Trim() -split "`n" | Select-Object -Last 1))
      $apiCallCount++
      if (Test-Path $out) {
        $data = Get-Content $out -Raw -Encoding UTF8 | ConvertFrom-Json
        $allDiscovered += $data
        $searchedNames.Add($s.name)
      }
    } catch {
      Write-Warning ("  [{0}] 取得失敗: {1}" -f $s.name, (Get-RedactedMessage $_.Exception.Message))
    }
  }
}

Write-Output ("  対象{0}名(既存再生リスト件数の少ない順・未探索/長期未探索を優先。テストモード時は入力JSONのstreamerに合わせて表示):" -f $selected.Count)
foreach ($s in $selected) {
  $daysLabel = if ($s.daysSinceSearch -eq [double]::MaxValue) { "未探索" } else { "{0:N0}日前に探索" -f $s.daysSinceSearch }
  Write-Output ("    - {0} (既存{1}件、{2})" -f $s.name, $s.playlistCount, $daysLabel)
}
Write-Output ""

$mergedPath = Join-Path $cycleDir "discovered-merged.json"
($allDiscovered | ConvertTo-Json -Depth 8) | Set-Content -Path $mergedPath -Encoding UTF8
$totalPlaylistsFound = ($allDiscovered | ForEach-Object { $_.playlists.Count } | Measure-Object -Sum).Sum
if (-not $totalPlaylistsFound) { $totalPlaylistsFound = 0 }

# ============================================================
# STEP4-7: 候補抽出・重複チェック・ゲーム照合・自動分類
#   (既存 match-playlist-candidates.ps1 をそのまま再利用。判定ロジックの
#    二重実装はしていない)
# ============================================================
Write-Output "[STEP4-7] match-playlist-candidates.ps1で照合・分類しています..."
$candidatesJsonPath = Join-Path $cycleDir "candidates.json"
& powershell.exe -NoProfile -File $matchScript -DiscoveredJson $mergedPath -Json $candidatesJsonPath | Out-Null
$matchReport = Get-Content $candidatesJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
$allCandidates = @($matchReport.candidates)

# HIGH/MEDIUM/LOW を A(import-ready)/B(manual-review)/C(reject) へ対応付ける。
# 判定基準を緩める余地を無くすため、A判定は「confidence=HIGHのみ」に限定する
# (HIGH自体が「公式channel一致・曖昧一致なし・非ゲーム語なし・itemCount>0」を
#  既に満たした場合にのみ付与される値のため、ここでの再判定は行わない)。
$importReady = @($allCandidates | Where-Object { $_.confidence -eq "HIGH" })
$reject = @($allCandidates | Where-Object { $_.likelyNonGame -eq $true })
$manualReview = @($allCandidates | Where-Object { $_.confidence -ne "HIGH" -and $_.likelyNonGame -ne $true })

Write-Output ("  発見playlist(全チャンネル合計): {0}" -f $totalPlaylistsFound)
Write-Output ("  新規候補: {0}  import-ready: {1}  manual-review: {2}  reject: {3}" -f $allCandidates.Count, $importReady.Count, $manualReview.Count, $reject.Count)
Write-Output ""

# ============================================================
# manual-review向け: 代表動画タイトルの取得(既定ON、上限あり)
# ============================================================
$videoSamples = @{}
if ($FetchVideoSamples -and $usingLiveApi -and $manualReview.Count -gt 0) {
  $fetchCount = [Math]::Min($manualReview.Count, $script:MaxVideoSampleCalls)
  Write-Output ("[補足] manual-review候補{0}件について代表動画タイトルを取得しています(上限{1}件)..." -f $manualReview.Count, $script:MaxVideoSampleCalls)
  $n = 0
  foreach ($c in $manualReview) {
    if ($n -ge $fetchCount) { break }
    $n++
    try {
      $url = "https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&playlistId=$($c.playlistId)&maxResults=5&key=$apiKey"
      $resp = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop
      $videoSamples[$c.playlistId] = @($resp.items | ForEach-Object { $_.snippet.title })
      $apiCallCount++
    } catch {
      Write-Warning ("  動画タイトル取得失敗({0}): {1}" -f $c.playlistId, (Get-RedactedMessage $_.Exception.Message))
      $videoSamples[$c.playlistId] = @()
    }
  }
  Write-Output ""
}

# ============================================================
# STEP10: dry-run(import-readyのみ。隔離コピー、既存validate-data.ps1を再利用)
# ============================================================
$dryRunPass = $true
$dryRunErrorCount = 0
if ($importReady.Count -gt 0) {
  Write-Output "[STEP10] import-ready候補についてdry-runしています(隔離コピー、production未変更)..."
  $dryDir = Join-Path ([System.IO.Path]::GetTempPath()) ("vgame-cycle-dryrun-" + [Guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Path $dryDir -Force | Out-Null
  Copy-Item $corePath (Join-Path $dryDir "data-core.js")
  Copy-Item $playlistsPath (Join-Path $dryDir "data-playlists.js")
  Copy-Item $validateScript (Join-Path $dryDir "validate-data.ps1")

  $dryPlaylistsPath = Join-Path $dryDir "data-playlists.js"
  $lines = [System.IO.File]::ReadAllLines($dryPlaylistsPath, [System.Text.Encoding]::UTF8)
  $closeIdx = -1
  for ($i = 0; $i -lt $lines.Length; $i++) { if ($lines[$i].Trim() -eq "];") { $closeIdx = $i; break } }

  $genreCache = @{}
  function Get-SuggestedGenre([string]$game) {
    if ($genreCache.ContainsKey($game)) { return $genreCache[$game] }
    $m = [regex]::Match($playlistsText, [regex]::Escape('game: "' + $game + '"') + '[^}]*?genre:\s*"([^"]*)"')
    $g = if ($m.Success) { $m.Groups[1].Value } else { "other" }
    $genreCache[$game] = $g
    return $g
  }

  $block = New-Object System.Collections.Generic.List[string]
  $seq = 0
  foreach ($c in $importReady) {
    $seq++
    $genre = Get-SuggestedGenre $c.game
    $block.Add("  {")
    $block.Add('    id: "dryrun-' + $cycleId + '-' + $seq + '",')
    $block.Add('    title: "' + ($c.title -replace '"', '\"') + '",')
    $block.Add('    streamer: "' + ($c.streamer -replace '"', '\"') + '",')
    $block.Add('    game: "' + ($c.game -replace '"', '\"') + '",')
    $block.Add('    genre: "' + $genre + '",')
    $block.Add('    playlistId: "' + $c.playlistId + '",')
    $block.Add('    videoCount: ' + [int]$c.itemCount + ',')
    $block.Add('    addedDate: "' + (Get-Date).ToString("yyyy-MM-dd") + '",')
    $block.Add("  },")
  }
  $newLines = $lines[0..($closeIdx - 1)] + $block.ToArray() + $lines[$closeIdx..($lines.Length - 1)]
  [System.IO.File]::WriteAllLines($dryPlaylistsPath, $newLines, (New-Object System.Text.UTF8Encoding($false)))

  $dryResultPath = Join-Path $cycleDir "dryrun-result.json"
  Push-Location $dryDir
  try {
    & powershell.exe -NoProfile -File ".\validate-data.ps1" -Json $dryResultPath | Out-Null
  } finally {
    Pop-Location
  }
  $dryResult = Get-Content $dryResultPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $dryRunErrorCount = 0
  foreach ($p in $dryResult.errors.PSObject.Properties) { $dryRunErrorCount += [int]$p.Value }
  $dryRunPass = ($dryRunErrorCount -eq 0)
  Remove-Item -Recurse -Force $dryDir

  Write-Output ("  dry-run結果: 再生リスト{0}件(投入想定) / ERROR {1}" -f $dryResult.playlistCount, $dryRunErrorCount)
  if (-not $dryRunPass) {
    Write-Warning "  dry-runでERRORを検出したため、import-ready候補はレポート上そのまま提示しますが、production投入には使用しないでください。"
  }
} else {
  Write-Output "[STEP10] import-ready候補が0件のため、dry-runはスキップしました。"
}
Write-Output ""

# ============================================================
# STEP9/11: レポート保存
# ============================================================
$summary = [ordered]@{
  cycleId            = $cycleId
  generatedAt        = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
  mode               = if ($usingLiveApi) { "live-api" } else { "test-mode(no-api)" }
  targetVtubers      = @($selected | ForEach-Object { $_.name })
  playlistsFound     = $totalPlaylistsFound
  newCandidates      = $allCandidates.Count
  importReadyCount   = $importReady.Count
  manualReviewCount  = $manualReview.Count
  rejectCount        = $reject.Count
  dryRunPass         = $dryRunPass
  dryRunErrorCount   = $dryRunErrorCount
  preAudit           = [ordered]@{ games = $preAudit.totals.games; streamers = $preAudit.totals.streamers; playlists = $preAudit.totals.playlists; errorTotal = $preAudit.errorTotal }
  apiCallsUsedApprox = $apiCallCount
  productionChanged  = $false
}
($summary | ConvertTo-Json -Depth 6) | Set-Content -Path (Join-Path $cycleDir "summary.json") -Encoding UTF8

$classification = [ordered]@{
  importReady   = $importReady
  manualReview  = $manualReview
  reject        = $reject
}
($classification | ConvertTo-Json -Depth 8) | Set-Content -Path (Join-Path $cycleDir "classification.json") -Encoding UTF8

# manual-review.md (人間が読みやすい形式)
$md = New-Object System.Collections.Generic.List[string]
$md.Add("# manual-review候補 ($cycleId)")
$md.Add("")
$md.Add("production未反映。人間による確認・判断が必要な候補一覧です。")
$md.Add("")
if ($manualReview.Count -eq 0) {
  $md.Add("該当なし。")
} else {
  $n = 0
  foreach ($c in $manualReview) {
    $n++
    $md.Add("## $n. $($c.streamer) / $($c.game)")
    $md.Add("")
    $md.Add("- playlistタイトル: $($c.title)")
    $md.Add("- playlist ID: $($c.playlistId)")
    $md.Add("- playlist URL: $($c.playlistUrl)")
    $md.Add("- itemCount: $($c.itemCount)")
    $md.Add("- confidence: $($c.confidence)")
    $md.Add("- manual-review理由: $($c.warning)")
    if ($videoSamples.ContainsKey($c.playlistId) -and $videoSamples[$c.playlistId].Count -gt 0) {
      $md.Add("- 代表動画タイトル:")
      foreach ($t in $videoSamples[$c.playlistId]) { $md.Add("  - $t") }
    } else {
      $md.Add("- 代表動画タイトル: (未取得。手動確認するか -FetchVideoSamples を有効にして再実行してください)")
    }
    $md.Add("")
  }
}
$md -join "`n" | Set-Content -Path (Join-Path $cycleDir "manual-review.md") -Encoding UTF8

# ============================================================
# STEP3(探索履歴)の更新
#   テストモード(-TestDiscoveredJson)では実際の探索を行っていないため、
#   履歴を汚さないよう更新をスキップする。
# ============================================================
if (-not $usingLiveApi) {
  Write-Output "[補足] テストモードのため探索履歴(search-history.json)は更新していません。"
  Write-Output ""
}
if ($usingLiveApi) {
if (-not (Test-Path $opsDir)) { New-Item -ItemType Directory -Path $opsDir -Force | Out-Null }
$historyArr = @()
# 注意: @(Get-Content ... | ConvertFrom-Json) は、Windows PowerShell 5.1では
# ConvertFrom-Jsonが返す配列そのものが1個のパイプライン要素として渡されるため、
# @() で二重にラップされ [ [6要素配列] ] のような壊れた構造になることを実機で確認した。
# そのため @() を付けず、foreach側でスカラー/配列どちらも安全に扱う。
if (Test-Path $historyPath) {
  $parsed = Get-Content $historyPath -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($null -ne $parsed) { $historyArr = $parsed }
}
$historyList = New-Object System.Collections.Generic.List[object]
foreach ($h in $historyArr) {
  # 過去の不具合で壊れた形式(value/Countプロパティを持つラッパー)が万一残っていた場合の保険
  if ($h.PSObject.Properties.Name -contains "value" -and $h.PSObject.Properties.Name -contains "Count" -and -not ($h.PSObject.Properties.Name -contains "streamerName")) {
    foreach ($inner in $h.value) { $historyList.Add($inner) }
    continue
  }
  $historyList.Add($h)
}

foreach ($s in $selected) {
  $streamerCandidates = @($allCandidates | Where-Object { $_.streamer -eq $s.name })
  $existing = $historyList | Where-Object { $_.streamerName -eq $s.name } | Select-Object -First 1
  $entry = [ordered]@{
    streamerName     = $s.name
    channelUrl       = $s.youtube
    lastSearchedAt   = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
    playlistsFound   = @($allDiscovered | Where-Object { $_.streamer -eq $s.name } | ForEach-Object { $_.playlists.Count } | Measure-Object -Sum).Sum
    newCandidates    = $streamerCandidates.Count
    importReadyCount = @($streamerCandidates | Where-Object { $_.confidence -eq "HIGH" }).Count
    manualReviewCount = @($streamerCandidates | Where-Object { $_.confidence -ne "HIGH" -and $_.likelyNonGame -ne $true }).Count
    rejectCount      = @($streamerCandidates | Where-Object { $_.likelyNonGame -eq $true }).Count
    searchMethod     = "discover-playlists.ps1(official-channel)"
    apiUsed          = $usingLiveApi
    cycleId          = $cycleId
  }
  if ($existing) { $historyList.Remove($existing) | Out-Null }
  $historyList.Add([PSCustomObject]$entry)
}
($historyList | ConvertTo-Json -Depth 6) | Set-Content -Path $historyPath -Encoding UTF8
}

# ============================================================
# STEP12: 最終コンソール表示
# ============================================================
Write-Output "=============================="
Write-Output "ぶいゲー 定常データ拡充"
Write-Output "=============================="
Write-Output ""
Write-Output "探索VTuber："
Write-Output "  $($selected.Count)"
Write-Output ""
Write-Output "発見playlist："
Write-Output "  $totalPlaylistsFound"
Write-Output ""
Write-Output "新規候補："
Write-Output "  $($allCandidates.Count)"
Write-Output ""
Write-Output "import-ready："
Write-Output "  $($importReady.Count)"
Write-Output ""
Write-Output "manual-review："
Write-Output "  $($manualReview.Count)"
Write-Output ""
Write-Output "reject："
Write-Output "  $($reject.Count)"
Write-Output ""
Write-Output "dry-run："
Write-Output "  $(if ($importReady.Count -eq 0) { 'N/A(import-ready 0件)' } elseif ($dryRunPass) { 'PASS' } else { 'FAIL' })"
Write-Output ""
Write-Output "audit："
Write-Output "  ERROR $($preAudit.errorTotal)(実行前。本番は今回変更していません)"
Write-Output ""
Write-Output "レポート："
Write-Output "  $cycleDir"
Write-Output ""
Write-Output "=============================="
Write-Output "本番データは変更していません"
Write-Output "人間確認を行ってください"
Write-Output "=============================="
