<#
.SYNOPSIS
  単発実況 → 再生リストの承認付き移行(standalone-migration-approval.ps1 / migrate-standalone.ps1)のテスト。
  一時フォルダに固定データを作って行う。YouTube API は呼ばない(固定の応答で置き換える)。リポジトリのデータは変更しない。
    .\test-standalone-migration-approval.ps1
  node が必要(データの読み込み・書き換え後の検証に使うため)。
#>
$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir 'standalone-matching.ps1')
. (Join-Path $scriptDir 'standalone-followups.ps1')
. (Join-Path $scriptDir 'standalone-migration-approval.ps1')

$script:pass = 0; $script:fail = 0
function Check([string]$name, [bool]$ok, [string]$detail = '') {
  if ($ok) { $script:pass++; Write-Output "  [PASS] $name" } else { $script:fail++; Write-Output "  [FAIL] $name"; if ($detail) { Write-Output "         $detail" } }
}
Write-Output '=== 単発実況 → 再生リスト 承認付き移行 テスト ==='

# リポジトリのデータが変わらないことを最後に確かめる
$repoHashes = @{}; foreach ($f in 'data-core.js', 'data-playlists.js', 'data-standalone.js') { $repoHashes[$f] = (Get-FileHash -LiteralPath (Join-Path $scriptDir $f) -Algorithm SHA256).Hash }

# ---- 固定データ(一時フォルダ) ----
$tmpRoot = Join-Path ([IO.Path]::GetTempPath()) ("vgame-migration-test-" + $PID)
if (Test-Path -LiteralPath $tmpRoot) { Remove-Item -LiteralPath $tmpRoot -Recurse -Force }
New-Item -ItemType Directory -Path $tmpRoot | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding($false)
function Write-Fixture([string]$dir, [string]$name, [string[]]$lines) { [IO.File]::WriteAllText((Join-Path $dir $name), (($lines -join "`r`n") + "`r`n"), $utf8) }
$ch = { param($c) 'UC' + ($c * 22) }
$v = { param($c) 'v' + ($c * 10) }   # 11文字の動画ID
function New-FixtureRoot([string]$name) {
  $d = Join-Path $tmpRoot $name
  New-Item -ItemType Directory -Path $d | Out-Null
  Write-Fixture $d 'data-core.js' @(
    'const STREAMERS = ['
    "  { name: `"VA`", youtube: `"https://www.youtube.com/channel/$(& $ch 'a')`" },"
    "  { name: `"VB`", youtube: `"https://www.youtube.com/channel/$(& $ch 'b')`" },"
    "  { name: `"VC`", youtube: `"https://www.youtube.com/channel/$(& $ch 'c')`" },"
    "  { name: `"VE`", youtube: `"https://www.youtube.com/channel/$(& $ch 'e')`" },"
    "  { name: `"共演相手`", group: `"にじさんじ 2026年`", youtube: `"https://www.youtube.com/channel/$(& $ch 'k')`" },"
    '];'
    'const GAMES = [ { name: "夜勤事件" }, { name: "8番出口" }, { name: "パワフルプロ野球" }, { name: "Unpacking" }, { name: "Stray" } ];'
    'const GAME_EVENTS = [ { id: "hololive-koshien", name: "ホロライブ甲子園" } ];'
    'const PLAYLIST_EVENTS = [ { playlist: "reg-e1", event: "hololive-koshien", game: "パワフルプロ野球" } ];'
  )
  Write-Fixture $d 'data-playlists.js' @(
    '/** テスト用 */'
    '// 再生リスト本体。'
    'const PLAYLISTS = ['
    '  {'
    '    id: "reg-c1",'
    '    title: "夜勤事件 { まとめ } [完結]",'
    '    streamer: "VC",'
    '    game: "夜勤事件",'
    '    genre: "horror",'
    '    playlistId: "PLREGC1xxxxxxxx",'
    '    videoCount: 3,'
    '    addedDate: "2026-01-01",'
    '  },'
    '  {'
    '    id: "reg-e1",'
    '    title: "⚾ホロライブ甲子園⚾",'
    '    streamer: "VE",'
    '    game: "パワフルプロ野球",'
    '    genre: "sports",'
    '    playlistId: "PLREGE1xxxxxxxx",'
    '    videoCount: 45,'
    '    addedDate: "2026-01-01",'
    '  },'
    '  {'
    '    id: "reg-b1",'
    '    title: "8番出口",'
    '    streamer: "VB",'
    '    game: "8番出口",'
    '    genre: "horror",'
    '    playlistId: "PLREGB1xxxxxxxx",'
    '    videoCount: 2,'
    '    addedDate: "2026-01-01",'
    '  },'
    '];'
    ''
    '// STANDALONE_PLAYS は data-standalone.js'
  )
  $sa = { param($id, $s, $g, $vids, $title = 't', $fmt = 'single')
    $out = @('  {', "    id: `"$id`",", "    title: `"$title`",", "    streamer: `"$s`",", "    game: `"$g`",", '    genre: "horror",', "    format: `"$fmt`",", '    videos: [')
    $out += @($vids | ForEach-Object { "      { title: `"【$g】$title`", url: `"https://www.youtube.com/watch?v=$_`", publishedDate: `"2026-09-01`" }," })
    $out += @('    ],', '    note: "専用再生リストなし { }",', '    addedDate: "2026-09-30"', '  },')
    return $out
  }
  $lines = @('/** テスト用 */', 'const STANDALONE_PLAYS = [', '  // 登録例', '  // {', '  //   id: "single-001",', '  // }')
  $lines += & $sa 's1' 'VA' '夜勤事件' @((& $v '1'))                         # 1. 承認 → 適用できる(new-playlist)
  $lines += & $sa 's2' 'VA' '8番出口' @((& $v '2'), (& $v '3')) 't' 'multi'  # 動画2本のうち1本しか移行先に無い
  $lines += & $sa 's3' 'VC' '夜勤事件' @((& $v '4'))                         # 登録済みの同じVTuber × ゲームの再生リストに入っている(existing-playlist)
  $lines += & $sa 's4' 'VE' 'パワフルプロ野球' @((& $v '5'))                 # 企画の再生リスト
  $lines += & $sa 's5' 'VB' 'Unpacking' @((& $v '6'))                        # 企画の疑いがある語(大会)
  $lines += & $sa 's6' 'VB' '夜勤事件' @((& $v '7'))                         # 移行先に他の単発実況の動画も入っている
  $lines += & $sa 's7' 'VA' 'Unpacking' @((& $v '8'))                        # 移行先が登録済みの再生リスト(new-playlist として二重登録しない)
  $lines += & $sa 's8' 'VC' '8番出口' @((& $v '9'))                          # 移行先が存在しない
  $lines += & $sa 's9' 'VA' 'Stray' @((& $v 'a'))                            # 所有チャンネルが違う
  $lines += & $sa 's10' 'VE' 'Unpacking' @((& $v 'b')) '共演相手さんと遊ぶ'     # 共演(本人以外のVTuber名)
  $lines += @('];')
  Write-Fixture $d 'data-standalone.js' $lines
  return $d
}

