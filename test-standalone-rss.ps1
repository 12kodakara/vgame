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
# テスト対象は、このテストを動かしている PowerShell と同じもの(Windows PowerShell 5.1 / PowerShell 7 の pwsh)で起動する
$psExe = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
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
  $o = & $psExe -NoProfile -ExecutionPolicy Bypass -File $watch -FeedDir $feedDir -OutFile $out -ChannelMapPath $map 2>&1 | ForEach-Object { "$_" }
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
  $o = & $psExe @a 2>&1 | ForEach-Object { "$_" }
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
$rs = & $psExe -NoProfile -ExecutionPolicy Bypass -File $watch -FeedDir $feedsS -OutFile $outS 2>&1 | ForEach-Object { "$_" }
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
$ru = & $psExe -NoProfile -ExecutionPolicy Bypass -File $watch -FeedDir $feedsU -OutFile $outU 2>&1 | ForEach-Object { "$_" }
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
[void](& $psExe -NoProfile -ExecutionPolicy Bypass -File $watch -FeedDir $feedsU -OutFile $outU 2>&1)
$ErrorActionPreference = "Stop"
$ju2 = ([IO.File]::ReadAllText($outU, [Text.Encoding]::UTF8)) | ConvertFrom-Json
$gRamen2 = $ju2.unknownGames | Where-Object name -eq "Japanese Ramen Simulator"
Check "12i. 同じRSSを再処理しても同じ動画は二重に追加しない(作品数・本数とも変わらない)" (@($ju2.unknownGames).Count -eq 5 -and $gRamen2.videoCount -eq 2 -and $ju2.lastRun.stats.unknownGameVideos -eq 0) ("count=$(@($ju2.unknownGames).Count) ramen=$($gRamen2.videoCount)")

Write-Output "== 複数チャンネルの巡回(-All。モック)"
$rows = @($chMap)
$c0 = $rows[0].channelId; $c1 = $rows[1].channelId; $c2 = $rows[2].channelId; $c3 = $rows[3].channelId; $c4 = $rows[4].channelId
$mockDir2 = Join-Path $work "mock-crawl"
New-Item -ItemType Directory -Path $mockDir2 -Force | Out-Null
Copy-Item -LiteralPath $mockScript -Destination (Join-Path $mockDir2 "mock-request.ps1")
[IO.File]::WriteAllText((Join-Path $mockDir2 "c0.xml"), (New-Feed $c0 @((New-Entry "Crawl0Game1" "【8番出口】巡回テスト" "2026-10-17T01:00:00+00:00"))), $utf8)
[IO.File]::WriteAllText((Join-Path $mockDir2 "c2.xml"), (New-Feed $c2 @((New-Entry "Crawl2Unkn1" "【WARDOGS】話題の100人対戦FPS！" "2026-10-17T02:00:00+00:00"))), $utf8)
[IO.File]::WriteAllText((Join-Path $mockDir2 "c3.xml"), (New-Feed $c3 @((New-Entry "Crawl3Talk1" "【雑談】まったり" "2026-10-17T03:00:00+00:00"))), $utf8)
[IO.File]::WriteAllText((Join-Path $mockDir2 "c4.xml"), (New-Feed $c4 @((New-Entry "Crawl4Game1" "【8番出口】もうひとり" "2026-10-17T04:00:00+00:00"))), $utf8)
$sc2 = [ordered]@{}
$sc2[$c0] = @(@{ ok = $true; file = "c0.xml" })
$sc2[$c1] = @(@{ ok = $false; status = 500; reason = "HTTP 500" }, @{ ok = $false; status = 500; reason = "HTTP 500" })
$sc2[$c2] = @(@{ ok = $true; file = "c2.xml" })
$sc2[$c3] = @(@{ ok = $true; file = "c3.xml" })
$sc2[$c4] = @(@{ ok = $true; file = "c4.xml" })
[IO.File]::WriteAllText((Join-Path $mockDir2 "scenario.json"), ($sc2 | ConvertTo-Json -Depth 5), $utf8)
$fetchDir2 = Join-Path $work "fetched-crawl"
$outC = Join-Path $work "crawl-candidates.json"
function Invoke-Crawl([string[]]$extra) {
  $ErrorActionPreference = "Continue"
  $a = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $watch, "-FeedDir", $fetchDir2, "-OutFile", $outC, "-RequestScript", (Join-Path $mockDir2 "mock-request.ps1"), "-RetryDelaySeconds", "0", "-RequestIntervalMs", "0") + $extra
  $o = & $psExe @a 2>&1 | ForEach-Object { "$_" }
  return [pscustomobject]@{ code = $LASTEXITCODE; output = ($o -join "`n") }
}
$callsLog2 = Join-Path $mockDir2 "calls.log"
function Get-Calls2() { if (Test-Path $callsLog2) { return @(([IO.File]::ReadAllText($callsLog2, [Text.Encoding]::UTF8) -split "`n") | Where-Object { $_ }) } else { return @() } }
$k1 = Invoke-Crawl @("-All")
$jc = ([IO.File]::ReadAllText($outC, [Text.Encoding]::UTF8)) | ConvertFrom-Json
$sc = $jc.lastRun.stats; $calls2 = Get-Calls2
$callsTo = { param($c) @($calls2 | Where-Object { $_ -like "*channel_id=$c`t*" }).Count }
Check "13a. -All は件数を指定しなければ対応表の先頭3チャンネルだけを巡回する" ($k1.code -eq 0 -and $sc.fetchTargets -eq 3 -and (& $callsTo $c0) -eq 1 -and (& $callsTo $c1) -eq 2 -and (& $callsTo $c2) -eq 1 -and (& $callsTo $c3) -eq 0 -and $sc.crawlTotal -eq 293 -and $sc.crawlNextIndex -eq 3) ($k1.output)
Check "13b. 途中のチャンネルが失敗しても残りを処理する(成功2・失敗1、失敗はエラーに記録)" ($sc.fetched -eq 2 -and $sc.fetchFailed -eq 1 -and @($jc.lastRun.errors | Where-Object { $_.channelId -eq $c1 -and $_.reason -eq "HTTP 500" }).Count -eq 1) ($jc.lastRun.errors | ConvertTo-Json -Compress)
Check "13c. 作品名の照合・未登録作品の候補を巡回でも行う(8番出口の候補・WARDOGS の未登録候補)" (@($jc.candidates | Where-Object videoId -eq "Crawl0Game1").Count -eq 1 -and @($jc.unknownGames | Where-Object name -eq "WARDOGS").Count -eq 1) ""
Check "13d. 対象・成功・失敗・新規候補・未登録作品候補の件数を表示する" ($k1.output -match "巡回: 対象 3 チャンネル / 成功 2 / 失敗 1\(再試行 1\)  新規候補 1 / 未登録作品の候補 1 本") ($k1.output)
$k2 = Invoke-Crawl @("-All")
$jc2 = ([IO.File]::ReadAllText($outC, [Text.Encoding]::UTF8)) | ConvertFrom-Json
Check "13e. 同じ範囲を再巡回しても候補・未登録作品の候補は重複しない" ($k2.code -eq 0 -and @($jc2.candidates).Count -eq 1 -and @($jc2.unknownGames).Count -eq 1 -and $jc2.lastRun.stats.newCandidates -eq 0 -and $jc2.lastRun.stats.unknownGameVideos -eq 0) ("cand=$(@($jc2.candidates).Count) unknown=$(@($jc2.unknownGames).Count)")
$before = (Get-Calls2).Count
$k3 = Invoke-Crawl @("-All", "-StartIndex", "3", "-MaxChannels", "2")
$calls2 = @(Get-Calls2 | Select-Object -Skip $before)
$jc3 = ([IO.File]::ReadAllText($outC, [Text.Encoding]::UTF8)) | ConvertFrom-Json
Check "13f. -StartIndex と -MaxChannels で巡回範囲を指定でき、次回の開始位置を記録する" ($k3.code -eq 0 -and $calls2.Count -eq 2 -and (& $callsTo $c3) -eq 1 -and (& $callsTo $c4) -eq 1 -and $jc3.lastRun.stats.crawlNextIndex -eq 5 -and @($jc3.candidates | Where-Object videoId -eq "Crawl4Game1").Count -eq 1) ($k3.output)
Check "13g. 前回までの候補は残したまま追記する" (@($jc3.candidates).Count -eq 2 -and @($jc3.unknownGames).Count -eq 1) ("cand=$(@($jc3.candidates).Count)")
$before = (Get-Calls2).Count
$k4 = Invoke-Crawl @("-All", "-Streamer", "鷹嶺ルイ")
Check "13h. -All と -Streamer の同時指定はエラーにして何も取得しない" ($k4.code -ne 0 -and (Get-Calls2).Count -eq $before) ($k4.output)

