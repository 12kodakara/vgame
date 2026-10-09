<#
.SYNOPSIS
  単発実況(STANDALONE_PLAYS)のシリーズ化・専用再生リスト移行候補の判定ロジック
  (report-standalone-followups.ps1 / test-standalone-followups.ps1 から dot-source して使う)。

.DESCRIPTION
  データ・生成物は一切変更しない。判定は「候補の報告」だけで、移行・削除は人が確認して行う。
  ゲーム名の照合は standalone-matching.ps1(先に dot-source しておくこと)の関数をそのまま使う。

  ■ 調べること(単発実況1件ごと)
    A. 動画の増加      : 同じVTuberの最近の動画のうち、同じゲームと判定できる別の動画
    B. 専用再生リスト  : 同じVTuberのチャンネルの、サイト未登録のゲーム名入り再生リスト(既存の動画IDが入っているかを優先して確認)
    C. 通常再生リストとの重複 : サイト登録済み(PLAYLISTS)の同じVTuberの再生リストに、既存の動画IDが入っていないか /
                                同じVTuber × ゲームの再生リストが登録済みでないか

  ■ ランク(強い順。複数の根拠があれば一番強いもの。どのランクでも自動移行はしない)
    STRONG : 同じVTuberの再生リストに既存の動画IDが入っていて、ゲームも一致する
             (チャンネル側のゲーム名入り再生リスト、またはサイト登録済みの同じVTuber × ゲームの再生リスト)
    MEDIUM : VTuber・ゲームが一致し関連が強いが、既存の動画IDの一致は確認できていない
             (同じゲームの別動画が【】の完全一致で見つかった / 同じVTuber × ゲームの再生リストが登録済み /
              ゲーム名入り再生リストの中身を確認できなかった)
    WEAK   : ゲーム名・タイトルが似ているだけ、または同一の実況とは言えない
             (ゲーム名入り再生リストに既存の動画が無い = 別の実況の可能性 / 一致が弱い別動画 /
              別ゲームで登録された再生リストに入っている / 企画の再生リストの可能性)
    NONE   : すべて確認でき、該当なし
    UNKNOWN: 該当は見つかっていないが、API で確認できなかった項目がある(「候補なし」とは扱わない)

  ■ 企画(data-core.js の GAME_EVENTS / PLAYLIST_EVENTS)
    PLAYLIST_EVENTS に登録された再生リスト、名前に企画名(GAME_EVENTS の name)を含む再生リスト・動画は、
    通常の実況へ移行しないよう WEAK までにする(企画名は確認済みのデータから取る。推測で企画と決めることはしない)。

  ■ 要確認の印(reviewFlags。Get-FollowupReviewFlags)
    単発実況の動画・候補の再生リスト・候補の動画の名前に、本人以外のVTuber名・本人以外の事務所名・企画名・企画を疑わせる語があるもの。
    共演(コラボ)や企画の可能性があるため、STRONG にはせず MEDIUM にして人の確認を待つ(文字列だけで移行を確定しない)。
#>

# 動画URL → 動画ID(watch?v= / youtu.be / live。validate-data.ps1 の Get-YouTubeVideoId と同じ形式)
function Get-FollowupVideoId([string]$url) {
  foreach ($p in @('^https://(?:www\.|m\.)?youtube\.com/watch\?(?:[^#]*&)?v=([A-Za-z0-9_-]{11})(?:[&#].*)?$',
      '^https://youtu\.be/([A-Za-z0-9_-]{11})(?:[?#].*)?$', '^https://(?:www\.)?youtube\.com/live/([A-Za-z0-9_-]{11})(?:[?#].*)?$')) {
    $m = [regex]::Match([string]$url, $p)
    if ($m.Success) { return $m.Groups[1].Value }
  }
  return $null
}

# 文字列から秘密の値(APIキー等)を伏せる。ログ・レポートに出す文字列は必ずこれを通す
function Protect-FollowupSecret([string]$text, [string]$secret) {
  if (-not $text) { return $text }
  if ($secret) { $text = $text.Replace($secret, '***') }
  return ($text -replace '([?&]key=)[^&\s"]+', '$1***')
}

$script:FollowupRankOrder = @('STRONG', 'MEDIUM', 'WEAK')

# ============================================================
# YouTube API クライアント(利用上限・キャッシュつき)
#   $httpGet: param($endpoint, $query) → API の応答(本番は Invoke-RestMethod、テストは固定データ)。キーは $httpGet 側で付ける
#   1回の要求 = 1ユニット(このツールが使う channels / playlists / playlistItems はすべて 1ユニット)。再試行はしない
#   キャッシュには API の応答から取り出した値だけを保存する(キー・認証情報は保存しない)
#   有効期限(時間):
#     handle(@ハンドル → チャンネルID)・uploadsId(チャンネル → アップロード再生リスト): 720(30日。変わらない対応)
#     uploads(最近の動画)・channelPlaylists(チャンネルの再生リスト一覧): 12
#       期限切れの uploads は新しい順に取り直し、キャッシュ済みの動画に届いたら止めて合わせる(差分取得)
#     playlistVideos(再生リストの動画ID): 168(7日)。ただし「その実行で新しく取った再生リスト一覧の動画数」と
#       キャッシュ時の動画数が同じときだけ使う(動画数が分からない・違うときは取り直す)。動画数0は取得しない
#   期限切れ・破損したキャッシュの値は判定に使わない(取り直せなければ「確認できない」= UNKNOWN になる)
# ============================================================
$script:FollowupCacheVersion = 1
$script:FollowupTtlHours = @{ handle = 720; uploadsId = 720; uploads = 12; channelPlaylists = 12; playlistVideos = 168 }