# ---- 固定の YouTube API(playlists / playlistItems)----
$liveData = @{
  'PLA1xxxxxxxxxxx' = @{ title = '夜勤事件 "完全版" \ まとめ'; channelId = (& $ch 'a'); videos = @((& $v '1'), 'vOTHERxxxxx') }
  'PLA2xxxxxxxxxxx' = @{ title = '8番出口'; channelId = (& $ch 'a'); videos = @((& $v '2')) }
  'PLREGC1xxxxxxxx' = @{ title = '夜勤事件 { まとめ } [完結]'; channelId = (& $ch 'c'); videos = @((& $v '4'), 'vREGxxxxxxx') }
  'PLE2xxxxxxxxxxx' = @{ title = 'ホロライブ甲子園 パワプロ'; channelId = (& $ch 'e'); videos = @((& $v '5')) }
  'PLB5xxxxxxxxxxx' = @{ title = 'Unpacking 大会'; channelId = (& $ch 'b'); videos = @((& $v '6')) }
  'PLB6xxxxxxxxxxx' = @{ title = '夜勤事件'; channelId = (& $ch 'b'); videos = @((& $v '7'), (& $v '1')) }
  'PLREGB1xxxxxxxx' = @{ title = '8番出口'; channelId = (& $ch 'b'); videos = @((& $v '8')) }
  'PLA9xxxxxxxxxxx' = @{ title = 'Stray'; channelId = (& $ch 'z'); videos = @((& $v 'a')) }
  'PLE10xxxxxxxxxx' = @{ title = 'Unpacking'; channelId = (& $ch 'e'); videos = @((& $v 'b')) }
}
$secret = 'SECRET_KEY_SHOULD_NOT_APPEAR_987'
$httpGet = {
  param($endpoint, $query)
  $plId = [regex]::Match($query, '(?:^|&)(?:id|playlistId)=([^&]+)').Groups[1].Value
  if ($plId -eq 'PLERRORxxxxxxxx') { throw "403 Forbidden https://www.googleapis.com/youtube/v3/playlists?id=$plId&key=$secret" }
  $d = $liveData[$plId]
  if ($endpoint -eq 'playlists') {
    if (-not $d) { return [pscustomobject]@{ items = @() } }
    return [pscustomobject]@{ items = @([pscustomobject]@{ id = $plId; snippet = [pscustomobject]@{ title = $d.title; channelId = $d.channelId }; contentDetails = [pscustomobject]@{ itemCount = @($d.videos).Count } }) }
  }
  if ($endpoint -eq 'playlistItems') {
    if (-not $d) { throw '404 playlistNotFound' }
    return [pscustomobject]@{ items = @($d.videos | ForEach-Object { [pscustomobject]@{ contentDetails = [pscustomobject]@{ videoId = $_ } } }); nextPageToken = $null }
  }
  throw "unexpected endpoint $endpoint"
}
$now = [datetime]'2026-10-09T12:00:00'
$newClient = { New-FollowupApiClient $httpGet 100 $null $now $secret }

