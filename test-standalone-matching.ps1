<#
.SYNOPSIS
  単発実況の候補判定(standalone-matching.ps1)の回帰テスト。YouTube API・Node.js は使わない。

.DESCRIPTION
  本番の data-core.js の GAMES(name / nameJa / aliases)をそのまま読み込み、
  単発実況 候補抽出精度監査 #1(_seo/standalone-discovery-audit.md)で確認した誤判定・危険な一致が
  再発しないこと、正しい候補が HIGH のまま残ることを確認する。
  本番データは読み取りのみで、変更しない。

.EXAMPLE
  .\test-standalone-matching.ps1
#>
param()
$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir "standalone-matching.ps1")

# ---- 本番の GAMES を読む(1ゲーム1行の書式) ----
$core = [IO.File]::ReadAllText((Join-Path $scriptDir "data-core.js"), [Text.Encoding]::UTF8)
$gamesBlock = $core.Substring($core.IndexOf("const GAMES = ["))
$gamesBlock = $gamesBlock.Substring(0, $gamesBlock.IndexOf("`n];"))
$games = foreach ($line in ($gamesBlock -split "`n")) {
  $m = [regex]::Match($line, '^\s*\{\s*name:\s*"((?:\\.|[^"])*)"')
  if (-not $m.Success) { continue }
  $names = @($m.Groups[1].Value)
  $ja = [regex]::Match($line, 'nameJa:\s*"((?:\\.|[^"])*)"'); if ($ja.Success) { $names += $ja.Groups[1].Value }
  $al = [regex]::Match($line, 'aliases:\s*\[([^\]]*)\]')
  if ($al.Success) { $names += @([regex]::Matches($al.Groups[1].Value, '"((?:\\.|[^"])*)"') | ForEach-Object { $_.Groups[1].Value }) }
  [pscustomobject]@{ name = $m.Groups[1].Value; aliases = @($names | ForEach-Object { $_ -replace '\\"', '"' }) }
}
$streamersBlock = $core.Substring($core.IndexOf("const STREAMERS = ["))
$streamersBlock = $streamersBlock.Substring(0, $streamersBlock.IndexOf("`n];"))
$streamerNames = @([regex]::Matches($streamersBlock, '\{\s*name:\s*"((?:\.|[^"])*)"') | ForEach-Object { $_.Groups[1].Value })
$index = New-StandaloneGameIndex $games $streamerNames

$pass = 0; $fail = 0
function Check([string]$name, [bool]$ok, [string]$detail) {
  if ($ok) { $script:pass++; Write-Output "  [PASS] $name" } else { $script:fail++; Write-Output "  [FAIL] $name`n         $detail" }
}
function M([string]$title, [string]$desc = "", $ctx = $null) { return (Get-StandaloneMatch $index $title $desc $ctx) }
function Show($m) { if (-not $m) { return "(一致なし)" }; return ($m.game + " / " + $m.confidence + " / " + $m.matchType + " / " + ($m.reasons -join "; ")) }

Write-Output "=== 単発実況 候補判定 回帰テスト(GAMES $($games.Count) 件・VTuber $($streamerNames.Count) 名) ==="

# ---- 1. 前回の FALSE POSITIVE(UNO: 説明欄のローマ字に "uno" が埋もれていた) ----
foreach ($d in @("illust: Siokazunoko", "mix: suzunoki", "thumbnail: chanmarorunoe")) {
  $m = M "【雑談】ゆるっとおしゃべり" $d
  Check ("1. 説明欄 '" + $d + "' で UNO に一致しない") (-not $m -or $m.game -ne "UNO") (Show $m)
}
$m = M "【UNO】みんなでUNOバトル！"
Check "1. 【UNO】は UNO で HIGH" ($m.game -eq "UNO" -and $m.confidence -eq "HIGH") (Show $m)

# ---- 2. 最長一致が説明欄を優先していた(DARK SOULS III → DARK SOULS REMASTERED) ----
$m = M "【DARK SOULS III】ついに最終ボス #9" "DARK SOULS REMASTERED 完結 再生リストはこちら"
Check "2. タイトルの【DARK SOULS III】を説明欄より優先する" ($m.game -eq "DARK SOULS III") (Show $m)
Check "2. 連番(#9)付きは HIGH にしない" ($m.confidence -eq "MEDIUM") (Show $m)
$m = M "【DARK SOULS 3】初見でいく"
Check "2. 表記揺れ: 【DARK SOULS 3】も DARK SOULS III で HIGH" ($m.game -eq "DARK SOULS III" -and $m.confidence -eq "HIGH") (Show $m)
$m = M "【Dark Souls Ⅲ】初見でいく"
Check "2. 表記揺れ: 全角ローマ数字・小文字も吸収" ($m.game -eq "DARK SOULS III" -and $m.confidence -eq "HIGH") (Show $m)
$m = M "【ダクソ】初見でいく"
Check "2. 共有別名「ダクソ」(4作品)だけでは HIGH にしない" ($m -and $m.confidence -ne "HIGH") (Show $m)

