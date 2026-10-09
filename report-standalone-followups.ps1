<#
.SYNOPSIS
  単発実況(STANDALONE_PLAYS)の「シリーズ化・専用再生リスト移行候補」レポートを作る(読み取り専用)。

.DESCRIPTION
  単発実況1件ごとに、次を調べて STRONG / MEDIUM / WEAK / NONE / UNKNOWN を付ける(判定は standalone-followups.ps1)。
    A. 同じVTuber・同じゲームの別の動画が増えていないか(最近の動画を GAMES と照合)
    B. 同じVTuberのチャンネルに、サイト未登録のゲーム名入り再生リストができていないか(既存の動画IDが入っているか)
    C. サイト登録済みの再生リスト(PLAYLISTS)と重複していないか
  データ・生成物は一切変更しない。STRONG でも自動移行はしない(人が確認して、再生リスト追加と単発実況の整理を同じ commit で行う)。

  出力: <OutDir>\standalone-followups.json と standalone-followups.md(既定の OutDir は reports\。git 管理外・公開対象外)。
  出力先に前回のレポートがあるときは、API を使う前に止まる(上書きしない)。別の -OutDir を指定するか、上書きしてよいときだけ -Overwrite。

  要確認の印(reviewFlags): 動画・再生リストの名前に本人以外のVTuber名・事務所名・企画名・企画を疑わせる語があるもの。
    共演・企画の可能性があるため STRONG にはしない(MEDIUM にして人が確認する。判定は standalone-followups.ps1)。

  YouTube API(読み取りのみ。キーは表示・保存しない):
    VTuberごとに channels(ハンドルのみ)・channels(contentDetails)・playlists(50件ごと)・playlistItems(最近の動画、50件ごと)、
    サイト登録済みの同じVTuberの再生リストとゲーム名入り再生リストの playlistItems(50件ごと)。いずれも 1回 = 1ユニット。
    -MaxUnits を超える要求はせず(8割に達したら知らせる)、残りは「未確認」として報告する(「候補なし」にはしない)。
    1日の利用上限・残量はこのスクリプトからは分からないため、Google Cloud コンソールで確認すること。

  キャッシュ(既定: reports\cache\standalone-followups-cache.json。git 管理外・公開対象外。キーは保存しない):
    同じ日の2回目はほぼ API を使わない。期限切れの最近の動画は新しい分だけ取り直す。
    再生リストの中身は、その実行で取った一覧の動画数がキャッシュ時と同じ(かつ7日以内)なら再利用する。
    有効期限は standalone-followups.ps1 の $script:FollowupTtlHours。壊れたキャッシュは使わずに作り直す。

.PARAMETER OutDir
  レポートの保存先フォルダ(既定: reports)。data\・public\ やリポジトリ直下には保存しない。
.PARAMETER Offline
  YouTube API を使わない(登録済みデータだけで分かる範囲を報告し、残りは UNKNOWN)。
.PARAMETER MaxVideos
  VTuberごとに見る最近の動画の本数(既定 200)。
.PARAMETER MaxUnits
  この実行で使う API ユニットの上限(既定 600)。
.PARAMETER ApiKey
  YouTube Data API v3 のAPIキー。省略時は環境変数 YOUTUBE_API_KEY。無ければ -Offline と同じ動作。
.PARAMETER CacheFile
  キャッシュファイル(既定: reports\cache\standalone-followups-cache.json)。リポジトリ内なら reports\ の下だけ。
.PARAMETER NoCache
  キャッシュを読まず・書かない。
.PARAMETER RefreshCache
  キャッシュを読まずに全部取り直し、結果でキャッシュを作り直す。
.PARAMETER Overwrite
  出力先にあるレポート(standalone-followups.json / .md)を上書きしてよいときだけ指定する。キャッシュには関係しない。

.EXAMPLE
  .\report-standalone-followups.ps1
.EXAMPLE
  .\report-standalone-followups.ps1 -Offline
#>
param(
  [string]$OutDir = "reports",
  [switch]$Offline,
  [int]$MaxVideos = 200,
  [int]$MaxUnits = 600,
  [string]$ApiKey = $env:YOUTUBE_API_KEY,
  [string]$CacheFile = "reports\cache\standalone-followups-cache.json",
  [switch]$NoCache,
  [switch]$RefreshCache,
  [switch]$Overwrite
)
$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "standalone-matching.ps1")
. (Join-Path $scriptDir "standalone-followups.ps1")

