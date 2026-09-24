<#
.SYNOPSIS
  data-core.js(GENRES/STREAMERS/GAMES)と data-playlists.js(PLAYLISTS)の
  整合性を検証し、警告とエラーに分けて件数を報告します。

.DESCRIPTION
  読み取り専用のチェックです。ファイルは一切書き換えません。
  チェック内容:
    エラー(データとして不正・矛盾しているもの):
      - playlistId の重複
      - 内部ID(id)の重複
      - GAMES に存在しないゲーム名を参照している
      - STREAMERS に存在しない実況者名を参照している
      - GENRES に存在しないジャンルIDを参照している
      - playlistId / thumbnailUrl の形式が不正(URLとして成立しない等)
      - 必須項目(id/title/streamer/game/genre/playlistId)の欠落
      - videoCount が負数・非整数など不正な値
      - addedDate / updatedDate の形式が不正(YYYY-MM-DD形式以外)
    警告(無くても表示は壊れないが、後で埋めた方が良いもの):
      - thumbnailUrl 未設定
      - updatedDate 未設定
      - GAMES の aliases(別名)が複数ゲームで重複、または他のゲームの正式名と衝突

  update-site.ps1 の最終ステップとしても呼び出されます(データ更新後の
  健全性チェック用)。エラーが1件でもあれば終了コード1、無ければ0を返します
  (警告のみの場合も終了コードは0)。

.PARAMETER Json
  集計結果および個別の詳細一覧をJSON形式でも出力する場合、出力先ファイルパスを
  指定します(省略時はJSON出力なし、コンソール表示のみ)。

.EXAMPLE
  .\validate-data.ps1

.EXAMPLE
  .\validate-data.ps1 -Json validate-report.json
#>
param(
  [string]$Json
)

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$corePath = Join-Path $scriptDir "data-core.js"
$playlistsPath = Join-Path $scriptDir "data-playlists.js"

if (-not (Test-Path $corePath)) {
  Write-Error "data-core.js が見つかりません: $corePath"
  exit 1
}
if (-not (Test-Path $playlistsPath)) {
  Write-Error "data-playlists.js が見つかりません: $playlistsPath"
  exit 1
}

$coreText = [System.IO.File]::ReadAllText($corePath, [System.Text.Encoding]::UTF8)
$playlistsText = [System.IO.File]::ReadAllText($playlistsPath, [System.Text.Encoding]::UTF8)

# ---- JS配列パーサ(generate-sitemap.ps1 と同じ手法。文字列中の [{}] は無視し、
#      ネストした {} も深さで正しく数える) ----
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

function FieldNumber([string]$obj, [string]$name) {
  $m = [regex]::Match($obj, [regex]::Escape($name) + '\s*:\s*(-?\d+(?:\.\d+)?)')
  if ($m.Success) { return [double]$m.Groups[1].Value }
  return $null
}

function HasKey([string]$obj, [string]$name) {
  return [regex]::IsMatch($obj, [regex]::Escape($name) + '\s*:')
}

function FieldArray([string]$obj, [string]$name) {
  $m = [regex]::Match($obj, [regex]::Escape($name) + '\s*:\s*\[([^\]]*)\]')
  if (-not $m.Success) { return @() }
  return [regex]::Matches($m.Groups[1].Value, '"((?:\\.|[^"])*)"') | ForEach-Object { $_.Groups[1].Value }
}

# ---- データ読み込み ----
$genreObjs = Get-Objects (Get-ArrayInner "GENRES" $coreText)
$streamerObjs = Get-Objects (Get-ArrayInner "STREAMERS" $coreText)
$gameObjs = Get-Objects (Get-ArrayInner "GAMES" $coreText)
$playlistObjs = Get-Objects (Get-ArrayInner "PLAYLISTS" $playlistsText)

$genreSet = @{}
foreach ($o in $genreObjs) { $v = Field $o "id"; if ($v) { $genreSet[$v] = $true } }
$streamerSet = @{}
foreach ($o in $streamerObjs) { $v = Field $o "name"; if ($v) { $streamerSet[$v] = $true } }
$gameSet = @{}
foreach ($o in $gameObjs) { $v = Field $o "name"; if ($v) { $gameSet[$v] = $true } }

# ---- 検証 ----
$warnings = @{}
$errors = @{}
$errorDetails = New-Object System.Collections.Generic.List[string]
$warningDetails = New-Object System.Collections.Generic.List[string]

function Add-Issue {
  param([hashtable]$Bucket, [string]$Key, [System.Collections.Generic.List[string]]$DetailList, [string]$Detail)
  if (-not $Bucket.ContainsKey($Key)) { $Bucket[$Key] = 0 }
  $Bucket[$Key]++
  if ($null -ne $DetailList -and $Detail) { [void]$DetailList.Add($Detail) }
}

