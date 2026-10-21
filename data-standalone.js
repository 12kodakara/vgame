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
    format: "single",
    videos: [
      { title: "【鳴潮】ストーリーとガチャいくぞ！！【ホロライブ/夏色まつり】", url: "https://www.youtube.com/watch?v=oIDOMuxSz8I", publishedDate: "2026-09-30" }
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
      { title: "🚀共同探検23 01 | No Man's Sky【静凛/にじさんじ】", url: "https://www.youtube.com/watch?v=sqxAKcovqtU", publishedDate: "2026-10-18" }
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
      { title: "【ELDEN RING/エルデンリング】竜の力で王になる  #5【にじさんじ/卯月コウ】", url: "https://www.youtube.com/watch?v=kPRq0aJiQy8", publishedDate: "2026-10-18" }
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
  }
];