# ---- レポート(report-standalone-followups.ps1 の JSON と同じ形)----
$pc = { param($plId, $title, $chId, $in = $true, $ev = $null) [pscustomobject]@{ playlistId = $plId; title = $title; channel = ''; channelId = $chId; count = 2; videoInPlaylist = $in; event = $ev } }
$res = { param($id, $s, $g, $rank, $pcs = @(), $dups = @()) [pscustomobject]@{ id = $id; streamer = $s; game = $g; rank = $rank; playlistCandidates = @($pcs); duplicateCandidates = @($dups); sharedWith = @() } }
$report = [pscustomobject]@{ generatedAt = '2026-10-09T11:00:00'; mode = 'API'; results = @(
    (& $res 's1' 'VA' '夜勤事件' 'STRONG' @((& $pc 'PLA1xxxxxxxxxxx' '夜勤事件 "完全版" \ まとめ' (& $ch 'a'))))
    (& $res 's2' 'VA' '8番出口' 'STRONG' @((& $pc 'PLA2xxxxxxxxxxx' '8番出口' (& $ch 'a'))))
    (& $res 's3' 'VC' '夜勤事件' 'STRONG' @() @([pscustomobject]@{ id = 'reg-c1'; playlistId = 'PLREGC1xxxxxxxx'; title = '夜勤事件 { まとめ } [完結]'; game = '夜勤事件'; sameGame = $true; event = $null; videoInPlaylist = $true }))
    (& $res 's4' 'VE' 'パワフルプロ野球' 'WEAK' @((& $pc 'PLE2xxxxxxxxxxx' 'ホロライブ甲子園 パワプロ' (& $ch 'e') $true 'ホロライブ甲子園')))
    (& $res 's5' 'VB' 'Unpacking' 'STRONG' @((& $pc 'PLB5xxxxxxxxxxx' 'Unpacking 大会' (& $ch 'b'))))
    (& $res 's6' 'VB' '夜勤事件' 'STRONG' @((& $pc 'PLB6xxxxxxxxxxx' '夜勤事件' (& $ch 'b'))))
    (& $res 's7' 'VA' 'Unpacking' 'STRONG' @((& $pc 'PLREGB1xxxxxxxx' '8番出口' (& $ch 'b'))))
    (& $res 's8' 'VC' '8番出口' 'STRONG' @((& $pc 'PLC8xxxxxxxxxxx' '8番出口' (& $ch 'c'))))
    (& $res 's9' 'VA' 'Stray' 'STRONG' @((& $pc 'PLA9xxxxxxxxxxx' 'Stray' (& $ch 'a'))))
    (& $res 's10' 'VE' 'Unpacking' 'MEDIUM' @((& $pc 'PLE10xxxxxxxxxx' 'Unpacking' (& $ch 'e'))))
    (& $res 's2' 'VA' '8番出口' 'WEAK' @((& $pc 'PLA2zzzzzzzzzzz' '8番出口 別の実況' (& $ch 'a') $false)))   # 既存の動画が入っていない = 候補にしない
  ) }

$hashOf = { param($root) $h = @{}; foreach ($f in 'data-core.js', 'data-playlists.js', 'data-standalone.js') { $h[$f] = (Get-FileHash -LiteralPath (Join-Path $root $f) -Algorithm SHA256).Hash }; return $h }
$sameHash = { param($a, $b) @('data-core.js', 'data-playlists.js', 'data-standalone.js' | Where-Object { $a[$_] -ne $b[$_] }).Count -eq 0 }
$stateOf = { param($root) $site = Read-MigrationSiteData $root; $st = Merge-MigrationCandidates (Read-MigrationState (Join-Path $root 'none.json')) (New-MigrationCandidates $report $site) $site $now $report.generatedAt; return @{ site = $site; state = $st } }
$candOf = { param($st, $sid) @($st.candidates | Where-Object { $_.standaloneId -eq $sid })[0] }
$applyOpts = { param($root, $live, $dry = $false, $failMid = $false) @{ root = $root; workDir = (Join-Path $root 'reports\standalone-migration'); now = $now; dryRun = $dry; live = $live; failAfterFirstWrite = $failMid } }

# ============================================================
$R1 = New-FixtureRoot 'r1'
$x = & $stateOf $R1; $site = $x.site; $state = $x.state
$client = & $newClient
$h0 = & $hashOf $R1

# ---- 候補の作成・表示項目 ----
Check '0a. 候補はレポートの移行先ごとに作られ、既存の動画が入っていない再生リスト(別の実況)は候補にしない' (@($state.candidates).Count -eq 10 -and -not @($state.candidates | Where-Object { $_.playlistId -eq 'PLA2zzzzzzzzzzz' }).Count) (@($state.candidates | ForEach-Object { $_.key }) -join ', ')
Check '0b. 新しい候補はすべて pending' (@($state.candidates | Where-Object { $_.status -ne 'pending' }).Count -eq 0)
$c1 = & $candOf $state 's1'
Check '0c. 候補に VTuber・ゲーム・現在の単発実況・移行先・再生リストID・動画数・重複・可否が入る' ($c1.streamer -eq 'VA' -and $c1.game -eq '夜勤事件' -and $c1.standalone.format -eq 'single' -and @($c1.standalone.videoIds)[0] -eq (& $v '1') -and $c1.playlistId -eq 'PLA1xxxxxxxxxxx' -and $c1.newPlaylistId -eq 'sa-s1' -and $null -ne $c1.target.count -and @($c1.duplicates).Count -ge 2 -and $c1.eligible -eq $true)

# ---- 1. 未承認(pending)は適用されない ----
$r = Invoke-MigrationApply $c1 $site (& $applyOpts $R1 (Get-MigrationLiveTarget $client 'PLA1xxxxxxxxxxx'))
Check '1. 未承認(pending)の候補は適用されない(データ不変)' (-not $r.ok -and -not $r.applied -and (& $sameHash $h0 (& $hashOf $R1))) $r.message

