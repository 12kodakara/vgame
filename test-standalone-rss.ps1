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
$r3 = Invoke-Watch $feeds2
$j3 = Read-Out
Check "7a. 取得・解析がすべて失敗しても既存の候補5件は残る" (@($j3.candidates).Count -eq 5 -and @($j3.lastRun.errors).Count -eq 1) ("count=$(@($j3.candidates).Count)")

Write-Output "== 既存の候補ファイルが壊れている場合"
$broken = '{"candidates": [ 壊れたJSON'
[IO.File]::WriteAllText($out, $broken, $utf8)
$r4 = Invoke-Watch
Check "8a. 壊れた候補ファイルは上書きせずに中止する(終了コード≠0・内容そのまま)" ($r4.code -ne 0 -and ([IO.File]::ReadAllText($out, [Text.Encoding]::UTF8)) -eq $broken) ("code=$($r4.code)")
Check "8b. 一時ファイル(.tmp)を残さない" (-not (Test-Path ($out + ".tmp"))) ""

$hashAfter = @($dataFiles | ForEach-Object { (Get-FileHash $_ -Algorithm SHA256).Hash })
Check "9a. 本番の data-core.js / data-playlists.js / data-standalone.js を変更しない" (($hashBefore -join ",") -eq ($hashAfter -join ",")) ""

Remove-Item -LiteralPath $work -Recurse -Force
Write-Output ""
Write-Output "PASS: $pass  FAIL: $fail"
if ($fail -gt 0) { exit 1 }
