<#
.SYNOPSIS
  YouTubeチャンネルのアップロード動画から、専用再生リストが無い可能性のある
  ゲーム実況を抽出し、admin-standalone.html で確認できるJSONを生成します。

.DESCRIPTION
  1) data-core.js の STREAMERS / GAMES、data-playlists.js の PLAYLISTS を読み取る
  2) YouTube Data API v3 で対象チャンネルの最近のアップロードを取得
  3) サイト登録済み再生リスト内の動画IDを照合して除外
  4) STANDALONE_PLAYS(data-standalone.js)に登録済みの動画IDも除外
  5) GAMES の name / nameJa / aliases を動画タイトル・説明欄と照合し、信頼度 HIGH / MEDIUM / LOW を付ける
     (判定ロジックと HIGH の条件は standalone-matching.ps1 の説明を参照)
  6) チャンネル側にゲーム名を含む専用PLがありそうかも確認(あれば HIGH にしない)
  7) 候補を streamer × game 単位にまとめて standalone-candidates.json に出力

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
# 候補判定ロジック(信頼度 HIGH / MEDIUM / LOW)
. (Join-Path $scriptDir "standalone-matching.ps1")
# STANDALONE_PLAYS に登録済みの動画は候補から外す(同じ単発実況を再提案しない)
$standalonePath = Join-Path $scriptDir "data-standalone.js"
$standaloneVideoIds = Get-StandaloneRegisteredVideoIds $(if (Test-Path $standalonePath) { [IO.File]::ReadAllText($standalonePath, [Text.Encoding]::UTF8) } else { "" })

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
$allStreamerNames = @($streamers | ForEach-Object { $_.name })   # 絞り込む前の全VTuber名(VTuber名の中のゲーム名一致を無視するため)
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
  # $pid は PowerShell の読み取り専用自動変数($PID)と衝突して停止するため別名にする
  $playlistIdValue=Field $obj "playlistId"; if (-not $playlistIdValue) { continue }
  [pscustomobject]@{ streamer=(Field $obj "streamer"); game=(Field $obj "game"); playlistId=$playlistIdValue; genre=(Field $obj "genre") }
}

$gameIndex = New-StandaloneGameIndex $games $allStreamerNames
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
  # GetNewClosure() の中からは dot-source した関数が見えないため、関数を変数に取ってから呼ぶ
  $findDedicated = ${function:Get-StandaloneDedicatedPlaylists}
  $dedicatedFor = { param($gameName) & $findDedicated $games $gameName $channelPlaylists }.GetNewClosure()
  $hasGamePlaylist = { param($gameName) @($myRegistered | Where-Object game -eq $gameName).Count -gt 0 }.GetNewClosure()
  foreach ($v in $uploads) {
    if ($knownVideoIds.Contains($v.videoId)) { continue }        # サイト登録済み再生リストの動画
    if ($standaloneVideoIds.Contains($v.videoId)) { continue }  # STANDALONE_PLAYS 登録済みの動画
    $m = Get-StandaloneMatch $gameIndex $v.title $v.description @{ siteHasGamePlaylist = $hasGamePlaylist; dedicatedPlaylists = $dedicatedFor }
    if (-not $m) { continue } # 既知ゲームに絞る。未登録ゲームは管理画面で別途追加可能。
    $candidates += [pscustomobject]@{
      streamer=$s.name; game=$m.game; videoId=$v.videoId; title=$v.title; url=("https://www.youtube.com/watch?v="+$v.videoId)
      publishedDate=$v.publishedAt; thumbnail=$v.thumbnail; matchedAlias=$m.matchedAlias
      confidence=$m.confidence; matchType=$m.matchType; reasons=@($m.reasons); otherGames=@($m.otherGames)
      likelyNonGame=(@($m.reasons | Where-Object { $_ -like '非ゲーム語*' }).Count -gt 0)
      siteHasGamePlaylist=(& $hasGamePlaylist $m.game)
      dedicatedPlaylistLikely=($m.dedicatedPlaylists.Count -gt 0); dedicatedPlaylists=@($m.dedicatedPlaylists | Select-Object id,title,count)
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
      # グループの信頼度は、含まれる動画のうち最も低いもの(1本でも曖昧なら HIGH にしない)
      confidence=$(if (@($items | Where-Object confidence -eq 'LOW').Count) {'LOW'} elseif (@($items | Where-Object confidence -eq 'MEDIUM').Count) {'MEDIUM'} else {'HIGH'})
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
Write-Output ("完了: $outPath  候補グループ数=$($allGroups.Count)(HIGH " + @($allGroups | Where-Object confidence -eq 'HIGH').Count + " / MEDIUM " + @($allGroups | Where-Object confidence -eq 'MEDIUM').Count + " / LOW " + @($allGroups | Where-Object confidence -eq 'LOW').Count + ")")
Write-Output "次に admin-standalone.html を開き、このJSONを読み込んで確認してください。"
