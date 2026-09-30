<#
.SYNOPSIS
  単発実況(STANDALONE_PLAYS)のうち、後日ゲーム専用の再生リストができて
  再生リスト方式へ移行すべき可能性があるものを検出する(読み取り専用)。

.DESCRIPTION
  STANDALONE_PLAYS の全件について、STRONG / MEDIUM / WEAK / NONE を判定して表示する。
  判定ロジックは standalone-matching.ps1 の Get-StandaloneMigrationStatus(条件は同ファイルの説明を参照)。

    STRONG : 同じVTuber × 同じgame の登録済み再生リストがあり、単発実況の動画もその中にある
    MEDIUM : 同じVTuber × 同じgame の登録済み再生リストはあるが、動画が中に無い / 確認していない
    WEAK   : VTuber × game を確定できないが関連の可能性がある(自動移行の対象には絶対にしない)
    NONE   : 該当なし(正常)

  このスクリプトはデータを一切変更しない(STANDALONE_PLAYS・PLAYLISTS・GAMES・生成データ)。
  STRONG でも自動削除はしない。移行するときは人が確認し、
  「再生リスト追加 + 単発実況削除 + 派生データ再生成」を同じ commit で行う
  (単発実況だけのVTuberで削除を先にすると、そのVTuberページが noindex・sitemap除外になるため)。

  役割分担:
    - このaudit     : 後日再生リスト化した可能性を早めに見つける(候補の報告だけ)
    - validate-data : 同じVTuber × game の再生リストと単発実況が両方入ったデータを ERROR にする(本番投入の関所)
  再生リストを追加した後(run-playlist-cycle.ps1 の結果を取り込んだ後など)に実行すると効果的。

  YouTube API:
    - 既定: APIキーがあれば、STRONG/MEDIUM 判定に使う再生リスト(同じVTuber × game)の動画だけ確認する。
            該当が無ければ API は呼ばない
    - -Offline      : API を使わない(動画の有無は「確認していない」扱いで MEDIUM)
    - -ChannelScan  : チャンネル側のサイト未登録の再生リストも調べて WEAK を出す(VTuberごとに数ユニット)

.PARAMETER Json
  結果をJSONで保存するパス(例: reports\standalone-migration.json。reports\ は git 管理外)。
.PARAMETER Offline
  YouTube API を使わない。
.PARAMETER ChannelScan
  チャンネル側のサイト未登録の再生リストも調べる。
.PARAMETER ShowAll
  NONE も含めて全件の詳細を表示する。
.PARAMETER ApiKey
  YouTube Data API v3 のAPIキー。省略時は環境変数 YOUTUBE_API_KEY。

.EXAMPLE
  .\audit-standalone-migration.ps1
.EXAMPLE
  .\audit-standalone-migration.ps1 -ChannelScan -Json reports\standalone-migration.json
#>
param(
  [string]$Json,
  [switch]$Offline,
  [switch]$ChannelScan,
  [switch]$ShowAll,
  [string]$ApiKey = $env:YOUTUBE_API_KEY
)
$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "standalone-matching.ps1")

# 出力先がデータ・生成物にならないようにする(読み取り専用を保証)
if ($Json) {
  $jsonFull = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($Json)) { $Json } else { Join-Path (Get-Location) $Json }))
  if ([IO.Path]::GetExtension($jsonFull) -ne ".json" -or $jsonFull.StartsWith([IO.Path]::GetFullPath((Join-Path $scriptDir "data")) + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    Write-Error "-Json には data\ 以外の .json ファイルを指定してください: $Json"; exit 1
  }
}
if ($ChannelScan -and $Offline) { Write-Error "-ChannelScan は YouTube API を使うため -Offline と同時に指定できません"; exit 1 }
$useApi = (-not $Offline) -and [bool]$ApiKey
if ($ChannelScan -and -not $useApi) { Write-Error "-ChannelScan には APIキー(-ApiKey または環境変数 YOUTUBE_API_KEY)が必要です"; exit 1 }

