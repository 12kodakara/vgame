<#
.SYNOPSIS
  RSS / API 巡回で見つけた確認待ちの単発実況候補を、人が審査するための CSV(確認シート)に書き出します。
  YouTube API・RSS には接続しません。候補・履歴・登録データは読むだけで変更しません。

.DESCRIPTION
  1) 候補 JSON を読む(既定は rss-state ブランチの discovered-standalone-rss.json を git show で読む。-CandidatesPath でファイルも指定可)
  2) status = pending の候補だけを対象にする(承認・保留・除外など判断済みの候補は載せない)
  3) watch-standalone-rss.ps1 が付けた確認分類(reviewCategory)で行を作る
       single          : 1動画1行
       series          : 配信者×作品(seriesKey)ごとに1行(動画本数・URL・動画IDをまとめる)。承認すると multi として登録する想定
       playlist-review : 1動画1行(登録済み再生リストに入っている可能性がある回)
       non-gameplay    : 行にせず件数だけ表示する(ショート・切り抜きなど)
     分類の無い確認待ち候補(既存作品に一致しなくなったものなど)も件数だけ表示する
  4) 作品のジャンル(genre)は、data-playlists.js / data-standalone.js で同じ作品に付いているものから多いものを下書きする
     同じ配信者×作品の登録済み再生リスト数・単発実況 ID も参考に載せる(重複登録の確認用)
  5) Excel で文字化けしない BOM 付き UTF-8・CRLF の CSV を書き出す
  判断欄(decision)は空欄で出す: approve(承認) / hold(保留) / reject(除外) を人が記入する。
  CSV の取り込み(判断の反映・登録)は別の処理で行う(このスクリプトは書き出しだけ)。

.PARAMETER CandidatesPath
  候補 JSON のファイル。省略時は -StateRef の discovered-standalone-rss.json を git show で読む。
.PARAMETER StateRef
  候補 JSON を読む Git の参照(既定 origin/rss-state。事前に git fetch origin しておく)。
.PARAMETER OutDir
  CSV の書き出し先(既定は OS の一時フォルダの vgame-standalone-review。リポジトリの外なので Git の管理対象にならない)。
.EXAMPLE
  git fetch origin; .\export-standalone-review.ps1
#>
param(
  [string]$CandidatesPath,
  [string]$StateRef = "origin/rss-state",
  [string]$OutDir = (Join-Path ([IO.Path]::GetTempPath()) "vgame-standalone-review"),
  [string]$PlaylistsPath,
  [string]$StandalonePath
)

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
if (-not $PlaylistsPath) { $PlaylistsPath = Join-Path $scriptDir "data-playlists.js" }
if (-not $StandalonePath) { $StandalonePath = Join-Path $scriptDir "data-standalone.js" }

# JSON は日付を文字列のまま読む(PowerShell 7 の ConvertFrom-Json は日付に見える文字列を日時型に変えるため)
function ConvertFrom-ReviewJson([string]$text) {
  $text = $text.TrimStart([char]0xFEFF)
  if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey("DateKind")) { return , ($text | ConvertFrom-Json -DateKind String) }
  return , ($text | ConvertFrom-Json)
}
# git show の出力を UTF-8 のまま受け取る(コンソールの文字コードに左右されないように)
function Get-GitShowText([string]$spec) {
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = "git"; $psi.Arguments = "-C `"$scriptDir`" show `"$spec`""
  $psi.UseShellExecute = $false; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
  $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
  $p = [Diagnostics.Process]::Start($psi)
  $out = $p.StandardOutput.ReadToEnd(); $err = $p.StandardError.ReadToEnd(); $p.WaitForExit()
  if ($p.ExitCode -ne 0) { throw "git show $spec に失敗しました(git fetch origin を実行しましたか?): $err" }
  return $out
}

if ($CandidatesPath) {
  $sourceLabel = $CandidatesPath
  $data = ConvertFrom-ReviewJson ([IO.File]::ReadAllText($CandidatesPath, [Text.Encoding]::UTF8))
} else {
  $sourceLabel = "${StateRef}:discovered-standalone-rss.json"
  $data = ConvertFrom-ReviewJson (Get-GitShowText $sourceLabel)
}
$all = @($data.candidates)