# ---- 3. 似た名前(Coffee Talk Tokyo → Coffee Talk) ----
$m = M "【Coffee Talk Tokyo】喫茶店のマスターになる"
Check "3. 【Coffee Talk Tokyo】は Coffee Talk の HIGH にしない" (-not $m -or $m.confidence -ne "HIGH") (Show $m)

# ---- 4. 短いゲーム名 ----
$m = M "REACH THE PEAK!! 山頂めざしてがんばる"
Check "4. PEAK: 【】の外の一般語一致は HIGH にしない" (-not $m -or $m.game -ne "PEAK" -or $m.confidence -ne "HIGH") (Show $m)
$m = M "【PEAK】みんなで山登り"
Check "4. 【PEAK】は HIGH" ($m.game -eq "PEAK" -and $m.confidence -eq "HIGH") (Show $m)
foreach ($t in @("trust me!! 信じて", "Rustaceanになりたい", "frustration 限界")) {
  $m = M $t
  Check ("4. '" + $t + "' で Rust に一致しない") (-not $m -or $m.game -ne "Rust") (Show $m)
}
$m = M "Rust サーバーでまったり"
Check "4. 【】外の 'Rust' は MEDIUM まで" ($m.game -eq "Rust" -and $m.confidence -eq "MEDIUM") (Show $m)
$m = M "【Rust】拠点づくり"
Check "4. 【Rust】は HIGH" ($m.game -eq "Rust" -and $m.confidence -eq "HIGH") (Show $m)
$m = M "【R.E.P.O.】ホラー回収バイト"
Check "4. 【R.E.P.O.】は HIGH" ($m.game -eq "R.E.P.O." -and $m.confidence -eq "HIGH") (Show $m)
$m = M "【REPO】ホラー回収バイト"
Check "4. 表記揺れ: 【REPO】も R.E.P.O. で HIGH" ($m.game -eq "R.E.P.O." -and $m.confidence -eq "HIGH") (Show $m)
$m = M "【雑談】repository整理するよ"
Check "4. 'repository' で R.E.P.O. に一致しない" (-not $m -or $m.game -ne "R.E.P.O.") (Show $m)

# ---- 5. 部分一致(日本語) ----
$m = M "【超魔界村】クリアまで"
Check "5. 漢字の続き(超+魔界村)は別タイトルの一部として扱う" (-not $m -or $m.confidence -ne "HIGH" -or $m.matchType -eq "bracket-exact") (Show $m)

# ---- 6. 複数ゲーム ----
$m = M "【Minecraft】からの【ARK: Survival Evolved】はしご配信"
Check "6. タイトルに2ゲーム → HIGH にしない" ($m -and $m.confidence -ne "HIGH" -and $m.otherGames.Count -ge 1) (Show $m)
$m = M "【Minecraft×Rust】コラボ"
Check "6. 【A×B】の複数ゲーム → HIGH にしない" (-not $m -or $m.confidence -ne "HIGH") (Show $m)

# ---- 6b. VTuber名の中のゲーム名(再監査で確認: 「大神ミオ」→ 大神) ----
$m = M "【MLBxhololive】ドジャース VS レッズ 同時視聴【博衣こより/大神ミオ】"
Check "6b. 「大神ミオ」の中の「大神」でゲーム「大神」に一致しない" (-not $m -or $m.game -ne "大神") (Show $m)
$m = M "【ARK】DAY3" "コラボ: 大神ミオ・白上フブキ"
Check "6b. 説明欄の「大神ミオ」でも「大神」に一致しない" (-not $m -or $m.game -ne "大神") (Show $m)
$m = M "【大神 絶景版】初見でいく"
Check "6b. ゲーム名としての「大神 絶景版」は HIGH のまま" ($m.game -eq "大神 絶景版" -and $m.confidence -eq "HIGH") (Show $m)

# ---- 7. 非ゲーム ----
foreach ($t in @("【歌枠】Minecraftの曲も歌う", "【雑談】夜勤事件の話", "【新衣装】お披露目", "【MV】オリジナル曲", "【告知】GeoGuessr大会のお知らせ")) {
  $m = M $t
  Check ("7. '" + $t + "' は HIGH にしない") (-not $m -or $m.confidence -ne "HIGH") (Show $m)
}

# ---- 8. 前回 HIGH で正解だったもの(Recall の確認) ----
foreach ($c in @(@("【GeoGuessr】世界を旅する", "GeoGuessr"), @("【空気読み。】空気を読んでいく", "空気読み。"), @("【R.E.P.O.】いくぞ", "R.E.P.O."), @("【夜勤事件】幽霊なんて、科学の力でワンパンです！【宙科そぴあ/ホロライブ/アソビ★まわり隊！】", "夜勤事件"), @("【壺おじ】ついにクリアする", "壺おじ"))) {
  $m = M $c[0]
  Check ("8. '" + $c[0].Substring(0, [Math]::Min(20, $c[0].Length)) + "…' は " + $c[1] + " で HIGH") ($m.game -eq $c[1] -and $m.confidence -eq "HIGH") (Show $m)
}