# キャッシュファイルを読む。無い・壊れている・形式が違うときは空のキャッシュ(warnings に理由)
function Read-FollowupCache([string]$path) {
  $c = @{ version = $script:FollowupCacheVersion; entries = @{}; warnings = New-Object System.Collections.Generic.List[string]; loaded = 0 }
  if (-not $path -or -not (Test-Path -LiteralPath $path)) { return $c }
  try {
    $j = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8) | ConvertFrom-Json
    if ($j.version -ne $script:FollowupCacheVersion -or $null -eq $j.entries) { throw "形式が違う(version $($j.version))" }
    foreach ($p in $j.entries.PSObject.Properties) {
      $e = $p.Value
      $at = [datetime]::MinValue
      if (-not $e -or -not $e.fetchedAt -or -not [datetime]::TryParse([string]$e.fetchedAt, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind, [ref]$at)) { $c.warnings.Add("キャッシュの項目 $($p.Name) が壊れているため使わない"); continue }
      $c.entries[$p.Name] = @{ fetchedAt = $at.ToUniversalTime(); data = $e.data; meta = $e.meta }
      $c.loaded++
    }
  } catch { $c.entries = @{}; $c.loaded = 0; $c.warnings.Add("キャッシュを読めないため使わない(作り直す): $($_.Exception.Message)") }
  return $c
}

# キャッシュファイルを書く(一時ファイルに書いてから置き換える。秘密の値が入っていたら書かない)
function Write-FollowupCache($cache, [string]$path, [string]$secret) {
  if (-not $path) { return }
  $entries = [ordered]@{}
  foreach ($k in @($cache.entries.Keys | Sort-Object)) { $e = $cache.entries[$k]; $entries[$k] = [ordered]@{ fetchedAt = $e.fetchedAt.ToString('o'); data = $e.data; meta = $e.meta } }
  $text = [ordered]@{ version = $script:FollowupCacheVersion; note = 'YouTube API の応答のキャッシュ(report-standalone-followups.ps1 用)。キー・認証情報は含まない'; entries = $entries } | ConvertTo-Json -Depth 10 -Compress
  if ($secret -and $text.Contains($secret)) { throw "キャッシュに秘密の値が含まれていたため保存しない" }
  $dir = Split-Path -Parent $path
  if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $tmp = $path + '.tmp'
  [IO.File]::WriteAllText($tmp, $text, (New-Object System.Text.UTF8Encoding($false)))
  Move-Item -LiteralPath $tmp -Destination $path -Force
}

function New-FollowupApiClient([scriptblock]$httpGet, [int]$maxUnits, $cache, [datetime]$now, [string]$secret = '') {
  if (-not $cache) { $cache = @{ entries = @{}; warnings = New-Object System.Collections.Generic.List[string]; loaded = 0 } }
  return @{ httpGet = $httpGet; maxUnits = $maxUnits; units = 0; byEndpoint = [ordered]@{}; budgetReached = $false; warnedNearLimit = $false
    cache = $cache; now = $now.ToUniversalTime(); secret = $secret; stats = [ordered]@{ hit = 0; miss = 0; expired = 0; reusedByCount = 0; incremental = 0; skippedEmpty = 0 }
    notices = New-Object System.Collections.Generic.List[string] }
}

# API を1回呼ぶ(利用上限を超える要求はしない。失敗しても再試行しない)
function Invoke-FollowupApi($client, [string]$endpoint, [string]$query) {
  if ($client.units + 1 -gt $client.maxUnits) {
    $client.budgetReached = $true
    throw "この実行の API 利用上限(-MaxUnits $($client.maxUnits))に達したため取得していない"
  }
  $client.units++
  if (-not $client.byEndpoint.Contains($endpoint)) { $client.byEndpoint[$endpoint] = 0 }
  $client.byEndpoint[$endpoint]++
  if (-not $client.warnedNearLimit -and $client.units -ge [math]::Ceiling($client.maxUnits * 0.8)) {
    $client.warnedNearLimit = $true; $client.notices.Add("API 利用量が上限の8割($($client.units) / $($client.maxUnits))に達した")
  }
  try { return (& $client.httpGet $endpoint $query) }
  catch { throw (Protect-FollowupSecret ([string]$_.Exception.Message) $client.secret) }
}

# 有効なキャッシュの値(無い・期限切れなら $null。期限切れは stats に数える)
function Get-FollowupCached($client, [string]$key, [string]$kind) {
  if (-not $client.cache.entries.ContainsKey($key)) { return $null }
  $e = $client.cache.entries[$key]
  if (($client.now - $e.fetchedAt).TotalHours -gt $script:FollowupTtlHours[$kind]) { $client.stats.expired++; return $null }
  return $e
}
function Set-FollowupCached($client, [string]$key, $data, $meta = $null) { $client.cache.entries[$key] = @{ fetchedAt = $client.now; data = $data; meta = $meta } }