Write-Output "== 説明欄の定型部分・再生リストとの重複・配信の種類"
$feedsT = Join-Path $work "feeds-template"
New-Item -ItemType Directory -Path $feedsT -Force | Out-Null
$promo = "🎧オリジナル楽曲『モノポリー』https://example.invalid/song"   # チャンネルの宣伝(話題の違う動画に共通する定型行)
$series = "ARK: Survival Ascended を遊びます"                       # シリーズの動画にだけ出てくる行
[IO.File]::WriteAllText((Join-Path $feedsT "rui.xml"), (New-Feed $rui @(
  (New-Entry "TplTalk0001" "【雑談】まったりおしゃべり" "2026-10-17T01:00:00+00:00" "今日の話`n$promo"),
  (New-Entry "TplNaipa001" "【#ナイパレ｜第3回】あなたはどっち？" "2026-10-16T01:00:00+00:00" "企画です`n$promo"),
  (New-Entry "TplBigW0001" "【 Big Walk 】4人で協力" "2026-10-15T01:00:00+00:00" "みんなで歩く`n$promo"),
  (New-Entry "TplArk00001" "【 #ホロ鯖ARK 】DAY3 拠点づくり" "2026-10-14T01:00:00+00:00" "$series`n$promo"),
  (New-Entry "TplArk00002" "【 #ホロ鯖ARK 】DAY4 テイム" "2026-10-13T01:00:00+00:00" "$series`n$promo"),
  (New-Entry "TplArk00003" "【 #ホロ鯖ARK 】DAY5 拡張" "2026-10-12T01:00:00+00:00" $series),
  (New-Entry "TplMcSeq001" "【Minecraft】拠点づくり #2【鷹嶺ルイ/ホロライブ】" "2026-10-11T01:00:00+00:00"),
  (New-Entry "TplOffco001" "【オフコラボ】ごはん会【鷹嶺ルイ/ホロライブ】" "2026-10-10T01:00:00+00:00" "ゲームもするかも")
)), $utf8)
$outT = Join-Path $work "template-candidates.json"
$ErrorActionPreference = "Continue"
[void](& $psExe -NoProfile -ExecutionPolicy Bypass -File $watch -FeedDir $feedsT -OutFile $outT 2>&1)
$ErrorActionPreference = "Stop"
$jt = ([IO.File]::ReadAllText($outT, [Text.Encoding]::UTF8)) | ConvertFrom-Json
$ct = @($jt.candidates)
Check "14a. 話題の違う3本以上に共通する宣伝の行(『モノポリー』)だけでは候補にしない" (@($ct | Where-Object game -eq "モノポリー").Count -eq 0) (($ct | ForEach-Object { "$($_.videoId)=$($_.game)" }) -join ",")
$arkC = @($ct | Where-Object { $_.videoId -like "TplArk*" })
Check "14b. シリーズの動画にだけ出てくる行は定型部分にしない(ARK の3本は候補に残る)" ($arkC.Count -eq 3 -and @($arkC | Where-Object game -eq "ARK: Survival Ascended").Count -eq 3) (($arkC | ForEach-Object { "$($_.videoId)=$($_.game)" }) -join ",")
$mcS = $ct | Where-Object videoId -eq "TplMcSeq001"
Check "14c. 再生リスト登録済み×連番の動画は削除せず、確認待ちのまま別グループ(likely-in-site-playlist)にする" ($mcS -and $mcS.reviewGroup -eq "likely-in-site-playlist" -and $mcS.status -eq "pending" -and $jt.lastRun.stats.likelyInSitePlaylist -ge 1) ($mcS | ConvertTo-Json -Compress)
Check "14d. 「DAY3」のような連番も認識する(ルイは ARK の再生リストが無いので new-standalone のまま)" (@($arkC | Where-Object { @($_.reasons) -contains "連番あり(続き物は再生リスト方式で拾う)" }).Count -eq 3 -and @($arkC | Where-Object reviewGroup -eq "new-standalone").Count -eq 3) ""
Check "14e. 配信の種類を表す【オフコラボ】は未登録作品の名前にしない" (@($jt.unknownGames | Where-Object name -eq "オフコラボ").Count -eq 0) (($jt.unknownGames | ForEach-Object name) -join ",")

Write-Output "== 精度改善(非ゲーム表現・作品の取り違え・英字名の境界・複数配信者)"
$feedsP = Join-Path $work "feeds-precision"
New-Item -ItemType Directory -Path $feedsP -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $feedsP "rui.xml"), (New-Feed $rui @(
  (New-Entry "PrcWuwa0001" "【鳴潮】「Ver.3.7予告特別通信」アーカイブ同時視聴【鷹嶺ルイ/ホロライブ】" "2026-10-17T01:00:00+00:00"),
  (New-Entry "PrcSuiko001" "【幻想水滸伝】教えて！幻想水滸伝！！【鷹嶺ルイ/ホロライブ】" "2026-10-16T01:00:00+00:00"),
  (New-Entry "PrcArk00001" "【#ホロ鯖ARK】ARK上陸8日目！素材集め【鷹嶺ルイ/ホロライブ】" "2026-10-15T01:00:00+00:00"),
  (New-Entry "PrcArk00002" "【#ホロ鯖ARK】ARK上陸9日目！テイム【鷹嶺ルイ/ホロライブ】" "2026-10-14T01:00:00+00:00" "ARK: Survival Ascended をプレイ中"),
  (New-Entry "PrcBomb0001" "【BOMBANANA!】協力して爆弾解除【鷹嶺ルイ/ホロライブ】" "2026-10-13T01:00:00+00:00"),
  (New-Entry "PrcSpag0001" "【SPAGHET】パスタの宅配【鷹嶺ルイ/ホロライブ】" "2026-10-12T01:00:00+00:00"),
  (New-Entry "PrcGacha001" "【ガチャ旅】どこだ、ここ【鷹嶺ルイ/ホロライブ】" "2026-10-11T01:00:00+00:00"),
  (New-Entry "PrcSpoil001" "【ネタバレあり】初見でクリアまで【鷹嶺ルイ/ホロライブ】" "2026-10-10T01:00:00+00:00"),
  (New-Entry "PrcTanpo001" "【タンポポは耐える。】タンポポってかわいい【鷹嶺ルイ/ホロライブ】" "2026-10-09T01:00:00+00:00" "いったいどんなゲームなんだ？"),
  (New-Entry "PrcWater001" "プールを経営して稼ぐ Waterpark Simulator【鷹嶺ルイ/ホロライブ】" "2026-10-08T01:00:00+00:00")
)), $utf8)
[IO.File]::WriteAllText((Join-Path $feedsP "sora.xml"), (New-Feed $sora @(
  (New-Entry "PrcBomb0002" "【BOMBANANA!】みんなで爆弾解除【ときのそら/ホロライブ】" "2026-10-13T02:00:00+00:00")
)), $utf8)
$outP = Join-Path $work "precision-candidates.json"
$ErrorActionPreference = "Continue"
$rp = & $psExe -NoProfile -ExecutionPolicy Bypass -File $watch -FeedDir $feedsP -OutFile $outP 2>&1 | ForEach-Object { "$_" }
$ErrorActionPreference = "Stop"
$jp = ([IO.File]::ReadAllText($outP, [Text.Encoding]::UTF8)) | ConvertFrom-Json
$cp = @($jp.candidates); $up = @($jp.unknownGames)
$cOf = { param($id) $cp | Where-Object videoId -eq $id }; $uOf = { param($n) $up | Where-Object name -eq $n }
$p1 = & $cOf "PrcWuwa0001"
Check "15a. アーカイブ同時視聴は非ゲーム表現として HIGH にしない" ($p1 -and $p1.confidence -ne "HIGH" -and @($p1.reasons | Where-Object { $_ -like "非ゲーム語*同時視聴*" }).Count -eq 1) ((($rp -join " ")) + " / " + ($p1 | ConvertTo-Json -Compress))
$p2 = & $cOf "PrcSuiko001"
Check "15b. 別名が別の作品名の先頭部分にもなっている一致(幻想水滸伝)は HIGH にしない" ($p2 -and $p2.confidence -ne "HIGH" -and @($p2.reasons | Where-Object { $_ -like "別名が別の作品名の先頭部分*" }).Count -eq 1) ($p2 | ConvertTo-Json -Compress)
$p3 = & $cOf "PrcArk00001"
Check "15c. 漢字の隣の英字名(ARK上陸)も一致させ、シリーズ名の語幹だけなら ARKシリーズ・HIGH にしない" ($p3 -and $p3.game -eq "ARKシリーズ" -and $p3.confidence -ne "HIGH" -and @($p3.reasons | Where-Object { $_ -like "シリーズ名の一部だけで一致*" }).Count -eq 1) ($p3 | ConvertTo-Json -Compress)
$p4 = & $cOf "PrcArk00002"
Check "15d. シリーズ名の語幹で一致しても、説明欄に具体的な作品名があればそちらで特定する" ($p4 -and $p4.game -eq "ARK: Survival Ascended" -and $p4.confidence -ne "HIGH") ($p4 | ConvertTo-Json -Compress)
$ub = & $uOf "BOMBANANA!"
Check "15e. ゲームを表す語が無くても2人以上の配信者に出てくる名前は未登録作品の候補にする" ($ub -and $ub.videoCount -eq 2 -and @($ub.streamers).Count -eq 2 -and $ub.status -eq "pending") ($up | ForEach-Object { "$($_.name)=$($_.videoCount)" } | Out-String)
Check "15f. ゲームを表す語が無く1人だけの名前(SPAGHET)は候補にしない" (-not (& $uOf "SPAGHET")) ""
Check "15g. 作品名の中の語(ガチャ旅のガチャ)はゲームを表す手がかりにしない" (-not (& $uOf "ガチャ旅")) ""
Check "15h. 【ネタバレあり】は配信の種類として未登録作品の名前にしない" (-not (& $uOf "ネタバレあり")) ""
$ut = & $uOf "タンポポは耐える。"
Check "15i. 2文字のVTuber名(える)を含むだけの語(耐える)はVTuber名の表記とみなさない" ($ut -and $ut.videoCount -eq 1) ""
$uw = & $uOf "Waterpark Simulator"
Check "15j. 作品名によく使われるジャンル名(Simulator)は作品名の中にあっても手がかりにする" ($uw -and $uw.confidence -eq "MEDIUM") ($uw | ConvertTo-Json -Compress)

