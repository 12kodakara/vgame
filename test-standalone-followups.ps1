<#
.SYNOPSIS
  単発実況のシリーズ化・専用再生リスト移行候補レポート(standalone-followups.ps1 / report-standalone-followups.ps1)のテスト。
  YouTube API は呼ばない(固定データの取得関数で置き換える)。本番データは変更しない。
    .\test-standalone-followups.ps1
#>
$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir "standalone-matching.ps1")
. (Join-Path $scriptDir "standalone-followups.ps1")

$script:pass = 0; $script:fail = 0
function Check([string]$name, [bool]$ok, [string]$detail = "") {
  if ($ok) { $script:pass++; Write-Output "  [PASS] $name" } else { $script:fail++; Write-Output "  [FAIL] $name"; if ($detail) { Write-Output "         $detail" } }
}
Write-Output "=== 単発実況 シリーズ化・専用再生リスト移行候補 テスト ==="

# ---- 固定データ ----
$ch = { param($c) "https://www.youtube.com/channel/UC" + ($c * 22) }
$games = @(
  [pscustomobject]@{ name = '夜勤事件'; aliases = @('夜勤事件') },
  [pscustomobject]@{ name = '8番出口'; aliases = @('8番出口') },
  [pscustomobject]@{ name = 'パワフルプロ野球'; aliases = @('パワフルプロ野球', 'パワプロ') }
)
$streamers = @(
  [pscustomobject]@{ name = 'VA'; youtube = (& $ch 'a') }, [pscustomobject]@{ name = 'VB'; youtube = 'https://www.youtube.com/@vb_handle' },
  [pscustomobject]@{ name = 'VC'; youtube = (& $ch 'c') }, [pscustomobject]@{ name = 'VD'; youtube = (& $ch 'd') },
  [pscustomobject]@{ name = 'VE'; youtube = (& $ch 'e') }, [pscustomobject]@{ name = 'VF'; youtube = (& $ch 'f') }
)
$vid = { param($c) 'v' + ($c * 10) }   # 11文字の動画ID
$play = { param($id, $s, $g, $v, $d = '2026-10-01') [pscustomobject]@{ id = $id; streamer = $s; game = $g; format = 'single'; videos = @([pscustomobject]@{ url = "https://www.youtube.com/watch?v=$v"; title = 't'; publishedDate = $d }) } }
$plays = @(
  (& $play 'p1' 'VA' '夜勤事件' (& $vid '1')),    # 1. 既存の動画がチャンネルの専用再生リストに入っている
  (& $play 'p2' 'VB' '夜勤事件' (& $vid '2')),    # 2. 同じゲームの再生リストはあるが別の実況
  (& $play 'p3' 'VC' '8番出口' (& $vid '3')),     # 3. 同じVTuberの別ゲームしかない
  (& $play 'p4' 'VE' 'パワフルプロ野球' (& $vid '4')),  # 4. 企画の再生リスト
  (& $play 'p5' 'VF' '夜勤事件' (& $vid '5')),    # 5. 再生リストが見つからない
  (& $play 'p6' 'VD' '夜勤事件' (& $vid '6')),    # 6. APIエラー
  (& $play 'p7' 'VA' '夜勤事件' (& $vid '7'))     # 8. p1 と同じ候補が出る
)
$sitePlaylists = @(
  [pscustomobject]@{ id = 'reg-e1'; title = '⚾ホロライブ甲子園⚾'; streamer = 'VE'; game = 'パワフルプロ野球'; playlistId = 'PLREGE1' },
  [pscustomobject]@{ id = 'reg-c1'; title = '夜勤事件まとめ'; streamer = 'VC'; game = '夜勤事件'; playlistId = 'PLREGC1' }   # 3. 同じVTuberの別ゲームの登録済み再生リスト
)
$up = { param($v, $t, $d = '2026-09-20T10:00:00Z') [pscustomobject]@{ videoId = $v; title = $t; description = ''; publishedAt = $d } }
$secret = 'SECRETKEY_SHOULD_NOT_APPEAR_123'
$mock = @{ calls = @{} }
$api = {
  param($kind, $arg)
  $c = [string]$arg
  if ($arg -is [hashtable]) { if ($arg.ContainsKey('playlistId')) { $c = [string]$arg.playlistId } else { $c = [string]$arg.channelId } }
  $key = $kind + ':' + $c
  if (-not $mock.calls.ContainsKey($key)) { $mock.calls[$key] = 0 }; $mock.calls[$key]++
  if ($kind -eq 'channelIdForHandle') { if ($arg -eq '@vb_handle') { return 'UC' + ('b' * 22) }; return $null }
  if ($c -eq ('UC' + ('d' * 22))) { throw "403 Forbidden https://www.googleapis.com/youtube/v3/channels?part=x&key=$secret" }
  if ($kind -eq 'uploads') {
    switch -Regex ($c) {
      'a{22}$' { return @((& $up 'u1aaaaaaaaa' '【夜勤事件】続きをやる'), (& $up (& $vid '1') '【夜勤事件】最初')) }
      'b{22}$' { return @((& $up 'u2bbbbbbbbb' '【夜勤事件】2周目 #2')) }
      'c{22}$' { return @((& $up 'u3ccccccccc' '【夜勤事件】別のゲーム')) }
      'e{22}$' { return @((& $up 'u4eeeeeeeee' '【パワプロ】ホロライブ甲子園 練習')) }
      default { return @((& $up 'u5fffffffff' '【雑談】おしゃべり')) }
    }
  }
  if ($kind -eq 'channelPlaylists') {
    switch -Regex ($c) {
      'a{22}$' { return @([pscustomobject]@{ id = 'PLA1'; title = '夜勤事件 まとめ'; count = 3 }) }
      'b{22}$' { return @([pscustomobject]@{ id = 'PLB1'; title = '【夜勤事件】2周目'; count = 2 }) }
      'c{22}$' { return @([pscustomobject]@{ id = 'PLC1'; title = '夜勤事件'; count = 5 }, [pscustomobject]@{ id = 'PLREGC1'; title = '雑談まとめ'; count = 9 }) }
      'e{22}$' { return @([pscustomobject]@{ id = 'PLE2'; title = 'ホロライブ甲子園 パワフルプロ野球'; count = 8 }, [pscustomobject]@{ id = 'PLREGE1'; title = '⚾ホロライブ甲子園⚾'; count = 45 }) }
      default { return @() }
    }
  }
  if ($kind -eq 'playlistVideos') {
    switch ($c) {
      'PLA1' { return @((& $vid '1'), 'u1aaaaaaaaa') }
      'PLB1' { return @('u2bbbbbbbbb') }
      'PLC1' { return @('u3ccccccccc') }
      'PLE2' { return @((& $vid '4')) }
      'PLREGE1' { return @((& $vid '4')) }
      'PLREGC1' { return @('zzzzzzzzzzz') }
      default { throw "unknown playlist $arg" }
    }
  }
  throw "unknown kind $kind"
}
$standaloneIds = New-Object System.Collections.Generic.HashSet[string]
foreach ($p in $plays) { [void]$standaloneIds.Add($p.videos[0].url.Substring($p.videos[0].url.Length - 11)) }
$collected = Invoke-StandaloneFollowupCollect $plays $streamers $sitePlaylists $games $api 200 $secret
$ctx = [pscustomobject]@{ games = $games; index = (New-StandaloneGameIndex $games @($streamers | ForEach-Object { $_.name })); sitePlaylists = $sitePlaylists
  eventPlaylistIds = @{ 'PLREGE1' = 'ホロライブ甲子園' }; eventNames = @('ホロライブ甲子園', 'にじさんじ甲子園'); standaloneVideoIds = $standaloneIds; collected = $collected }