# 再生リストの全項目(50件ずつ。$max 件で打ち切り。$stopAt に入っている動画IDに届いたらそこで止める)
function Get-FollowupPlaylistItems($client, [string]$playlistId, [string]$part, [int]$max, $stopAt = $null) {
  $items = @(); $token = $null; $reached = $false
  do {
    $q = "part=$part&maxResults=50&playlistId=$([uri]::EscapeDataString($playlistId))"
    if ($token) { $q += "&pageToken=$([uri]::EscapeDataString($token))" }
    $r = Invoke-FollowupApi $client 'playlistItems' $q
    foreach ($it in @($r.items)) {
      if ($stopAt -and $stopAt.Contains([string]$it.contentDetails.videoId)) { $reached = $true; break }
      $items += $it
    }
    $token = $r.nextPageToken
  } while ($token -and -not $reached -and ($max -le 0 -or $items.Count -lt $max))
  if ($max -gt 0 -and $items.Count -gt $max) { $items = $items[0..($max - 1)] }
  return [pscustomobject]@{ items = $items; reachedCached = $reached }
}

# Invoke-StandaloneFollowupCollect に渡す $api(キャッシュつき)を作る。
# 使うクライアントは $script:FollowupActiveClient に置く(GetNewClosure はモジュール扱いになり、dot-source した関数が見えなくなるため)。
# 同時に使えるクライアントは1つだけ
function New-FollowupCachedApi($client) {
  $script:FollowupActiveClient = $client
  return {
    param($kind, $arg)
    $c = $script:FollowupActiveClient
    if ($kind -eq 'channelIdForHandle') {
      $key = "handle|$arg"; $e = Get-FollowupCached $c $key 'handle'
      if ($e) { $c.stats.hit++; return $e.data }
      $c.stats.miss++
      $r = Invoke-FollowupApi $c 'channels' ("part=id&forHandle=" + [uri]::EscapeDataString($arg))
      $id = $null; if ($r.items) { $id = [string]$r.items[0].id }
      if ($id) { Set-FollowupCached $c $key $id }
      return $id
    }
    if ($kind -eq 'uploads') {
      $cid = $arg.channelId; $max = [int]$arg.max
      $ukey = "uploadsId|$cid"; $ue = Get-FollowupCached $c $ukey 'uploadsId'
      if ($ue) { $c.stats.hit++; $uploadsId = [string]$ue.data }
      else {
        $c.stats.miss++
        $r = Invoke-FollowupApi $c 'channels' ("part=contentDetails&id=" + [uri]::EscapeDataString($cid))
        if (-not $r.items) { throw "チャンネル情報を取得できません" }
        $uploadsId = [string]$r.items[0].contentDetails.relatedPlaylists.uploads
        Set-FollowupCached $c $ukey $uploadsId
      }
      $lkey = "uploads|$cid"; $le = Get-FollowupCached $c $lkey 'uploads'
      if ($le -and $le.meta -and [int]$le.meta.max -ge $max) { $c.stats.hit++; return @($le.data | Select-Object -First $max) }
      # 期限切れでも以前の一覧があれば、新しい動画だけ取り直して合わせる(以前の一覧は同じ max で取ったものに限る)
      $old = $null
      if ($c.cache.entries.ContainsKey($lkey)) { $o = $c.cache.entries[$lkey]; if ($o.meta -and [int]$o.meta.max -eq $max -and $o.data) { $old = @($o.data) } }
      $stopAt = $null
      if ($old) { $stopAt = New-Object System.Collections.Generic.HashSet[string]; foreach ($v in $old) { [void]$stopAt.Add([string]$v.videoId) } }
      $c.stats.miss++
      $res = Get-FollowupPlaylistItems $c $uploadsId 'snippet,contentDetails' $max $stopAt
      $fresh = @($res.items | ForEach-Object {
          [pscustomobject]@{ videoId = [string]$_.contentDetails.videoId; title = [string]$_.snippet.title; description = [string]$_.snippet.description
            publishedAt = $(if ($_.contentDetails.videoPublishedAt) { [string]$_.contentDetails.videoPublishedAt } else { [string]$_.snippet.publishedAt }) } })
      $list = $fresh
      if ($res.reachedCached) {
        $c.stats.incremental++
        $seen = @{}; $list = @()
        foreach ($v in @($fresh) + @($old)) { if (-not $seen.ContainsKey($v.videoId)) { $seen[$v.videoId] = $true; $list += $v } }
        $list = @($list | Select-Object -First $max)
      }
      Set-FollowupCached $c $lkey $list @{ max = $max }
      return $list
    }
    if ($kind -eq 'channelPlaylists') {
      $key = "channelPlaylists|$arg"; $e = Get-FollowupCached $c $key 'channelPlaylists'
      if ($e) { $c.stats.hit++; return @($e.data) }
      $c.stats.miss++
      $pls = @(); $token = $null
      do {
        $q = "part=snippet,contentDetails&maxResults=50&channelId=" + [uri]::EscapeDataString($arg)
        if ($token) { $q += "&pageToken=$([uri]::EscapeDataString($token))" }
        $r = Invoke-FollowupApi $c 'playlists' $q
        $pls += @($r.items | ForEach-Object { [pscustomobject]@{ id = [string]$_.id; title = [string]$_.snippet.title; count = $_.contentDetails.itemCount } }); $token = $r.nextPageToken
      } while ($token)
      Set-FollowupCached $c $key $pls
      return $pls
    }
    if ($kind -eq 'playlistVideos') {
      $pid0 = [string]$arg.playlistId; $count = $arg.count
      if ($null -ne $count -and [int]$count -eq 0) { $c.stats.skippedEmpty++; return @() }
      $key = "playlistVideos|$pid0"; $e = Get-FollowupCached $c $key 'playlistVideos'
      if ($e -and $null -ne $count -and $e.meta -and $null -ne $e.meta.count -and [int]$e.meta.count -eq [int]$count) { $c.stats.reusedByCount++; return @($e.data) }
      $c.stats.miss++
      $ids = @((Get-FollowupPlaylistItems $c $pid0 'contentDetails' 0).items | ForEach-Object { [string]$_.contentDetails.videoId })
      Set-FollowupCached $c $key $ids @{ count = $(if ($null -ne $count) { [int]$count } else { $ids.Count }) }
      return $ids
    }
    throw "不明な取得種別: $kind"
  }
}