# ---- データ読み込み: generate-detail-data.js と同じく、データファイルを node の vm で実行して取り出す ----
# (正規表現パーサーを増やさないため。出力は ASCII にエスケープして文字コードの問題を避ける)
$loader = @'
const fs = require("fs"), path = require("path"), vm = require("vm");
const root = process.argv[process.argv.length - 1], ctx = {};
vm.createContext(ctx);
for (const f of ["data-core.js", "data-playlists.js", "data-standalone.js"]) vm.runInContext(fs.readFileSync(path.join(root, f), "utf8"), ctx, { filename: f });
const pick = (n) => vm.runInContext("typeof " + n + " === 'undefined' ? [] : " + n, ctx);
const out = {
  streamers: pick("STREAMERS").map((s) => ({ name: s.name, youtube: s.youtube || "" })),
  games: pick("GAMES").map((g) => ({ name: g.name, aliases: [g.name].concat(g.nameJa ? [g.nameJa] : [], g.aliases || []) })),
  playlists: pick("PLAYLISTS").map((p) => ({ id: p.id, title: p.title, streamer: p.streamer, game: p.game, playlistId: p.playlistId })),
  standalone: pick("STANDALONE_PLAYS").map((p) => ({ id: p.id, streamer: p.streamer, game: p.game, format: p.format, videos: (p.videos || []).map((v) => ({ url: v.url })) })),
};
const esc = (c) => String.fromCharCode(92) + "u" + c.charCodeAt(0).toString(16).padStart(4, "0");
process.stdout.write(JSON.stringify(out).replace(/[^ -~]/g, esc));
'@
# スクリプトは標準入力で渡す(PowerShell 5.1 はコマンドライン引数の中の " を正しく渡せないため)。
# loader は ASCII のみ・バックスラッシュなしで書く(標準入力を通すと ASCII 以外や一部のエスケープが崩れるため)
$raw = $loader | & node - $scriptDir
if ($LASTEXITCODE -ne 0 -or -not $raw) { Write-Error "データの読み込みに失敗しました(node が必要です)"; exit 1 }
$data = ($raw -join "") | ConvertFrom-Json
$streamers = @($data.streamers | ForEach-Object { $_ })
$games = @($data.games | ForEach-Object { [pscustomobject]@{ name = $_.name; aliases = @($_.aliases | ForEach-Object { $_ }) } })
$sitePlaylists = @($data.playlists | ForEach-Object { $_ })
$plays = @($data.standalone | ForEach-Object { [pscustomobject]@{ id = $_.id; streamer = $_.streamer; game = $_.game; format = $_.format; videos = @($_.videos | ForEach-Object { $_ }) } })

# ---- YouTube API(読み取りのみ。キーは表示しない) ----
$script:units = 0
function ApiGet([string]$url) {
  $script:units++
  try { Invoke-RestMethod -Uri ($url + "&key=" + [uri]::EscapeDataString($ApiKey)) -Method Get }
  catch { throw ($_.Exception.Message -replace [regex]::Escape($ApiKey), "***") }
}
function Get-PlaylistVideoIds([string]$playlistId) {
  $ids = @(); $token = $null
  do {
    $u = "https://www.googleapis.com/youtube/v3/playlistItems?part=contentDetails&maxResults=50&playlistId=$([uri]::EscapeDataString($playlistId))"
    if ($token) { $u += "&pageToken=$([uri]::EscapeDataString($token))" }
    $r = ApiGet $u
    $ids += @($r.items | ForEach-Object { $_.contentDetails.videoId }); $token = $r.nextPageToken
  } while ($token)
  return , $ids
}
function Get-ChannelPlaylists([string]$youtubeUrl) {
  $channelId = $null
  $m = [regex]::Match($youtubeUrl, '/channel/(UC[A-Za-z0-9_-]+)')
  if ($m.Success) { $channelId = $m.Groups[1].Value }
  else {
    $h = [regex]::Match($youtubeUrl, '/(@[^/?#]+)')
    if ($h.Success) { $r = ApiGet ("https://www.googleapis.com/youtube/v3/channels?part=id&forHandle=" + [uri]::EscapeDataString($h.Groups[1].Value)); if ($r.items) { $channelId = $r.items[0].id } }
  }
  if (-not $channelId) { return $null }
  $pls = @(); $token = $null
  do {
    $u = "https://www.googleapis.com/youtube/v3/playlists?part=snippet,contentDetails&maxResults=50&channelId=$channelId"
    if ($token) { $u += "&pageToken=$([uri]::EscapeDataString($token))" }
    $r = ApiGet $u
    $pls += @($r.items | ForEach-Object { [pscustomobject]@{ id = $_.id; title = $_.snippet.title; count = $_.contentDetails.itemCount } }); $token = $r.nextPageToken
  } while ($token)
  return , $pls
}

$playlistVideos = @{}
$warnings = @()
if ($useApi) {
  # 動画の有無を確認するのは、STRONG/MEDIUM の判定に使う「同じVTuber × game」の再生リストだけ
  $targets = @($sitePlaylists | Where-Object { $pl = $_; @($plays | Where-Object { $_.streamer -eq $pl.streamer -and $_.game -eq $pl.game }).Count -gt 0 })
  foreach ($pl in $targets) {
    try { $playlistVideos[$pl.playlistId] = Get-PlaylistVideoIds $pl.playlistId }
    catch { $warnings += "再生リストの動画を取得できません($($pl.id) $($pl.playlistId)): $($_.Exception.Message)" }
  }
}

