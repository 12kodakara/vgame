<#
.SYNOPSIS
  YouTubeチャンネルのアップロード動画から、専用再生リストが無い可能性のある
  ゲーム実況を抽出し、admin-standalone.html で確認できるJSONを生成します。

.DESCRIPTION
  1) data-core.js の STREAMERS / GAMES、data-playlists.js の PLAYLISTS を読み取る
  2) YouTube Data API v3 で対象チャンネルの最近のアップロードを取得
  3) サイト登録済み再生リスト内の動画IDを照合して除外
  4) GAMES の name / nameJa / aliases を動画タイトル・説明欄と照合
  5) チャンネル側にゲーム名を含む専用PLがありそうかも確認
  6) 候補を streamer × game 単位にまとめて standalone-candidates.json に出力

  ※ data-core.js / data-playlists.js は自動更新しません。候補は必ず管理画面で人が確認してください。

.PARAMETER ApiKey
  YouTube Data API v3 APIキー。省略時は環境変数 YOUTUBE_API_KEY。
.PARAMETER Streamer
  実況者名を1人だけ指定。
.PARAMETER Group
  STREAMERS.group の完全一致で絞り込み。
.PARAMETER MaxVideos
  1チャンネルから調べる最大アップロード数。既定200。
.PARAMETER PublishedAfter
  この日以降の動画だけを候補にする (YYYY-MM-DD)。省略可。
.PARAMETER OutFile
  出力JSON。既定 standalone-candidates.json。

.EXAMPLE
  .\discover-standalone.ps1 -ApiKey "AIza..." -Streamer "兎田ぺこら" -MaxVideos 300
#>
param(
  [string]$ApiKey = $env:YOUTUBE_API_KEY,
  [string]$Streamer,
  [string]$Group,
  [int]$MaxVideos = 200,
  [string]$PublishedAfter,
  [string]$OutFile = "standalone-candidates.json"
)

$ErrorActionPreference = "Stop"
if (-not $ApiKey) { throw "APIキーがありません。-ApiKey または環境変数 YOUTUBE_API_KEY を指定してください。" }

$scriptDir = $PSScriptRoot
$corePath = Join-Path $scriptDir "data-core.js"
$playlistsPath = Join-Path $scriptDir "data-playlists.js"
$outPath = Join-Path $scriptDir $OutFile
# STREAMERS/GAMES は data-core.js、PLAYLISTS は data-playlists.js にあるため両方読み込んで結合する
$full = ([IO.File]::ReadAllText($corePath, [Text.Encoding]::UTF8)) + "`n" + ([IO.File]::ReadAllText($playlistsPath, [Text.Encoding]::UTF8))

function Get-ArrayInner([string]$name) {
  $marker = "const $name = ["
  $start = $full.IndexOf($marker)
  if ($start -lt 0) { throw "$name 配列が見つかりません。" }
  $i = $start + $marker.Length
  $depth = 1; $inString = $false; $escape = $false
  for ($p=$i; $p -lt $full.Length; $p++) {
    $ch = $full[$p]
    if ($inString) {
      if ($escape) { $escape = $false; continue }
      if ($ch -eq '\\') { $escape = $true; continue }
      if ($ch -eq '"') { $inString = $false }
      continue
    }
    if ($ch -eq '"') { $inString = $true; continue }
    if ($ch -eq '[') { $depth++ }
    elseif ($ch -eq ']') {
      $depth--
      if ($depth -eq 0) { return $full.Substring($i, $p-$i) }
    }
  }
  throw "$name 配列の終端が見つかりません。"
}

function Get-Objects([string]$inner) {
  $results = @(); $depth=0; $start=-1; $inString=$false; $escape=$false
  for ($i=0; $i -lt $inner.Length; $i++) {
    $ch=$inner[$i]
    if ($inString) {
      if ($escape) { $escape=$false; continue }
      if ($ch -eq '\\') { $escape=$true; continue }
      if ($ch -eq '"') { $inString=$false }
      continue
    }
    if ($ch -eq '"') { $inString=$true; continue }
    if ($ch -eq '{') { if ($depth -eq 0) { $start=$i }; $depth++ }
    elseif ($ch -eq '}') { $depth--; if ($depth -eq 0 -and $start -ge 0) { $results += $inner.Substring($start, $i-$start+1); $start=-1 } }
  }
  return $results
}