Write-Output "== 再判定(確認待ちの既存候補を今のロジックで判定し直す)"
$feedsR = Join-Path $work "feeds-rejudge"
New-Item -ItemType Directory -Path $feedsR -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $feedsR "rui.xml"), (New-Feed $rui @(
  (New-Entry "RjSuiko0001" "【幻想水滸伝】教えて！幻想水滸伝！！【鷹嶺ルイ/ホロライブ】" "2026-10-16T01:00:00+00:00"),
  (New-Entry "RjWuwa00001" "【鳴潮】アーカイブ同時視聴【鷹嶺ルイ/ホロライブ】" "2026-10-15T01:00:00+00:00"),
  (New-Entry "Rj8ex000001" "【8番出口】はじめての8番出口【鷹嶺ルイ/ホロライブ】" "2026-10-14T01:00:00+00:00"),
  (New-Entry "RjTalk00001" "【雑談】まったりおしゃべり【鷹嶺ルイ/ホロライブ】" "2026-10-13T01:00:00+00:00"),
  (New-Entry "RjWuwaAppr1" "【鳴潮】アーカイブ同時視聴その2【鷹嶺ルイ/ホロライブ】" "2026-10-12T01:00:00+00:00"),
  (New-Entry "RjGacha0001" "【ガチャ旅】どこだ、ここ【鷹嶺ルイ/ホロライブ】" "2026-10-11T01:00:00+00:00"),
  (New-Entry "RjOffco0001" "【オフコラボ】ごはん会【鷹嶺ルイ/ホロライブ】" "2026-10-10T01:00:00+00:00" "ゲームもするかも"),
  (New-Entry "RjSpoil0001" "【ネタバレあり】クリアまで【鷹嶺ルイ/ホロライブ】" "2026-10-09T01:00:00+00:00" "初見プレイ"),
  (New-Entry "RjWardog001" "【WARDOGS】話題の100人対戦FPS！【鷹嶺ルイ/ホロライブ】" "2026-10-08T01:00:00+00:00")
)), $utf8)
$old = "2026-10-01T00:00:00"
function New-OldCand([string]$id, [string]$title, [string]$game, [string]$conf, [string]$status) {
  return [ordered]@{ videoId = $id; url = "https://www.youtube.com/watch?v=$id"; streamer = "鷹嶺ルイ"; channelId = $rui; title = $title; publishedAt = "2026-10-01T00:00:00+00:00"; publishedDate = "2026-10-01"
    game = $game; confidence = $conf; matchType = "bracket-exact"; matchedAlias = $game; reasons = @(); otherGames = @(); likelyNonGame = $false; siteHasGamePlaylist = $false; playlistVideoCheck = "unverified"
    status = $status; source = "rss"; firstSeenAt = $old; lastSeenAt = $old }
}
function New-OldUnknown([string]$name, [string]$id, [string]$title, [string]$status) {
  return [ordered]@{ name = $name; key = ""; confidence = "MEDIUM"; videoCount = 1; streamers = @("鷹嶺ルイ"); possibleExisting = @(); reasons = @("【】の中の語"); status = $status; firstSeenAt = $old; lastSeenAt = $old
    videos = @([ordered]@{ videoId = $id; url = "https://www.youtube.com/watch?v=$id"; streamer = "鷹嶺ルイ"; channelId = $rui; title = $title; publishedDate = "2026-10-01"; source = "bracket"; confidence = "MEDIUM"; reasons = @("【】の中の語"); firstSeenAt = $old }) }
}
. (Join-Path $scriptDir "standalone-matching.ps1")
$oldU = @((New-OldUnknown "ガチャ旅" "RjGacha0001" "【ガチャ旅】どこだ、ここ" "pending"), (New-OldUnknown "オフコラボ" "RjOffco0001" "【オフコラボ】ごはん会" "pending"),
          (New-OldUnknown "ネタバレあり" "RjSpoil0001" "【ネタバレあり】クリアまで" "rejected"), (New-OldUnknown "WARDOGS" "RjWardog001" "【WARDOGS】話題の100人対戦FPS！" "pending"))
foreach ($u in $oldU) { $u.key = Get-StandaloneLooseKey $u.name }
$oldJson = [ordered]@{ generatedAt = $old; source = "youtube-channel-rss"; note = "test"; lastRun = @{}
  candidates = @((New-OldCand "RjSuiko0001" "【幻想水滸伝】教えて！幻想水滸伝！！" "幻想水滸伝I&II HDリマスター 門の紋章戦争/デュナン統一戦争" "HIGH" "pending"),
                 (New-OldCand "RjWuwa00001" "【鳴潮】アーカイブ同時視聴" "鳴潮" "HIGH" "pending"),
                 (New-OldCand "Rj8ex000001" "【8番出口】はじめての8番出口" "8番出口" "HIGH" "pending"),
                 (New-OldCand "RjTalk00001" "【雑談】まったりおしゃべり" "モノポリー" "LOW" "pending"),
                 (New-OldCand "RjWuwaAppr1" "【鳴潮】アーカイブ同時視聴その2" "鳴潮" "HIGH" "approved"),
                 (New-OldCand "RjNotInFeed" "RSS に出てこない動画" "8番出口" "HIGH" "pending"))
  unknownGames = $oldU }
