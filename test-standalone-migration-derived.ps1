<#
.SYNOPSIS
  単発実況 → 再生リストの移行後の派生データ(件数バッジ・トップ・新着「NEW」・詳細ページ用)のテスト。
  実データ・サイトのスクリプトを一時フォルダにコピーして行う(リポジトリのデータは変更しない)。
  YouTube API は呼ばない(移行先の状態は固定の値で置き換える)。node が必要。
    .\test-standalone-migration-derived.ps1
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
Write-Output '=== 単発実況 → 再生リスト 移行後の派生データ(新着・NEW・件数バッジ)テスト ==='

# リポジトリのファイルが変わらないことを最後に確かめる
$guard = @('data-playlists.js', 'data-standalone.js', 'data-core.js', 'data-counts.js', 'data-home.js', 'data-new.js', 'data-ranking.js', 'data-genres.js', 'sitemap.xml', 'robots.txt')
$repoHash = @{}; foreach ($f in $guard) { $repoHash[$f] = (Get-FileHash -LiteralPath (Join-Path $scriptDir $f) -Algorithm SHA256).Hash }

# ---- 実データ・サイトのスクリプトを一時フォルダへ(テストファイル・reports\ は除く)----
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("vgame-migration-derived-" + $PID)
if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
$R = Join-Path $tmp 'site'
New-Item -ItemType Directory -Path $R | Out-Null
Get-ChildItem -LiteralPath $scriptDir -Filter *.js -File | Where-Object { $_.Name -notlike 'test-*' } | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $R }
Copy-Item -LiteralPath (Join-Path $scriptDir 'generate-counts.ps1') -Destination $R
Copy-Item -LiteralPath (Join-Path $scriptDir 'data') -Destination (Join-Path $R 'data') -Recurse
$work = Join-Path $tmp 'work'
$utf8 = New-Object System.Text.UTF8Encoding($false)

# ---- 補助: 派生データ・新着・トップ・件数バッジの読み取り(node)----
$probeJs = @'
const fs = require("fs"), path = require("path"), vm = require("vm");
const root = process.argv[process.argv.length - 2], viewDate = process.argv[process.argv.length - 1], ctx = {}; vm.createContext(ctx);
for (const f of ["data-core.js", "data-playlists.js", "data-standalone.js", "data-counts.js", "data-new.js", "data-home.js"]) vm.runInContext(fs.readFileSync(path.join(root, f), "utf8"), ctx, { filename: f });
const g = (n) => vm.runInContext("typeof " + n + " === 'undefined' ? null : " + n, ctx);
const P = g("PLAYLISTS"), S = g("STANDALONE_PLAYS"), N = g("NEW_LIST").items, H = g("HOME_SUMMARY"), E = g("PLAYLIST_EVENTS");
const now = new Date(viewDate + "T12:00:00");
const isNew = (p) => (now - new Date(p.addedDate + "T00:00:00")) / 864e5 <= 14;   // new.js の判定(NEW_WITHIN_DAYS = 14)と同じ
const cnt = (arr, k) => arr.reduce((m, p) => (m[p[k]] = (m[p[k]] || 0) + 1, m), {});
const diff = (a, b) => { const ks = new Set([...Object.keys(a || {}), ...Object.keys(b || {})]); let d = 0; ks.forEach((k) => { if ((a || {})[k] !== (b || {})[k]) d++; }); return d; };
const sortDate = (p) => p.updatedDate || p.addedDate || "";
const rec = H.recentUpdated;
const out = {
  newIds: N.map((p) => p.id), newBadge: N.filter(isNew).map((p) => p.id), newDup: N.length - new Set(N.map((p) => p.id)).size,
  newSorted: N.every((p, i) => i === 0 || N[i - 1].addedDate >= p.addedDate),   // new.js の computeNewList と同じく追加日の新しい順
  newItem: (id) => null, recent: rec.map((p) => p.id), recentSorted: rec.every((p, i) => i === 0 || sortDate(rec[i - 1]) >= sortDate(p)),
  countsDiff: diff(g("PLAYLIST_COUNTS_BY_GAME"), cnt(P, "game")) + diff(g("PLAYLIST_COUNTS_BY_STREAMER"), cnt(P, "streamer")) + diff(g("STANDALONE_COUNTS_BY_GAME"), cnt(S, "game")) + diff(g("STANDALONE_COUNTS_BY_STREAMER"), cnt(S, "streamer")),
  singles: S.map((p) => p.id), playlists: P.length, events: E.map((e) => e.playlist + ":" + e.event).join("|"),
  eventInPlaylists: E.filter((e) => P.some((p) => p.id === e.playlist)).length,
  items: Object.fromEntries(N.filter((p) => p.id.startsWith("sa-") || p.id.startsWith("reg-test")).map((p) => [p.id, { addedDate: p.addedDate, isNew: isNew(p) }])),
};
delete out.newItem;
process.stdout.write(JSON.stringify(out).replace(/[^ -~]/g, (c) => "\\u" + c.charCodeAt(0).toString(16).padStart(4, "0")));
'@
$probe = { param($viewDate) (($probeJs | & node - $R $viewDate) -join '') | ConvertFrom-Json }
$derivedHash = { $h = Get-MigrationDerivedHashes $R; foreach ($f in 'data-playlists.js', 'data-standalone.js') { $h[$f] = (Get-FileHash -LiteralPath (Join-Path $R $f) -Algorithm SHA256).Hash }; return $h }
$same = { param($a, $b) @(@($a.Keys) + @($b.Keys) | Select-Object -Unique | Where-Object { $a[$_] -ne $b[$_] }).Count -eq 0 }
$changedKeys = { param($a, $b) @(@($a.Keys) + @($b.Keys) | Select-Object -Unique | Where-Object { $a[$_] -ne $b[$_] } | Sort-Object) }

