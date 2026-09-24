<#
.SYNOPSIS
  data-playlists.js の PLAYLISTS から、ゲーム別・実況者別の再生リスト件数だけを
  持つ軽量な索引ファイル data-counts.js を生成します。

.DESCRIPTION
  games-row.html(行別ゲーム一覧)・streamers.html(実況者一覧)は、再生リストの
  「件数」バッジを表示するためだけに、これまで数MBある data-playlists.js を
  丸ごと読み込んでいました(PLAYLISTS.filter(...).length で数えるだけなのに)。
  このスクリプトで件数だけの軽量ファイル(数十KB程度)を生成し、該当ページでは
  data-playlists.js の代わりにこちらを読み込むことで、転送量・パース時間を
  大きく削減します。

  data-playlists.js の PLAYLISTS を追加・削除したら、このスクリプトを
  再実行して data-counts.js を再生成してください(update-dates.ps1 実行後や、
  手動でのデータ追加後など)。data-counts.js は自動生成物なので手編集しないこと。

.EXAMPLE
  .\generate-counts.ps1
#>
$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$playlistsPath = Join-Path $scriptDir "data-playlists.js"
$outPath = Join-Path $scriptDir "data-counts.js"

$full = [System.IO.File]::ReadAllText($playlistsPath, [System.Text.Encoding]::UTF8)

function Get-ArrayInner([string]$name, [string]$text) {
  $marker = "const $name = ["
  $start = $text.IndexOf($marker)
  if ($start -lt 0) { throw "$name 配列が見つかりません。" }
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

function JsStringEscape([string]$s) {
  return $s -replace '\\', '\\\\' -replace '"', '\"'
}

$gameCounts = [ordered]@{}
$streamerCounts = [ordered]@{}
foreach ($obj in Get-Objects (Get-ArrayInner "PLAYLISTS" $full)) {
  $game = Field $obj "game"
  $streamer = Field $obj "streamer"
  if ($game) {
    if (-not $gameCounts.Contains($game)) { $gameCounts[$game] = 0 }
    $gameCounts[$game] = $gameCounts[$game] + 1
  }
  if ($streamer) {
    if (-not $streamerCounts.Contains($streamer)) { $streamerCounts[$streamer] = 0 }
    $streamerCounts[$streamer] = $streamerCounts[$streamer] + 1
  }
}

function Write-CountsObject([System.Text.StringBuilder]$sb, [string]$varName, [System.Collections.Specialized.OrderedDictionary]$counts) {
  [void]$sb.Append("const $varName = {")
  $first = $true
  foreach ($k in ($counts.Keys | Sort-Object)) {
    if (-not $first) { [void]$sb.Append(',') }
    [void]$sb.Append('"' + (JsStringEscape $k) + '":' + $counts[$k])
    $first = $false
  }
  [void]$sb.AppendLine('};')
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('/**')
[void]$sb.AppendLine(' * ゲーム別・実況者別の再生リスト件数だけを持つ軽量な索引(自動生成ファイル)。')
[void]$sb.AppendLine(' * generate-counts.ps1 で data-playlists.js の PLAYLISTS から生成しています。')
[void]$sb.AppendLine(' * 手編集しないでください。PLAYLISTS を追加・削除したら generate-counts.ps1 を')
[void]$sb.AppendLine(' * 再実行して再生成してください。')
[void]$sb.AppendLine(' *')
[void]$sb.AppendLine(' * 件数バッジの表示だけで済むページ(games-row.html / streamers.html)で、')
[void]$sb.AppendLine(' * 数MBある data-playlists.js の代わりにこちらを読み込みます。')
[void]$sb.AppendLine(' */')
Write-CountsObject $sb "PLAYLIST_COUNTS_BY_GAME" $gameCounts
Write-CountsObject $sb "PLAYLIST_COUNTS_BY_STREAMER" $streamerCounts

[System.IO.File]::WriteAllText($outPath, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Write-Output "data-counts.js を生成しました: $outPath (ゲーム $($gameCounts.Count) 件 / 実況者 $($streamerCounts.Count) 件)"