# 企画名(GAME_EVENTS の name)を名前に含むか(照合は standalone-matching.ps1 と同じ正規化)
function Test-FollowupEventName([string]$text, $eventNames) {
  if (-not $text) { return $null }
  $t = (Get-StandaloneNorm $text) -replace ' ', ''
  foreach ($n in @($eventNames)) {
    $k = (Get-StandaloneNorm $n) -replace ' ', ''
    if ($k.Length -ge 2 -and $t.Contains($k)) { return $n }
  }
  return $null
}

# ============================================================
# 人の確認が必要な候補(共演・他事務所・企画の疑い)。文字列だけで移行を確定しないための「要確認」の印。
#   - 本人以外のVTuber名: STREAMERS の名前(全体)と名前の部分(「・」・空白・文字種の切れ目で分けた3文字以上)
#       例: 壱百満天原サロメ → サロメ / アンジュ・カトリーナ → アンジュ・カトリーナ。英字の名前は単語単位、
#       かなだけの語は前後がかなでないときだけ一致にする(ジョー ≠ ジョーカー)。名前全体は3文字以上(漢字を含むなら2文字以上)
#   - 本人以外の事務所: STREAMERS の group の先頭(ホロライブ / にじさんじ / ぶいすぽ)と英字表記
#   - 企画名(GAME_EVENTS)と、企画を疑わせる語($script:FollowupReviewKeywords)
#   当てはまってもランクを上げることはない(STRONG は MEDIUM にして人の確認を待つ)
# ============================================================
$script:FollowupReviewKeywords = @('甲子園', '大会', '杯', 'リーグ', '選手権', 'トーナメント', 'コラボ', '企画', '対抗', '交流戦', 'カップ', 'cup', 'フェス', '祭', 'vs', '運動会', 'チーム戦')
$script:FollowupAgencyAliases = @{ 'ホロライブ' = @('hololive'); 'にじさんじ' = @('nijisanji'); 'ぶいすぽ' = @('vspo') }

# 企画名・企画を疑わせる語(照合は standalone-matching.ps1 と同じ正規化)。見つかったものを「企画名「…」」「語「…」」で返す
function Find-FollowupEventWords([string[]]$texts, $eventNames) {
  $found = New-Object System.Collections.Generic.List[string]
  foreach ($t in @($texts | Where-Object { $_ })) {
    $n = Test-FollowupEventName $t $eventNames
    if ($n -and -not $found.Contains("企画名「$n」")) { $found.Add("企画名「$n」") }
    $norm = (Get-StandaloneNorm $t) -replace ' ', ''
    foreach ($k in $script:FollowupReviewKeywords) {
      $kn = (Get-StandaloneNorm $k) -replace ' ', ''
      if ($kn -and $norm.Contains($kn) -and -not $found.Contains("語「$k」")) { $found.Add("語「$k」") }
    }
  }
  return $found.ToArray()   # 呼び出し側で @() に包む(0件は空配列)
}

# 名前を照合用の語に分ける(全体 + 3文字以上の部分)。返り値は正規化済み・空白なしの語
function Get-FollowupNameTokens([string]$name) {
  $tokens = New-Object System.Collections.Generic.List[string]
  $add = { param($s) $n = (Get-StandaloneNorm $s) -replace ' ', ''; if ($n -and -not $tokens.Contains($n)) { $tokens.Add($n) } }
  $whole = (Get-StandaloneNorm $name) -replace ' ', ''
  # 名前全体は3文字以上。2文字は漢字を含むときだけ(「える」が「エルデンリング」に当たるような誤検出を防ぐ)
  if ($whole.Length -ge 3 -or ($whole.Length -eq 2 -and $whole -match '[一-鿿々]')) { & $add $name }
  $kind = { param([char]$c) $i = [int]$c
    if (($i -ge 0x4E00 -and $i -le 0x9FFF) -or $i -eq 0x3005) { 'kanji' } elseif ($i -ge 0x30A1 -and $i -le 0x30FC -and $i -ne 0x30FB) { 'kata' } elseif ($i -ge 0x3041 -and $i -le 0x309F) { 'hira' }
    elseif ([char]::IsLetterOrDigit($c) -or $c -eq "'") { 'latin' } else { 'sep' } }
  $cur = New-Object System.Text.StringBuilder; $curKind = $null
  foreach ($c in ($name + ' ').ToCharArray()) {
    $k = & $kind $c
    if ($k -ne $curKind) {
      # 部分は3文字以上(英字は4文字以上。「Ver」が「ver.1.2」に当たるような誤検出を防ぐ)
      if ($curKind -and $curKind -ne 'sep' -and $cur.Length -ge $(if ($curKind -eq 'latin') { 4 } else { 3 })) { & $add $cur.ToString() }
      [void]$cur.Clear(); $curKind = $k
    }
    if ($k -ne 'sep') { [void]$cur.Append($c) }
  }
  return $tokens.ToArray()
}