# ---- 3. 却下は適用されない ----
[void](Set-MigrationDecision $state $c1.key 'reject' $now 'test')
$r = Invoke-MigrationApply $c1 $site (& $applyOpts $R1 (Get-MigrationLiveTarget $client 'PLA1xxxxxxxxxxx'))
Check '3. 却下(rejected)の候補は適用されない(データ不変)' ($c1.status -eq 'rejected' -and -not $r.applied -and (& $sameHash $h0 (& $hashOf $R1))) $r.message

# ---- 2. 承認済みだけが適用できる(dry-run → 適用)----
[void](Set-MigrationDecision $state $c1.key 'approve' $now 'test')
Check '2a. 承認すると approved・承認時の fingerprint を記録(データは不変)' ($c1.status -eq 'approved' -and $c1.approvedFingerprint -eq $c1.fingerprint -and (& $sameHash $h0 (& $hashOf $R1)))
$live1 = Get-MigrationLiveTarget $client 'PLA1xxxxxxxxxxx'
$r = Invoke-MigrationApply $c1 $site (& $applyOpts $R1 $live1 $true)
Check '2b. dry-run は適用できると判定するがデータを変えない' ($r.ok -and -not $r.applied -and (& $sameHash $h0 (& $hashOf $R1))) $r.message
$plBefore = Read-MigrationText (Join-Path $R1 'data-playlists.js'); $saBefore = Read-MigrationText (Join-Path $R1 'data-standalone.js')
$r = Invoke-MigrationApply $c1 $site (& $applyOpts $R1 $live1)
$after = Read-MigrationSiteData $R1
$added = @($after.playlists | Where-Object { $_.id -eq 'sa-s1' })
Check '2c. 承認済みの候補は適用される(単発実況 s1 を削除・再生リスト sa-s1 を追加)' ($r.applied -and -not @($after.standalone | Where-Object { $_.id -eq 's1' }).Count -and $added.Count -eq 1 -and $added[0].playlistId -eq 'PLA1xxxxxxxxxxx' -and $added[0].streamer -eq 'VA' -and $added[0].game -eq '夜勤事件') $r.message
Check '2d. 再生リスト名の " と \ を正しく書く(読み直して同じ文字列)' ($added.Count -and $added[0].title -eq '夜勤事件 "完全版" \ まとめ') ($added | ForEach-Object { $_.title })
$plAfter = Read-MigrationText (Join-Path $R1 'data-playlists.js'); $saAfter = Read-MigrationText (Join-Path $R1 'data-standalone.js')
Check '2e. 変更は最小限(再生リストは末尾に1件挿入・単発実況は1件の行だけ削除。改行コード CRLF を保つ)' ($plAfter.StartsWith($plBefore.Substring(0, $plBefore.IndexOf('];'))) -and $plAfter.EndsWith($plBefore.Substring($plBefore.IndexOf('];'))) -and $saAfter.Length -lt $saBefore.Length -and -not ($plAfter -replace "`r`n", '').Contains("`n") -and -not ($saAfter -replace "`r`n", '').Contains("`n") -and $saAfter.Contains('//   id: "single-001",'))
Check '2f. バックアップに元のファイルがある(ハッシュ一致)' ($r.backupDir -and (Get-FileHash -LiteralPath (Join-Path $r.backupDir 'data-playlists.js') -Algorithm SHA256).Hash -eq $h0['data-playlists.js'] -and (Get-FileHash -LiteralPath (Join-Path $r.backupDir 'data-standalone.js') -Algorithm SHA256).Hash -eq $h0['data-standalone.js'])
Check '2g. data-core.js は変えない' ((& $hashOf $R1)['data-core.js'] -eq $h0['data-core.js'])
Set-MigrationProp $c1 'status' 'applied'

# ---- 8. 二重実行の防止 ----
$h1 = & $hashOf $R1
$r = Invoke-MigrationApply $c1 $after (& $applyOpts $R1 $live1)
Check '8a. 適用済み(applied)の候補は再実行しても何もしない' (-not $r.applied -and (& $sameHash $h1 (& $hashOf $R1))) $r.message
Set-MigrationProp $c1 'status' 'approved'   # 状態ファイルを失って approved のまま残った場合
$r = Invoke-MigrationApply $c1 $after (& $applyOpts $R1 $live1)
Check '8b. 状態が approved のままでも、データ側の再検証で二重登録を止める(単発実況が無い・再生リストが登録済み)' (-not $r.applied -and (@($r.blockers) -join ' ') -match '現在のデータに無い' -and (& $sameHash $h1 (& $hashOf $R1))) (@($r.blockers) -join ' / ')
Check '8c. 再生リスト sa-s1 は1件だけ' (@((Read-MigrationSiteData $R1).playlists | Where-Object { $_.playlistId -eq 'PLA1xxxxxxxxxxx' }).Count -eq 1)
Set-MigrationProp $c1 'status' 'applied'
$err = $null; try { [void](Set-MigrationDecision $state $c1.key 'approve' $now '') } catch { $err = $_.Exception.Message }
Check '8d. 適用済みの候補は承認・却下し直せない' ($err -match '適用済み') $err

# ---- existing-playlist(登録済みの再生リストへの整理)----
$c3 = & $candOf $state 's3'
[void](Set-MigrationDecision $state $c3.key 'approve' $now '')
$h2 = & $hashOf $R1
$r = Invoke-MigrationApply $c3 $after (& $applyOpts $R1 (Get-MigrationLiveTarget $client 'PLREGC1xxxxxxxx'))
$after3 = Read-MigrationSiteData $R1
Check '2h. 登録済みの同じVTuber × ゲームの再生リストに入っている単発実況は、単発実況だけを削除(PLAYLISTS は不変)' ($r.applied -and (& $hashOf $R1)['data-playlists.js'] -eq $h2['data-playlists.js'] -and -not @($after3.standalone | Where-Object { $_.id -eq 's3' }).Count -and @($after3.playlists).Count -eq @($after.playlists).Count) $r.message

