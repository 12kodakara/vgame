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
    エラー(data-standalone.js の STANDALONE_PLAYS。単発・PLなし実況):
      - 必須項目(id/title/streamer/game/genre/format)の欠落、id の重複
      - format が single / multi / mixed-playlist 以外
      - STREAMERS / GAMES / GENRES に存在しない名前・IDを参照している
      - 動画URLから YouTube の video ID(11文字)を取り出せない、
        mixedPlaylistUrl が YouTube の再生リストURLでない
      - 同じ video ID が複数の単発実況に登録されている
      - videos の本数が format と合わない(single は1本、multi は1本以上、
        mixed-playlist は mixedPlaylistUrl か videos のどちらかが必要)
      - 再生リストとの重複(再生リスト方式を優先するため登録不可):
          ・同じVTuber×同じゲームの再生リストが PLAYLISTS に登録済み
          ・mixedPlaylistUrl の再生リストが PLAYLISTS に登録済み
        ※ PLAYLISTS は再生リスト内の動画IDを保持していないため、
          「同じ video ID が登録済み再生リストに含まれるか」はここでは判定できない。
          それは discover-standalone.ps1 が候補を作る時点で YouTube API を使って除外する。
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
$standalonePath = Join-Path $scriptDir "data-standalone.js"
$standaloneText = if (Test-Path $standalonePath) { [System.IO.File]::ReadAllText($standalonePath, [System.Text.Encoding]::UTF8) } else { $null }

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

# data-standalone.js は登録例をコメント(// ...)で残しているため、そのまま
# Get-Objects に通すとコメント内の例が実データとして数えられてしまう。
# 文字列の外にある // と /* */ だけを取り除く("https://..." の // は残す)。
function Remove-JsComments([string]$text) {
  $sb = New-Object System.Text.StringBuilder
  $quote = [char]0; $escape = $false
  for ($i = 0; $i -lt $text.Length; $i++) {
    $ch = $text[$i]
    if ($quote -ne [char]0) {
      [void]$sb.Append($ch)
      if ($escape) { $escape = $false }
      elseif ($ch -eq '\') { $escape = $true }
      elseif ($ch -eq $quote) { $quote = [char]0 }
      continue
    }
    $next = if ($i + 1 -lt $text.Length) { $text[$i + 1] } else { [char]0 }
    if ($ch -eq '/' -and $next -eq '/') {
      while ($i -lt $text.Length -and $text[$i] -ne "`n") { $i++ }
      if ($i -lt $text.Length) { [void]$sb.Append("`n") }
      continue
    }
    if ($ch -eq '/' -and $next -eq '*') {
      $end = $text.IndexOf('*/', $i + 2)
      $i = if ($end -lt 0) { $text.Length } else { $end + 1 }
      continue
    }
    if ($ch -eq '"' -or $ch -eq "'" -or $ch -eq '`') { $quote = $ch }
    [void]$sb.Append($ch)
  }
  return $sb.ToString()
}

# オブジェクト内の配列プロパティ(例: videos: [ {...}, {...} ])の中身を返す
function Get-PropertyArrayInner([string]$obj, [string]$name) {
  $m = [regex]::Match($obj, [regex]::Escape($name) + '\s*:\s*\[')
  if (-not $m.Success) { return $null }
  $depth = 1; $inString = $false; $escape = $false
  for ($p = $m.Index + $m.Length; $p -lt $obj.Length; $p++) {
    $ch = $obj[$p]
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
      if ($depth -eq 0) { return $obj.Substring($m.Index + $m.Length, $p - $m.Index - $m.Length) }
    }
  }
  return $null
}