# STREAMERS(name, group)から照合用の索引を作る
function New-FollowupCollabIndex($streamers) {
  $idx = @{ tokens = New-Object System.Collections.Generic.List[object]; tokensOf = @{}; agencyOf = @{}; agencies = New-Object System.Collections.Generic.List[string] }
  foreach ($s in @($streamers)) {
    if (-not $s -or -not $s.name) { continue }
    $toks = @(Get-FollowupNameTokens ([string]$s.name))
    $idx.tokensOf[[string]$s.name] = $toks
    # kana: かなだけの語は前後がかなでないときだけ一致にする(「ジョー」が「ジョーカー」に当たるような誤検出を防ぐ)
    foreach ($t in $toks) { $idx.tokens.Add([pscustomobject]@{ token = $t; owner = [string]$s.name; ascii = ($t -match '^[\x00-\x7f]+$'); kana = ($t -match '^[ぁ-ゟー・]+$') }) }
    $g = [string]$s.group
    if ($g) { $a = ($g.Trim() -split '\s+')[0]; $idx.agencyOf[[string]$s.name] = $a; if (-not $idx.agencies.Contains($a)) { $idx.agencies.Add($a) } }
  }
  return $idx
}

# 本人($self)以外のVTuber名・事務所名を探す。見つかったものの説明を返す
function Find-FollowupCollab([string[]]$texts, $index, [string]$self) {
  $found = New-Object System.Collections.Generic.List[string]
  if (-not $index) { return $found.ToArray() }
  $selfTokens = @(); if ($index.tokensOf.ContainsKey($self)) { $selfTokens = @($index.tokensOf[$self]) }
  $selfAgency = $index.agencyOf[$self]
  foreach ($t in @($texts | Where-Object { $_ })) {
    $norm = (Get-StandaloneNorm $t) -replace ' ', ''
    $spaced = Get-StandaloneNorm $t
    foreach ($e in $index.tokens) {
      if ($e.owner -eq $self -or $selfTokens -contains $e.token) { continue }
      $hit = $(if ($e.ascii) { [regex]::IsMatch($spaced, '(?<![a-z0-9])' + [regex]::Escape($e.token) + '(?![a-z0-9])') }
        elseif ($e.kana) { [regex]::IsMatch($norm, '(?<![ぁ-ゟァ-ー])' + [regex]::Escape($e.token) + '(?![ぁ-ゟァ-ー])') }
        else { $norm.Contains($e.token) })
      if ($hit) { $msg = "本人以外のVTuber「$($e.owner)」"; if (-not $found.Contains($msg)) { $found.Add($msg) } }
    }
    foreach ($a in $index.agencies) {
      if ($a -eq $selfAgency) { continue }
      $keys = @($a) + @($script:FollowupAgencyAliases[$a] | Where-Object { $_ })
      foreach ($k in $keys) {
        $kn = (Get-StandaloneNorm $k) -replace ' ', ''
        if ($kn -and $norm.Contains($kn)) { $msg = "本人以外の事務所「$a」"; if (-not $found.Contains($msg)) { $found.Add($msg) }; break }
      }
    }
  }
  return $found.ToArray()
}

# 要確認の印(共演・他事務所・企画)。$where はどの文字列か(例: 単発実況の動画)
function Get-FollowupReviewFlags([string]$where, [string[]]$texts, $collabIndex, $eventNames, [string]$self) {
  $items = @(Find-FollowupCollab $texts $collabIndex $self) + @(Find-FollowupEventWords $texts $eventNames)
  return @($items | ForEach-Object { "$($where): $_" })
}

