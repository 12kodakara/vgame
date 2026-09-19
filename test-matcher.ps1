<#
.SYNOPSIS
  match-playlist-candidates.ps1 の候補生成ロジックの回帰テスト。

.DESCRIPTION
  版語(リメイク / HD / DX / DLC / Collection など)を含む playlist タイトルが、
  短い既存ゲーム名や略称aliasだけで誤ったゲームへ自動確定しないこと、および
  正当な版表記・拡張名の一致は妨げられないことを、テーブル駆動で確認する。

  仕組み:
    テストケースのタイトルから discover-playlists.ps1 と同じ形式の合成JSONを作り、
    match-playlist-candidates.ps1 に通して候補を検証する。YouTube APIは使わない。
    本番 data-core.js / data-playlists.js は読み取りのみで、変更しない。

  判定項目(ケースごとに指定したものだけを検査する):
    expectCount      候補件数
    expectTopGame    最も高い confidence の候補のゲーム名
    expectTopConf    その候補の confidence
    expectAmbiguous  ambiguousMatch
    expectNotGame    この候補が含まれてはいけないゲーム名
    expectTokens     検出されるべき版語クラス(カンマ区切り、順不同)
    expectNoTokens   検出されてはいけない版語クラス

.PARAMETER Json
  結果をJSONで書き出す先(任意)。

.EXAMPLE
  .\test-matcher.ps1
#>
param(
  [string]$Json
)

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$matcher = Join-Path $scriptDir "match-playlist-candidates.ps1"
if (-not (Test-Path $matcher)) { Write-Error "match-playlist-candidates.ps1 が見つかりません: $matcher"; exit 1 }

