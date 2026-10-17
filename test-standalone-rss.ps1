<#
.SYNOPSIS
  watch-standalone-rss.ps1(RSS からの単発実況候補の抽出)のオフライン回帰テスト。
  YouTube API・RSS の実取得・Node.js は使わない。サンプル RSS は一時フォルダに書き出して使う。
.DESCRIPTION
  本番の data-core.js / data-playlists.js / data-standalone.js は読み取りのみで、変更しない
  (テスト前後でハッシュが同じことも確認する)。出力は一時フォルダにだけ書く。
.EXAMPLE
  .\test-standalone-rss.ps1
#>
param()
$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$watch = Join-Path $scriptDir "watch-standalone-rss.ps1"
$pass = 0; $fail = 0
function Check([string]$name, [bool]$ok, [string]$detail) {
  if ($ok) { $script:pass++; Write-Output "  [PASS] $name" } else { $script:fail++; Write-Output "  [FAIL] $name`n         $detail" }
}

$work = Join-Path ([IO.Path]::GetTempPath()) ("vgame-rss-test-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
$feeds = Join-Path $work "feeds"
New-Item -ItemType Directory -Path $feeds -Force | Out-Null
$out = Join-Path $work "candidates.json"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$dataFiles = @("data-core.js", "data-playlists.js", "data-standalone.js") | ForEach-Object { Join-Path $scriptDir $_ }
$hashBefore = @($dataFiles | ForEach-Object { (Get-FileHash $_ -Algorithm SHA256).Hash })

# ---- サンプル RSS(YouTube チャンネル RSS と同じ構造) ----
function New-Entry([string]$videoId, [string]$title, [string]$published, [string]$description = "") {
  $t = [Security.SecurityElement]::Escape($title); $d = [Security.SecurityElement]::Escape($description)
  return @"
 <entry>
  <id>yt:video:$videoId</id>
  <yt:videoId>$videoId</yt:videoId>
  <title>$t</title>
  <published>$published</published>
  <media:group><media:title>$t</media:title><media:description>$d</media:description></media:group>
 </entry>
"@
}
function New-Feed([string]$channelId, [string[]]$entries) {
  return @"
<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns:yt="http://www.youtube.com/xml/schemas/2015" xmlns:media="http://search.yahoo.com/mrss/" xmlns="http://www.w3.org/2005/Atom">
 <yt:channelId>$channelId</yt:channelId>
 <title>sample</title>
$($entries -join "`n")
</feed>
"@
}
$rui = "UCs9_O1tRPMQTHQ-N_L6FU2g"       # 鷹嶺ルイ(STREAMERS に /channel/UC… で登録)
$sora = "UCp6993wxpyDPHUpavwDFqgg"      # ときのそら(RSS 側は UC を省いた形で書く)
$kanade = "UCtestKanadeAAAAAAAAAAAA"    # 音乃瀬奏(STREAMERS は @ハンドルだけ。対応表で結び付ける。架空のID)
[IO.File]::WriteAllText((Join-Path $feeds "01-rui.xml"), (New-Feed $rui @(
  (New-Entry "uTPPpoWnwl0" "【 利用規約に同意したい 】最速でクリアして最高のクリスマスにしようね☺【鷹嶺ルイ/ ホロライブ】" "2025-12-24T16:00:00+00:00"),
  (New-Entry "RssTest8ex1" "【8番出口】はじめての8番出口【鷹嶺ルイ/ホロライブ】" "2026-10-16T16:30:00+00:00"),
  (New-Entry "RssTest8ex1" "【8番出口】はじめての8番出口【鷹嶺ルイ/ホロライブ】" "2026-10-16T16:30:00+00:00"),
  (New-Entry "RssTestTalk" "【雑談】まったりおしゃべり【鷹嶺ルイ/ホロライブ】" "2026-10-15T12:00:00+00:00"),
  (New-Entry "RssTestMcft" "【Minecraft】拠点づくり【鷹嶺ルイ/ホロライブ】" "2026-10-14T12:00:00+00:00"),
  (New-Entry "RssTestDrqe" "【ドラクエ】ひさしぶりに冒険【鷹嶺ルイ/ホロライブ】" "2026-10-13T12:00:00+00:00")
)), $utf8)
[IO.File]::WriteAllText((Join-Path $feeds "02-sora.xml"), (New-Feed ($sora.Substring(2)) @(
  (New-Entry "RssTestSora" "【8番出口】そらも8番出口【ときのそら/ホロライブ】" "2026-10-12T03:00:00+00:00")
)), $utf8)
[IO.File]::WriteAllText((Join-Path $feeds "03-kanade.xml"), (New-Feed $kanade @(
  (New-Entry "cJ8bg4oeo_8" "【 利用規約に同意したい 】ぺこーら先輩から送られたゲームやってみる！！！！！【音乃瀬奏】" "2026-01-15T11:00:00+00:00"),
  (New-Entry "RssTestKnd8" "【8番出口】奏も8番出口【音乃瀬奏】" "2026-10-11T11:00:00+00:00")
)), $utf8)
[IO.File]::WriteAllText((Join-Path $feeds "04-empty.xml"), (New-Feed $rui @()), $utf8)
[IO.File]::WriteAllText((Join-Path $feeds "05-broken.xml"), "<feed><entry>壊れたXML", $utf8)
[IO.File]::WriteAllText((Join-Path $feeds "06-unknown.xml"), (New-Feed "UCunknownChannelAAAAAAAA" @((New-Entry "RssTestUnkn" "【8番出口】知らないチャンネル" "2026-10-10T00:00:00+00:00"))), $utf8)
$map = Join-Path $work "channel-map.json"
[IO.File]::WriteAllText($map, '[{"streamer":"音乃瀬奏","channelId":"' + $kanade + '"},{"streamer":"登録されていない名前","channelId":"UCunknownChannelAAAAAAAA"}]', $utf8)

function Invoke-Watch([string]$feedDir = $feeds) {
  # 子プロセスのエラー出力でテスト自体が止まらないよう、呼び出す間だけ Continue にして終了コードで判定する
  $ErrorActionPreference = "Continue"
  $o = & powershell -NoProfile -ExecutionPolicy Bypass -File $watch -FeedDir $feedDir -OutFile $out -ChannelMapPath $map 2>&1 | ForEach-Object { "$_" }
  return [pscustomobject]@{ code = $LASTEXITCODE; output = ($o -join "`n") }
}
function Read-Out() { return ([IO.File]::ReadAllText($out, [Text.Encoding]::UTF8)) | ConvertFrom-Json }

Write-Output "== 1回目の実行"
$r1 = Invoke-Watch
Check "1a. 正常終了し、候補ファイルを書き出す" ($r1.code -eq 0 -and (Test-Path $out)) $r1.output
$j1 = Read-Out
$c1 = @($j1.candidates)
$ids1 = @($c1 | ForEach-Object { $_.videoId })
$st = $j1.lastRun.stats
Check "1b. RSS 6件のうち読めたのは4件(壊れ1・未登録チャンネル1を除く。動画0件のRSSは読めた上で警告)" ($st.feeds -eq 6 -and $st.feedsRead -eq 4) ("feeds=$($st.feeds) read=$($st.feedsRead)")
Check "1c. 新規候補は5件(8番出口×3・Minecraft・ドラクエ)" ($c1.Count -eq 5 -and $st.newCandidates -eq 5) ($ids1 -join ",")

$e8 = $c1 | Where-Object videoId -eq "RssTest8ex1"
Check "2a. 動画ID・タイトル・公開日時・チャンネルID・VTuber を取り出す" ($e8 -and $e8.title -like "【8番出口】はじめての8番出口*" -and $e8.publishedAt -eq "2026-10-16T16:30:00+00:00" -and $e8.channelId -eq $rui -and $e8.streamer -eq "鷹嶺ルイ" -and $e8.url -eq "https://www.youtube.com/watch?v=RssTest8ex1") ($e8 | ConvertTo-Json -Compress)
Check "2b. 公開日は日本時間の日付にする(2026-10-16T16:30Z → 2026-10-17)" ($e8.publishedDate -eq "2026-10-17") $e8.publishedDate
Check "2c. ゲーム照合: 【8番出口】は 8番出口・HIGH" ($e8.game -eq "8番出口" -and $e8.confidence -eq "HIGH") ("$($e8.game) $($e8.confidence) $($e8.reasons -join ',')")
Check "2d. 候補はすべて status=pending・playlistVideoCheck=unverified(自動確定しない)" (@($c1 | Where-Object { $_.status -ne "pending" -or $_.playlistVideoCheck -ne "unverified" }).Count -eq 0) ""

Check "3a. STANDALONE_PLAYS 登録済みの動画(uTPPpoWnwl0・cJ8bg4oeo_8)は候補にしない" (-not ($ids1 -contains "uTPPpoWnwl0") -and -not ($ids1 -contains "cJ8bg4oeo_8") -and $st.registeredStandalone -eq 2) ("registered=$($st.registeredStandalone)")
Check "3b. 同じRSS内に同じ動画IDが2回あっても候補は1件" (@($c1 | Where-Object videoId -eq "RssTest8ex1").Count -eq 1) ""
Check "3c. ゲーム名の無い動画(雑談)は候補にしない" (-not ($ids1 -contains "RssTestTalk") -and $st.noGame -ge 1) ""
$mc = $c1 | Where-Object videoId -eq "RssTestMcft"
Check "3d. 同じVTuber×ゲームの再生リストが登録済みなら印を付け、HIGH にしない" ($mc -and $mc.siteHasGamePlaylist -eq $true -and $mc.confidence -ne "HIGH" -and (@($mc.reasons) -contains "同じVTuber×ゲームの再生リストが登録済み")) ($mc | ConvertTo-Json -Compress)
$dq = $c1 | Where-Object videoId -eq "RssTestDrqe"
Check "3e. 複数ゲームで共有される名前(ドラクエ)は HIGH にしない" ($dq -and $dq.confidence -ne "HIGH" -and (@($dq.reasons | Where-Object { $_ -like "複数ゲームで共有される名前*" }).Count -ge 1)) ($dq | ConvertTo-Json -Compress)

$so = $c1 | Where-Object videoId -eq "RssTestSora"
Check "4a. RSS のチャンネルIDが UC を省いた形でも対応付ける" ($so -and $so.streamer -eq "ときのそら" -and $so.channelId -eq $sora) ($so | ConvertTo-Json -Compress)
$kd = $c1 | Where-Object videoId -eq "RssTestKnd8"
Check "4b. @ハンドルだけのVTuberは対応表(-ChannelMapPath)で結び付ける" ($kd -and $kd.streamer -eq "音乃瀬奏") ""
Check "4c. 対応表にあっても STREAMERS に無い名前は使わない(未登録チャンネルとして扱う)" (-not ($ids1 -contains "RssTestUnkn")) ""

$errs = @($j1.lastRun.errors); $warns = @($j1.lastRun.warnings)
Check "5a. 壊れたXMLはエラーとして記録し、ほかのRSSは処理を続ける" (@($errs | Where-Object { $_.file -eq "05-broken.xml" -and $_.reason -eq "XMLとして読めない" }).Count -eq 1) ($errs | ConvertTo-Json -Compress)
Check "5b. 未登録チャンネルのRSSはエラーとして記録する" (@($errs | Where-Object { $_.file -eq "06-unknown.xml" }).Count -eq 1) ""
Check "5c. 動画が1件も無いRSSは警告として記録する" (@($warns | Where-Object { $_.file -eq "04-empty.xml" -and $_.reason -eq "動画が1件も無い" }).Count -eq 1) ($warns | ConvertTo-Json -Compress)

Write-Output "== 2回目の実行(同じRSS)"
Start-Sleep -Seconds 1
$r2 = Invoke-Watch
$j2 = Read-Out
$c2 = @($j2.candidates)
# 検出済みは 6(候補5件 + 同じRSS内で2回出てくる RssTest8ex1 の2回目)
Check "6a. 同じRSSを再処理しても候補は増えない(5件のまま・新規0件)" ($r2.code -eq 0 -and $c2.Count -eq 5 -and $j2.lastRun.stats.newCandidates -eq 0 -and $j2.lastRun.stats.alreadyCandidate -eq 6) ("count=$($c2.Count) new=$($j2.lastRun.stats.newCandidates) already=$($j2.lastRun.stats.alreadyCandidate)")
$e8b = $c2 | Where-Object videoId -eq "RssTest8ex1"
Check "6b. 検出済み候補は firstSeenAt を変えず lastSeenAt だけ更新する" ($e8b.firstSeenAt -eq $e8.firstSeenAt -and $e8b.lastSeenAt -ne $e8.firstSeenAt) ("first=$($e8b.firstSeenAt) last=$($e8b.lastSeenAt)")

Write-Output "== RSS が全部読めない場合"
$feeds2 = Join-Path $work "feeds-broken"
New-Item -ItemType Directory -Path $feeds2 -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $feeds2 "x.xml"), "not xml", $utf8)
[void](Invoke-Watch $feeds2)
$j3 = Read-Out
Check "7a. 取得・解析がすべて失敗しても既存の候補5件は残る" (@($j3.candidates).Count -eq 5 -and @($j3.lastRun.errors).Count -eq 1) ("count=$(@($j3.candidates).Count)")

