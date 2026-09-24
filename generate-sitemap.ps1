<#
.SYNOPSIS
  data-core.js の GAMES / STREAMERS と静的ページから sitemap.xml を生成します。

.DESCRIPTION
  ゲーム別ページ(game.html?game=...)・実況者別ページ(streamer.html?streamer=...)は
  クエリパラメータ形式のURLで、件数も数千件規模になるため手書きでは管理できません。
  このスクリプトを data-core.js 編集後(ゲーム・実況者の追加/削除後)に実行し、
  sitemap.xml を再生成してください。

.PARAMETER SiteUrl
  サイトの公開URL(末尾スラッシュ無し。例: "https://example.com")。
  省略時は data-core.js の SITE_URL をそのまま使うため、本番ドメインは
  data-core.js の SITE_URL を1箇所変更するだけでこのスクリプトにも反映されます。
  -SiteUrl を指定した場合はそちらが優先されます(一時的な別ドメイン生成用)。

.EXAMPLE
  .\generate-sitemap.ps1
  .\generate-sitemap.ps1 -SiteUrl "https://vgame.example.com"
#>
param(
  [string]$SiteUrl = ""
)

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$corePath = Join-Path $scriptDir "data-core.js"
$outPath = Join-Path $scriptDir "sitemap.xml"

$full = [System.IO.File]::ReadAllText($corePath, [System.Text.Encoding]::UTF8)

if ([string]::IsNullOrWhiteSpace($SiteUrl)) {
  # -SiteUrl 未指定時は data-core.js の SITE_URL を単一の設定値として使う。
  $siteUrlMatch = [System.Text.RegularExpressions.Regex]::Match($full, 'const SITE_URL\s*=\s*"([^"]*)"')
  if ($siteUrlMatch.Success -and $siteUrlMatch.Groups[1].Value) {
    $SiteUrl = $siteUrlMatch.Groups[1].Value
  } else {
    $SiteUrl = "https://example.com"
  }
}
$siteUrl = $SiteUrl.TrimEnd("/")

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

function XmlEscape([string]$s) {
  return [System.Security.SecurityElement]::Escape($s)
}

$allGames = foreach ($obj in Get-Objects (Get-ArrayInner "GAMES" $full)) {
  $name = Field $obj "name"; if ($name) { $name }
}
$allStreamers = foreach ($obj in Get-Objects (Get-ArrayInner "STREAMERS" $full)) {
  $name = Field $obj "name"; if ($name) { $name }
}

# ---- 再生リスト・単発実況が1件も無いゲーム/VTuberをsitemapから除外する ----
# game.js/streamer.js側で、再生リスト0件のページには動的にnoindexを付与している
# (data-game-editorial.js等は変更していない)。sitemapに載っていてもnoindexページは
# インデックスされないが、無駄なクロール対象を減らすため、こちらも同じ条件
# (再生リスト・単発実況が1件以上あるか)で自動的に絞り込む。手作業でのURLリスト
# 管理はせず、data-playlists.js / data-standalone.js の実データから毎回判定する。
function Get-NameSet([string]$fieldName, [string]$text) {
  $set = New-Object 'System.Collections.Generic.HashSet[string]'
  $pattern = [regex]::Escape($fieldName) + ':\s*"((?:\\.|[^"])*)"'
  foreach ($m in [regex]::Matches($text, $pattern)) {
    $v = $m.Groups[1].Value -replace '\\"', '"' -replace '\\\\', '\'
    if ($v) { [void]$set.Add($v) }
  }
  return $set
}

$playlistsPath = Join-Path $scriptDir "data-playlists.js"
$standalonePath = Join-Path $scriptDir "data-standalone.js"
$gamesWithData = New-Object 'System.Collections.Generic.HashSet[string]'
$streamersWithData = New-Object 'System.Collections.Generic.HashSet[string]'

