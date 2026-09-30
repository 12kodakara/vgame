<#
.SYNOPSIS
  validate-data.ps1 の STANDALONE_PLAYS(単発・PLなし実況)検証の回帰テスト。

.DESCRIPTION
  一時フォルダに validate-data.ps1 と本番 data-core.js(STREAMERS/GAMES/GENRES)を
  コピーし、テスト用の data-playlists.js / data-standalone.js を書いて実行する。
  ケースごとに「出るべきエラー」「出てはいけないエラー」を確認する。
  YouTube API と Node.js は使わない。本番の data-playlists.js / data-standalone.js は
  読み取りも変更もしない(一時フォルダは最後に削除する)。

  テスト用 PLAYLISTS には「姫森ルーナ × 夜勤事件」の再生リストを1件だけ置き、
  再生リストとの重複判定(同じVTuber×ゲーム / mixedPlaylistUrl)を確認する。

.EXAMPLE
  .\test-standalone-validation.ps1
#>
param()

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$validator = Join-Path $scriptDir "validate-data.ps1"
$corePath = Join-Path $scriptDir "data-core.js"
foreach ($p in @($validator, $corePath)) { if (-not (Test-Path $p)) { Write-Error "見つかりません: $p"; exit 1 } }

$work = Join-Path ([IO.Path]::GetTempPath()) ("vgame-standalone-test-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory $work | Out-Null
Copy-Item $validator $work
Copy-Item $corePath $work
$utf8 = New-Object System.Text.UTF8Encoding $false

$registeredPlaylistId = "PL6gUpTCMieF6ST4fiDt736lK32alFp8U4"
$playlistsJs = @"
const PLAYLISTS = [
  { id: "t-001", title: "夜勤事件", streamer: "姫森ルーナ", game: "夜勤事件", genre: "horror", playlistId: "$registeredPlaylistId", thumbnailUrl: "https://i.ytimg.com/vi/xxxxxxxxxxx/mqdefault.jpg", updatedDate: "2026-09-01" },
];
"@
[IO.File]::WriteAllText((Join-Path $work "data-playlists.js"), $playlistsJs, $utf8)

# 1件分の単発実況オブジェクトを作る(上書きしたい項目だけ指定する)
function Entry([hashtable]$o) {
  $d = [ordered]@{ id = "single-t"; title = "夜勤事件 単発実況"; streamer = "宙科そぴあ"; game = "夜勤事件"; genre = "horror"; format = "single" }
  foreach ($k in $o.Keys) { $d[$k] = $o[$k] }
  $videos = if ($o.ContainsKey("videos")) { $o["videos"] } else { @("https://www.youtube.com/watch?v=Ac-DypNuXyc") }
  $parts = foreach ($k in $d.Keys) { if ($k -ne "videos" -and $null -ne $d[$k]) { "$k`: `"$($d[$k])`"" } }
  $vparts = foreach ($u in $videos) { "{ title: `"配信タイトル`", url: `"$u`", publishedDate: `"2026-09-28`" }" }
  return "  { " + ($parts -join ", ") + ", videos: [ " + ($vparts -join ", ") + " ] }"
}

# 本番ファイルと同じく、先頭に登録例のコメントを残した形で書く
$commentHeader = @"
const STANDALONE_PLAYS = [
  // 登録例(コメント内の { } や "https://..." は無視されること)
  // {
  //   id: "single-001", title: "ゲーム名 単発実況", streamer: "実況者名", game: "ゲーム名",
  //   videos: [ { title: "配信タイトル", url: "https://www.youtube.com/watch?v=...", publishedDate: "2026-01-01" } ]
  // }
"@

$cases = @(
  @{ name = "登録0件(コメントの登録例だけ)"; entries = @(); expectCount = 0; expect = @(); forbid = @("*") }
  @{ name = "正常: 宙科そぴあ × 夜勤事件 single"; entries = @((Entry @{})); expectCount = 1; expect = @(); forbid = @("*") }
  @{ name = "正常: youtu.be / live URL の multi"; entries = @((Entry @{ format = "multi"; videos = @("https://youtu.be/Ac-DypNuXyc", "https://www.youtube.com/live/NBPgxu6pLgk") })); expectCount = 1; expect = @(); forbid = @("*") }
  @{ name = "必須項目欠落(genre)"; entries = @((Entry @{ genre = $null })); expect = @("単発:必須項目欠落(genre)") }
  @{ name = "format不正"; entries = @((Entry @{ format = "series" })); expect = @("単発:format不正") }
  @{ name = "ID重複"; entries = @((Entry @{}), (Entry @{ videos = @("https://www.youtube.com/watch?v=NBPgxu6pLgk") })); expect = @("単発:ID重複"); forbid = @("単発:video ID重複") }
  @{ name = "動画URL不正(video IDが11文字でない)"; entries = @((Entry @{ videos = @("https://www.youtube.com/watch?v=abc") })); expect = @("単発:動画URL不正") }
  @{ name = "動画URL不正(YouTube以外)"; entries = @((Entry @{ videos = @("https://example.com/watch?v=Ac-DypNuXyc") })); expect = @("単発:動画URL不正") }
  @{ name = "video ID重複(別エントリ)"; entries = @((Entry @{}), (Entry @{ id = "single-t2"; game = "PEAK" })); expect = @("単発:video ID重複"); forbid = @("単発:ID重複") }
  @{ name = "未登録VTuber"; entries = @((Entry @{ streamer = "存在しないVTuber" })); expect = @("単発:未登録VTuber") }
  @{ name = "未登録ゲーム"; entries = @((Entry @{ game = "存在しないゲーム" })); expect = @("単発:未登録ゲーム") }
  @{ name = "未登録ジャンル"; entries = @((Entry @{ genre = "nope" })); expect = @("単発:未登録ジャンル") }
  @{ name = "single に動画2本"; entries = @((Entry @{ videos = @("https://www.youtube.com/watch?v=Ac-DypNuXyc", "https://www.youtube.com/watch?v=NBPgxu6pLgk") })); expect = @("単発:formatと動画数の不一致") }
  @{ name = "再生リスト重複(同じVTuber×ゲームのPLが登録済み)"; entries = @((Entry @{ streamer = "姫森ルーナ" })); expect = @("単発:再生リスト重複") }
  @{ name = "再生リスト重複(mixedPlaylistUrlが登録済みPL)"; entries = @((Entry @{ format = "mixed-playlist"; mixedPlaylistUrl = "https://www.youtube.com/playlist?list=$registeredPlaylistId" })); expect = @("単発:再生リスト重複") }
  @{ name = "mixedPlaylistUrl不正"; entries = @((Entry @{ format = "mixed-playlist"; mixedPlaylistUrl = "https://www.youtube.com/watch?v=Ac-DypNuXyc" })); expect = @("単発:再生リストURL不正") }
)

$pass = 0; $fail = 0
try {
  foreach ($c in $cases) {
    $js = $commentHeader + "`n" + (@($c.entries) -join ",`n") + "`n];`n"
    [IO.File]::WriteAllText((Join-Path $work "data-standalone.js"), $js, $utf8)
    $jsonPath = Join-Path $work "report.json"
    if (Test-Path $jsonPath) { Remove-Item $jsonPath }
    $null = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $work "validate-data.ps1") -Json $jsonPath
    $report = Get-Content $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $keys = @($report.errors.PSObject.Properties | ForEach-Object { $_.Name } | Where-Object { $_ -like "単発:*" })
    $problems = @()
    foreach ($e in @($c.expect)) { if ($keys -notcontains $e) { $problems += "期待したエラーが出ない: $e" } }
    foreach ($f in @($c.forbid)) {
      if ($f -eq "*") { if ($keys.Count -gt 0) { $problems += "エラーが出てはいけない: " + ($keys -join ", ") } }
      elseif ($keys -contains $f) { $problems += "出てはいけないエラー: $f" }
    }
    if ($c.ContainsKey("expectCount") -and $report.standaloneCount -ne $c.expectCount) { $problems += "単発実況件数 $($report.standaloneCount) (期待 $($c.expectCount))" }
    if ($problems.Count -eq 0) { $pass++; Write-Output "  OK   $($c.name)" }
    else { $fail++; Write-Output "  FAIL $($c.name)"; $problems | ForEach-Object { Write-Output "         $_" }; Write-Output ("         検出: " + ($keys -join ", ")) }
  }
} finally {
  Remove-Item -Recurse -Force $work
}

Write-Output ""
Write-Output "結果: $pass 件成功 / $fail 件失敗"
if ($fail -gt 0) { exit 1 } else { exit 0 }