Write-Output "== 既存の候補ファイルが壊れている場合"
$broken = '{"candidates": [ 壊れたJSON'
[IO.File]::WriteAllText($out, $broken, $utf8)
$r4 = Invoke-Watch
Check "8a. 壊れた候補ファイルは上書きせずに中止する(終了コード≠0・内容そのまま)" ($r4.code -ne 0 -and ([IO.File]::ReadAllText($out, [Text.Encoding]::UTF8)) -eq $broken) ("code=$($r4.code)")
Check "8b. 一時ファイル(.tmp)を残さない" (-not (Test-Path ($out + ".tmp"))) ""

Write-Output "== RSS の取得(モック。ネットワークには接続しない)"
$mockDir = Join-Path $work "mock"
New-Item -ItemType Directory -Path $mockDir -Force | Out-Null
$chMap = ([IO.File]::ReadAllText((Join-Path $scriptDir "streamer-channel-ids.json"), [Text.Encoding]::UTF8)) | ConvertFrom-Json
$kanadeReal = ($chMap | Where-Object streamer -eq "音乃瀬奏").channelId
$roboco = "UCDqI2jOz0weumE8s7paEk6g"   # ロボ子さん(STREAMERS に /channel/UC… で登録)
[IO.File]::WriteAllText((Join-Path $mockDir "rui.xml"), (New-Feed $rui @((New-Entry "RssFetchR01" "【8番出口】取得テスト【鷹嶺ルイ/ホロライブ】" "2026-10-17T03:00:00+00:00"))), $utf8)
[IO.File]::WriteAllText((Join-Path $mockDir "sora.xml"), (New-Feed $sora @((New-Entry "RssFetchS01" "【8番出口】再試行テスト【ときのそら/ホロライブ】" "2026-10-17T04:00:00+00:00"))), $utf8)
[IO.File]::WriteAllText((Join-Path $mockDir "error.html"), "<!DOCTYPE html><html><body>Error</body></html>", $utf8)
$scenario = [ordered]@{}
$scenario[$rui] = @(@{ ok = $true; file = "rui.xml" })
$scenario[$sora] = @(@{ ok = $false; status = 500; reason = "HTTP 500" }, @{ ok = $true; file = "sora.xml" })
$scenario[$kanadeReal] = @(@{ ok = $false; reason = "タイムアウト" }, @{ ok = $false; reason = "タイムアウト" })
$scenario[$roboco] = @(@{ ok = $true; file = "error.html" }, @{ ok = $true; file = "error.html" })
[IO.File]::WriteAllText((Join-Path $mockDir "scenario.json"), ($scenario | ConvertTo-Json -Depth 5), $utf8)
$mockScript = Join-Path $mockDir "mock-request.ps1"
[IO.File]::WriteAllText($mockScript, @'
$script:mockDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:mockScenario = [IO.File]::ReadAllText((Join-Path $script:mockDir "scenario.json"), [Text.Encoding]::UTF8) | ConvertFrom-Json
$script:mockCount = @{}
function Invoke-StandaloneRssRequest([string]$url, [int]$timeoutSec) {
  $cid = [regex]::Match($url, "channel_id=([A-Za-z0-9_-]+)").Groups[1].Value
  $n = 1 + [int]$script:mockCount[$cid]; $script:mockCount[$cid] = $n
  [IO.File]::AppendAllText((Join-Path $script:mockDir "calls.log"), "$url`t$n`t$timeoutSec`n", (New-Object System.Text.UTF8Encoding($false)))
  $steps = @($script:mockScenario.$cid)
  if ($steps.Count -eq 0 -or -not $steps[0]) { return @{ ok = $false; status = 404; reason = "HTTP 404" } }
  $s = $steps[[Math]::Min($n, $steps.Count) - 1]
  if ($s.ok) { return @{ ok = $true; status = 200; content = [IO.File]::ReadAllText((Join-Path $script:mockDir $s.file), [Text.Encoding]::UTF8) } }
  return @{ ok = $false; status = $s.status; reason = $s.reason }
}
'@, (New-Object System.Text.UTF8Encoding($true)))
$fetchDir = Join-Path $work "fetched"
New-Item -ItemType Directory -Path $fetchDir -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $fetchDir "old.xml"), (New-Feed $rui @((New-Entry "RssFetchOld" "【8番出口】前回の取得で残ったファイル" "2026-10-01T00:00:00+00:00"))), $utf8)
$outF = Join-Path $work "fetch-candidates.json"
function Invoke-Fetch([string[]]$names, [string[]]$ids) {
  $ErrorActionPreference = "Continue"
  $a = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $watch, "-FeedDir", $fetchDir, "-OutFile", $outF, "-RequestScript", $mockScript, "-TimeoutSec", "7", "-RetryDelaySeconds", "0", "-RequestIntervalMs", "0")
  if ($names) { $a += "-Streamer"; $a += ($names -join ",") }
  if ($ids) { $a += "-ChannelId"; $a += ($ids -join ",") }
  $o = & powershell @a 2>&1 | ForEach-Object { "$_" }
  return [pscustomobject]@{ code = $LASTEXITCODE; output = ($o -join "`n") }
}
$f1 = Invoke-Fetch @("鷹嶺ルイ", "ときのそら", "音乃瀬奏", "存在しないVTuber") @($roboco, "UCbad")
$jf = ([IO.File]::ReadAllText($outF, [Text.Encoding]::UTF8)) | ConvertFrom-Json
$cf = @($jf.candidates); $idsF = @($cf | ForEach-Object { $_.videoId })
$calls = @(([IO.File]::ReadAllText((Join-Path $mockDir "calls.log"), [Text.Encoding]::UTF8) -split "`n") | Where-Object { $_ })
$callsOf = { param($c) @($calls | Where-Object { $_ -like "*channel_id=$c`t*" }).Count }
$sf = $jf.lastRun.stats; $ef = @($jf.lastRun.errors); $wf = @($jf.lastRun.warnings)
Check "10a. 取得できたRSSだけを解析し、候補2件(ルイ・そら)を追加する" ($f1.code -eq 0 -and $cf.Count -eq 2 -and ($idsF -contains "RssFetchR01") -and ($idsF -contains "RssFetchS01")) ($f1.output)
Check "10b. 取得モードでは保存先に残っていた古いRSSを読まない" (-not ($idsF -contains "RssFetchOld")) ""
Check "10c. 取得先は YouTube 公式のチャンネルフィード・タイムアウト秒数を渡す" (@($calls | Where-Object { $_ -eq ("https://www.youtube.com/feeds/videos.xml?channel_id=$rui`t1`t7") }).Count -eq 1) ($calls -join " | ")
Check "10d. 成功したチャンネルは1回だけ取得し、失敗したチャンネルも2回(1回だけ再試行)で止める" ((& $callsOf $rui) -eq 1 -and (& $callsOf $sora) -eq 2 -and (& $callsOf $kanadeReal) -eq 2 -and (& $callsOf $roboco) -eq 2 -and $calls.Count -eq 7) ($calls -join " | ")
Check "10e. VTuber名は対応表(streamer-channel-ids.json)でチャンネルIDに変換する(ハンドルだけの音乃瀬奏も取得対象)" ((& $callsOf $kanadeReal) -ge 1) ""
Check "10f. 取得できたRSSは保存先に <チャンネルID>.xml で保存し、失敗したものは保存しない" ((Test-Path (Join-Path $fetchDir "$rui.xml")) -and (Test-Path (Join-Path $fetchDir "$sora.xml")) -and -not (Test-Path (Join-Path $fetchDir "$kanadeReal.xml")) -and -not (Test-Path (Join-Path $fetchDir "$roboco.xml"))) ""
Check "10g. 再試行で取得できたチャンネルは警告に1回目の失敗理由を残す" (@($wf | Where-Object { $_.channelId -eq $sora -and $_.reason -like "*HTTP 500*" }).Count -eq 1) ($wf | ConvertTo-Json -Compress)
Check "10h. タイムアウトが続いたチャンネルはエラー(理由・試行2回)として記録する" (@($ef | Where-Object { $_.channelId -eq $kanadeReal -and $_.reason -eq "タイムアウト" -and $_.attempts -eq 2 -and $_.stage -eq "fetch" }).Count -eq 1) ($ef | ConvertTo-Json -Compress)
Check "10i. XMLではない応答が続いたチャンネルはエラーとして記録する" (@($ef | Where-Object { $_.channelId -eq $roboco -and $_.reason -eq "XMLとして読めない応答" }).Count -eq 1) ""
Check "10j. 対応表に無いVTuber名・形式の正しくないチャンネルIDは取得せずエラーにする" (@($ef | Where-Object { $_.streamer -eq "存在しないVTuber" }).Count -eq 1 -and @($ef | Where-Object { $_.channelId -eq "UCbad" }).Count -eq 1) ""
Check "10k. 取得の件数を記録する(対象4・成功2・失敗2・再試行3)" ($sf.fetchTargets -eq 4 -and $sf.fetched -eq 2 -and $sf.fetchFailed -eq 2 -and $sf.retried -eq 3) ($sf | ConvertTo-Json -Compress)
$f2 = Invoke-Fetch @("鷹嶺ルイ", "ときのそら") $null
$jf2 = ([IO.File]::ReadAllText($outF, [Text.Encoding]::UTF8)) | ConvertFrom-Json
Check "10l. 同じRSSを再取得しても候補は増えない" ($f2.code -eq 0 -and @($jf2.candidates).Count -eq 2 -and $jf2.lastRun.stats.newCandidates -eq 0) ("count=$(@($jf2.candidates).Count)")
$f3 = Invoke-Fetch @("音乃瀬奏") $null
$jf3 = ([IO.File]::ReadAllText($outF, [Text.Encoding]::UTF8)) | ConvertFrom-Json
Check "10m. 取得がすべて失敗しても既存の候補は消さない" ($f3.code -eq 0 -and @($jf3.candidates).Count -eq 2 -and $jf3.lastRun.stats.fetchFailed -eq 1) ("count=$(@($jf3.candidates).Count)")