# ---- 保存先の確認(公開データ・生成物の場所には書かない) ----
$outFull = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($OutDir)) { $OutDir } else { Join-Path (Get-Location) $OutDir }))
$rootFull = [IO.Path]::GetFullPath($scriptDir).TrimEnd('\')
$sep = [IO.Path]::DirectorySeparatorChar
$inRepo = $outFull.TrimEnd('\').StartsWith($rootFull + $sep, [StringComparison]::OrdinalIgnoreCase) -or $outFull.TrimEnd('\') -ieq $rootFull
$underReports = $outFull.TrimEnd('\') -ieq (Join-Path $rootFull "reports") -or $outFull.StartsWith((Join-Path $rootFull "reports") + $sep, [StringComparison]::OrdinalIgnoreCase)
if ($inRepo -and -not $underReports) { Write-Error "-OutDir はリポジトリ内なら reports\ の下にしてください(git 管理外・公開対象外の場所): $OutDir"; exit 1 }
# キャッシュも同じ決まり(リポジトリ内なら reports\ の下だけ。拡張子は .json)。相対パスはリポジトリ基準
$cacheFull = $null
if (-not $NoCache) {
  $cacheFull = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($CacheFile)) { $CacheFile } else { Join-Path $scriptDir $CacheFile }))
  $cInRepo = $cacheFull.StartsWith($rootFull + $sep, [StringComparison]::OrdinalIgnoreCase)
  $cUnderReports = $cacheFull.StartsWith((Join-Path $rootFull "reports") + $sep, [StringComparison]::OrdinalIgnoreCase)
  if (($cInRepo -and -not $cUnderReports) -or [IO.Path]::GetExtension($cacheFull) -ne '.json') { Write-Error "-CacheFile はリポジトリ内なら reports\ の下の .json にしてください: $CacheFile"; exit 1 }
}

# ---- 前回のレポートを誤って上書きしない(API を使う前に確かめる。キャッシュは触らない) ----
$existingReports = @('standalone-followups.json', 'standalone-followups.md' | Where-Object { Test-Path -LiteralPath (Join-Path $outFull $_) })
if ($existingReports.Count -and -not $Overwrite) {
  Write-Error ("出力先に前回のレポートがあるため中止しました(上書きしていません。API も使っていません): $(Join-Path $outFull ($existingReports -join ', '))。" +
    "別の出力先を -OutDir で指定してください(例: -OutDir reports\followups-$((Get-Date).ToString('yyyyMMdd-HHmm')))。上書きしてよいときだけ -Overwrite を付けてください")
  exit 1
}

$useApi = (-not $Offline) -and [bool]$ApiKey
$mode = $(if ($useApi) { "API" } elseif ($Offline) { "オフライン(-Offline)" } else { "オフライン(APIキー未設定)" })