# ---- テストケース表 ----
$cases = @(
  # --- 版語なし: 従来どおりの一致を壊さない ---
  @{ n = "1. 版語なし 正式名一致";           title = "モンスターハンターライズ";
     expectCount = 1; expectTopGame = "モンスターハンターライズ"; expectTopConf = "HIGH"; expectAmbiguous = $false; expectTokens = "" }
  @{ n = "2. 版語なし 共有aliasは複数候補";   title = "モンハン";
     expectAmbiguous = $true; expectTokens = "" }
  @{ n = "3. 版語なし ナンバリング";          title = "ドラゴンクエストII";
     expectTopGame = "ドラゴンクエストII"; expectTokens = "" }

  # --- 原則A: 拡張名が alias に登録されている場合は正当な根拠として使う ---
  @{ n = "4. 拡張名aliasへ収束(原則C)";       title = "モンハンサンブレイク";
     expectCount = 1; expectTopGame = "モンスターハンターライズ"; expectAmbiguous = $false }
  @{ n = "5. 本編名+拡張名の併記";            title = "モンハンライズ：サンブレイク";
     expectCount = 1; expectTopGame = "モンスターハンターライズ"; expectAmbiguous = $false }
  @{ n = "6. 拡張名のみ";                     title = "サンブレイク";
     expectCount = 1; expectTopGame = "モンスターハンターライズ"; expectAmbiguous = $false }

  # --- 原則A: 版語が正式名に含まれるゲームを優先する ---
  @{ n = "7. HD版を持つゲーム";               title = "ゼルダの伝説 スカイウォードソードHD";
     expectCount = 1; expectTopGame = "ゼルダの伝説 スカイウォードソード HD"; expectTopConf = "HIGH"; expectTokens = "hd" }
  @{ n = "8. Remastered版を持つゲーム";       title = "DARK SOULS REMASTERED";
     expectCount = 1; expectTopGame = "DARK SOULS REMASTERED"; expectTopConf = "HIGH"; expectTokens = "remaster" }
  @{ n = "9. Collectionを持つゲーム";         title = "逆転裁判123 成歩堂セレクション";
     expectCount = 1; expectTopGame = "逆転裁判123 成歩堂セレクション"; expectTopConf = "HIGH" }

  # --- 原則B: 版語があるのにカタログが版を区別していないならHIGHに上げない ---
  @{ n = "10. リメイク版が未登録";            title = "スーパーマリオRPGリメイク";
     expectCount = 1; expectTopGame = "スーパーマリオRPG"; expectTopConf = "MEDIUM"; expectTokens = "remake" }
  @{ n = "11. Remastered版が未登録";          title = "【進行中】テイルズ オブ シンフォニア Remastered";
     expectCount = 1; expectTopGame = "テイルズ オブ シンフォニア"; expectTopConf = "MEDIUM"; expectTokens = "remaster" }

  # --- 誤吸収防止: 短い既存ゲーム名へ短絡しない ---
  @{ n = "12. 短いナンバリングへ短絡しない";  title = "ドラクエIIリメイク";
     expectNotGame = "ドラゴンクエストII"; expectTokens = "remake" }
  @{ n = "13. 集約リメイクへ寄る";            title = "ドラクエⅠ&Ⅱ リメイク";
     expectCount = 1; expectTopGame = "ドラゴンクエストI・II・III HD-2D Remake"; expectNotGame = "ドラゴンクエストII" }

  # --- DLC/拡張は本編へ統合する既存運用を壊さない(原則Bの対象外) ---
  @{ n = "14. DLC語でHIGHを落とさない";       title = "【完結】ゼノブレイド3 DLC";
     expectCount = 1; expectTopGame = "ゼノブレイド3"; expectTopConf = "HIGH"; expectTokens = "dlc" }
  @{ n = "15. 本編+DLC表記";                  title = "Outer Wilds+DLC";
     expectCount = 1; expectTopGame = "Outer Wilds"; expectTopConf = "HIGH"; expectTokens = "dlc" }

  # --- false positive を起こさない ---
  @{ n = "16. DXはブランド名の一部";          title = "beatmania IIDX INFINITAS";
     expectCount = 1; expectTopGame = "beatmania IIDX INFINITAS"; expectTopConf = "HIGH"; expectNoTokens = "dx" }
  @{ n = "17. デラックスは正式名の一部";      title = "星のカービィ スーパーデラックス";
     expectCount = 1; expectTopGame = "星のカービィ スーパーデラックス"; expectTopConf = "HIGH" }
  @{ n = "18. Completeは実況の完結表示";      title = "Cuphead (Complete)";
     expectCount = 1; expectTopGame = "Cuphead"; expectTopConf = "HIGH"; expectNoTokens = "complete" }
  @{ n = "19. Ultimateは正式名の一部";        title = "FallGuys: Ultimate Knockout 👊";
     expectCount = 1; expectTopGame = "Fall Guys"; expectTopConf = "HIGH"; expectNoTokens = "ultimate" }
  @{ n = "20. DDLCからDLCを切り出さない";     title = "Doki Doki Literature Club (DDLC)";
     expectCount = 1; expectTopGame = "Doki Doki Literature Club"; expectTopConf = "HIGH"; expectNoTokens = "dlc" }
  @{ n = "21. コレクションが正式名の一部";    title = "トモダチコレクション 新生活";
     expectCount = 1; expectTopGame = "トモダチコレクション 新生活"; expectTopConf = "HIGH" }

  # --- 定着した短縮カナ表記(ブレワイ)を拾えること ---
  #     alias一致はHIGHに昇格しない仕様のため、期待値は MEDIUM である。
  @{ n = "22. 短縮カナalias 単独";            title = "ブレワイ";
     expectCount = 1; expectTopGame = "ゼルダの伝説 ブレス オブ ザ ワイルド"; expectTopConf = "MEDIUM"; expectAmbiguous = $false }
  @{ n = "23. 短縮カナalias 装飾付き";        title = "【ブレワイ】";
     expectCount = 1; expectTopGame = "ゼルダの伝説 ブレス オブ ザ ワイルド" }
  # 総称game「ゼルダの伝説」も同時に一致するため ambiguous になるが、
  # 正解が候補に含まれること自体が改善点なので、そこを固定する。
  @{ n = "24. 総称名と併記(ambiguous)";       title = "ゼルダの伝説 ブレワイ";
     expectAmbiguous = $true; expectContainsGame = "ゼルダの伝説 ブレス オブ ザ ワイルド" }

  # --- 英字3文字「BOW」はaliasに登録していないため、一般語・人名・別作品名から
  #     切り出されて誤一致しないこと(監査で D 判定にした表記) ---
  @{ n = "25. 未登録の3文字略称は一致しない"; title = "BOW";
     expectCount = 0 }
  @{ n = "26. 一般語Rainbowから切り出さない"; title = "Rainbow";
     expectCount = 0 }
  @{ n = "27. 人名BOWIEから切り出さない";     title = "BOWIE";
     expectCount = 0 }
  @{ n = "28. 一般語BOWMANから切り出さない";  title = "BOWMAN 実況";
     expectCount = 0 }
  @{ n = "29. bowを含む既存gameは自分自身へ"; title = "Rainbow Six Siege";
     expectCount = 1; expectTopGame = "Rainbow Six Siege"; expectTopConf = "HIGH"; expectNotGame = "ゼルダの伝説 ブレス オブ ザ ワイルド" }

  # --- 英字略称 APEX を拾えること。alias一致はHIGHに昇格しないため期待値は MEDIUM ---
  @{ n = "30. 英字略称alias 単独(APEX)";      title = "APEX";
     expectCount = 1; expectTopGame = "Apex Legends"; expectTopConf = "MEDIUM"; expectAmbiguous = $false }
  @{ n = "31. 装飾付きの英字略称";            title = "🔫APEX🔫";
     expectCount = 1; expectTopGame = "Apex Legends" }
  @{ n = "32. 正式名は従来どおりHIGH";        title = "Apex Legends";
     expectCount = 1; expectTopGame = "Apex Legends"; expectTopConf = "HIGH" }
  # 一般英単語の複合語やシーズン表記からは切り出さない(境界ガードの確認)
  @{ n = "33. 複合語から切り出さない";        title = "apexpredator";
     expectCount = 0 }
  @{ n = "34. シーズン表記から切り出さない";  title = "APEXS12";
     expectCount = 0 }

  # --- 定着した略称 プロセカ を拾えること。alias一致はHIGHに昇格しないため期待値は MEDIUM ---
  @{ n = "35. 略称alias を含む通常タイトル";  title = "【音ゲー】プロセカ";
     expectCount = 1; expectTopGame = "プロジェクトセカイ"; expectTopConf = "MEDIUM"; expectAmbiguous = $false }
  @{ n = "36. 略称alias 単独";                title = "プロセカ";
     expectCount = 1; expectTopGame = "プロジェクトセカイ"; expectTopConf = "MEDIUM" }
  @{ n = "37. 正式名は従来どおりHIGH";        title = "プロジェクトセカイ";
     expectCount = 1; expectTopGame = "プロジェクトセカイ"; expectTopConf = "HIGH" }
  @{ n = "38. 英語併記の既存正常表記を壊さない"; title = "Project Sekai・プロジェクトセカイ";
     expectCount = 1; expectTopGame = "プロジェクトセカイ"; expectTopConf = "HIGH" }
  @{ n = "39. 数字が続く場合は切り出さない";  title = "プロセカ2";
     expectCount = 0 }
)