$results = Get-StandaloneFollowupReport $plays $ctx
$byId = @{}; foreach ($res in $results) { $byId[$res.id] = $res }
$has = { param($r, $pattern) @($r.reasons | Where-Object { $_ -match $pattern }).Count -gt 0 }

# 1. 既存の動画が専用再生リストに入っている
Check '1. 既存の動画がチャンネルのゲーム名入り再生リストに入っている → STRONG(自動移行はしない旨の推奨アクション)' `
  ($byId.p1.rank -eq 'STRONG' -and (& $has $byId.p1 '^\[B/STRONG\].*夜勤事件 まとめ') -and $byId.p1.action -match '確認待ち' -and @($byId.p1.playlistCandidates | Where-Object { $_.playlistId -eq 'PLA1' -and $_.videoInPlaylist -eq $true }).Count -eq 1) ($byId.p1 | ConvertTo-Json -Depth 4)
Check '1b. 同じゲームの別の動画(【】一致)も新規動画候補に出し、既存の動画そのものは候補にしない' `
  ((@($byId.p1.newVideoCandidates | ForEach-Object { $_.videoId }) -join ',') -eq 'u1aaaaaaaaa')
# 2. 同じゲームだが別の実況
Check '2. 同じゲームの再生リストに既存の動画が無い → その根拠は WEAK(別の実況の可能性)、全体は STRONG にならない' `
  ($byId.p2.rank -ne 'STRONG' -and (& $has $byId.p2 '^\[B/WEAK\].*別の実況') -and $byId.p2.rank -eq 'MEDIUM' -and (& $has $byId.p2 '^\[A/MEDIUM\].*同じシリーズかは未確定')) ($byId.p2.reasons -join ' / ')
Check '2b. ハンドル(@…)のチャンネルも特定できる' ($mock.calls.ContainsKey('channelIdForHandle:@vb_handle') -and $collected.streamers['VB'].status -eq 'ok')
# 3. 同じVTuberだが別ゲーム
Check '3. 同じVTuberの別ゲームの動画・再生リストは候補にしない → NONE' ($byId.p3.rank -eq 'NONE' -and @($byId.p3.newVideoCandidates).Count -eq 0 -and @($byId.p3.playlistCandidates).Count -eq 0) ($byId.p3 | ConvertTo-Json -Depth 4)
# 4. 企画の再生リスト
Check '4. 企画の再生リスト(登録済みの PLAYLIST_EVENTS・企画名入りのチャンネル再生リスト・企画名入りの動画)は WEAK まで(STRONG にしない)' `
  ($byId.p4.rank -eq 'WEAK' -and (& $has $byId.p4 '^\[C/WEAK\].*企画') -and (& $has $byId.p4 '^\[B/WEAK\].*企画') -and (& $has $byId.p4 '^\[A/WEAK\].*企画') -and -not (& $has $byId.p4 'STRONG')) ($byId.p4.reasons -join ' / ')