# ============================================================
# 取得(YouTube API)。$api は次の種類に答えるスクリプトブロック(本番は API、テストは固定データ)
#   & $api 'channelIdForHandle' '@handle' → チャンネルID / $null
#   & $api 'uploads' @{ channelId; max }   → @( @{ videoId; title; description; publishedAt } ... )(新しい順)
#   & $api 'channelPlaylists' channelId     → @( @{ id; title; count } ... )
#   & $api 'playlistVideos' @{ playlistId; count } → @( 動画ID ... )(count = 一覧での動画数。分からなければ $null)
# 失敗したものは failures に「対象と理由」を残し、判定では「確認できない」として扱う。同じ再生リストは1回だけ取得する。
# ============================================================
function Invoke-StandaloneFollowupCollect($plays, $streamers, $sitePlaylists, $games, [scriptblock]$api, [int]$maxVideos = 200, [string]$secret = '') {
  $col = @{ streamers = @{}; playlistVideos = @{}; failures = New-Object System.Collections.Generic.List[object] }
  $fail = { param($target, $err) $col.failures.Add([pscustomobject]@{ target = $target; reason = (Protect-FollowupSecret ([string]$err) $secret) }) }
  # $count: その実行で取ったチャンネルの再生リスト一覧での動画数(分からなければ $null)。キャッシュの再利用判定に使う
  $getPlaylist = {
    param($plId, $label, $count)
    if ($col.playlistVideos.ContainsKey($plId)) { return }
    try { $col.playlistVideos[$plId] = @(& $api 'playlistVideos' @{ playlistId = $plId; count = $count }) }
    catch { $col.playlistVideos[$plId] = $null; & $fail ("再生リスト " + $label + " (" + $plId + ")") $_.Exception.Message }
  }
  $registeredIds = @{}; foreach ($p in @($sitePlaylists)) { $registeredIds[$p.playlistId] = $true }
  foreach ($name in @($plays | ForEach-Object { $_.streamer } | Select-Object -Unique)) {
    $st = @($streamers | Where-Object { $_.name -eq $name })[0]
    $info = @{ status = 'ok'; channelId = $null; uploads = $null; channelPlaylists = $null }
    $col.streamers[$name] = $info
    try {
      $url = $(if ($st) { [string]$st.youtube } else { '' })
      $m = [regex]::Match($url, '/channel/(UC[A-Za-z0-9_-]{22})')
      if ($m.Success) { $info.channelId = $m.Groups[1].Value }
      else {
        $h = [regex]::Match($url, '/(@[^/?#]+)')
        if (-not $h.Success) { throw "STREAMERS の youtube からチャンネルを特定できません" }
        $info.channelId = & $api 'channelIdForHandle' $h.Groups[1].Value
        if (-not $info.channelId) { throw "ハンドル $($h.Groups[1].Value) のチャンネルが見つかりません" }
      }
    } catch { $info.status = 'failed'; & $fail ("チャンネル " + $name) $_.Exception.Message; continue }
    try { $info.uploads = @(& $api 'uploads' @{ channelId = $info.channelId; max = $maxVideos }) }
    catch { $info.uploads = $null; & $fail ("最近の動画 " + $name) $_.Exception.Message }
    try { $info.channelPlaylists = @(& $api 'channelPlaylists' $info.channelId) }
    catch { $info.channelPlaylists = $null; & $fail ("チャンネルの再生リスト一覧 " + $name) $_.Exception.Message }
    $counts = @{}; foreach ($cp in @($info.channelPlaylists)) { if ($cp -and $null -ne $cp.count) { $counts[[string]$cp.id] = $cp.count } }
    # C: サイト登録済みの同じVTuberの再生リスト(既存の動画IDが入っていないか)
    foreach ($p in @($sitePlaylists | Where-Object { $_.streamer -eq $name })) { & $getPlaylist $p.playlistId ($p.id + "「" + $p.title + "」") $counts[$p.playlistId] }
    # B: サイト未登録のゲーム名入り再生リスト
    if ($null -ne $info.channelPlaylists) {
      $unregistered = @($info.channelPlaylists | Where-Object { -not $registeredIds.ContainsKey($_.id) })
      foreach ($play in @($plays | Where-Object { $_.streamer -eq $name })) {
        foreach ($cp in @(Get-StandaloneDedicatedPlaylists $games $play.game $unregistered)) { & $getPlaylist $cp.id ("「" + $cp.title + "」") $counts[$cp.id] }
      }
    }
  }
  return $col
}

