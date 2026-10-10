<#
.SYNOPSIS
  単発実況の移行候補レポートの API 効率化(キャッシュ・利用上限)のテスト。
  YouTube API は呼ばない(YouTube の応答を真似た固定データで置き換える)。本番データ・本番のキャッシュは使わない。
    .\test-standalone-followups-cache.ps1
#>
$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir "standalone-matching.ps1")
. (Join-Path $scriptDir "standalone-followups.ps1")

$script:pass = 0; $script:fail = 0
function Check([string]$name, [bool]$ok, [string]$detail = "") {
  if ($ok) { $script:pass++; Write-Output "  [PASS] $name" } else { $script:fail++; Write-Output "  [FAIL] $name"; if ($detail) { Write-Output "         $detail" } }
}
Write-Output "=== 単発実況 移行候補レポート API 効率化(キャッシュ・利用上限) テスト ==="

# ---- YouTube の応答を真似る固定データ ----
$cidA = 'UC' + ('a' * 22); $cidB = 'UC' + ('b' * 22)
$secret = 'SECRETKEY_SHOULD_NOT_APPEAR_456'
function New-Fake {
  $upA = @([pscustomobject]@{ videoId = 'u1aaaaaaaaa'; title = '【夜勤事件】続きをやる'; at = '2026-10-05T10:00:00Z' })
  for ($i = 0; $i -lt 120; $i++) { $upA += [pscustomobject]@{ videoId = ('fa' + $i.ToString('000000000')); title = "【雑談】おしゃべり #$i"; at = '2026-09-01T10:00:00Z' } }
  $upA[60] = [pscustomobject]@{ videoId = 'v1111111111'; title = '【夜勤事件】最初'; at = '2026-09-10T10:00:00Z' }
  $upA[110] = [pscustomobject]@{ videoId = 'v2222222222'; title = '【8番出口】クリア'; at = '2026-08-01T10:00:00Z' }
  $upB = @([pscustomobject]@{ videoId = 'v3333333333'; title = '【夜勤事件】やる'; at = '2026-09-20T10:00:00Z' })
  for ($i = 0; $i -lt 9; $i++) { $upB += [pscustomobject]@{ videoId = ('fb' + $i.ToString('000000000')); title = "【歌枠】$i"; at = '2026-08-01T10:00:00Z' } }
  $fill = @(); for ($i = 0; $i -lt 30; $i++) { $fill += ('fp' + $i.ToString('000000000')) }
  return @{
    handles = @{ '@vb_handle' = $cidB }
    uploadsId = @{ $cidA = 'UU' + ('a' * 22); $cidB = 'UU' + ('b' * 22) }
    uploads = @{ ('UU' + ('a' * 22)) = $upA; ('UU' + ('b' * 22)) = $upB }
    playlists = @{
      $cidA = @(@{ id = 'PLA1'; title = '夜勤事件 まとめ'; items = @('v1111111111', 'u1aaaaaaaaa') }, @{ id = 'PLA2'; title = '雑談'; items = $fill }, @{ id = 'PLA3'; title = '夜勤事件 から'; items = @() })
      $cidB = @(@{ id = 'PLB1'; title = '8番出口'; items = @('v3333333333', 'fb000000000') })
    }
    fail = @{}; calls = @{}; total = 0
  }
}
$script:fake = New-Fake
$httpGet = {
  param($endpoint, $query)
  $f = $script:fake
  $f.total++; $k = "$endpoint?$query"; if (-not $f.calls.ContainsKey($k)) { $f.calls[$k] = 0 }; $f.calls[$k]++
  $q = @{}; foreach ($kv in $query.Split('&')) { $p = $kv.Split('=', 2); $q[$p[0]] = [uri]::UnescapeDataString($p[1]) }
  foreach ($bad in $f.fail.Keys) { if ($query.Contains($bad)) { throw "500 Internal Error https://www.googleapis.com/youtube/v3/$endpoint?$query&key=$secret" } }
  $page = { param($all) $off = 0; if ($q.ContainsKey('pageToken')) { $off = [int]$q.pageToken }; $items = @($all | Select-Object -Skip $off -First 50); $next = $null; if ($off + 50 -lt @($all).Count) { $next = [string]($off + 50) }; return @{ items = $items; next = $next } }
  if ($endpoint -eq 'channels') {
    if ($q.ContainsKey('forHandle')) { if ($f.handles.ContainsKey($q.forHandle)) { return [pscustomobject]@{ items = @([pscustomobject]@{ id = $f.handles[$q.forHandle] }) } }; return [pscustomobject]@{ items = @() } }
    return [pscustomobject]@{ items = @([pscustomobject]@{ contentDetails = [pscustomobject]@{ relatedPlaylists = [pscustomobject]@{ uploads = $f.uploadsId[$q.id] } } }) }
  }
  if ($endpoint -eq 'playlists') {
    $pg = & $page @($f.playlists[$q.channelId])
    return [pscustomobject]@{ nextPageToken = $pg.next; items = @($pg.items | ForEach-Object { [pscustomobject]@{ id = $_.id; snippet = [pscustomobject]@{ title = $_.title }; contentDetails = [pscustomobject]@{ itemCount = @($_.items).Count } } }) }
  }
  if ($endpoint -eq 'playlistItems') {
    $plId = $q.playlistId
    if ($f.uploads.ContainsKey($plId)) {
      $pg = & $page @($f.uploads[$plId])
      return [pscustomobject]@{ nextPageToken = $pg.next; items = @($pg.items | ForEach-Object { [pscustomobject]@{ snippet = [pscustomobject]@{ title = $_.title; description = ''; publishedAt = $_.at }; contentDetails = [pscustomobject]@{ videoId = $_.videoId; videoPublishedAt = $_.at } } }) }
    }
    $pl = $null; foreach ($cid in $f.playlists.Keys) { foreach ($x in $f.playlists[$cid]) { if ($x.id -eq $plId) { $pl = $x } } }
    if (-not $pl) { throw "404 playlist not found" }
    $pg = & $page @($pl.items)
    return [pscustomobject]@{ nextPageToken = $pg.next; items = @($pg.items | ForEach-Object { [pscustomobject]@{ contentDetails = [pscustomobject]@{ videoId = $_ } } }) }
  }
  throw "unknown endpoint $endpoint"
}