function Field([string]$obj,[string]$name) {
  $m=[regex]::Match($obj, [regex]::Escape($name) + '\s*:\s*"((?:\\.|[^"])*)"')
  if ($m.Success) { return ($m.Groups[1].Value -replace '\\"','"' -replace '\\\\','\\') }
  return ""
}
function ArrayField([string]$obj,[string]$name) {
  $m=[regex]::Match($obj, [regex]::Escape($name) + '\s*:\s*\[([^\]]*)\]')
  if (-not $m.Success) { return @() }
  return @([regex]::Matches($m.Groups[1].Value,'"((?:\\.|[^"])*)"') | ForEach-Object { $_.Groups[1].Value })
}
function Norm([string]$s) {
  if ($null -eq $s) { return "" }
  $x=$s.Normalize([Text.NormalizationForm]::FormKC).ToLowerInvariant()
  $x=[regex]::Replace($x,'\s+',' ')
  return $x.Trim()
}
function ApiGet([string]$url) { Invoke-RestMethod -Uri $url -Method Get }

$streamers = foreach ($obj in Get-Objects (Get-ArrayInner "STREAMERS")) {
  $name=Field $obj "name"; if (-not $name) { continue }
  [pscustomobject]@{ name=$name; group=(Field $obj "group"); youtube=(Field $obj "youtube") }
}
if ($Streamer) { $streamers=@($streamers | Where-Object name -eq $Streamer) }
if ($Group) { $streamers=@($streamers | Where-Object group -eq $Group) }
$streamers=@($streamers | Where-Object { $_.youtube })
if ($streamers.Count -eq 0) { throw "対象実況者が見つかりません。" }

$games = foreach ($obj in Get-Objects (Get-ArrayInner "GAMES")) {
  $name=Field $obj "name"; if (-not $name) { continue }
  $aliases=@($name, (Field $obj "nameJa"), (ArrayField $obj "aliases")) | ForEach-Object { $_ } | Where-Object { $_ }
  [pscustomobject]@{ name=$name; kana=(Field $obj "kana"); series=(Field $obj "series"); aliases=@($aliases | Select-Object -Unique) }
}

$registered = foreach ($obj in Get-Objects (Get-ArrayInner "PLAYLISTS")) {
  $pid=Field $obj "playlistId"; if (-not $pid) { continue }
  [pscustomobject]@{ streamer=(Field $obj "streamer"); game=(Field $obj "game"); playlistId=$pid; genre=(Field $obj "genre") }
}