# ---- 登録データから、作品ごとのジャンルと、配信者×作品の登録状況を集める(1項目1行の書式を前提に読む) ----
$genreByGame = @{}      # 作品 → @{ ジャンル → 件数 }
$playlistCount = @{}    # 配信者|作品 → 登録済み再生リスト数
$standaloneIds = @{}    # 配信者|作品 → 単発実況 ID の一覧
foreach ($src in @(@{ path = $PlaylistsPath; kind = "playlist" }, @{ path = $StandalonePath; kind = "standalone" })) {
  if (-not (Test-Path -LiteralPath $src.path)) { continue }
  $id = ""; $streamer = ""; $game = ""
  foreach ($line in [IO.File]::ReadAllLines($src.path, [Text.Encoding]::UTF8)) {
    if ($line -match '^\s*//') { continue }
    if ($line -match '^\s*\{\s*$') { $id = ""; $streamer = ""; $game = ""; continue }
    if ($line -match '^\s*id:\s*"([^"]*)"') { $id = $Matches[1]; continue }
    if ($line -match '^\s*streamer:\s*"([^"]*)"') { $streamer = $Matches[1]; continue }
    if ($line -match '^\s*game:\s*"([^"]*)"') {
      $game = $Matches[1]; $k = "$streamer|$game"
      if ($src.kind -eq "playlist") { $playlistCount[$k] = 1 + [int]$playlistCount[$k] }
      elseif ($id) { if (-not $standaloneIds.ContainsKey($k)) { $standaloneIds[$k] = New-Object System.Collections.Generic.List[string] }; $standaloneIds[$k].Add($id) }
      continue
    }
    if ($line -match '^\s*genre:\s*"([^"]*)"' -and $game) {
      if (-not $genreByGame.ContainsKey($game)) { $genreByGame[$game] = @{} }
      $genreByGame[$game][$Matches[1]] = 1 + [int]$genreByGame[$game][$Matches[1]]
    }
  }
}
function Get-GenreSuggestion([string]$game) {
  if (-not $genreByGame.ContainsKey($game)) { return @{ genre = ""; note = "登録データに同じ作品なし(要記入)" } }
  $sorted = @($genreByGame[$game].GetEnumerator() | Sort-Object @{ Expression = { $_.Value }; Descending = $true }, @{ Expression = { [string]$_.Key } })
  $note = ($sorted | ForEach-Object { "$($_.Key) $($_.Value)" }) -join " / "
  if ($sorted.Count -gt 1 -and $sorted[0].Value -eq $sorted[1].Value) { return @{ genre = ""; note = "候補が同数: $note(要記入)" } }
  return @{ genre = [string]$sorted[0].Key; note = $note }
}