# ---- 9. 説明欄 ----
$m = M "#わちゃわちゃカメレオン みんなで遊ぶ" "配信タイトル:めっちゃカメレオン`nいつもありがとう"
Check "9. 説明欄の「配信タイトル:」行の一致は MEDIUM" ($m.game -eq "めっちゃカメレオン" -and $m.confidence -eq "MEDIUM") (Show $m)
$m = M "今日はのんびり" "今日は GeoGuessr の話もしたけど、ほぼ雑談"
Check "9. 説明欄だけの一致は LOW" ($m.game -eq "GeoGuessr" -and $m.confidence -eq "LOW") (Show $m)

# ---- 10. 登録状況による格下げ ----
$ctx = @{ siteHasGamePlaylist = { param($g) $g -eq "7 Days to Die" }; dedicatedPlaylists = { param($g) if ($g -eq "Minecraft") { @([pscustomobject]@{ id = "PLx"; title = "Minecraft ハードコア"; count = 6 }) } else { @() } } }
$m = M "【7 Days to Die】初日" "" $ctx
Check "10. 同じVTuber×ゲームの再生リストが登録済みなら MEDIUM" ($m.confidence -eq "MEDIUM") (Show $m)
$m = M "【Minecraft】ハードコア" "" $ctx
Check "10. チャンネル側に専用再生リストがあれば MEDIUM" ($m.confidence -eq "MEDIUM") (Show $m)

# ---- 10b. 専用再生リスト判定(discover と同じ呼び出し方: GetNewClosure + 関数参照) ----
$pls = @([pscustomobject]@{ id = "PLx"; title = "GeoGuessr まとめ"; count = 3 }, [pscustomobject]@{ id = "PLy"; title = "ゲーム"; count = 9 })
$findDedicated = ${function:Get-StandaloneDedicatedPlaylists}
$dedNone = { param($g) & $findDedicated $games $g @($pls[1]) }.GetNewClosure()
$dedHit = { param($g) & $findDedicated $games $g $pls }.GetNewClosure()
$m = M "【GeoGuessr】場所当て" "" @{ dedicatedPlaylists = $dedNone }
Check "10b. 専用PLなし(0件)なら HIGH のまま(空配列を1件と数えない)" ($m.confidence -eq "HIGH" -and $m.dedicatedPlaylists.Count -eq 0) (Show $m)
$m = M "【GeoGuessr】場所当て" "" @{ dedicatedPlaylists = $dedHit }
Check "10b. ゲーム名入りのチャンネルPLがあれば MEDIUM" ($m.confidence -eq "MEDIUM" -and $m.dedicatedPlaylists.Count -eq 1 -and $m.dedicatedPlaylists[0].id -eq "PLx") (Show $m)
$disc = [IO.File]::ReadAllText((Join-Path $PSScriptRoot "discover-standalone.ps1"), [Text.Encoding]::UTF8)
Check "10b. discover はクロージャ内で関数参照経由で専用PL判定を呼ぶ" ($disc.Contains('${function:Get-StandaloneDedicatedPlaylists}') -and $disc.Contains('New-StandaloneGameIndex $games $allStreamerNames'))

# ---- 11. 重複除外(STANDALONE_PLAYS・再生リスト) ----
$standaloneText = [IO.File]::ReadAllText((Join-Path $scriptDir "data-standalone.js"), [Text.Encoding]::UTF8)
$ids = Get-StandaloneRegisteredVideoIds $standaloneText
Check "11. STANDALONE_PLAYS の登録済み動画(宙科そぴあ × 夜勤事件 Ac-DypNuXyc)を除外対象にする" ($ids.Contains("Ac-DypNuXyc")) ("取得: " + ($ids -join ","))
Check "11. コメント内の例(watch?v=...)は除外対象に含めない" ($ids.Count -eq 1) ("件数: " + $ids.Count)
$discover = [IO.File]::ReadAllText((Join-Path $scriptDir "discover-standalone.ps1"), [Text.Encoding]::UTF8)
Check "11. discover は再生リスト登録済み・STANDALONE_PLAYS 登録済みの動画を判定前に外す" (($discover -match 'if \(\$knownVideoIds\.Contains\(\$v\.videoId\)\) \{ continue \}') -and ($discover -match 'if \(\$standaloneVideoIds\.Contains\(\$v\.videoId\)\) \{ continue \}')) ""
Check "11. discover は Get-StandaloneMatch で判定し、旧来の最長一致ロジックを持たない" (($discover -match 'Get-StandaloneMatch \$gameIndex') -and -not ($discover -match '\$bestLen')) ""

Write-Output ""
Write-Output "PASS: $pass  FAIL: $fail"
if ($fail -gt 0) { exit 1 }