Write-Output "== 誤検出対策(楽曲タイトル・短い英数字名)"
$botan = "UCUKD-uaobj9jiqB-VXt71mA"   # 獅白ぼたん(STREAMERS に /channel/UC… で登録)
$feedsS = Join-Path $work "feeds-stray"
New-Item -ItemType Directory -Path $feedsS -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $feedsS "botan.xml"), (New-Feed $botan @(
  (New-Entry "RssStray001" "Stray&Stay / 獅白ぼたん【original】" "2026-09-19T03:00:00+00:00"),
  (New-Entry "RssStray002" "見るタイプのStray&Stay【獅白ぼたん/ホロライブ】 #shorts" "2026-10-10T03:00:00+00:00"),
  (New-Entry "RssStray003" "【Stray】猫になって街を冒険する【獅白ぼたん/ホロライブ】" "2026-10-11T03:00:00+00:00"),
  (New-Entry "RssStray004" "Stray 実況 はじめての猫ゲーム【獅白ぼたん/ホロライブ】" "2026-10-12T03:00:00+00:00"),
  (New-Entry "RssJpn00001" "【利用規約に同意したい】同意するだけ【獅白ぼたん/ホロライブ】" "2026-10-13T03:00:00+00:00"),
  (New-Entry "tdCaDO2y6N0" "【利用規約に同意したい】利用規約に同意しますん【獅白ぼたん/ホロライブ】" "2025-12-12T15:16:49+00:00"),
  (New-Entry "RssOrig0001" "【original】Minecraft の思い出を歌にした新曲【獅白ぼたん/ホロライブ】" "2026-10-14T03:00:00+00:00")
)), $utf8)
$outS = Join-Path $work "stray-candidates.json"
$ErrorActionPreference = "Continue"
$rs = & powershell -NoProfile -ExecutionPolicy Bypass -File $watch -FeedDir $feedsS -OutFile $outS 2>&1 | ForEach-Object { "$_" }
$ErrorActionPreference = "Stop"
$js = ([IO.File]::ReadAllText($outS, [Text.Encoding]::UTF8)) | ConvertFrom-Json
$cs = @($js.candidates); $idsS = @($cs | ForEach-Object { $_.videoId })
Check "11a. 「Stray&Stay」(楽曲・ショート)は Stray と判定しない" (-not ($idsS -contains "RssStray001") -and -not ($idsS -contains "RssStray002")) (($rs -join " ") + " / " + ($idsS -join ","))
$s3 = $cs | Where-Object videoId -eq "RssStray003"
Check "11b. 【Stray】の実況は Stray・HIGH で検出する" ($s3 -and $s3.game -eq "Stray" -and $s3.confidence -eq "HIGH") ($s3 | ConvertTo-Json -Compress)
$s4 = $cs | Where-Object videoId -eq "RssStray004"
Check "11c. 【】の外の「Stray 実況」も Stray として検出する(短い英数字名なので HIGH にはしない)" ($s4 -and $s4.game -eq "Stray" -and $s4.confidence -ne "HIGH") ($s4 | ConvertTo-Json -Compress)
$s6 = $cs | Where-Object videoId -eq "RssJpn00001"
Check "11d. 日本語の作品名(【利用規約に同意したい】)は従来どおり HIGH" ($s6 -and $s6.game -eq "利用規約に同意したい" -and $s6.confidence -eq "HIGH") ($s6 | ConvertTo-Json -Compress)
Check "11e. 登録済みの単発実況(tdCaDO2y6N0)は引き続き除外する" (-not ($idsS -contains "tdCaDO2y6N0") -and $js.lastRun.stats.registeredStandalone -eq 1) ""
$s8 = $cs | Where-Object videoId -eq "RssOrig0001"
Check "11f. 【original】の動画はゲーム名が一致しても LOW(非ゲーム語)にする" ($s8 -and $s8.confidence -eq "LOW" -and (@($s8.reasons) -contains "非ゲーム語: original")) ($s8 | ConvertTo-Json -Compress)