# ---- データ読み込み(audit-standalone-migration.ps1 と同じく node の vm で実行して取り出す。ASCII にエスケープ) ----
$loader = @'
const fs = require("fs"), path = require("path"), vm = require("vm");
const root = process.argv[process.argv.length - 1], ctx = {};
vm.createContext(ctx);
for (const f of ["data-core.js", "data-playlists.js", "data-standalone.js"]) vm.runInContext(fs.readFileSync(path.join(root, f), "utf8"), ctx, { filename: f });
const pick = (n) => vm.runInContext("typeof " + n + " === 'undefined' ? [] : " + n, ctx);
const playlists = pick("PLAYLISTS");
const evNames = {}; pick("GAME_EVENTS").forEach((e) => { evNames[e.id] = e.name; });
const evByPlaylist = {}; pick("PLAYLIST_EVENTS").forEach((e) => { const p = playlists.find((x) => x.id === e.playlist); if (p && evNames[e.event]) evByPlaylist[p.playlistId] = evNames[e.event]; });
const out = {
  streamers: pick("STREAMERS").map((s) => ({ name: s.name, youtube: s.youtube || "", group: s.group || "" })),
  games: pick("GAMES").map((g) => ({ name: g.name, aliases: [g.name].concat(g.nameJa ? [g.nameJa] : [], g.aliases || []) })),
  playlists: playlists.map((p) => ({ id: p.id, title: p.title, streamer: p.streamer, game: p.game, playlistId: p.playlistId })),
  standalone: pick("STANDALONE_PLAYS").map((p) => ({ id: p.id, title: p.title || "", streamer: p.streamer, game: p.game, format: p.format, videos: (p.videos || []).map((v) => ({ url: v.url, title: v.title || "", publishedDate: v.publishedDate || "" })) })),
  eventNames: Object.values(evNames), eventByPlaylist: evByPlaylist,
};
const esc = (c) => String.fromCharCode(92) + "u" + c.charCodeAt(0).toString(16).padStart(4, "0");
process.stdout.write(JSON.stringify(out).replace(/[^ -~]/g, esc));
'@
$raw = $loader | & node - $scriptDir
if ($LASTEXITCODE -ne 0 -or -not $raw) { Write-Error "データの読み込みに失敗しました(node が必要です)"; exit 1 }
$data = ($raw -join "") | ConvertFrom-Json
$streamers = @($data.streamers | ForEach-Object { $_ })
$games = @($data.games | ForEach-Object { [pscustomobject]@{ name = $_.name; aliases = @($_.aliases | ForEach-Object { $_ }) } })
$sitePlaylists = @($data.playlists | ForEach-Object { $_ })
$plays = @($data.standalone | ForEach-Object { [pscustomobject]@{ id = $_.id; title = $_.title; streamer = $_.streamer; game = $_.game; format = $_.format; videos = @($_.videos | ForEach-Object { $_ }) } })
$eventPlaylistIds = @{}; foreach ($p in $data.eventByPlaylist.PSObject.Properties) { $eventPlaylistIds[$p.Name] = $p.Value }
$eventNames = @($data.eventNames | ForEach-Object { $_ })
$standaloneVideoIds = New-Object System.Collections.Generic.HashSet[string]
foreach ($pl in $plays) { foreach ($v in $pl.videos) { $id = Get-FollowupVideoId $v.url; if ($id) { [void]$standaloneVideoIds.Add($id) } } }

# ---- YouTube API(読み取りのみ。キーは要求のURLにだけ付け、エラー文・キャッシュ・レポートからは伏せる) ----
# 取得・キャッシュ・利用上限は standalone-followups.ps1 の New-FollowupApiClient / New-FollowupCachedApi。
# 1回の要求につき1回だけ試す(失敗しても再試行しない。失敗した対象は「確認できない」として報告する)
$httpGet = {
  param($endpoint, $query)
  Invoke-RestMethod -Uri ("https://www.googleapis.com/youtube/v3/" + $endpoint + "?" + $query + "&key=" + [uri]::EscapeDataString($ApiKey)) -Method Get -TimeoutSec 30
}
$cache = $null
$cacheWarnings = @()
if ($useApi -and $cacheFull) {
  if ($RefreshCache) { $cache = Read-FollowupCache $null } else { $cache = Read-FollowupCache $cacheFull }
  $cacheWarnings = @($cache.warnings)
}
$client = New-FollowupApiClient $httpGet $MaxUnits $cache (Get-Date) $ApiKey
$collected = $null
if ($useApi) {
  $api = New-FollowupCachedApi $client
  $collected = Invoke-StandaloneFollowupCollect $plays $streamers $sitePlaylists $games $api $MaxVideos $ApiKey
  if ($cacheFull) { Write-FollowupCache $client.cache $cacheFull $ApiKey }
}

$index = New-StandaloneGameIndex $games @($streamers | ForEach-Object { $_.name })
$ctx = [pscustomobject]@{ games = $games; index = $index; sitePlaylists = $sitePlaylists; eventPlaylistIds = $eventPlaylistIds; eventNames = $eventNames
  standaloneVideoIds = $standaloneVideoIds; collected = $collected; collabIndex = (New-FollowupCollabIndex $streamers) }
$results = Get-StandaloneFollowupReport $plays $ctx

