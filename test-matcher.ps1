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

  # --- 作品略称 ポケモンZA。alias一致はHIGHに昇格しないため期待値は MEDIUM ---
  @{ n = "40. 作品略称alias 単独";            title = "ポケモンZA";
     expectCount = 1; expectTopGame = "Pokémon LEGENDS Z-A"; expectTopConf = "MEDIUM"; expectAmbiguous = $false }
  @{ n = "41. 括弧付き";                      title = "【ポケモンZA】";
     expectCount = 1; expectTopGame = "Pokémon LEGENDS Z-A"; expectTopConf = "MEDIUM" }
  @{ n = "42. ZA単独は切り出さない";          title = "ZA";
     expectCount = 0 }
  @{ n = "43. ポケモンSVには効かない";        title = "ポケモンSV";
     expectNotGame = "Pokémon LEGENDS Z-A" }
  @{ n = "44. アルセウス正式名は従来どおりHIGH"; title = "Pokémon LEGENDS アルセウス";
     expectCount = 1; expectTopGame = "Pokémon LEGENDS アルセウス"; expectTopConf = "HIGH"; expectNotGame = "Pokémon LEGENDS Z-A" }
  @{ n = "45. Z-A正式名は従来どおりHIGH";     title = "Pokémon LEGENDS Z-A";
     expectCount = 1; expectTopGame = "Pokémon LEGENDS Z-A"; expectTopConf = "HIGH" }

  # --- F2: 同じ長さの name と alias が同時に当たる場合、GAMES の並び順に関係なく name として記録する ---
  @{ n = "46. F2 name と alias の正規化結果が同一"; title = "SILENT HILL 2 リメイク";
     expectCount = 1; expectTopGame = "SILENT HILL 2 リメイク"; expectTopConf = "HIGH"; expectVia = "name" }
  @{ n = "47. F2 alias表記でも正規化後が正式名と同一"; title = "SILENT HILL2リメイク";
     expectCount = 1; expectTopGame = "SILENT HILL 2 リメイク"; expectTopConf = "HIGH"; expectVia = "name" }
  @{ n = "48. F2 alias だけの一致は従来どおりMEDIUM"; title = "Silent Hill 2 Remake";
     expectCount = 1; expectTopGame = "SILENT HILL 2 リメイク"; expectTopConf = "MEDIUM"; expectVia = "alias" }

  # --- 作品略称 ポケモンSV。alias一致はHIGHに昇格しないため期待値は MEDIUM ---
  @{ n = "49. 作品略称alias 単独";            title = "ポケモンSV";
     expectCount = 1; expectTopGame = "ポケットモンスター スカーレット・バイオレット"; expectTopConf = "MEDIUM"; expectAmbiguous = $false }
  @{ n = "50. 括弧付き";                      title = "【ポケモンSV】";
     expectCount = 1; expectTopGame = "ポケットモンスター スカーレット・バイオレット"; expectTopConf = "MEDIUM" }
  @{ n = "51. SV単独は切り出さない";          title = "SV";
     expectCount = 0 }
  @{ n = "52. 数字が続く場合は切り出さない";  title = "ポケモンSV2";
     expectCount = 0 }
  # 境界が弱い接尾(漢字が続く)は既存仕様どおりLOWに落とす。ここを広げる変更はしない
  @{ n = "53. 漢字が続く場合はLOW";           title = "ポケモンSV実況";
     expectCount = 1; expectTopGame = "ポケットモンスター スカーレット・バイオレット"; expectTopConf = "LOW" }
  @{ n = "54. ポケモンZAには効かない";        title = "ポケモンZA";
     expectCount = 1; expectTopGame = "Pokémon LEGENDS Z-A"; expectNotGame = "ポケットモンスター スカーレット・バイオレット" }
  @{ n = "55. SV正式名は従来どおりHIGH";      title = "ポケットモンスター スカーレット・バイオレット";
     expectCount = 1; expectTopGame = "ポケットモンスター スカーレット・バイオレット"; expectTopConf = "HIGH"; expectVia = "name" }
  @{ n = "56. 剣盾は従来どおりHIGH";          title = "ポケットモンスター ソード・シールド";
     expectCount = 1; expectTopGame = "ポケットモンスター ソード・シールド"; expectTopConf = "HIGH"; expectNotGame = "ポケットモンスター スカーレット・バイオレット" }

  # --- 作品略称 アルセウス。57-59 は実データにある表記をそのまま使っている ---
  @{ n = "57. 作品略称alias 単独";            title = "アルセウス";
     expectCount = 1; expectTopGame = "Pokémon LEGENDS アルセウス"; expectTopConf = "MEDIUM"; expectAmbiguous = $false }
  @{ n = "58. 和名表記";                      title = "ポケモンレジェンズアルセウス";
     expectCount = 1; expectTopGame = "Pokémon LEGENDS アルセウス"; expectTopConf = "MEDIUM" }
  @{ n = "59. ポケモン+作品名";               title = "ポケモンアルセウス";
     expectCount = 1; expectTopGame = "Pokémon LEGENDS アルセウス"; expectTopConf = "MEDIUM" }
  @{ n = "60. 正式名はaliasに奪われない";     title = "Pokémon LEGENDS アルセウス";
     expectCount = 1; expectTopGame = "Pokémon LEGENDS アルセウス"; expectTopConf = "HIGH"; expectVia = "name" }
  @{ n = "61. 数字が続く場合は切り出さない";  title = "アルセウス2";
     expectCount = 0 }
  # ポケモン個体としての「アルセウス」用法。現在の登録データには実例が無いため合成タイトルで、
  # 「漢字が続く弱い境界はLOWに落ちる(自動確定しない)」という現在の挙動をそのまま固定する。
  @{ n = "62. 個体を指す用法はLOWに落ちる";   title = "アルセウス捕獲";
     expectCount = 1; expectTopGame = "Pokémon LEGENDS アルセウス"; expectTopConf = "LOW" }
  @{ n = "63. ZAはアルセウスへ寄らない";      title = "ポケモンZA";
     expectCount = 1; expectTopGame = "Pokémon LEGENDS Z-A"; expectNotGame = "Pokémon LEGENDS アルセウス" }
  @{ n = "64. SVはアルセウスへ寄らない";      title = "ポケモンSV";
     expectCount = 1; expectTopGame = "ポケットモンスター スカーレット・バイオレット"; expectNotGame = "Pokémon LEGENDS アルセウス" }

  # --- 英語公式名 Genshin Impact。65-67 は実データにある表記をそのまま使っている ---
  @{ n = "65. 英語公式名alias 単独";          title = "Genshin Impact";
     expectCount = 1; expectTopGame = "原神"; expectTopConf = "MEDIUM"; expectVia = "alias"; expectAmbiguous = $false }
  @{ n = "66. 和名と英語公式名の併記";        title = "原神／Genshin Impact";
     expectCount = 1; expectTopGame = "原神"; expectTopConf = "MEDIUM" }
  @{ n = "67. 配信者名が前置された実例";      title = "Layla Plays : Genshin Impact";
     expectCount = 1; expectTopGame = "原神"; expectTopConf = "MEDIUM" }
  # 実データ(リゼ・ヘルエスタ)由来。Genshin単独は拾わない。和名「原神」は2文字のため突き合わせ対象外
  @{ n = "68. Genshin単独は切り出さない";     title = "【原神/Genshin】星と深淵を目指せ";
     expectCount = 0 }
  @{ n = "69. 和名のみは従来どおり候補0件";   title = "原神";
     expectCount = 0 }
  @{ n = "70. 数字が続く場合は切り出さない";  title = "Genshin Impact2";
     expectCount = 0 }
  # 漢字が続く弱い境界はLOWに落とす既存仕様の固定(ここを広げる変更はしない)
  @{ n = "71. 漢字が続く場合はLOW";           title = "Genshin Impact実況";
     expectCount = 1; expectTopGame = "原神"; expectTopConf = "LOW" }

  # --- 作品略称 ポケモン剣盾。73-74 は実データにある表記をそのまま使っている ---
  @{ n = "72. 作品略称alias 単独";            title = "ポケモン剣盾";
     expectCount = 1; expectTopGame = "ポケットモンスター ソード・シールド"; expectTopConf = "MEDIUM"; expectVia = "alias"; expectAmbiguous = $false }
  @{ n = "73. 括弧付きの実例";                title = "〖ポケモン剣盾〗";
     expectCount = 1; expectTopGame = "ポケットモンスター ソード・シールド"; expectTopConf = "MEDIUM" }
  # DLC は本編gameへ統合する既存運用(原則Bの対象外クラス)を壊さないことの固定
  @{ n = "74. DLC表記の実例";                 title = "ポケモン剣盾+DLC";
     expectCount = 1; expectTopGame = "ポケットモンスター ソード・シールド"; expectTopConf = "MEDIUM"; expectTokens = "dlc" }
  @{ n = "75. 正式名はaliasに奪われない";     title = "ポケットモンスター ソード・シールド";
     expectCount = 1; expectTopGame = "ポケットモンスター ソード・シールド"; expectTopConf = "HIGH"; expectVia = "name" }
  # 実データ(卯月コウ「剣盾ランクマ」)由来。「剣盾」単独は拾わない
  @{ n = "76. 剣盾単独は切り出さない";        title = "剣盾ランクマ";
     expectCount = 0 }
  @{ n = "77. 数字が続く場合は切り出さない";  title = "ポケモン剣盾2";
     expectCount = 0 }
  @{ n = "78. SVは剣盾へ寄らない";            title = "ポケモンSV";
     expectCount = 1; expectTopGame = "ポケットモンスター スカーレット・バイオレット"; expectNotGame = "ポケットモンスター ソード・シールド" }
  @{ n = "79. ZAは剣盾へ寄らない";            title = "ポケモンZA";
     expectCount = 1; expectTopGame = "Pokémon LEGENDS Z-A"; expectNotGame = "ポケットモンスター ソード・シールド" }
  @{ n = "80. アルセウスは剣盾へ寄らない";    title = "Pokémon LEGENDS アルセウス";
     expectCount = 1; expectTopGame = "Pokémon LEGENDS アルセウス"; expectTopConf = "HIGH"; expectNotGame = "ポケットモンスター ソード・シールド" }

  # --- 定着した略称 ツイステ。82-84 は実データにある表記をそのまま使っている ---
  @{ n = "81. 略称alias 単独";                title = "ツイステ";
     expectCount = 1; expectTopGame = "ディズニー ツイステッドワンダーランド"; expectTopConf = "MEDIUM"; expectVia = "alias"; expectAmbiguous = $false }
  @{ n = "82. 副題のみの実例";                title = "ツイステッドワンダーランド";
     expectCount = 1; expectTopGame = "ディズニー ツイステッドワンダーランド"; expectTopConf = "MEDIUM" }
  @{ n = "83. 括弧内に略称がある実例";        title = "Ser.魔道士の「ツイステ」";
     expectCount = 1; expectTopGame = "ディズニー ツイステッドワンダーランド"; expectTopConf = "MEDIUM" }
  @{ n = "84. 英語名との併記の実例";          title = "Twisted Wonderland・ツイステ (w/ Elira)";
     expectCount = 1; expectTopGame = "ディズニー ツイステッドワンダーランド"; expectTopConf = "MEDIUM" }
  @{ n = "85. 正式名はaliasに奪われない";     title = "ディズニー ツイステッドワンダーランド";
     expectCount = 1; expectTopGame = "ディズニー ツイステッドワンダーランド"; expectTopConf = "HIGH"; expectVia = "name" }
  @{ n = "86. 途中までの文字列は拾わない";    title = "ツイス";
     expectCount = 0 }
  @{ n = "87. 数字が続く場合は切り出さない";  title = "ツイステ2";
     expectCount = 0 }
  # アニメ同時視聴は既存の非ゲーム語ルールでLOWに落ちる。現在の挙動を固定する
  @{ n = "88. アニメ同時視聴はLOW";           title = "ツイステアニメ同時視聴";
     expectCount = 1; expectTopGame = "ディズニー ツイステッドワンダーランド"; expectTopConf = "LOW" }

  # --- 英語公式名 LOST JUDGMENT。90-92 は実データにある表記をそのまま使っている ---
  @{ n = "89. 英語公式名alias 単独";          title = "LOST JUDGMENT";
     expectCount = 1; expectTopGame = "LOST JUDGMENT:裁かれざる記憶"; expectTopConf = "MEDIUM"; expectVia = "alias"; expectAmbiguous = $false }
  @{ n = "90. 記号付きの実例";                title = "【完結】⚖LOST JUDGMENT⚖";
     expectCount = 1; expectTopGame = "LOST JUDGMENT:裁かれざる記憶"; expectTopConf = "MEDIUM" }
  # 正式名は「:」区切り。実データには空白区切りの表記があり、name一致せずalias一致になる
  @{ n = "91. 空白区切りの副題つき実例";      title = "【完結】LOST JUDGMENT 裁かれざる記憶";
     expectCount = 1; expectTopGame = "LOST JUDGMENT:裁かれざる記憶"; expectTopConf = "MEDIUM" }
  @{ n = "92. 英題併記の実例";                title = "🏫LOST JUDGMENT 裁かれざる記憶：Lost Judgment：完結🏫";
     expectCount = 1; expectTopGame = "LOST JUDGMENT:裁かれざる記憶"; expectTopConf = "MEDIUM" }
  @{ n = "93. 正式名はaliasに奪われない";     title = "LOST JUDGMENT:裁かれざる記憶";
     expectCount = 1; expectTopGame = "LOST JUDGMENT:裁かれざる記憶"; expectTopConf = "HIGH"; expectVia = "name" }
  @{ n = "94. 姉妹作の正式名は従来どおりHIGH"; title = "JUDGE EYES:死神の遺言";
     expectCount = 1; expectTopGame = "JUDGE EYES:死神の遺言"; expectTopConf = "HIGH"; expectVia = "name"; expectNotGame = "LOST JUDGMENT:裁かれざる記憶" }
  @{ n = "95. JUDGMENT単独は切り出さない";    title = "JUDGMENT";
     expectCount = 0 }
  @{ n = "96. 英字が続く場合は切り出さない";  title = "LOST JUDGMENT Remastered";
     expectCount = 0 }
  @{ n = "97. 数字が続く場合は切り出さない";  title = "LOST JUDGMENT2";
     expectCount = 0 }

  # --- 英語公式名 JUDGE EYES。99-101 は実データにある表記をそのまま使っている ---
  @{ n = "98. 英語公式名alias 単独";          title = "JUDGE EYES";
     expectCount = 1; expectTopGame = "JUDGE EYES:死神の遺言"; expectTopConf = "MEDIUM"; expectVia = "alias"; expectAmbiguous = $false }
  # 正式名は「:」区切り。実データには空白区切りの表記があり、name一致せずalias一致になる
  @{ n = "99. 空白区切りの副題つき実例";      title = "【🦋完結】JUDGE EYES 死神の遺言";
     expectCount = 1; expectTopGame = "JUDGE EYES:死神の遺言"; expectTopConf = "MEDIUM" }
  @{ n = "100. VTuber名が前置された実例";     title = "月ノ美兎のJUDGE EYES 死神の遺言";
     expectCount = 1; expectTopGame = "JUDGE EYES:死神の遺言"; expectTopConf = "MEDIUM" }
  # 全角空白で区切られ漢字が続く実例。弱い境界でLOWに落ちる現在の挙動を固定する
  @{ n = "101. 漢字が続く実例はLOW";          title = "JUDGE　EYES実況";
     expectCount = 1; expectTopGame = "JUDGE EYES:死神の遺言"; expectTopConf = "LOW" }
  @{ n = "102. 正式名はaliasに奪われない";    title = "JUDGE EYES:死神の遺言";
     expectCount = 1; expectTopGame = "JUDGE EYES:死神の遺言"; expectTopConf = "HIGH"; expectVia = "name" }
  # Remastered は同一作品の再発売。既存どおり name 一致の MEDIUM(原則Bのキャップ)を保つ
  @{ n = "103. Remastered表記の実例";         title = "🔎JUDGE EYES：死神の遺言 Remastered：本編完結🔎";
     expectCount = 1; expectTopGame = "JUDGE EYES:死神の遺言"; expectTopConf = "MEDIUM"; expectVia = "name" }
  @{ n = "104. JUDGE単独は切り出さない";      title = "JUDGE";
     expectCount = 0 }
  @{ n = "105. EYES単独は切り出さない";       title = "EYES";
     expectCount = 0 }
  @{ n = "106. 数字が続く場合は切り出さない"; title = "JUDGE EYES2";
     expectCount = 0 }
  @{ n = "107. 姉妹作は寄らない";             title = "LOST JUDGMENT";
     expectCount = 1; expectTopGame = "LOST JUDGMENT:裁かれざる記憶"; expectNotGame = "JUDGE EYES:死神の遺言" }
  @{ n = "108. 姉妹作の正式名も寄らない";     title = "LOST JUDGMENT:裁かれざる記憶";
     expectCount = 1; expectTopGame = "LOST JUDGMENT:裁かれざる記憶"; expectTopConf = "HIGH"; expectVia = "name"; expectNotGame = "JUDGE EYES:死神の遺言" }

  # --- 版を含む略称 ドラクエ11S。110-112 は実データにある表記をそのまま使っている ---
  @{ n = "109. 版つき略称alias 単独";         title = "ドラクエ11S";
     expectCount = 1; expectTopGame = "ドラゴンクエストXI S 過ぎ去りし時を求めて"; expectTopConf = "MEDIUM"; expectVia = "alias"; expectAmbiguous = $false }
  @{ n = "110. 記号付きの実例";               title = "▶完結◀ドラクエ11S💙";
     expectCount = 1; expectTopGame = "ドラゴンクエストXI S 過ぎ去りし時を求めて"; expectTopConf = "MEDIUM" }
  @{ n = "111. 小文字表記の実例";             title = "ドラクエ11s";
     expectCount = 1; expectTopGame = "ドラゴンクエストXI S 過ぎ去りし時を求めて"; expectTopConf = "MEDIUM" }
  # 漢字が直前に来る弱い境界はLOWに落ちる。実データ(猫又おかゆ)の挙動をそのまま固定する
  @{ n = "112. 漢字が直前に来る実例はLOW";    title = "深夜ドラクエ11S🍙";
     expectCount = 1; expectTopGame = "ドラゴンクエストXI S 過ぎ去りし時を求めて"; expectTopConf = "LOW" }
  @{ n = "113. 括弧付き";                     title = "【ドラクエ11S】";
     expectCount = 1; expectTopGame = "ドラゴンクエストXI S 過ぎ去りし時を求めて"; expectTopConf = "MEDIUM" }
  @{ n = "114. 無印版は切り出さない";         title = "ドラクエ11";
     expectCount = 0 }
  @{ n = "115. 数字が続く場合は切り出さない"; title = "ドラクエ11S2";
     expectCount = 0 }
  @{ n = "116. 他ナンバリングは切り出さない"; title = "ドラクエ3";
     expectCount = 0 }
  # 正式名の一部だけでは本作へ寄らない(既存の「ドラゴンクエスト」一致のまま)
  @{ n = "117. 正式名の一部は本作へ寄らない"; title = "ドラゴンクエストXI S";
     expectCount = 1; expectTopGame = "ドラゴンクエスト"; expectNotGame = "ドラゴンクエストXI S 過ぎ去りし時を求めて" }
  @{ n = "118. 正式名は従来どおりの候補";     title = "ドラゴンクエストXI S 過ぎ去りし時を求めて";
     expectCount = 2; expectContainsGame = "ドラゴンクエストXI S 過ぎ去りし時を求めて"; expectAmbiguous = $true }

  # --- 外伝作品の略称 龍が如く7外伝。120-121 は実データにある表記をそのまま使っている ---
  @{ n = "119. 外伝略称alias 単独";           title = "龍が如く7外伝";
     expectCount = 1; expectTopGame = "龍が如く7外伝 名を消した男"; expectTopConf = "MEDIUM"; expectVia = "alias"; expectAmbiguous = $false }
  @{ n = "120. 全角数字+空白の実例";          title = "龍が如く７ 外伝";
     expectCount = 1; expectTopGame = "龍が如く7外伝 名を消した男"; expectTopConf = "MEDIUM" }
  @{ n = "121. 副題を波ダッシュで繋いだ実例"; title = "龍が如く7外伝～名を消した男～🐉【完結】";
     expectCount = 1; expectTopGame = "龍が如く7外伝 名を消した男"; expectTopConf = "MEDIUM" }
  @{ n = "122. 正式名はaliasに奪われない";    title = "龍が如く7外伝 名を消した男";
     expectCount = 1; expectTopGame = "龍が如く7外伝 名を消した男"; expectTopConf = "HIGH"; expectVia = "name" }
  # --- ここから下は「外伝aliasが本編・シリーズへ広がらない」ことの固定 ---
  @{ n = "123. 本編7は切り出さない";          title = "龍が如く7";
     expectCount = 0 }
  @{ n = "124. 本編7の正式名は従来どおり";    title = "龍が如く7 光と闇の行方";
     expectCount = 1; expectTopGame = "龍が如く7 光と闇の行方"; expectTopConf = "HIGH"; expectVia = "name"; expectNotGame = "龍が如く7外伝 名を消した男" }
  @{ n = "125. 8は従来どおり";                title = "龍が如く8";
     expectCount = 1; expectTopGame = "龍が如く8"; expectTopConf = "HIGH"; expectVia = "name"; expectNotGame = "龍が如く7外伝 名を消した男" }
  # 実データに3件ある「龍が如く8外伝」。8側のLOWのまま、7外伝へは寄らない
  @{ n = "126. 8外伝は7外伝へ寄らない";       title = "龍が如く8外伝";
     expectCount = 1; expectTopGame = "龍が如く8"; expectTopConf = "LOW"; expectNotGame = "龍が如く7外伝 名を消した男" }
  @{ n = "127. シリーズ1作目は従来どおり";    title = "龍が如く";
     expectCount = 1; expectTopGame = "龍が如く"; expectTopConf = "MEDIUM"; expectNotGame = "龍が如く7外伝 名を消した男" }
  @{ n = "128. 龍が如く外伝は寄らない";       title = "龍が如く外伝";
     expectCount = 1; expectTopGame = "龍が如く"; expectTopConf = "LOW"; expectNotGame = "龍が如く7外伝 名を消した男" }
  @{ n = "129. 数字が続く場合は切り出さない"; title = "龍が如く7外伝2";
     expectCount = 0 }

  # --- ナンバリング略称 ARMORED CORE VI。130-133 は実データにある表記をそのまま使っている ---
  @{ n = "130. ナンバリング略称alias 単独";  title = "ARMORED CORE VI";
     expectCount = 1; expectTopGame = "ARMORED CORE VI FIRES OF RUBICON"; expectTopConf = "MEDIUM"; expectVia = "alias"; expectAmbiguous = $false }
  @{ n = "131. 墨付き括弧・装飾付きの実例";  title = "🎮【完結】ARMORED CORE VI";
     expectCount = 1; expectTopGame = "ARMORED CORE VI FIRES OF RUBICON"; expectTopConf = "MEDIUM"; expectVia = "alias" }
  @{ n = "132. 大小文字混在の実例";          title = "Armored Core VI";
     expectCount = 1; expectTopGame = "ARMORED CORE VI FIRES OF RUBICON"; expectTopConf = "MEDIUM"; expectVia = "alias" }
  @{ n = "133. 正式名はaliasに奪われない";   title = "🤍ARMORED CORE VI FIRES OF RUBICON │AC6";
     expectCount = 1; expectTopGame = "ARMORED CORE VI FIRES OF RUBICON"; expectTopConf = "HIGH"; expectVia = "name" }
  @{ n = "134. 実況付き";                    title = "ARMORED CORE VI 実況";
     expectCount = 1; expectTopGame = "ARMORED CORE VI FIRES OF RUBICON"; expectTopConf = "MEDIUM"; expectVia = "alias" }
  # --- ここから下は「VI aliasが隣接ナンバリング・派生語へ広がらない」ことの固定 ---
  @{ n = "135. Vは切り出さない";             title = "ARMORED CORE V";
     expectCount = 0 }
  @{ n = "136. VIIは切り出さない";           title = "ARMORED CORE VII";
     expectCount = 0 }
  @{ n = "137. IVは切り出さない";            title = "ARMORED CORE IV";
     expectCount = 0 }
  @{ n = "138. IIIは切り出さない";           title = "ARMORED CORE III";
     expectCount = 0 }
  @{ n = "139. IIは切り出さない";            title = "ARMORED CORE II";
     expectCount = 0 }
  @{ n = "140. VIIIは切り出さない";          title = "ARMORED CORE VIII";
     expectCount = 0 }
  @{ n = "141. 英単語が続く場合は切り出さない"; title = "ARMORED CORE VI Online";
     expectCount = 0 }
  @{ n = "142. 4は従来どおり";               title = "ARMORED CORE 4";
     expectCount = 1; expectTopGame = "ARMORED CORE 4"; expectTopConf = "HIGH"; expectVia = "name"; expectNotGame = "ARMORED CORE VI FIRES OF RUBICON" }
  @{ n = "143. for Answerは従来どおり";      title = "ARMORED CORE for Answer";
     expectCount = 1; expectTopGame = "ARMORED CORE for Answer"; expectTopConf = "HIGH"; expectVia = "name"; expectNotGame = "ARMORED CORE VI FIRES OF RUBICON" }

  # --- 中黒なし表記 ホグワーツレガシー。145 は実データにある表記をそのまま使っている ---
  @{ n = "144. 中黒なし表記alias 単独";      title = "ホグワーツレガシー";
     expectCount = 1; expectTopGame = "ホグワーツ・レガシー"; expectTopConf = "MEDIUM"; expectVia = "alias"; expectAmbiguous = $false }
  @{ n = "145. 完結タグ付きの実例";          title = "【完結】ホグワーツレガシー";
     expectCount = 1; expectTopGame = "ホグワーツ・レガシー"; expectTopConf = "MEDIUM"; expectVia = "alias" }
  @{ n = "146. 正式名はaliasに奪われない";   title = "ホグワーツ・レガシー";
     expectCount = 1; expectTopGame = "ホグワーツ・レガシー"; expectTopConf = "HIGH"; expectVia = "name" }
  @{ n = "147. 正式名と併記でも降格しない";  title = "ホグワーツ・レガシー / ホグワーツレガシー";
     expectCount = 1; expectTopGame = "ホグワーツ・レガシー"; expectTopConf = "HIGH"; expectVia = "name" }
  # --- ここから下は「aliasが続編の数字表記・英題・別作品へ広がらない」ことの固定 ---
  @{ n = "148. 続編の数字表記は切り出さない"; title = "ホグワーツレガシー2";
     expectCount = 0 }
  @{ n = "149. 空白+数字も切り出さない";     title = "ホグワーツレガシー 2";
     expectCount = 0 }
  @{ n = "150. 英題の続編は従来どおり";      title = "Hogwarts Legacy 2";
     expectCount = 0 }
  @{ n = "151. 別作品は従来どおり";          title = "ホグワーツミステリー";
     expectCount = 0 }

  # --- ナンバリング略称 龍が如く0。152-154 は実データにある表記をそのまま使っている ---
  @{ n = "152. ナンバリング略称alias 単独";  title = "龍が如く0";
     expectCount = 1; expectTopGame = "龍が如く0 誓いの場所"; expectTopConf = "MEDIUM"; expectVia = "alias"; expectAmbiguous = $false }
  @{ n = "153. 全角数字の実例";              title = "🍑龍が如く０🍑";
     expectCount = 1; expectTopGame = "龍が如く0 誓いの場所"; expectTopConf = "MEDIUM"; expectVia = "alias" }
  @{ n = "154. 空白+全角数字の実例";         title = "龍が如く ０";
     expectCount = 1; expectTopGame = "龍が如く0 誓いの場所"; expectTopConf = "MEDIUM"; expectVia = "alias" }
  @{ n = "155. 正式名はaliasに奪われない";   title = "龍が如く0 誓いの場所";
     expectCount = 1; expectTopGame = "龍が如く0 誓いの場所"; expectTopConf = "HIGH"; expectVia = "name" }
  # --- ここから下は「0 aliasが他ナンバリング・数字違いへ広がらない」ことの固定 ---
  @{ n = "156. 1作目は従来どおり";           title = "龍が如く";
     expectCount = 1; expectTopGame = "龍が如く"; expectTopConf = "MEDIUM"; expectVia = "name"; expectNotGame = "龍が如く0 誓いの場所" }
  @{ n = "157. 8は従来どおり";               title = "龍が如く8";
     expectCount = 1; expectTopGame = "龍が如く8"; expectTopConf = "HIGH"; expectVia = "name"; expectNotGame = "龍が如く0 誓いの場所" }
  @{ n = "158. 7外伝は従来どおり";           title = "龍が如く7外伝";
     expectCount = 1; expectTopGame = "龍が如く7外伝 名を消した男"; expectTopConf = "MEDIUM"; expectVia = "alias"; expectNotGame = "龍が如く0 誓いの場所" }
  @{ n = "159. 数字が続く場合は切り出さない"; title = "龍が如く02";
     expectCount = 0 }
  @{ n = "160. 10は切り出さない";            title = "龍が如く10";
     expectCount = 0 }

  # --- 「スーパー」省略の略称 マリオメーカー2。162-163 は実データにある表記をそのまま使っている ---
  @{ n = "161. 略称alias 単独";              title = "マリオメーカー2";
     expectCount = 1; expectTopGame = "スーパーマリオメーカー2"; expectTopConf = "MEDIUM"; expectVia = "alias"; expectAmbiguous = $false }
  @{ n = "162. 全角数字+実況の実例";         title = "マリオメーカー２　実況プレイ";
     expectCount = 1; expectTopGame = "スーパーマリオメーカー2"; expectTopConf = "MEDIUM"; expectVia = "alias" }
  @{ n = "163. 括弧付きの実例";              title = "【マリオメーカー2】まずは腕試しなのだ！";
     expectCount = 1; expectTopGame = "スーパーマリオメーカー2"; expectTopConf = "MEDIUM"; expectVia = "alias" }
  @{ n = "164. 正式名はaliasに奪われない";   title = "スーパーマリオメーカー2";
     expectCount = 1; expectTopGame = "スーパーマリオメーカー2"; expectTopConf = "HIGH"; expectVia = "name" }
  # --- ここから下は「aliasが数字違い・無印・別のマリオ作品へ広がらない」ことの固定 ---
  @{ n = "165. 無印は切り出さない";          title = "マリオメーカー";
     expectCount = 0 }
  @{ n = "166. 3は切り出さない";             title = "マリオメーカー3";
     expectCount = 0 }
  @{ n = "167. 数字が続く場合は切り出さない"; title = "マリオメーカー20";
     expectCount = 0 }
  @{ n = "168. 別のマリオ作品は従来どおり";  title = "マリオカート8 デラックス";
     expectCount = 1; expectTopGame = "マリオカート8 デラックス"; expectTopConf = "HIGH"; expectVia = "name"; expectNotGame = "スーパーマリオメーカー2" }

  # --- 正式表記寄りの略称 ドラゴンクエスト11S。170-171 は実データにある表記をそのまま使っている ---
  @{ n = "169. 略称alias 単独";              title = "ドラゴンクエスト11S";
     expectCount = 1; expectTopGame = "ドラゴンクエストXI S 過ぎ去りし時を求めて"; expectTopConf = "MEDIUM"; expectVia = "alias"; expectAmbiguous = $false }
  @{ n = "170. 墨付き括弧・英字略称併記の実例"; title = "【ドラゴンクエスト11S/DQ11S】";
     expectCount = 1; expectTopGame = "ドラゴンクエストXI S 過ぎ去りし時を求めて"; expectTopConf = "MEDIUM"; expectVia = "alias" }
  @{ n = "171. 小文字 s の実例";             title = "ドラゴンクエスト11s";
     expectCount = 1; expectTopGame = "ドラゴンクエストXI S 過ぎ去りし時を求めて"; expectTopConf = "MEDIUM"; expectVia = "alias" }
  @{ n = "172. 実況付き";                    title = "ドラゴンクエスト11S 実況";
     expectCount = 1; expectTopGame = "ドラゴンクエストXI S 過ぎ去りし時を求めて"; expectTopConf = "MEDIUM"; expectVia = "alias" }
  # 正式名は従来どおり(シリーズ名「ドラゴンクエスト」と並ぶ曖昧候補のまま。aliasに奪われない)
  @{ n = "173. 正式名は従来どおり";          title = "ドラゴンクエストXI S 過ぎ去りし時を求めて";
     expectCount = 2; expectContainsGame = "ドラゴンクエストXI S 過ぎ去りし時を求めて"; expectAmbiguous = $true }
  # --- ここから下は「aliasが S なし・他ナンバリング・英単語付きへ広がらない」ことの固定 ---
  @{ n = "174. S なしは切り出さない";        title = "ドラゴンクエスト11";
     expectCount = 0 }
  @{ n = "175. 12は切り出さない";            title = "ドラゴンクエスト12";
     expectCount = 0 }
  @{ n = "176. 数字が続く場合は切り出さない"; title = "ドラゴンクエスト11S2";
     expectCount = 0 }
  @{ n = "177. 英単語が続く場合は切り出さない"; title = "ドラゴンクエスト11S Switch";
     expectCount = 0 }

  # --- ハイフンなし表記 キャプテン翼 RISE OF NEW CHAMPIONS。179-180 は実データにある表記をそのまま使っている ---
  @{ n = "178. ハイフンなし表記alias 単独";  title = "キャプテン翼 RISE OF NEW CHAMPIONS";
     expectCount = 1; expectTopGame = "キャプテン翼 -RISE OF NEW CHAMPIONS-"; expectTopConf = "MEDIUM"; expectVia = "alias"; expectAmbiguous = $false }
  @{ n = "179. 絵文字付きの実例";            title = "⚽キャプテン翼 RISE OF NEW CHAMPIONS⚽";
     expectCount = 1; expectTopGame = "キャプテン翼 -RISE OF NEW CHAMPIONS-"; expectTopConf = "MEDIUM"; expectVia = "alias" }
  @{ n = "180. 英題併記の実例";              title = "⚽キャプテン翼 RISE OF NEW CHAMPIONS：Captain Tsubasa: Rise of New Champions：一旦完結⚽";
     expectCount = 1; expectTopGame = "キャプテン翼 -RISE OF NEW CHAMPIONS-"; expectTopConf = "MEDIUM"; expectVia = "alias" }
  @{ n = "181. 正式名はaliasに奪われない";   title = "キャプテン翼 -RISE OF NEW CHAMPIONS-";
     expectCount = 1; expectTopGame = "キャプテン翼 -RISE OF NEW CHAMPIONS-"; expectTopConf = "HIGH"; expectVia = "name" }
  # --- ここから下は「aliasが2作目・シリーズ名・英単語付きへ広がらない」ことの固定 ---
  @{ n = "182. 2作目は従来どおり";           title = "キャプテン翼２ WORLD FIGHTERS";
     expectCount = 1; expectTopGame = "キャプテン翼2 WORLD FIGHTERS"; expectTopConf = "HIGH"; expectVia = "name"; expectNotGame = "キャプテン翼 -RISE OF NEW CHAMPIONS-" }
  @{ n = "183. キャプテン翼だけでは切り出さない"; title = "キャプテン翼";
     expectCount = 0 }
  @{ n = "184. 数字が続く場合は切り出さない"; title = "キャプテン翼 RISE OF NEW CHAMPIONS2";
     expectCount = 0 }
  @{ n = "185. 英単語が続く場合は切り出さない"; title = "キャプテン翼 RISE OF NEW CHAMPIONS Remastered";
     expectCount = 0 }

  # --- コロンなし表記 モンスターハンターワールド。187-188 は実データにある表記をそのまま使っている ---
  @{ n = "186. コロンなし表記alias 単独";    title = "モンスターハンターワールド";
     expectCount = 1; expectTopGame = "モンスターハンター：ワールド"; expectTopConf = "MEDIUM"; expectVia = "alias"; expectAmbiguous = $false }
  @{ n = "187. 全角空白+実況の実例";         title = "モンスターハンターワールド　実況プレイ";
     expectCount = 1; expectTopGame = "モンスターハンター：ワールド"; expectTopConf = "MEDIUM"; expectVia = "alias" }
  @{ n = "188. 拡張コンテンツ併記の実例";    title = "🦖モンスターハンターワールド：アイスボーン🧊";
     expectCount = 1; expectTopGame = "モンスターハンター：ワールド"; expectTopConf = "MEDIUM"; expectVia = "alias" }
  @{ n = "189. 正式名はaliasに奪われない";   title = "モンスターハンター：ワールド";
     expectCount = 1; expectTopGame = "モンスターハンター：ワールド"; expectTopConf = "HIGH"; expectVia = "name" }
  # --- ここから下は「aliasがシリーズ他作品・シリーズ名・数字違いへ広がらない」ことの固定 ---
  @{ n = "190. ワイルズは従来どおり";        title = "モンスターハンターワイルズ";
     expectCount = 1; expectTopGame = "モンスターハンターワイルズ"; expectTopConf = "HIGH"; expectVia = "name"; expectNotGame = "モンスターハンター：ワールド" }
  @{ n = "191. ライズは従来どおり";          title = "モンスターハンターライズ";
     expectCount = 1; expectTopGame = "モンスターハンターライズ"; expectTopConf = "HIGH"; expectVia = "name"; expectNotGame = "モンスターハンター：ワールド" }
  @{ n = "192. シリーズ名だけでは切り出さない"; title = "モンスターハンター";
     expectCount = 0 }
  @{ n = "193. 数字が続く場合は切り出さない"; title = "モンスターハンターワールド2";
     expectCount = 0 }

  # --- 英題表記 Pokémon Legends: Z-A。194 は実データにある表記をそのまま使っている ---
  @{ n = "194. 英題表記alias 単独";          title = "Pokémon Legends: Z-A";
     expectCount = 1; expectTopGame = "Pokémon LEGENDS Z-A"; expectTopConf = "MEDIUM"; expectVia = "alias"; expectAmbiguous = $false }
  @{ n = "195. 実況付き";                    title = "Pokémon Legends: Z-A 実況";
     expectCount = 1; expectTopGame = "Pokémon LEGENDS Z-A"; expectTopConf = "MEDIUM"; expectVia = "alias" }
  @{ n = "196. 正式名はaliasに奪われない";   title = "Pokémon LEGENDS Z-A";
     expectCount = 1; expectTopGame = "Pokémon LEGENDS Z-A"; expectTopConf = "HIGH"; expectVia = "name" }
  # --- ここから下は「aliasが é なし・アルセウス・英単語付き・数字付きへ広がらない」ことの固定 ---
  @{ n = "197. é なし表記は切り出さない";    title = "Pokemon Legends: Z-A";
     expectCount = 0 }
  @{ n = "198. アルセウス英題は切り出さない"; title = "Pokémon Legends: Arceus";
     expectCount = 0 }
  @{ n = "199. 英単語が続く場合は切り出さない"; title = "Pokémon Legends: Z-A DLC";
     expectCount = 0 }
  @{ n = "200. 数字が続く場合は切り出さない"; title = "Pokémon Legends: Z-A2";
     expectCount = 0 }

  # --- 空白・コロンなし表記 バイオハザードRE2。202-203 は実データにある表記をそのまま使っている ---
  @{ n = "201. 空白・コロンなし表記alias 単独"; title = "バイオハザードRE2";
     expectCount = 1; expectTopGame = "バイオハザード RE:2"; expectTopConf = "MEDIUM"; expectVia = "alias"; expectAmbiguous = $false }
  @{ n = "202. 小文字 e の実例";             title = "バイオハザードRe2🧟‍♂️";
     expectCount = 1; expectTopGame = "バイオハザード RE:2"; expectTopConf = "MEDIUM"; expectVia = "alias" }
  @{ n = "203. 全角空白+実況の実例";         title = "バイオハザードRE2　実況プレイ";
     expectCount = 1; expectTopGame = "バイオハザード RE:2"; expectTopConf = "MEDIUM"; expectVia = "alias" }
  @{ n = "204. 正式名はaliasに奪われない";   title = "バイオハザード RE:2";
     expectCount = 1; expectTopGame = "バイオハザード RE:2"; expectTopConf = "HIGH"; expectVia = "name" }
  @{ n = "205. 正式名と併記でも降格しない";  title = "バイオハザードRE2 / バイオハザード RE:2";
     expectCount = 1; expectTopGame = "バイオハザード RE:2"; expectTopConf = "HIGH"; expectVia = "name" }
  # --- ここから下は「aliasが RE3・無印2・英字表記・数字違いへ広がらない」ことの固定 ---
  @{ n = "206. RE3は切り出さない";           title = "バイオハザードRE3";
     expectNotGame = "バイオハザード RE:2" }
  @{ n = "207. 無印2は切り出さない";         title = "バイオハザード2";
     expectCount = 0 }
  @{ n = "208. 数字が続く場合は切り出さない"; title = "バイオハザードRE20";
     expectCount = 0 }
  @{ n = "209. 英字表記は対象外";            title = "BIOHAZARD RE2";
     expectCount = 0 }

  # --- 全角コロンなし表記 崩壊スターレイル。211 は実データにある表記をそのまま使っている ---
  @{ n = "210. 全角コロンなし表記alias 単独"; title = "崩壊スターレイル";
     expectCount = 1; expectTopGame = "崩壊：スターレイル"; expectTopConf = "MEDIUM"; expectVia = "alias"; expectAmbiguous = $false }
  @{ n = "211. 絵文字付きの実例";            title = "🎮崩壊スターレイル";
     expectCount = 1; expectTopGame = "崩壊：スターレイル"; expectTopConf = "MEDIUM"; expectVia = "alias" }
  @{ n = "212. 正式名はaliasに奪われない";   title = "崩壊：スターレイル";
     expectCount = 1; expectTopGame = "崩壊：スターレイル"; expectTopConf = "HIGH"; expectVia = "name" }
  @{ n = "213. 正式名と併記でも降格しない";  title = "崩壊：スターレイル【ゲーム実況/崩壊スターレイル】";
     expectCount = 1; expectTopGame = "崩壊：スターレイル"; expectTopConf = "HIGH"; expectVia = "name" }
  # --- ここから下は「aliasが崩壊3rd・短い語・英題・数字違いへ広がらない」ことの固定 ---
  @{ n = "214. 崩壊3rdは従来どおり";         title = "崩壊3rd";
     expectCount = 1; expectTopGame = "崩壊3rd"; expectTopConf = "HIGH"; expectVia = "name"; expectNotGame = "崩壊：スターレイル" }
  @{ n = "215. スターレイルだけでは切り出さない"; title = "スターレイル";
     expectCount = 0 }
  @{ n = "216. 英題は対象外";                title = "Honkai: Star Rail";
     expectCount = 0 }
  @{ n = "217. 数字が続く場合は切り出さない"; title = "崩壊スターレイル2";
     expectCount = 0 }

  # --- 空白・コロンなし表記 バイオハザードRE3。219-220 は実データにある表記をそのまま使っている ---
  @{ n = "218. 空白・コロンなし表記alias 単独"; title = "バイオハザードRE3";
     expectCount = 1; expectTopGame = "バイオハザード RE:3"; expectTopConf = "MEDIUM"; expectVia = "alias"; expectAmbiguous = $false }
  @{ n = "219. 小文字 e の実例";             title = "バイオハザードRe3🧟";
     expectCount = 1; expectTopGame = "バイオハザード RE:3"; expectTopConf = "MEDIUM"; expectVia = "alias" }
  @{ n = "220. 括弧+実況の実例";             title = "【バイオハザードRE3】実況";
     expectCount = 1; expectTopGame = "バイオハザード RE:3"; expectTopConf = "MEDIUM"; expectVia = "alias" }
  @{ n = "221. 正式名はaliasに奪われない";   title = "バイオハザード RE:3";
     expectCount = 1; expectTopGame = "バイオハザード RE:3"; expectTopConf = "HIGH"; expectVia = "name" }
  @{ n = "222. 正式名と併記でも降格しない";  title = "バイオハザードRE3 / バイオハザード RE:3";
     expectCount = 1; expectTopGame = "バイオハザード RE:3"; expectTopConf = "HIGH"; expectVia = "name" }
  # --- ここから下は「aliasが RE2・無印3・英字表記・数字違いへ広がらない」ことの固定 ---
  @{ n = "223. RE2は既存aliasどおり";        title = "バイオハザードRE2";
     expectCount = 1; expectTopGame = "バイオハザード RE:2"; expectTopConf = "MEDIUM"; expectVia = "alias"; expectNotGame = "バイオハザード RE:3" }
  @{ n = "224. 無印3は切り出さない";         title = "バイオハザード3";
     expectCount = 0 }
  @{ n = "225. 数字が続く場合は切り出さない"; title = "バイオハザードRE30";
     expectCount = 0 }
  @{ n = "226. 英字表記は対象外";            title = "BIOHAZARD RE3";
     expectCount = 0 }

  # --- コロンなし表記 NieRAutomata。227 は実データにある表記をそのまま使っている ---
  @{ n = "227. コロンなし表記aliasの実例";   title = "NieRAutomata【完結】";
     expectCount = 1; expectTopGame = "NieR:Automata"; expectTopConf = "MEDIUM"; expectVia = "alias"; expectAmbiguous = $false }
  @{ n = "228. 小文字表記";                  title = "nierautomata";
     expectCount = 1; expectTopGame = "NieR:Automata"; expectTopConf = "MEDIUM"; expectVia = "alias" }
  @{ n = "229. 空白表記";                    title = "NieR Automata 実況";
     expectCount = 1; expectTopGame = "NieR:Automata"; expectTopConf = "MEDIUM"; expectVia = "alias" }
  @{ n = "230. 正式名はaliasに奪われない";   title = "NieR:Automata";
     expectCount = 1; expectTopGame = "NieR:Automata"; expectTopConf = "HIGH"; expectVia = "name" }
  @{ n = "231. 正式名と併記でも降格しない";  title = "NieRAutomata / NieR:Automata";
     expectCount = 1; expectTopGame = "NieR:Automata"; expectTopConf = "HIGH"; expectVia = "name" }
  # --- ここから下は「aliasが別作品・部分語・数字/英字が続く形へ広がらない」ことの固定 ---
  @{ n = "232. 別作品Replicantは自作品へ";   title = "NieR Replicant";
     expectCount = 1; expectTopGame = "NieR Replicant"; expectTopConf = "HIGH"; expectVia = "name"; expectNotGame = "NieR:Automata" }
  @{ n = "233. 数字が続く場合は切り出さない"; title = "NieRAutomata2";
     expectCount = 0 }
  @{ n = "234. 英字が続く場合は切り出さない"; title = "NieRAutomataOnline";
     expectCount = 0 }
  @{ n = "235. カナ表記は対象外";            title = "ニーアオートマタ　実況プレイ";
     expectCount = 0 }

  # --- 「ら」抜き表記 ほの暮しの庭。236-238 は実データにある表記をそのまま使っている ---
  @{ n = "236. ら抜き表記alias 単独";        title = "ほの暮しの庭";
     expectCount = 1; expectTopGame = "ほの暮らしの庭"; expectTopConf = "MEDIUM"; expectVia = "alias"; expectAmbiguous = $false }
  @{ n = "237. 括弧+実況の実例";             title = "【ほの暮しの庭】実況プレイ";
     expectCount = 1; expectTopGame = "ほの暮らしの庭"; expectTopConf = "MEDIUM"; expectVia = "alias" }
  @{ n = "238. 絵文字付きの実例";            title = "ほの暮しの庭🌱";
     expectCount = 1; expectTopGame = "ほの暮らしの庭"; expectTopConf = "MEDIUM"; expectVia = "alias" }
  @{ n = "239. 正式名はaliasに奪われない";   title = "ほの暮らしの庭";
     expectCount = 1; expectTopGame = "ほの暮らしの庭"; expectTopConf = "HIGH"; expectVia = "name" }
  @{ n = "240. 正式名と併記でも降格しない";  title = "ほの暮しの庭 / ほの暮らしの庭";
     expectCount = 1; expectTopGame = "ほの暮らしの庭"; expectTopConf = "HIGH"; expectVia = "name" }
  # --- ここから下は「aliasが部分語・数字違い・別語へ広がらない」ことの固定 ---
  @{ n = "241. 部分語は切り出さない";         title = "暮しの庭";
     expectCount = 0 }
  @{ n = "242. 数字が続く場合は切り出さない"; title = "ほの暮しの庭2";
     expectCount = 0 }
  @{ n = "243. 別語は切り出さない";           title = "ほのぼの暮しの庭";
     expectCount = 0 }
  @{ n = "244. かな表記は対象外";            title = "ほのくらしのにわ";
     expectCount = 0 }

  # --- コロンなし表記 ARK survival evolved。245-247 は実データにある表記をそのまま使っている ---
  @{ n = "245. コロンなし表記alias 単独";    title = "ARK survival evolved";
     expectCount = 1; expectTopGame = "ARK: Survival Evolved"; expectTopConf = "MEDIUM"; expectVia = "alias"; expectAmbiguous = $false }
  @{ n = "246. 大小文字ゆれの実例";          title = "Ark Survival Evolved 【にじさんじ鯖】Crystal Isles";
     expectCount = 1; expectTopGame = "ARK: Survival Evolved"; expectTopConf = "MEDIUM"; expectVia = "alias" }
  @{ n = "247. 括弧が続く実例";              title = "ARK survival evolved【にじさんじ鯖】The Island";
     expectCount = 1; expectTopGame = "ARK: Survival Evolved"; expectTopConf = "MEDIUM"; expectVia = "alias" }
  @{ n = "248. 正式名はaliasに奪われない";   title = "ARK: Survival Evolved";
     expectCount = 1; expectTopGame = "ARK: Survival Evolved"; expectTopConf = "HIGH"; expectVia = "name" }
  @{ n = "249. 正式名と併記でも降格しない";  title = "ARK survival evolved / ARK: Survival Evolved";
     expectCount = 1; expectTopGame = "ARK: Survival Evolved"; expectTopConf = "HIGH"; expectVia = "name" }
  # --- ここから下は「aliasが別作品・部分語・英数字が続く形へ広がらない」ことの固定 ---
  @{ n = "250. 別作品Ascendedは自作品へ";    title = "ARK: Survival Ascended";
     expectCount = 1; expectTopGame = "ARK: Survival Ascended"; expectTopConf = "HIGH"; expectVia = "name"; expectNotGame = "ARK: Survival Evolved" }
  @{ n = "251. 数字が続く場合は切り出さない"; title = "ARK survival evolved2";
     expectCount = 0 }
  @{ n = "252. 英単語が続く場合は切り出さない"; title = "ARK survival evolved Aberration";
     expectCount = 0 }
  @{ n = "253. 部分語は切り出さない";         title = "survival evolved";
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
    if ($c.ContainsKey("expectVia") -and $top -and $top.matchVia -ne $c.expectVia) { $problems.Add("matchVia 期待$($c.expectVia) 実際$($top.matchVia)") }
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

  # ---- F2: GAMES の並び順を変えても判定が変わらないこと ----
  # data-core.js の GAMES エントリ(と各エントリ内の aliases)の並びだけを変えた複製を作り、
  # 同じ合成入力で matcher を実行して、全ケースの判定が元の並びと完全に一致することを確かめる。
  # シャッフルは固定seedのみ使う(実行ごとに結果が変わるテストにしない)。
  $sigOf = {
    param($list)
    $map = @{}
    foreach ($c in $cases) {
      $plid = $idOf[$c.n]
      $map[$c.n] = (@($list | Where-Object { $_.playlistId -eq $plid } | ForEach-Object {
        "{0}|{1}|{2}|{3}|{4}|{5}|{6}" -f $_.game, $_.confidence, $_.matchVia, $_.ambiguousMatch, $_.exactTitle, $_.cleanBoundary, $_.preferredBy
      }) | Sort-Object) -join " ; "
    }
    $map
  }
  $baseSig = & $sigOf $cands
  $coreLines = $coreText -split "`r?`n"
  $gStart = -1; $gEnd = -1
  for ($k = 0; $k -lt $coreLines.Count; $k++) {
    if ($gStart -lt 0 -and $coreLines[$k].StartsWith("const GAMES = [")) { $gStart = $k; continue }
    if ($gStart -ge 0 -and $coreLines[$k] -match '^\];') { $gEnd = $k; break }
  }
  $slots = @(for ($k = $gStart + 1; $k -lt $gEnd; $k++) { if ($coreLines[$k] -match '^\s*\{ name: "') { $k } })
  $entries = @($slots | ForEach-Object { $coreLines[$_] })
  $reorderAliases = {
    param([string]$line, [scriptblock]$fn)
    $am = [regex]::Match($line, 'aliases: \[([^\]]*)\]')
    if (-not $am.Success) { return $line }
    $items = @([regex]::Matches($am.Groups[1].Value, '"(?:[^"\\]|\\.)*"') | ForEach-Object { $_.Value })
    if ($items.Count -lt 2) { return $line }
    $line.Replace($am.Value, "aliases: [" + ((& $fn $items) -join ", ") + "]")
  }
  $seededShuffle = {
    param($arr, [int]$seed)
    $a = @($arr); $rnd = New-Object System.Random $seed
    for ($k = $a.Count - 1; $k -gt 0; $k--) { $j = $rnd.Next($k + 1); $tmp = $a[$k]; $a[$k] = $a[$j]; $a[$j] = $tmp }
    , $a
  }
  $nameOf = { param($l) [regex]::Match($l, 'name: "((?:[^"\\]|\\.)*)"').Groups[1].Value }
  $nameSorted = [string[]]$entries.Clone()
  [Array]::Sort([string[]]@($nameSorted | ForEach-Object { & $nameOf $_ }), $nameSorted, [System.StringComparer]::Ordinal)
  $perms = @(
    @{ n = "reverse";   games = @($entries[($entries.Count - 1)..0]); alias = { param($x) @($x[($x.Count - 1)..0]) } }
    @{ n = "name順";    games = @($nameSorted);                        alias = { param($x) @($x | Sort-Object) } }
    @{ n = "shuffle(seed=20260919)"; games = @(& $seededShuffle $entries 20260919); alias = { param($x) @(& $seededShuffle $x 7031) } }
  )
  foreach ($p in $perms) {
    $permDir = Join-Path $tmpDir ("perm-" + [guid]::NewGuid().ToString("N").Substring(0, 6))
    New-Item -ItemType Directory -Path $permDir -Force | Out-Null
    $out = [string[]]$coreLines.Clone()
    for ($k = 0; $k -lt $slots.Count; $k++) { $out[$slots[$k]] = & $reorderAliases $p.games[$k] $p.alias }
    [System.IO.File]::WriteAllText((Join-Path $permDir "data-core.js"), ($out -join "`r`n"), (New-Object System.Text.UTF8Encoding $false))
    Copy-Item -LiteralPath $matcher -Destination $permDir
    Copy-Item -LiteralPath (Join-Path $scriptDir "data-playlists.js") -Destination $permDir
    $permOut = Join-Path $permDir "candidates.json"
    & powershell.exe -NoProfile -File (Join-Path $permDir "match-playlist-candidates.ps1") -DiscoveredJson $inputPath -Json $permOut *> (Join-Path $permDir "matcher.log")
    $problems = New-Object System.Collections.Generic.List[string]
    if (-not (Test-Path $permOut)) { $problems.Add("matcher の実行に失敗しました") }
    else {
      $permSig = & $sigOf @((Get-Content $permOut -Raw -Encoding UTF8 | ConvertFrom-Json).candidates)
      foreach ($c in $cases) {
        if ($permSig[$c.n] -ne $baseSig[$c.n]) { $problems.Add("「$($c.title)」 元の並び[$($baseSig[$c.n])] / 並べ替え後[$($permSig[$c.n])]") }
      }
    }
    $ok = ($problems.Count -eq 0)
    if ($ok) { $pass++ } else { $fail++ }
    $label = "F2. GAMES並び順の入れ替えで判定が変わらない($($p.n))"
    Write-Output ("  [{0}] {1}" -f $(if ($ok) { "PASS" } else { "FAIL" }), $label)
    Write-Output ("        先頭ゲーム=「{0}」 / 比較ケース {1} 件" -f (& $nameOf $p.games[0]), $cases.Count)
    foreach ($q in $problems) { Write-Output "        NG: $q" }
    $rows.Add([PSCustomObject]@{ name = $label; title = ""; count = $null; topGame = $null; topConf = $null; ambiguous = $null; tokens = @(); pass = $ok; problems = $problems.ToArray() })
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