# ---- 4. 同一動画の重複防止 ----
$c6 = & $candOf $state 's6'
$chk = Test-MigrationCandidate $c6 $site (Get-MigrationLiveTarget $client 'PLB6xxxxxxxxxxx')   # s1 を適用する前のデータ
Check '4a. 移行先に他の単発実況・登録済みの動画が入っていれば止める(s6 の移行先に s1 の動画)' (-not $chk.eligible -and (@($chk.blockers) -join ' ') -match '他の単発実況') (@($chk.blockers) -join ' / ')
$c2 = & $candOf $state 's2'
$chk = Test-MigrationCandidate $c2 $after3 (Get-MigrationLiveTarget $client 'PLA2xxxxxxxxxxx')
Check '4b. 単発実況の動画が移行先に全部は入っていなければ止める(動画の情報を失わない)' (-not $chk.eligible -and (@($chk.blockers) -join ' ') -match '入っていない: ' + (& $v '3')) (@($chk.blockers) -join ' / ')

# ---- 5. 同一再生リストの重複防止 ----
$c7 = & $candOf $state 's7'
Check '5a. 移行先が登録済みの再生リストIDなら new-playlist として登録しない' (-not $c7.eligible -and (@($c7.blockers) -join ' ') -match '登録済み') (@($c7.blockers) -join ' / ')
$x2 = & $stateOf $R1
$c1b = & $candOf $x2.state 's1'
Check '5b. 適用後に作り直した候補では、s1 は現在のデータに無いため適用不可' ($null -eq $c1b -or -not $c1b.eligible)

# ---- 6. 企画の誤分類防止 ----
$c4 = & $candOf $state 's4'; $c5 = & $candOf $state 's5'
Check '6a. 企画名(ホロライブ甲子園)を含む移行先・企画に使われるゲームは適用不可' (-not $c4.eligible -and (@($c4.blockers) -join ' ') -match 'ホロライブ甲子園' -and (@($c4.blockers) -join ' ') -match '企画\(PLAYLIST_EVENTS\)に使われるゲーム') (@($c4.blockers) -join ' / ')
Check '6b. 企画の疑いがある語(大会)を含む移行先は要確認(適用不可)' (-not $c5.eligible -and (@($c5.blockers) -join ' ') -match '企画の疑い') (@($c5.blockers) -join ' / ')
$err = $null; try { [void](Set-MigrationDecision $state $c4.key 'approve' $now '') } catch { $err = $_.Exception.Message }
Check '6c. 適用不可の候補は承認できない' ($err -match '承認できない' -and $c4.status -eq 'pending') $err
$evPl = [pscustomobject]@{ key = 'x'; standaloneId = 's4'; type = 'existing-playlist'; playlistId = 'PLREGE1xxxxxxxx'; streamer = 'VE'; game = 'パワフルプロ野球'; target = [pscustomobject]@{ registeredId = 'reg-e1'; title = '⚾ホロライブ甲子園⚾'; event = $null; videoInPlaylist = $true }; sharedWith = @(); targetsForSameStandalone = 1; fingerprint = '' }
$chk = Test-MigrationCandidate $evPl $after3 $null
Check '6d. 登録済みの企画の再生リスト(PLAYLIST_EVENTS)への整理も適用不可' (-not $chk.eligible -and (@($chk.blockers) -join ' ') -match '企画の再生リスト') (@($chk.blockers) -join ' / ')

# ---- 7. 存在しない移行先・確認できない移行先 ----
$c8 = & $candOf $state 's8'
$chk = Test-MigrationCandidate $c8 $after3 (Get-MigrationLiveTarget $client 'PLC8xxxxxxxxxxx')
Check '7a. 移行先の再生リストが存在しなければ止める' (-not $chk.eligible -and (@($chk.blockers) -join ' ') -match '存在しない') (@($chk.blockers) -join ' / ')
$liveErr = Get-MigrationLiveTarget $client 'PLERRORxxxxxxxx'
$chk = Test-MigrationCandidate $c8 $after3 $liveErr
Check '7b. API エラーなら止める(エラー文に APIキーを出さない)' (-not $chk.eligible -and (@($chk.blockers) -join ' ') -match '確認できない' -and -not ((@($chk.blockers) -join ' ').Contains($secret))) (@($chk.blockers) -join ' / ')
$c9 = & $candOf $state 's9'
$chk = Test-MigrationCandidate $c9 $after3 (Get-MigrationLiveTarget $client 'PLA9xxxxxxxxxxx')
Check '7c. 移行先の所有チャンネルが違えば止める' (-not $chk.eligible -and (@($chk.blockers) -join ' ') -match '所有チャンネル') (@($chk.blockers) -join ' / ')
$r = Invoke-MigrationApply ([pscustomobject]@{ key = 'k'; status = 'approved'; approvedFingerprint = 'a'; fingerprint = 'a' }) $after3 (& $applyOpts $R1 $null)
Check '7d. 移行先を API で確認していなければ適用しない' (-not $r.applied -and $r.message -match 'API') $r.message