$outR = Join-Path $work "rejudge-candidates.json"
[IO.File]::WriteAllText($outR, ($oldJson | ConvertTo-Json -Depth 8), $utf8)
function Invoke-Rejudge() {
  $ErrorActionPreference = "Continue"
  $o = & $psExe -NoProfile -ExecutionPolicy Bypass -File $watch -FeedDir $feedsR -OutFile $outR 2>&1 | ForEach-Object { "$_" }
  return (($o -join " ") + "")
}
$rr1 = Invoke-Rejudge
$jr = ([IO.File]::ReadAllText($outR, [Text.Encoding]::UTF8)) | ConvertFrom-Json
$cr = { param($id) $jr.candidates | Where-Object videoId -eq $id }; $ur = { param($n) $jr.unknownGames | Where-Object name -eq $n }
$s1 = & $cr "RjSuiko0001"; $s2 = & $cr "RjWuwa00001"
Check "16a. 確認待ちの「教えて！幻想水滸伝」は HIGH から判定し直す(初回検出日時・タイトルは変えない)" ($s1.confidence -ne "HIGH" -and $s1.firstSeenAt -eq $old -and $s1.title -eq "【幻想水滸伝】教えて！幻想水滸伝！！" -and $s1.rejudgedAt) ($rr1 + " / " + ($s1 | ConvertTo-Json -Compress))
Check "16b. 確認待ちの「アーカイブ同時視聴」は HIGH から LOW に判定し直す" ($s2.confidence -eq "LOW" -and @($s2.reasons | Where-Object { $_ -like "非ゲーム語*" }).Count -eq 1) ($s2 | ConvertTo-Json -Compress)
$s3 = & $cr "Rj8ex000001"
Check "16c. 正しい候補(8番出口)は HIGH のまま残る" ($s3 -and $s3.game -eq "8番出口" -and $s3.confidence -eq "HIGH" -and $s3.status -eq "pending") ($s3 | ConvertTo-Json -Compress)
$s4 = & $cr "RjTalk00001"
Check "16d. 今のロジックで既存作品に一致しなくなった候補は削除せず rejudged-not-matched の印を付ける" ($s4 -and $s4.reviewGroup -eq "rejudged-not-matched" -and $s4.confidence -eq "NONE" -and $s4.status -eq "pending" -and $s4.game -eq "モノポリー") ($s4 | ConvertTo-Json -Compress)
$s5 = & $cr "RjWuwaAppr1"
Check "16e. 人が確認した候補(status=approved)は判定を変えない" ($s5 -and $s5.status -eq "approved" -and $s5.confidence -eq "HIGH" -and -not $s5.rejudgedAt) ($s5 | ConvertTo-Json -Compress)
$s6 = & $cr "RjNotInFeed"
Check "16f. RSS に出てこない既存候補は削除しない(判定も変えない)" ($s6 -and $s6.confidence -eq "HIGH" -and $s6.lastSeenAt -eq $old) ""
Check "16g. 未登録作品の誤検出(ガチャ旅・オフコラボ)は再判定で rejudged-not-candidate の印を付ける(削除しない)" ((& $ur "ガチャ旅").reviewGroup -eq "rejudged-not-candidate" -and (& $ur "オフコラボ").reviewGroup -eq "rejudged-not-candidate" -and @($jr.unknownGames).Count -eq 4) (($jr.unknownGames | ForEach-Object { "$($_.name)=$($_.reviewGroup)" }) -join ",")
Check "16h. 人が却下した未登録作品(status=rejected)は変えない" ((& $ur "ネタバレあり").status -eq "rejected" -and -not (& $ur "ネタバレあり").reviewGroup) ""
Check "16i. 正しい未登録作品の候補(WARDOGS)は残る" ((& $ur "WARDOGS").reviewGroup -eq "unknown-game" -and (& $ur "WARDOGS").videoCount -eq 1) ""
$rr2 = Invoke-Rejudge
$jr2 = ([IO.File]::ReadAllText($outR, [Text.Encoding]::UTF8)) | ConvertFrom-Json
Check "16j. 同じRSSを2回処理しても候補は重複せず、2回目は判定が変わらない" (@($jr2.candidates).Count -eq 6 -and @($jr2.unknownGames).Count -eq 4 -and $jr2.lastRun.stats.newCandidates -eq 0 -and $jr2.lastRun.stats.rejudgeChanged -eq 0 -and $jr2.lastRun.stats.unknownRejudgedNotCandidate -eq 0) ($rr2)

Write-Output "== 一括再判定(-RejudgeOnly。履歴の RSS を含めて既存候補だけを判定し直す)"
$feedsB = Join-Path $work "feeds-bulk"
$archB = Join-Path (Join-Path $feedsB "archive") $rui
New-Item -ItemType Directory -Path $archB -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $feedsB "rui.xml"), (New-Feed $rui @(
  (New-Entry "Bk8exNew001" "【8番出口】新しい動画【鷹嶺ルイ/ホロライブ】" "2026-10-17T01:00:00+00:00"),
  (New-Entry "BkSuiko0001" "【幻想水滸伝】教えて！幻想水滸伝！！【鷹嶺ルイ/ホロライブ】" "2026-10-16T01:00:00+00:00")
)), $utf8)
[IO.File]::WriteAllText((Join-Path $feedsB "sora.xml"), (New-Feed $sora @(
  (New-Entry "BkBomb00002" "【BOMBANANA!】みんなで爆弾解除【ときのそら/ホロライブ】" "2026-10-15T01:00:00+00:00")
)), $utf8)
$archFile = Join-Path $archB "20261001-000000.xml"
[IO.File]::WriteAllText($archFile, (New-Feed $rui @(
  (New-Entry "BkWuwa00001" "【鳴潮】アーカイブ同時視聴【鷹嶺ルイ/ホロライブ】" "2026-09-30T01:00:00+00:00"),
  (New-Entry "BkApprov001" "【鳴潮】アーカイブ同時視聴その2【鷹嶺ルイ/ホロライブ】" "2026-09-29T01:00:00+00:00"),
  (New-Entry "BkGacha0001" "【ガチャ旅】どこだ、ここ【鷹嶺ルイ/ホロライブ】" "2026-09-28T01:00:00+00:00"),
  (New-Entry "BkWard00001" "【WARDOGS】話題の100人対戦FPS！【鷹嶺ルイ/ホロライブ】" "2026-09-27T01:00:00+00:00"),
  (New-Entry "BkBomb00001" "【BOMBANANA!】協力して爆弾解除【鷹嶺ルイ/ホロライブ】" "2026-09-26T01:00:00+00:00")
)), $utf8)
(Get-Item $archFile).LastWriteTime = (Get-Date).AddDays(-10)   # 履歴は最新の RSS より古い
$bulkU = @((New-OldUnknown "ガチャ旅" "BkGacha0001" "【ガチャ旅】どこだ、ここ" "pending"), (New-OldUnknown "WARDOGS" "BkWard00001" "【WARDOGS】話題の100人対戦FPS！" "pending"),
           (New-OldUnknown "BOMBANANA!" "BkBomb00001" "【BOMBANANA!】協力して爆弾解除" "pending"))
foreach ($u in $bulkU) { $u.key = Get-StandaloneLooseKey $u.name }
$bulkJson = [ordered]@{ generatedAt = $old; source = "youtube-channel-rss"; note = "test"; lastRun = @{}
  candidates = @((New-OldCand "BkSuiko0001" "【幻想水滸伝】教えて！幻想水滸伝！！" "幻想水滸伝I&II HDリマスター 門の紋章戦争/デュナン統一戦争" "HIGH" "pending"),
                 (New-OldCand "BkWuwa00001" "【鳴潮】アーカイブ同時視聴" "鳴潮" "HIGH" "pending"),
                 (New-OldCand "BkApprov001" "【鳴潮】アーカイブ同時視聴その2" "鳴潮" "HIGH" "approved"),
                 (New-OldCand "BkNoRss0001" "保存済みRSSに無い動画" "8番出口" "HIGH" "pending"))
  unknownGames = $bulkU }