# ---- 候補(実データの単発実況 single-001 を新しい再生リストへ。移行日は単発実況の追加日より後)----
$migrationDay = [datetime]'2026-10-20T12:00:00'   # 移行した日(単発実況の追加日 2026-09-30 から20日後)
$site = Read-MigrationSiteData $R
$play = @($site.standalone | Where-Object { $_.id -eq 'single-001' })[0]
$st = @($site.streamers | Where-Object { $_.name -eq $play.streamer })[0]
$chId = [regex]::Match($st.youtube, '/channel/(UC[A-Za-z0-9_-]{22})').Groups[1].Value
$vid = Get-FollowupVideoId $play.videos[0].url
$report = [pscustomobject]@{ generatedAt = 'test'; results = @([pscustomobject]@{ id = 'single-001'; streamer = $play.streamer; game = $play.game; rank = 'STRONG'
      playlistCandidates = @([pscustomobject]@{ playlistId = 'PLmigtest00000001'; title = "$($play.game) まとめ"; channel = $play.streamer; channelId = $chId; count = 3; videoInPlaylist = $true; event = $null })
      duplicateCandidates = @(); sharedWith = @(); reviewFlags = @() }) }
$state = Merge-MigrationCandidates (Read-MigrationState (Join-Path $tmp 'none.json')) (New-MigrationCandidates $report $site) $site $migrationDay 'test'
$cand = @($state.candidates)[0]
$liveOk = [pscustomobject]@{ exists = $true; error = $null; title = "$($play.game) まとめ"; channelId = $chId; itemCount = 3; videoIds = @($vid, 'vNEWxxxxxx1', 'vNEWxxxxxx2') }
$getLive = { param($plId) $liveOk }
$runOpts = { param($apply, $failMid = $false) @{ root = $R; workDir = $work; now = $migrationDay; apply = $apply; getLive = $getLive; stateFile = (Join-Path $work 'approvals.json'); logFile = (Join-Path $work 'log.jsonl'); failAfterFirstWrite = $failMid } }
Check '0. 候補(single-001 → 新しい再生リスト)は適用できる候補として作られる' ($cand.eligible -and $cand.status -eq 'pending') (@($cand.blockers) -join ' / ')

$p0 = & $probe '2026-10-20'
$h0 = & $derivedHash
Check '0b. 移行前: 件数バッジ(data-counts.js)は実データと一致し、新着に同じ id は無い' ($p0.countsDiff -eq 0 -and $p0.newDup -eq 0)

# 1. 未承認(pending)
$r1 = Invoke-MigrationApplyRun $state @($cand) (& $runOpts $true)
Check '1. 未承認の候補では、データも派生データ(件数バッジ・新着・トップ・詳細ページ用)も変わらない' ($r1.appliedNow -eq 0 -and $null -eq $r1.derived -and (& $same $h0 (& $derivedHash))) (@($r1.lines) -join ' / ')
[void](Set-MigrationDecision $state $cand.key 'reset' $migrationDay '')