# ---- 共演(コラボ)・別VTuber・別チャンネルの誤判定防止 ----
$c10 = & $candOf $state 's10'
Check 'cl1. 単発実況の動画に本人以外のVTuber名(共演の疑い)がある候補は適用不可(要確認)・承認できない' (-not $c10.eligible -and (@($c10.blockers) -join ' ') -match '共演・他事務所の疑い' -and (@($c10.blockers) -join ' ') -match '共演相手') (@($c10.blockers) -join ' / ')
$err = $null; try { [void](Set-MigrationDecision $state $c10.key 'approve' $now '') } catch { $err = $_.Exception.Message }
Check 'cl2. 共演の疑いがある候補は承認できず pending のまま' ($err -match '承認できない' -and $c10.status -eq 'pending') $err
$chk = Test-MigrationCandidate $c10 $site (Get-MigrationLiveTarget $client 'PLE10xxxxxxxxxx')
Check 'cl3. 移行先の中身が正しくても、共演の疑いは適用時の再検証でも止める(文字列だけで移行を確定しない)' (-not $chk.eligible -and (@($chk.blockers) -join ' ') -match '共演') (@($chk.blockers) -join ' / ')
$clone = { param($o) ($o | ConvertTo-Json -Depth 8 | ConvertFrom-Json) }
$c1other = & $clone (& $candOf (& $stateOf (New-FixtureRoot 'r1c')).state 's1')
$siteC = Read-MigrationSiteData (Join-Path $tmpRoot 'r1c')
$c1other.target | Add-Member -NotePropertyName channel -NotePropertyValue 'VB' -Force
$chk = Test-MigrationCandidate $c1other $siteC $null
Check 'cl4. 別のVTuberのチャンネルの再生リストは移行先にしない' (-not $chk.eligible -and (@($chk.blockers) -join ' ') -match '別のVTuber') (@($chk.blockers) -join ' / ')
$c1ch = & $clone (& $candOf (& $stateOf (New-FixtureRoot 'r1d')).state 's1'); $c1ch.target.channelId = (& $ch 'b')
$chk = Test-MigrationCandidate $c1ch (Read-MigrationSiteData (Join-Path $tmpRoot 'r1d')) $null
Check 'cl5. 移行先のチャンネルIDが本人のチャンネル(STREAMERS の youtube)と違えば移行先にしない' (-not $chk.eligible -and (@($chk.blockers) -join ' ') -match 'チャンネル') (@($chk.blockers) -join ' / ')

# ---- 9. 途中エラーで元に戻す ----
$R2 = New-FixtureRoot 'r2'
$y = & $stateOf $R2; $ca = & $candOf $y.state 's1'
[void](Set-MigrationDecision $y.state $ca.key 'approve' $now '')
$hb = & $hashOf $R2
$r = Invoke-MigrationApply $ca $y.site (& $applyOpts $R2 (Get-MigrationLiveTarget $client 'PLA1xxxxxxxxxxx') $false $true)
Check '9a. 1つ目のファイルを書いた後に失敗しても、両方のファイルが元に戻る(ハッシュ一致)' (-not $r.applied -and $r.message -match '元に戻した' -and $r.message -match '復元を確認済み' -and (& $sameHash $hb (& $hashOf $R2))) $r.message
# 承認後に単発実況の内容が変わった(fingerprint 不一致)
$saPath2 = Join-Path $R2 'data-standalone.js'
[IO.File]::WriteAllText($saPath2, (Read-MigrationText $saPath2).Replace('"2026-09-30"', '"2026-10-01"'), $utf8)
$y2site = Read-MigrationSiteData $R2
$hc = & $hashOf $R2
$r = Invoke-MigrationApply $ca $y2site (& $applyOpts $R2 (Get-MigrationLiveTarget $client 'PLA1xxxxxxxxxxx'))
Check '9b. 承認後に単発実況の内容が変わったら適用しない(再承認が必要)' (-not $r.applied -and (@($r.blockers) -join ' ') -match '変わっている' -and (& $sameHash $hc (& $hashOf $R2))) (@($r.blockers) -join ' / ')
$st2 = Merge-MigrationCandidates $y.state (New-MigrationCandidates $report $y2site) $y2site $now 'r2'
$ca2 = & $candOf $st2 's1'
Check '9c. 候補を作り直すと、内容が変わった承認は取り消されて pending に戻る' ($ca2.status -eq 'pending' -and -not $ca2.approvedFingerprint -and (@($ca2.history | ForEach-Object { $_.action }) -contains 'invalidated'))
$st3 = Merge-MigrationCandidates $st2 (New-MigrationCandidates $report $y2site) $y2site $now 'r3'
[void](Set-MigrationDecision $st3 (& $candOf $st3 's1').key 'approve' $now '')
$st4 = Merge-MigrationCandidates $st3 (New-MigrationCandidates $report $y2site) $y2site $now 'r4'
Check '9d. 内容が同じなら作り直しても承認は残る' ((& $candOf $st4 's1').status -eq 'approved')
$err = $null; $c2b = & $candOf $st4 's2'; try { [void](Set-MigrationDecision $st4 $c2b.key 'approve' $now '') } catch { $err = $_.Exception.Message }
Check '9e. 適用不可(動画が一部しか移行先に無い等)はレポート時点の判定では止まらなくても、適用時の再検証で止まる' ($null -eq $err -or $err -match '承認できない')