$outB = Join-Path $work "bulk-candidates.json"
[IO.File]::WriteAllText($outB, ($bulkJson | ConvertTo-Json -Depth 8), $utf8)
$outB2 = Join-Path $work "bulk-normal.json"
[IO.File]::WriteAllText($outB2, ($bulkJson | ConvertTo-Json -Depth 8), $utf8)
function Invoke-Bulk([string[]]$extra, [string]$out) {
  $ErrorActionPreference = "Continue"
  $o = & $psExe @(@("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $watch, "-FeedDir", $feedsB, "-OutFile", $out) + $extra) 2>&1 | ForEach-Object { "$_" }
  return [pscustomobject]@{ code = $LASTEXITCODE; output = ($o -join " ") }
}
$b1 = Invoke-Bulk @("-RejudgeOnly") $outB
$jb = ([IO.File]::ReadAllText($outB, [Text.Encoding]::UTF8)) | ConvertFrom-Json
$cb = { param($id) $jb.candidates | Where-Object videoId -eq $id }; $ubk = { param($n) $jb.unknownGames | Where-Object name -eq $n }
Check "17a. 一括再判定は最新の RSS にある確認待ちの候補を判定し直す(幻想水滸伝 HIGH → HIGH 以外)" ($b1.code -eq 0 -and (& $cb "BkSuiko0001").confidence -ne "HIGH") ($b1.output)
Check "17b. 新着から外れて履歴(archive)にしかない確認待ちの候補も判定し直す(同時視聴 HIGH → LOW)" ((& $cb "BkWuwa00001").confidence -eq "LOW" -and (& $cb "BkWuwa00001").firstSeenAt -eq $old) ((& $cb "BkWuwa00001") | ConvertTo-Json -Compress)
Check "17c. 人が確認した候補(approved)は変えない" ((& $cb "BkApprov001").confidence -eq "HIGH" -and (& $cb "BkApprov001").status -eq "approved" -and -not (& $cb "BkApprov001").rejudgedAt) ""
Check "17d. 保存済みRSSに無い確認待ちの候補はそのまま残し、件数を数える" ((& $cb "BkNoRss0001").confidence -eq "HIGH" -and $jb.lastRun.stats.rejudgeNotInRss -eq 1) ("notInRss=$($jb.lastRun.stats.rejudgeNotInRss)")
Check "17e. 一括再判定では新しい動画を候補に追加しない" (-not (& $cb "Bk8exNew001") -and @($jb.candidates).Count -eq 4 -and $jb.lastRun.stats.rejudgeSkippedNew -ge 2) ("count=$(@($jb.candidates).Count) skipped=$($jb.lastRun.stats.rejudgeSkippedNew)")
Check "17f. 未登録作品の誤検出(ガチャ旅)は印を付け、正しい候補(WARDOGS)は残す" ((& $ubk "ガチャ旅").reviewGroup -eq "rejudged-not-candidate" -and (& $ubk "WARDOGS").reviewGroup -eq "unknown-game") ""
$bk = & $ubk "BOMBANANA!"
Check "17g. 新しい動画は追加しないが、2人以上の配信者に出てくる証拠としては数える(BOMBANANA! は1本のまま残る)" ($bk.reviewGroup -eq "unknown-game" -and $bk.videoCount -eq 1) ($bk | ConvertTo-Json -Compress -Depth 5)
$b2 = Invoke-Bulk @("-RejudgeOnly") $outB
$jb2 = ([IO.File]::ReadAllText($outB, [Text.Encoding]::UTF8)) | ConvertFrom-Json
Check "17h. 同じ RSS で一括再判定を2回行っても重複せず、2回目は判定が変わらない" ($b2.code -eq 0 -and @($jb2.candidates).Count -eq 4 -and @($jb2.unknownGames).Count -eq 3 -and $jb2.lastRun.stats.rejudgeChanged -eq 0 -and $jb2.lastRun.stats.unknownRejudgedNotCandidate -eq 0) ($b2.output)
$n1 = Invoke-Bulk @() $outB2
$jn = ([IO.File]::ReadAllText($outB2, [Text.Encoding]::UTF8)) | ConvertFrom-Json
Check "17i. 通常の処理は従来どおり(直下の RSS だけを読み、新しい動画は候補に追加し、履歴は読まない)" ($n1.code -eq 0 -and @($jn.candidates | Where-Object videoId -eq "Bk8exNew001").Count -eq 1 -and ($jn.candidates | Where-Object videoId -eq "BkWuwa00001").confidence -eq "HIGH") ($n1.output)
$b3 = Invoke-Bulk @("-RejudgeOnly", "-Streamer", "鷹嶺ルイ") $outB
Check "17j. -RejudgeOnly と取得の指定(-Streamer)は同時に使えない" ($b3.code -ne 0) ($b3.output)
Check "17k. RSS を取得したときは動画ごとの履歴(entries/<チャンネルID>.json)に記録し、RSS 全体の archive は作らない" ((Test-Path (Join-Path (Join-Path $fetchDir "entries") "$rui.json")) -and -not (Test-Path (Join-Path $fetchDir "archive"))) ""
$migr = ([IO.File]::ReadAllText((Join-Path (Join-Path $feedsB "entries") "$rui.json"), [Text.Encoding]::UTF8)) | ConvertFrom-Json
Check "17l. 以前の archive の XML は削除せず、一括再判定のときに履歴JSONへ取り込む" ((Test-Path $archFile) -and @($migr.videos | Where-Object videoId -eq "BkWuwa00001").Count -eq 1 -and @($migr.videos).Count -eq 7) ("videos=$(@($migr.videos).Count)")

Write-Output "== 動画ごとの履歴(entries/<チャンネルID>.json)"
$feedsH = Join-Path $work "feeds-history"
New-Item -ItemType Directory -Path $feedsH -Force | Out-Null
$entH = Join-Path $feedsH "entries"
$ruiH = Join-Path $feedsH "rui.xml"
function Invoke-Dir([string]$dir, [string]$o, [string[]]$extra) {
  $ErrorActionPreference = "Continue"
  $r = & $psExe @(@("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $watch, "-FeedDir", $dir, "-OutFile", $o) + $extra) 2>&1 | ForEach-Object { "$_" }
  return [pscustomobject]@{ code = $LASTEXITCODE; output = ($r -join " ") }
}
function Read-Store([string]$cid) { return ([IO.File]::ReadAllText((Join-Path $entH "$cid.json"), [Text.Encoding]::UTF8)) | ConvertFrom-Json }
$outH = Join-Path $work "history-normal.json"
[IO.File]::WriteAllText($ruiH, (New-Feed $rui @(
  (New-Entry "Hk8ex000001" "【8番出口】履歴テスト【鷹嶺ルイ/ホロライブ】" "2026-10-10T01:00:00+00:00" "説明1"),
  (New-Entry "HkWuwa00001" "【鳴潮】アーカイブ同時視聴【鷹嶺ルイ/ホロライブ】" "2026-10-09T01:00:00+00:00" "元の説明"),
  (New-Entry "HkTalk00001" "【雑談】まったり【鷹嶺ルイ/ホロライブ】" "2026-10-08T01:00:00+00:00"),
  (New-Entry "HkApprov001" "【鳴潮】アーカイブ同時視聴その2【鷹嶺ルイ/ホロライブ】" "2026-10-07T01:00:00+00:00")
)), $utf8)
(Get-Item $ruiH).LastWriteTime = (Get-Date).AddMinutes(-30)
$h1 = Invoke-Dir $feedsH $outH @()
$s1 = Read-Store $rui
(Get-Item $ruiH).LastWriteTime = (Get-Date).AddMinutes(-20)   # 同じ RSS をもう一度取得した想定
$h2 = Invoke-Dir $feedsH $outH @()
$s2 = Read-Store $rui
$w1 = $s1.videos | Where-Object videoId -eq "HkWuwa00001"; $w2 = $s2.videos | Where-Object videoId -eq "HkWuwa00001"
Check "18a. 同じ RSS を2回処理しても履歴の動画は増えない(4本のまま。firstSeenAt は変えず lastSeenAt だけ更新)" ($h1.code -eq 0 -and $h2.code -eq 0 -and @($s1.videos).Count -eq 4 -and @($s2.videos).Count -eq 4 -and $s2.videoCount -eq 4 -and $w2.firstSeenAt -eq $w1.firstSeenAt -and $w2.lastSeenAt -ne $w1.lastSeenAt) ("$($h2.output) first=$($w2.firstSeenAt) last=$($w2.lastSeenAt)")
Check "18b. 履歴には動画ID・タイトル・説明欄・公開日時・初回/最終検出日時を記録する" ($w2.title -like "【鳴潮】*" -and $w2.description -eq "元の説明" -and $w2.published -eq "2026-10-09T01:00:00+00:00" -and $s2.channelId -eq $rui -and $s2.streamer -eq "鷹嶺ルイ") ($w2 | ConvertTo-Json -Compress)
[IO.File]::WriteAllText($ruiH, (New-Feed $rui @(
  (New-Entry "HkNew000001" "【8番出口】新着の動画【鷹嶺ルイ/ホロライブ】" "2026-10-12T01:00:00+00:00"),
  (New-Entry "Hk8ex000001" "【8番出口】履歴テスト(タイトル変更)【鷹嶺ルイ/ホロライブ】" "2026-10-10T01:00:00+00:00" "説明1")
)), $utf8)
(Get-Item $ruiH).LastWriteTime = (Get-Date).AddMinutes(-10)
$h3 = Invoke-Dir $feedsH $outH @()
$s3 = Read-Store $rui
$x3 = $s3.videos | Where-Object videoId -eq "Hk8ex000001"; $x1 = $s1.videos | Where-Object videoId -eq "Hk8ex000001"; $w3 = $s3.videos | Where-Object videoId -eq "HkWuwa00001"
Check "18c. 新着から外れた動画も履歴に残り、同じ動画はタイトルと lastSeenAt だけ更新する(5本)" ($h3.code -eq 0 -and @($s3.videos).Count -eq 5 -and $w3 -and $w3.description -eq "元の説明" -and $w3.lastSeenAt -eq $w2.lastSeenAt -and $x3.title -like "*タイトル変更*" -and $x3.firstSeenAt -eq $x1.firstSeenAt -and $x3.lastSeenAt -ne $x1.lastSeenAt) ($s3.videos | ConvertTo-Json -Compress)
Check "18d. 履歴の書き込みで一時ファイル(.tmp)を残さない" (@(Get-ChildItem -LiteralPath $entH -Filter *.tmp).Count -eq 0) ""
$outHB = Join-Path $work "history-rejudge.json"
$hbJson = [ordered]@{ generatedAt = $old; source = "youtube-channel-rss"; note = "test"; lastRun = @{}
  candidates = @((New-OldCand "HkWuwa00001" "【鳴潮】アーカイブ同時視聴" "鳴潮" "HIGH" "pending"),
                 (New-OldCand "HkApprov001" "【鳴潮】アーカイブ同時視聴その2" "鳴潮" "HIGH" "approved"),
                 (New-OldCand "HkNoHist001" "履歴に無い動画" "8番出口" "HIGH" "pending"))
  unknownGames = @() }
[IO.File]::WriteAllText($outHB, ($hbJson | ConvertTo-Json -Depth 8), $utf8)
$hb1 = Invoke-Dir $feedsH $outHB @("-RejudgeOnly")
$jh = ([IO.File]::ReadAllText($outHB, [Text.Encoding]::UTF8)) | ConvertFrom-Json
$ch = { param($id) $jh.candidates | Where-Object videoId -eq $id }
Check "18e. 一括再判定は履歴JSONを使い、新着から外れた確認待ちの候補も判定し直す(同時視聴 HIGH → LOW)" ($hb1.code -eq 0 -and (& $ch "HkWuwa00001").confidence -eq "LOW" -and (& $ch "HkWuwa00001").firstSeenAt -eq $old) ($hb1.output)
Check "18f. 既存の候補と判定結果は失われない(3件のまま・approved は変えない・履歴に無い候補はそのまま)" (@($jh.candidates).Count -eq 3 -and (& $ch "HkApprov001").confidence -eq "HIGH" -and (& $ch "HkApprov001").status -eq "approved" -and (& $ch "HkNoHist001").confidence -eq "HIGH" -and $jh.lastRun.stats.rejudgeNotInRss -eq 1 -and -not (& $ch "HkNew000001")) ("count=$(@($jh.candidates).Count) notIn=$($jh.lastRun.stats.rejudgeNotInRss)")
$storeHash = (Get-FileHash (Join-Path $entH "$rui.json") -Algorithm SHA256).Hash
$hb2 = Invoke-Dir $feedsH $outHB @("-RejudgeOnly")
$jh2 = ([IO.File]::ReadAllText($outHB, [Text.Encoding]::UTF8)) | ConvertFrom-Json
Check "18g. 一括再判定を2回行っても候補・履歴は変わらない(履歴JSONを書き直さない)" ($hb2.code -eq 0 -and @($jh2.candidates).Count -eq 3 -and $jh2.lastRun.stats.rejudgeChanged -eq 0 -and (Get-FileHash (Join-Path $entH "$rui.json") -Algorithm SHA256).Hash -eq $storeHash) ($hb2.output)
$brokenStore = '{"channelId": "' + $sora + '", "videos": [ 壊れたJSON'
[IO.File]::WriteAllText((Join-Path $entH "$sora.json"), $brokenStore, $utf8)
[IO.File]::WriteAllText((Join-Path $feedsH "sora.xml"), (New-Feed $sora @((New-Entry "HkSora00001" "【8番出口】そらの履歴テスト【ときのそら/ホロライブ】" "2026-10-11T01:00:00+00:00"))), $utf8)
$h4 = Invoke-Dir $feedsH $outH @()
$jh4 = ([IO.File]::ReadAllText($outH, [Text.Encoding]::UTF8)) | ConvertFrom-Json
Check "18h. 履歴JSONが壊れていても上書きせず、エラーに記録してほかの処理は続ける" ($h4.code -eq 0 -and ([IO.File]::ReadAllText((Join-Path $entH "$sora.json"), [Text.Encoding]::UTF8)) -eq $brokenStore -and @($jh4.lastRun.errors | Where-Object { $_.stage -eq "history" -and $_.channelId -eq $sora }).Count -eq 1 -and @($jh4.candidates | Where-Object videoId -eq "HkSora00001").Count -eq 1 -and @((Read-Store $rui).videos).Count -eq 5) ($h4.output)
$hb3 = Invoke-Dir $feedsH $outHB @("-RejudgeOnly")
Check "18i. 履歴JSONが壊れていても一括再判定は止まらず、壊れたファイルはそのまま" ($hb3.code -eq 0 -and ([IO.File]::ReadAllText((Join-Path $entH "$sora.json"), [Text.Encoding]::UTF8)) -eq $brokenStore) ($hb3.output)
$entF = Join-Path $fetchDir "entries"
$fetchStoreBefore = @(Get-ChildItem -LiteralPath $entF -Filter *.json | Sort-Object Name | ForEach-Object { $_.Name + "=" + (Get-FileHash $_.FullName -Algorithm SHA256).Hash })
$f9 = Invoke-Fetch @("音乃瀬奏") $null
$fetchStoreAfter = @(Get-ChildItem -LiteralPath $entF -Filter *.json | Sort-Object Name | ForEach-Object { $_.Name + "=" + (Get-FileHash $_.FullName -Algorithm SHA256).Hash })
Check "18j. RSS の取得に失敗したときは履歴JSONを変更しない" ($f9.code -eq 0 -and $fetchStoreBefore.Count -ge 2 -and ($fetchStoreBefore -join ",") -eq ($fetchStoreAfter -join ",")) ("before=$($fetchStoreBefore.Count) after=$($fetchStoreAfter.Count)")

Write-Output "== API 方式(-Source Api。モック。ネットワークには接続しない)"
$apiDir = Join-Path $work "api-mock"
New-Item -ItemType Directory -Path $apiDir -Force | Out-Null
$fakeKey = "TESTKEY-DO-NOT-PRINT-7f3a9c"
$apiChannels = @(@{ id = $rui; name = "鷹嶺ルイ" }, @{ id = $sora; name = "ときのそら" }, @{ id = $botan; name = "獅白ぼたん" }, @{ id = $roboco; name = "ロボ子さん" }, @{ id = $kanadeReal; name = "音乃瀬奏" })
$apiMap = Join-Path $work "api-map.json"
[IO.File]::WriteAllText($apiMap, (ConvertTo-Json -InputObject @($apiChannels | ForEach-Object { [pscustomobject]@{ streamer = $_.name; channelId = $_.id } }) -Depth 3), $utf8)
$uu = @{}; foreach ($c in $apiChannels) { $uu[$c.name] = "UU" + $c.id.Substring(2) }
function New-ApiPage([object[]]$items, [string]$next = "") {
  $o = [ordered]@{ kind = "youtube#playlistItemListResponse"; items = @($items | ForEach-Object {
    $cd = [ordered]@{ videoId = $_.id }; if ($_.pub) { $cd.videoPublishedAt = $_.pub }
    [ordered]@{ snippet = [ordered]@{ title = $_.title; description = [string]$_.desc }; contentDetails = $cd } }) }
  if ($next) { $o.nextPageToken = $next }
  return ($o | ConvertTo-Json -Depth 6)
}
function Write-ApiFile([string]$name, [string]$text) { [IO.File]::WriteAllText((Join-Path $apiDir $name), $text, $utf8) }
Write-ApiFile "rui.json" (New-ApiPage @(@{ id = "ApiRui00001"; title = "【8番出口】API取得テスト【鷹嶺ルイ/ホロライブ】"; pub = "2026-10-18T01:00:00Z" }, @{ id = "ApiRuiPriv1"; title = "非公開の動画"; pub = "" }))
Write-ApiFile "sora.json" (New-ApiPage @(@{ id = "ApiSora0001"; title = "【8番出口】そらのAPIテスト【ときのそら/ホロライブ】"; pub = "2026-10-17T01:00:00Z" }))
Write-ApiFile "botan-ch.json" ((@{ items = @(@{ contentDetails = @{ relatedPlaylists = @{ uploads = "UUbotanResolved0000000x" } } }) } | ConvertTo-Json -Depth 6))
Write-ApiFile "botan.json" (New-ApiPage @(@{ id = "ApiBotan001"; title = "【雑談】ぼたんの雑談"; pub = "2026-10-16T01:00:00Z" }))
Write-ApiFile "roboco1.json" (New-ApiPage @(@{ id = "ApiRobo0001"; title = "【雑談】ロボ1"; pub = "2026-10-15T03:00:00Z" }, @{ id = "ApiRobo0002"; title = "【雑談】ロボ2"; pub = "2026-10-15T02:00:00Z" }) "PAGE2")
Write-ApiFile "roboco2.json" (New-ApiPage @(@{ id = "ApiRobo0003"; title = "【雑談】ロボ3(2ページ目)"; pub = "2026-10-15T01:00:00Z" }, @{ id = "RbOld000001"; title = "【雑談】前回の動画"; pub = "2026-10-01T01:00:00Z" }))
Write-ApiFile "kanade1.json" (New-ApiPage @(@{ id = "ApiKnd00001"; title = "【雑談】奏の新着"; pub = "2026-10-14T02:00:00Z" }, @{ id = "KnKnown0001"; title = "【雑談】前回の動画"; pub = "2026-10-01T01:00:00Z" }) "PAGE2")
Write-ApiFile "kanade2.json" (New-ApiPage @(@{ id = "KnPage2only"; title = "読まれないはずの2ページ目"; pub = "2026-09-01T01:00:00Z" }))
[IO.File]::WriteAllText((Join-Path $apiDir "api-mock.ps1"), @'
$script:md = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:sc = [IO.File]::ReadAllText((Join-Path $script:md "scenario.json"), [Text.Encoding]::UTF8) | ConvertFrom-Json
$script:cnt = @{}
function Invoke-StandaloneApiRequest([string]$url, [int]$timeoutSec) {
  $hasKey = [int]($url -match '[?&]key=[^&]+$')
  if ($url -match '/v3/channels\?.*[?&]id=([^&]+)') { $k = "channels:" + [uri]::UnescapeDataString($Matches[1]) }
  else { $k = [uri]::UnescapeDataString([regex]::Match($url, 'playlistId=([^&]+)').Groups[1].Value) + "|" + [uri]::UnescapeDataString([regex]::Match($url, 'pageToken=([^&]+)').Groups[1].Value) }
  $n = 1 + [int]$script:cnt[$k]; $script:cnt[$k] = $n
  [IO.File]::AppendAllText((Join-Path $script:md "calls.log"), "$k`t$n`t$hasKey`n", (New-Object System.Text.UTF8Encoding($false)))   # API キー・URL は記録しない
  $steps = @($script:sc.$k)
  if ($steps.Count -eq 0 -or -not $steps[0]) { return @{ ok = $false; status = 404; reason = "HTTP 404"; apiReason = "playlistNotFound" } }
  $s = $steps[[Math]::Min($n, $steps.Count) - 1]
  if ($s.ok) { return @{ ok = $true; status = 200; content = [IO.File]::ReadAllText((Join-Path $script:md $s.file), [Text.Encoding]::UTF8) } }
  return @{ ok = $false; status = [int]$s.status; reason = [string]$s.reason; apiReason = [string]$s.apiReason }
}
'@, (New-Object System.Text.UTF8Encoding($true)))
$okStep = { param($f) @(@{ ok = $true; file = $f }) }
function Write-ApiScenario($overrides) {
  $sc = [ordered]@{}
  $sc[$uu["鷹嶺ルイ"] + "|"] = & $okStep "rui.json"
  $sc[$uu["ときのそら"] + "|"] = @(@{ ok = $false; status = 500; reason = "HTTP 500"; apiReason = "backendError" }, @{ ok = $true; file = "sora.json" })
  $sc[$uu["獅白ぼたん"] + "|"] = @(@{ ok = $false; status = 404; reason = "HTTP 404"; apiReason = "playlistNotFound" })
  $sc["channels:" + $botan] = & $okStep "botan-ch.json"
  $sc["UUbotanResolved0000000x|"] = & $okStep "botan.json"
  $sc[$uu["ロボ子さん"] + "|"] = & $okStep "roboco1.json"
  $sc[$uu["ロボ子さん"] + "|PAGE2"] = & $okStep "roboco2.json"
  $sc[$uu["音乃瀬奏"] + "|"] = & $okStep "kanade1.json"
  $sc[$uu["音乃瀬奏"] + "|PAGE2"] = & $okStep "kanade2.json"
  if ($overrides) { foreach ($k in $overrides.Keys) { $sc[$k] = $overrides[$k] } }
  [IO.File]::WriteAllText((Join-Path $apiDir "scenario.json"), ($sc | ConvertTo-Json -Depth 6), $utf8)
  if (Test-Path (Join-Path $apiDir "calls.log")) { Remove-Item -LiteralPath (Join-Path $apiDir "calls.log") }
}
function New-ApiFeedDir([string]$name) {
  $d = Join-Path $work $name; $e = Join-Path $d "entries"; New-Item -ItemType Directory -Path $e -Force | Out-Null
  # 前回の記録: ロボ子さんは1ページ目に既知の動画が無い(2ページ目を読む)、奏は1ページ目に既知の動画がある(読まない)
  foreach ($h in @(@{ id = $roboco; name = "ロボ子さん"; vid = "RbOld000001" }, @{ id = $kanadeReal; name = "音乃瀬奏"; vid = "KnKnown0001" })) {
    $doc = [ordered]@{ channelId = $h.id; streamer = $h.name; updatedAt = $old; videoCount = 1; videos = @([ordered]@{ videoId = $h.vid; title = "前回の動画"; description = ""; published = "2026-10-01T01:00:00Z"; firstSeenAt = $old; lastSeenAt = $old }) }
    [IO.File]::WriteAllText((Join-Path $e ($h.id + ".json")), ($doc | ConvertTo-Json -Depth 5), $utf8)
  }
  return $d
}
function Invoke-ApiRun([string]$feedDir, [string]$outFile, [string[]]$extra, [string]$key = $fakeKey) {
  $ErrorActionPreference = "Continue"
  $saved = $env:YOUTUBE_API_KEY; $env:YOUTUBE_API_KEY = $key
  try {
    $a = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $watch, "-FeedDir", $feedDir, "-OutFile", $outFile, "-ChannelMapPath", $apiMap, "-Source", "Api",
           "-RequestScript", (Join-Path $apiDir "api-mock.ps1"), "-RetryDelaySeconds", "0", "-RequestIntervalMs", "0") + $extra
    $o = & $psExe @a 2>&1 | ForEach-Object { "$_" }
    return [pscustomobject]@{ code = $LASTEXITCODE; output = ($o -join "`n") }
  } finally { $env:YOUTUBE_API_KEY = $saved }
}
function Get-ApiCalls() { $p = Join-Path $apiDir "calls.log"; if (Test-Path $p) { return @(([IO.File]::ReadAllText($p, [Text.Encoding]::UTF8) -split "`n") | Where-Object { $_ }) } else { return @() } }
function Read-ApiOut([string]$p) { return ([IO.File]::ReadAllText($p, [Text.Encoding]::UTF8)) | ConvertFrom-Json }

# A. 正常: 5チャンネル(再試行・再生リストの調べ直し・2ページ目あり/なし)
Write-ApiScenario $null
$fdA = New-ApiFeedDir "api-feeds-a"; $outA = Join-Path $work "api-a.json"
$ra = Invoke-ApiRun $fdA $outA @("-All", "-MaxChannels", "5", "-StartIndex", "0")
$ja = Read-ApiOut $outA; $sa = $ja.lastRun.stats; $ca = Get-ApiCalls
$idsA = @($ja.candidates | ForEach-Object { $_.videoId })
Check "19a. API 方式で5チャンネルを取得し、取得した動画を既存の判定に渡す(【8番出口】は候補)" ($ra.code -eq 0 -and $sa.source -eq "Api" -and $sa.fetched -eq 5 -and $sa.fetchFailed -eq 0 -and ($idsA -contains "ApiRui00001") -and ($idsA -contains "ApiSora0001")) ($ra.output)
Check "19b. 呼び出し回数を数える(ルイ1・そら2[500→再試行]・ぼたん3[404→調べ直し→取得]・ロボ子2[2ページ]・奏1 = 9回)" ($sa.apiCalls -eq 9 -and $ca.Count -eq 9 -and $sa.apiResolvedUploads -eq 1 -and $sa.apiPages -eq 6 -and $sa.retried -eq 1) ("calls=$($sa.apiCalls) log=$($ca.Count) pages=$($sa.apiPages) resolved=$($sa.apiResolvedUploads) retried=$($sa.retried)")
$hRobo = Read-ApiOut (Join-Path (Join-Path $fdA "entries") "$roboco.json"); $hKnd = Read-ApiOut (Join-Path (Join-Path $fdA "entries") "$kanadeReal.json"); $hRui = Read-ApiOut (Join-Path (Join-Path $fdA "entries") "$rui.json")
Check "19c. 前回の記録があり1ページ目に既知の動画が無いときだけ2ページ目を読む(ロボ子は読む・奏は読まない)" (@($hRobo.videos | Where-Object videoId -eq "ApiRobo0003").Count -eq 1 -and @($hKnd.videos | Where-Object videoId -eq "KnPage2only").Count -eq 0 -and @($ca | Where-Object { $_ -like ($uu["音乃瀬奏"] + "|PAGE2*") }).Count -eq 0) ""
Check "19d. 非公開・削除済み(videoPublishedAt が無い)動画は除き、取得した動画は履歴に記録する" (@($hRui.videos | Where-Object videoId -eq "ApiRui00001").Count -eq 1 -and @($hRui.videos | Where-Object videoId -eq "ApiRuiPriv1").Count -eq 0 -and -not ($idsA -contains "ApiRuiPriv1")) ""
Check "19e. 最後まで巡回したら次回の開始位置は 0・取り直すチャンネルは無い" ($sa.crawlNextIndex -eq 0 -and @($ja.lastRun.retryChannelIds).Count -eq 0) ("next=$($sa.crawlNextIndex) retry=$(@($ja.lastRun.retryChannelIds) -join ',')")
$keyLeak = @($ra.output, [IO.File]::ReadAllText($outA, [Text.Encoding]::UTF8), (Get-ChildItem -LiteralPath (Join-Path $fdA "entries") -File | ForEach-Object { [IO.File]::ReadAllText($_.FullName) }) -join "") | Where-Object { $_ -match [regex]::Escape($fakeKey) }
Check "19f. API キーはリクエストに付けるが、ログ・候補JSON・履歴には出さない" (@($ca | Where-Object { $_ -notmatch "`t1$" }).Count -eq 0 -and @($keyLeak).Count -eq 0) ""
$ra2 = Invoke-ApiRun $fdA $outA @("-All", "-MaxChannels", "5", "-StartIndex", "0")
$ja2 = Read-ApiOut $outA
Check "19g. 同じ内容を2回取得しても候補は増えない" ($ra2.code -eq 0 -and @($ja2.candidates).Count -eq @($ja.candidates).Count -and $ja2.lastRun.stats.newCandidates -eq 0) ("count=$(@($ja2.candidates).Count)")

# B. 呼び出しの上限: 4回で止める(ぼたんの調べ直しは上限で打ち切り → 失敗として次回に取り直す。ロボ子・奏は取得前に止める)
Write-ApiScenario $null
$fdB = New-ApiFeedDir "api-feeds-b"; $outB3 = Join-Path $work "api-b.json"
$rb = Invoke-ApiRun $fdB $outB3 @("-All", "-MaxChannels", "5", "-StartIndex", "0", "-MaxApiCalls", "4")
$jb3 = Read-ApiOut $outB3; $sb = $jb3.lastRun.stats
Check "19h. 失敗した呼び出しも数え、上限(4回)を超えて呼ばない" ($rb.code -eq 0 -and $sb.apiCalls -eq 4 -and (Get-ApiCalls).Count -eq 4 -and $sb.apiStopped -eq "limit") ("calls=$($sb.apiCalls) stopped=$($sb.apiStopped)")
Check "19i. 上限で止めたときは、試したところまで巡回位置を進め(次回 3)、取得前のチャンネルは巡回位置で次回に残す" ($sb.crawlNextIndex -eq 3 -and $sb.fetched -eq 2 -and $sb.fetchFailed -eq 1 -and $sb.fetchNotAttempted -eq 2 -and ((@($jb3.lastRun.retryChannelIds)) -join ",") -eq $botan) ("next=$($sb.crawlNextIndex) fetched=$($sb.fetched) failed=$($sb.fetchFailed) notAttempted=$($sb.fetchNotAttempted) retry=$(@($jb3.lastRun.retryChannelIds) -join ',')")

# C. 取り直し: 前回失敗したぼたん・ロボ子を先に取得(ロボ子は巡回の順でも対象だが1回だけ取得する)
Write-ApiScenario $null
$fdC = New-ApiFeedDir "api-feeds-c"; $outC3 = Join-Path $work "api-c.json"
$rc = Invoke-ApiRun $fdC $outC3 @("-All", "-MaxChannels", "3", "-StartIndex", "3", "-PriorityChannelId", "$botan,$roboco,UCbadId")
$jc3 = Read-ApiOut $outC3; $sc3 = $jc3.lastRun.stats; $cc = Get-ApiCalls
Check "19j. 取り直すチャンネルを先に取得し(-MaxChannels の枠に含める)、成功したチャンネルは同じ実行で取り直さない" ($rc.code -eq 0 -and $sc3.priorityTargets -eq 2 -and $sc3.fetched -eq 2 -and $cc[0] -like ($uu["獅白ぼたん"] + "|*") -and @($cc | Where-Object { $_ -like ($uu["ロボ子さん"] + "|`t*") }).Count -eq 1 -and @($jc3.lastRun.retryChannelIds).Count -eq 0) ("prio=$($sc3.priorityTargets) fetched=$($sc3.fetched) calls=$($cc -join ' | ')")
Check "19k. 巡回位置は対応表の順の分だけ進め(3 → 4)、形式の正しくない取り直しIDはエラーにする" ($sc3.crawlNextIndex -eq 4 -and @($jc3.lastRun.errors | Where-Object { $_.channelId -eq "UCbadId" }).Count -eq 1) ("next=$($sc3.crawlNextIndex)")

# D. 利用枠の超過: そらで quotaExceeded → その時点で取得をやめる(取得できた分は判定・残りは次回)
Write-ApiScenario @{ ($uu["ときのそら"] + "|") = @(@{ ok = $false; status = 403; reason = "HTTP 403"; apiReason = "quotaExceeded" }) }
$fdD = New-ApiFeedDir "api-feeds-d"; $outD = Join-Path $work "api-d.json"
$rd = Invoke-ApiRun $fdD $outD @("-All", "-MaxChannels", "5", "-StartIndex", "0")
$jd = Read-ApiOut $outD; $sd = $jd.lastRun.stats
Check "19l. quotaExceeded では再試行せずに取得をやめ、取得できた分は判定し、そらは次回に取り直す" ($rd.code -eq 0 -and $sd.apiStopped -eq "quota" -and $sd.apiCalls -eq 2 -and $sd.fetched -eq 1 -and $sd.crawlNextIndex -eq 2 -and ((@($jd.lastRun.retryChannelIds)) -join ",") -eq $sora -and (@($jd.candidates | ForEach-Object videoId) -contains "ApiRui00001")) ("code=$($rd.code) stopped=$($sd.apiStopped) calls=$($sd.apiCalls) next=$($sd.crawlNextIndex)")

# E. キーの誤り(400 keyInvalid): 1回目で取得をやめ、終了コード 3
Write-ApiScenario @{ ($uu["鷹嶺ルイ"] + "|") = @(@{ ok = $false; status = 400; reason = "HTTP 400"; apiReason = "keyInvalid" }) }
$fdE = New-ApiFeedDir "api-feeds-e"; $outE = Join-Path $work "api-e.json"
$re = Invoke-ApiRun $fdE $outE @("-All", "-MaxChannels", "5", "-StartIndex", "0")
Check "19m. API キー・権限のエラーでは、それ以上呼ばずに終了コード 3 で止める" ($re.code -eq 3 -and (Get-ApiCalls).Count -eq 1 -and (Read-ApiOut $outE).lastRun.stats.apiStopped -eq "fatal") ("code=$($re.code) calls=$((Get-ApiCalls).Count)")

# F. API キーが無い・指定の組み合わせが正しくない: 何も呼ばずに止め、出力ファイルを作らない
Write-ApiScenario $null
$outF2 = Join-Path $work "api-f.json"
$rf = Invoke-ApiRun (New-ApiFeedDir "api-feeds-f") $outF2 @("-All", "-MaxChannels", "5") ""
Check "19n. API キーが無いときは何も呼ばずに止め、出力ファイルを作らない" ($rf.code -ne 0 -and (Get-ApiCalls).Count -eq 0 -and -not (Test-Path $outF2)) ("code=$($rf.code)")
$rg = Invoke-ApiRun (New-ApiFeedDir "api-feeds-g") $outF2 @("-Streamer", "鷹嶺ルイ", "-PriorityChannelId", $rui)
Check "19o. -PriorityChannelId は -All と一緒でないと止める" ($rg.code -ne 0 -and (Get-ApiCalls).Count -eq 0) ("code=$($rg.code)")

$hashAfter = @($dataFiles | ForEach-Object { (Get-FileHash $_ -Algorithm SHA256).Hash })
Check "9a. 本番の data-core.js / data-playlists.js / data-standalone.js を変更しない" (($hashBefore -join ",") -eq ($hashAfter -join ",")) ""

Remove-Item -LiteralPath $work -Recurse -Force
Write-Output ""
Write-Output "PASS: $pass  FAIL: $fail"
if ($fail -gt 0) { exit 1 }