# ============================================================
# 判定(1件)。$ctx: games / index(New-StandaloneGameIndex) / sitePlaylists / eventPlaylistIds(playlistId → 企画名) /
#   eventNames / standaloneVideoIds(全単発実況の動画ID) / collected(Invoke-StandaloneFollowupCollect の結果。$null = API を使っていない)
# ============================================================
function Get-StandaloneFollowup($play, $ctx) {
  $videoIds = @(@($play.videos) | ForEach-Object { Get-FollowupVideoId $_.url } | Where-Object { $_ } | Select-Object -Unique)
  $evidence = New-Object System.Collections.Generic.List[object]
  $unverified = New-Object System.Collections.Generic.List[string]
  $newVideos = New-Object System.Collections.Generic.List[object]
  $playlistCands = New-Object System.Collections.Generic.List[object]
  $dupCands = New-Object System.Collections.Generic.List[object]
  $add = { param($kind, $rank, $reason) $evidence.Add([pscustomobject]@{ kind = $kind; rank = $rank; reason = $reason }) }
  $pv = $(if ($ctx.collected) { $ctx.collected.playlistVideos } else { @{} })
  $contains = { param($plId) if (-not $pv.ContainsKey($plId) -or $null -eq $pv[$plId]) { return $null }; return (@($videoIds | Where-Object { @($pv[$plId]) -contains $_ }).Count -gt 0) }
  $info = $(if ($ctx.collected -and $ctx.collected.streamers.ContainsKey($play.streamer)) { $ctx.collected.streamers[$play.streamer] } else { $null })
  if (-not $videoIds.Count) { $unverified.Add('動画URLから動画IDを取り出せない(照合できない)') }

  # ---- C. サイト登録済み再生リスト(PLAYLISTS)との重複 ----
  $mine = @($ctx.sitePlaylists | Where-Object { $_.streamer -eq $play.streamer })
  foreach ($pl in $mine) {
    $exact = ($pl.game -eq $play.game)
    $ev = $ctx.eventPlaylistIds[$pl.playlistId]
    $in = & $contains $pl.playlistId
    if (-not $exact -and $in -ne $true) { continue }
    $dupCands.Add([pscustomobject]@{ id = $pl.id; playlistId = $pl.playlistId; title = $pl.title; game = $pl.game; sameGame = $exact; event = $ev; videoInPlaylist = $in })
    if ($ev) { & $add 'C' 'WEAK' "登録済みの企画再生リスト「$($pl.title)」($ev)$(if ($in) { 'に既存の動画が入っている' } else { 'と同じ組み合わせ' })。企画なので通常の実況へは移行しない"; continue }
    if ($exact -and $in -eq $true) { & $add 'C' 'STRONG' "登録済みの同じVTuber × ゲームの再生リスト「$($pl.title)」($($pl.id))に既存の動画が入っている(重複。単発実況側の整理が必要)" }
    elseif ($exact) {
      & $add 'C' 'MEDIUM' "同じVTuber × ゲームの再生リスト「$($pl.title)」($($pl.id))が登録済み(validate-data でエラーになる組み合わせ)$(if ($in -eq $false) { '。既存の動画は入っていない' } else { '' })"
      if ($null -eq $in) { $unverified.Add("登録済み再生リスト $($pl.id) の中身を確認できない") }
    } else { & $add 'C' 'WEAK' "既存の動画が、別ゲーム「$($pl.game)」として登録された再生リスト「$($pl.title)」($($pl.id))に入っている(ゲーム分類の確認が必要)" }
  }
  if ($ctx.collected) {
    foreach ($pl in $mine) { if ($pv.ContainsKey($pl.playlistId) -and $null -eq $pv[$pl.playlistId]) { $unverified.Add("登録済み再生リスト $($pl.id) の中身を取得できない") } }
  } else { $unverified.Add('YouTube API を使っていない(登録済み再生リストの中身・チャンネルの再生リスト・最近の動画は未確認)') }

  if ($ctx.collected) {
    if (-not $info -or $info.status -ne 'ok') { $unverified.Add('チャンネルを特定できない(再生リスト・最近の動画は未確認)') }
    else {
      # ---- B. チャンネル側のサイト未登録のゲーム名入り再生リスト ----
      if ($null -eq $info.channelPlaylists) { $unverified.Add('チャンネルの再生リスト一覧を取得できない') }
      else {
        $registered = @{}; foreach ($p in @($ctx.sitePlaylists)) { $registered[$p.playlistId] = $true }
        $unregistered = @($info.channelPlaylists | Where-Object { -not $registered.ContainsKey($_.id) })
        foreach ($cp in @(Get-StandaloneDedicatedPlaylists $ctx.games $play.game $unregistered)) {
          $in = & $contains $cp.id
          $evName = Test-FollowupEventName $cp.title $ctx.eventNames
          $playlistCands.Add([pscustomobject]@{ playlistId = $cp.id; title = $cp.title; channel = $play.streamer; channelId = $info.channelId; count = $cp.count; videoInPlaylist = $in; event = $evName })
          if ($evName) { & $add 'B' 'WEAK' "チャンネルの再生リスト「$($cp.title)」は企画名「$evName」を含む(企画の可能性。通常の実況へは移行しない)" }
          elseif ($in -eq $true) { & $add 'B' 'STRONG' "同じVTuberのチャンネルの、ゲーム名入り再生リスト「$($cp.title)」($($cp.count)本)に既存の動画が入っている" }
          elseif ($in -eq $false) { & $add 'B' 'WEAK' "ゲーム名入り再生リスト「$($cp.title)」($($cp.count)本)はあるが、既存の動画は入っていない(別の実況の可能性)" }
          else { & $add 'B' 'MEDIUM' "ゲーム名入り再生リスト「$($cp.title)」($($cp.count)本)があるが、中身を確認できない"; $unverified.Add("再生リスト $($cp.id) の中身を取得できない") }
        }
      }
      # ---- A. 同じVTuber・同じゲームの別の動画 ----
      if ($null -eq $info.uploads) { $unverified.Add('最近の動画を取得できない') }
      else {
        $existingDate = @(@($play.videos) | ForEach-Object { $_.publishedDate } | Where-Object { $_ } | Sort-Object)[0]
        $oldest = @(@($info.uploads) | ForEach-Object { [string]$_.publishedAt } | Where-Object { $_ } | Sort-Object)[0]
        if ($existingDate -and $oldest -and $oldest.Substring(0, 10) -gt $existingDate) { $unverified.Add("最近の動画の取得範囲($($oldest.Substring(0, 10))以降)が既存の動画の公開日($existingDate)まで届いていない(それより前の動画は未確認)") }
        foreach ($v in @($info.uploads)) {
          if ($videoIds -contains $v.videoId) { continue }
          if ($ctx.standaloneVideoIds -and $ctx.standaloneVideoIds.Contains($v.videoId)) { continue }   # 別の単発実況として登録済み
          $mt = Get-StandaloneMatch $ctx.index ([string]$v.title) ([string]$v.description) $null
          if (-not $mt -or $mt.game -ne $play.game) { continue }
          $inRegistered = @($mine | Where-Object { $pv.ContainsKey($_.playlistId) -and $null -ne $pv[$_.playlistId] -and @($pv[$_.playlistId]) -contains $v.videoId } | ForEach-Object { $_.id })
          $evName = Test-FollowupEventName ([string]$v.title) $ctx.eventNames
          $strongMatch = ($mt.matchType -eq 'bracket-exact' -and $mt.confidence -ne 'LOW' -and -not @($mt.otherGames).Count -and -not @($mt.reasons | Where-Object { $_ -match '共有|複数ゲーム' }).Count)
          $newVideos.Add([pscustomobject]@{ videoId = $v.videoId; title = $v.title; publishedAt = $v.publishedAt; matchType = $mt.matchType; confidence = $mt.confidence; matchReasons = @($mt.reasons); inRegisteredPlaylists = @($inRegistered); event = $evName })
          $when = $(if ($existingDate -and $v.publishedAt -and ([string]$v.publishedAt).Substring(0, 10) -lt $existingDate) { '既存の動画より前の' } else { '' })
          if ($evName) { & $add 'A' 'WEAK' "$($when)同じゲームの動画「$($v.title)」は企画名「$evName」を含む(企画の可能性)" }
          elseif ($inRegistered.Count) { & $add 'A' 'WEAK' "$($when)同じゲームの動画「$($v.title)」は登録済み再生リスト($($inRegistered -join ', '))に入っている" }
          elseif ($strongMatch) { & $add 'A' 'MEDIUM' "$($when)同じVTuber・同じゲームの別の動画「$($v.title)」(タイトルの【】がゲーム名と一致。同じシリーズかは未確定)" }
          else { & $add 'A' 'WEAK' "$($when)同じゲームの可能性がある動画「$($v.title)」(一致: $($mt.matchType)・$($mt.confidence))" }
        }
      }
    }
  }

  # ---- 要確認の印(共演・他事務所・企画の疑い)。単発実況の動画と、候補の再生リスト・動画の名前を調べる ----
  $collabIndex = $(if ($ctx.PSObject.Properties['collabIndex']) { $ctx.collabIndex } else { $null })
  $reviewFlags = New-Object System.Collections.Generic.List[string]
  $addFlags = { param($where, $texts) foreach ($f in @(Get-FollowupReviewFlags $where $texts $collabIndex $ctx.eventNames $play.streamer)) { if (-not $reviewFlags.Contains($f)) { $reviewFlags.Add($f) } } }
  $playTitle = $(if ($play.PSObject.Properties['title']) { [string]$play.title } else { '' })
  & $addFlags '単発実況' (@($playTitle) + @(@($play.videos) | ForEach-Object { [string]$_.title }))
  foreach ($cp in $playlistCands) { & $addFlags "再生リスト「$($cp.title)」" @([string]$cp.title) }
  foreach ($nv in $newVideos) { & $addFlags "動画「$($nv.title)」" @([string]$nv.title) }

  $rank = $null
  foreach ($r in $script:FollowupRankOrder) { if (@($evidence | Where-Object { $_.rank -eq $r }).Count) { $rank = $r; break } }
  if (-not $rank) { $rank = $(if ($unverified.Count) { 'UNKNOWN' } else { 'NONE' }) }
  # 要確認の印があれば STRONG にしない(文字列だけで移行を確定しない。人が確認するまで MEDIUM)
  if ($reviewFlags.Count -and $rank -eq 'STRONG') { $rank = 'MEDIUM'; & $add '要確認' 'MEDIUM' '共演・他事務所・企画の疑いがあるため STRONG にしない(人が確認する)' }
  $action = switch ($rank) {
    'STRONG' { '移行候補(確認待ち)。人が再生リストの内容を確認し、再生リスト追加と単発実況の整理を同じ commit で行う' }
    'MEDIUM' { '確認待ち。既存の動画IDが再生リストに入っているか・同じ実況かを確認する' }
    'WEAK' { '経過観察。同じ実況の証拠が無いため移行しない(企画・別の実況・分類違いの可能性を確認)' }
    'UNKNOWN' { 'API で再確認する(未確認の項目があるため「候補なし」とは判定しない)' }
    default { '対応不要' }
  }
  if ($reviewFlags.Count -and @('STRONG', 'MEDIUM') -contains $rank) { $action = '要確認(共演・他事務所・企画の疑い)。' + $action }
  return [pscustomobject]@{ id = $play.id; streamer = $play.streamer; game = $play.game; format = $play.format; videoIds = @($videoIds)
    rank = $rank; action = $action; reasons = @($evidence | ForEach-Object { "[$($_.kind)/$($_.rank)] $($_.reason)" }); reviewFlags = $reviewFlags.ToArray(); unverified = @($unverified | Select-Object -Unique)
    newVideoCandidates = $newVideos.ToArray(); playlistCandidates = $playlistCands.ToArray(); duplicateCandidates = $dupCands.ToArray(); sharedWith = @() }   # List は ToArray で配列にする(@(List) をハッシュ表の中に書くと PowerShell 5.1 でエラーになる)
}

