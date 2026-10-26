/**
 * ============================================================
 * 専用再生リストが存在しない実況データ
 * ============================================================
 * YouTube側にゲーム専用の再生リストがない場合はこちらに登録します。
 * format:
 *   single         : 1本だけの単発実況
 *   multi          : 複数本あるが専用再生リストなし
 *   mixed-playlist : 「その他」等の雑多な再生リストに混在
 *
 * 必須: id, title, streamer, game, genre, format
 * single/multi は videos に動画URLを登録します。
 * mixed-playlist は mixedPlaylistUrl と videos の両方を持てます。
 * 実在確認できたURLだけを登録してください。
 *
 * 以前は data-playlists.js の末尾にありましたが、game.html/streamer.html が
 * 数MBある PLAYLISTS(data-playlists.js)を読み込まずに済むよう、
 * このファイルだけ独立させています(件数が少なく軽量なため、
 * PLAYLISTS を読み込むページ・読み込まないページの両方でこのファイルを
 * 読み込みます)。admin-standalone.html で生成した貼り付け用コードは
 * このファイルの STANDALONE_PLAYS 配列に追記してください。
 */
const STANDALONE_PLAYS = [
  // 登録例(URLは例なのでコメントのまま使用してください)
  // {
  //   id: "single-001",
  //   title: "ゲーム名 単発実況",
  //   streamer: "実況者名",
  //   game: "ゲーム名",
  //   genre: "other",
  //   format: "single",
  //   videos: [
  //     { title: "配信タイトル", url: "https://www.youtube.com/watch?v=...", publishedDate: "2026-01-01" }
  //   ],
  //   note: "専用再生リストなし",
  //   addedDate: "2026-09-09"
  // }
  {
    id: "single-001",
    title: "【夜勤事件】幽霊なんて、科学の力でワンパンです！",
    streamer: "宙科そぴあ",
    game: "夜勤事件",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【夜勤事件】幽霊なんて、科学の力でワンパンです！【宙科そぴあ/ホロライブ/アソビ★まわり隊！】", url: "https://www.youtube.com/watch?v=Ac-DypNuXyc", publishedDate: "2026-09-27" }
    ],
    note: "専用再生リストなし(本人の汎用「ゲーム」再生リストに収録)",
    addedDate: "2026-09-30"
  },
  {
    id: "single-002",
    title: "【ウツロマユ】ヘタレの汚名返上！！！！",
    streamer: "輪堂千速",
    game: "ウツロマユ",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【ウツロマユ】ヘタレの汚名返上！！！！【#輪堂千速 / #hololivedev_is  #FLOWGLOW 】", url: "https://www.youtube.com/watch?v=id2Fds0mOLo", publishedDate: "2026-07-12" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-09-30"
  },
  {
    id: "single-003",
    title: "【unpacking】うんぱくきんぐ #引っ越し",
    streamer: "花芽すみれ",
    game: "Unpacking",
    genre: "puzzle",
    format: "single",
    videos: [
      { title: "【unpacking】うんぱくきんぐ #引っ越し【ぶいすぽっ！/花芽すみれ】", url: "https://www.youtube.com/watch?v=U9YP0EIdyTI", publishedDate: "2026-08-20" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-09-30"
  },
  {
    id: "single-004",
    title: "【空気読み。】人外が人間社会で生きるということ。",
    streamer: "熱千めら",
    game: "空気読み。",
    genre: "other",
    format: "single",
    videos: [
      { title: "【空気読み。】人外が人間社会で生きるということ。【ホロライブ/アソビ★まわり隊！/熱千めら】", url: "https://www.youtube.com/watch?v=jo0r-Jq12a0", publishedDate: "2026-09-28" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-09-30"
  },
  {
    id: "single-005",
    title: "【めっちゃカメレオン】初見の大人気かくれんぼゲーム",
    streamer: "月ノ美兎",
    game: "めっちゃカメレオン",
    genre: "other",
    format: "single",
    videos: [
      { title: "【めっちゃカメレオン】初見の大人気かくれんぼゲーム【サロメ楓アンジュ美兎】", url: "https://www.youtube.com/watch?v=gklbzGVhI3s", publishedDate: "2026-07-05" }
    ],
    note: "専用再生リストなし(本人のコラボ用再生リスト「【コラボ】わっちゃわっちゃ」に収録)",
    addedDate: "2026-09-30"
  },
  {
    id: "single-006",
    title: "【リズム天国ミラクルスターズ】友達の家でWiiでやったっきりのリズ天",
    streamer: "輪堂千速",
    game: "リズム天国 ミラクルスターズ",
    genre: "other",
    format: "single",
    videos: [
      { title: "【リズム天国ミラクルスターズ】友達の家でWiiでやったっきりのリズ天【#輪堂千速 / #hololivedev_is  #FLOWGLOW 】", url: "https://www.youtube.com/watch?v=2N5jkTRmZwA", publishedDate: "2026-07-06" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-09-30"
  },
  {
    id: "single-007",
    title: "【ときめきメモリアル】完全初見。僕の青春高校生活...ひとり攻略まで！",
    streamer: "轟はじめ",
    game: "ときめきメモリアル",
    genre: "sim",
    format: "single",
    videos: [
      { title: "【ときめきメモリアル】完全初見。僕の青春高校生活...ひとり攻略まで！【轟はじめ/ReGLOSS】※ネタバレ＆告白シーンあります", url: "https://www.youtube.com/watch?v=aPYS9WQdqVs", publishedDate: "2026-06-28" }
    ],
    note: "専用再生リストなし(本人の汎用「ゲーム」再生リストに収録)",
    addedDate: "2026-10-01"
  },
  {
    id: "single-008",
    title: "【夜勤清掃】深夜にお掃除ホラゲ",
    streamer: "轟はじめ",
    game: "夜勤清掃",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【夜勤清掃】深夜にお掃除ホラゲ【轟はじめ/ReGLOSS】", url: "https://www.youtube.com/watch?v=cAVJ8gjGjCQ", publishedDate: "2026-04-05" }
    ],
    note: "専用再生リストなし(本人の汎用「ゲーム」再生リストに収録)",
    addedDate: "2026-10-01"
  },
  {
    id: "single-009",
    title: "【 夜勤清掃 】ホラーゲームをがんばります",
    streamer: "猫又おかゆ",
    game: "夜勤清掃",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【 夜勤清掃 】ホラーゲームをがんばります【 猫又おかゆ/ホロライブ 】", url: "https://www.youtube.com/watch?v=hQmMVdWhSg0", publishedDate: "2026-03-26" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-01"
  },
  {
    id: "single-010",
    title: "【夜勤清掃】ホラゲやる。",
    streamer: "戌神ころね",
    game: "夜勤清掃",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【夜勤清掃】ホラゲやる。", url: "https://www.youtube.com/watch?v=8dDVN2hz3ko", publishedDate: "2026-05-21" }
    ],
    note: "専用再生リストなし(本人のホラゲー再生リストに収録)",
    addedDate: "2026-10-01"
  },
  {
    id: "single-011",
    title: "【 みつめ 】怖がりな二人で異変を探せ！？",
    streamer: "綺々羅々ヴィヴィ",
    game: "みつめ",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【 みつめ 】怖がりな二人で異変を探せ！？【#綺々羅々ヴィヴィ #hololiveDEV_IS #FLOWGLOW #水宮枢 】", url: "https://www.youtube.com/watch?v=Bv73ukncvVs", publishedDate: "2026-09-07" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-01"
  },
  {
    id: "single-012",
    title: "【 鬼子母 Hariti  】怖がりの今年一怖い最恐ホラゲー！",
    streamer: "綺々羅々ヴィヴィ",
    game: "鬼子母 Hariti",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【 鬼子母 Hariti  】怖がりの今年一怖い最恐ホラゲー！【#綺々羅々ヴィヴィ #hololiveDEV_IS #FLOWGLOW  】", url: "https://www.youtube.com/watch?v=50PEQJ1GfH8", publishedDate: "2026-09-11" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-01"
  },
  {
    id: "single-013",
    title: "【心霊物件】大丈夫なので大丈夫です",
    streamer: "月ノ美兎",
    game: "心霊物件",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【心霊物件】大丈夫なので大丈夫です", url: "https://www.youtube.com/watch?v=EOTlRCWHfuw", publishedDate: "2025-03-23" }
    ],
    note: "専用再生リストなし(本人の「単発ゲーム実況」再生リストに収録)",
    addedDate: "2026-10-01"
  },
  {
    id: "single-014",
    title: "【8番出口】怖いの苦手なのじゃ…",
    streamer: "熱千めら",
    game: "8番出口",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【8番出口】怖いの苦手なのじゃ…【ホロライブ/アソビ★まわり隊！/熱千めら】", url: "https://www.youtube.com/watch?v=KNZDbpsAnB8", publishedDate: "2026-10-02" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-06"
  },
  {
    id: "single-015",
    title: "【GeoGuessr】なぜか場所特定が得意なのじゃ…",
    streamer: "熱千めら",
    game: "GeoGuessr",
    genre: "other",
    format: "single",
    videos: [
      { title: "【GeoGuessr】なぜか場所特定が得意なのじゃ…【ホロライブ/アソビ★まわり隊！/熱千めら】", url: "https://www.youtube.com/watch?v=z_ZP9E7qJc4", publishedDate: "2026-09-27" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-06"
  },
  {
    id: "single-016",
    title: "【Melatonin】チルなリズムゲーで まったり過ごそっ！",
    streamer: "宙科そぴあ",
    game: "Melatonin",
    genre: "other",
    format: "single",
    videos: [
      { title: "【Melatonin】チルなリズムゲーで まったり過ごそっ！【宙科そぴあ/ホロライブ/アソビ★まわり隊！】", url: "https://www.youtube.com/watch?v=pLCDnmdf9RU", publishedDate: "2026-10-03" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-06"
  },
  {
    id: "single-017",
    title: "【8番出口】新たな異変を見つけに行きたいゾ",
    streamer: "戌神ころね",
    game: "8番出口",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【8番出口】新たな異変を見つけに行きたいゾ【戌神ころね】", url: "https://www.youtube.com/watch?v=B0d7rw5tDc8", publishedDate: "2025-09-06" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-15"
  },
  {
    id: "single-018",
    title: "【Forza Horizon 6】ころねとドライブしよ～～～🚙=3",
    streamer: "戌神ころね",
    game: "Forza Horizon 6",
    genre: "racing",
    format: "single",
    videos: [
      { title: "【Forza Horizon 6】ころねとドライブしよ～～～🚙=3", url: "https://www.youtube.com/watch?v=AJVjf7cwpgY", publishedDate: "2026-06-08" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-15"
  },
  {
    id: "single-019",
    title: "【リズム天国ミラクルスターズ】遊ぶ【新作/発売したばかり/新しいゲーム】",
    streamer: "戌神ころね",
    game: "リズム天国 ミラクルスターズ",
    genre: "other",
    format: "single",
    videos: [
      { title: "【リズム天国ミラクルスターズ】遊ぶ【新作/発売したばかり/新しいゲーム】", url: "https://www.youtube.com/watch?v=Nx9mOOAA7IA", publishedDate: "2026-07-02" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-15"
  },
  {
    id: "single-020",
    title: "【 Forza Horizon 6 】東京をドライブしよう～～～💜💜💜",
    streamer: "猫又おかゆ",
    game: "Forza Horizon 6",
    genre: "racing",
    format: "single",
    videos: [
      { title: "【 Forza Horizon 6 】東京をドライブしよう～～～💜💜💜【 猫又おかゆ/ホロライブ 】", url: "https://www.youtube.com/watch?v=1vYyPS-HSe4", publishedDate: "2026-05-23" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-15"
  },
  {
    id: "single-021",
    title: "【ゼンレスゾーンゼロ】はじめてのゼンゼロ！たのしみ！",
    streamer: "花芽すみれ",
    game: "ゼンレスゾーンゼロ",
    genre: "rpg",
    format: "single",
    videos: [
      { title: "【ゼンレスゾーンゼロ】はじめてのゼンゼロ！たのしみ！【ぶいすぽっ！/花芽すみれ】", url: "https://www.youtube.com/watch?v=UTNfEMgOkbc", publishedDate: "2026-08-11" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-15"
  },
  {
    id: "single-022",
    title: "【利用規約に同意したい】が、難しいらしい(´;ω;｀)",
    streamer: "花芽すみれ",
    game: "利用規約に同意したい",
    genre: "action",
    format: "single",
    videos: [
      { title: "【利用規約に同意したい】が、難しいらしい(´;ω;｀)【ぶいすぽっ！/花芽すみれ】", url: "https://www.youtube.com/watch?v=6S9XXO5nQMM", publishedDate: "2025-12-25" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-15"
  },
  {
    id: "single-023",
    title: "【R.E.P.O.】このゲーム5人でできるんだ",
    streamer: "花芽すみれ",
    game: "R.E.P.O.",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【R.E.P.O.】このゲーム5人でできるんだ【ぶいすぽっ！/花芽すみれ】", url: "https://www.youtube.com/watch?v=RvuA9YralLw", publishedDate: "2026-01-09" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-15"
  },
  {
    id: "single-024",
    title: "【 HoloCure 】久しぶりのホロキュア！",
    streamer: "綺々羅々ヴィヴィ",
    game: "HoloCure",
    genre: "action",
    format: "single",
    videos: [
      { title: "【 HoloCure 】久しぶりのホロキュア！【#綺々羅々ヴィヴィ #hololiveDEV_IS #FLOWGLOW】", url: "https://www.youtube.com/watch?v=akRYyULNYAc", publishedDate: "2026-07-14" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-15"
  },
  {
    id: "single-025",
    title: "【めっちゃカメレオン】視聴者参加型！大阪でみんなと遊びたい！",
    streamer: "綺々羅々ヴィヴィ",
    game: "めっちゃカメレオン",
    genre: "other",
    format: "single",
    videos: [
      { title: "【めっちゃカメレオン】視聴者参加型！大阪でみんなと遊びたい！【#綺々羅々ヴィヴィ #hololiveDEV_IS #FLOWGLOW】", url: "https://www.youtube.com/watch?v=90J4KKSex-A", publishedDate: "2026-08-03" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-15"
  },
  {
    id: "single-026",
    title: "【 スーパーマリオブラザーズ2 】久しぶりにマリオやる～～～🍄✦",
    streamer: "猫又おかゆ",
    game: "スーパーマリオブラザーズ2",
    genre: "action",
    format: "multi",
    videos: [
      { title: "【 スーパーマリオブラザーズ2 】久しぶりにマリオやる～～～🍄✦【 猫又おかゆ/ホロライブ 】", url: "https://www.youtube.com/watch?v=D0PuyuYKFbc", publishedDate: "2026-04-09" },
      { title: "【 スーパーマリオブラザーズ2 】久しぶりにマリオやる～～～🍄✦#02【 猫又おかゆ/ホロライブ 】", url: "https://www.youtube.com/watch?v=b7DBD1coWD0", publishedDate: "2026-04-10" },
      { title: "【 スーパーマリオブラザーズ2 】久しぶりにマリオやる～～～🍄✦#03【 猫又おかゆ/ホロライブ 】", url: "https://www.youtube.com/watch?v=KjzhivMGKfY", publishedDate: "2026-04-16" },
      { title: "【 スーパーマリオブラザーズ2 】久しぶりにマリオやる～～～🍄✦#最終回【 猫又おかゆ/ホロライブ 】", url: "https://www.youtube.com/watch?v=7LNpmgkK85k", publishedDate: "2026-04-17" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-15"
  },
  {
    id: "single-027",
    title: "【ポケモンZA㊗発売】Pokémon LEGENDS Z-A遊ぶぞおおおおおおおおおお！！！！",
    streamer: "戌神ころね",
    game: "Pokémon LEGENDS Z-A",
    genre: "rpg",
    format: "multi",
    videos: [
      { title: "【ポケモンZA㊗発売】Pokémon LEGENDS Z-A遊ぶぞおおおおおおおおおお！！！！【戌神ころね】", url: "https://www.youtube.com/watch?v=cIU9vmiDewQ", publishedDate: "2025-10-16" },
      { title: "#2【ポケモンZA㊗発売】Pokémon LEGENDS Z-A遊ぶぞおおおおおおおおおお！！！！【戌神ころね】", url: "https://www.youtube.com/watch?v=QIZ6EJN0Bxs", publishedDate: "2025-10-16" },
      { title: "#3【ポケモンZA㊗発売】Pokémon LEGENDS Z-A遊ぶぞおおおおおおおおおお！！！！【戌神ころね】", url: "https://www.youtube.com/watch?v=Dwll_KR3m_Y", publishedDate: "2025-10-17" },
      { title: "【ポケモンZA】クリア後を楽しむの巻。伝説のポケモンほしい！！！", url: "https://www.youtube.com/watch?v=SOPKN5jgUpU", publishedDate: "2025-10-21" },
      { title: "【ポケモンZA】図鑑埋めるまで終われまテン！？", url: "https://www.youtube.com/watch?v=OdkJFj7b7Gw", publishedDate: "2025-11-02" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-15"
  },
  {
    id: "single-028",
    title: "#1【バイオハザード HDリマスター】やるです。",
    streamer: "戌神ころね",
    game: "バイオハザード HDリマスター",
    genre: "horror",
    format: "multi",
    videos: [
      { title: "#1【バイオハザード HDリマスター】やるです。", url: "https://www.youtube.com/watch?v=h3joGokdAiM", publishedDate: "2026-09-29" },
      { title: "#2【バイオハザード HDリマスター】やるです。", url: "https://www.youtube.com/watch?v=_eZmv3qcm9w", publishedDate: "2026-10-05" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-15"
  },
  {
    id: "single-029",
    title: "【利用規約に同意したい】ころねの復帰に同意して♡",
    streamer: "戌神ころね",
    game: "利用規約に同意したい",
    genre: "action",
    format: "multi",
    videos: [
      { title: "【利用規約に同意したい】ころねの復帰に同意して♡", url: "https://www.youtube.com/watch?v=u3LX06MaZOY", publishedDate: "2026-02-02" },
      { title: "【利用規約に同意したい】ころねの復帰に同意して♡ぱーとツー♡", url: "https://www.youtube.com/watch?v=iEqeynwejQQ", publishedDate: "2026-02-03" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-15"
  },
  {
    id: "single-030",
    title: "【利用規約に同意したい】利用規約に同意しますん",
    streamer: "獅白ぼたん",
    game: "利用規約に同意したい",
    genre: "action",
    format: "single",
    videos: [
      { title: "【利用規約に同意したい】利用規約に同意しますん【獅白ぼたん/ホロライブ】", url: "https://www.youtube.com/watch?v=tdCaDO2y6N0", publishedDate: "2025-12-13" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-17"
  },
  {
    id: "single-031",
    title: "【 利用規約に同意したい 】余裕綽々",
    streamer: "小森めと",
    game: "利用規約に同意したい",
    genre: "action",
    format: "single",
    videos: [
      { title: "【 利用規約に同意したい 】余裕綽々【 ぶいすぽっ！ / 小森めと 】", url: "https://www.youtube.com/watch?v=0GfcL_UYZeA", publishedDate: "2026-01-02" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-17"
  },
  {
    id: "single-032",
    title: "【 利用規約に同意したい 】 普通にキレます",
    streamer: "橘ひなの",
    game: "利用規約に同意したい",
    genre: "action",
    format: "single",
    videos: [
      { title: "【 利用規約に同意したい 】 普通にキレます【ぶいすぽっ！/橘ひなの】", url: "https://www.youtube.com/watch?v=V9MjPwyqenE", publishedDate: "2026-01-08" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-17"
  },
  {
    id: "single-033",
    title: "【利用規約に同意したい】　したいちゃう、すんねん！！！！！！！！！！",
    streamer: "蝶屋はなび",
    game: "利用規約に同意したい",
    genre: "action",
    format: "single",
    videos: [
      { title: "【利用規約に同意したい】　したいちゃう、すんねん！！！！！！！！！！　【 ぶいすぽっ！ ⁠/蝶屋はなび 】", url: "https://www.youtube.com/watch?v=kTnalJSxvro", publishedDate: "2025-12-25" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-17"
  },
  {
    id: "single-034",
    title: "◤ 利用規約に同意したい ◢　同意しかないのだが",
    streamer: "龍巻ちせ",
    game: "利用規約に同意したい",
    genre: "action",
    format: "single",
    videos: [
      { title: "◤ 利用規約に同意したい ◢　同意しかないのだが　◤ぶいすぽっ！ #龍巻ちせ ⁠◢", url: "https://www.youtube.com/watch?v=dQ0sjO0fL1w", publishedDate: "2026-02-02" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-17"
  },
  {
    id: "single-035",
    title: "【利用規約に同意したい】さすがにすぐ終わるっしょｗ",
    streamer: "千燈ゆうひ",
    game: "利用規約に同意したい",
    genre: "action",
    format: "single",
    videos: [
      { title: "【利用規約に同意したい】さすがにすぐ終わるっしょｗ【 ぶいすぽっ！ / 千燈ゆうひ 】", url: "https://www.youtube.com/watch?v=uraxCsKy5GE", publishedDate: "2025-12-31" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-17"
  },
  {
    id: "single-036",
    title: "【利用規約に同意したい】同意するだけでいいんだよね？",
    streamer: "兎咲ミミ",
    game: "利用規約に同意したい",
    genre: "action",
    format: "single",
    videos: [
      { title: "【利用規約に同意したい】同意するだけでいいんだよね？【ぶいすぽ/兎咲ミミ】", url: "https://www.youtube.com/watch?v=fJDJ1geW548", publishedDate: "2026-01-02" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-17"
  },
  {
    id: "single-037",
    title: "【 利用規約に同意したい 】今日できなかったら2026年も挑戦します",
    streamer: "神成きゅぴ",
    game: "利用規約に同意したい",
    genre: "action",
    format: "single",
    videos: [
      { title: "【 利用規約に同意したい 】今日できなかったら2026年も挑戦します【ぶいすぽ/神成きゅぴ】", url: "https://www.youtube.com/watch?v=QIutehAgh9U", publishedDate: "2025-12-30" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-17"
  },
  {
    id: "single-038",
    title: "【 利用規約に同意したい】爆速で終わらしてやる",
    streamer: "花芽なずな",
    game: "利用規約に同意したい",
    genre: "action",
    format: "single",
    videos: [
      { title: "【 利用規約に同意したい】爆速で終わらしてやる【ぶいすぽ/花芽なずな】", url: "https://www.youtube.com/watch?v=yUiwBqjBkPA", publishedDate: "2025-12-28" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-17"
  },
  {
    id: "single-039",
    title: "【利用規約に同意したい】利用規約に同意して生活リズムを直す",
    streamer: "紡木こかげ",
    game: "利用規約に同意したい",
    genre: "action",
    format: "single",
    videos: [
      { title: "【利用規約に同意したい】利用規約に同意して生活リズムを直す【ぶいすぽっ！ / 紡木こかげ】", url: "https://www.youtube.com/watch?v=OgBYjwZjR-A", publishedDate: "2026-06-04" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-17"
  },
  {
    id: "single-040",
    title: "【 利用規約に同意したい 】最速でクリアして最高のクリスマスにしようね☺",
    streamer: "鷹嶺ルイ",
    game: "利用規約に同意したい",
    genre: "action",
    format: "single",
    videos: [
      { title: "【 利用規約に同意したい 】最速でクリアして最高のクリスマスにしようね☺【鷹嶺ルイ/ ホロライブ】", url: "https://www.youtube.com/watch?v=uTPPpoWnwl0", publishedDate: "2025-12-25" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-17"
  },
  {
    id: "single-041",
    title: "【 利用規約に同意したい 】ぺこーら先輩から送られたゲームやってみる！！！！！",
    streamer: "音乃瀬奏",
    game: "利用規約に同意したい",
    genre: "action",
    format: "single",
    videos: [
      { title: "【 利用規約に同意したい 】ぺこーら先輩から送られたゲームやってみる！！！！！【音乃瀬奏】#hololiveDEV_IS #ReGLOSS", url: "https://www.youtube.com/watch?v=cJ8bg4oeo_8", publishedDate: "2026-01-15" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-17"
  },
{
    id: "single-042",
    title: "【バイオハザード６】ポンコツバイオでゆくレオン・ヘレナ編クリア耐久",
    streamer: "さくらみこ",
    game: "バイオハザード6",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【バイオハザード６】ポンコツバイオでゆくレオン・ヘレナ編クリア耐久【ホロライブ/#みこったかにぇ】", url: "https://www.youtube.com/watch?v=TIJctYljVA0", publishedDate: "2026-10-07" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-21"
  },
  {
    id: "single-043",
    title: "【鳴潮】ストーリーとガチャいくぞ！！",
    streamer: "夏色まつり",
    game: "鳴潮",
    genre: "rpg",
    format: "multi",
    videos: [
      { title: "【鳴潮】ストーリーとガチャいくぞ！！【ホロライブ/夏色まつり】", url: "https://www.youtube.com/watch?v=oIDOMuxSz8I", publishedDate: "2026-09-30" },
      { title: "【 鳴潮 】今日は姫に守護ってもらうポルまちゅ！【ホロライブ/夏色まつり】", url: "https://www.youtube.com/watch?v=JNOjAFc5oso", publishedDate: "2026-10-24" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-21"
  },
  {
    id: "single-044",
    title: "【R.E.P.O.】ひさしぶりのREPO！はじめ視点",
    streamer: "轟はじめ",
    game: "R.E.P.O.",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【R.E.P.O.】ひさしぶりのREPO！はじめ視点【轟はじめ/ReGLOSS】", url: "https://www.youtube.com/watch?v=g3XDlsGUU8w", publishedDate: "2026-09-20" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-21"
  },
  {
    id: "single-045",
    title: "【デュエプレ】そんなに怖いか？新世壊が！！新弾「虹帝∞命動」開封！！",
    streamer: "社築",
    game: "デュエル・マスターズ プレイス",
    genre: "other",
    format: "single",
    videos: [
      { title: "【デュエプレ】そんなに怖いか？新世壊が！！新弾「虹帝∞命動」開封！！【にじさんじ/社築】", url: "https://www.youtube.com/watch?v=eN92w-z7j_8", publishedDate: "2026-09-26" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-21"
  },
  {
    id: "single-046",
    title: "【逆転裁判123 成歩堂セレクション】※ネタバレ有 めっちゃ久しぶりに話進める！",
    streamer: "春崎エアル",
    game: "逆転裁判123 成歩堂セレクション",
    genre: "puzzle",
    format: "single",
    videos: [
      { title: "【逆転裁判123 成歩堂セレクション】※ネタバレ有 めっちゃ久しぶりに話進める！【春崎エアル/にじさんじ】", url: "https://www.youtube.com/watch?v=3mkR6gvUAmM", publishedDate: "2026-10-13" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-21"
  },
  {
    id: "single-047",
    title: "【壺おじ】目指すんだ…！圧倒的高み…ッ！！",
    streamer: "百灯キョーコ",
    game: "Getting Over It",
    genre: "action",
    format: "single",
    videos: [
      { title: "【壺おじ】目指すんだ…！圧倒的高み…ッ！！【百灯キョーコ/ホロライブ/アソビ★まわり隊！】", url: "https://www.youtube.com/watch?v=ai5tJOVZwUU", publishedDate: "2026-09-28" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-21"
  },
  {
    id: "single-048",
    title: "【ポケコロツイン】かざまの着せ替えセンスを見せるときが来たか・・・！",
    streamer: "風真いろは",
    game: "ポケコロツイン",
    genre: "other",
    format: "single",
    videos: [
      { title: "【ポケコロツイン】かざまの着せ替えセンスを見せるときが来たか・・・！【風真いろは/ホロライブ】", url: "https://www.youtube.com/watch?v=dTouiXf4DiA", publishedDate: "2026-09-18" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-21"
  },
  {
    id: "single-049",
    title: "【夜勤事件】コワクナイ。",
    streamer: "鈴鳴つづり",
    game: "夜勤事件",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【夜勤事件】コワクナイ。【鈴鳴つづり/ホロライブ/アソビ★まわり隊！】 #ホロライブ #アソビまわり隊  #つづり配達中", url: "https://www.youtube.com/watch?v=gTT0Af4vYyI", publishedDate: "2026-10-10" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-21"
  },
  {
    id: "single-050",
    title: "【幻想水滸伝】教えて！幻想水滸伝！！",
    streamer: "大空スバル",
    game: "幻想水滸伝I&II HDリマスター 門の紋章戦争/デュナン統一戦争",
    genre: "rpg",
    format: "single",
    videos: [
      { title: "【幻想水滸伝】教えて！幻想水滸伝！！【ホロライブ/大空スバル 姫森ルーナ 獅白ぼたん】", url: "https://www.youtube.com/watch?v=xhYUcXSiiz4", publishedDate: "2026-10-07" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-21"
  },
  {
    id: "single-051",
    title: "【7Days to Die】初参戦！初心者なので教えてもらいながら！！",
    streamer: "夏色まつり",
    game: "7 Days to Die",
    genre: "sandbox",
    format: "multi",
    videos: [
      { title: "【7Days to Die】初参戦！初心者なので教えてもらいながら！！#ホロ7大豆劇場 【ホロライブ/夏色まつり】", url: "https://www.youtube.com/watch?v=zSlhsP1jHwE", publishedDate: "2026-08-18" },
      { title: "【7Days to Die】エイムで７日目を乗り越える～！#ホロ7大豆劇場 【ホロライブ/夏色まつり】", url: "https://www.youtube.com/watch?v=yncG6v5Bu0E", publishedDate: "2026-08-19" },
      { title: "【7Days to Die】引っ越したらしい！クエスト受けまくり～！#ホロ7大豆劇場 【ホロライブ/夏色まつり】", url: "https://www.youtube.com/watch?v=shTjdf6aE5g", publishedDate: "2026-08-24" },
      { title: "【7Days to Die】砂漠あちあちゾンビ！！#ホロ7大豆劇場 【ホロライブ/夏色まつり】", url: "https://www.youtube.com/watch?v=HULJY5ZMKmo", publishedDate: "2026-09-08" },
      { title: "【7Days to Die】冷静にさばいていくッ！！#ホロ7大豆劇場 【ホロライブ/夏色まつり】", url: "https://www.youtube.com/watch?v=eBrln7M6Rdo", publishedDate: "2026-09-08" },
      { title: "【7Days to Die】銃がつよくなりました！#ホロ7大豆劇場 【ホロライブ/夏色まつり】", url: "https://www.youtube.com/watch?v=eX02LKDWsk4", publishedDate: "2026-09-09" },
      { title: "【7Days to Die】立てこもり！襲撃に耐えろ！！#ホロ7大豆劇場 【ホロライブ/夏色まつり】", url: "https://www.youtube.com/watch?v=lra3XyTDKhE", publishedDate: "2026-09-15" },
      { title: "【7Days to Die】荒地でクエスト回しまくり～！#ホロ7大豆劇場 【ホロライブ/夏色まつり】", url: "https://www.youtube.com/watch?v=lpejWDQTlJU", publishedDate: "2026-09-17" },
      { title: "【7Days to Die】最終日！背中はまかせた～！！#ホロ7大豆劇場 【ホロライブ/夏色まつり】", url: "https://www.youtube.com/watch?v=vHj0NCLwo-k", publishedDate: "2026-09-20" },
      { title: "【7Days to Die】番外編！高難易度クエストいくぞ～！#ホロ7大豆劇場 【ホロライブ/夏色まつり】", url: "https://www.youtube.com/watch?v=W4kIcPlxUTU", publishedDate: "2026-09-24" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-21"
  },
{
    id: "single-052",
    title: "【めっちゃカメレオン】今頃！やっと初プレイのめっちゃカメレオンwith謎いつメン",
    streamer: "社築",
    game: "めっちゃカメレオン",
    genre: "other",
    format: "single",
    videos: [
      { title: "【めっちゃカメレオン】今頃！！やっと初プレイのめっちゃカメレオンwith謎いつメン【にじさんじ/社築】", url: "https://www.youtube.com/watch?v=oVd8OJGrLDs", publishedDate: "2026-10-07" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-21"
  },
  {
    id: "single-053",
    title: "【アソビ大全】「運」の熱千めら VS「知」の宙科そぴあ",
    streamer: "熱千めら",
    game: "世界のアソビ大全51",
    genre: "other",
    format: "single",
    videos: [
      { title: "【アソビ大全】「運」の熱千めら VS「知」の宙科そぴあ【ホロライブ】", url: "https://www.youtube.com/watch?v=LyPzb9zrjXU", publishedDate: "2026-10-08" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-21"
  },
  {
    id: "single-054",
    title: "事故物件をあーだこーだ ※ネタバレ禁止  | 日本事故物件監視協会 -JSP-",
    streamer: "叶",
    game: "日本事故物件監視協会",
    genre: "horror",
    format: "single",
    videos: [
      { title: "事故物件をあーだこーだ ※ネタバレ禁止  | 日本事故物件監視協会 -JSP-【にじさんじ/叶】", url: "https://www.youtube.com/watch?v=ACLr0oq58u0", publishedDate: "2026-09-24" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-21"
  },
  {
    id: "single-055",
    title: "BDX二次会カメレオンらしい  | めっちゃカメレオン",
    streamer: "叶",
    game: "めっちゃカメレオン",
    genre: "other",
    format: "single",
    videos: [
      { title: "BDX二次会カメレオンらしい  | めっちゃカメレオン【にじさんじ/叶】", url: "https://www.youtube.com/watch?v=A4TtiPNZbgg", publishedDate: "2026-09-29" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-21"
  },
  {
    id: "single-056",
    title: "【初】３Dで莉々華とリングフィット アドベンチャー！",
    streamer: "轟はじめ",
    game: "リングフィットアドベンチャー",
    genre: "sports",
    format: "single",
    videos: [
      { title: "【初】３Dで莉々華とリングフィット アドベンチャー！【轟はじめ/ホロライブReGLOSS】", url: "https://www.youtube.com/watch?v=Qv7M3pSYW5U", publishedDate: "2026-10-18" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-21"
  },
  {
    id: "single-057",
    title: "ありえんスマートな2人によるSuper Bunny Man",
    streamer: "宙科そぴあ",
    game: "Super Bunny Man",
    genre: "action",
    format: "single",
    videos: [
      { title: "ありえんスマートな2人によるSuper Bunny Man【宙科そぴあ/鈴鳴つづり/ホロライブ/アソビ★まわり隊！】", url: "https://www.youtube.com/watch?v=fGnE7S2OFfo", publishedDate: "2026-10-12" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-21"
  },
  {
    id: "single-058",
    title: "【#ホロ夏Among Us】アツいAmong Usが…くるッ…！",
    streamer: "百鬼あやめ",
    game: "Among Us",
    genre: "other",
    format: "single",
    videos: [
      { title: "【#ホロ夏Among Us】アツいAmong Usが…くるッ…！【百鬼あやめ/ホロライブ】", url: "https://www.youtube.com/watch?v=sB05O-NIXKQ", publishedDate: "2026-08-04" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-21"
  },
  {
    id: "single-059",
    title: "【ホラー】カフェの仕事？憧れてたんです！ | 閉店事件",
    streamer: "百灯キョーコ",
    game: "閉店事件",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【ホラー】カフェの仕事？憧れてたんです！ | 閉店事件【百灯キョーコ/ホロライブ/アソビ★まわり隊！】", url: "https://www.youtube.com/watch?v=yT6Sp7JtRVY", publishedDate: "2026-10-04" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-21"
  },
  {
    id: "single-060",
    title: "【EN】First time playing Five Nights at Freddy's! | FNAF",
    streamer: "百灯キョーコ",
    game: "Five Nights at Freddy's",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【EN】First time playing Five Nights at Freddy's!! | FNAF【Hyakuto Kyoko/Hololive】", url: "https://www.youtube.com/watch?v=UoDgaiOpxIw", publishedDate: "2026-10-17" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-21"
  },
  {
    id: "single-061",
    title: "魔法少女ノ魔女裁判｜ この中に、魔女になった少女がいる ※ネタバレ注意",
    streamer: "夕陽リリ",
    game: "魔法少女ノ魔女裁判",
    genre: "horror",
    format: "single",
    videos: [
      { title: "▶︎▷ 魔法少女ノ魔女裁判｜ この中に、魔女になった少女がいる ※ネタバレ注意 ｜ 夕陽リリ ￤ にじさんじ", url: "https://www.youtube.com/watch?v=WUfZtcK1S0o", publishedDate: "2026-09-27" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-21"
  },
  {
    id: "single-062",
    title: "宇宙探検隊 | No Man's Sky",
    streamer: "静凛",
    game: "No Man's Sky",
    genre: "sandbox",
    format: "multi",
    videos: [
      { title: "🚀 | 宇宙探検隊 | No Man's Sky【静凛/にじさんじ】", url: "https://www.youtube.com/watch?v=C9HmvFjdt0U", publishedDate: "2026-10-08" },
      { title: "🚀02 | 宇宙探検隊 | No Man's Sky【静凛/にじさんじ】", url: "https://www.youtube.com/watch?v=z9S8tElDSs4", publishedDate: "2026-10-09" },
      { title: "🚀03 | 宇宙探検隊 | No Man's Sky【静凛/にじさんじ】", url: "https://www.youtube.com/watch?v=GUMIbX_CXig", publishedDate: "2026-10-10" },
      { title: "🚀04 | 宇宙探検隊 | No Man's Sky【静凛/にじさんじ】", url: "https://www.youtube.com/watch?v=A-ZR6yqnsuo", publishedDate: "2026-10-11" },
      { title: "🚀05 | 宇宙探検隊 | No Man's Sky【静凛/にじさんじ】", url: "https://www.youtube.com/watch?v=EiGBwXyY7fE", publishedDate: "2026-10-13" },
      { title: "🚀06 | コルベットver1.0完成!! | No Man's Sky【静凛/にじさんじ】", url: "https://www.youtube.com/watch?v=ODv3y376gFg", publishedDate: "2026-10-14" },
      { title: "🚀07 | 今日の宇宙は | No Man's Sky【静凛/にじさんじ】", url: "https://www.youtube.com/watch?v=26hGhUBOR1k", publishedDate: "2026-10-15" },
      { title: "🚀08 | 宇宙船… | No Man's Sky【静凛/にじさんじ】", url: "https://www.youtube.com/watch?v=LbjXZEee92Y", publishedDate: "2026-10-16" },
      { title: "🚀共同探検23 01 | No Man's Sky【静凛/にじさんじ】", url: "https://www.youtube.com/watch?v=sqxAKcovqtU", publishedDate: "2026-10-18" },
      { title: "🚀共同探検23 02 | No Man's Sky【静凛/にじさんじ】", url: "https://www.youtube.com/watch?v=mxUlqfGxP7E", publishedDate: "2026-10-19" },
      { title: "🚀共同探検23 03 | No Man's Sky【静凛/にじさんじ】", url: "https://www.youtube.com/watch?v=ah706yKX4jA", publishedDate: "2026-10-22" },
      { title: "🚀共同探検23 04 | No Man's Sky【静凛/にじさんじ】", url: "https://www.youtube.com/watch?v=CDMB23_t5pU", publishedDate: "2026-10-25" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-21"
  },
  {
    id: "single-063",
    title: "【#生スバル】キャプテン翼2 WORLD FIGHTERS やるしゅばあああああああああああああああああああああああああああ！",
    streamer: "大空スバル",
    game: "キャプテン翼2 WORLD FIGHTERS",
    genre: "sports",
    format: "multi",
    videos: [
      { title: "【#生スバル】キャプテン翼2 WORLD FIGHTERS やるしゅばあああああああああああああああああああああああああああ！！！！！！！【ホロライブ/大空スバル】", url: "https://www.youtube.com/watch?v=uEJk1HN5AyM", publishedDate: "2026-09-26" },
      { title: "【#2】キャプテン翼2 WORLD FIGHTERS やるしゅばあああああああああああああああああああああああああああ！！！！！！！【ホロライブ/大空スバル】", url: "https://www.youtube.com/watch?v=SqQWD7yy06U", publishedDate: "2026-09-27" },
      { title: "【#3】キャプテン翼2 WORLD FIGHTERS やるしゅばあああああああああああああああああああああああああああ！！！！！！！【ホロライブ/大空スバル】", url: "https://www.youtube.com/watch?v=nVLlI4TBy_w", publishedDate: "2026-10-03" },
      { title: "【#4】キャプテン翼2 WORLD FIGHTERS やるしゅばあああああああああああああああああああああああああああ！！！！！！！【ホロライブ/大空スバル】", url: "https://www.youtube.com/watch?v=BOjKLly-bLQ", publishedDate: "2026-10-04" },
      { title: "【#5】キャプテン翼2 WORLD FIGHTERS やるしゅばあああああああああああああああああああああああああああ！！！！！！！【ホロライブ/大空スバル】", url: "https://www.youtube.com/watch?v=VgVoVniznX8", publishedDate: "2026-10-10" },
      { title: "【#最終回】キャプテン翼2 WORLD FIGHTERS やるしゅばあああああああああああああああああああああああああああ！！！！！！！【ホロライブ/大空スバル】", url: "https://www.youtube.com/watch?v=QeppR1Vk3_g", publishedDate: "2026-10-11" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-21"
  },
  {
    id: "single-064",
    title: "【ELDEN RING/エルデンリング】俺は王になる男だ",
    streamer: "卯月コウ",
    game: "ELDEN RING",
    genre: "action",
    format: "multi",
    videos: [
      { title: "【ELDEN RING/エルデンリング】俺は王になる男だ #1【にじさんじ/卯月コウ】", url: "https://www.youtube.com/watch?v=71HA995ZF64", publishedDate: "2026-10-11" },
      { title: "【ELDEN RING/エルデンリング】マルギット倒せたんだから王になれる #2【にじさんじ/卯月コウ】", url: "https://www.youtube.com/watch?v=0Fn_4V4rm4Y", publishedDate: "2026-10-11" },
      { title: "【ELDEN RING/エルデンリング】おいそこどけキングのお通り  #３【にじさんじ/卯月コウ】", url: "https://www.youtube.com/watch?v=mjoNPXV498A", publishedDate: "2026-10-15" },
      { title: "【ELDEN RING/エルデンリング】魔女BBA倒して王になる  #４【にじさんじ/卯月コウ】", url: "https://www.youtube.com/watch?v=5JHuwA7WrOY", publishedDate: "2026-10-18" },
      { title: "【ELDEN RING/エルデンリング】竜の力で王になる  #5【にじさんじ/卯月コウ】", url: "https://www.youtube.com/watch?v=kPRq0aJiQy8", publishedDate: "2026-10-18" },
      { title: "【ELDEN RING/エルデンリング】星が落ちた地  #6【にじさんじ/卯月コウ】", url: "https://www.youtube.com/watch?v=vyR2fvR-8aQ", publishedDate: "2026-10-23" },
      { title: "【ELDEN RING/エルデンリング】王都を侵略して王になる #7【にじさんじ/卯月コウ】", url: "https://www.youtube.com/watch?v=ck6sBHiVx2Y", publishedDate: "2026-10-25" },
      { title: "【ELDEN RING/エルデンリング】王都完結、そして火山も破壊する #8【にじさんじ/卯月コウ】", url: "https://www.youtube.com/watch?v=NDlq2Z8MBcA", publishedDate: "2026-10-26" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-21"
  },
  {
    id: "single-065",
    title: "【EN】#1 FIRST TIME PLAYING Cuphead",
    streamer: "百灯キョーコ",
    game: "Cuphead",
    genre: "action",
    format: "multi",
    videos: [
      { title: "【EN】#1 FIRST TIME PLAYING Cuphead【Hyakuto Kyoko/Hololive】", url: "https://www.youtube.com/watch?v=n1VcCnoPHds", publishedDate: "2026-10-09" },
      { title: "【EN】#2 I'm already in love with this game! | Cuphead【Hyakuto Kyoko/Hololive】", url: "https://www.youtube.com/watch?v=GGHPveb5wFU", publishedDate: "2026-10-11" },
      { title: "【EN】#3 Continuing on the 2nd Isle!! | Cuphead【Hyakuto Kyoko/Hololive】", url: "https://www.youtube.com/watch?v=1xNlquw8BYw", publishedDate: "2026-10-14" },
      { title: "【EN】#4 Can I finish the 2nd Isle today? | Cuphead【Hyakuto Kyoko/Hololive】", url: "https://www.youtube.com/watch?v=CVsPXWqiD8k", publishedDate: "2026-10-16" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-21"
  },
  {
    id: "single-066",
    title: "VALORANT イモータルを目指す!",
    streamer: "鈴鳴つづり",
    game: "VALORANT",
    genre: "fps",
    format: "multi",
    videos: [
      { title: "VALORANT イモータルを目指す!! 　#１【鈴鳴つづり/ホロライブ/アソビ★まわり隊！】 #ホロライブ #アソビまわり隊  #つづり配達中", url: "https://www.youtube.com/watch?v=8GlaHUbu95o", publishedDate: "2026-09-28" },
      { title: "VALORANT イモータルを目指す!! 　#２【鈴鳴つづり/ホロライブ/アソビ★まわり隊！】 #ホロライブ #アソビまわり隊  #つづり配達中", url: "https://www.youtube.com/watch?v=8w3b1H5ww5Q", publishedDate: "2026-09-29" },
      { title: "VALORANT イモータルを目指す!! 　#３【鈴鳴つづり/ホロライブ/アソビ★まわり隊！】 #ホロライブ #アソビまわり隊  #つづり配達中", url: "https://www.youtube.com/watch?v=pvcMRIQ9jwQ", publishedDate: "2026-10-12" },
      { title: "VALORANT イモータルを目指す!! 　#４【鈴鳴つづり/ホロライブ/アソビ★まわり隊！】 #ホロライブ #アソビまわり隊  #つづり配達中", url: "https://www.youtube.com/watch?v=ZspvK4EGpWY", publishedDate: "2026-10-16" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-21"
  },
  {
    id: "single-067",
    title: "【空の軌跡 the 2nd】完全初見！2ndいくぞおおおおおお！※ネタバレあり",
    streamer: "博衣こより",
    game: "空の軌跡 the 2nd",
    genre: "rpg",
    format: "multi",
    videos: [
      { title: "【空の軌跡 the 2nd】完全初見！2ndいくぞおおおおおお！！！！！！！！！【博衣こより/ホロライブ】※ネタバレあり", url: "https://www.youtube.com/watch?v=Ibd0E7cEr1M", publishedDate: "2026-10-03" },
      { title: "【空の軌跡 the 2nd】完全初見！第1章プレイ中！withシェラ姉だよ～！ #2 【博衣こより/ホロライブ】※ネタバレあり", url: "https://www.youtube.com/watch?v=d3_-HSxjShc", publishedDate: "2026-10-04" },
      { title: "【空の軌跡 the 2nd】完全初見！第2章突入！withシェラ姉！ #3 【博衣こより/ホロライブ】※ネタバレあり", url: "https://www.youtube.com/watch?v=z8qmbc8BMC8", publishedDate: "2026-10-10" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-21"
  },
  {
    id: "single-068",
    title: "#1 神ゲーに挑むぞー！ | 都市伝説解体センター　※ネタバレ注意",
    streamer: "百灯キョーコ",
    game: "都市伝説解体センター",
    genre: "other",
    format: "multi",
    videos: [
      { title: "#1 神ゲーに挑むぞー！！！ | 都市伝説解体センター　※ネタバレ注意【百灯キョーコ/ホロライブ/アソビ★まわり隊！】", url: "https://www.youtube.com/watch?v=zscbFBdOvyI", publishedDate: "2026-10-02" },
      { title: "#2 更なる謎の解明に！いざああああ！！！ | 都市伝説解体センター　※ネタバレ注意【百灯キョーコ/ホロライブ/アソビ★まわり隊！】", url: "https://www.youtube.com/watch?v=255rLPEHoi8", publishedDate: "2026-10-12" },
      { title: "#3 深まる謎も、全部解き明かすよーー！！！ | 都市伝説解体センター　※ネタバレ注意【百灯キョーコ/ホロライブ/アソビ★まわり隊！】", url: "https://www.youtube.com/watch?v=yaGBdBwtvWA", publishedDate: "2026-10-18" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-21"
  },
  {
    id: "single-069",
    title: "日本事故物件監視協会 -Japan Stigmatized Property- ｜ ホラーゲーム",
    streamer: "夕陽リリ",
    game: "日本事故物件監視協会",
    genre: "horror",
    format: "multi",
    videos: [
      { title: "▶︎▷ 日本事故物件監視協会 -Japan Stigmatized Property- ｜ ホラーゲーム ｜ 夕陽リリ ￤ にじさんじ", url: "https://www.youtube.com/watch?v=uL1Uc-8zDeg", publishedDate: "2026-10-06" },
      { title: "▶︎▷ 日本事故物件監視協会 -Japan Stigmatized Property- ｜ ホラーゲーム2 ｜ 夕陽リリ ￤ にじさんじ", url: "https://www.youtube.com/watch?v=EuC6bpuiZDo", publishedDate: "2026-10-11" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-21"
  },
{
    id: "single-070",
    title: "【 🎮パラノマサイト FILE23 本所七不思議 / #1 】蘇りの秘術を求めて呪っちゃう？ホラーミステリー※ネタバレあり",
    streamer: "轟京子",
    game: "パラノマサイト FILE23 本所七不思議",
    genre: "horror",
    format: "multi",
    videos: [
      { title: "【 🎮パラノマサイト FILE23 本所七不思議 / #1 】蘇りの秘術を求めて呪っちゃう？ホラーミステリー※ネタバレあり 【にじさんじ/轟京子】", url: "https://www.youtube.com/watch?v=GzPgNeTTYQU", publishedDate: "2026-09-15" },
      { title: "【 🎮パラノマサイト FILE23 本所七不思議 / #2 】呪え！蘇りの秘術を巡るホラーミステリー※ネタバレあり 【にじさんじ/轟京子】", url: "https://www.youtube.com/watch?v=gU58n6lDilQ", publishedDate: "2026-09-16" },
      { title: "【 🎮パラノマサイト FILE23 本所七不思議 / #3 】コックリさんなんかチャレンジしてみちゃうホラーミステリー※ネタバレあり 【にじさんじ/轟京子】", url: "https://www.youtube.com/watch?v=Av7tWZ9iAB4", publishedDate: "2026-09-18" },
      { title: "【 🎮パラノマサイト FILE23 本所七不思議 / #4 】呪主探して墨田区を練り歩こう！※ネタバレあり 【にじさんじ/轟京子】", url: "https://www.youtube.com/watch?v=5kz4YTEobNI", publishedDate: "2026-09-19" },
      { title: "【 🎮パラノマサイト FILE23 本所七不思議 / #5 】だいぶエグい事件が起こっているホラーミステリー※ネタバレあり 【にじさんじ/轟京子】", url: "https://www.youtube.com/watch?v=WgNjSyEg0i8", publishedDate: "2026-09-20" },
      { title: "【 🎮パラノマサイト FILE23 本所七不思議 / #6 】入手困難すぎる本と、人を探しています。※ネタバレあり 【にじさんじ/轟京子】", url: "https://www.youtube.com/watch?v=6XcB8hTTCB4", publishedDate: "2026-09-23" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-21"
  },
  {
    id: "single-071",
    title: "【バイオハザード レクイエム】新作のバイオやるぞ・・・！",
    streamer: "百鬼あやめ",
    game: "バイオハザード レクイエム",
    genre: "horror",
    format: "multi",
    videos: [
      { title: "【バイオハザード レクイエム】新作のバイオやるぞ・・・！【百鬼あやめ/ホロライブ】", url: "https://www.youtube.com/watch?v=2srqHwe62vE", publishedDate: "2026-03-28" },
      { title: "【バイオハザード レクイエム】ステルスを覚え始めました。＃2【百鬼あやめ/ホロライブ】", url: "https://www.youtube.com/watch?v=E1DuNe3uIrY", publishedDate: "2026-04-01" },
      { title: "【バイオハザード レクイエム】臓器探しの旅編 になりそうな予感。＃3【百鬼あやめ/ホロライブ】", url: "https://www.youtube.com/watch?v=lVaCdidMYhs", publishedDate: "2026-04-08" },
      { title: "【バイオハザード レクイエム】恐怖の地下編＃4【百鬼あやめ/ホロライブ】", url: "https://www.youtube.com/watch?v=e7JvA7J1jNs", publishedDate: "2026-04-26" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-21"
  },
  {
    id: "single-072",
    title: "【遊戯王マスターデュエル　#にじ遊戯王祭2026】あのねっ！ マギストスってなあに？",
    streamer: "社築",
    game: "遊戯王マスターデュエル",
    genre: "other",
    format: "multi",
    videos: [
      { title: "【遊戯王マスターデュエル　#にじ遊戯王祭2026】あのねっ！ マギストスってなあに？【にじさんじ/社築】", url: "https://www.youtube.com/watch?v=BiPnuK6KCRY", publishedDate: "2026-09-08" },
      { title: "【遊戯王マスターデュエル　#にじ遊戯王祭2026】おい、修行しろよ【にじさんじ/社築】", url: "https://www.youtube.com/watch?v=fzlEBHWCjiw", publishedDate: "2026-09-16" },
      { title: "【遊戯王マスターデュエル　#にじ遊戯王祭2026】えらいハリキリ☆チームが顔合わせじゃねぇか【にじさんじ/社築】", url: "https://www.youtube.com/watch?v=b-V4x8HPkjo", publishedDate: "2026-09-18" },
      { title: "【遊戯王マスターデュエル　#にじ遊戯王祭2026】僕が言いたいのは「粛清」　予選Aリーグ【にじさんじ/社築】", url: "https://www.youtube.com/watch?v=heoYTNO39tI", publishedDate: "2026-09-21" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-21"
  },
  {
    id: "single-073",
    title: "【遊戯王マスターデュエル】町内対抗☆ゲートボール大会☆",
    streamer: "社築",
    game: "遊戯王マスターデュエル",
    genre: "other",
    format: "single",
    videos: [
      { title: "【遊戯王マスターデュエル】町内対抗☆ゲートボール大会☆【にじさんじ/社築】", url: "https://www.youtube.com/watch?v=P68BSNROdKs", publishedDate: "2026-09-27" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-21"
  },
  {
    id: "single-074",
    title: "【スプラトゥーン3】誘ったら来てくれた杯2　ジェッパマン箱外に出動！",
    streamer: "社築",
    game: "スプラトゥーン3",
    genre: "fps",
    format: "single",
    videos: [
      { title: "【スプラトゥーン3】誘ったら来てくれた杯2　ジェッパマン箱外に出動！！【にじさんじ/社築】", url: "https://www.youtube.com/watch?v=Wn2LiMz2LGM", publishedDate: "2026-09-20" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-21"
  },
  {
    id: "single-075",
    title: "【スプラトゥーン3】VCC INK FES 2いきなり本番　イカすジェッパを見せる男",
    streamer: "社築",
    game: "スプラトゥーン3",
    genre: "fps",
    format: "single",
    videos: [
      { title: "【スプラトゥーン3】VCC INK FES 2いきなり本番　イカすジェッパを見せる男【にじさんじ/社築】", url: "https://www.youtube.com/watch?v=aY5t0v5DTps", publishedDate: "2026-10-17" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-10-21"
  },
  {
    id: "single-076",
    title: "【スプラトゥーン3 】　短射程はやめた！！っぱスピナーよ",
    streamer: "アルス・アルマル",
    game: "スプラトゥーン3",
    genre: "fps",
    format: "single",
    videos: [
      { title: "【スプラトゥーン3 】　短射程はやめた！！っぱスピナーよ　【アルス・アルマル/にじさんじ】", url: "https://www.youtube.com/watch?v=v7NCiECxw80", publishedDate: "2026-10-23" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-24"
  },
  {
    id: "single-077",
    title: "【マリオカートワールド】朗読新刊出ました",
    streamer: "シェリン・バーガンディ",
    game: "マリオカートワールド",
    genre: "racing",
    format: "single",
    videos: [
      { title: "【マリオカートワールド】朗読新刊出ました【シェリン/にじさんじ】", url: "https://www.youtube.com/watch?v=2JPTgIJMt3g", publishedDate: "2026-10-13" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-24"
  },
  {
    id: "single-078",
    title: "【 ぽこ あ ポケモン 】ポケモン達もハロウィンを楽しんでいるみたい",
    streamer: "セフィナ",
    game: "ぽこ あ ポケモン",
    genre: "other",
    format: "single",
    videos: [
      { title: "【 ぽこ あ ポケモン 】ポケモン達もハロウィンを楽しんでいるみたい【にじさんじ | セフィナ】", url: "https://www.youtube.com/watch?v=NU10enUjuhI", publishedDate: "2026-10-18" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-24"
  },
  {
    id: "single-079",
    title: "【 めっちゃカメレオン 】めっちゃ #ふぃことりすた 🐤⭐️ カメレオン！",
    streamer: "ソフィア・ヴァレンタイン",
    game: "めっちゃカメレオン",
    genre: "other",
    format: "single",
    videos: [
      { title: "【 めっちゃカメレオン 】めっちゃ #ふぃことりすた 🐤⭐️ カメレオン！【ソフィア・ヴァレンタイン/にじさんじ】", url: "https://www.youtube.com/watch?v=3UgcHwhBEyU", publishedDate: "2026-09-26" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-24"
  },
  {
    id: "single-080",
    title: "【Melatonin】リズムゲーム初心者ぷりん・らら・もーど見参‼🍮💌",
    streamer: "ぷりん・らら・もーど",
    game: "Melatonin",
    genre: "other",
    format: "single",
    videos: [
      { title: "【Melatonin】リズムゲーム初心者ぷりん・らら・もーど見参‼🍮💌【ぷりん・らら・もーど / にじさんじ】", url: "https://www.youtube.com/watch?v=cRktz3VVLyE", publishedDate: "2026-10-01" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-24"
  },
  {
    id: "single-081",
    title: "【ピクミン２】完全初見！今まで見たことなかった紫な子と白い子どんな子なんだ⁉ぷりんとおともだちになってほしすぎる～💖🍮💌",
    streamer: "ぷりん・らら・もーど",
    game: "ピクミン2",
    genre: "action",
    format: "single",
    videos: [
      { title: "【ピクミン２】完全初見！今まで見たことなかった紫な子と白い子どんな子なんだ⁉ぷりんとおともだちになってほしすぎる～💖🍮💌【ぷりん・らら・もーど / にじさんじ】", url: "https://www.youtube.com/watch?v=_Mc5o0HNmGc", publishedDate: "2026-10-24" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-24"
  },
  {
    id: "single-082",
    title: "【 ファミレスを享受せよ 】ファミレスで駄弁ってたあの青春よ、永遠に……",
    streamer: "ぽめろ・ぱんち",
    game: "ファミレスを享受せよ",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【 ファミレスを享受せよ 】ファミレスで駄弁ってたあの青春よ、永遠に……【ぽめろ・ぱんち / にじさんじ】", url: "https://www.youtube.com/watch?v=bboVYS9ifJM", publishedDate: "2026-10-16" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-24"
  },
  {
    id: "single-083",
    title: "【 Shadowverse: Worlds Beyond 】本日はドラゴン",
    streamer: "ルンルン",
    game: "Shadowverse: Worlds Beyond",
    genre: "other",
    format: "single",
    videos: [
      { title: "【 Shadowverse: Worlds Beyond 】本日はドラゴン【ルンルン/にじさんじ】", url: "https://www.youtube.com/watch?v=fqF2kPXzE4g", publishedDate: "2026-09-25" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-24"
  },
  {
    id: "single-084",
    title: "【Slay the Spire 2】鬼久々まったりスレスパ",
    streamer: "レイン・パターソン",
    game: "Slay the Spire 2",
    genre: "other",
    format: "single",
    videos: [
      { title: "【Slay the Spire 2】鬼久々まったりスレスパ【レイン・パターソン/にじさんじ】", url: "https://www.youtube.com/watch?v=qpc1Xqgi2cs", publishedDate: "2026-10-02" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-24"
  },
  {
    id: "single-085",
    title: "【Unpacking】ちる～く引っ越し整理する",
    streamer: "レオス・ヴィンセント",
    game: "Unpacking",
    genre: "puzzle",
    format: "single",
    videos: [
      { title: "【Unpacking】ちる～く引っ越し整理する【レオス・ヴィンセント/にじさんじ】", url: "https://www.youtube.com/watch?v=O3eJlAHC3_w", publishedDate: "2026-10-12" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-24"
  },
  {
    id: "single-086",
    title: "【 アークナイツ：エンドフィールド 】スーが来たぞおおおおおお！！！！",
    streamer: "伊波ライ",
    game: "アークナイツ：エンドフィールド",
    genre: "rpg",
    format: "single",
    videos: [
      { title: "【 アークナイツ：エンドフィールド 】スーが来たぞおおおおおお！！！！【 伊波ライ / にじさんじ 】", url: "https://www.youtube.com/watch?v=pxhtCaIsIDM", publishedDate: "2026-10-21" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-24"
  },
  {
    id: "single-087",
    title: "【スーパーマリオサンシャイン】泣き言は聞きたくない。",
    streamer: "一ノ瀬うるは",
    game: "スーパーマリオサンシャイン",
    genre: "action",
    format: "single",
    videos: [
      { title: "【スーパーマリオサンシャイン】泣き言は聞きたくない。【ぶいすぽ/一ノ瀬うるは】", url: "https://www.youtube.com/watch?v=mHxcoFfUEzc", publishedDate: "2026-09-25" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-24"
  },
  {
    id: "single-088",
    title: "【SuperBunnyMan】ずっとやりたくてあたためていたが我慢できないのでソロ",
    streamer: "宇佐美リト",
    game: "Super Bunny Man",
    genre: "action",
    format: "single",
    videos: [
      { title: "【SuperBunnyMan】ずっとやりたくてあたためていたが我慢できないのでソロ【宇佐美リト/にじさんじ】", url: "https://www.youtube.com/watch?v=4_fXEIFTCVE", publishedDate: "2026-09-30" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-24"
  },
  {
    id: "single-089",
    title: "【Lethal Company】８人でゴミ拾い会社就職",
    streamer: "英リサ",
    game: "Lethal Company",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【Lethal Company】８人でゴミ拾い会社就職【ぶいすぽっ！/英リサ】", url: "https://www.youtube.com/watch?v=cXR7ZitMJNQ", publishedDate: "2026-10-10" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-24"
  },
  {
    id: "single-090",
    title: "【REPO】久々におバカなやつらとのREPOが帰ってきた",
    streamer: "花芽なずな",
    game: "R.E.P.O.",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【REPO】久々におバカなやつらとのREPOが帰ってきた【ぶいすぽ/花芽なずな】", url: "https://www.youtube.com/watch?v=Td1knDZkWKE", publishedDate: "2026-10-06" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-24"
  },
  {
    id: "single-091",
    title: "【Teamfight Tactics】たぬふぁい本番Dチーム！大会四連覇する。",
    streamer: "空澄セナ",
    game: "Teamfight Tactics",
    genre: "other",
    format: "single",
    videos: [
      { title: "【Teamfight Tactics】たぬふぁい本番Dチーム！大会四連覇する。【空澄セナ/ぶいすぽっ！】", url: "https://www.youtube.com/watch?v=1MSAb0Opz90", publishedDate: "2026-10-01" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-24"
  },
  {
    id: "single-092",
    title: "【雀魂】天開塾！え、わたしって押しすぎ……？/w 天開司",
    streamer: "健屋花那",
    game: "雀魂",
    genre: "other",
    format: "single",
    videos: [
      { title: "【雀魂】天開塾！え、わたしって押しすぎ……？/w 天開司【健屋花那/にじさんじ】", url: "https://www.youtube.com/watch?v=sVdcrnNI_k4", publishedDate: "2026-10-16" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-24"
  },
  {
    id: "single-093",
    title: "【めっちゃカメレオン】＃謎いつメン でめっちゃカメレオンやるのだ",
    streamer: "黒井しば",
    game: "めっちゃカメレオン",
    genre: "other",
    format: "single",
    videos: [
      { title: "【めっちゃカメレオン】＃謎いつメン でめっちゃカメレオンやるのだ【黒井しば視点】", url: "https://www.youtube.com/watch?v=Oto21fMWj70", publishedDate: "2026-10-08" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-24"
  },
  {
    id: "single-094",
    title: "【デュエプレ】第37弾「虹帝∞命動」　～天門！天門！天門！～",
    streamer: "榊ネス",
    game: "デュエル・マスターズ プレイス",
    genre: "other",
    format: "single",
    videos: [
      { title: "【デュエプレ】第37弾「虹帝∞命動」　～天門！天門！天門！～【榊ネス/にじさんじ】", url: "https://www.youtube.com/watch?v=eES6gHnublI", publishedDate: "2026-10-05" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-24"
  },
  {
    id: "single-095",
    title: "【PEAK】にじSSS ～再び頂を目指して～",
    streamer: "榊ネス",
    game: "PEAK",
    genre: "action",
    format: "single",
    videos: [
      { title: "【PEAK】にじSSS ～再び頂を目指して～【榊ネス/にじさんじ】", url: "https://www.youtube.com/watch?v=DU8a_w55Kbg", publishedDate: "2026-10-06" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-24"
  },
  {
    id: "single-096",
    title: "【Pokémon Champions】サカキなのであく統一パでランクに挑戦します",
    streamer: "榊ネス",
    game: "Pokémon Champions",
    genre: "other",
    format: "single",
    videos: [
      { title: "【Pokémon Champions】サカキなのであく統一パでランクに挑戦します【榊ネス/にじさんじ】", url: "https://www.youtube.com/watch?v=SZNTfJESBXc", publishedDate: "2026-10-15" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-24"
  },
  {
    id: "single-097",
    title: "【ファミレスを享受せよ】チルくて素晴らしい音楽があるらしい",
    streamer: "山田龍一郎",
    game: "ファミレスを享受せよ",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【ファミレスを享受せよ】チルくて素晴らしい音楽があるらしい【にじさんじ / 山田龍一郎】", url: "https://www.youtube.com/watch?v=HaPZ9Zx07-E", publishedDate: "2026-10-04" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-24"
  },
  {
    id: "single-098",
    title: "【 めっちゃカメレオン 】#ふぃことりすた のみんなとめちゃカメ🎨 七瀬視点",
    streamer: "七瀬すず菜",
    game: "めっちゃカメレオン",
    genre: "other",
    format: "single",
    videos: [
      { title: "【 めっちゃカメレオン 】#ふぃことりすた のみんなとめちゃカメ🎨 七瀬視点【 七瀬すず菜 /にじさんじ】", url: "https://www.youtube.com/watch?v=5iCeP_5jiys", publishedDate: "2026-09-26" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-24"
  },
  {
    id: "single-099",
    title: "【めっちゃカメレオン】めっちゃ大好き☆ #謎いつメン",
    streamer: "周央サンゴ",
    game: "めっちゃカメレオン",
    genre: "other",
    format: "single",
    videos: [
      { title: "【めっちゃカメレオン】めっちゃ大好き☆ #謎いつメン 【アンジュ・カトリーナ/黒井しば/社築/周央サンゴ】", url: "https://www.youtube.com/watch?v=v6Q-dh3wVJw", publishedDate: "2026-10-07" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-24"
  },
  {
    id: "single-100",
    title: "【デュエプレ】新弾開封！バラギアラマジ！？",
    streamer: "渚トラウト",
    game: "デュエル・マスターズ プレイス",
    genre: "other",
    format: "single",
    videos: [
      { title: "【デュエプレ】新弾開封！バラギアラマジ！？【渚トラウト/にじさんじ】", url: "https://www.youtube.com/watch?v=ezIO2ASnxfQ", publishedDate: "2026-09-24" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-24"
  },
  {
    id: "single-101",
    title: "【 Lethal Company 】ぶいすぽりーさるかんぱに～",
    streamer: "小雀とと",
    game: "Lethal Company",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【 Lethal Company 】ぶいすぽりーさるかんぱに～【 ぶいすぽ / 小雀とと 】", url: "https://www.youtube.com/watch?v=C8P_hvyCci0", publishedDate: "2026-10-10" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-24"
  },
  {
    id: "single-102",
    title: "【PowerWash Simulator 2】久々寝るか！「赤城ウェンの寝る時間ですよ！」",
    streamer: "赤城ウェン",
    game: "PowerWash Simulator2",
    genre: "sim",
    format: "single",
    videos: [
      { title: "【PowerWash Simulator 2】久々寝るか！「赤城ウェンの寝る時間ですよ！」【赤城ウェン/にじさんじ】", url: "https://www.youtube.com/watch?v=lJQCPnspi6E", publishedDate: "2026-10-24" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-24"
  },
  {
    id: "single-103",
    title: "【APEX】きゃわいい後輩ずと昼えぺ！w/ぱたち、あゆゆ",
    streamer: "雪城眞尋",
    game: "Apex Legends",
    genre: "fps",
    format: "single",
    videos: [
      { title: "【APEX】きゃわいい後輩ずと昼えぺ！w/ぱたち、あゆゆ【雪城眞尋/にじさんじ】", url: "https://www.youtube.com/watch?v=rp9hmGvPoNw", publishedDate: "2026-10-01" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-24"
  },
  {
    id: "single-104",
    title: "【 スイカゲーム 】みどり髪と黒髪でスイカな２人🍉話しながらまったり遊ぶ w/ 十河ののは先輩",
    streamer: "千凛あゆむ",
    game: "スイカゲーム",
    genre: "puzzle",
    format: "single",
    videos: [
      { title: "【 スイカゲーム 】みどり髪と黒髪でスイカな２人🍉話しながらまったり遊ぶ w/ 十河ののは先輩【にじさんじ / 千凛あゆむ】", url: "https://www.youtube.com/watch?v=WQ5g1n70E2o", publishedDate: "2026-10-01" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-24"
  },
  {
    id: "single-105",
    title: "【 メグとばけもの 】泣くほど感動するRPG。感情移入しちゃうタイプだけど大丈夫かな？",
    streamer: "千凛あゆむ",
    game: "メグとばけもの",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【 メグとばけもの 】泣くほど感動するRPG。感情移入しちゃうタイプだけど大丈夫かな？【にじさんじ / 千凛あゆむ】", url: "https://www.youtube.com/watch?v=qB6AsleBy8s", publishedDate: "2026-10-12" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-24"
  },
  {
    id: "single-106",
    title: "【 スプラトゥーン3 】スプラ元1億2297万2528位  w/ 倉持めると先輩 綺沙良先輩 早乙女ベリー先輩",
    streamer: "千凛あゆむ",
    game: "スプラトゥーン3",
    genre: "fps",
    format: "single",
    videos: [
      { title: "【 スプラトゥーン3 】スプラ元1億2297万2528位  w/ 倉持めると先輩 綺沙良先輩 早乙女ベリー先輩　【にじさんじ / 千凛あゆむ】", url: "https://www.youtube.com/watch?v=8IDzKZUO8gU", publishedDate: "2026-10-18" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-24"
  },
  {
    id: "single-107",
    title: "【ゼルダの伝説 ティアーズ オブ ザ キングダム】#last ｺｺ完全初見🔰時を超えてガノンドロフを討ち取るぞ！！！",
    streamer: "倉持めると",
    game: "ゼルダの伝説 ティアーズ オブ ザ キングダム",
    genre: "action",
    format: "single",
    videos: [
      { title: "【ゼルダの伝説 ティアーズ オブ ザ キングダム】#last ｺｺ完全初見🔰時を超えてガノンドロフを討ち取るぞ！！！【倉持めると/にじさんじ】", url: "https://www.youtube.com/watch?v=8GHanfm6Mlk", publishedDate: "2026-09-24" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-24"
  },
  {
    id: "single-108",
    title: "【アソビ大全】そーまとアソビ大全でバトル！！",
    streamer: "早乙女ベリー",
    game: "世界のアソビ大全51",
    genre: "other",
    format: "single",
    videos: [
      { title: "【アソビ大全】そーまとアソビ大全でバトル！！早乙女ベリー/ 酒寄颯馬/にじさんじ】", url: "https://www.youtube.com/watch?v=GM9gim11SGo", publishedDate: "2026-10-08" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-24"
  },
  {
    id: "single-109",
    title: "【APEX】なんか流行ってるらしいじゃん",
    streamer: "長尾景",
    game: "Apex Legends",
    genre: "fps",
    format: "single",
    videos: [
      { title: "【APEX】なんか流行ってるらしいじゃん【長尾景/にじさんじ】", url: "https://www.youtube.com/watch?v=uVcpbemMuTo", publishedDate: "2026-09-27" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-24"
  },
  {
    id: "single-110",
    title: "【マイクラ】にじ鯖でおにごっこ！？！？",
    streamer: "長尾景",
    game: "Minecraft",
    genre: "sandbox",
    format: "single",
    videos: [
      { title: "【マイクラ】にじ鯖でおにごっこ！？？【長尾景/にじさんじ】#にじクラおにごっこ", url: "https://www.youtube.com/watch?v=ZDtH5XKQKGo", publishedDate: "2026-10-13" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-24"
  },
  {
    id: "single-111",
    title: "【Lethal Company】大人数でゴミ集め",
    streamer: "兎咲ミミ",
    game: "Lethal Company",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【Lethal Company】大人数でゴミ集め【ぶいすぽ/兎咲ミミ】", url: "https://www.youtube.com/watch?v=I1uC1LS3MjI", publishedDate: "2026-10-10" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-24"
  },
  {
    id: "single-112",
    title: "【Lethal Company】ぶいすぽメンバーとゴミ拾いに行きます",
    streamer: "猫汰つな",
    game: "Lethal Company",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【Lethal Company】ぶいすぽメンバーとゴミ拾いに行きます【ぶいすぽ / 猫汰つな】", url: "https://www.youtube.com/watch?v=2O5DPB_ZyrA", publishedDate: "2026-10-09" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-24"
  },
  {
    id: "single-113",
    title: "【リズム天国 ミラクルスターズ】久々リズ天🎶全部のメダルとＰがほしい🎶ステージ15から🎶",
    streamer: "白砂あやね",
    game: "リズム天国 ミラクルスターズ",
    genre: "other",
    format: "single",
    videos: [
      { title: "【リズム天国 ミラクルスターズ】久々リズ天🎶全部のメダルとＰがほしい🎶ステージ15から🎶【 白砂あやね / にじさんじ 】", url: "https://www.youtube.com/watch?v=aY_xMHW2liA", publishedDate: "2026-10-01" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-24"
  },
  {
    id: "single-114",
    title: "【めっちゃカメレオン】#ふぃことりすた 🐤⭐️のみんなと色塗りかくれんぼ！",
    streamer: "立伝都々",
    game: "めっちゃカメレオン",
    genre: "other",
    format: "single",
    videos: [
      { title: "【めっちゃカメレオン】#ふぃことりすた 🐤⭐️のみんなと色塗りかくれんぼ！【立伝都々視点/にじさんじ】", url: "https://www.youtube.com/watch?v=xbShYtX72SE", publishedDate: "2026-09-26" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-24"
  },
  {
    id: "single-115",
    title: "【NieR:Automata】消すか壊すか、残酷な2択",
    streamer: "鈴原るる",
    game: "NieR:Automata",
    genre: "rpg",
    format: "single",
    videos: [
      { title: "【NieR:Automata】消すか壊すか、残酷な2択【にじさんじ/鈴原るる】", url: "https://www.youtube.com/watch?v=CQn1dLr6xy0", publishedDate: "2026-10-21" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-24"
  },
  {
    id: "single-116",
    title: "【 Super Bunny Man 】 初コラボ！ツクリさんと遊ぶぞ～～！",
    streamer: "蝸堂みかる",
    game: "Super Bunny Man",
    genre: "action",
    format: "single",
    videos: [
      { title: "【 Super Bunny Man 】 初コラボ！ツクリさんと遊ぶぞ～～！ 【 にじさんじ 蝸堂みかる / ミリプロ 眠雲ツクリ 】", url: "https://www.youtube.com/watch?v=lunYpkVdYEU", publishedDate: "2026-10-09" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-24"
  },
  {
    id: "single-117",
    title: "【 レーシングマスター  】　深夜ドライブってこと？？？！？！！！！！！！！！！",
    streamer: "蝶屋はなび",
    game: "レーシングマスター",
    genre: "racing",
    format: "single",
    videos: [
      { title: "【 レーシングマスター  】　深夜ドライブってこと？？？！？！！！！！！！！！！　【 ぶいすぽっ！ ⁠/蝶屋はなび 】", url: "https://www.youtube.com/watch?v=sVdyKycu7eU", publishedDate: "2026-10-24" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-26"
  },
  {
    id: "single-118",
    title: "【 R.E.P.O. 】仕事帰りにはやっぱりREPOだよな～～🥂✨",
    streamer: "角巻わため",
    game: "R.E.P.O.",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【 R.E.P.O. 】仕事帰りにはやっぱりREPOだよな～～🥂✨【角巻わため/ホロライブ４期生】", url: "https://www.youtube.com/watch?v=83F3kMuhy1M", publishedDate: "2026-10-23" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-26"
  },
  {
    id: "single-119",
    title: "【  Unpacking 】　早起きしたから片付けでもするか！！！！！！！！！",
    streamer: "蝶屋はなび",
    game: "Unpacking",
    genre: "puzzle",
    format: "single",
    videos: [
      { title: "【  Unpacking 】　早起きしたから片付けでもするか！！！！！！！！！　【 ぶいすぽっ！ ⁠/蝶屋はなび 】", url: "https://www.youtube.com/watch?v=m4otrIjv5ZY", publishedDate: "2026-10-22" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-26"
  },
  {
    id: "single-120",
    title: "【アークナイツ】戦闘システムが好き！アークナイツの世界に帰還！初配信～！",
    streamer: "尾丸ポルカ",
    game: "アークナイツ",
    genre: "sim",
    format: "single",
    videos: [
      { title: "【アークナイツ】戦闘システムが好き！アークナイツの世界に帰還！初配信～！【尾丸ポルカ/ホロライブ】", url: "https://www.youtube.com/watch?v=CI5KKwUfKtM", publishedDate: "2026-10-20" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-26"
  },
  {
    id: "single-121",
    title: "【  R.E.P.O. 】　ストリヌで出会った本仲間たちとお金稼ぐぞおおおお！！！！！！！！！w/そあら／ゾム／ショッピ／ひょう太朗／シヴァ",
    streamer: "蝶屋はなび",
    game: "R.E.P.O.",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【  R.E.P.O. 】　ストリヌで出会った本仲間たちとお金稼ぐぞおおおお！！！！！！！！！w/そあら／ゾム／ショッピ／ひょう太朗／シヴァ　【 ぶいすぽっ！ ⁠/蝶屋はなび 】", url: "https://www.youtube.com/watch?v=5GwuQx9fqJk", publishedDate: "2026-10-15" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-26"
  },
  {
    id: "single-122",
    title: "【 Lethal Company 】　ぶいすぽメンバーと大人数MODいれてあそぶぞおおお！！！",
    streamer: "蝶屋はなび",
    game: "Lethal Company",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【 Lethal Company 】　ぶいすぽメンバーと大人数MODいれてあそぶぞおおお！！！　【 ぶいすぽっ！ ⁠/蝶屋はなび 】", url: "https://www.youtube.com/watch?v=flmx5U-oIhk", publishedDate: "2026-10-10" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-26"
  },
  {
    id: "single-123",
    title: "【Lethal Company】ぶいすぽゴミ拾い部始動!!",
    streamer: "銀城サイネ",
    game: "Lethal Company",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【Lethal Company】ぶいすぽゴミ拾い部始動!!【ぶいすぽっ！ #銀城サイネ 】", url: "https://www.youtube.com/watch?v=yn0a9LFg3UI", publishedDate: "2026-10-10" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-26"
  },
  {
    id: "single-124",
    title: "【 Euro Truck Simulator 2 】　乗ってけ（免許なし）（サムネはあくまで未来）！！！！！！！",
    streamer: "蝶屋はなび",
    game: "Euro Truck Simulator 2",
    genre: "sim",
    format: "single",
    videos: [
      { title: "【 Euro Truck Simulator 2 】　乗ってけ（免許なし）（サムネはあくまで未来）！！！！！！！　【 ぶいすぽっ！ ⁠/蝶屋はなび 】", url: "https://www.youtube.com/watch?v=KvBiY7Bx-6c", publishedDate: "2026-09-28" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-26"
  }
];