# 2. dry-run
[void](Set-MigrationDecision $state $cand.key 'approve' $migrationDay '')
$r2 = Invoke-MigrationApplyRun $state @($cand) (& $runOpts $false)
Check '2. dry-run では、適用できると判定しても派生データを作り直さず、何も変わらない' ($r2.appliedNow -eq 0 -and $null -eq $r2.derived -and @($r2.results)[0].ok -and (& $same $h0 (& $derivedHash)) -and $cand.status -eq 'approved') (@($r2.lines) -join ' / ')

# 3. 移行の失敗(1つ目のファイルを書いた直後に失敗)
$r3 = Invoke-MigrationApplyRun $state @($cand) (& $runOpts $true $true)
Check '3. 移行に失敗したら、データも派生データも元のまま(派生データは作り直さない)。候補は error' ($r3.appliedNow -eq 0 -and $null -eq $r3.derived -and (& $same $h0 (& $derivedHash)) -and $cand.status -eq 'error') (@($r3.lines) -join ' / ')
[void](Set-MigrationDecision $state $cand.key 'reset' $migrationDay '')
[void](Set-MigrationDecision $state $cand.key 'approve' $migrationDay '')

# 4. 正常な移行
$r4 = Invoke-MigrationApplyRun $state @($cand) (& $runOpts $true)
$p4 = & $probe '2026-10-20'
$h4 = & $derivedHash
$changed4 = & $changedKeys $h0 $h4
$item = $p4.items.'sa-single-001'
Check '4a. 正常に移行したときだけ派生データを作り直し、すべての --check が通る' ($r4.appliedNow -eq 1 -and $r4.derived -and $r4.derived.ok -and $cand.status -eq 'applied') (@($r4.lines) -join ' / ')
Check '4b. 件数バッジ(data-counts.js)が移行後のデータと一致する(再生リスト +1・単発実況 -1)' ($p4.countsDiff -eq 0 -and $changed4 -contains 'data-counts.js' -and $p4.playlists -eq $p0.playlists + 1 -and -not ($p4.singles -contains 'single-001')) ($changed4 -join ', ')
Check '4c. 新着(data-new.js)に新しい再生リストが1回だけ入り、詳細ページ用データ(data\)も更新される' ($p4.newDup -eq 0 -and @($p4.newIds | Where-Object { $_ -eq 'sa-single-001' }).Count -le 1 -and @($changed4 | Where-Object { $_ -like 'data\*' }).Count -ge 1) ($changed4 -join ', ')
Check '5a. 移行した日を新着日にしない: 新しい再生リストの追加日は単発実況の追加日(2026-09-30)を引き継ぐ' ($cand.appliedRecord.after.addedPlaylist.addedDate -eq $play.addedDate -and $cand.appliedRecord.after.addedDateFrom -eq 'standalone' -and $play.addedDate -eq '2026-09-30') ($cand.appliedRecord.after | ConvertTo-Json -Depth 4)
Check '5b. 移行した日(2026-10-20)に見ても「NEW」は付かない(追加から20日 > 14日)。新着は追加日の順のまま(移行した日の位置には並ばない)' (-not ($p4.newBadge -contains 'sa-single-001') -and $p4.newSorted -and $item.addedDate -eq '2026-09-30' -and -not $item.isNew) ("newBadge=" + ($p4.newBadge -join ',') + " item=" + ($item | ConvertTo-Json -Compress))
$p4early = & $probe '2026-10-05'
Check '6a. 既存の NEW 条件(追加日から14日以内)はそのまま: 追加日の5日後に見れば NEW が付く' ($p4early.newBadge -contains 'sa-single-001') ($p4early.newBadge -join ',')
Check '6b. トップの「最近更新」は日付順のまま(移行した日を理由に先頭へ割り込まない)。トップに NEW バッジは無い' ($p4.recentSorted -and @($p4.recent)[0] -ne 'sa-single-001' -and -not (Select-String -LiteralPath (Join-Path $R 'home.js') -Pattern 'showNewBadge' -Quiet)) ($p4.recent -join ',')
Check '7. 企画の再生リスト(PLAYLIST_EVENTS)と対象の再生リストは変わらない' ($p4.events -eq $p0.events -and $p4.eventInPlaylists -eq $p0.eventInPlaylists -and $p0.eventInPlaylists -gt 0)