$nonGameWords = @('雑談','歌枠','歌ってみた','cover','music','original song','shorts','切り抜き','誕生日','周年','記念配信','お知らせ','告知','朝活','晩酌','asmr')
$allGroups=@()
$si=0
foreach ($s in $streamers) {
  $si++
  Write-Output "[$si/$($streamers.Count)] $($s.name) を確認中..."
  $channelId=$null
  if ($s.youtube -match '/channel/(UC[A-Za-z0-9_-]+)') { $channelId=$Matches[1] }
  elseif ($s.youtube -match '/@([^/?]+)') {
    $handle='@'+$Matches[1]
    $u="https://www.googleapis.com/youtube/v3/channels?part=id&forHandle=$([uri]::EscapeDataString($handle))&key=$ApiKey"
    $r=ApiGet $u; if ($r.items.Count -gt 0) { $channelId=$r.items[0].id }
  }
  if (-not $channelId) { Write-Warning "チャンネルIDを取得できません: $($s.name)"; continue }

  $ch=ApiGet "https://www.googleapis.com/youtube/v3/channels?part=contentDetails&id=$channelId&key=$ApiKey"
  if (-not $ch.items) { continue }
  $uploadsId=$ch.items[0].contentDetails.relatedPlaylists.uploads

  # チャンネル側の公開再生リスト名を取得（専用PLらしきものが存在するかの補助判定）
  $channelPlaylists=@(); $token=$null
  do {
    $u="https://www.googleapis.com/youtube/v3/playlists?part=snippet,contentDetails&channelId=$channelId&maxResults=50&key=$ApiKey"
    if ($token) { $u += "&pageToken=$([uri]::EscapeDataString($token))" }
    $r=ApiGet $u
    foreach ($p in $r.items) { $channelPlaylists += [pscustomobject]@{ id=$p.id; title=$p.snippet.title; count=$p.contentDetails.itemCount } }
    $token=$r.nextPageToken
  } while ($token)

  # サイト登録済みの当該実況者の専用PLに含まれる動画IDを収集
  $knownVideoIds=[Collections.Generic.HashSet[string]]::new()
  $myRegistered=@($registered | Where-Object streamer -eq $s.name)
  foreach ($rp in $myRegistered) {
    $token=$null
    do {
      try {
        $u="https://www.googleapis.com/youtube/v3/playlistItems?part=contentDetails&playlistId=$([uri]::EscapeDataString($rp.playlistId))&maxResults=50&key=$ApiKey"
        if ($token) { $u += "&pageToken=$([uri]::EscapeDataString($token))" }
        $r=ApiGet $u
        foreach ($v in $r.items) { if ($v.contentDetails.videoId) { [void]$knownVideoIds.Add([string]$v.contentDetails.videoId) } }
        $token=$r.nextPageToken
      } catch { Write-Warning "登録PLの動画照合をスキップ: $($rp.playlistId)"; $token=$null }
    } while ($token)
  }

  # アップロード取得
  $uploads=@(); $token=$null
  do {
    $u="https://www.googleapis.com/youtube/v3/playlistItems?part=snippet,contentDetails&playlistId=$uploadsId&maxResults=50&key=$ApiKey"
    if ($token) { $u += "&pageToken=$([uri]::EscapeDataString($token))" }
    $r=ApiGet $u
    foreach ($v in $r.items) {
      $date=[datetime]$v.contentDetails.videoPublishedAt
      if ($PublishedAfter -and $date.Date -lt ([datetime]$PublishedAfter).Date) { continue }
      $uploads += [pscustomobject]@{ videoId=[string]$v.contentDetails.videoId; title=[string]$v.snippet.title; description=[string]$v.snippet.description; publishedAt=$date.ToString('yyyy-MM-dd'); thumbnail=$v.snippet.thumbnails.medium.url }
      if ($uploads.Count -ge $MaxVideos) { break }
    }
    $token=$r.nextPageToken
  } while ($token -and $uploads.Count -lt $MaxVideos)

  $candidates=@()
  foreach ($v in $uploads) {
    if ($knownVideoIds.Contains($v.videoId)) { continue }
    $text=Norm ($v.title + ' ' + $v.description)
    $titleNorm=Norm $v.title
    $likelyNonGame=$false
    foreach ($w in $nonGameWords) { if ($titleNorm.Contains((Norm $w))) { $likelyNonGame=$true; break } }

    $best=$null; $bestLen=0; $matchedAlias=''
    foreach ($g in $games) {
      foreach ($a in $g.aliases) {
        $na=Norm $a
        if ($na.Length -lt 3) { continue }
        if ($text.Contains($na) -and $na.Length -gt $bestLen) { $best=$g; $bestLen=$na.Length; $matchedAlias=$a }
      }
    }
    if (-not $best) { continue } # 今回は既知ゲームに絞る。未登録ゲームは管理画面で別途追加可能。

    $dedicated=@()
    foreach ($cp in $channelPlaylists) {
      $pt=Norm $cp.title
      foreach ($a in $best.aliases) {
        $na=Norm $a
        if ($na.Length -ge 3 -and $pt.Contains($na)) { $dedicated += $cp; break }
      }
    }
    $siteHasGamePlaylist = @($myRegistered | Where-Object game -eq $best.name).Count -gt 0
    $candidates += [pscustomobject]@{
      streamer=$s.name; game=$best.name; videoId=$v.videoId; title=$v.title; url=("https://www.youtube.com/watch?v="+$v.videoId)
      publishedDate=$v.publishedAt; thumbnail=$v.thumbnail; matchedAlias=$matchedAlias
      likelyNonGame=$likelyNonGame; siteHasGamePlaylist=$siteHasGamePlaylist
      dedicatedPlaylistLikely=($dedicated.Count -gt 0); dedicatedPlaylists=@($dedicated | Select-Object id,title,count)
    }
  }

  foreach ($grp in ($candidates | Group-Object game)) {
    $items=@($grp.Group | Sort-Object publishedDate)
    $first=$items[0]
    $genre=($myRegistered | Where-Object game -eq $grp.Name | Select-Object -First 1).genre
    if (-not $genre) { $genre='other' }
    $allGroups += [pscustomobject]@{
      candidateId=("cand-"+[guid]::NewGuid().ToString('N').Substring(0,10))
      streamer=$s.name; game=$grp.Name; genre=$genre
      suggestedFormat=$(if ($items.Count -eq 1) {'single'} else {'multi'})
      videoCount=$items.Count
      warning=$(if (@($items | Where-Object dedicatedPlaylistLikely).Count -gt 0) {'チャンネル側に専用再生リスト候補あり'} elseif (@($items | Where-Object siteHasGamePlaylist).Count -gt 0) {'サイト登録済み専用PLと同ゲーム（動画ID未収録）'} else {''})
      videos=$items
    }
  }
}

$result=[pscustomobject]@{
  generatedAt=(Get-Date).ToString('s')
  maxVideosPerChannel=$MaxVideos
  publishedAfter=$PublishedAfter
  note='自動判定結果です。公開前に必ず動画内容と再生リスト状況を人が確認してください。'
  candidates=@($allGroups | Sort-Object streamer,game)
}
$result | ConvertTo-Json -Depth 9 | Set-Content -Path $outPath -Encoding UTF8
Write-Output "完了: $outPath  候補グループ数=$($allGroups.Count)"
Write-Output "次に admin-standalone.html を開き、このJSONを読み込んで確認してください。"