# ---- 10. 既存URL・SEO情報の保護 ----
$seoJs = @'
const fs = require("fs"), path = require("path"), vm = require("vm");
const root = process.argv[process.argv.length - 1], ctx = {}; vm.createContext(ctx);
for (const f of ["data-core.js", "data-playlists.js", "data-standalone.js"]) vm.runInContext(fs.readFileSync(path.join(root, f), "utf8"), ctx);
const P = vm.runInContext("PLAYLISTS", ctx), S = vm.runInContext("STANDALONE_PLAYS", ctx);
const g = new Set(P.map((p) => p.game).concat(S.map((p) => p.game))), s = new Set(P.map((p) => p.streamer).concat(S.map((p) => p.streamer)));
process.stdout.write(JSON.stringify({ games: [...g].sort(), streamers: [...s].sort(), ids: P.map((p) => p.id) }).replace(/[^ -~]/g, (c) => "\\u" + c.charCodeAt(0).toString(16).padStart(4, "0")));
'@
# 移行前と同じ固定データ(r0)と、s1・s3 を適用した r1 を比べる
$R0 = New-FixtureRoot 'r0'
$seoBeforeObj = (($seoJs | & node - $R0) -join '') | ConvertFrom-Json
$seoAfterObj = (($seoJs | & node - $R1) -join '') | ConvertFrom-Json
Check '10a. 実況のあるゲーム・VTuber(ゲーム詳細・VTuber詳細の index / sitemap の対象)は移行の前後で同じ' ((($seoBeforeObj.games -join '|') -eq ($seoAfterObj.games -join '|')) -and (($seoBeforeObj.streamers -join '|') -eq ($seoAfterObj.streamers -join '|')))
Check '10b. 既存の再生リストの id(内部ID)は変えず、新しい再生リストは末尾に追加' ((@($seoAfterObj.ids)[0..(@($seoBeforeObj.ids).Count - 1)] -join '|') -eq (@($seoBeforeObj.ids) -join '|') -and @($seoAfterObj.ids)[-1] -eq 'sa-s1')
Check '10c. ゲーム・VTuberの URL を決める GAMES / STREAMERS(data-core.js)は変えない' ((& $hashOf $R1)['data-core.js'] -eq (& $hashOf $R0)['data-core.js'])