# 8. 再実行
Set-MigrationProp $cand 'status' 'approved'   # 状態ファイルを失って approved のまま残った場合
$r8 = Invoke-MigrationApplyRun $state @($cand) (& $runOpts $true)
$h8 = & $derivedHash
Check '8a. 再実行しても二重に適用・二重に作り直ししない(データ・派生データは1回目の後と同じ)' ($r8.appliedNow -eq 0 -and $null -eq $r8.derived -and (& $same $h4 $h8)) (@($r8.lines) -join ' / ')
$again = Invoke-MigrationDerivedUpdate $R
Check '8b. 派生データの作り直しをもう一度実行しても、内容は変わらない' ($again.ok -and @($again.changed).Count -eq 0) (@($again.changed) -join ', ')

# 既存の再生リストへの整理(PLAYLISTS は変えない): 新着・トップは変わらず、件数バッジだけ直る
$play2 = @((Read-MigrationSiteData $R).standalone | Where-Object { $_.id -eq 'single-002' })[0]
$plPath = Join-Path $R 'data-playlists.js'
$regEntry = [ordered]@{ id = 'reg-test-002'; title = "$($play2.game) 実況"; streamer = $play2.streamer; game = $play2.game; genre = $play2.genre; playlistId = 'PLregtest00000002'; videoCount = 2; addedDate = '2026-08-01' }
[IO.File]::WriteAllText($plPath, (Add-MigrationPlaylistText (Read-MigrationText $plPath) $regEntry "`r`n"), $utf8)
[void](Invoke-MigrationDerivedUpdate $R)   # 登録済みの状態を基準にする
$pB = & $probe '2026-10-20'; $hB = & $derivedHash
$vid2 = Get-FollowupVideoId $play2.videos[0].url
$report2 = [pscustomobject]@{ generatedAt = 'test2'; results = @([pscustomobject]@{ id = 'single-002'; streamer = $play2.streamer; game = $play2.game; rank = 'STRONG'; playlistCandidates = @()
      duplicateCandidates = @([pscustomobject]@{ id = 'reg-test-002'; playlistId = 'PLregtest00000002'; title = $regEntry.title; game = $play2.game; sameGame = $true; event = $null; videoInPlaylist = $true }); sharedWith = @(); reviewFlags = @() }) }
$site2 = Read-MigrationSiteData $R
$state2 = Merge-MigrationCandidates (Read-MigrationState (Join-Path $tmp 'none2.json')) (New-MigrationCandidates $report2 $site2) $site2 $migrationDay 'test2'
$cand2 = @($state2.candidates)[0]
[void](Set-MigrationDecision $state2 $cand2.key 'approve' $migrationDay '')
$liveReg = [pscustomobject]@{ exists = $true; error = $null; title = $regEntry.title; channelId = ''; itemCount = 2; videoIds = @($vid2, 'vREGxxxxxx1') }
$r9 = Invoke-MigrationApplyRun $state2 @($cand2) @{ root = $R; workDir = $work; now = $migrationDay; apply = $true; getLive = { param($x) $liveReg }; stateFile = (Join-Path $work 'approvals2.json'); logFile = (Join-Path $work 'log.jsonl') }
$p9 = & $probe '2026-10-20'; $h9 = & $derivedHash; $changed9 = & $changedKeys $hB $h9
Check '9. 既存の再生リストへの整理: 新着(data-new.js)・トップ(data-home.js)は変わらず、件数バッジは移行後のデータと一致する' `
  ($r9.appliedNow -eq 1 -and $r9.derived.ok -and -not ($changed9 -contains 'data-new.js') -and -not ($changed9 -contains 'data-home.js') -and $changed9 -contains 'data-counts.js' -and $p9.countsDiff -eq 0 -and (($p9.newBadge -join ',') -eq ($pB.newBadge -join ','))) `
  ((@($r9.lines) -join ' / ') + ' changed=' + ($changed9 -join ','))

# ---- 後片付け・リポジトリのファイルが変わっていないこと ----
Remove-Item -LiteralPath $tmp -Recurse -Force
$repoAfter = @{}; foreach ($f in $guard) { $repoAfter[$f] = (Get-FileHash -LiteralPath (Join-Path $scriptDir $f) -Algorithm SHA256).Hash }
Check '10. リポジトリのデータ・派生データ・sitemap・robots は変わっていない' (& $same $repoHash $repoAfter)

Write-Output ''
Write-Output "PASS: $($script:pass)  FAIL: $($script:fail)"
if ($script:fail) { exit 1 } else { exit 0 }