# ---- 出力 ----
$order = @('STRONG', 'MEDIUM', 'WEAK', 'UNKNOWN', 'NONE')
$counts = [ordered]@{}; foreach ($l in $order) { $counts[$l] = @($results | Where-Object rank -eq $l).Count }
# 0件でも JSON で [] になるよう配列で持つ($() で包むと空配列が消えて {} になるため)
$failures = [object[]]@()
if ($collected) { $failures = [object[]]$collected.failures.ToArray() }
$generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
$unitsByEndpoint = [ordered]@{}; foreach ($k in $client.byEndpoint.Keys) { $unitsByEndpoint[$k] = $client.byEndpoint[$k] }
$cacheInfo = [ordered]@{ file = $(if ($cacheFull -and $useApi) { $cacheFull } else { $null }); loadedEntries = $(if ($cache) { $cache.loaded } else { 0 }); refresh = [bool]$RefreshCache
  hit = $client.stats.hit; miss = $client.stats.miss; expired = $client.stats.expired; reusedByCount = $client.stats.reusedByCount; incremental = $client.stats.incremental
  skippedEmpty = $client.stats.skippedEmpty; warnings = [object[]]@($cacheWarnings) }
$notices = [object[]]@($client.notices.ToArray())
$report = [pscustomobject]@{ generatedAt = $generatedAt; mode = $mode; apiUnits = $client.units; apiUnitsByEndpoint = $unitsByEndpoint; budgetReached = $client.budgetReached
  notices = $notices; cache = $cacheInfo; maxUnits = $MaxUnits; maxVideos = $MaxVideos
  note = "読み取り専用のレポート。データは変更していない。どのランクでも自動移行はしない"; total = $results.Count; counts = $counts
  failures = $failures; results = @($results) }
$json = $report | ConvertTo-Json -Depth 8

$md = New-Object System.Text.StringBuilder
[void]$md.AppendLine("# 単発実況 シリーズ化・専用再生リスト移行候補レポート")
[void]$md.AppendLine("")
[void]$md.AppendLine("- 作成: $generatedAt / 確認方法: $mode / API ユニット: $($client.units)(上限 $MaxUnits$(if ($client.budgetReached) { '。上限に達したため一部を取得していない' })) / 最近の動画: VTuberごとに最大 $MaxVideos 本")
[void]$md.AppendLine("- ユニットの内訳: " + $(if ($unitsByEndpoint.Count) { ($unitsByEndpoint.Keys | ForEach-Object { "$_ $($unitsByEndpoint[$_])" }) -join " / " } else { 'なし' }))
[void]$md.AppendLine("- キャッシュ: " + $(if ($cacheInfo.file) { "読み込み $($cacheInfo.loadedEntries) 件 / 再利用 $($cacheInfo.hit) / 動画数一致で再利用 $($cacheInfo.reusedByCount) / 差分取得 $($cacheInfo.incremental) / 取得 $($cacheInfo.miss) / 期限切れ $($cacheInfo.expired) / 動画数0で省略 $($cacheInfo.skippedEmpty)" } else { '使っていない' }))
foreach ($w in @($cacheWarnings) + @($notices)) { [void]$md.AppendLine("- 注意: $w") }
[void]$md.AppendLine("- 件数: 全 $($results.Count) 件 / " + (($order | ForEach-Object { "$_ $($counts[$_])" }) -join " / "))
[void]$md.AppendLine("- 取得できなかった対象: $($failures.Count) 件")
[void]$md.AppendLine("- **データは変更していない。STRONG でも自動移行はしない**(人が確認して、再生リスト追加と単発実況の整理を同じ commit で行う)")
[void]$md.AppendLine("")
[void]$md.AppendLine("| ID | VTuber | ゲーム | 現在の動画ID | 新規動画候補 | 専用再生リスト候補 | 重複候補 | 要確認 | ランク | 推奨アクション |")
[void]$md.AppendLine("|---|---|---|---|---|---|---|---|---|---|")
$cell = { param($s) ([string]$s).Replace('|', '｜').Replace("`n", ' ') }
foreach ($r in $results) {
  [void]$md.AppendLine("| $($r.id) | $(& $cell $r.streamer) | $(& $cell $r.game) | $($r.videoIds -join ', ') | $(@($r.newVideoCandidates).Count) | $(@($r.playlistCandidates).Count) | $(@($r.duplicateCandidates).Count) | $(@($r.reviewFlags).Count) | **$($r.rank)** | $(& $cell $r.action) |")
}
foreach ($r in $results) {
  [void]$md.AppendLine("")
  [void]$md.AppendLine("## $($r.id) $(& $cell $r.streamer) × $(& $cell $r.game) — $($r.rank)")
  [void]$md.AppendLine("- 現在の動画ID: $($r.videoIds -join ', ') / 推奨アクション: $($r.action)")
  if (@($r.reasons).Count) { [void]$md.AppendLine("- 判定理由:"); foreach ($x in $r.reasons) { [void]$md.AppendLine("  - $(& $cell $x)") } } else { [void]$md.AppendLine("- 判定理由: 該当なし") }
  foreach ($v in $r.newVideoCandidates) { [void]$md.AppendLine("- 新規動画候補: $($v.videoId)「$(& $cell $v.title)」 公開 $($v.publishedAt) / 一致 $($v.matchType)・$($v.confidence)") }
  foreach ($p in $r.playlistCandidates) { [void]$md.AppendLine("- 専用再生リスト候補: $($p.playlistId)「$(& $cell $p.title)」 所有 $(& $cell $p.channel) / $($p.count) 本 / 既存の動画: $(if ($p.videoInPlaylist -eq $true) { 'あり' } elseif ($p.videoInPlaylist -eq $false) { 'なし' } else { '未確認' })$(if ($p.event) { " / 企画名: $($p.event)" })") }
  foreach ($d in $r.duplicateCandidates) { [void]$md.AppendLine("- 重複候補(登録済み): $($d.id)「$(& $cell $d.title)」 game=$(& $cell $d.game) / 既存の動画: $(if ($d.videoInPlaylist -eq $true) { 'あり' } elseif ($d.videoInPlaylist -eq $false) { 'なし' } else { '未確認' })$(if ($d.event) { " / 企画: $($d.event)" })") }
  foreach ($f in @($r.reviewFlags)) { [void]$md.AppendLine("- 要確認(共演・他事務所・企画の疑い): $(& $cell $f)") }
  foreach ($u in $r.unverified) { [void]$md.AppendLine("- 未確認: $(& $cell $u)") }
}
if ($failures.Count) {
  [void]$md.AppendLine(""); [void]$md.AppendLine("## 取得できなかった対象")
  foreach ($f in $failures) { [void]$md.AppendLine("- $(& $cell $f.target): $(& $cell $f.reason)") }
}
$mdText = $md.ToString()