if (Test-Path $playlistsPath) {
  $playlistsText = [System.IO.File]::ReadAllText($playlistsPath, [System.Text.Encoding]::UTF8)
  foreach ($v in (Get-NameSet "game" $playlistsText)) { [void]$gamesWithData.Add($v) }
  foreach ($v in (Get-NameSet "streamer" $playlistsText)) { [void]$streamersWithData.Add($v) }
}
if (Test-Path $standalonePath) {
  $standaloneText = [System.IO.File]::ReadAllText($standalonePath, [System.Text.Encoding]::UTF8)
  foreach ($v in (Get-NameSet "game" $standaloneText)) { [void]$gamesWithData.Add($v) }
  foreach ($v in (Get-NameSet "streamer" $standaloneText)) { [void]$streamersWithData.Add($v) }
}

$games = @($allGames | Where-Object { $gamesWithData.Contains($_) })
$streamers = @($allStreamers | Where-Object { $streamersWithData.Contains($_) })
$excludedGames = @($allGames | Where-Object { -not $gamesWithData.Contains($_) })
$excludedStreamers = @($allStreamers | Where-Object { -not $streamersWithData.Contains($_) })

Write-Output ("再生リスト0件のため sitemap から除外したゲーム: " + $excludedGames.Count + "件")
if ($excludedGames.Count -gt 0) { $excludedGames | ForEach-Object { Write-Output "  - $_" } }
Write-Output ("再生リスト0件のため sitemap から除外したVTuber: " + $excludedStreamers.Count + "件")
if ($excludedStreamers.Count -gt 0) { $excludedStreamers | ForEach-Object { Write-Output "  - $_" } }

$staticPages = @(
  "games.html", "streamers.html", "playlists.html",
  "singles.html", "ranking.html", "new.html",
  "about.html", "operator.html", "privacy.html", "contact.html"
)

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
[void]$sb.AppendLine('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">')

# トップページは index.html ではなく正規URL(ルート)で登録する。canonical も
# 各HTMLで https://.../ (ルート)を指しているため揃えている。
[void]$sb.AppendLine("  <url><loc>$siteUrl/</loc></url>")
foreach ($p in $staticPages) {
  [void]$sb.AppendLine("  <url><loc>$siteUrl/$p</loc></url>")
}

# common.js の KANA_ROW_GROUPS と同じ10行。行が増減したらここも合わせて変更すること。
$kanaRows = @("あ", "か", "さ", "た", "な", "は", "ま", "や", "ら", "わ")
foreach ($row in $kanaRows) {
  $url = "$siteUrl/games-row.html?row=" + [uri]::EscapeDataString($row)
  [void]$sb.AppendLine("  <url><loc>$(XmlEscape $url)</loc></url>")
}
foreach ($g in $games) {
  $url = "$siteUrl/game.html?game=" + [uri]::EscapeDataString($g)
  [void]$sb.AppendLine("  <url><loc>$(XmlEscape $url)</loc></url>")
}
foreach ($s in $streamers) {
  $url = "$siteUrl/streamer.html?streamer=" + [uri]::EscapeDataString($s)
  [void]$sb.AppendLine("  <url><loc>$(XmlEscape $url)</loc></url>")
}
[void]$sb.AppendLine('</urlset>')

[System.IO.File]::WriteAllText($outPath, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Write-Output "sitemap.xml を生成しました: $outPath ($(1 + $staticPages.Count + $kanaRows.Count + $games.Count + $streamers.Count) URL)"

# robots.txt の Sitemap: 行も同じ $siteUrl に合わせて更新する
# (robots.txt はブラウザJSが実行されない静的ファイルのため、data-core.js の
# SITE_URL を変えただけでは自動反映されない。このスクリプト実行時に揃える)。
$robotsPath = Join-Path $scriptDir "robots.txt"
if (Test-Path $robotsPath) {
  $robots = [System.IO.File]::ReadAllText($robotsPath, [System.Text.Encoding]::UTF8)
  $robots = [System.Text.RegularExpressions.Regex]::Replace($robots, 'Sitemap:\s*\S+', "Sitemap: $siteUrl/sitemap.xml")
  [System.IO.File]::WriteAllText($robotsPath, $robots, (New-Object System.Text.UTF8Encoding($false)))
  Write-Output "robots.txt の Sitemap URL も更新しました: $siteUrl/sitemap.xml"
}

if ($siteUrl -eq "https://example.com") {
  Write-Warning "SiteUrl がプレースホルダー(https://example.com)のままです。公開ドメインが決まったら data-core.js の SITE_URL を変更するか、-SiteUrl を指定して再実行してください。"
}