# ---- テキスト書き換えの安全性 ----
$err = $null; try { [void](Remove-MigrationStandaloneText 'const STANDALONE_PLAYS = [{ id: "a" }];' 'a') } catch { $err = $_.Exception.Message }
Check '11a. 想定外の形(1行に複数項目など)は書き換えずにエラー' ($null -ne $err) $err
$err = $null; try { [void](Remove-MigrationStandaloneText (Read-MigrationText (Join-Path $R0 'data-standalone.js')) 'single-001') } catch { $err = $_.Exception.Message }
Check '11b. コメント内の登録例(// id: "single-001")は書き換え対象にしない' ($err -match '0 件') $err
Check '11c. JS 文字列のエスケープ(" \ 改行)' ((ConvertTo-MigrationJsString "a`"b\c`nd") -eq '"a\"b\\c\u000ad"')

# ---- 適用前の確認(Test-MigrationPlan。API なし・データを変えない)----
$R4 = New-FixtureRoot 'r4'
$z = & $stateOf $R4; $cz = & $candOf $z.state 's1'
[void](Set-MigrationDecision $z.state $cz.key 'approve' $now '')
$h4 = & $hashOf $R4
$planTmp = Join-Path $tmpRoot 'plan-tmp'; New-Item -ItemType Directory -Path $planTmp | Out-Null
$plan = Test-MigrationPlan $cz $z.site $R4 $planTmp $now
Check 'k1. 承認済みで問題の無い候補は OK。変わるファイル(再生リスト1件追加・単発実況1件削除)を表示する' ($plan.ok -and @($plan.changes | Where-Object { $_ -match 'data-playlists.js: 末尾に1件追加 id=sa-s1' }).Count -eq 1 -and @($plan.changes | Where-Object { $_ -match 'data-standalone.js: 1件削除 id=s1' }).Count -eq 1) (@($plan.problems) + @($plan.changes) -join ' / ')
Check 'k2. 確認ではデータを変えず、一時ファイルも残さない' ((& $sameHash $h4 (& $hashOf $R4)) -and @(Get-ChildItem -LiteralPath $planTmp).Count -eq 0 -and -not (Test-Path (Join-Path $R4 'reports')))
$cz6 = & $candOf $z.state 's7'
$plan6 = Test-MigrationPlan $cz6 $z.site $R4 $planTmp $now
Check 'k3. 未承認・登録済みの再生リストIDなどの問題は NG として理由を出す' (-not $plan6.ok -and (@($plan6.problems) -join ' ') -match 'pending' -and (@($plan6.problems) -join ' ') -match '登録済み') (@($plan6.problems) -join ' / ')

# ---- CLI(migrate-standalone.ps1)を一時フォルダのコピーで通しで動かす(API なし)----
$R3 = New-FixtureRoot 'r3'
foreach ($f in 'standalone-matching.ps1', 'standalone-followups.ps1', 'standalone-migration-approval.ps1', 'migrate-standalone.ps1') { Copy-Item -LiteralPath (Join-Path $scriptDir $f) -Destination $R3 }
New-Item -ItemType Directory -Path (Join-Path $R3 'reports') | Out-Null
[IO.File]::WriteAllText((Join-Path $R3 'reports\standalone-followups.json'), ($report | ConvertTo-Json -Depth 8), $utf8)
$cli = Join-Path $R3 'migrate-standalone.ps1'
$h3 = & $hashOf $R3
# 子プロセスには APIキーを渡さない(環境変数を空にして実行し、終わったら戻す)
$runCli = { param([string[]]$a) $saved = $env:YOUTUBE_API_KEY; $env:YOUTUBE_API_KEY = $null; $ErrorActionPreference = 'Continue'; try { $o = & powershell -NoProfile -ExecutionPolicy Bypass -File $cli @a 2>&1 | Out-String; return @{ out = $o; code = $LASTEXITCODE } } finally { $env:YOUTUBE_API_KEY = $saved } }
$k0 = & $runCli @('-Action', 'check')
Check '12-0. CLI check: 状態ファイルが無い(承認済み0件)なら「適用対象なし」で正常終了' ($k0.code -eq 0 -and $k0.out -match '適用対象なし' -and (& $sameHash $h3 (& $hashOf $R3))) $k0.out
$o1 = & $runCli @('-Action', 'init')
$stFile = Join-Path $R3 'reports\standalone-migration\approvals.json'
Check '12a. CLI init: 候補を状態ファイルに取り込み、一覧(candidates.md)を書く。データは不変' ($o1.code -eq 0 -and (Test-Path $stFile) -and (Test-Path (Join-Path $R3 'reports\standalone-migration\candidates.md')) -and (& $sameHash $h3 (& $hashOf $R3))) $o1.out
$k1 = & $runCli @('-Action', 'check')
Check '12-1. CLI check: 候補はあるが承認済み0件なら「適用対象なし」で正常終了' ($k1.code -eq 0 -and $k1.out -match '適用対象なし') $k1.out
$o2 = & $runCli @('-Action', 'approve', '-Id', 's1', '-Note', 'cli')
$stHash = (Get-FileHash -LiteralPath $stFile).Hash; $logLines = @(Get-Content -LiteralPath (Join-Path $R3 'reports\standalone-migration\log.jsonl')).Count
$k2 = & $runCli @('-Action', 'check')
Check '12-2. CLI check: 承認済みの候補を API なしで確認し、変わるファイルを表示する(データ・状態ファイル・ログは変えない。API 0)' `
  ($k2.code -eq 0 -and $k2.out -match '\[OK\] s1\|new-playlist' -and $k2.out -match '変更されるファイル: data-playlists.js' -and $k2.out -match 'API ユニット 0' -and (& $sameHash $h3 (& $hashOf $R3)) -and (Get-FileHash -LiteralPath $stFile).Hash -eq $stHash -and @(Get-Content -LiteralPath (Join-Path $R3 'reports\standalone-migration\log.jsonl')).Count -eq $logLines) $k2.out
$k3 = & $runCli @('-Action', 'check', '-Id', 's4')
Check '12-3. CLI check -Id: 指定した候補(未承認・企画)は NG と理由を出し、終了コード 1' ($k3.code -eq 1 -and $k3.out -match '\[NG\] s4' -and $k3.out -match 'pending' -and $k3.out -match '企画') $k3.out
$o3 = & $runCli @('-Action', 'apply')
Check '12b. CLI approve → apply(API なし): 承認は記録されるが、移行先を再確認できないため適用しない' ($o2.code -eq 0 -and $o2.out -match 'approved' -and $o3.out -match 'API なし' -and (& $sameHash $h3 (& $hashOf $R3))) ($o2.out + $o3.out)
$o4 = & $runCli @('-Action', 'apply', '-Apply')
Check '12c. CLI apply -Apply: APIキーが無ければ何も変更せずエラー' ($o4.code -ne 0 -and $o4.out -match 'APIキー' -and (& $sameHash $h3 (& $hashOf $R3))) $o4.out
$o5 = & $runCli @('-Action', 'list', '-WorkDir', 'data')
Check '12d. CLI: 書き込み先が reports\ の外ならエラー' ($o5.code -ne 0 -and $o5.out -match 'reports') $o5.out
$o6 = & $runCli @('-Action', 'approve', '-Id', 's4')
Check '12e. CLI: 適用不可の候補は承認できない(状態は pending のまま)' ($o6.code -ne 0 -and ((([IO.File]::ReadAllText($stFile, [Text.Encoding]::UTF8) | ConvertFrom-Json).candidates | Where-Object { $_.standaloneId -eq 's4' }).status -eq 'pending')) $o6.out
$log = Join-Path $R3 'reports\standalone-migration\log.jsonl'
Check '12f. 操作はログ(log.jsonl)に残り、APIキーを含まない' ((Test-Path $log) -and @(Get-Content -LiteralPath $log).Count -ge 3 -and -not ([IO.File]::ReadAllText($log)).Contains($secret))

# ---- 後片付け・リポジトリのデータが変わっていないこと ----
Remove-Item -LiteralPath $tmpRoot -Recurse -Force
$repoAfter = @{}; foreach ($f in 'data-core.js', 'data-playlists.js', 'data-standalone.js') { $repoAfter[$f] = (Get-FileHash -LiteralPath (Join-Path $scriptDir $f) -Algorithm SHA256).Hash }
Check '13. リポジトリの data-core.js / data-playlists.js / data-standalone.js は変わっていない' (& $sameHash $repoHashes $repoAfter)

Write-Output ''
Write-Output "PASS: $($script:pass)  FAIL: $($script:fail)"
if ($script:fail) { exit 1 } else { exit 0 }