$games = @([pscustomobject]@{ name = '夜勤事件'; aliases = @('夜勤事件') }, [pscustomobject]@{ name = '8番出口'; aliases = @('8番出口') })
$streamers = @([pscustomobject]@{ name = 'VA'; youtube = "https://www.youtube.com/channel/$cidA" }, [pscustomobject]@{ name = 'VB'; youtube = 'https://www.youtube.com/@vb_handle' })
$mk = { param($id, $s, $g, $v, $d) [pscustomobject]@{ id = $id; streamer = $s; game = $g; format = 'single'; videos = @([pscustomobject]@{ url = "https://www.youtube.com/watch?v=$v"; title = 't'; publishedDate = $d }) } }
$plays = @((& $mk 'p1' 'VA' '夜勤事件' 'v1111111111' '2026-09-10'), (& $mk 'p2' 'VA' '8番出口' 'v2222222222' '2026-08-01'), (& $mk 'p3' 'VB' '夜勤事件' 'v3333333333' '2026-09-20'))
$sitePlaylists = @([pscustomobject]@{ id = 'reg-b1'; title = '8番出口'; streamer = 'VB'; game = '8番出口'; playlistId = 'PLB1' })
$sids = New-Object System.Collections.Generic.HashSet[string]; foreach ($p in $plays) { [void]$sids.Add($p.videos[0].url.Substring($p.videos[0].url.Length - 11)) }
$index = New-StandaloneGameIndex $games @('VA', 'VB')
$t0 = [datetime]::Parse('2026-10-09T00:00:00Z').ToUniversalTime()