# ---- 合成入力を作って matcher に通す ----
$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("vgame-matcher-test-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
try {
  $plays = New-Object System.Collections.Generic.List[object]
  $idOf = @{}
  $i = 0
  foreach ($c in $cases) {
    $i++
    $plid = "PLMTEST" + $i.ToString("D13")
    $idOf[$c.n] = $plid
    $plays.Add([PSCustomObject]@{
      playlistId = $plid; title = $c.title; description = ""
      itemCount = 5; publishedAt = "2026-01-01T00:00:00Z"
    })
  }
  # streamer は STREAMERS に実在する名前を使う(officialChannelMatch を満たすため)
  $coreText = [System.IO.File]::ReadAllText((Join-Path $scriptDir "data-core.js"), [System.Text.Encoding]::UTF8)
  $m = [regex]::Match($coreText, 'const STREAMERS = \[[\s\S]*?\{ name: "([^"]+)"')
  if (-not $m.Success) { Write-Error "STREAMERS から名前を取得できませんでした"; exit 1 }
  $streamer = $m.Groups[1].Value

  $input = @([PSCustomObject]@{ streamer = $streamer; channelId = "UCMATCHERTEST00000000000"; status = "success"; playlists = $plays.ToArray() })
  $inputPath = Join-Path $tmpDir "synthetic-discovered.json"
  ($input | ConvertTo-Json -Depth 8) | Set-Content -Path $inputPath -Encoding UTF8
  $outPath = Join-Path $tmpDir "candidates.json"
  & powershell.exe -NoProfile -File $matcher -DiscoveredJson $inputPath -Json $outPath *> (Join-Path $tmpDir "matcher.log")
  if (-not (Test-Path $outPath)) {
    Write-Output "matcher の実行に失敗しました。ログ:"
    Get-Content (Join-Path $tmpDir "matcher.log") | Select-Object -Last 20 | ForEach-Object { Write-Output "  $_" }
    exit 1
  }
  $cands = @((Get-Content $outPath -Raw -Encoding UTF8 | ConvertFrom-Json).candidates)

  # ---- 検証 ----
  $rank = @{ "HIGH" = 3; "MEDIUM" = 2; "LOW" = 1 }
  $pass = 0; $fail = 0
  $rows = New-Object System.Collections.Generic.List[object]
  Write-Output "=== match-playlist-candidates.ps1 回帰テスト ==="
  Write-Output "使用streamer: $streamer / テストケース: $($cases.Count) 件"
  Write-Output ""
  foreach ($c in $cases) {
    $plid = $idOf[$c.n]
    $got = @($cands | Where-Object { $_.playlistId -eq $plid })
    $top = $null
    foreach ($g in $got) { if (-not $top -or $rank[$g.confidence] -gt $rank[$top.confidence]) { $top = $g } }
    $tokens = if ($got.Count -gt 0) { @($got[0].editionTokens) } else { @() }

    $problems = New-Object System.Collections.Generic.List[string]
    if ($c.ContainsKey("expectCount") -and $got.Count -ne $c.expectCount) { $problems.Add("件数 期待$($c.expectCount) 実際$($got.Count)") }
    if ($c.ContainsKey("expectTopGame")) {
      if (-not $top) { $problems.Add("候補なし(期待game「$($c.expectTopGame)」)") }
      elseif ($top.game -ne $c.expectTopGame) { $problems.Add("top game 期待「$($c.expectTopGame)」実際「$($top.game)」") }
    }
    if ($c.ContainsKey("expectTopConf") -and $top -and $top.confidence -ne $c.expectTopConf) { $problems.Add("top confidence 期待$($c.expectTopConf) 実際$($top.confidence)") }
    if ($c.ContainsKey("expectAmbiguous") -and $top -and [bool]$top.ambiguousMatch -ne [bool]$c.expectAmbiguous) { $problems.Add("ambiguousMatch 期待$($c.expectAmbiguous) 実際$($top.ambiguousMatch)") }
    if ($c.ContainsKey("expectNotGame") -and (@($got | Where-Object { $_.game -eq $c.expectNotGame }).Count -gt 0)) { $problems.Add("含まれてはいけないgame「$($c.expectNotGame)」が候補にある") }
    # ambiguous になる想定のケースでは top が一意に決まらないため、
    # 「正解が候補集合に含まれていること」だけを固定できるようにする。
    if ($c.ContainsKey("expectContainsGame") -and (@($got | Where-Object { $_.game -eq $c.expectContainsGame }).Count -eq 0)) { $problems.Add("候補に含まれるべきgame「$($c.expectContainsGame)」がない") }
    if ($c.ContainsKey("expectTokens") -and $c.expectTokens -ne "") {
      foreach ($t in ($c.expectTokens -split ',')) { $t = $t.Trim(); if ($t -and ($tokens -notcontains $t)) { $problems.Add("版語クラス「$t」が検出されていない") } }
    }
    if ($c.ContainsKey("expectTokens") -and $c.expectTokens -eq "" -and $tokens.Count -gt 0) { $problems.Add("版語クラスが検出されないはずだが [$($tokens -join ',')]") }
    if ($c.ContainsKey("expectNoTokens")) {
      foreach ($t in ($c.expectNoTokens -split ',')) { $t = $t.Trim(); if ($t -and ($tokens -contains $t)) { $problems.Add("版語クラス「$t」を検出してはいけない") } }
    }

    $ok = ($problems.Count -eq 0)
    if ($ok) { $pass++ } else { $fail++ }
    Write-Output ("  [{0}] {1}" -f $(if ($ok) { "PASS" } else { "FAIL" }), $c.n)
    Write-Output ("        title=`"{0}`" -> 候補{1}件 / top={2} ({3}) / amb={4} / tokens=[{5}]" -f `
      $c.title, $got.Count, $(if ($top) { "「$($top.game)」" } else { "(なし)" }), $(if ($top) { $top.confidence } else { "-" }), `
      $(if ($top) { $top.ambiguousMatch } else { "-" }), ($tokens -join ','))
    foreach ($p in $problems) { Write-Output "        NG: $p" }
    $rows.Add([PSCustomObject]@{
      name = $c.n; title = $c.title; count = $got.Count
      topGame = $(if ($top) { $top.game } else { $null }); topConf = $(if ($top) { $top.confidence } else { $null })
      ambiguous = $(if ($top) { $top.ambiguousMatch } else { $null }); tokens = $tokens
      pass = $ok; problems = $problems.ToArray()
    })
  }
  Write-Output ""
  Write-Output ("PASS: {0}  FAIL: {1}" -f $pass, $fail)

  if ($Json) {
    $jsonDir = Split-Path -Parent $Json
    if ($jsonDir -and -not (Test-Path $jsonDir)) { New-Item -ItemType Directory -Path $jsonDir -Force | Out-Null }
    ([PSCustomObject]@{ pass = $pass; fail = $fail; cases = $rows.ToArray() } | ConvertTo-Json -Depth 6) | Set-Content -Path $Json -Encoding UTF8
    Write-Output "結果をJSONで出力しました: $Json"
  }
  if ($fail -gt 0) { exit 1 }
  exit 0
}
finally {
  if (Test-Path $tmpDir) { Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue }
}