$channelCache = @{}
$results = @()
foreach ($play in $plays) {
  $channelPls = $null
  if ($ChannelScan) {
    if (-not $channelCache.ContainsKey($play.streamer)) {
      $st = $streamers | Where-Object name -eq $play.streamer | Select-Object -First 1
      $cp = $null
      try { if ($st -and $st.youtube) { $cp = Get-ChannelPlaylists $st.youtube } } catch { $warnings += "チャンネルの再生リストを取得できません($($play.streamer)): $($_.Exception.Message)" }
      $channelCache[$play.streamer] = $cp
    }
    $channelPls = $channelCache[$play.streamer]
    # ゲーム名入りの未登録再生リストは、動画が入っているかも確認する
    if ($channelPls) {
      $registeredIds = @($sitePlaylists | ForEach-Object { $_.playlistId })
      foreach ($cp in @(Get-StandaloneDedicatedPlaylists $games $play.game @($channelPls | Where-Object { $registeredIds -notcontains $_.id }))) {
        if (-not $playlistVideos.ContainsKey($cp.id)) {
          try { $playlistVideos[$cp.id] = Get-PlaylistVideoIds $cp.id } catch { $warnings += "再生リストの動画を取得できません($($cp.id)): $($_.Exception.Message)" }
        }
      }
    }
  }
  $results += Get-StandaloneMigrationStatus $play $sitePlaylists $games $playlistVideos $channelPls
}

# ---- 出力(要約 → STRONG / MEDIUM / WEAK の詳細。NONE は -ShowAll のときだけ) ----
$order = @('STRONG', 'MEDIUM', 'WEAK', 'NONE')
$counts = [ordered]@{}; foreach ($l in $order) { $counts[$l] = @($results | Where-Object level -eq $l).Count }
$mode = $(if ($ChannelScan) { "API(登録済み再生リスト + チャンネル側)" } elseif ($useApi) { "API(登録済み再生リストの動画のみ)" } else { "オフライン(動画の有無は未確認)" })
Write-Output "=== 単発実況 → 再生リスト移行 audit(読み取り専用) ==="
Write-Output "確認方法: $mode / APIユニット: $script:units"
Write-Output ("総件数 {0} / STRONG {1} / MEDIUM {2} / WEAK {3} / NONE {4}" -f $results.Count, $counts['STRONG'], $counts['MEDIUM'], $counts['WEAK'], $counts['NONE'])
# 表示順: 判定レベル(STRONG → NONE)、同じレベルの中は STANDALONE_PLAYS の並び順
$shown = for ($i = 0; $i -lt $results.Count; $i++) { if ($ShowAll -or $results[$i].level -ne 'NONE') { [pscustomobject]@{ r = $results[$i]; lv = [array]::IndexOf($order, $results[$i].level); i = $i } } }
foreach ($r in @($shown | Sort-Object lv, i | ForEach-Object { $_.r })) {
  Write-Output ""
  Write-Output ("[{0}] {1}  {2} × {3}  video: {4}" -f $r.level, $r.id, $r.streamer, $r.game, ($r.videoIds -join ","))
  foreach ($p in $r.playlists) {
    $inText = $(if ($p.videoInPlaylist -eq $true) { "動画あり" } elseif ($p.videoInPlaylist -eq $false) { "動画なし" } else { "動画未確認" })
    $label = $(if ($p.source -eq 'site') { "登録済み $($p.id)" } else { "チャンネル側(未登録)" })
    Write-Output ("    再生リスト: {0}「{1}」 {2} / {3}" -f $label, $p.title, $p.playlistId, $inText)
  }
  foreach ($reason in $r.reasons) { Write-Output "    理由: $reason" }
}
if ($counts['STRONG'] + $counts['MEDIUM'] + $counts['WEAK'] -gt 0) {
  Write-Output ""
  Write-Output "※ データは変更していません。移行は人が確認し、再生リスト追加と単発実況削除を同じ commit で行ってください。"
}
foreach ($w in $warnings) { Write-Warning $w }

if ($Json) {
  $dir = Split-Path -Parent $jsonFull
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  [pscustomobject]@{
    generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss"); mode = $mode; apiUnits = $script:units
    total = $results.Count; counts = $counts; warnings = @($warnings); results = @($results)
  } | ConvertTo-Json -Depth 6 | Set-Content -Path $jsonFull -Encoding UTF8
  Write-Output ""
  Write-Output "JSON: $jsonFull"
}
exit 0