# YouTube動画URLから video ID(11文字)を取り出す。形式が不正なら空文字
function Get-YouTubeVideoId([string]$url) {
  $patterns = @(
    '^https://(?:www\.|m\.)?youtube\.com/watch\?(?:[^#]*&)?v=([A-Za-z0-9_-]{11})(?:[&#].*)?$',
    '^https://youtu\.be/([A-Za-z0-9_-]{11})(?:[?#].*)?$',
    '^https://(?:www\.)?youtube\.com/live/([A-Za-z0-9_-]{11})(?:[?#].*)?$'
  )
  foreach ($pattern in $patterns) {
    $m = [regex]::Match($url, $pattern)
    if ($m.Success) { return $m.Groups[1].Value }
  }
  return ""
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

# ---- STANDALONE_PLAYS(単発・PLなし実況)の検証 ----
$standaloneObjs = @()
if ($null -eq $standaloneText) {
  Add-Issue $warnings "data-standalone.jsなし" $warningDetails "data-standalone.js が見つからないため単発実況の検証をスキップしました: $standalonePath"
} else {
  $standaloneObjs = @(Get-Objects (Get-ArrayInner "STANDALONE_PLAYS" (Remove-JsComments $standaloneText)))
}

# 再生リスト優先の判定用: 登録済みの「VTuber×ゲーム」
$playlistStreamerGame = @{}
foreach ($obj in $playlistObjs) {
  $s = Field $obj "streamer"; $g = Field $obj "game"
  if ($s -and $g) { $playlistStreamerGame["$s`t$g"] = $true }
}

$standaloneFormats = @("single", "multi", "mixed-playlist")
$standaloneRequired = @("id", "title", "streamer", "game", "genre", "format")
$seenStandaloneIds = @{}
$seenStandaloneVideoIds = @{}

foreach ($obj in $standaloneObjs) {
  $id = Field $obj "id"
  $streamer = Field $obj "streamer"
  $game = Field $obj "game"
  $genre = Field $obj "genre"
  $format = Field $obj "format"
  $mixedPlaylistUrl = Field $obj "mixedPlaylistUrl"
  $label = "単発:" + $(if ($id) { $id } else { Field $obj "title" })

  foreach ($req in $standaloneRequired) {
    if (-not (Field $obj $req)) {
      Add-Issue $errors "単発:必須項目欠落($req)" $errorDetails "[$label] $req が空です"
    }
  }

  if ($id) {
    if ($seenStandaloneIds.ContainsKey($id)) {
      Add-Issue $errors "単発:ID重複" $errorDetails "[$label] id が重複しています: $id"
    } else {
      $seenStandaloneIds[$id] = $true
    }
  }

  if ($format -and $standaloneFormats -notcontains $format) {
    Add-Issue $errors "単発:format不正" $errorDetails "[$label] format は single / multi / mixed-playlist のいずれかです: $format"
  }
  if ($game -and -not $gameSet.ContainsKey($game)) {
    Add-Issue $errors "単発:未登録ゲーム" $errorDetails "[$label] GAMESに存在しないゲーム名です: $game"
  }
  if ($streamer -and -not $streamerSet.ContainsKey($streamer)) {
    Add-Issue $errors "単発:未登録VTuber" $errorDetails "[$label] STREAMERSに存在しない実況者名です: $streamer"
  }
  if ($genre -and -not $genreSet.ContainsKey($genre)) {
    Add-Issue $errors "単発:未登録ジャンル" $errorDetails "[$label] GENRESに存在しないジャンルIDです: $genre"
  }

  $addedDate = Field $obj "addedDate"
  if ($addedDate -and $addedDate -notmatch '^\d{4}-\d{2}-\d{2}$') {
    Add-Issue $errors "単発:不正な日付形式" $errorDetails "[$label] addedDate の形式が不正です(YYYY-MM-DD形式で指定): $addedDate"
  }
  if (HasKey $obj "videoCount") {
    $videoCount = FieldNumber $obj "videoCount"
    if ($null -eq $videoCount -or $videoCount -lt 0 -or ($videoCount -ne [Math]::Floor($videoCount))) {
      Add-Issue $errors "単発:不正な動画数" $errorDetails "[$label] videoCount が不正です"
    }
  }

  # videos: 各動画URLから video ID を取り出し、形式と重複を確認する
  $videosInner = Get-PropertyArrayInner $obj "videos"
  $videoObjs = if ($null -eq $videosInner) { @() } else { @(Get-Objects $videosInner) }
  foreach ($v in $videoObjs) {
    $url = Field $v "url"
    $videoId = Get-YouTubeVideoId $url
    if (-not $videoId) {
      Add-Issue $errors "単発:動画URL不正" $errorDetails "[$label] YouTube動画URLから video ID を取り出せません: $url"
    } elseif ($seenStandaloneVideoIds.ContainsKey($videoId)) {
      Add-Issue $errors "単発:video ID重複" $errorDetails "[$label] video ID $videoId は [$($seenStandaloneVideoIds[$videoId])] にも登録されています"
    } else {
      $seenStandaloneVideoIds[$videoId] = $label
    }
    $publishedDate = Field $v "publishedDate"
    if ($publishedDate -and $publishedDate -notmatch '^\d{4}-\d{2}-\d{2}$') {
      Add-Issue $errors "単発:不正な日付形式" $errorDetails "[$label] publishedDate の形式が不正です(YYYY-MM-DD形式で指定): $publishedDate"
    }
  }

  if ($format -eq "single" -and $videoObjs.Count -ne 1) {
    Add-Issue $errors "単発:formatと動画数の不一致" $errorDetails "[$label] format single は videos がちょうど1本必要です(現在 $($videoObjs.Count) 本)"
  } elseif ($format -eq "multi" -and $videoObjs.Count -lt 1) {
    Add-Issue $errors "単発:formatと動画数の不一致" $errorDetails "[$label] format multi は videos が1本以上必要です"
  } elseif ($format -eq "mixed-playlist" -and -not $mixedPlaylistUrl -and $videoObjs.Count -lt 1) {
    Add-Issue $errors "単発:formatと動画数の不一致" $errorDetails "[$label] format mixed-playlist は mixedPlaylistUrl か videos のどちらかが必要です"
  }

  if ($mixedPlaylistUrl) {
    $pm = [regex]::Match($mixedPlaylistUrl, '^https://(?:www\.)?youtube\.com/playlist\?list=([A-Za-z0-9_-]+)$')
    if (-not $pm.Success) {
      Add-Issue $errors "単発:再生リストURL不正" $errorDetails "[$label] mixedPlaylistUrl がYouTube再生リストURLではありません: $mixedPlaylistUrl"
    } elseif ($seenPlaylistIds.ContainsKey($pm.Groups[1].Value)) {
      Add-Issue $errors "単発:再生リスト重複" $errorDetails "[$label] mixedPlaylistUrl の再生リストは PLAYLISTS に登録済みです: $($pm.Groups[1].Value)"
    }
  }

  # 再生リスト方式を優先: 同じVTuber×ゲームの再生リストがあれば単発実況として登録しない
  if ($streamer -and $game -and $playlistStreamerGame.ContainsKey("$streamer`t$game")) {
    Add-Issue $errors "単発:再生リスト重複" $errorDetails "[$label] $streamer × $game の再生リストが PLAYLISTS に登録済みです(再生リストを優先)"
  }
}

# ---- 出力 ----
Write-Output "=== データチェック結果 ==="
Write-Output ""
Write-Output "再生リスト: $($playlistObjs.Count)"
Write-Output "ゲーム: $($gameObjs.Count)"
Write-Output "VTuber: $($streamerObjs.Count)"
Write-Output "単発実況: $($standaloneObjs.Count)"
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
    standaloneCount = $standaloneObjs.Count
    warnings      = $warnings
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