Write-Output "== 未登録作品の候補(unknownGames)"
$feedsU = Join-Path $work "feeds-unknown"
New-Item -ItemType Directory -Path $feedsU -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $feedsU "botan.xml"), (New-Feed $botan @(
  (New-Entry "UnkGears001" "ガチムチ達のプランBが帰ってきたぞ～っ！－Gears of War: E-Day【獅白ぼたん/ホロライブ】" "2026-10-16T12:00:00+00:00" "PvEモード「Horde Siege」も後でやりたいです"),
  (New-Entry "UnkRamen001" "お店の売上金がなぜか合わないJapanese Ramen Simulator【獅白ぼたん/ホロライブ】" "2026-10-11T12:00:00+00:00" "麺屋ぼたん オープンしました"),
  (New-Entry "UnkRamen002" "ワンオペで挑むJapanese Ramen Simulator【獅白ぼたん/ホロライブ】" "2026-10-10T12:00:00+00:00" "まずバイトを雇います"),
  (New-Entry "UnkWardog01" "【WARDOGS】話題の100人対戦FPS！レベルあげていきたい～！【獅白ぼたん/ホロライブ】" "2026-09-16T12:00:00+00:00" "まずはレベルをあげたい！！"),
  (New-Entry "UnkHoloDr01" "【ホロドリ】「ぽ」と「ら」と「り」を引く！！！！【獅白ぼたん/ホロライブ】" "2026-10-08T12:00:00+00:00" "獅白ぼたんがホロドリをあそびます"),
  (New-Entry "UnkStrayer1" "【Strayer】はじめての実況【獅白ぼたん/ホロライブ】" "2026-10-07T12:00:00+00:00"),
  (New-Entry "UnkNotGm001" "【#ホロドリ釣り名人】だからやってみろ、必ず目標を達成できる！【獅白ぼたん/ホロライブ】" "2026-10-15T12:00:00+00:00" "ゲーム内イベント"),
  (New-Entry "UnkNotGm002" "【Steamオータムセール】まだ神ゲー間に合うか！？Steamのセール見ていくぞ～【獅白ぼたん/ホロライブ】" "2026-10-03T12:00:00+00:00" "ゲームを紹介"),
  (New-Entry "UnkNotGm003" "【雑談】最近の振り返り雑談！いろいろあるぞ～～～～～っ【獅白ぼたん/ホロライブ】" "2026-09-27T12:00:00+00:00" "ゲームの話も"),
  (New-Entry "UnkNotGm004" "ロボ子さんの『現世アリス』dance【獅白ぼたん/ホロライブ】✨#ロボ子さん #現世アリス #shorts #dance  #hololive" "2026-09-24T12:00:00+00:00"),
  (New-Entry "UnkNotGm005" "【 #ねぽっくす まであと6日】💜💜#shorts" "2026-09-19T12:00:00+00:00"),
  (New-Entry "UnkNotGm006" "【 #獅白ぼたん生誕祭2026 】重大告知あります！獅白ぼたん生誕3D LIVE✨『Stray&Stay』【獅白ぼたん/ホロライブ】" "2026-09-18T12:00:00+00:00"),
  (New-Entry "UnkNotGm007" "Stray&Stay / 獅白ぼたん【original】" "2026-09-19T12:00:00+00:00"),
  (New-Entry "UnkNotGm008" "おゆいさんと #めろぞーま 🩵#shorts #SWEETSTEADY #すいすて" "2026-09-17T12:00:00+00:00"),
  (New-Entry "UnkNotGm009" "【キオクシア】ししろん先生が教える！PC ストレージ教室！【獅白ぼたん/ホロライブ】" "2026-09-16T12:00:00+00:00" "ご紹介した商品")
)), $utf8)
$outU = Join-Path $work "unknown-candidates.json"
$ErrorActionPreference = "Continue"
$ru = & powershell -NoProfile -ExecutionPolicy Bypass -File $watch -FeedDir $feedsU -OutFile $outU 2>&1 | ForEach-Object { "$_" }
$ErrorActionPreference = "Stop"
$ju = ([IO.File]::ReadAllText($outU, [Text.Encoding]::UTF8)) | ConvertFrom-Json
$ug = @($ju.unknownGames)
$ugOf = { param($name) $ug | Where-Object name -eq $name }
$gGears = & $ugOf "Gears of War: E-Day"; $gRamen = & $ugOf "Japanese Ramen Simulator"; $gWar = & $ugOf "WARDOGS"
Check "12a. Gears of War: E-Day は1本(説明欄の PvE だけが手がかりなので LOW)" ($gGears -and $gGears.videoCount -eq 1 -and $gGears.confidence -eq "LOW") (($ru -join " ") + " / " + ($ug | ForEach-Object { "$($_.name)=$($_.videoCount)" }) -join ",")
Check "12b. Japanese Ramen Simulator は2本(作品名ごとにまとめ、MEDIUM)" ($gRamen -and $gRamen.videoCount -eq 2 -and $gRamen.confidence -eq "MEDIUM" -and @($gRamen.videos | ForEach-Object { $_.videoId }).Count -eq 2) ($gRamen | ConvertTo-Json -Compress -Depth 5)
Check "12c. WARDOGS は1本(【】の語 + タイトルの FPS で MEDIUM)" ($gWar -and $gWar.videoCount -eq 1 -and $gWar.confidence -eq "MEDIUM") ($gWar | ConvertTo-Json -Compress -Depth 5)
$unkVideoIds = @($ug | ForEach-Object { $_.videos } | ForEach-Object { $_.videoId })
Check "12d. 雑談・セール・ハッシュタグの【】・ショート・dance・告知・楽曲・ゲームを表す語の無い【】(企業名)は候補にしない" (@($unkVideoIds | Where-Object { $_ -like "UnkNotGm*" }).Count -eq 0) ($unkVideoIds -join ",")
$gHolo = & $ugOf "ホロドリ"
Check "12e. 説明欄にだけゲームを表す語がある【】の語は LOW で確認待ちにする" ($gHolo -and $gHolo.confidence -eq "LOW" -and $gHolo.status -eq "pending") ($gHolo | ConvertTo-Json -Compress -Depth 5)
$gStrayer = & $ugOf "Strayer"
Check "12f. 既存作品と名前が一部一致する候補には表記揺れの可能性(possibleExisting)を記録する" ($gStrayer -and (@($gStrayer.possibleExisting) -contains "Stray")) ($gStrayer | ConvertTo-Json -Compress -Depth 5)
Check "12g. 候補はすべて status=pending・信頼度は MEDIUM まで(HIGH にしない)" (@($ug | Where-Object { $_.status -ne "pending" -or $_.confidence -eq "HIGH" }).Count -eq 0 -and $ug.Count -eq 5) ("count=$($ug.Count)")
Check "12h. 既存作品の候補(candidates)には入れない" (@($ju.candidates).Count -eq 0) ""
$ErrorActionPreference = "Continue"
[void](& powershell -NoProfile -ExecutionPolicy Bypass -File $watch -FeedDir $feedsU -OutFile $outU 2>&1)
$ErrorActionPreference = "Stop"
$ju2 = ([IO.File]::ReadAllText($outU, [Text.Encoding]::UTF8)) | ConvertFrom-Json
$gRamen2 = $ju2.unknownGames | Where-Object name -eq "Japanese Ramen Simulator"
Check "12i. 同じRSSを再処理しても同じ動画は二重に追加しない(作品数・本数とも変わらない)" (@($ju2.unknownGames).Count -eq 5 -and $gRamen2.videoCount -eq 2 -and $ju2.lastRun.stats.unknownGameVideos -eq 0) ("count=$(@($ju2.unknownGames).Count) ramen=$($gRamen2.videoCount)")

$hashAfter = @($dataFiles | ForEach-Object { (Get-FileHash $_ -Algorithm SHA256).Hash })
Check "9a. 本番の data-core.js / data-playlists.js / data-standalone.js を変更しない" (($hashBefore -join ",") -eq ($hashAfter -join ",")) ""

Remove-Item -LiteralPath $work -Recurse -Force
Write-Output ""
Write-Output "PASS: $pass  FAIL: $fail"
if ($fail -gt 0) { exit 1 }