# ---- GAMES の aliases 重複チェック(同じ別名が複数ゲームに登録されている、
#      または別名が他のゲームの正式名と衝突していると、検索・自動判定が
#      あいまいになるため) ----
$aliasOwner = @{}
foreach ($o in $gameObjs) {
  $gname = Field $o "name"
  if (-not $gname) { continue }
  foreach ($alias in (FieldArray $o "aliases")) {
    if (-not $alias) { continue }
    if ($aliasOwner.ContainsKey($alias)) {
      if ($aliasOwner[$alias] -ne $gname) {
        # シリーズ内で愛称(例: "龍如")を複数タイトルが共有するのは意図的な設計のため、
        # データ不整合の「エラー」ではなく確認用の「警告」として扱う。
        Add-Issue $warnings "aliases重複" $warningDetails "別名 `"$alias`" が複数のゲームに登録されています: $($aliasOwner[$alias]) / $gname"
      }
    } else {
      $aliasOwner[$alias] = $gname
    }
    if ($gameSet.ContainsKey($alias) -and $alias -ne $gname) {
      Add-Issue $warnings "aliases重複" $warningDetails "別名 `"$alias`"($gname)が他のゲームの正式名と衝突しています: $alias"
    }
  }
}

$seenIds = @{}
$seenPlaylistIds = @{}
$requiredFields = @("id", "title", "streamer", "game", "genre", "playlistId")

foreach ($obj in $playlistObjs) {
  $id = Field $obj "id"
  $playlistId = Field $obj "playlistId"
  $title = Field $obj "title"
  $streamer = Field $obj "streamer"
  $game = Field $obj "game"
  $genre = Field $obj "genre"
  $thumbnailUrl = Field $obj "thumbnailUrl"
  $updatedDate = Field $obj "updatedDate"
  $videoCount = FieldNumber $obj "videoCount"
  $label = if ($id) { $id } elseif ($title) { $title } else { "(id/titleとも空のエントリ)" }

  foreach ($req in $requiredFields) {
    if (-not (Field $obj $req)) {
      Add-Issue $errors "必須項目欠落($req)" $errorDetails "[$label] $req が空です"
    }
  }

  if ($id) {
    if ($seenIds.ContainsKey($id)) {
      Add-Issue $errors "内部ID重複" $errorDetails "id が重複しています: $id"
    } else {
      $seenIds[$id] = $true
    }
  }

  if ($playlistId) {
    if ($seenPlaylistIds.ContainsKey($playlistId)) {
      Add-Issue $errors "playlistId重複" $errorDetails "[$label] playlistId が重複しています: $playlistId"
    } else {
      $seenPlaylistIds[$playlistId] = $true
    }
    if ($playlistId -notmatch '^[A-Za-z0-9_-]+$') {
      Add-Issue $errors "playlistId形式異常" $errorDetails "[$label] playlistId の形式が不正です: $playlistId"
    }
  }

  if ($game -and -not $gameSet.ContainsKey($game)) {
    Add-Issue $errors "未登録ゲーム" $errorDetails "[$label] GAMESに存在しないゲーム名です: $game"
  }
  if ($streamer -and -not $streamerSet.ContainsKey($streamer)) {
    Add-Issue $errors "未登録VTuber" $errorDetails "[$label] STREAMERSに存在しない実況者名です: $streamer"
  }
  if ($genre -and -not $genreSet.ContainsKey($genre)) {
    Add-Issue $errors "未登録ジャンル" $errorDetails "[$label] GENRESに存在しないジャンルIDです: $genre"
  }

  if (HasKey $obj "videoCount") {
    if ($null -eq $videoCount -or $videoCount -lt 0 -or ($videoCount -ne [Math]::Floor($videoCount))) {
      Add-Issue $errors "不正な動画数" $errorDetails "[$label] videoCount が不正です"
    }
  }

  if (-not $thumbnailUrl) {
    Add-Issue $warnings "thumbnailなし" $warningDetails "[$label] thumbnailUrl が未設定です"
  } elseif ($thumbnailUrl -notmatch '^https?://') {
    Add-Issue $errors "URL形式異常" $errorDetails "[$label] thumbnailUrl の形式が不正です: $thumbnailUrl"
  }

  if (-not $updatedDate) {
    Add-Issue $warnings "updatedDateなし" $warningDetails "[$label] updatedDate が未設定です"
  } elseif ($updatedDate -notmatch '^\d{4}-\d{2}-\d{2}$') {
    Add-Issue $errors "不正な日付形式" $errorDetails "[$label] updatedDate の形式が不正です(YYYY-MM-DD形式で指定): $updatedDate"
  }

  $addedDate = Field $obj "addedDate"
  if ($addedDate -and $addedDate -notmatch '^\d{4}-\d{2}-\d{2}$') {
    Add-Issue $errors "不正な日付形式" $errorDetails "[$label] addedDate の形式が不正です(YYYY-MM-DD形式で指定): $addedDate"
  }
}

# ---- 出力 ----
Write-Output "=== データチェック結果 ==="
Write-Output ""
Write-Output "再生リスト: $($playlistObjs.Count)"
Write-Output "ゲーム: $($gameObjs.Count)"
Write-Output "VTuber: $($streamerObjs.Count)"
Write-Output ""

Write-Output "警告"
if ($warnings.Count -gt 0) {
  $warnings.GetEnumerator() | Sort-Object Name | ForEach-Object { Write-Output ("  {0}: {1}" -f $_.Key, $_.Value) }
} else {
  Write-Output "  なし"
}
Write-Output ""

Write-Output "エラー"
if ($errors.Count -gt 0) {
  $errors.GetEnumerator() | Sort-Object Name | ForEach-Object { Write-Output ("  {0}: {1}" -f $_.Key, $_.Value) }
} else {
  Write-Output "  なし"
}

if ($Json) {
  $report = [PSCustomObject]@{
    playlistCount  = $playlistObjs.Count
    gameCount      = $gameObjs.Count
    streamerCount  = $streamerObjs.Count
    warnings       = $warnings
    errors         = $errors
    warningDetails = $warningDetails
    errorDetails   = $errorDetails
  }
  ($report | ConvertTo-Json -Depth 5) | Set-Content -Path $Json -Encoding UTF8
  Write-Output ""
  Write-Output "詳細をJSONで出力しました: $Json"
}

if ($errors.Count -gt 0) {
  exit 1
} else {
  exit 0
}