# 5. 再生リストが見つからない
Check '5. すべて確認でき、該当が無い → NONE(未確認なし)' ($byId.p5.rank -eq 'NONE' -and @($byId.p5.unverified).Count -eq 0) ($byId.p5 | ConvertTo-Json -Depth 4)
# 6. APIエラー
$f6 = @($collected.failures | Where-Object { $_.target -match 'VD' })
Check '6. API エラーのVTuberは UNKNOWN(「候補なし」にしない)。失敗した対象と理由を記録し、キーは伏せる' `
  ($byId.p6.rank -eq 'UNKNOWN' -and $f6.Count -eq 2 -and @($f6 | Where-Object { $_.reason -match '403' -and $_.reason -match 'key=\*\*\*' -and $_.reason -notmatch [regex]::Escape($secret) }).Count -eq 2 -and @($byId.p6.unverified).Count -gt 0) (($collected.failures | ConvertTo-Json -Depth 3))
# 8. 同じ候補の重複
Check '8. 同じ候補(動画・再生リスト)が複数の単発実況に出たら両方に記録する' `
  (@($byId.p1.sharedWith | Where-Object { $_.candidate -eq 'playlist:PLA1' -and $_.with -contains 'p7' }).Count -eq 1 -and @($byId.p7.sharedWith | Where-Object { $_.candidate -eq 'video:u1aaaaaaaaa' -and $_.with -contains 'p1' }).Count -eq 1 -and (& $has $byId.p7 '^\[共通\]'))