# 全件の判定。同じ動画・再生リストが複数の単発実況の候補になったら sharedWith に記録する
function Get-StandaloneFollowupReport($plays, $ctx) {
  $results = @(@($plays) | ForEach-Object { Get-StandaloneFollowup $_ $ctx })
  $owners = @{}
  foreach ($r in $results) {
    $keys = @($r.newVideoCandidates | ForEach-Object { 'video:' + $_.videoId }) + @($r.playlistCandidates | ForEach-Object { 'playlist:' + $_.playlistId })
    foreach ($k in @($keys | Select-Object -Unique)) { if (-not $owners.ContainsKey($k)) { $owners[$k] = @() }; $owners[$k] += $r.id }
  }
  foreach ($r in $results) {
    $keys = @($r.newVideoCandidates | ForEach-Object { 'video:' + $_.videoId }) + @($r.playlistCandidates | ForEach-Object { 'playlist:' + $_.playlistId })
    $shared = @()
    foreach ($k in @($keys | Select-Object -Unique)) { $others = @($owners[$k] | Where-Object { $_ -ne $r.id }); if ($others.Count) { $shared += [pscustomobject]@{ candidate = $k; with = $others } } }
    if ($shared.Count) {
      $r.sharedWith = $shared
      $r.reasons = @($r.reasons) + @("[共通] 同じ候補が他の単発実況にも出ている: " + (($shared | ForEach-Object { $_.candidate + ' → ' + ($_.with -join ',') }) -join ' / ') + "(どちらの実況か確認が必要)")
    }
  }
  return , $results
}