# ---- 確認シートの対象: 確認待ち(pending)だけ。判断済みは載せない ----
$pending = @($all | Where-Object { [string]$_.status -eq "pending" })
$decided = $all.Count - $pending.Count
$byCat = @{}; foreach ($c in $pending) { $k = [string]$c.reviewCategory; if (-not $k) { $k = "(分類なし)" }; $byCat[$k] = 1 + [int]$byCat[$k] }
$confRank = @{ HIGH = 0; MEDIUM = 1; LOW = 2 }
$rows = New-Object System.Collections.Generic.List[object]
function New-ReviewRow([string]$type, $items, [string]$seriesKey) {
  $items = @($items | Sort-Object @{ Expression = { [string]$_.publishedAt } }, @{ Expression = { [string]$_.videoId } })
  $first = $items[0]; $k = [string]$first.streamer + "|" + [string]$first.game
  $g = Get-GenreSuggestion ([string]$first.game)
  $confs = @($items | Group-Object { [string]$_.confidence } | Sort-Object { $confRank[$_.Name] } | ForEach-Object { if ($items.Count -eq 1) { $_.Name } else { "$($_.Name) $($_.Count)" } }) -join " / "
  $reasons = @($items | ForEach-Object { @($_.reasons) } | ForEach-Object { [string]$_ } | Where-Object { $_ } | Select-Object -Unique) -join " / "
  return [pscustomobject][ordered]@{
    rowType = $type
    "decision(approve/hold/reject)" = ""
    game = [string]$first.game
    genre = $g.genre
    genreNote = $g.note
    streamer = [string]$first.streamer
    videoCount = $items.Count
    publishedFrom = [string]$items[0].publishedDate
    publishedTo = [string]$items[-1].publishedDate
    confidence = $confs
    episodeMarker = @($items | Where-Object { $_.episodeMarker -eq $true }).Count
    urls = @($items | ForEach-Object { [string]$_.url }) -join " "
    titles = @($items | ForEach-Object { [string]$_.title }) -join " ｜ "
    reasons = $reasons
    sitePlaylistsSameGame = [int]$playlistCount[$k]
    existingStandaloneIds = $(if ($standaloneIds.ContainsKey($k)) { $standaloneIds[$k] -join " " } else { "" })
    "excludeVideoIds(series のみ)" = ""
    note = ""
    videoIds = @($items | ForEach-Object { [string]$_.videoId }) -join " "
    seriesKey = $seriesKey
  }
}
foreach ($c in @($pending | Where-Object { $_.reviewCategory -eq "single" } | Sort-Object @{ Expression = { $confRank[[string]$_.confidence] } }, @{ Expression = { [string]$_.streamer } }, @{ Expression = { [string]$_.publishedAt } })) {
  $rows.Add((New-ReviewRow "single" @($c) ""))
}
foreach ($grp in @($pending | Where-Object { $_.reviewCategory -eq "series" } | Group-Object { [string]$_.seriesKey } | Sort-Object @{ Expression = { $_.Count }; Descending = $true }, @{ Expression = { $_.Name } })) {
  $rows.Add((New-ReviewRow "series" $grp.Group $grp.Name))
}
foreach ($c in @($pending | Where-Object { $_.reviewCategory -eq "playlist-review" } | Sort-Object @{ Expression = { [string]$_.streamer } }, @{ Expression = { [string]$_.game } }, @{ Expression = { [string]$_.publishedAt } })) {
  $rows.Add((New-ReviewRow "playlist-review" @($c) ""))
}

# ---- CSV(BOM 付き UTF-8・CRLF。すべての値を "" で囲む) ----
if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }
$stamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
$outPath = Join-Path $OutDir "standalone-review-$stamp.csv"
$q = { param($v) '"' + ([string]$v).Replace('"', '""') + '"' }
$lines = New-Object System.Collections.Generic.List[string]
$headers = @("no") + @($rows[0].PSObject.Properties.Name)
$lines.Add(($headers | ForEach-Object { & $q $_ }) -join ",")
$no = 0
foreach ($r in $rows) { $no++; $lines.Add(((@($no) + @($r.PSObject.Properties | ForEach-Object { $_.Value })) | ForEach-Object { & $q $_ }) -join ",") }
[IO.File]::WriteAllText($outPath, (($lines -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($true)))

$cnt = @{}; foreach ($r in $rows) { $cnt[$r.rowType] = 1 + [int]$cnt[$r.rowType] }
$seriesVideos = (@($rows | Where-Object rowType -eq "series") | Measure-Object videoCount -Sum).Sum
Write-Output "確認シート: $outPath"
Write-Output ("読んだ候補: $sourceLabel  全 $($all.Count) 件(確認待ち $($pending.Count) 件・判断済み $decided 件は載せない)")
Write-Output ("行: 合計 $($rows.Count) 行 = 単発 $([int]$cnt['single']) 行 / 続き物 $([int]$cnt['series']) 行(動画 $([int]$seriesVideos) 本) / 再生リスト確認 $([int]$cnt['playlist-review']) 行")
Write-Output ("件数だけ: ゲーム実況以外 $([int]$byCat['non-gameplay']) 件 / 分類なし(既存作品に一致しなくなったなど) $([int]$byCat['(分類なし)']) 件")