# 1回分の実行(キャッシュ → 取得 → 判定)。結果・クライアントを返す
function Invoke-Run($cache, [datetime]$now, [int]$maxUnits = 100) {
  $client = New-FollowupApiClient $httpGet $maxUnits $cache $now $secret
  $api = New-FollowupCachedApi $client
  $col = Invoke-StandaloneFollowupCollect $plays $streamers $sitePlaylists $games $api 200 $secret
  $ctx = [pscustomobject]@{ games = $games; index = $index; sitePlaylists = $sitePlaylists; eventPlaylistIds = @{}; eventNames = @('ホロライブ甲子園'); standaloneVideoIds = $sids; collected = $col }
  $res = Get-StandaloneFollowupReport $plays $ctx
  return @{ client = $client; collected = $col; results = $res; key = (($res | ForEach-Object { $_.id + '=' + $_.rank + ':' + (@($_.reasons) -join '|') }) -join ' ;; ') }
}
$rankOf = { param($run, $id) @($run.results | Where-Object { $_.id -eq $id })[0].rank }
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("followups-cache-test-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Path $tmp | Out-Null
$cachePath = Join-Path $tmp 'cache.json'
try {
  # ---- 基準: キャッシュなし(#50 と同じ取り方) ----
  $script:fake = New-Fake
  $base = Invoke-Run $null $t0
  $u0 = $base.client.units
  Check "0. 基準(キャッシュなし): p1 STRONG / p2 NONE / p3 WEAK($u0 ユニット)" ((& $rankOf $base 'p1') -eq 'STRONG' -and (& $rankOf $base 'p2') -eq 'NONE' -and (& $rankOf $base 'p3') -eq 'WEAK') $base.key
  Check '0b. 同じチャンネルは2件の単発実況があっても1回だけ取得する(重複した要求なし)' (@($script:fake.calls.Values | Where-Object { $_ -gt 1 }).Count -eq 0) (($script:fake.calls.GetEnumerator() | Where-Object { $_.Value -gt 1 } | ForEach-Object { $_.Key }) -join ', ')
  Check '0c. 動画数0の再生リストは中身を取得しない' (-not @($script:fake.calls.Keys | Where-Object { $_ -match 'PLA3' }).Count -and $base.client.stats.skippedEmpty -ge 1)

  # ---- 1. 初回(キャッシュファイルなし) ----
  $script:fake = New-Fake
  $c1 = Read-FollowupCache $cachePath
  $r1 = Invoke-Run $c1 $t0
  Write-FollowupCache $r1.client.cache $cachePath $secret
  Check "1. 初回: 基準と同じ結果・同じユニット数($($r1.client.units))で、キャッシュを保存する" ($r1.key -eq $base.key -and $r1.client.units -eq $u0 -and (Test-Path $cachePath))
  $ctext = [IO.File]::ReadAllText($cachePath)
  Check '1b. キャッシュにキー・認証情報を保存しない' (-not $ctext.Contains($secret) -and $ctext -notmatch 'key=')

  # ---- 2. 同じ日の2回目(1時間後) / キャッシュ有効(11時間後) ----
  $script:fake = New-Fake
  $r2 = Invoke-Run (Read-FollowupCache $cachePath) $t0.AddHours(1)
  Check '2. 同じ日の2回目: API を使わず(0 ユニット)、結果は初回と同じ' ($r2.client.units -eq 0 -and $script:fake.total -eq 0 -and $r2.key -eq $base.key) "units=$($r2.client.units) $($r2.key)"
  $script:fake = New-Fake
  $r3 = Invoke-Run (Read-FollowupCache $cachePath) $t0.AddHours(11)
  Check '3. キャッシュ有効(11時間後): 0 ユニット・結果は同じ' ($r3.client.units -eq 0 -and $r3.key -eq $base.key)

  # ---- 4. 期限切れ(13時間後) ----
  $script:fake = New-Fake
  $r4 = Invoke-Run (Read-FollowupCache $cachePath) $t0.AddHours(13)
  Check "4. 期限切れ: 最近の動画は差分だけ・一覧は取り直し・中身は動画数一致で再利用($($r4.client.units) ユニット < 初回 $u0)、結果は同じ" `
    ($r4.key -eq $base.key -and $r4.client.units -eq 4 -and $r4.client.stats.incremental -eq 2 -and $r4.client.stats.reusedByCount -ge 2 -and $r4.client.stats.expired -ge 4) "units=$($r4.client.units) stats=$(($r4.client.stats.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ',')"
  Write-FollowupCache $r4.client.cache $cachePath $secret
  # 新しい動画が増え、専用再生リストにも入った(動画数が変わった)→ 中身を取り直し、新しい動画も候補に出る
  $script:fake = New-Fake
  $script:fake.uploads[('UU' + ('a' * 22))] = @([pscustomobject]@{ videoId = 'u9aaaaaaaaa'; title = '【夜勤事件】新作'; at = '2026-10-09T05:00:00Z' }) + @($script:fake.uploads[('UU' + ('a' * 22))])
  $script:fake.playlists[$cidA][0].items = @('v1111111111', 'u1aaaaaaaaa', 'u9aaaaaaaaa')
  $r4b = Invoke-Run (Read-FollowupCache $cachePath) $t0.AddHours(26)
  $p1b = @($r4b.results | Where-Object { $_.id -eq 'p1' })[0]
  $vids = @($p1b.newVideoCandidates | ForEach-Object { $_.videoId })
  Check '4b. 動画数が変わった再生リストは取り直し、差分で取った新しい動画も候補に出る(同じ動画IDは1回だけ)' `
    (@($script:fake.calls.Keys | Where-Object { $_ -match 'playlistId=PLA1' }).Count -eq 1 -and $vids -contains 'u9aaaaaaaaa' -and $vids -contains 'u1aaaaaaaaa' -and @($vids | Select-Object -Unique).Count -eq $vids.Count -and $p1b.rank -eq 'STRONG') ($vids -join ',')
  $script:fake = New-Fake
  $r4c = Invoke-Run (Read-FollowupCache $cachePath) $t0.AddDays(8)
  Check '4c. 再生リストの中身は7日を過ぎたら動画数が同じでも取り直す' ($r4c.client.stats.reusedByCount -eq 0 -and @($script:fake.calls.Keys | Where-Object { $_ -match 'playlistId=PLB1' }).Count -eq 1 -and $r4c.key -eq $base.key)

  # ---- 5. キャッシュ破損 ----
  [IO.File]::WriteAllText($cachePath, '{ "version": 1, "entries": { broken')
  $cb = Read-FollowupCache $cachePath
  $cbEntries = $cb.entries.Count; $cbWarnings = $cb.warnings.Count
  $script:fake = New-Fake
  $r5 = Invoke-Run $cb $t0
  Check '5. 壊れたキャッシュは使わず(理由を記録)、初回と同じく全部取り直して結果は同じ' ($cbWarnings -eq 1 -and $cbEntries -eq 0 -and $r5.client.units -eq $u0 -and $r5.key -eq $base.key) ("units=$($r5.client.units) entries=$($cb.entries.Count) warnings=$($cb.warnings.Count) sameKey=$($r5.key -eq $base.key) / " + ($cb.warnings -join ' / '))
  [IO.File]::WriteAllText($cachePath, '{ "version": 1, "entries": { "handle|@vb_handle": { "data": "UCx" }, "uploadsId|' + $cidA + '": { "fetchedAt": "2026-10-09T00:00:00.0000000Z", "data": "UU' + ('a' * 22) + '" } } }')
  $cp = Read-FollowupCache $cachePath
  Check '5b. 一部の項目だけ壊れていたら、その項目だけ使わない' ($cp.entries.Count -eq 1 -and $cp.warnings.Count -eq 1 -and $cp.entries.ContainsKey("uploadsId|$cidA"))
  [IO.File]::WriteAllText($cachePath, '{ "version": 99, "entries": {} }')
  Check '5c. 形式(version)が違うキャッシュは使わない' ((Read-FollowupCache $cachePath).warnings.Count -eq 1)
  Write-FollowupCache $r1.client.cache $cachePath $secret

  # ---- 7. API エラー(再試行しない・失敗はキャッシュしない) ----
  $script:fake = New-Fake
  $script:fake.fail["channelId=$cidA"] = $true
  $r7 = Invoke-Run $null $t0
  $f7 = $r7.collected.failures.ToArray()
  Check '7. API エラー: 失敗した対象と理由を記録(キーは伏せる)、その要求は1回だけ(再試行しない)、該当なしの単発実況は UNKNOWN' `
    ($f7.Count -eq 1 -and $f7[0].reason -match '500' -and -not $f7[0].reason.Contains($secret) -and @($script:fake.calls.GetEnumerator() | Where-Object { $_.Key -match "channelId=$cidA" -and $_.Value -ne 1 }).Count -eq 0 -and (& $rankOf $r7 'p2') -eq 'UNKNOWN') (($f7 | ConvertTo-Json -Depth 3))
  Check '7b. 失敗した取得はキャッシュに残さない(次の実行で取り直す)' (-not $r7.client.cache.entries.ContainsKey("channelPlaylists|$cidA"))
  Check '7c. 一部が失敗しても、確認できた根拠は残す(p1 は最近の動画から MEDIUM・未確認ありと記録)' ((& $rankOf $r7 'p1') -eq 'MEDIUM' -and @(@($r7.results | Where-Object { $_.id -eq 'p1' })[0].unverified).Count -gt 0)

  # ---- 8. API 利用上限 ----
  $script:fake = New-Fake
  $r8 = Invoke-Run $null $t0 3
  Check '8. 利用上限(3)に達したら、それ以上は要求せず(3 ユニット)、残りは「上限のため未取得」として UNKNOWN(NONE にしない)' `
    ($r8.client.units -eq 3 -and $script:fake.total -eq 3 -and $r8.client.budgetReached -and @($r8.collected.failures | Where-Object { $_.reason -match '利用上限' }).Count -gt 0 -and @($r8.results | Where-Object { $_.rank -eq 'NONE' }).Count -eq 0)
  Check '8b. 上限の8割に達したら知らせる' (@($r8.client.notices | Where-Object { $_ -match '8割' }).Count -eq 1)
  # 古いキャッシュだけで「候補なし」にしない: 期限切れのキャッシュがあっても、取り直せなければ UNKNOWN
  $script:fake = New-Fake
  $r8c = Invoke-Run (Read-FollowupCache $cachePath) $t0.AddHours(13) 0
  Check '8c. 期限切れのキャッシュしかなく取り直せないときは、古い値で NONE にせず UNKNOWN' ((& $rankOf $r8c 'p2') -eq 'UNKNOWN' -and $script:fake.total -eq 0 -and $r8c.client.units -eq 0)

  # ---- その他 ----
  $bad = @{ entries = @{ 'x' = @{ fetchedAt = (Get-Date).ToUniversalTime(); data = "a $secret b"; meta = $null } } }
  $threw = $false; try { Write-FollowupCache $bad (Join-Path $tmp 'leak.json') $secret } catch { $threw = $true }
  Check 'x1. キャッシュに秘密の値が紛れ込んでいたら保存しない' ($threw -and -not (Test-Path (Join-Path $tmp 'leak.json')))
  Check 'x2. キャッシュの書き込みは一時ファイル経由(途中で失敗しても壊れたファイルを残さない)' (-not (Test-Path ($cachePath + '.tmp')))
} finally {
  Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output ""
Write-Output "PASS: $script:pass  FAIL: $script:fail"
if ($script:fail -gt 0) { exit 1 } else { exit 0 }