# キーがレポートに紛れ込んでいないことを確認してから保存する
if ($ApiKey -and ($json.Contains($ApiKey) -or $mdText.Contains($ApiKey))) { Write-Error "レポートに APIキーが含まれていたため保存を中止しました"; exit 1 }
if (-not (Test-Path $outFull)) { New-Item -ItemType Directory -Path $outFull -Force | Out-Null }
$utf8 = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $outFull "standalone-followups.json"), $json, $utf8)
[IO.File]::WriteAllText((Join-Path $outFull "standalone-followups.md"), $mdText, $utf8)

Write-Output "=== 単発実況 シリーズ化・専用再生リスト移行候補(読み取り専用) ==="
Write-Output "確認方法: $mode / API ユニット: $($client.units)(上限 $MaxUnits$(if ($client.budgetReached) { '・上限に到達' })) / 内訳: $(if ($unitsByEndpoint.Count) { ($unitsByEndpoint.Keys | ForEach-Object { "$_ $($unitsByEndpoint[$_])" }) -join ', ' } else { 'なし' })"
Write-Output "キャッシュ: $(if ($cacheInfo.file) { "再利用 $($cacheInfo.hit) / 動画数一致で再利用 $($cacheInfo.reusedByCount) / 差分取得 $($cacheInfo.incremental) / 取得 $($cacheInfo.miss) / 期限切れ $($cacheInfo.expired)" } else { '使っていない' })"
foreach ($w in @($cacheWarnings) + @($notices)) { Write-Warning $w }
Write-Output ("全 {0} 件 / STRONG {1} / MEDIUM {2} / WEAK {3} / UNKNOWN {4} / NONE {5} / 取得できなかった対象 {6}" -f $results.Count, $counts['STRONG'], $counts['MEDIUM'], $counts['WEAK'], $counts['UNKNOWN'], $counts['NONE'], $failures.Count)
foreach ($r in $results) { Write-Output ("  [{0}] {1} {2} × {3}{4}" -f $r.rank, $r.id, $r.streamer, $r.game, $(if (@($r.reviewFlags).Count) { " / 要確認: " + (@($r.reviewFlags) -join " / ") } else { "" })) }
Write-Output "レポート: $(Join-Path $outFull 'standalone-followups.md') / .json"
exit 0