Check '8b. 同じ再生リスト・チャンネルは1回だけ取得する(不要なリクエストをしない)' (@($mock.calls.Values | Where-Object { $_ -gt 1 }).Count -eq 0) (($mock.calls.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', ')
Check '8c. 別の単発実況として登録済みの動画は「新規動画候補」にしない' (-not @($byId.p7.newVideoCandidates | Where-Object { $_.videoId -eq (& $vid '1') }).Count)
# 9. データ0件
$empty = Get-StandaloneFollowupReport @() $ctx
$mock.calls = @{}
$c0 = Invoke-StandaloneFollowupCollect @() $streamers $sitePlaylists $games $api 200 $secret
Check '9. 単発実況が0件でもエラーにならず、API も呼ばない' (@($empty).Count -eq 0 -and $mock.calls.Count -eq 0 -and $c0.failures.Count -eq 0)
# オフライン(API を使わない)
$off = Get-StandaloneFollowupReport $plays ([pscustomobject]@{ games = $games; index = $ctx.index; sitePlaylists = $sitePlaylists; eventPlaylistIds = $ctx.eventPlaylistIds; eventNames = $ctx.eventNames; standaloneVideoIds = $standaloneIds; collected = $null })
Check '7a. API を使わないときは NONE にせず UNKNOWN(登録済みデータだけで分かる企画の重複は WEAK)' `
  (@($off | Where-Object { $_.rank -eq 'NONE' }).Count -eq 0 -and @($off | Where-Object { $_.id -ne 'p4' -and $_.rank -ne 'UNKNOWN' }).Count -eq 0 -and @($off | Where-Object { $_.id -eq 'p4' })[0].rank -eq 'WEAK')
# 補助関数
Check 'x1. 動画IDは watch?v= / youtu.be / live の形式から取り出す(推測しない)' `
  ((Get-FollowupVideoId 'https://www.youtube.com/watch?v=Ac-DypNuXyc') -eq 'Ac-DypNuXyc' -and (Get-FollowupVideoId 'https://youtu.be/Ac-DypNuXyc') -eq 'Ac-DypNuXyc' -and (Get-FollowupVideoId 'https://www.youtube.com/live/Ac-DypNuXyc') -eq 'Ac-DypNuXyc' -and $null -eq (Get-FollowupVideoId 'https://www.youtube.com/playlist?list=PLx') -and $null -eq (Get-FollowupVideoId 'https://video.invalid/watch?v=Ac-DypNuXyc'))
Check 'x2. キーを伏せる(値そのもの・URL の key= のどちらも)' ((Protect-FollowupSecret "a $secret b&key=OTHER123 c" $secret) -eq 'a *** b&key=*** c')

# ---- 要確認の印(共演・他事務所・企画の疑い) ----
$collabStreamers = @(
  [pscustomobject]@{ name = '月ノ美兎'; group = 'にじさんじ 1期生' }, [pscustomobject]@{ name = '壱百満天原サロメ'; group = 'にじさんじ 2022年' },
  [pscustomobject]@{ name = 'アンジュ・カトリーナ'; group = 'にじさんじ 2018年' }, [pscustomobject]@{ name = '水宮枢'; group = 'ホロライブ FLOW GLOW' },
  [pscustomobject]@{ name = '綺々羅々ヴィヴィ'; group = 'ホロライブ FLOW GLOW' }, [pscustomobject]@{ name = 'える'; group = 'にじさんじ 2018年' },
  [pscustomobject]@{ name = 'ジョー・力一'; group = 'にじさんじ 2019年' }, [pscustomobject]@{ name = 'Ver Vermillion'; group = 'にじさんじ EN' },
  [pscustomobject]@{ name = 'Gigi Murin'; group = 'ホロライブ EN' }, [pscustomobject]@{ name = '共演相手'; group = 'にじさんじ 2026年' }
)
$ci = New-FollowupCollabIndex $collabStreamers
$fc = { param($text, $self) @(Find-FollowupCollab @($text) $ci $self) }
Check 'c1. 共演: 名前の一部(【サロメ楓アンジュ美兎】)・フルネーム(#水宮枢)・英字の名前(with Gigi)を本人以外のVTuberとして検出' `
  ((& $fc '【めっちゃカメレオン】初見の大人気かくれんぼゲーム【サロメ楓アンジュ美兎】' '月ノ美兎').Count -eq 2 -and (& $fc '【 みつめ 】怖がりな二人で異変を探せ！？【#綺々羅々ヴィヴィ #水宮枢 】' '綺々羅々ヴィヴィ').Count -eq 1 -and (& $fc 'A way out with Gigi!' 'Ver Vermillion').Count -eq 1) `
  ((& $fc '【サロメ楓アンジュ美兎】' '月ノ美兎') -join ',')
Check 'c2. 本人の名前・本人の事務所のタグだけなら共演にしない' ((& $fc '【夜勤事件】怖い【#綺々羅々ヴィヴィ / ホロライブ / FLOWGLOW】' '綺々羅々ヴィヴィ').Count -eq 0)
Check 'c3. 本人以外の事務所名(にじさんじのVTuberのタイトルに「ホロライブ」「hololive」)を検出' `
  ((& $fc '【APEX】ホロライブの皆さんと' '月ノ美兎') -contains '本人以外の事務所「ホロライブ」' -and (& $fc 'collab with #hololive' '月ノ美兎') -contains '本人以外の事務所「ホロライブ」')
Check 'c4. 誤検出しない: 2文字のかなの名前(える ≠ エルデンリング)・かなの部分一致(ジョー ≠ ジョーカー)・英字3文字(Ver ≠ ver.1.22)' `
  ((& $fc 'エルデンリング' '月ノ美兎').Count -eq 0 -and (& $fc 'ドラゴンクエストジョーカー' '月ノ美兎').Count -eq 0 -and (& $fc 'NieR Replicant ver.1.22474487139' '月ノ美兎').Count -eq 0)
Check 'c5. 企画名・企画を疑わせる語も要確認の印にする(どこで見つかったかを付ける)' `
  (@(Get-FollowupReviewFlags '単発実況' @('【パワプロ】ホロライブ甲子園 練習') $ci @('ホロライブ甲子園') '月ノ美兎') -contains '単発実況: 企画名「ホロライブ甲子園」')
# STRONG の候補でも、要確認の印があれば MEDIUM(人の確認待ち)。印が無ければ STRONG のまま(既存の判定と整合)
$ctxC = [pscustomobject]@{ games = $ctx.games; index = $ctx.index; sitePlaylists = $ctx.sitePlaylists; eventPlaylistIds = $ctx.eventPlaylistIds; eventNames = $ctx.eventNames
  standaloneVideoIds = $ctx.standaloneVideoIds; collected = $ctx.collected; collabIndex = $ci }
$p1c = & $play 'p1' 'VA' '夜勤事件' (& $vid '1'); $p1c.videos[0].title = '【夜勤事件】共演相手さんと遊ぶ'
$rc = Get-StandaloneFollowup $p1c $ctxC
$rn = Get-StandaloneFollowup $plays[0] $ctxC
Check 'c6. 共演の疑いがある単発実況は STRONG にせず MEDIUM。判定根拠(reviewFlags・[要確認])を残す' `
  ($rc.rank -eq 'MEDIUM' -and @($rc.reviewFlags | Where-Object { $_ -match '共演相手' }).Count -eq 1 -and (& $has $rc '^\[要確認/MEDIUM\]') -and $rc.action -match '^要確認' -and @($rc.playlistCandidates | Where-Object { $_.playlistId -eq 'PLA1' }).Count -eq 1) `
  ($rc | ConvertTo-Json -Depth 4)
Check 'c7. 要確認の印が無ければ従来どおり STRONG(印でランクを上げることはない)' ($rn.rank -eq 'STRONG' -and @($rn.reviewFlags).Count -eq 0)

# ---- 実行スクリプト(本番データを読み込む。データは変更しない) ----
$runner = Join-Path $scriptDir "report-standalone-followups.ps1"
$dataFiles = @('data-standalone.js', 'data-playlists.js', 'data-core.js', 'data-home.js', 'data-series.js', 'sitemap.xml', 'robots.txt')
$hash = { $dataFiles | ForEach-Object { (Get-FileHash (Join-Path $scriptDir $_) -Algorithm SHA256).Hash } }
$before = & $hash
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("followups-test-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
  # 7. APIキー未設定
  $null = & $runner -OutDir (Join-Path $tmp 'nokey') -CacheFile (Join-Path $tmp 'nokey-cache.json') -ApiKey '' 6>&1 2>&1
  $j = Get-Content (Join-Path $tmp 'nokey\standalone-followups.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  Check "7. APIキー未設定: エラーにせずオフラインで報告し、全件 UNKNOWN($($j.total)件・API $($j.apiUnits) ユニット)" `
    ($j.mode -match 'APIキー未設定' -and $j.apiUnits -eq 0 -and $j.total -eq 16 -and @($j.results | Where-Object { $_.rank -ne 'UNKNOWN' }).Count -eq 0 -and (Test-Path (Join-Path $tmp 'nokey\standalone-followups.md')))
  $jraw = Get-Content (Join-Path $tmp 'nokey\standalone-followups.json') -Raw -Encoding UTF8
  Check '7b. 取得できなかった対象が0件のとき、JSON の failures は空の配列 [](件数を誤って数えない)' ($jraw -match '"failures":\s*\[\s*\]')
  # 上書き防止: 7. のレポートがある出力先には書かない(MaxUnits 0 なので、万一進んでも通信はしない)。キャッシュは触らない
  $owDir = Join-Path $tmp 'nokey'; $owJson = Join-Path $owDir 'standalone-followups.json'
  $owCache = Join-Path $tmp 'ow-cache.json'; [IO.File]::WriteAllText($owCache, '{"version":1,"entries":{}}', (New-Object System.Text.UTF8Encoding($false)))
  $h1 = (Get-FileHash $owJson).Hash; $t1 = (Get-Item $owJson).LastWriteTimeUtc; $hc = (Get-FileHash $owCache).Hash
  $prevPref = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  try { $owOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $runner -OutDir $owDir -CacheFile $owCache -ApiKey $secret -MaxUnits 0 2>&1 | Out-String; $owCode = $LASTEXITCODE } finally { $ErrorActionPreference = $prevPref }
  Check 'o1. 出力先に前回のレポートがあると、上書きせずに止まる(別の -OutDir か -Overwrite を案内)' ($owCode -ne 0 -and (Get-FileHash $owJson).Hash -eq $h1 -and $owOut -match 'OutDir' -and $owOut -match 'Overwrite') $owOut
  Check 'o2. 止まったときもキャッシュは削除・変更しない。エラー文に APIキーを出さない' ((Test-Path $owCache) -and (Get-FileHash $owCache).Hash -eq $hc -and -not $owOut.Contains($secret))
  Start-Sleep -Milliseconds 1100
  $null = & $runner -OutDir $owDir -CacheFile $owCache -ApiKey '' -Overwrite 6>&1 2>&1
  Check 'o3. -Overwrite を付けたときだけ上書きする' ((Get-Item $owJson).LastWriteTimeUtc -gt $t1)
  $prevPref = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  try { $null = & powershell -NoProfile -ExecutionPolicy Bypass -File $runner -OutDir $owDir -Offline 2>&1; $owCode2 = $LASTEXITCODE } finally { $ErrorActionPreference = $prevPref }
  Check 'o4. -Offline でも既存のレポートは上書きしない' ($owCode2 -ne 0)
  # 利用上限: 偽のキーで MaxUnits 0 → 通信せずに全件「取得していない」、キーはレポートに出ない
  $null = & $runner -OutDir (Join-Path $tmp 'budget') -CacheFile (Join-Path $tmp 'budget-cache.json') -ApiKey $secret -MaxUnits 0 6>&1 2>&1
  $jt = Get-Content (Join-Path $tmp 'budget\standalone-followups.json') -Raw -Encoding UTF8
  $mt = Get-Content (Join-Path $tmp 'budget\standalone-followups.md') -Raw -Encoding UTF8
  $jb = $jt | ConvertFrom-Json
  Check '6b. API の利用上限を超える取得はせず、対象と理由を記録して UNKNOWN。レポートにキーは出ない' `
    ($jb.apiUnits -eq 0 -and @($jb.failures).Count -gt 0 -and @($jb.failures | Where-Object { $_.reason -notmatch '利用上限' }).Count -eq 0 -and @($jb.results | Where-Object { $_.rank -eq 'NONE' }).Count -eq 0 -and -not $jt.Contains($secret) -and -not $mt.Contains($secret))
  # 保存先の制限
  $refused = 0
  foreach ($bad in @((Join-Path $scriptDir 'data'), (Join-Path $scriptDir 'public'), $scriptDir)) {
    # 別プロセスのエラー出力を例外にしない(PowerShell 5.1 は Stop のとき標準エラーを例外として扱うため)
    $prevPref = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try { $null = & powershell -NoProfile -ExecutionPolicy Bypass -File $runner -OutDir $bad -Offline 2>&1; $code = $LASTEXITCODE } finally { $ErrorActionPreference = $prevPref }
    if ($code -ne 0 -and -not (Test-Path (Join-Path $bad 'standalone-followups.json'))) { $refused++ }
  }
  Check '10a. data\・public\・リポジトリ直下には保存しない(reports\ か リポジトリ外だけ)' ($refused -eq 3)
} finally {
  Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
$after = & $hash
Check '10. 本番データ(単発実況16件を含む data-*.js・sitemap.xml・robots.txt)は変更しない' (($before -join ',') -eq ($after -join ','))

Write-Output ""
Write-Output "PASS: $script:pass  FAIL: $script:fail"
if ($script:fail -gt 0) { exit 1 } else { exit 0 }
