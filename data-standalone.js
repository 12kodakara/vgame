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
 * 同じVTuber×ゲームの再生リストが登録済みでも、別シリーズの実況は例外として登録できる(個別指定のみ。validate-data.ps1 が検証する):
 *   separateSeriesFrom(再生リストid・複数はカンマ区切り) / separateSeriesReason(理由) / playlistCheckedAt(YYYY-MM-DD。再生リストに対象動画が無いと確認した日)
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
    format: "multi",
    videos: [
      { title: "【GeoGuessr】なぜか場所特定が得意なのじゃ…【ホロライブ/アソビ★まわり隊！/熱千めら】", url: "https://www.youtube.com/watch?v=z_ZP9E7qJc4", publishedDate: "2026-09-27" },
      { title: "電柱ソムリエの一歩も動かないGeoGuessr【ホロライブ/熱千めら】", url: "https://www.youtube.com/watch?v=0PgUff6IQ-Y", publishedDate: "2026-10-25" }
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
    format: "multi",
    videos: [
      { title: "【壺おじ】目指すんだ…！圧倒的高み…ッ！！【百灯キョーコ/ホロライブ/アソビ★まわり隊！】", url: "https://www.youtube.com/watch?v=ai5tJOVZwUU", publishedDate: "2026-09-28" },
      { title: "【壺おじ】シーズン２、遂に解禁【百灯キョーコ/ホロライブ/アソビ★まわり隊！】", url: "https://www.youtube.com/watch?v=yLNe1445sNs", publishedDate: "2026-10-29" }
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
    format: "multi",
    videos: [
      { title: "【EN】First time playing Five Nights at Freddy's!! | FNAF【Hyakuto Kyoko/Hololive】", url: "https://www.youtube.com/watch?v=UoDgaiOpxIw", publishedDate: "2026-10-17" },
      { title: "【EN】I'm back at Five Nights at Freddy's!! | FNAF【Hyakuto Kyoko/Hololive】", url: "https://www.youtube.com/watch?v=hgqohSU3vpg", publishedDate: "2026-10-20" },
      { title: "【EN】I’m gonna become a FNAF master!!  | Five Nights at Freddy's 2【Hyakuto Kyoko/Hololive】", url: "https://www.youtube.com/watch?v=Zrchcy1PtV0", publishedDate: "2026-10-23" }
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
      { title: "【EN】#4 Can I finish the 2nd Isle today? | Cuphead【Hyakuto Kyoko/Hololive】", url: "https://www.youtube.com/watch?v=CVsPXWqiD8k", publishedDate: "2026-10-16" },
      { title: "【EN】#5 YAY!! I made it to the 3rd Isle!! | Cuphead【Hyakuto Kyoko/Hololive】", url: "https://www.youtube.com/watch?v=HhcEbmmIkFY", publishedDate: "2026-10-22" },
      { title: "【EN】#6 YAY!! I made it to the 3rd Isle!! | Cuphead【Hyakuto Kyoko/Hololive】", url: "https://www.youtube.com/watch?v=FLSPXynYTJ0", publishedDate: "2026-10-26" },
      { title: "【EN】#7 WHO IS LEFT!? I'M COMING FOR YOU!!!! | Cuphead【Hyakuto Kyoko/Hololive】", url: "https://www.youtube.com/watch?v=kYxfR1beO4o", publishedDate: "2026-10-31" }
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
      { title: "VALORANT イモータルを目指す!! 　#４【鈴鳴つづり/ホロライブ/アソビ★まわり隊！】 #ホロライブ #アソビまわり隊  #つづり配達中", url: "https://www.youtube.com/watch?v=ZspvK4EGpWY", publishedDate: "2026-10-16" },
      { title: "VALORANT イモータルを目指す!! #５　【鈴鳴つづり/ホロライブ/アソビ★まわり隊！】 #ホロライブ #アソビまわり隊  #つづり配達中", url: "https://www.youtube.com/watch?v=aAAvIiof87M", publishedDate: "2026-10-24" },
      { title: "VALORANT 先行体験！！新キャラ(HUSH)をお試しで使います...!!!　【鈴鳴つづり/ホロライブ/アソビ★まわり隊！】 #ホロライブ #アソビまわり隊  #つづり配達中", url: "https://www.youtube.com/watch?v=zpOdryzEx00", publishedDate: "2026-10-27" }
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
      { title: "#3 深まる謎も、全部解き明かすよーー！！！ | 都市伝説解体センター　※ネタバレ注意【百灯キョーコ/ホロライブ/アソビ★まわり隊！】", url: "https://www.youtube.com/watch?v=yaGBdBwtvWA", publishedDate: "2026-10-18" },
      { title: "#4 審判の日が近づく！？今回も謎をガンガン解いてこーー！！！ | 都市伝説解体センター　※ネタバレ注意【百灯キョーコ/ホロライブ/アソビ★まわり隊！】", url: "https://www.youtube.com/watch?v=BtIXGeBO2dU", publishedDate: "2026-10-26" }
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
  },
  {
    id: "single-125",
    title: "【MINECRAFT】FLYING HIGH WITH CREATE AERONAUTICS WITH YAMINO-KUN",
    streamer: "Luca Kaneshiro",
    game: "Minecraft",
    genre: "sandbox",
    format: "single",
    videos: [
      { title: "【MINECRAFT】FLYING HIGH WITH CREATE AERONAUTICS WITH YAMINO-KUN【 #lucakaneshiro #nijisanji_en 】", url: "https://www.youtube.com/watch?v=ByRVWHxNg7E", publishedDate: "2026-10-23" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-26"
  },
  {
    id: "single-126",
    title: "【MINECRAFT】  my f-f-f-first time on StellarCraft! 😳",
    streamer: "青月レミア",
    game: "Minecraft",
    genre: "sandbox",
    format: "single",
    videos: [
      { title: "【MINECRAFT】  my f-f-f-first time on StellarCraft! 😳【#VSPOEN #RemiaAotsuki】", url: "https://www.youtube.com/watch?v=UGaNZi9t-jM", publishedDate: "2026-10-22" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-26"
  },
  {
    id: "single-127",
    title: "Finding my way with Uki!【WE WERE HERE FOREVER】",
    streamer: "Vantacrow Bringer",
    game: "We Were Here Forever",
    genre: "puzzle",
    format: "single",
    videos: [
      { title: "Finding my way with Uki!【WE WERE HERE FOREVER】", url: "https://www.youtube.com/watch?v=03SYBzosMVY", publishedDate: "2026-10-21" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-26"
  },
  {
    id: "single-128",
    title: "【WE WERE HERE FOREVER】psycrow is back, but we're trapped 🐦‍⬛💜",
    streamer: "Uki Violeta",
    game: "We Were Here Forever",
    genre: "puzzle",
    format: "single",
    videos: [
      { title: "【WE WERE HERE FOREVER】psycrow is back, but we're trapped 🐦‍⬛💜", url: "https://www.youtube.com/watch?v=0yLuKR-CeSQ", publishedDate: "2026-10-21" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-26"
  },
  {
    id: "single-129",
    title: "【DETROIT: BECOME HUMAN】67 STAB WOUNDS WITH @holoen_ceciliaimmergreen",
    streamer: "Koseki Bijou",
    game: "Detroit: Become Human",
    genre: "other",
    format: "single",
    videos: [
      { title: "【DETROIT: BECOME HUMAN】67 STAB WOUNDS WITH @holoen_ceciliaimmergreen", url: "https://www.youtube.com/watch?v=Yn624nnrVNQ", publishedDate: "2026-10-20" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-26"
  },
  {
    id: "single-130",
    title: "Chopcon takes on PUBG. WINNER WINNER CHICKEN DINNER TIME |  [PUBG: BATTLEGROUNDS]",
    streamer: "Ryoma Barrenwort",
    game: "PUBG: BATTLEGROUNDS",
    genre: "fps",
    format: "single",
    videos: [
      { title: "Chopcon takes on PUBG. WINNER WINNER CHICKEN DINNER TIME |  [PUBG: BATTLEGROUNDS]", url: "https://www.youtube.com/watch?v=hJ7YuZCzWtg", publishedDate: "2026-10-19" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-26"
  },
  {
    id: "single-131",
    title: "【OVERWATCH】   international girl squad rank demons 😈",
    streamer: "青月レミア",
    game: "Overwatch",
    genre: "fps",
    format: "single",
    videos: [
      { title: "【OVERWATCH】   international girl squad rank demons 😈 【#VSPOEN #RemiaAotsuki】", url: "https://www.youtube.com/watch?v=AKmiLNWeGCE", publishedDate: "2026-10-18" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-26"
  },
  {
    id: "single-132",
    title: "【Super Bunny Man】With My Beloved Riri-senpai!",
    streamer: "Klara Charmwood",
    game: "Super Bunny Man",
    genre: "action",
    format: "single",
    videos: [
      { title: "【Super Bunny Man】With My Beloved Riri-senpai!【NIJISANJI EN | Klara Charmwood】", url: "https://www.youtube.com/watch?v=ozjtvjOk_x4", publishedDate: "2026-10-16" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-26"
  },
  {
    id: "single-133",
    title: "【LEAGUE OF LEGENDS】WITH MORI CALLIOPE!! (REAL)(NOTCLICKBAIT) + ANNOUNCEMENT",
    streamer: "Gigi Murin",
    game: "League of Legends",
    genre: "other",
    format: "single",
    videos: [
      { title: "【LEAGUE OF LEGENDS】WITH MORI CALLIOPE!! (REAL)(NOTCLICKBAIT) + ANNOUNCEMENT", url: "https://www.youtube.com/watch?v=w13xqPC1h1g", publishedDate: "2026-10-15" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-26"
  },
  {
    id: "single-134",
    title: "Camping with KRISISIS!【SONS OF THE FOREST】",
    streamer: "Vantacrow Bringer",
    game: "Sons of the Forest",
    genre: "sandbox",
    format: "single",
    videos: [
      { title: "Camping with KRISISIS!【SONS OF THE FOREST】", url: "https://www.youtube.com/watch?v=h9Vz4bbwNKQ", publishedDate: "2026-10-13" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-26"
  },
  {
    id: "single-135",
    title: "【Sons of the Forest】Krisisis in an abandoned forest... or is it?",
    streamer: "Vezalius Bandage",
    game: "Sons of the Forest",
    genre: "sandbox",
    format: "single",
    videos: [
      { title: "【Sons of the Forest】Krisisis in an abandoned forest... or is it?【NIJISANJI EN | Vezalius Bandage】", url: "https://www.youtube.com/watch?v=WNbJBoIA9uQ", publishedDate: "2026-10-13" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-26"
  },
  {
    id: "single-136",
    title: "【Vampire Survivors】 Here It Comes",
    streamer: "Zeal Ginjoka",
    game: "Vampire Survivors",
    genre: "action",
    format: "single",
    videos: [
      { title: "【Vampire Survivors】 Here It Comes 【NIJISANJI EN | Zeal Ginjoka】", url: "https://www.youtube.com/watch?v=dhy3jYFXzAQ", publishedDate: "2026-10-13" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-26"
  },
  {
    id: "single-137",
    title: "【VALORANT】  EU CS2 player tries edating..",
    streamer: "青月レミア",
    game: "VALORANT",
    genre: "fps",
    format: "single",
    videos: [
      { title: "【VALORANT】  EU CS2 player tries edating.. 【#VSPOEN #RemiaAotsuki】", url: "https://www.youtube.com/watch?v=yklAo9pHOio", publishedDate: "2026-10-13" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-26"
  },
  {
    id: "single-138",
    title: "【FINAL FANTASY XIV】LEEEEEEEEETS GO FISHINGGGGGG #ad",
    streamer: "Gigi Murin",
    game: "FINAL FANTASY XIV",
    genre: "rpg",
    format: "single",
    videos: [
      { title: "【FINAL FANTASY XIV】LEEEEEEEEETS GO FISHINGGGGGG #ad", url: "https://www.youtube.com/watch?v=UIx1lScM4IU", publishedDate: "2026-10-12" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-26"
  },
  {
    id: "single-139",
    title: "【VAMPIRE SURVIVORS】6 LIVES SHOULD BE ENOUGH, RIGHT?",
    streamer: "Raora Panthera",
    game: "Vampire Survivors",
    genre: "action",
    format: "single",
    videos: [
      { title: "【VAMPIRE SURVIVORS】6 LIVES SHOULD BE ENOUGH, RIGHT?", url: "https://www.youtube.com/watch?v=M_-a09BBegM", publishedDate: "2026-10-11" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-26"
  },
  {
    id: "single-140",
    title: "【AMONG US】TAG COLLAB YEY",
    streamer: "Millie Parfait",
    game: "Among Us",
    genre: "other",
    format: "single",
    videos: [
      { title: "【AMONG US】TAG COLLAB YEY", url: "https://www.youtube.com/watch?v=T-ie3HbKgXo", publishedDate: "2026-10-08" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-26"
  },
  {
    id: "single-141",
    title: "【UNO】dos, tres",
    streamer: "Vestia Zeta",
    game: "UNO",
    genre: "other",
    format: "single",
    videos: [
      { title: "【UNO】dos, tres", url: "https://www.youtube.com/watch?v=_Dl6Vu1L3kw", publishedDate: "2026-10-08" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-26"
  },
  {
    id: "single-142",
    title: "【PEAK】にじSSS三人、仲間パワーで山登りリベンジ！！！",
    streamer: "Klara Charmwood",
    game: "PEAK",
    genre: "action",
    format: "single",
    videos: [
      { title: "【PEAK】にじSSS三人、仲間パワーで山登りリベンジ！！！【NIJISANJI EN | Klara Charmwood】", url: "https://www.youtube.com/watch?v=EUZPAl46ACs", publishedDate: "2026-10-06" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-26"
  },
  {
    id: "single-143",
    title: "【MINECRAFT】I'M NOT SCARED! TEST OF COURAGE 2026! #マイクラ肝試し2026",
    streamer: "Gigi Murin",
    game: "Minecraft",
    genre: "sandbox",
    format: "single",
    videos: [
      { title: "【MINECRAFT】I'M NOT SCARED! TEST OF COURAGE 2026! #マイクラ肝試し2026", url: "https://www.youtube.com/watch?v=C1WvGkD8Zfo", publishedDate: "2026-10-03" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-26"
  },
  {
    id: "single-144",
    title: "【R.E.P.O.】 my friends are my power to get over these CRAMPS",
    streamer: "Elira Pendora",
    game: "R.E.P.O.",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【R.E.P.O.】 my friends are my power to get over these CRAMPS 【NIJISANJI EN | Elira Pendora】", url: "https://www.youtube.com/watch?v=aVV_7fdXxNo", publishedDate: "2026-10-03" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-26"
  },
  {
    id: "single-145",
    title: "【REPO】 Experiencing the new game updates! [Collab] Ft. Elira, Millie, Uki, Wilson & Zeal",
    streamer: "Finana Ryugu",
    game: "R.E.P.O.",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【REPO】 Experiencing the new game updates! [Collab] Ft. Elira, Millie, Uki, Wilson & Zeal", url: "https://www.youtube.com/watch?v=r8p7ygFxjwc", publishedDate: "2026-10-03" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-26"
  },
  {
    id: "single-146",
    title: "【R.E.P.O.】no ramen for us 😔",
    streamer: "Uki Violeta",
    game: "R.E.P.O.",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【R.E.P.O.】no ramen for us 😔", url: "https://www.youtube.com/watch?v=ox52wjpRajM", publishedDate: "2026-10-03" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-26"
  },
  {
    id: "single-147",
    title: "【R.E.P.O.】 ft. NijiEN",
    streamer: "Zeal Ginjoka",
    game: "R.E.P.O.",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【R.E.P.O.】 ft. NijiEN 【NIJISANJI EN | Zeal Ginjoka】", url: "https://www.youtube.com/watch?v=hMBaIftWWEo", publishedDate: "2026-10-03" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-26"
  },
  {
    id: "single-148",
    title: "【R.E.P.O.】NO RAMEN SO WE JUST STEAL STUFF",
    streamer: "Millie Parfait",
    game: "R.E.P.O.",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【R.E.P.O.】NO RAMEN SO WE JUST STEAL STUFF", url: "https://www.youtube.com/watch?v=8Wif2Uc2XJs", publishedDate: "2026-10-03" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-26"
  },
  {
    id: "single-149",
    title: "【PEAK】 w/ juno, pan, rpr",
    streamer: "涼上エリス",
    game: "PEAK",
    genre: "action",
    format: "single",
    videos: [
      { title: "【PEAK】 w/ juno, pan, rpr【#VSPOEN #ErisSuzukami 】", url: "https://www.youtube.com/watch?v=RuG-64He1Qk", publishedDate: "2026-09-30" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-26"
  },
  {
    id: "single-150",
    title: "【DEAD BY DAYLIGHT】 surviving 2v8 game mode one last time with Kitten",
    streamer: "Elira Pendora",
    game: "Dead by Daylight",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【DEAD BY DAYLIGHT】 surviving 2v8 game mode one last time with Kitten 【NIJISANJI EN | Elira Pendora】", url: "https://www.youtube.com/watch?v=gVoY6lq0B3I", publishedDate: "2026-09-29" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-26"
  },
  {
    id: "single-151",
    title: "【OVERWATCH】chill(?) sunday rankge",
    streamer: "ソラリリコ",
    game: "Overwatch",
    genre: "fps",
    format: "single",
    videos: [
      { title: "【OVERWATCH】chill(?) sunday rankge【#VSPOEN #RikoSolari】", url: "https://www.youtube.com/watch?v=giumS9mdxpQ", publishedDate: "2026-09-28" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-26"
  },
  {
    id: "single-152",
    title: "【HITMAN】i protec and i also reck 🐾🩵 【FUWAWA SOLO】",
    streamer: "FUWAMOCO",
    game: "HITMAN",
    genre: "action",
    format: "single",
    videos: [
      { title: "【HITMAN】i protec and i also reck 🐾🩵 【FUWAWA SOLO】", url: "https://www.youtube.com/watch?v=uHDGJmhsX7k", publishedDate: "2026-09-27" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-10-26"
  },
  {
    id: "single-153",
    title: "Apex Legends 配信まとめ",
    streamer: "胡桃のあ",
    game: "Apex Legends",
    genre: "fps",
    format: "multi",
    videos: [
      { title: "【 APEX 】モチベ結構あります【 ぶいすぽっ！胡桃のあ 】", url: "https://www.youtube.com/watch?v=Ejxf2jkUNdw", publishedDate: "2026-09-24" },
      { title: "【 APEX 】移動できるキャラに甘えんじゃないよ【 ぶいすぽっ！胡桃のあ 】", url: "https://www.youtube.com/watch?v=PSL_JnxgFHk", publishedDate: "2026-09-25" },
      { title: "【 APEX 】美が呼んでいます【 ぶいすぽっ！胡桃のあ 】", url: "https://www.youtube.com/watch?v=2nz9F90qViE", publishedDate: "2026-09-28" },
      { title: "【 APEX 】私のハートはすべてを見破る。【 ぶいすぽっ！胡桃のあ 】", url: "https://www.youtube.com/watch?v=PhWKT1y71O4", publishedDate: "2026-09-30" },
      { title: "【 APEX 】久しぶりにソロ行ってみるかぁ【 ぶいすぽっ！胡桃のあ 】", url: "https://www.youtube.com/watch?v=HZh3kKEseqM", publishedDate: "2026-10-11" },
      { title: "【 APEX 】今も特に環境はかわらずですか？【 ぶいすぽっ！胡桃のあ 】", url: "https://www.youtube.com/watch?v=uSEPDCBu3pE", publishedDate: "2026-10-19" },
      { title: "【 APEX 】いかないで；；【 ぶいすぽっ！胡桃のあ 】", url: "https://www.youtube.com/watch?v=qmeWbb02TxA", publishedDate: "2026-10-21" },
      { title: "【 APEX 】ソロでもダイヤ２に行きたい！【 ぶいすぽっ！胡桃のあ 】", url: "https://www.youtube.com/watch?v=iN_5lu5pE3U", publishedDate: "2026-10-22" },
      { title: "【 APEX 】ちょっと寝てたけどワールズエッジのために【 ぶいすぽっ！胡桃のあ 】", url: "https://www.youtube.com/watch?v=FjPVM3IqJJI", publishedDate: "2026-10-26" }
    ],
    note: "専用再生リストなし(RSS収集による仮登録。公式再生リストではありません)",
    addedDate: "2026-10-28"
  },
  {
    id: "single-154",
    title: "VALORANT 配信まとめ",
    streamer: "レヨン",
    game: "VALORANT",
    genre: "fps",
    format: "multi",
    videos: [
      { title: "【VALORANT】2日連続valoをやったっていい", url: "https://www.youtube.com/watch?v=iG3DJAPTfuY", publishedDate: "2026-10-01" },
      { title: "【VALORANT】新しいマウスを頂いたので早速使ってみた", url: "https://www.youtube.com/watch?v=39fAQaKhFqE", publishedDate: "2026-10-05" },
      { title: "【VALORANT】新しいマウスに慣れるためにランクですな", url: "https://www.youtube.com/watch?v=k1-r6-p2btk", publishedDate: "2026-10-06" },
      { title: "【VALORANT】今日は歌みたがあがるらしいですな", url: "https://www.youtube.com/watch?v=Idu7jhwQytI", publishedDate: "2026-10-07" },
      { title: "【VALORANT】俺はソロだ。", url: "https://www.youtube.com/watch?v=R6HNd0-9Yh0", publishedDate: "2026-10-08" },
      { title: "【VALORANT】本日まさかの3回配信です", url: "https://www.youtube.com/watch?v=1D5alwRw5rw", publishedDate: "2026-10-11" },
      { title: "【VALORANT】24時を回ればハーフアニバまであと1週間だぜ", url: "https://www.youtube.com/watch?v=nsuqux3_JJE", publishedDate: "2026-10-12" },
      { title: "【VALORANT】今日でシーズンリセットらしい。", url: "https://www.youtube.com/watch?v=AQqpU1WVSUY", publishedDate: "2026-10-14" },
      { title: "【VALORANT】新シーズンが来たらしいな。", url: "https://www.youtube.com/watch?v=KGKb0fJbV-k", publishedDate: "2026-10-16" },
      { title: "【VALORANT】家のトイレが先ほど壊れたって話する？", url: "https://www.youtube.com/watch?v=af_cA8fgR20", publishedDate: "2026-10-23" },
      { title: "【VALORANT】レイナレイナレイナ。", url: "https://www.youtube.com/watch?v=VjvstWtjBQM", publishedDate: "2026-10-24" }
    ],
    note: "専用再生リストなし(RSS収集による仮登録。公式再生リストではありません)",
    addedDate: "2026-10-28"
  },
  {
    id: "single-155",
    title: "【コラボ】アソビ★まわり隊！の４人でR.E.P.Oに挑戦だーーー！！！",
    streamer: "百灯キョーコ",
    game: "R.E.P.O.",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【コラボ】アソビ★まわり隊！の４人でR.E.P.Oに挑戦だーーー！！！【百灯キョーコ/ホロライブ/アソビ★まわり隊！】", url: "https://www.youtube.com/watch?v=pHmyFfovwj8", publishedDate: "2026-10-14" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-11-02"
  },
  {
    id: "single-156",
    title: "ホロライブ新人ユニットがホラゲ「R.E.P.O.」で遊ぶのじゃ",
    streamer: "熱千めら",
    game: "R.E.P.O.",
    genre: "horror",
    format: "single",
    videos: [
      { title: "ホロライブ新人ユニットがホラゲ「R.E.P.O.」で遊ぶのじゃ【アソビ★まわり隊！】", url: "https://www.youtube.com/watch?v=xKhbOWNoYN8", publishedDate: "2026-10-14" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-11-02"
  },
  {
    id: "single-157",
    title: "既プレイなのに反応が初見すぎる「夜勤事件」",
    streamer: "熱千めら",
    game: "夜勤事件",
    genre: "horror",
    format: "single",
    videos: [
      { title: "既プレイなのに反応が初見すぎる「夜勤事件」【ホロライブ/熱千めら】", url: "https://www.youtube.com/watch?v=ZQJkVI2CWq0", publishedDate: "2026-10-23" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-11-02"
  },
  {
    id: "single-158",
    title: "【APEX】　トワ先輩・すいせい先輩と初コラボ！？APEX参ります!!!!!",
    streamer: "鈴鳴つづり",
    game: "Apex Legends",
    genre: "fps",
    format: "single",
    videos: [
      { title: "【APEX】　トワ先輩・すいせい先輩と初コラボ！？APEX参ります!!!!!【鈴鳴つづり/ホロライブ/アソビ★まわり隊！】 #ホロライブ #アソビまわり隊  #つづり配達中", url: "https://www.youtube.com/watch?v=xb1KaLmkaoo", publishedDate: "2026-10-29" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-11-02"
  },
  {
    id: "single-159",
    title: "【R.E.P.O. with アソビ★まわり隊！】博士が幽霊に負けるわけないよねっ！！",
    streamer: "宙科そぴあ",
    game: "R.E.P.O.",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【R.E.P.O. with アソビ★まわり隊！】博士が幽霊に負けるわけないよねっ！！【宙科そぴあ視点/ホロライブ】", url: "https://www.youtube.com/watch?v=cZc0ItF8h44", publishedDate: "2026-10-14" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-11-02"
  },
  {
    id: "single-160",
    title: "【アソビ★まわり隊！】4人で協力アクション、できるのかっ！？",
    streamer: "宙科そぴあ",
    game: "PICO PARK",
    genre: "puzzle",
    format: "single",
    videos: [
      { title: "【アソビ★まわり隊！】4人で協力アクション、できるのかっ！？【PICO PARK/ホロライブ】", url: "https://www.youtube.com/watch?v=m2z1mA9ICSI", publishedDate: "2026-10-20" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-11-02"
  },
  {
    id: "single-161",
    title: "【#ホロ鯖かくれんぼ】ホロメンの先輩とマイクラで かくれんぼっ！",
    streamer: "宙科そぴあ",
    game: "Minecraft",
    genre: "sandbox",
    format: "single",
    videos: [
      { title: "【#ホロ鯖かくれんぼ】ホロメンの先輩とマイクラで かくれんぼっ！【宙科そぴあ/ホロライブ/アソビ★まわり隊！】", url: "https://www.youtube.com/watch?v=Uy-KPheZe7U", publishedDate: "2026-10-22" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-11-02"
  },
  {
    id: "single-162",
    title: "Jump King 配信まとめ",
    streamer: "百灯キョーコ",
    game: "Jump King",
    genre: "action",
    format: "multi",
    videos: [
      { title: "【EN】FIRST TIME PLAYING JUMP KING!!! 【Hyakuto Kyoko/Hololive】", url: "https://www.youtube.com/watch?v=Z4mtsZKfnTw", publishedDate: "2026-10-28" },
      { title: "明日のイベントに向けて練習～～～！！ | Jump King【百灯キョーコ/ホロライブ/アソビ★まわり隊！】", url: "https://www.youtube.com/watch?v=Wuca3jqkXjg", publishedDate: "2026-10-30" },
      { title: "【JUMP KING HOLORACE】遂に本番！！ てっぺん目指すぞーーー！！ |  Kyoko POV【百灯キョーコ/ホロライブ/アソビ★まわり隊！】", url: "https://www.youtube.com/watch?v=B_NEeTucjJI", publishedDate: "2026-10-30" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-07"
  },
  {
    id: "single-163",
    title: "Jump King 配信まとめ",
    streamer: "熱千めら",
    game: "Jump King",
    genre: "action",
    format: "multi",
    videos: [
      { title: "🔰鬼畜ゲー「Jump King」初心者大会直前練習のじゃ！【ホロライブ/アソビ★まわり隊！/熱千めら】", url: "https://www.youtube.com/watch?v=67vqn8Hyw3I", publishedDate: "2026-10-30" },
      { title: "初心者は1時間で「Jump King」どこまで登れるか…？！ 【ホロライブ/熱千めら】", url: "https://www.youtube.com/watch?v=_3_gYnsYquE", publishedDate: "2026-10-30" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-07"
  },
  {
    id: "single-164",
    title: "Jump King 配信まとめ",
    streamer: "宙科そぴあ",
    game: "Jump King",
    genre: "action",
    format: "multi",
    videos: [
      { title: "物理学博士によるJump King【宙科そぴあ/ホロライブ/アソビ★まわり隊！】", url: "https://www.youtube.com/watch?v=fMC8x2qT5-A", publishedDate: "2026-10-28" },
      { title: "【JUMP KING HOLORACE】ジャンプは物理 by 宙科そぴあ【ホロライブ/アソビ★まわり隊！】", url: "https://www.youtube.com/watch?v=1nGDxGnxJtA", publishedDate: "2026-10-30" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-07"
  },
  {
    id: "single-165",
    title: "R.E.P.O. 配信まとめ",
    streamer: "鈴鳴つづり",
    game: "R.E.P.O.",
    genre: "horror",
    format: "multi",
    videos: [
      { title: "ホロライブ新人ユニットで【R.E.P.O  with.アソビ★まわり隊！】#ホロライブ #アソビまわり隊", url: "https://www.youtube.com/watch?v=xl-CTTXCekc", publishedDate: "2026-10-14" },
      { title: "【R.E.P.O.】新MAPも来た！？先輩方と初めてのR.E.P.Oでワクワク！！【鈴鳴つづり/ホロライブ/アソビ★まわり隊！】 #ホロライブ #アソビまわり隊  #つづり配達中", url: "https://www.youtube.com/watch?v=JvUyxkeFWRM", publishedDate: "2026-10-31" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-07"
  },
  {
    id: "single-166",
    title: "レーシングマスター 配信まとめ",
    streamer: "兎田ぺこら",
    game: "レーシングマスター",
    genre: "racing",
    format: "multi",
    videos: [
      { title: "【レーシングマスター】本格レースの世界を体験してみる！ぺこ！【ホロライブ/兎田ぺこら】", url: "https://www.youtube.com/watch?v=E1-SAXfsQZQ", publishedDate: "2026-09-23" },
      { title: "【爆走】ぺこら、レーシングマスター案件でガチレース！最速の座を目指して大爆走！【兎田ぺこら／レーシングマスター】", url: "https://www.youtube.com/watch?v=5XVavftwhps", publishedDate: "2026-10-13" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-07"
  },
  {
    id: "single-167",
    title: "トルネコの大冒険 配信まとめ",
    streamer: "兎田ぺこら",
    game: "トルネコの大冒険 不思議のダンジョン",
    genre: "rpg",
    format: "multi",
    videos: [
      { title: "【初見】もっと不思議のダンジョンに挑戦！トルネコの大冒険 ちょっとステキなリマスター！ぺこ！【ホロライブ/兎田ぺこら】※ネタバレ注意", url: "https://www.youtube.com/watch?v=Leqxfa6jYzM", publishedDate: "2026-09-21" },
      { title: "【初見】もっと不思議のダンジョンをクリアしたい！トルネコの大冒険 ちょっとステキなリマスター！ぺこ！【ホロライブ/兎田ぺこら】※ネタバレ注意", url: "https://www.youtube.com/watch?v=ZCAWxX1oRBU", publishedDate: "2026-09-22" },
      { title: "【初見】もっと不思議のダンジョンをマジでクリアしたい！トルネコの大冒険 ちょっとステキなリマスター！ぺこ！【ホロライブ/兎田ぺこら】※ネタバレ注意", url: "https://www.youtube.com/watch?v=nKJpG9-zd6Y", publishedDate: "2026-09-23" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-08"
  },
  {
    id: "single-168",
    title: "ポケットモンスター シャイニングパール 配信まとめ",
    streamer: "兎田ぺこら",
    game: "ポケットモンスター ブリリアントダイヤモンド・シャイニングパール",
    genre: "rpg",
    format: "multi",
    videos: [
      { title: "【ポケモンダイパ】ホロメン6人に貰ったタマゴでクリアを目指す旅！ぺこ！【ホロライブ/兎田ぺこら】", url: "https://www.youtube.com/watch?v=183AUMKOkas", publishedDate: "2026-10-04" },
      { title: "#2【ポケモンダイパ】ホロメン6人に貰ったタマゴでクリアを目指す旅！ぺこ！【ホロライブ/兎田ぺこら】", url: "https://www.youtube.com/watch?v=ffiRtvdubvA", publishedDate: "2026-10-05" },
      { title: "#3【ポケモンダイパ】いくぞ四天王戦！ホロメン6人に貰ったタマゴでクリアを目指す旅！ぺこ！【ホロライブ/兎田ぺこら】", url: "https://www.youtube.com/watch?v=w_QlfNcwYZ0", publishedDate: "2026-10-06" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-11",
    separateSeriesFrom: "hd-0514",
    separateSeriesReason: "2021年の再生リスト(ポケモンBD)とは別の実況。2026年10月の「ホロメン6人に貰ったタマゴでクリアを目指す旅」(シャイニングパール)で、再生リストの内容をブラウザで確認し3本が未収録と確認済み",
    playlistCheckedAt: "2026-11-11"
  },
  {
    id: "single-169",
    title: "【リズム天国】大人気リズムゲームを初見プレイのじゃ！",
    streamer: "熱千めら",
    game: "リズム天国 ミラクルスターズ",
    genre: "other",
    format: "single",
    videos: [
      { title: "【リズム天国】大人気リズムゲームを初見プレイのじゃ！【ホロライブ/アソビ★まわり隊！/熱千めら】", url: "https://www.youtube.com/watch?v=mNcFyUgR_B4", publishedDate: "2026-10-11" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-11-17"
  },
  {
    id: "single-170",
    title: "ホロ鯖ARK 配信まとめ",
    streamer: "兎田ぺこら",
    game: "ARK: Survival Evolved",
    genre: "sandbox",
    format: "multi",
    videos: [
      { title: "【#ホロ鯖ARK】DAY1🦖きｔらああああああああああああああああああああ！！！【ホロライブ/兎田ぺこら】", url: "https://www.youtube.com/watch?v=tqzLShTKJkk", publishedDate: "2026-10-10" },
      { title: "【#ホロ鯖ARK】DAY2🦖きｔらああああああああああああああああああああ！！！【ホロライブ/兎田ぺこら】", url: "https://www.youtube.com/watch?v=UjdcDg3mPnY", publishedDate: "2026-10-11" },
      { title: "【#ホロ鯖ARK】DAY3🦖きｔらああああああああああああああああああああ！！！【ホロライブ/兎田ぺこら】", url: "https://www.youtube.com/watch?v=7oPO_-SK_CY", publishedDate: "2026-10-12" },
      { title: "【#ホロ鯖ARK】DAY4🦖きｔらああああああああああああああああああああ！！！【ホロライブ/兎田ぺこら】", url: "https://www.youtube.com/watch?v=RAFETsi0eyA", publishedDate: "2026-10-13" },
      { title: "【#ホロ鯖ARK】DAY5🦖きｔらああああああああああああああああああああ！！！【ホロライブ/兎田ぺこら】", url: "https://www.youtube.com/watch?v=rQJtAEtidic", publishedDate: "2026-10-14" },
      { title: "【#ホロ鯖ARK】DAY6🦖きｔらああああああああああああああああああああ！！！【ホロライブ/兎田ぺこら】", url: "https://www.youtube.com/watch?v=mqsCAFeZ2ks", publishedDate: "2026-10-15" },
      { title: "【#ホロ鯖ARK】DAY7🦖きｔらああああああああああああああああああああ！！！【ホロライブ/兎田ぺこら】", url: "https://www.youtube.com/watch?v=AeGUXowhpOE", publishedDate: "2026-10-17" },
      { title: "【#ホロ鯖ARK】DAY8🦖きｔらああああああああああああああああああああ！！！【ホロライブ/兎田ぺこら】", url: "https://www.youtube.com/watch?v=SIxl_AYaD70", publishedDate: "2026-10-18" },
      { title: "【#ホロ鯖ARK】DAY9🦖きｔらああああああああああああああああああああ！！！【ホロライブ/兎田ぺこら】", url: "https://www.youtube.com/watch?v=xPXkTgryIgs", publishedDate: "2026-10-19" },
      { title: "【#ホロ鯖ARK】DAY10🦖きｔらああああああああああああああああああああ！！！【ホロライブ/兎田ぺこら】", url: "https://www.youtube.com/watch?v=XrvCHE7TDIY", publishedDate: "2026-10-20" },
      { title: "【#ホロ鯖ARK】DAY11🦖きｔらああああああああああああああああああああ！！！【ホロライブ/兎田ぺこら】", url: "https://www.youtube.com/watch?v=GEa150_DsKY", publishedDate: "2026-10-20" },
      { title: "【#ホロ鯖ARK】DAY12🦖きｔらああああああああああああああああああああ！！！【ホロライブ/兎田ぺこら】", url: "https://www.youtube.com/watch?v=ioEKuzmwOYI", publishedDate: "2026-10-21" },
      { title: "【#ホロ鯖ARK】DAY13🦖きｔらああああああああああああああああああああ！！！【ホロライブ/兎田ぺこら】", url: "https://www.youtube.com/watch?v=8X0Pa0P7zZM", publishedDate: "2026-10-24" },
      { title: "【#ホロ鯖ARK】DAY14🦖きｔらああああああああああああああああああああ！！！【ホロライブ/兎田ぺこら】", url: "https://www.youtube.com/watch?v=T-puonDnjXE", publishedDate: "2026-10-25" },
      { title: "【#ホロ鯖ARK】緊急ゲリラ‼ 最強ギガノトサウルス発見したからテイムする‼ ぺこ！【ホロライブ/兎田ぺこら】", url: "https://www.youtube.com/watch?v=QuhsRznIp9w", publishedDate: "2026-10-25" },
      { title: "【#ホロ鯖ARK】DAY16🦖きｔらああああああああああああああああああああ！！！【ホロライブ/兎田ぺこら】", url: "https://www.youtube.com/watch?v=Qp37V8rz7QQ", publishedDate: "2026-10-27" },
      { title: "【#ホロ鯖ARK】DAY17🦖きｔらああああああああああああああああああああ！！！【ホロライブ/兎田ぺこら】", url: "https://www.youtube.com/watch?v=KjEw1qSGTv0", publishedDate: "2026-10-28" },
      { title: "【#ホロ鯖ARK】DAY18🦖きｔらああああああああああああああああああああ！！！【ホロライブ/兎田ぺこら】", url: "https://www.youtube.com/watch?v=AZPIzPt4cJo", publishedDate: "2026-10-29" },
      { title: "【#ホロ鯖ARK】ホロメンたちと試練の洞窟へ行く！！！【ホロライブ/兎田ぺこら】", url: "https://www.youtube.com/watch?v=KweMgPbHN9I", publishedDate: "2026-10-29" },
      { title: "【#ホロ鯖ARK】DAY20🦖きｔらああああああああああああああああああああ！！！【ホロライブ/兎田ぺこら】", url: "https://www.youtube.com/watch?v=J_0fi6QvUfE", publishedDate: "2026-10-31" },
      { title: "【#ホロ鯖ARK】DAY21🦖きｔらああああああああああああああああああああ！！！【ホロライブ/兎田ぺこら】", url: "https://www.youtube.com/watch?v=1E7eYQJB_58", publishedDate: "2026-10-31" },
      { title: "【#ホロ鯖ARK】DAY22🦖きｔらああああああああああああああああああああ！！！【ホロライブ/兎田ぺこら】", url: "https://www.youtube.com/watch?v=BWs4Co9bqr0", publishedDate: "2026-11-02" },
      { title: "【#ホロ鯖ARK】DAY23🦖きｔらああああああああああああああああああああ！！！【ホロライブ/兎田ぺこら】", url: "https://www.youtube.com/watch?v=mVa6zdBSUKg", publishedDate: "2026-11-05" },
      { title: "【#ホロ鯖ARK】DAY24🦖きｔらああああああああああああああああああああ！！！【ホロライブ/兎田ぺこら】", url: "https://www.youtube.com/watch?v=o1uMpV9ZemQ", publishedDate: "2026-11-07" },
      { title: "【#ホロ鯖ARK】DAY25🦖きｔらああああああああああああああああああああ！！！【ホロライブ/兎田ぺこら】", url: "https://www.youtube.com/watch?v=uqIGdOy-3J0", publishedDate: "2026-11-08" },
      { title: "【#ホロ鯖ARK】最終日🦖きｔらああああああああああああああああああああ！！！【ホロライブ/兎田ぺこら】", url: "https://www.youtube.com/watch?v=CSScHhS82x0", publishedDate: "2026-11-09" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-21"
  },
  {
    id: "single-171",
    title: "【空気読み。2】無知とは時に卑劣のじゃ…",
    streamer: "熱千めら",
    game: "空気読み。2",
    genre: "other",
    format: "single",
    videos: [
      { title: "【空気読み。2】無知とは時に卑劣のじゃ…【ホロライブ/アソビ★まわり隊！/熱千めら】", url: "https://www.youtube.com/watch?v=poERFwoVxxE", publishedDate: "2026-10-17" }
    ],
    note: "専用再生リストなし(サイト未登録。YouTube 側の再生リストへの収録は未確認)",
    addedDate: "2026-11-21"
  },
  {
    id: "single-172",
    title: "Rust 配信まとめ",
    streamer: "紫咲シオン",
    game: "Rust",
    genre: "sandbox",
    format: "multi",
    videos: [
      { title: "【#holoRUST】ガチ初見RUST！！ホロ鯖冒険します！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=matC32C-i-M", publishedDate: "2025-04-19" },
      { title: "【#holoRUST】ガチ初見RUST！！ホロ鯖冒険します！！2【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=NyQA-oXdwS4", publishedDate: "2025-04-19" },
      { title: "【#holoRUST】ホロ鯖RUST！！今日も生き残りたい！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=48VYp4T1UKM", publishedDate: "2025-04-21" },
      { title: "【#holoRUST】ホロ鯖RUST！！冒険したり農業したり！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=qBfBVk_l0TU", publishedDate: "2025-04-23" },
      { title: "【#holoRUST】ラストのRUST！！たくさん思い出作って楽しむ！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=WUe-ylfdHSk", publishedDate: "2025-04-24" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-173",
    title: "【スーパーマリオパーティジャンボリー】#マシぺこ (塩田マリ子) でマリパする！👑",
    streamer: "紫咲シオン",
    game: "スーパー マリオパーティ ジャンボリー",
    genre: "other",
    format: "single",
    videos: [
      { title: "【スーパーマリオパーティジャンボリー】#マシぺこ (塩田マリ子) でマリパする！👑【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=MrzXY7e00a0", publishedDate: "2025-04-17" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-174",
    title: "GeoGuessr 配信まとめ",
    streamer: "紫咲シオン",
    game: "GeoGuessr",
    genre: "other",
    format: "multi",
    videos: [
      { title: "【#あずしお】紫咲シオンをGeoGuessrする配信…！？【ホロライブ/紫咲シオン/AZKi】", url: "https://www.youtube.com/watch?v=pq0Wf288wiI", publishedDate: "2025-04-13" },
      { title: "【#あずしお】紫咲シオンをGeoGuessrする配信…！？【ホロライブ/紫咲シオン/AZKi】", url: "https://www.youtube.com/watch?v=--1m3Mj8uew", publishedDate: "2025-04-13" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-175",
    title: "ポケットモンスター 金・銀 配信まとめ",
    streamer: "紫咲シオン",
    game: "ポケットモンスター 金・銀",
    genre: "rpg",
    format: "multi",
    videos: [
      { title: "【ポケットモンスター銀】はじめましての新しい冒険！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=u2aEvbFEjRY", publishedDate: "2025-04-05" },
      { title: "【ポケットモンスター銀】まだ見ぬ新天地目指して冒険だぁ！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=gPubrU59GWE", publishedDate: "2025-04-07" },
      { title: "【ポケットモンスター銀】初めてのカントー地方へ！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=IJ5BtotPzU0", publishedDate: "2025-04-09" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-176",
    title: "【MiSide : ミサイド】彼女とラブラブ新生活始めます！💓(予定)",
    streamer: "紫咲シオン",
    game: "MiSide",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【MiSide : ミサイド】彼女とラブラブ新生活始めます！💓(予定)【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=TikDVKv_IZE", publishedDate: "2025-03-24" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-177",
    title: "お宝マウンテン 配信まとめ",
    streamer: "紫咲シオン",
    game: "お宝マウンテン",
    genre: "other",
    format: "multi",
    videos: [
      { title: "【お宝マウンテン】噂のゲーム遊んでみるぞ～～！！告知あるヨ！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=vs-ijWvRdKY", publishedDate: "2024-08-23" },
      { title: "【お宝マウンテン】久しぶりにいっちょ行きますか…【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=MVx_2lL5Wrc", publishedDate: "2025-03-21" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-178",
    title: "モンスターハンターワイルズ 配信まとめ",
    streamer: "紫咲シオン",
    game: "モンスターハンターワイルズ",
    genre: "action",
    format: "multi",
    videos: [
      { title: "【モンハンワイルズ】新作モンハンベータテストきた～！！遊ぶ！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=OHBA1ZrI90Y", publishedDate: "2024-11-03" },
      { title: "【モンハンワイルズ】狩猟解禁！！モンハンの世界へいくぞ～～！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=eV0tk3BjyfY", publishedDate: "2025-03-01" },
      { title: "【モンハンワイルズ】一狩り行くぞ！！ストーリークリアまで！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=awnf6rTMzUs", publishedDate: "2025-03-02" },
      { title: "【モンハンワイルズ】上位を少し嗜みに行ってみる！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=7LpT5kHEI_k", publishedDate: "2025-03-11" },
      { title: "【モンハンワイルズ】塩ぺこ天下統一モンハン！！行くぞ！！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=TfDN_TjmG3c", publishedDate: "2025-03-12" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-179",
    title: "【TrickShot Simulator】話しながら奇跡を起こす配信。",
    streamer: "紫咲シオン",
    game: "TrickShot Simulator",
    genre: "sim",
    format: "single",
    videos: [
      { title: "【TrickShot Simulator】話しながら奇跡を起こす配信。【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=q62YpF5ec7Q", publishedDate: "2025-02-03" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-180",
    title: "【The Forest】#塩シャチ クリスマスデート🎄食人族の住む森へ・・・",
    streamer: "紫咲シオン",
    game: "The Forest",
    genre: "sandbox",
    format: "single",
    videos: [
      { title: "【The Forest】#塩シャチ クリスマスデート🎄食人族の住む森へ・・・【ホロライブ/紫咲シオン/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=inYwH5VuRfs", publishedDate: "2024-12-24" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-181",
    title: "ドラゴンクエストIII HD-2D Remake 配信まとめ",
    streamer: "紫咲シオン",
    game: "ドラゴンクエストIII HD-2D Remake",
    genre: "rpg",
    format: "multi",
    videos: [
      { title: "【ドラクエ3リメイク】完全初見ドラゴンクエスト⚔️そして伝説へ・・・【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=0ZO2Vg6pVpQ", publishedDate: "2024-11-23" },
      { title: "【ドラクエ3リメイク】完全初見ドラゴンクエスト⚔️伝説のオーブ集め【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=WsP3xMQXgqE", publishedDate: "2024-11-30" },
      { title: "【ドラクエ3リメイク】完全初見ドラゴンクエスト⚔️いざバラモス城へ【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=j5u9KpHXhmc", publishedDate: "2024-12-06" },
      { title: "【ドラクエ3リメイク】完全初見ドラゴンクエスト⚔️そして伝説になる【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=_PFWjSkrHsQ", publishedDate: "2024-12-20" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-182",
    title: "Liar's Bar 配信まとめ",
    streamer: "紫咲シオン",
    game: "Liar's Bar",
    genre: "other",
    format: "multi",
    videos: [
      { title: "【 Liar's Bar 】命がけのギャンブル…！ #一夜限りのホロハロウィン 🎃【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=OHGqQ3DWmP4", publishedDate: "2024-10-31" },
      { title: "【 Liar's Bar 】視聴者参加型！夜中のギャンブル大会開催🌟【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=3Hew-oEpEEQ", publishedDate: "2024-11-16" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-183",
    title: "TCG Card Shop Simulator 配信まとめ",
    streamer: "紫咲シオン",
    game: "TCG Card Shop Simulator",
    genre: "sim",
    format: "multi",
    videos: [
      { title: "【TCG Card Shop Simulator】カードショップ開店！！パック開ける仕事したいです！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=GfUnoE6645Y", publishedDate: "2024-10-03" },
      { title: "【TCG Card Shop Simulator】激レアカード引きたい！買って買って～！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=efcrh-LDhc8", publishedDate: "2024-10-07" },
      { title: "【TCG Card Shop Simulator】そろそろ激レアカード欲しいよね？【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=zizR7UkN6oo", publishedDate: "2024-10-12" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-184",
    title: "【僕、アルバイトォォ！！】はじめてのコンビニバイト！！頑張ります！",
    streamer: "紫咲シオン",
    game: "僕、アルバイトォォ！！",
    genre: "sim",
    format: "single",
    videos: [
      { title: "【僕、アルバイトォォ！！】はじめてのコンビニバイト！！頑張ります！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=MzwYKS604xw", publishedDate: "2024-09-27" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-185",
    title: "【Buckshot Roulette】これが命がけのギャンブル・・・ッ！！",
    streamer: "紫咲シオン",
    game: "Buckshot Roulette",
    genre: "other",
    format: "single",
    videos: [
      { title: "【Buckshot Roulette】これが命がけのギャンブル・・・ッ！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=ksBdR9urnCc", publishedDate: "2024-09-07" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-186",
    title: "【８番出口】誕生日までに駅から出してください。",
    streamer: "紫咲シオン",
    game: "8番出口",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【８番出口】誕生日までに駅から出してください。【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=hHRA5nJbnxI", publishedDate: "2023-12-07" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-187",
    title: "ストリートファイター6 配信まとめ",
    streamer: "紫咲シオン",
    game: "ストリートファイター6",
    genre: "action",
    format: "multi",
    videos: [
      { title: "【STREET FIGHTER 6】ガチ初心者、頑張ります！ばぶ【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=ZhsbdX7D3mE", publishedDate: "2023-11-10" },
      { title: "【STREET FIGHTER 6】初心者界最強を目指して特訓🔥【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=peKMJ3Xky_s", publishedDate: "2023-11-19" },
      { title: "【STREET FIGHTER 6】初心者修行。ランク上げたいっ！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=HGC78j5h374", publishedDate: "2023-11-29" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-188",
    title: "【Party Animals】#マシぺこ で動物になって真剣勝負だっ！！",
    streamer: "紫咲シオン",
    game: "Party Animals",
    genre: "action",
    format: "single",
    videos: [
      { title: "【Party Animals】#マシぺこ で動物になって真剣勝負だっ！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=MdF8ICGkKF8", publishedDate: "2023-11-11" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-189",
    title: "【スーパーマリオブラザーズ ワンダー】最新作のマリオ遊ぶ！！",
    streamer: "紫咲シオン",
    game: "スーパーマリオブラザーズ ワンダー",
    genre: "action",
    format: "single",
    videos: [
      { title: "【スーパーマリオブラザーズ ワンダー】最新作のマリオ遊ぶ！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=sGYHS_3R-9I", publishedDate: "2023-10-21" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-190",
    title: "スイカゲーム 配信まとめ",
    streamer: "紫咲シオン",
    game: "スイカゲーム",
    genre: "puzzle",
    format: "multi",
    videos: [
      { title: "【スイカゲーム】流行りのスイカ作るゲーム！初見プレイ🍉【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=536oJXjyUb8", publishedDate: "2023-09-28" },
      { title: "【スイカゲーム】優しくしてください。3000点目指して…【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=zgOaL43MnBE", publishedDate: "2023-10-03" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-191",
    title: "【漢字でGO!】漢字なんでも読みます！！ネ〇リーグ風漢字クイズ！",
    streamer: "紫咲シオン",
    game: "漢字でGO!",
    genre: "other",
    format: "single",
    videos: [
      { title: "【漢字でGO!】漢字なんでも読みます！！ネ〇リーグ風漢字クイズ！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=SPqmehUygjk", publishedDate: "2023-09-08" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-192",
    title: "【つぐのひ】船長のホラゲー(？)をやってみる！！",
    streamer: "紫咲シオン",
    game: "つぐのひ",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【つぐのひ】船長のホラゲー(？)をやってみる！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=m8SEKjAoQic", publishedDate: "2023-08-21" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-193",
    title: "ポケモンユナイト 配信まとめ",
    streamer: "紫咲シオン",
    game: "ポケモンユナイト",
    genre: "other",
    format: "multi",
    videos: [
      { title: "【ポケモンユナイト】まったりユナイト！守りたい…ッ！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=Fd5h2qWYDiY", publishedDate: "2021-08-11" },
      { title: "【ポケモンユナイト】大会に向けてちょっと練習しちゃお！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=fVzRhDsGVDk", publishedDate: "2023-08-09" },
      { title: "【#ポケモンユナイト世界大会】ホロライブ対抗戦！！！勝つぞおおおお！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=IdtekjqYJ5o", publishedDate: "2023-08-10" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-194",
    title: "ピクミン4 配信まとめ",
    streamer: "紫咲シオン",
    game: "ピクミン4",
    genre: "action",
    format: "multi",
    videos: [
      { title: "【ピクミン４】人生はじめてのピクミン！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=8elmnvda8Tk", publishedDate: "2023-07-23" },
      { title: "【ピクミン４】紫咲ピクミン頑張ります。【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=a9He6UOUKVQ", publishedDate: "2023-07-25" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-195",
    title: "ONLY UP! 配信まとめ",
    streamer: "紫咲シオン",
    game: "ONLY UP!",
    genre: "action",
    format: "multi",
    videos: [
      { title: "【OnlyUp!】頂上目指して登ってみる！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=hgXu0qkfrxQ", publishedDate: "2023-07-02" },
      { title: "【OnlyUp!】頂上まで行きたいリベンジ！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=OhBQJ-58VE0", publishedDate: "2023-07-04" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-196",
    title: "【Pineapple on pizza】みんなが神ゲーっていうゲームやる。",
    streamer: "紫咲シオン",
    game: "Pineapple on pizza",
    genre: "other",
    format: "single",
    videos: [
      { title: "【Pineapple on pizza】みんなが神ゲーっていうゲームやる。【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=FJt6RYFqFfc", publishedDate: "2023-06-13" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-197",
    title: "【ぷよぷよテトリス2】練習しますか～！？※大会出ません、やりたいだけ！",
    streamer: "紫咲シオン",
    game: "ぷよぷよテトリス2",
    genre: "puzzle",
    format: "single",
    videos: [
      { title: "【ぷよぷよテトリス2】練習しますか～！？※大会出ません、やりたいだけ！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=AkTLxzKcrfk", publishedDate: "2023-04-14" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-198",
    title: "【Q REMASTERED】難しい問題もハバ卒なら余裕だよねっ",
    streamer: "紫咲シオン",
    game: "Q REMASTERED",
    genre: "puzzle",
    format: "single",
    videos: [
      { title: "【Q REMASTERED】難しい問題もハバ卒なら余裕だよねっ【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=97fkzW87PfY", publishedDate: "2023-04-07" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-199",
    title: "【A Little to the Left】深夜のお片付け～！！猫ちゃん！",
    streamer: "紫咲シオン",
    game: "A Little to the Left",
    genre: "puzzle",
    format: "single",
    videos: [
      { title: "【A Little to the Left】深夜のお片付け～！！猫ちゃん！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=cOH2NqYpLb0", publishedDate: "2023-03-24" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-200",
    title: "HoloCure 配信まとめ",
    streamer: "紫咲シオン",
    game: "HoloCure",
    genre: "action",
    format: "multi",
    videos: [
      { title: "【HoloCure】ファンメイドのゲームやるぞ！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=zBhbH-H4I4o", publishedDate: "2022-06-29" },
      { title: "【HoloCure】神ゲーをクリアしたい・・・！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=xoQfOBdKKt0", publishedDate: "2022-07-02" },
      { title: "【HoloCure】2期生キターーー！！遊んでみる！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=q8bvXSVD7mo", publishedDate: "2023-02-15" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-201",
    title: "【Trombone Champ】最高のトロンボーンを奏でます。",
    streamer: "紫咲シオン",
    game: "Trombone Champ",
    genre: "other",
    format: "single",
    videos: [
      { title: "【Trombone Champ】最高のトロンボーンを奏でます。【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=kSeHkGEh6HA", publishedDate: "2022-11-23" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-202",
    title: "ポケットモンスター スカーレット・バイオレット 配信まとめ",
    streamer: "紫咲シオン",
    game: "ポケットモンスター スカーレット・バイオレット",
    genre: "rpg",
    format: "multi",
    videos: [
      { title: "【ポケモンSV】最新作！！全力で楽しむバイオレット！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=7kvhzyozAq4", publishedDate: "2022-11-17" },
      { title: "【ポケモンSV】最新作！！全力で楽しむバイオレット！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=jA5Mcl7_ySI", publishedDate: "2022-11-18" },
      { title: "【ポケモンSV】最新作！！次の場所を目指して冒険へ【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=39eqgSJps50", publishedDate: "2022-11-18" },
      { title: "【ポケモンSV】四天王倒してチャンピオンになる！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=iaac1oVGAwA", publishedDate: "2022-11-20" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-203",
    title: "【Cats Organized Neatly】ﾈｺﾁｬﾝのパズル！ﾈｺﾁｬﾝ！ﾈｺﾁｬﾝ！",
    streamer: "紫咲シオン",
    game: "Cats Organized Neatly",
    genre: "puzzle",
    format: "single",
    videos: [
      { title: "【Cats Organized Neatly】ﾈｺﾁｬﾝのパズル！ﾈｺﾁｬﾝ！ﾈｺﾁｬﾝ！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=bQ4eg1Qehak", publishedDate: "2022-11-13" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-204",
    title: "スプラトゥーン3 配信まとめ",
    streamer: "紫咲シオン",
    game: "スプラトゥーン3",
    genre: "fps",
    format: "multi",
    videos: [
      { title: "【 スプラトゥーン３ 】初心者がんばるぞ！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=uo27oDWG4uI", publishedDate: "2022-09-16" },
      { title: "【 スプラトゥーン３ 】バンカラマッチにいく！！腕前Bです。【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=PMhU82XVTV8", publishedDate: "2022-09-27" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-205",
    title: "モンスターハンターライズ 配信まとめ",
    streamer: "紫咲シオン",
    game: "モンスターハンターライズ",
    genre: "action",
    format: "multi",
    videos: [
      { title: "【MONSTER HUNTER RISE】ひと狩りいこうぜ！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=-PziNUil23U", publishedDate: "2021-03-30" },
      { title: "【MONSTER HUNTER RISE】今日も太刀で立ち向かいます！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=AImKIq6CXWE", publishedDate: "2021-04-01" },
      { title: "【MONSTER HUNTER RISE】視聴者参加型！！みんなの姫です♡【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=_x4VZl1rTPg", publishedDate: "2021-04-17" },
      { title: "【MONSTER HUNTER RISE】るしおんで優勝する！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=di-JD4P_CI4", publishedDate: "2021-05-15" },
      { title: "【モンハンサンブレイク】初めてのサンブレイク！！がんばるます！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=8Hn5PmIC5-A", publishedDate: "2022-07-06" },
      { title: "【モンハンサンブレイク】今日もがんばる赤ちゃんハンター【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=HLJyyGFIWpE", publishedDate: "2022-07-09" },
      { title: "【モンハンサンブレイク】今日もひと狩り！MR３行くぞ～！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=Lsyh93LCD8E", publishedDate: "2022-07-13" },
      { title: "【モンハンサンブレイク】しおぺこで一狩り行くぞ！！！【ホロライブ/紫咲シオン/兎田ぺこら】", url: "https://www.youtube.com/watch?v=FBCq5qHGCcI", publishedDate: "2022-07-26" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-206",
    title: "【stray】猫になって世界を見に行く！",
    streamer: "紫咲シオン",
    game: "Stray",
    genre: "other",
    format: "single",
    videos: [
      { title: "【stray】猫になって世界を見に行く！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=kuq02FVWK9Q", publishedDate: "2022-07-22" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-207",
    title: "Nintendo Switch Sports 配信まとめ",
    streamer: "紫咲シオン",
    game: "Nintendo Switch Sports",
    genre: "sports",
    format: "multi",
    videos: [
      { title: "【Switch Sports】スポーツは立ってやるものだろ！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=yQWwtFwPvpI", publishedDate: "2022-06-04" },
      { title: "【Switch Sports】美女の真剣勝負。【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=Ze637H39a6s", publishedDate: "2022-06-11" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-208",
    title: "【NEEDY GIRL OVERDOSE】メンヘラ彼女プロデュースします💓",
    streamer: "紫咲シオン",
    game: "NEEDY GIRL OVERDOSE",
    genre: "other",
    format: "single",
    videos: [
      { title: "【NEEDY GIRL OVERDOSE】メンヘラ彼女プロデュースします💓【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=5S2Qm7jn9Tw", publishedDate: "2022-06-06" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-209",
    title: "【Unpacking】やっと引っ越しだ・・・！！深夜の片づけだ！",
    streamer: "紫咲シオン",
    game: "Unpacking",
    genre: "puzzle",
    format: "single",
    videos: [
      { title: "【Unpacking】やっと引っ越しだ・・・！！深夜の片づけだ！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=SxzGVLjZ4P8", publishedDate: "2022-04-08" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-210",
    title: "Pokémon LEGENDS アルセウス 配信まとめ",
    streamer: "紫咲シオン",
    game: "Pokémon LEGENDS アルセウス",
    genre: "rpg",
    format: "multi",
    videos: [
      { title: "【Pokémon LEGENDS アルセウス】新たな冒険へ【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=47vGw09GELw", publishedDate: "2022-01-28" },
      { title: "【Pokémon LEGENDS アルセウス】新　世　界【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=UD51ml70dv8", publishedDate: "2022-01-29" },
      { title: "【Pokémon LEGENDS アルセウス】今日からニート編【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=pUwiOJ2eAaU", publishedDate: "2022-02-12" },
      { title: "【Pokémon LEGENDS アルセウス】僕たちの旅はまだ終わらない【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=d49_lf66mU0", publishedDate: "2022-02-20" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-211",
    title: "ポケットモンスター ブリリアントダイヤモンド・シャイニングパール 配信まとめ",
    streamer: "紫咲シオン",
    game: "ポケットモンスター ブリリアントダイヤモンド・シャイニングパール",
    genre: "rpg",
    format: "multi",
    videos: [
      { title: "【シャイニングパール】念願のダイパリメイクやるぞ！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=hNUpi17Genw", publishedDate: "2021-11-19" },
      { title: "【シャイニングパール】念願のダイパリメイクやるぞ！！続き！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=pS5TOMFX7ZY", publishedDate: "2021-11-20" },
      { title: "【シャイニングパール】ダイパリメイク！！殿堂入り後の世界！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=FPXR4vfhQKg", publishedDate: "2021-11-22" },
      { title: "【シャイニングパール】ダイパリメイク！！いざ全国へ…【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=tybJpxrYB8E", publishedDate: "2021-11-25" },
      { title: "【シャイニングパール】探検！！そして地下労働・・・！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=8Si1BhNfYns", publishedDate: "2021-11-28" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-212",
    title: "【マリオパーティ スーパースターズ】みんなでバトルだぁ！！",
    streamer: "紫咲シオン",
    game: "マリオパーティ スーパースターズ",
    genre: "other",
    format: "single",
    videos: [
      { title: "【マリオパーティ スーパースターズ】みんなでバトルだぁ！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=r7Dsg5nF-cE", publishedDate: "2021-11-03" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-213",
    title: "Among Us 配信まとめ",
    streamer: "紫咲シオン",
    game: "Among Us",
    genre: "other",
    format: "multi",
    videos: [
      { title: "【#ゆるホロAmongUs 】初めてのAmongUs！！You SUS！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=Sa-kE9TkJ9g", publishedDate: "2020-12-03" },
      { title: "【 #ホロハロウィンAmongUs 】怪しくないよ！Trick or SUS！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=KfZzhjXQRds", publishedDate: "2021-10-31" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-214",
    title: "【Undertale】完全初見！！誰も死なない平和なRPG？",
    streamer: "紫咲シオン",
    game: "UNDERTALE",
    genre: "rpg",
    format: "single",
    videos: [
      { title: "【Undertale】完全初見！！誰も死なない平和なRPG？【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=Xi_ubsIVq1E", publishedDate: "2021-10-30" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-215",
    title: "【ポケモンDP】制限時間アリ…！？ダイパを楽しむ！！",
    streamer: "紫咲シオン",
    game: "ポケットモンスター ダイヤモンド・パール",
    genre: "rpg",
    format: "single",
    videos: [
      { title: "【ポケモンDP】制限時間アリ…！？ダイパを楽しむ！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=H7YqZMdbr-k", publishedDate: "2021-09-23" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-216",
    title: "【Gartic Phone】噂のお絵描き伝言ゲーム！！視聴者参加型！！",
    streamer: "紫咲シオン",
    game: "Gartic Phone",
    genre: "other",
    format: "single",
    videos: [
      { title: "【Gartic Phone】噂のお絵描き伝言ゲーム！！視聴者参加型！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=gH0az8_ai3g", publishedDate: "2021-08-03" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-217",
    title: "【ウマ娘】完全初見のウマ娘！！トウカイテイオー！！",
    streamer: "紫咲シオン",
    game: "ウマ娘 プリティーダービー",
    genre: "sim",
    format: "single",
    videos: [
      { title: "【ウマ娘】完全初見のウマ娘！！トウカイテイオー！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=wifLiZ5XbFs", publishedDate: "2021-05-18" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-218",
    title: "New ポケモンスナップ 配信まとめ",
    streamer: "紫咲シオン",
    game: "New ポケモンスナップ",
    genre: "action",
    format: "multi",
    videos: [
      { title: "【Newポケモンスナップ】新作きたー！！全力で楽しむ！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=NKvJOLqNGGc", publishedDate: "2021-05-02" },
      { title: "【Newポケモンスナップ】全力で楽しむポケモンスナップ！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=UOs8OL3K-1k", publishedDate: "2021-05-03" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-219",
    title: "【planet coaster】真夜中遊園地デート💓",
    streamer: "紫咲シオン",
    game: "Planet Coaster",
    genre: "sim",
    format: "single",
    videos: [
      { title: "【planet coaster】真夜中遊園地デート💓【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=QNLE24V71tU", publishedDate: "2021-02-23" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-220",
    title: "【L4D2】戦場デート！！ししおんで頑張るぞ！！",
    streamer: "紫咲シオン",
    game: "Left 4 Dead 2",
    genre: "fps",
    format: "single",
    videos: [
      { title: "【L4D2】戦場デート！！ししおんで頑張るぞ！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=yarCKBQ94Pc", publishedDate: "2020-12-29" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-221",
    title: "Doki Doki Literature Club 配信まとめ",
    streamer: "紫咲シオン",
    game: "Doki Doki Literature Club",
    genre: "horror",
    format: "multi",
    videos: [
      { title: "【DDLC】ドキドキ・・・これってまさか恋？【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=ZDl-ZhTUjvc", publishedDate: "2020-12-20" },
      { title: "【DDLC】聖夜だしラブラブします。ごめん・・・【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=6aKW_UMHv4U", publishedDate: "2020-12-25" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-222",
    title: "【Dead by Daylight】初見鬼ごっこ！！深夜の眠れるDBD",
    streamer: "紫咲シオン",
    game: "Dead by Daylight",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【Dead by Daylight】初見鬼ごっこ！！深夜の眠れるDBD【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=8R2N4tgpZpc", publishedDate: "2020-12-14" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-223",
    title: "Papers, Please 配信まとめ",
    streamer: "紫咲シオン",
    game: "Papers, Please",
    genre: "sim",
    format: "multi",
    videos: [
      { title: "【Papers, Please】入国審査官になりました！！でてけ！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=IyT0PJQrDH4", publishedDate: "2020-11-25" },
      { title: "【Papers, Please】入国審査の時間。働きます・・・【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=ce3DHJl8yEI", publishedDate: "2020-11-27" },
      { title: "【Papers, Please】何があっても働くんだよ・・・！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=FXRDAvrh-pU", publishedDate: "2020-12-05" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-224",
    title: "Tavern Manager Simulator 配信まとめ",
    streamer: "沙花叉クロヱ",
    game: "Tavern Manager Simulator",
    genre: "sim",
    format: "multi",
    videos: [
      { title: "【 Tavern Manager Simulator 】ビアガールになって酒場を復興させる！ 酒場経営シミュレーター！ 【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=WLHtQmZfUjc", publishedDate: "2024-11-03" },
      { title: "【 Tavern Manager Simulator 】はい！しゅわしゅわ一丁！ 酒場経営シミュレーターやるぞおおおお 【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=9zKB_2bScm0", publishedDate: "2024-11-23" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-225",
    title: "ゼルダの伝説 ティアーズ オブ ザ キングダム 配信まとめ",
    streamer: "沙花叉クロヱ",
    game: "ゼルダの伝説 ティアーズ オブ ザ キングダム",
    genre: "action",
    format: "multi",
    videos: [
      { title: "#1【新作】人生初のゼルダわっくわくどきどき！ゼルダの伝説　ティアーズ オブ ザ キングダム初見プレイ【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=9f5DrJSH8Ik", publishedDate: "2023-05-13" },
      { title: "#2【新作】人生初のゼルダ！まさかのゼルダがリンクでした ゼルダの伝説　ティアーズ オブ ザ キングダム初見プレイ【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=Hc2wjRf4eyw", publishedDate: "2023-05-22" },
      { title: "#3【新作】人生初のゼルダ！車が高床式になってしまうシャチ ゼルダの伝説　ティアーズ オブ ザ キングダム初見プレイ【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=pWwFIuhrktc", publishedDate: "2023-05-24" },
      { title: "#4【新作】人生初のゼルダ！各地の村からみかじめを求める勇者！それが沙花叉 オブ ザ キングダム初見プレイ【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=FUmSyEn1kNI", publishedDate: "2023-06-02" },
      { title: "【 ティアキン 】ここはどこ主人公ってゼルダ？記憶全ロスで挑むゼルダの伝説ティアーズオブキングダム実況【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=k3TD8Z9PusM", publishedDate: "2023-09-18" },
      { title: "【 ティアキン 】人生初ゼルダが神ゲーすぎる件について！ゼルダの伝説ティアーズオブキングダム【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=Ue2E11eHvto", publishedDate: "2023-09-19" },
      { title: "【 ティアキン 】人生初ゼルダ！ゾーラの里をお掃除します♡ゼルダの伝説ティアーズオブキングダム【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=4r6rvqh_-6M", publishedDate: "2023-09-26" },
      { title: "【 ティアキン 】人生初ゼルダ！最後の異変調査！ゼルダの伝説ティアーズオブキングダム【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=YxQE6H0BO6c", publishedDate: "2023-10-23" },
      { title: "【 ティアキン 】全員記憶を失くした5か月ぶりのゼルダ ゼルダの伝説ティアーズオブキングダム【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=6jv14r3qZzc", publishedDate: "2024-03-09" },
      { title: "【 ティアキン 】地上絵の秘密が明らかに！ 龍の泪 編！ ゼルダの伝説ティアーズオブキングダム【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=TGsGKjFUp2M", publishedDate: "2024-03-21" },
      { title: "【 ティアキン 】ついにクライマックス！呪われたハイラル城へ… ゼルダの伝説ティアーズオブキングダム【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=OXrSzV6CEJ0", publishedDate: "2024-07-21" },
      { title: "【 ティアキン 】そろそろハイラル城を救うぞぉおおおおお…！！！ ゼルダの伝説ティアーズオブキングダム【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=T4qJ6Bmt8fk", publishedDate: "2024-10-22" },
      { title: "【 ティアキン 】ラスボス前に強化間に合わせるぞ～～～！！！の回 ゼルダの伝説ティアーズオブキングダム【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=8ZOjfTN3k90", publishedDate: "2024-10-31" },
      { title: "【 ティアキン 】未強化の縛りをいざ解かん…！！！ ゼルダの伝説ティアーズオブキングダム【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=8d2nAFVOuSM", publishedDate: "2024-11-25" },
      { title: "【 ティアキン 】ラスボス前に最強の剣、マスタードソースを探す！ ゼルダの伝説ティアーズオブキングダム【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=D9uZEBf0JCg", publishedDate: "2024-12-15" },
      { title: "【 ティアキン 】いざ最終回！ラスボスへ！ ゼルダの伝説ティアーズオブキングダム【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=JK417zyxs4g", publishedDate: "2025-01-22" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-226",
    title: "【 重大告知あり 】不穏なタイピングゲームでミスタイプはゆるされますか…？ DYPING",
    streamer: "沙花叉クロヱ",
    game: "DYPING",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【 重大告知あり 】不穏なタイピングゲームでミスタイプはゆるされますか…？ DYPING【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=fSx6krtjzEA", publishedDate: "2025-01-17" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-227",
    title: "【 違う冬のぼくら 】こよクロで景色も出来事も、それぞれ違う冬を旅する！",
    streamer: "沙花叉クロヱ",
    game: "違う冬のぼくら",
    genre: "other",
    format: "single",
    videos: [
      { title: "【 違う冬のぼくら 】こよクロで景色も出来事も、それぞれ違う冬を旅する！【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=u5hBkM77dX0", publishedDate: "2025-01-14" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-228",
    title: "風来のシレン6 とぐろ島探検録 配信まとめ",
    streamer: "沙花叉クロヱ",
    game: "風来のシレン6 とぐろ島探検録",
    genre: "rpg",
    format: "multi",
    videos: [
      { title: "【 風来のシレン６ 】人生初めての風来のシレン楽しむぞ～～～！ 不思議のダンジョン 風来のシレン６ とぐろ島探検録【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=HAvwPovi7N0", publishedDate: "2024-03-14" },
      { title: "【 風来のシレン６ 】ここからが本番です！人生初めて初心者シレンジャーの風来のシレン！ 不思議のダンジョン 風来のシレン６ とぐろ島探検録【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=bpJqv0cnbtM", publishedDate: "2024-03-22" },
      { title: "【 風来のシレン６ 】とぐろ島を越えて…！人生初めて初心者シレンジャーの風来のシレン！ 不思議のダンジョン 風来のシレン６ とぐろ島探検録【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=HQkN-SjKaHQ", publishedDate: "2024-06-30" },
      { title: "【 風来のシレン６ 】お買い物上手の修験道いってみよ！人生初めて初心者シレンジャーの風来のシレン！ 不思議のダンジョン 風来のシレン６ とぐろ島探検録【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=svLFs4nltEs", publishedDate: "2024-07-11" },
      { title: "【 風来のシレン６ 】人生初シレン！お正月だしまったり一緒に夜更かし楽しも～～！ 不思議のダンジョン 風来のシレン６ とぐろ島探検録【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=4mrBjN_YdkM", publishedDate: "2025-01-01" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-229",
    title: "【 Get To Work 】お金も髪の毛もナイおじさんを飛ばす",
    streamer: "沙花叉クロヱ",
    game: "Get To Work",
    genre: "sim",
    format: "single",
    videos: [
      { title: "【 Get To Work 】お金も髪の毛もナイおじさんを飛ばす【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=42Rdim2lVDk", publishedDate: "2024-12-21" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-230",
    title: "DON'T SCREAM 配信まとめ",
    streamer: "沙花叉クロヱ",
    game: "DON'T SCREAM",
    genre: "horror",
    format: "multi",
    videos: [
      { title: "【 DON'T SCREAM 】絶対に叫ぶな！絶対だぞ！！！叫んだらリセぽちされるホラーゲーム！【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=m3zA80QwiG0", publishedDate: "2024-05-21" },
      { title: "【 DON'T SCREAM 】叫んだらやり直し！最恐ホラーゲーム再び…！【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=Z5S_LGXBY88", publishedDate: "2024-11-20" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-231",
    title: "Poppy Playtime 配信まとめ",
    streamer: "沙花叉クロヱ",
    game: "Poppy Playtime",
    genre: "horror",
    format: "multi",
    videos: [
      { title: "【 Poppy Playtime 】ホラー耐性０シャチ、いきます【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=qqbIqmx8ovk", publishedDate: "2024-03-12" },
      { title: "【 Poppy Playtime2 】び、びびビビってないし…！ ホラーゲーム 初見プレイ 【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=89xHdDcxYeE", publishedDate: "2024-11-10" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-232",
    title: "Planet Coaster 配信まとめ",
    streamer: "沙花叉クロヱ",
    game: "Planet Coaster",
    genre: "sim",
    format: "multi",
    videos: [
      { title: "【 Planet Coaster 】そうだ、理想の遊園地を作ろう！ 【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=EN0k9MQcLvE", publishedDate: "2024-09-14" },
      { title: "【 Planet Coaster 】予算4000ドル、来客0から理想のパークを作る！ 【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=kf3UOEOisr4", publishedDate: "2024-09-16" },
      { title: "【 Planet Coaster 】予算4000ドル→借金地獄！だけど遊園地を成功させたい！ 【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=uGUffqFXLqA", publishedDate: "2024-09-18" },
      { title: "【 Planet Coaster 】制限時間120分で自作コースターを設置したい！ 【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=JmNCKdLTMoQ", publishedDate: "2024-09-22" },
      { title: "【 Planet Coaster 】次回作出る前に遊園地完成させちゃうぞ～～！！！ 【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=fvIoREW2O2I", publishedDate: "2024-10-26" },
      { title: "【 Planet Coaster 】進捗最高です！次回作までにパークを完成させたい！ 【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=jlhH-oBCjpk", publishedDate: "2024-10-27" },
      { title: "【 Planet Coaster 】最終回！ついに北極 (パーク名) を完成させます！ 【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=Fii_wJbwCtI", publishedDate: "2024-11-06" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-233",
    title: "TCG Card Shop Simulator 配信まとめ",
    streamer: "沙花叉クロヱ",
    game: "TCG Card Shop Simulator",
    genre: "sim",
    format: "multi",
    videos: [
      { title: "【 TCG Card Shop Simulator 】 復帰早々、カドショオープンします！！！！！！【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=yYEFbP8C22o", publishedDate: "2024-10-02" },
      { title: "【 TCG Card Shop Simulator 】 大物新人バイトくん()が来てしまった前途多難なカードショップ！【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=8UKjUHKw-Q4", publishedDate: "2024-10-06" },
      { title: "【 TCG Card Shop Simulator 】 ㊗高額カード出てます！！！エピックパックは今が買い、どうぞお買い求めください！！！【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=xPcbr-Av9iQ", publishedDate: "2024-10-07" },
      { title: "【 TCG Card Shop Simulator 】 目指せ100万超え＆店舗拡大！！【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=R4CGKpwAMT0", publishedDate: "2024-10-13" },
      { title: "【 TCG Card Shop Simulator 】 カドショ777でカードを買ったら彼女ができました！【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=gGi-wzv-sT0", publishedDate: "2024-10-19" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-234",
    title: "お宝マウンテン 配信まとめ",
    streamer: "沙花叉クロヱ",
    game: "お宝マウンテン",
    genre: "other",
    format: "multi",
    videos: [
      { title: "【 holoindie 】 新作のお宝マウンテンであそぶぅうううううう！！！【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=gBPCxratYzQ", publishedDate: "2024-08-03" },
      { title: "【 holoindie 】 holoX参戦！塩シャチ作りたい♡お宝マウンテン【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=BIgDNI1ZgNU", publishedDate: "2024-08-11" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-235",
    title: "【 推理 】ドア越しにストーカーと会話するヤンデレゲー Inverted Angel",
    streamer: "沙花叉クロヱ",
    game: "Inverted Angel",
    genre: "other",
    format: "single",
    videos: [
      { title: "【 推理 】ドア越しにストーカーと会話するヤンデレゲー Inverted Angel【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=J-EgEMJ4jb0", publishedDate: "2024-08-05" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-236",
    title: "【 僕、アルバイトォォ！！ 】お帰りくださいませ、ご主人様♡",
    streamer: "沙花叉クロヱ",
    game: "僕、アルバイトォォ！！",
    genre: "sim",
    format: "single",
    videos: [
      { title: "【 僕、アルバイトォォ！！ 】お帰りくださいませ、ご主人様♡【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=-SAYpK8Sa5Y", publishedDate: "2024-07-19" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-237",
    title: "Chained Together 配信まとめ",
    streamer: "沙花叉クロヱ",
    game: "Chained Together",
    genre: "action",
    format: "multi",
    videos: [
      { title: "【 Chained Together 】一人落ちたらやり直し！かなけんの絆が試される！！！【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=WqXTH-tcvmA", publishedDate: "2024-06-27" },
      { title: "【 Chained Together 】鎖に繋がれかなけんの絆が試される…！【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=2ou6x1eOpYA", publishedDate: "2024-07-15" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-238",
    title: "モンスターハンター：ワールド 配信まとめ",
    streamer: "沙花叉クロヱ",
    game: "モンスターハンター：ワールド",
    genre: "action",
    format: "multi",
    videos: [
      { title: "【 MHW 】ついに来た！ モンハンワールド 初心者ハンター！【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=HPlAgnWMc6Y", publishedDate: "2024-03-30" },
      { title: "【 MHW 】参加型も！ モンハンワールド 初心者双剣ハンター！【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=7I_L1WVodjM", publishedDate: "2024-03-31" },
      { title: "【 モンハンワールド 】参加型あり！ソロでつよつよモンスター捕獲するぞぉおおお！ 初心者双剣ハンター MHW【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=sk75vLlWWkM", publishedDate: "2024-04-01" },
      { title: "【 モンハンワールド 】ついにソロハン卒業！こよクロ上位クエ無双だ！！！【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=gmoYASlEs2I", publishedDate: "2024-04-04" },
      { title: "【 モンハンワールド 】参加型あり！ついに上位クエスト突入だぁあああ！！ 初心者双剣ハンター MHW【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=0shFmIWr_xk", publishedDate: "2024-04-07" },
      { title: "【 モンハンワールド 】古龍三体討伐IKZZZZZ！！ 初心者双剣ハンター MHW【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=FU1ceVRWZTA", publishedDate: "2024-04-10" },
      { title: "【 モンハンワールド 】ついにアイスボーンに突入だ！つよつよモンスターかかってこい！！ 初心者双剣ハンター MHW【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=5L5crwZ7QR8", publishedDate: "2024-04-16" },
      { title: "【 モンハンワールド 】アイスボーンでベリオロス討伐するぞおおおお！！！ 初心者双剣ハンター MHW【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=WAZ2cJNT_jY", publishedDate: "2024-04-29" },
      { title: "【 モンハンワールド 】ついにイヴェルカーナ討伐するぞおおおお！！！ 初心者双剣ハンター MHW アイスボーン【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=dAvv8Bg92Qo", publishedDate: "2024-04-30" },
      { title: "【 モンハンワールド 】今度こそイヴェルカーナ討伐するぞおおおお！！！ 初心者双剣ハンター MHW アイスボーン【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=Fzyn7zSXEN8", publishedDate: "2024-05-05" },
      { title: "【 モンハンワールド 】いい加減ガチでイヴェルカーナ討伐しにいきます！ 初心者双剣ハンター MHW アイスボーン【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=YvOUD9wFbOc", publishedDate: "2024-05-11" },
      { title: "【 モンハンワールド 】レイギエナぁあああああああああ！！！！ 初心者双剣ハンター MHW アイスボーン【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=dpwqjqF5OiI", publishedDate: "2024-05-25" },
      { title: "【 モンハンワールド 】ネロミェール戦いくぞぉおおおお！！！ 初心者双剣ハンター MHW アイスボーン【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=B278Brr5Puw", publishedDate: "2024-06-08" },
      { title: "【 モンハンワールド 】ラスボス戦！大いなる存在倒す！！！ 初心者双剣ハンター MHW アイスボーン【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=gFmjYZBvJMY", publishedDate: "2024-06-23" },
      { title: "【 モンハンワールド 】フルパで一狩りいくぞぉおおお！双剣で暴れます！ MHW アイスボーン【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=_w4kQ_8SVRU", publishedDate: "2024-07-04" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-239",
    title: "Among Us 配信まとめ",
    streamer: "沙花叉クロヱ",
    game: "Among Us",
    genre: "other",
    format: "multi",
    videos: [
      { title: "【アモアス】久々にお掃除しちゃいますか！/ホロAmongUs【沙花叉クロヱ/ホロライブ】", url: "https://www.youtube.com/watch?v=d9FWj93G42o", publishedDate: "2022-11-25" },
      { title: "【#ホロAmongUs】ほろ酔いでどんどん崩壊していくアモングアス！【沙花叉クロヱ/ホロライブ】", url: "https://www.youtube.com/watch?v=Gj_SJgmXy2w", publishedDate: "2022-12-26" },
      { title: "【#突発ホロライブ】久しぶりの突発Among Us！アモングアスだ～～～！【沙花叉クロヱ/ホロライブ】", url: "https://www.youtube.com/watch?v=Fr6ijJdZgzw", publishedDate: "2023-05-08" },
      { title: "【 #ホロAmongUs 】 1年に1度の掃除屋タイム！ AmongUs【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=LoSe9lsuCnE", publishedDate: "2024-06-04" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-240",
    title: "【 Buckshot Roulette 】ギャンブラー沙花叉クロヱに勝てない勝負はない。",
    streamer: "沙花叉クロヱ",
    game: "Buckshot Roulette",
    genre: "other",
    format: "single",
    videos: [
      { title: "【 Buckshot Roulette 】ギャンブラー沙花叉クロヱに勝てない勝負はない。【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=JM0zrYOM_IQ", publishedDate: "2024-04-21" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-241",
    title: "【 迷宮校舎 】先輩、守ってください…！ #しゃちいぬ",
    streamer: "沙花叉クロヱ",
    game: "迷宮校舎",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【 迷宮校舎 】先輩、守ってください…！ #しゃちいぬ【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=JARBvCaUT20", publishedDate: "2024-03-26" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-242",
    title: "【 Lethal Company 】はじめてのリーサルカンパニー！先輩方、引率よろしくお願いします！",
    streamer: "沙花叉クロヱ",
    game: "Lethal Company",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【 Lethal Company 】はじめてのリーサルカンパニー！先輩方、引率よろしくお願いします！【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=vOxP60evAmQ", publishedDate: "2024-03-24" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-243",
    title: "【 Pacific Drive 】沙花叉運転の危険なドライブ！超常現象もあるよ！",
    streamer: "沙花叉クロヱ",
    game: "Pacific Drive",
    genre: "sim",
    format: "single",
    videos: [
      { title: "【 Pacific Drive 】沙花叉運転の危険なドライブ！超常現象もあるよ！【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=kAKPnIfD9g0", publishedDate: "2024-03-13" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-244",
    title: "Palworld 配信まとめ",
    streamer: "沙花叉クロヱ",
    game: "Palworld",
    genre: "sandbox",
    format: "multi",
    videos: [
      { title: "【 PALWORLD 】ついにログインできたパルワールドぉおおおおおおお！！！！！【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=WG94XpAYrus", publishedDate: "2024-01-26" },
      { title: "【 PALWORLD 】グランモスLv38に挑む初心者！倒すぞぉおおおお！！！【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=1o8BQUjSccI", publishedDate: "2024-01-28" },
      { title: "【 PALWORLD 】スプラドンLv30捕獲作戦始動です！他ボスも…？【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=lO4wbzm8fko", publishedDate: "2024-02-04" },
      { title: "【 PALWORLD 】超難易度！レヴィドラLv45に初心者が挑みます！！【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=DfoHUhT_q7I", publishedDate: "2024-02-05" },
      { title: "【 PALWORLD 】ボス戦！パリピドンとムラクモ捕まえたい！！【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=Ii8-vk2qqqI", publishedDate: "2024-02-27" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-245",
    title: "【 8番出口 】 GPS来いGPS来いｯGPS来いぃいいいッ！！！！！！",
    streamer: "沙花叉クロヱ",
    game: "8番出口",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【 8番出口 】 GPS来いGPS来いｯGPS来いぃいいいッ！！！！！！【沙花叉クロヱ/ホロライブ】", url: "https://www.youtube.com/watch?v=GZmpASTXEFk", publishedDate: "2023-12-06" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-246",
    title: "【Refind Self】きゃ～～沙花叉の可愛い性格がバレちゃう～～～＞＜",
    streamer: "沙花叉クロヱ",
    game: "Refind Self",
    genre: "other",
    format: "single",
    videos: [
      { title: "【Refind Self】きゃ～～沙花叉の可愛い性格がバレちゃう～～～＞＜【沙花叉クロヱ/ホロライブ】", url: "https://www.youtube.com/watch?v=A0Hl_7XFVnQ", publishedDate: "2023-11-16" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-247",
    title: "【 誘拐事件 】ガチで怖いと話題のチラズアートさんの新作ホラーゲームやるぞ！",
    streamer: "沙花叉クロヱ",
    game: "誘拐事件",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【 誘拐事件 】ガチで怖いと話題のチラズアートさんの新作ホラーゲームやるぞ！【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=O7paiuX1l60", publishedDate: "2023-11-02" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-248",
    title: "スイカゲーム 配信まとめ",
    streamer: "沙花叉クロヱ",
    game: "スイカゲーム",
    genre: "puzzle",
    format: "multi",
    videos: [
      { title: "【 スイカゲーム 】初見で3000スコア出しちゃいます！！！【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=hKonM8-RooI", publishedDate: "2023-10-10" },
      { title: "【 スイカゲーム 】勝つのはどっち！？#ベークロ 並走スコア対決！【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=o3U_d7d2ek8", publishedDate: "2023-10-30" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-249",
    title: "Starfield 配信まとめ",
    streamer: "沙花叉クロヱ",
    game: "Starfield",
    genre: "rpg",
    format: "multi",
    videos: [
      { title: "【 STARFIELD 】宇宙の惑星を探索して収集！建設！戦闘！【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=C9vIEukw48I", publishedDate: "2023-10-11" },
      { title: "【 STARFIELD 】宇宙の謎を解くカギは……え、沙花叉ですか！？【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=C5U6avOl6HU", publishedDate: "2023-10-13" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-250",
    title: "ONLY UP! 配信まとめ",
    streamer: "沙花叉クロヱ",
    game: "ONLY UP!",
    genre: "action",
    format: "multi",
    videos: [
      { title: "【Only Up!】初見プレイ!! 休止中にみんな空登ってた【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=1J76tLhX6RI", publishedDate: "2023-07-10" },
      { title: "【Only Up!】3時間登ったら変わらぬ景色がそこにありました【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=uEc-TOGCtf4", publishedDate: "2023-07-21" },
      { title: "【Only Up!】登らせてえええええええええええええええええ【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=Ko50Y_S0zBw", publishedDate: "2023-08-03" },
      { title: "【Only Up!】例のアレで無事落下したシャチが０から登るぞおおおおおおおお【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=caUy9pftWmM", publishedDate: "2023-08-14" },
      { title: "【Only Up!】ついに最終回！？ドラゴンの唐揚げつくる♡【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=llAYNr1V9Hs", publishedDate: "2023-09-14" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-251",
    title: "【 パラソーシャル 】新人Vtuberの沙花叉クロヱですっ！ホラーゲームをやっていくよ！",
    streamer: "沙花叉クロヱ",
    game: "パラソーシャル",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【 パラソーシャル 】新人Vtuberの沙花叉クロヱですっ！ホラーゲームをやっていくよ！【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=erVcXSSdX3s", publishedDate: "2023-09-12" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-252",
    title: "【 漢字でGO 】余裕でしょｗネプ〇ーグ風の漢字クイズに挑戦だ～～！",
    streamer: "沙花叉クロヱ",
    game: "漢字でGO!",
    genre: "other",
    format: "single",
    videos: [
      { title: "【 漢字でGO 】余裕でしょｗネプ〇ーグ風の漢字クイズに挑戦だ～～！【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=Z4WhsjyePKE", publishedDate: "2023-09-03" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-253",
    title: "【完全初見プレイ】人生初カービィは君に決めた！星のカービィスーパーデラックスでホロサマビンゴ開ける！",
    streamer: "沙花叉クロヱ",
    game: "星のカービィ スーパーデラックス",
    genre: "action",
    format: "single",
    videos: [
      { title: "【完全初見プレイ】人生初カービィは君に決めた！星のカービィスーパーデラックスでホロサマビンゴ開ける！【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=Txy7juIjctc", publishedDate: "2023-08-22" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-254",
    title: "【つぐのひ】マリン先輩何があったんですか！！！美魔女の真実マリンの秘宝船",
    streamer: "沙花叉クロヱ",
    game: "つぐのひ",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【つぐのひ】マリン先輩何があったんですか！！！美魔女の真実マリンの秘宝船【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=D5kYN0ucG0k", publishedDate: "2023-08-15" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-255",
    title: "【グルーヴコースター ワイワイパーティー!!!!】沙花叉が音ゲーに登場だああああああ！！！",
    streamer: "沙花叉クロヱ",
    game: "グルーヴコースター ワイワイパーティー",
    genre: "other",
    format: "single",
    videos: [
      { title: "【グルーヴコースター ワイワイパーティー!!!!】沙花叉が音ゲーに登場だああああああ！！！【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=Yi5lCzcEhWs", publishedDate: "2023-08-12" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-256",
    title: "【#カプとれ】大量ＧＥＴ！？クレーンゲームの腕前、ついに見せちゃうか～～～～！",
    streamer: "沙花叉クロヱ",
    game: "カプとれ",
    genre: "other",
    format: "single",
    videos: [
      { title: "【#カプとれ】大量ＧＥＴ！？クレーンゲームの腕前、ついに見せちゃうか～～～～！【ホロライブ/沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=E32TImrvRUo", publishedDate: "2023-05-26" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-257",
    title: "【#こよクロ】まさかの1年ぶりに再結成！WE WERE HERE TOGETHER",
    streamer: "沙花叉クロヱ",
    game: "We Were Here",
    genre: "puzzle",
    format: "single",
    videos: [
      { title: "【#こよクロ】まさかの1年ぶりに再結成！WE WERE HERE TOGETHER【沙花叉クロヱ/ホロライブ】", url: "https://www.youtube.com/watch?v=gpJGXG5fvQI", publishedDate: "2023-04-18" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-258",
    title: "【MINDHACK】悪人の脳内をお花畑に洗脳しちゃうぞ！ぽえぽえ～",
    streamer: "沙花叉クロヱ",
    game: "MINDHACK",
    genre: "other",
    format: "single",
    videos: [
      { title: "【MINDHACK】悪人の脳内をお花畑に洗脳しちゃうぞ！ぽえぽえ～【沙花叉クロヱ/ホロライブ】", url: "https://www.youtube.com/watch?v=U2qETvtqPgk", publishedDate: "2023-04-14" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-259",
    title: "【Q REMASTERED】激ムズ物理演算パズル！シャチはかしこい…！！！はず………",
    streamer: "沙花叉クロヱ",
    game: "Q REMASTERED",
    genre: "puzzle",
    format: "single",
    videos: [
      { title: "【Q REMASTERED】激ムズ物理演算パズル！シャチはかしこい…！！！はず………【沙花叉クロヱ/ホロライブ】", url: "https://www.youtube.com/watch?v=rav7Gr38iRs", publishedDate: "2023-04-02" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-260",
    title: "【アソビ大全】相性最悪な地獄のコラボが始まるようです…#ポルカオルカ",
    streamer: "沙花叉クロヱ",
    game: "世界のアソビ大全51",
    genre: "other",
    format: "single",
    videos: [
      { title: "【アソビ大全】相性最悪な地獄のコラボが始まるようです…#ポルカオルカ【沙花叉クロヱ/ホロライブ】", url: "https://www.youtube.com/watch?v=zV9zrrYBiOM", publishedDate: "2023-03-14" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-261",
    title: "バイオハザード ヴィレッジ 配信まとめ",
    streamer: "沙花叉クロヱ",
    game: "バイオハザード ヴィレッジ",
    genre: "horror",
    format: "multi",
    videos: [
      { title: "【#1】今時レアな完全初見プレイで神ストーリーと話題のバイオハザード ヴィレッジ！Resident Evil Village【沙花叉クロヱ/ホロライブ】", url: "https://www.youtube.com/watch?v=C1D4AhmdRZM", publishedDate: "2023-02-04" },
      { title: "【#2】ドミトレスク討伐後、今時レアな完全初見プレイで神ストーリーと話題のバイオハザード ヴィレッジ！Resident Evil Village【沙花叉クロヱ/ホロライブ】", url: "https://www.youtube.com/watch?v=5OEcEz4FsPw", publishedDate: "2023-02-11" },
      { title: "【#3】ついにハイゼンベルク戦へ！今時レアな完全初見プレイで神ストーリーと話題のバイオハザード ヴィレッジ！Resident Evil Village【沙花叉クロヱ/ホロライブ】", url: "https://www.youtube.com/watch?v=rBPb6qTjRYM", publishedDate: "2023-02-26" },
      { title: "【#4】ラスボス、ミランダ戦へ…今時レアな完全初見プレイで神ストーリーと話題のバイオハザード ヴィレッジ！Resident Evil Village【沙花叉クロヱ/ホロライブ】", url: "https://www.youtube.com/watch?v=sWH5SmUwBzQ", publishedDate: "2023-03-04" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-262",
    title: "【Melatonin】チルいリズムゲーで遊んでみる！",
    streamer: "沙花叉クロヱ",
    game: "Melatonin",
    genre: "other",
    format: "single",
    videos: [
      { title: "【Melatonin】チルいリズムゲーで遊んでみる！【沙花叉クロヱ/ホロライブ】", url: "https://www.youtube.com/watch?v=D0hIluk1yl8", publishedDate: "2023-03-02" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-263",
    title: "帰ってきた魔界村 配信まとめ",
    streamer: "沙花叉クロヱ",
    game: "帰ってきた魔界村",
    genre: "action",
    format: "multi",
    videos: [
      { title: "【重大告知あり】遂に帰ってきた魔界村に挑戦…！【沙花叉クロヱ/ホロライブ】", url: "https://www.youtube.com/watch?v=9Qw2L4WIbBM", publishedDate: "2022-12-02" },
      { title: "【鬼畜ゲー】絶対クリアする！帰ってきた魔界村に挑戦…！初見プレイ【沙花叉クロヱ/ホロライブ】", url: "https://www.youtube.com/watch?v=STsbgmWNAzg", publishedDate: "2022-12-06" },
      { title: "【2面クリア耐久】絶対にイライラしない帰ってきた魔界村！【沙花叉クロヱ/ホロライブ】", url: "https://www.youtube.com/watch?v=3BIVJ_qoOZA", publishedDate: "2022-12-30" },
      { title: "【3面クリア耐久】絶対に叫んではいけない、おしとやかに帰ってきた魔界村！【沙花叉クロヱ/ホロライブ】", url: "https://www.youtube.com/watch?v=TTeopa_tO90", publishedDate: "2023-01-17" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-264",
    title: "GeoGuessr 配信まとめ",
    streamer: "沙花叉クロヱ",
    game: "GeoGuessr",
    genre: "other",
    format: "multi",
    videos: [
      { title: "【GeoGuessr】地図は読めず都道府県は言えず現在地すら指をさせないシャチ【沙花叉クロヱ/ホロライブ】", url: "https://www.youtube.com/watch?v=6FSfScdgc6g", publishedDate: "2023-01-12" },
      { title: "【GeoGuessr】観光地縛りなら地図読めなくてもいけます！(？)【沙花叉クロヱ/ホロライブ】", url: "https://www.youtube.com/watch?v=XYFZnTzTyH4", publishedDate: "2023-01-15" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-265",
    title: "マリオカート8 デラックス 配信まとめ",
    streamer: "沙花叉クロヱ",
    game: "マリオカート8 デラックス",
    genre: "racing",
    format: "multi",
    videos: [
      { title: "【マリカ8DX】9位以下即終了で大会練習だぁああああああああ【沙花叉クロヱ/ホロライブ】", url: "https://www.youtube.com/watch?v=JpcS7BeHe2Y", publishedDate: "2022-12-27" },
      { title: "【#ホロお正月CUP2023】Aチーム本番ジャイロオフ、ガチでおしとやかに挑みます！！！マリカ8DX【沙花叉クロヱ/ホロライブ】", url: "https://www.youtube.com/watch?v=WklOPZAcU3A", publishedDate: "2023-01-07" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-266",
    title: "バイオハザード7 レジデント イービル 配信まとめ",
    streamer: "沙花叉クロヱ",
    game: "バイオハザード7 レジデント イービル",
    genre: "horror",
    format: "multi",
    videos: [
      { title: "【バイオ7】超絶びびりのBIOHAZARD 7初見プレイ！RESIDENT EVIL#1【沙花叉クロヱ/ホロライブ】", url: "https://www.youtube.com/watch?v=3lV_4bJm0Og", publishedDate: "2022-12-10" },
      { title: "【バイオ7】超絶びびりのBIOHAZARD 7初見プレイ！土日クリア耐久！RESIDENT EVIL#2【沙花叉クロヱ/ホロライブ】", url: "https://www.youtube.com/watch?v=FCOGONWkVZ8", publishedDate: "2022-12-17" },
      { title: "【バイオ7】DLCのNot a hero初見プレイ！RESIDENT EVIL#3【沙花叉クロヱ/ホロライブ】", url: "https://www.youtube.com/watch?v=FOVg9gzVhSg", publishedDate: "2022-12-18" },
      { title: "【バイオ7】DLCのEND OF ZOE初見プレイ！RESIDENT EVIL#4【沙花叉クロヱ/ホロライブ】", url: "https://www.youtube.com/watch?v=mdwu80_dxh8", publishedDate: "2022-12-23" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-267",
    title: "【A Little to the Left】部屋片づけたいのに猫が邪魔してくる！！！！",
    streamer: "沙花叉クロヱ",
    game: "A Little to the Left",
    genre: "puzzle",
    format: "single",
    videos: [
      { title: "【A Little to the Left】部屋片づけたいのに猫が邪魔してくる！！！！【沙花叉クロヱ/ホロライブ】", url: "https://www.youtube.com/watch?v=CehiimRZ9Fk", publishedDate: "2022-12-13" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-22"
  },
  {
    id: "single-268",
    title: "Minecraft 配信まとめ",
    streamer: "紫咲シオン",
    game: "Minecraft",
    genre: "sandbox",
    format: "multi",
    videos: [
      { title: "【マイクラ】ぽんこつ二人の新生活！", url: "https://www.youtube.com/watch?v=USmBGqUDOfY", publishedDate: "2018-11-14" },
      { title: "【マイクラ】お昼のまったりMinecraft！！Part２", url: "https://www.youtube.com/watch?v=MPRpZrPReYk", publishedDate: "2018-12-14" },
      { title: "【マイクラ】ホロライブクラフト開会式！紫咲シオン視点【ホロライブサーバー】", url: "https://www.youtube.com/watch?v=7G1hSXQ6UkU", publishedDate: "2018-12-14" },
      { title: "【マイクラ】洞窟から宝を探せ！！！！", url: "https://www.youtube.com/watch?v=zwGisN4dT0M", publishedDate: "2018-12-15" },
      { title: "【マイクラ】お昼のまったりMinecraft！！", url: "https://www.youtube.com/watch?v=cGWHep9v94Q", publishedDate: "2018-12-17" },
      { title: "【マイクラ】ホロサバにいたずらする…！？", url: "https://www.youtube.com/watch?v=4adUk5vt1L8", publishedDate: "2018-12-17" },
      { title: "【マイクラ】お昼のまったりMinecraft！！", url: "https://www.youtube.com/watch?v=obydHQxxcx4", publishedDate: "2018-12-18" },
      { title: "【マイクラ】お昼のまったりMinecraft！！", url: "https://www.youtube.com/watch?v=ouWTNgzOMT8", publishedDate: "2018-12-19" },
      { title: "【マイクラ】午後のまったりMinecraft！！", url: "https://www.youtube.com/watch?v=RsGSiLgM9ec", publishedDate: "2018-12-22" },
      { title: "【マイクラ】午後のまったりMinecraft！！クリスマス！！", url: "https://www.youtube.com/watch?v=w8DjCBqA-Q4", publishedDate: "2018-12-22" },
      { title: "【マイクラ】午後のまったりMinecraft！！お正月！！", url: "https://www.youtube.com/watch?v=I8olmj8Q1lo", publishedDate: "2018-12-30" },
      { title: "【マイクラ】午後のまったりMinecraft！！", url: "https://www.youtube.com/watch?v=1-dFua3_7Kw", publishedDate: "2018-12-31" },
      { title: "【マイクラ】久しぶりのMinecraft！！いろいろ変わった？！", url: "https://www.youtube.com/watch?v=RvfNsXt466M", publishedDate: "2019-01-11" },
      { title: "【マインクラフト】二人で初めての共同生活♡【#塩パン】", url: "https://www.youtube.com/watch?v=DKJiYe1NK_8", publishedDate: "2019-04-16" },
      { title: "【Minecraft】いろいろ変わったらしいマイクラを遊ぶ！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=dXfEhEoZAuM", publishedDate: "2019-05-21" },
      { title: "【Minecraft】盗んだ物資で生活してく。【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=DtSZCUZi3Ns", publishedDate: "2019-05-24" },
      { title: "【Minecraft】宝石ほしい！まったり地下探索【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=7DVH-K-0lvA", publishedDate: "2019-06-01" },
      { title: "【Minecraft】エンチャントしたい！宝石ほしい！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=aZIz9xgVn5s", publishedDate: "2019-06-04" },
      { title: "【Minecraft】ダイヤ見つける！！最強PCでマイクラやるぞ～【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=cWE6VVgqiAs", publishedDate: "2019-06-08" },
      { title: "【Minecraft】まったり地下探索！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=LfXRi2dZ-mA", publishedDate: "2019-06-16" },
      { title: "【Minecraft】自由な3人で共同生活！？マイクラ！【ホロライブ/紫咲シオン/猫又おかゆ/戌神ころね】", url: "https://www.youtube.com/watch?v=vkXu6pmIGig", publishedDate: "2019-06-23" },
      { title: "【Minecraft】寝起きのマイクラ！ここをキャンプ地とする！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=pJEpfwm5F4M", publishedDate: "2019-08-14" },
      { title: "【Minecraft】ゆるーいマイクラ！気づいたら略奪者と戦ってた。【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=k7hsPgmbPJI", publishedDate: "2019-08-18" },
      { title: "【Minecraft】ゆるーいマイクラ！今日こそ豪邸を建てるぞ～！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=ETJID1ptHNw", publishedDate: "2019-08-20" },
      { title: "【Minecraft】これぞ青春。まったりマイクラ生活！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=_iy9rSG7exw", publishedDate: "2019-08-24" },
      { title: "【Minecraft】激レア！茶色のパンダ探し！！#ホロ鯖【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=bEdcE5SVT8c", publishedDate: "2019-09-01" },
      { title: "【Minecraft】ダイヤを求めて三千里。マグマプールだぁ！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=5jx6U6KMB0c", publishedDate: "2019-09-07" },
      { title: "【Minecraft】新ホロ鯖！！大冒険の始まりだー！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=rRHMdn3b0z0", publishedDate: "2019-10-12" },
      { title: "【Minecraft】新ホロ鯖！！裕福な暮らしを目指して・・・【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=rAPqbIpDFy4", publishedDate: "2019-10-14" },
      { title: "【Minecraft】新ホロ鯖！！新居祝いにダイヤがほしい！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=wL7O-tjVVao", publishedDate: "2019-10-15" },
      { title: "【Minecraft】新ホロ鯖！初エンチャントがしたい！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=pVAL7QIdE74", publishedDate: "2019-10-17" },
      { title: "【Minecraft】地図を持って冒険したい！！ホロ鯖旅行！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=k5-H-OQlxP0", publishedDate: "2019-10-21" },
      { title: "【Minecraft】幸運をみて！！！ダイヤ掘ります！！はろうぃ～ん...。【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=IzLFydkjilg", publishedDate: "2019-10-26" },
      { title: "【Minecraft】綺麗すぎて一同涙！！衝撃の観光＆まったり釣り。【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=9Oia0bhZqYs", publishedDate: "2019-10-29" },
      { title: "【Minecraft】ネザーへ行きたい！訴えられるってマ...！？【ホロライブ】", url: "https://www.youtube.com/watch?v=HeSoHcsFIvE", publishedDate: "2019-11-04" },
      { title: "【Minecraft】綺麗な海が見たい！旅に行く！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=A7-kErzNSB4", publishedDate: "2019-11-22" },
      { title: "【Minecraft】新バージョンで蜂さんに会いに行く！！🐝【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=-hBnf6kMhzo", publishedDate: "2019-12-13" },
      { title: "【Minecraft】地獄の生活も悪くない！こっそり生活。【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=FDjRW3pLcoU", publishedDate: "2019-12-15" },
      { title: "【Minecraft】もうすぐクリスマス！！気分はサンタさんで準備する！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=EJehZDVuYvU", publishedDate: "2019-12-20" },
      { title: "【Minecraft】おはようのマイクラ！！クリスマス計画実行！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=JwVHrMby5Y0", publishedDate: "2019-12-20" },
      { title: "【Minecraft】ネザーリベンジ！！今度こそここで生きてく！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=Fd8Pdq535F8", publishedDate: "2019-12-23" },
      { title: "【Minecraft】新春🌸今年の運試し！！お話ししながら掘るぞ～！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=cr0VSEVbdA4", publishedDate: "2020-01-02" },
      { title: "【Minecraft】ポーションを作りたい！！いざ地獄の戦いへ…【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=gFTGvYhu0kc", publishedDate: "2020-01-06" },
      { title: "【Minecraft】伝説のコラボ！！協力して鏡餅を作れるのか...！？【#塩パン/紫咲シオン/戌神ころね】", url: "https://www.youtube.com/watch?v=wqV1LZgD5xo", publishedDate: "2020-01-08" },
      { title: "【Minecraft】資材鯖に行けず大事件が起こりました。【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=U6GmImloQ0U", publishedDate: "2020-01-16" },
      { title: "【Minecraft】家爆発したし…秘密基地に住む！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=Ip0n1rVzFEk", publishedDate: "2020-01-17" },
      { title: "【Minecraft】目指せ地下帝国！！贅沢な暮らしを目指して…。【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=YbMimadqwXg", publishedDate: "2020-01-19" },
      { title: "【Minecraft】欲しいものはお宝！！お宝求めて出発だ！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=W-6ohKTfVVE", publishedDate: "2020-01-21" },
      { title: "【Minecraft】未開拓の地で海底探索！！海賊王になる！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=SWWzFL9K9cw", publishedDate: "2020-01-23" },
      { title: "【Minecraft】いざ、ジャングルへ！！トライデント最強！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=IphUs0dkZuI", publishedDate: "2020-01-26" },
      { title: "【Minecraft】ゼロから始めるハードコアの世界。死んだら即終了！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=Z4jtrc5oYH8", publishedDate: "2020-01-28" },
      { title: "【Minecraft】久しぶりのマイクラ！！！地下探索でダイヤ見つけるぞ～！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=7FIBbQhcMsM", publishedDate: "2020-03-18" },
      { title: "【Minecraft】ホロ鯖！！失われた記憶を取り戻せ！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=FtjZ9uyMe0Q", publishedDate: "2020-05-27" },
      { title: "【Minecraft】ホロ鯖！！深夜のまったり地下探検！！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=mTK7tbCH7DI", publishedDate: "2020-06-02" },
      { title: "【Minecraft】深夜のおしゃべり地下探検！！掘れ…！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=cOo7hsUDR8A", publishedDate: "2020-07-23" },
      { title: "【マインクラフト】久々深夜のマイクラ作業！！プチ報告も！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=bpu2gHmluCA", publishedDate: "2020-09-18" },
      { title: "【Minecraft】深夜のマイクラ！！お引越し大作戦だぁ！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=I7Z3Ti8gZfc", publishedDate: "2020-09-24" },
      { title: "【Minecraft】深夜のホロ鯖！！新居作りする！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=5HIRys4QTT0", publishedDate: "2020-09-26" },
      { title: "【Minecraft】ホロ鯖新居内装作り！！！完成目指して✨【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=-aslVdSaAfU", publishedDate: "2020-09-28" },
      { title: "【Minecraft】深夜のホロ鯖探検！！ん・・・？なにこれ。【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=5GUb02JMabg", publishedDate: "2020-10-01" },
      { title: "【Minecraft】深夜のホロ鯖！！まったりマイクラ✨【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=CsLhIyGyVjk", publishedDate: "2020-10-14" },
      { title: "【Minecraft】ホロ鯖マイクラ！！何が起こるかな～！？【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=nnPvwD2aT08", publishedDate: "2020-10-18" },
      { title: "【Minecraft】久しぶりのホロ鯖！！エンドへ行きたい！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=A2io0-_aM7E", publishedDate: "2020-11-16" },
      { title: "【Minecraft】50万人行くまでひたすら掘る…！！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=6GCEK54QoDc", publishedDate: "2020-11-23" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-23"
  },
  {
    id: "single-269",
    title: "【悲報】友達が別売りだったから一人でやるｗｗｗｗ【1-2-Switch】",
    streamer: "紫咲シオン",
    game: "1-2-Switch",
    genre: "other",
    format: "single",
    videos: [
      { title: "【悲報】友達が別売りだったから一人でやるｗｗｗｗ【1-2-Switch】", url: "https://www.youtube.com/watch?v=HzKkFFc_Ldk", publishedDate: "2019-01-07" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-23"
  },
  {
    id: "single-270",
    title: "Getting Over It 配信まとめ",
    streamer: "紫咲シオン",
    game: "Getting Over It",
    genre: "action",
    format: "multi",
    videos: [
      { title: "鬼畜ゲー？はじめて壺おじさんと遊ぶ！！【getting over it】", url: "https://www.youtube.com/watch?v=3IXn0AqZzOs", publishedDate: "2019-01-19" },
      { title: "鬼畜ゲー？壺おじさんをクリアしたい…【getting over it】", url: "https://www.youtube.com/watch?v=3s1GBZds7ZU", publishedDate: "2019-01-21" },
      { title: "【壺男】みてぇ！！じょーずでしょ？？いらいらしない！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=oUDVqAF4opk", publishedDate: "2020-04-20" },
      { title: "【壺男】暴言言ったら即終了！？清楚にクリア目指す！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=pgZI9o9Ig5U", publishedDate: "2020-04-28" },
      { title: "【壺男】まだ見ぬ世界へ・・！！眠くなるまで壺おじさん！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=mhpnXoZnSEc", publishedDate: "2020-07-06" },
      { title: "【壺男】壺おじクリア耐久！！今日は勝つ・・・【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=-C_mc22cz-o", publishedDate: "2020-07-24" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-23"
  },
  {
    id: "single-271",
    title: "Tetris 99 配信まとめ",
    streamer: "紫咲シオン",
    game: "Tetris 99",
    genre: "puzzle",
    format: "multi",
    videos: [
      { title: "【TETRIS99】テトリスとかいう神ゲー。バトロワ！？", url: "https://www.youtube.com/watch?v=x_HQ6XlAPtA", publishedDate: "2019-02-19" },
      { title: "【TETRIS99】神ゲーテトリスで遊ぶ。バトロワ！？", url: "https://www.youtube.com/watch?v=h_qNHxzMGRE", publishedDate: "2019-03-01" },
      { title: "【テトリス９９】１位を目指して！！ボコボコにする！！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=P6PL8zW2tR4", publishedDate: "2019-12-22" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-23"
  },
  {
    id: "single-272",
    title: "スプラトゥーン2 配信まとめ",
    streamer: "紫咲シオン",
    game: "スプラトゥーン2",
    genre: "fps",
    format: "multi",
    videos: [
      { title: "【スプラトゥーン2】二人でまったりスプラする！！【#塩がゆ】", url: "https://www.youtube.com/watch?v=CHzP69GMs0s", publishedDate: "2019-04-07" },
      { title: "【スプラトゥーン2】みんなでスプラトゥーンする！！", url: "https://www.youtube.com/watch?v=lSVETzAVQSI", publishedDate: "2019-04-10" },
      { title: "【スプラ２】強くなりたいから練習する！！あやめちゃんと！", url: "https://www.youtube.com/watch?v=99TGtZ5vl30", publishedDate: "2019-04-28" },
      { title: "【スプラトゥーン2】お昼からスプラ練習！！いろいろする！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=1mJ_1cReP6w", publishedDate: "2019-05-20" },
      { title: "【スプラトゥーン2】ファイナルフェス！我、混沌なり。【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=AqLUvuRFjHU", publishedDate: "2019-07-21" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-23"
  },
  {
    id: "single-273",
    title: "【おえかきの森】３人は絵を描けるのか…！？【#ねむい組】",
    streamer: "紫咲シオン",
    game: "おえかきの森",
    genre: "other",
    format: "single",
    videos: [
      { title: "【おえかきの森】３人は絵を描けるのか…！？【#ねむい組】", url: "https://www.youtube.com/watch?v=xriXDKKiQHs", publishedDate: "2019-04-21" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-23"
  },
  {
    id: "single-274",
    title: "Apex Legends 配信まとめ",
    streamer: "紫咲シオン",
    game: "Apex Legends",
    genre: "fps",
    format: "multi",
    videos: [
      { title: "【APEX】犬と魔女のチャンピオン物語。【#塩パン】", url: "https://www.youtube.com/watch?v=fgC5cUZStEc", publishedDate: "2019-04-26" },
      { title: "【APEX】二人なら余裕だよね！！ドン勝したい！！【ホロライブ/紫咲シオン/湊あくあ】", url: "https://www.youtube.com/watch?v=QvtGz052dC0", publishedDate: "2020-04-10" },
      { title: "【APEX】ランクアップ修行の旅！！クナイ見てえええ！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=UtAT7oCuvyY", publishedDate: "2020-04-29" },
      { title: "【APEX】紫龍組のラブラブ戦場デート💓いくぞおおおお！！！【ホロライブ/紫咲シオン/桐生ココ】", url: "https://www.youtube.com/watch?v=kPBS_WjgZsI", publishedDate: "2020-05-01" },
      { title: "【APEX】目指せランクアップ！！大切なのは優しい気持ち…。【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=W8rvli4EM-k", publishedDate: "2020-05-04" },
      { title: "【APEX】塩がゆ仲良しAPEX！！チャンピオンになりたい！！【ホロライブ/紫咲シオン/猫又おかゆ】", url: "https://www.youtube.com/watch?v=FWW3kMrO6xA", publishedDate: "2020-05-07" },
      { title: "【APEX】いざ戦場へ！！今日は勝てる気がする！！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=mBEJskRG0HU", publishedDate: "2020-05-11" },
      { title: "【APEX】新シーズン突入！！まったりお昼のあぺ活！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=GVP0Gdl5TIQ", publishedDate: "2020-05-14" },
      { title: "【APEX】あくしお💓二人でチャンピオンになるんだ・・！！【紫咲シオン/湊あくあ】", url: "https://www.youtube.com/watch?v=uduvRJEZ2Fg", publishedDate: "2020-05-17" },
      { title: "【APEX】あくしお💓二人でチャンピオンになるんだ・・！！【紫咲シオン/湊あくあ】", url: "https://www.youtube.com/watch?v=AeBNEdEpD_E", publishedDate: "2020-05-17" },
      { title: "【APEX】100連ガチャ回す！！スパレジェがほしい！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=1gz3Wf9yNa0", publishedDate: "2020-05-20" },
      { title: "【APEX】ねむい組でチャンピオン目指す！！！ぶんぶん！！【紫咲シオン/戌神ころね/猫又おかゆ】", url: "https://www.youtube.com/watch?v=GmCtI235oL0", publishedDate: "2020-06-01" },
      { title: "【APEX】今シーズン初のAPEX！！楽しむぞぞぞ！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=eFvXO-5Ggzk", publishedDate: "2020-09-06" },
      { title: "【APEX】久しぶりのAPEX練習！！勝ちたーい！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=8A0AGgj7XQ8", publishedDate: "2020-10-17" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-23"
  },
  {
    id: "single-275",
    title: "【ラクガキ王国】画伯が王国作る！！",
    streamer: "紫咲シオン",
    game: "ラクガキ王国",
    genre: "other",
    format: "single",
    videos: [
      { title: "【ラクガキ王国】画伯が王国作る！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=X5GiAjAJm3I", publishedDate: "2019-05-04" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-23"
  },
  {
    id: "single-276",
    title: "UNDERTALE 配信まとめ",
    streamer: "沙花叉クロヱ",
    game: "UNDERTALE",
    genre: "rpg",
    format: "multi",
    videos: [
      { title: "【UNDERTALE】シャチのアンダーテール【沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=GMQMhfKsdjw", publishedDate: "2021-12-04" },
      { title: "【UNDERTALE】#2 シャチのアンダーテール～こうどうを覚えた～【沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=afhseq0JsJ8", publishedDate: "2021-12-11" },
      { title: "【UNDERTALE】#3 パピルスに振られたシャチのアンダーテール【沙花叉クロヱ/ホロライブ】", url: "https://www.youtube.com/watch?v=WdaNY0MXeFI", publishedDate: "2021-12-15" },
      { title: "【UNDERTALE】Nルート最終回！シャチのアンダーテール 【沙花叉クロヱ/ホロライブ】", url: "https://www.youtube.com/watch?v=9hgL70ttqpw", publishedDate: "2021-12-20" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-23"
  },
  {
    id: "single-277",
    title: "ポケットモンスター ブリリアントダイヤモンド・シャイニングパール 配信まとめ",
    streamer: "沙花叉クロヱ",
    game: "ポケットモンスター ブリリアントダイヤモンド・シャイニングパール",
    genre: "rpg",
    format: "multi",
    videos: [
      { title: "【ポケモンBD】初見2人でダイパリメイク並走！初心者トレーナー！【沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=KPd2eJDDoWo", publishedDate: "2021-12-09" },
      { title: "【ポケモンBD】初心者トレーナーがダイパリメイク初見プレイ！#2【沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=lLePwU1Egck", publishedDate: "2021-12-12" },
      { title: "【ポケモンBD】初心者トレーナーがダイパリメイク初見プレイ！#3【沙花叉クロヱ/ホロライブ】", url: "https://www.youtube.com/watch?v=iWIdXnna5Cc", publishedDate: "2021-12-17" },
      { title: "【ポケモンBD】初見プレイ！運PT作りつつバッジ3個目めざす！#4【沙花叉クロヱ/ホロライブ】", url: "https://www.youtube.com/watch?v=0CP2tV62Ook", publishedDate: "2021-12-23" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-23"
  },
  {
    id: "single-278",
    title: "マリオカート8 デラックス 配信まとめ(2021年12月〜2022年2月)",
    streamer: "沙花叉クロヱ",
    game: "マリオカート8 デラックス",
    genre: "racing",
    format: "multi",
    videos: [
      { title: "【マリカ8DX】参加型で飼育員さんたちをぼこぼこにする！【沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=rFeulkDGvao", publishedDate: "2021-12-26" },
      { title: "【マリカ8DX】holoX最強は誰かを決める！【沙花叉クロヱ/ホロライブ】", url: "https://www.youtube.com/watch?v=hX8RoG3XpFg", publishedDate: "2021-12-28" },
      { title: "【マリカ8DX】本気、見せちゃおっかなｗ【沙花叉クロヱ/ホロライブ】", url: "https://www.youtube.com/watch?v=HLJGuyQNCRc", publishedDate: "2021-12-29" },
      { title: "【マリカ8DX】参加型でholoXの集大成、見せつける【沙花叉クロヱ/ホロライブ】", url: "https://www.youtube.com/watch?v=7prXmg5J7o0", publishedDate: "2022-01-06" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-23"
  },
  {
    id: "single-279",
    title: "Among Us 配信まとめ(2021年12月〜2022年2月)",
    streamer: "沙花叉クロヱ",
    game: "Among Us",
    genre: "other",
    format: "multi",
    videos: [
      { title: "【AmongUs】全員お掃除☆アモングアス！ホロ宇宙人狼【沙花叉クロヱ/ホロライブ】", url: "https://www.youtube.com/watch?v=nsC7yksOg5Q", publishedDate: "2021-12-29" },
      { title: "【AmongUs】日本酒片手にほろ酔いアモングアス！よっぱっぱ～～【沙花叉クロヱ/ホロライブ】", url: "https://www.youtube.com/watch?v=5DJo5Wz700U", publishedDate: "2022-02-13" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-23"
  },
  {
    id: "single-280",
    title: "【GettingOverIt】己の限界を越えていけ　新春壺おじ！",
    streamer: "沙花叉クロヱ",
    game: "Getting Over It",
    genre: "action",
    format: "single",
    videos: [
      { title: "【GettingOverIt】己の限界を越えていけ　新春壺おじ！【沙花叉クロヱ/ホロライブ】", url: "https://www.youtube.com/watch?v=cPOExVGRN28", publishedDate: "2022-01-02" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-23"
  },
  {
    id: "single-281",
    title: "Minecraft 配信まとめ",
    streamer: "沙花叉クロヱ",
    game: "Minecraft",
    genre: "sandbox",
    format: "multi",
    videos: [
      { title: "【Minecraft】#マイクラholoX初観光　ドキドキ【沙花叉クロヱ/ホロライブ】", url: "https://www.youtube.com/watch?v=Bmzhm0qDMag", publishedDate: "2022-01-05" },
      { title: "【Minecraft】EN鯖の初観光！英語で会話できるかな！？Hakos senpai and Mumei senpai yorosiku desu【沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=4gAKkEhvwJ0", publishedDate: "2022-02-12" },
      { title: "【Minecraft】初のソロマイクラ！スロット台を作る場所探す～！【沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=VGP_fBBM7aw", publishedDate: "2022-02-14" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-23"
  },
  {
    id: "single-282",
    title: "【Raft】鮫のいる海上でサバイバル！#海犬フレンズ",
    streamer: "沙花叉クロヱ",
    game: "Raft",
    genre: "sandbox",
    format: "single",
    videos: [
      { title: "【Raft】鮫のいる海上でサバイバル！#海犬フレンズ【沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=Th1Xki6PbZY", publishedDate: "2022-01-30" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-23"
  },
  {
    id: "single-283",
    title: "GREEN HELL 配信まとめ",
    streamer: "沙花叉クロヱ",
    game: "GREEN HELL",
    genre: "sandbox",
    format: "multi",
    videos: [
      { title: "【GREENHELL】アマゾンの奥地でサバイバル生活！【沙花叉クロヱ/ホロライブ】", url: "https://www.youtube.com/watch?v=RoUW43iMLgQ", publishedDate: "2022-02-04" },
      { title: "【GREENHELL】アマゾンの奥地で究極のサバイバル！#2【沙花叉クロヱ/ホロライブ】", url: "https://www.youtube.com/watch?v=8MSVgT3_KVo", publishedDate: "2022-02-05" },
      { title: "【GREENHELL】-最終回-物語をTRUEENDへ、ミアを救え【沙花叉クロヱ/ホロライブ】", url: "https://www.youtube.com/watch?v=kdixAMrEwhs", publishedDate: "2022-02-06" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-23"
  },
  {
    id: "single-284",
    title: "【JumpKing】遂に初めてのジャンプキング！クリア目指すけど余裕っしょｗｗｗｗｗ",
    streamer: "沙花叉クロヱ",
    game: "Jump King",
    genre: "action",
    format: "single",
    videos: [
      { title: "【JumpKing】遂に初めてのジャンプキング！クリア目指すけど余裕っしょｗｗｗｗｗ【沙花叉クロヱ】", url: "https://www.youtube.com/watch?v=g4epc4Q0_bE", publishedDate: "2022-02-12" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-23"
  },
  {
    id: "single-285",
    title: "ARK: Survival Evolved 配信まとめ",
    streamer: "紫咲シオン",
    game: "ARK: Survival Evolved",
    genre: "sandbox",
    format: "multi",
    videos: [
      { title: "【ARK】初めての恐竜の世界！！ホロ鯖に参上！！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=KfZhXF_6HiY", publishedDate: "2020-01-29" },
      { title: "【ARK】これがサバイバルの世界！！お家作って生き残りたい。【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=Y_j2C4YuzkI", publishedDate: "2020-01-30" },
      { title: "【ARK】空を飛んで大冒険！！仲間を増やして生きる！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=37ryjzY9PE0", publishedDate: "2020-01-31" },
      { title: "【ARK】肉食恐竜捕獲目指して協力💓初コラボ！！【ホロライブ/紫咲シオン/桐生ココ】", url: "https://www.youtube.com/watch?v=PDvxKio33vA", publishedDate: "2020-02-03" },
      { title: "【ARK】健康的に生きるには、農業だ！！※そしてペット探し【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=4FKPnxFn_T0", publishedDate: "2020-02-04" },
      { title: "【ARK】1時間以内にアルゲン捕獲できるのか....！？【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=AvP0HKf3GkI", publishedDate: "2020-02-07" },
      { title: "【ARK】ワイバーンの卵を盗みたい！！泥棒します！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=YA_BXtzBeJk", publishedDate: "2020-02-09" },
      { title: "【ARK】盗んだワイバーンの卵を孵化！！そしてママになる。【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=kRX9O98XA8I", publishedDate: "2020-02-11" },
      { title: "【ARK】バレンタインイベント！？ペットほしい！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=qagcNPM1uLo", publishedDate: "2020-02-13" },
      { title: "【ARK】空を飛んでまだ見ぬ世界へ！！とまらないバレンタイン💘【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=fGcbm4NQX3k", publishedDate: "2020-02-15" },
      { title: "【ARK】意のままに、ただやるんだ。【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=AHOcQ5LzFOI", publishedDate: "2020-02-18" },
      { title: "【ARK】トラウマの雪山へ！！！いざ参る！！！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=WaJGz0QJXdI", publishedDate: "2020-02-20" },
      { title: "【#紫龍組】これが新しいARK！！新世界アベレーションで生き抜く…！！【ホロライブ/紫咲シオン/桐生ココ】", url: "https://www.youtube.com/watch?v=LsvoHAs3XSA", publishedDate: "2020-03-24" },
      { title: "【 #ホロARK探検隊 】ARKの世界にあくしお参戦！！大冒険💓【ホロライブ/紫咲シオン/湊あくあ】", url: "https://www.youtube.com/watch?v=Ws7_UWFc8Ps", publishedDate: "2020-07-05" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-24"
  },
  {
    id: "single-286",
    title: "あつまれ どうぶつの森 配信まとめ",
    streamer: "紫咲シオン",
    game: "あつまれ どうぶつの森",
    genre: "sim",
    format: "multi",
    videos: [
      { title: "【あつまれどうぶつの森】無人島生活スタート！？全力で楽しむぞおおお！！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=PCHRyqhMA1c", publishedDate: "2020-03-20" },
      { title: "【あつまれどうぶつの森】無人島生活2日目！！いろいろできるし冒険する！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=HUb0DjnItis", publishedDate: "2020-03-21" },
      { title: "【あつまれどうぶつの森】のんびり島めぐり！！発展した島を見て👀【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=Xkij4PL68bg", publishedDate: "2020-03-22" },
      { title: "【あつまれどうぶつの森】進化しすぎた島！！たくさんお金ほしい！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=d75033fOLKI", publishedDate: "2020-03-25" },
      { title: "【あつまれどうぶつの森】みんな集合な！！５人で遊ぶよおおお！！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=R6W2R9pcUqo", publishedDate: "2020-03-27" },
      { title: "【あつまれどうぶつの森】視聴者の島に凸撃！！何しちゃおうかな～！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=zOhRadU27Z4", publishedDate: "2020-03-29" },
      { title: "【あつまれどうぶつの森】視聴者の島に凸撃！！自慢の島募集！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=U9utuYNLjxg", publishedDate: "2020-04-02" },
      { title: "【あつまれどうぶつの森】みてみてイースター！！島を工事で可愛くする！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=fbMnI29059Y", publishedDate: "2020-04-04" },
      { title: "【あつまれどうぶつの森】おしゃれな島を目指して！！島を工事する！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=uan1WtkGOKg", publishedDate: "2020-04-05" },
      { title: "【あつ森】視聴者の島に行く！！可愛いもの強奪作戦！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=2oN7l9pFoe0", publishedDate: "2020-04-09" },
      { title: "【あつ森】住民ガチャできずブサイクに敗北しました。【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=OvuBdYIFpvM", publishedDate: "2020-04-14" },
      { title: "【あつ森】美女がほしい！！リベンジ住民ガチャ！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=ZUUCuP6_9aY", publishedDate: "2020-04-16" },
      { title: "【あつ森】離島住民ガチャ！！たくさんガチャしたいなぁ！？【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=UuREbjAFRYU", publishedDate: "2020-04-21" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-24"
  },
  {
    id: "single-287",
    title: "スーパーマリオメーカー2 配信まとめ",
    streamer: "紫咲シオン",
    game: "スーパーマリオメーカー2",
    genre: "action",
    format: "multi",
    videos: [
      { title: "【マリオメーカー2】初めてのマリオメーカーで遊ぶ！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=K2HzS88b3h0", publishedDate: "2019-06-28" },
      { title: "【マリオメーカー2】レート戦があるってマジ！？やるしかない！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=j3ABkYdb838", publishedDate: "2019-07-02" },
      { title: "【マリオメーカー2】進捗どうですか？鬼畜コースできました！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=diMGmWgWV-o", publishedDate: "2019-07-03" },
      { title: "【マリオメーカー2】レート戦でランクアップ目指して勝負！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=RWOKYNRdfno", publishedDate: "2019-07-05" },
      { title: "【マリオメーカー2】レートBに行きたい！！トラウマメーカー。【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=UkYluFsHAI4", publishedDate: "2019-07-11" },
      { title: "【マリオメーカー2】許してください...！！鬼畜なキノコの言うことを聞く。【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=zPUBxI70eJI", publishedDate: "2019-07-19" },
      { title: "【マリオメーカー2】難しいの？余裕～！！みんなのおすすめコースをやる！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=Ixy6uGPEFC4", publishedDate: "2019-07-22" },
      { title: "【マリオメーカー2】なんでもかかってこい～？みんなのおすすめコース遊ぶ！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=6ShksPR2E5I", publishedDate: "2019-07-25" },
      { title: "【マリオメーカー2】どんなコースもクリアする！みんなのおすすめコースで遊ぶ！#3【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=esc-KM_Femw", publishedDate: "2019-08-08" },
      { title: "【マリオメーカー2】Vtuberの作ったコース？上等だぁ！クリアする！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=3VGAXfsNHZA", publishedDate: "2019-08-13" },
      { title: "【マリオメーカー2】世界を倒しにきた！！クリアするぞぉ！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=EpeibchzFss", publishedDate: "2019-08-21" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-24"
  },
  {
    id: "single-288",
    title: "マリオカート8 デラックス 配信まとめ",
    streamer: "紫咲シオン",
    game: "マリオカート8 デラックス",
    genre: "racing",
    format: "multi",
    videos: [
      { title: "【マリオカート８DX】運転初心者の７位以下即終了！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=uUpMYuyTOuA", publishedDate: "2019-05-23" },
      { title: "【マリオカート８DX】運転初心者悲しみの練習【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=gDGmVpLw808", publishedDate: "2019-05-23" },
      { title: "【マリオカート８DX】１０位以下で即終了！！これならいけるはず…。【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=boLCZp6Zq7E", publishedDate: "2019-05-30" },
      { title: "【マリオカート8デラックス】１位とる！勝利の味が知りたいなぁｗｗｗ【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=lr7SC-H5ioc", publishedDate: "2019-10-20" },
      { title: "【マリオカート８DX】そろそろ本気で１位がとりたい！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=YIoFbsoSJxM", publishedDate: "2019-10-28" },
      { title: "【マリオカート８DX】野生の兎と負けられない戦い...！！【ホロライブ】", url: "https://www.youtube.com/watch?v=r4gQLGG_PQY", publishedDate: "2019-11-01" },
      { title: "【マリオカート8DX】7位以下で即終了！？まあ1時間余裕っしょwww【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=GBewqO88DY8", publishedDate: "2020-01-12" },
      { title: "【マリオカート8DX】7位で即終了雑談！！負けました。【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=RCYCpQAOUAM", publishedDate: "2020-01-18" },
      { title: "【マリオカート8DX】7位以下で〇〇になる！！負けられない視聴者参加型！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=tqrgGmGRYE4", publishedDate: "2020-03-31" },
      { title: "【マリオカート8DX】負けられない！！久しぶりでも1時間なんて余裕！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=24jI9oLhsc4", publishedDate: "2020-05-10" },
      { title: "【マリオカート8DX】7位以下で即終了するマリオカート・・・【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=zKTwcNjXT3U", publishedDate: "2020-09-01" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-24"
  },
  {
    id: "single-289",
    title: "ポケットモンスター ソード・シールド 配信まとめ",
    streamer: "紫咲シオン",
    game: "ポケットモンスター ソード・シールド",
    genre: "rpg",
    format: "multi",
    videos: [
      { title: "【ポケモンシールド】新しい冒険の始まり。いくぞ！！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=D3x6qnLiZUw", publishedDate: "2019-11-15" },
      { title: "【ポケモンシールド】ポケモンマスターになる！殿堂入り耐久！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=KpUpx-bMZcs", publishedDate: "2019-11-17" },
      { title: "【ポケモンシールド】負けられない戦い。湊あくあが勝負をしかけてきた！【紫咲シオン/湊あくあ】", url: "https://www.youtube.com/watch?v=rlkzDlVCC8I", publishedDate: "2019-11-24" },
      { title: "【ポケモンシールド】はじめてのランクバトル！4vヒンバス配布する！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=UNmJuqg2a78", publishedDate: "2019-11-25" },
      { title: "【ポケモンシールド】初心者ランクバトル！対戦に慣れて強くなりたい！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=ZOmiX8sL2yI", publishedDate: "2019-11-29" },
      { title: "【ポケモンシールド】ランクアップ目指してバトル！！脳筋パルシェン最強！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=fE4rWdT_mR0", publishedDate: "2019-12-10" },
      { title: "【ポケモンシールド】もうすぐマスボ級！？目指すはランクアップ！！やっぱパルシェンなんだよなぁ【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=d9NwD00CX20", publishedDate: "2019-12-12" },
      { title: "【ポケモンシールド】マスボ級到達！！順位アップめざしてレート戦！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=cQFpPT9tgR8", publishedDate: "2019-12-17" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-24"
  },
  {
    id: "single-290",
    title: "みんなのリズム天国 配信まとめ",
    streamer: "紫咲シオン",
    game: "みんなのリズム天国",
    genre: "other",
    format: "multi",
    videos: [
      { title: "【みんなのリズム天国】初挑戦！リズム感はあるのか...！？重大告知も！【#紫咲シオン3D】", url: "https://www.youtube.com/watch?v=cCFE-TWNfIw", publishedDate: "2019-07-28" },
      { title: "【みんなのリズム天国】真の最強リズム感を見せつける！！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=u6GjCMhDrSg", publishedDate: "2019-08-07" },
      { title: "【みんなのリズム天国】これが最大の敵。リズムに勝つ！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=B2fGh1i3_tE", publishedDate: "2019-08-19" },
      { title: "【みんなのリズム天国】1番苦手なゲーム。実質鬱ゲーに勝ちます。※最後に告知あり！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=KG9gogCrUp0", publishedDate: "2019-08-22" },
      { title: "【みんなのリズム天国】最も苦手なゲーム。クリアを目指して...！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=zobHIBDsEW0", publishedDate: "2019-08-28" },
      { title: "【リズム天国】長い地獄も今日で終わり！！苦手ゲームクリア目指す！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=u3LKNwKwVJM", publishedDate: "2019-09-06" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-24"
  },
  {
    id: "single-291",
    title: "スーパーマリオワールド 配信まとめ",
    streamer: "紫咲シオン",
    game: "スーパーマリオワールド",
    genre: "action",
    format: "multi",
    videos: [
      { title: "【マリオワールド】超有名アクションゲーム！初見プレイ！#1【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=Z8AV-ScXi24", publishedDate: "2019-06-20" },
      { title: "【マリオワールド】超有名アクションゲーム！初見プレイ！#2【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=keqLKSy3TRE", publishedDate: "2019-06-22" },
      { title: "【マリオワールド】超有名アクションゲーム！激ムズ！！#3【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=cJv2ADbYa2U", publishedDate: "2019-06-25" },
      { title: "【マリオワールド】絶対ゲームの腕も上がったしクリア余裕っしょ！！#4【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=tDyewy3ue6Y", publishedDate: "2019-07-17" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-24"
  },
  {
    id: "single-292",
    title: "大乱闘スマッシュブラザーズ SPECIAL 配信まとめ",
    streamer: "紫咲シオン",
    game: "大乱闘スマッシュブラザーズ SPECIAL",
    genre: "action",
    format: "multi",
    videos: [
      { title: "【スマブラSP】視聴者参加型！！半年ぶりのスマブラ余裕すぎwww【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=HrLZwBu7c-0", publishedDate: "2020-01-04" },
      { title: "【スマブラSP】みんなで仲良く！！視聴者わからせスマブラ大会！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=EsAkZTMpB6A", publishedDate: "2020-01-20" },
      { title: "【スマブラSP】視聴者参加型バトル！！目指すは5勝！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=2EPBZFj9wFc", publishedDate: "2020-02-06" },
      { title: "【スマブラSP】視聴者参加型！！優しくしてください。【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=tUo-HJCBWVI", publishedDate: "2020-10-16" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-24"
  },
  {
    id: "single-293",
    title: "Fall Guys 配信まとめ",
    streamer: "紫咲シオン",
    game: "Fall Guys",
    genre: "other",
    format: "multi",
    videos: [
      { title: "【FallGuys】初見！！1位目指して頑張るぞおお！！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=nuQPZXGAgY8", publishedDate: "2020-08-19" },
      { title: "【FallGuys】1位になりたああああい！！！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=OWCJMKkhzBA", publishedDate: "2020-08-30" },
      { title: "【FallGuys】4人の絆で1位目指すっ！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=BXlRQrSM6O4", publishedDate: "2020-10-12" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-24"
  },
  {
    id: "single-294",
    title: "slither.io 配信まとめ",
    streamer: "紫咲シオン",
    game: "slither.io",
    genre: "other",
    format: "multi",
    videos: [
      { title: "【Slither.io】世界1位になる！！！！ミミズ界の美女です。【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=RBVqMNjvOj8", publishedDate: "2020-03-23" },
      { title: "【Slither.io】今日こそ世界とる！！リベンジミミズ！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=9ZjfpN9LYPo", publishedDate: "2020-03-28" },
      { title: "【Slither.io】成長しました！！美少女ミミズ最終回…！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=i8qHspqLZg4", publishedDate: "2020-04-07" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-24"
  },
  {
    id: "single-295",
    title: "Craftopia 配信まとめ",
    streamer: "紫咲シオン",
    game: "Craftopia",
    genre: "sandbox",
    format: "multi",
    videos: [
      { title: "【クラフトピア】なんでもできる世界！？初見プレイ！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=8uKTkhUEMd4", publishedDate: "2020-09-14" },
      { title: "【クラフトピア】仲間が欲しい！！深夜探検するぞ！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=Geyhx1nG9N0", publishedDate: "2020-09-15" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-24"
  },
  {
    id: "single-296",
    title: "おどる メイド イン ワリオ 配信まとめ",
    streamer: "紫咲シオン",
    game: "おどる メイド イン ワリオ",
    genre: "other",
    format: "multi",
    videos: [
      { title: "【おどるメイドインワリオ】座っててもダンスできます！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=OC3UMNlu1rI", publishedDate: "2019-10-07" },
      { title: "【おどるメイドインワリオ】鋼の意思で立たないプロダンサーです！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=-lr74qvkwi8", publishedDate: "2019-10-16" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-24"
  },
  {
    id: "single-297",
    title: "雀魂 配信まとめ",
    streamer: "紫咲シオン",
    game: "雀魂",
    genre: "other",
    format: "multi",
    videos: [
      { title: "【雀魂】初心者麻雀！！絶対に怒らないでください・・・【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=UDBDPav3m3Q", publishedDate: "2020-07-21" },
      { title: "【雀魂】ホロメン4人で麻雀！！初心者女子会💓【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=F-CyFM49hm4", publishedDate: "2020-07-26" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-24"
  },
  {
    id: "single-298",
    title: "世界のアソビ大全51 配信まとめ",
    streamer: "紫咲シオン",
    game: "世界のアソビ大全51",
    genre: "other",
    format: "multi",
    videos: [
      { title: "【世界のアソビ大全51】かかってこい！！深夜のアソビの時間✨【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=-rytDKpD_BA", publishedDate: "2020-08-22" },
      { title: "【世界のアソビ大全51】アソビだって負けられない・・！！あくしお対決🔥【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=eT0KVQCgArY", publishedDate: "2020-08-24" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-24"
  },
  {
    id: "single-299",
    title: "魔女の家 配信まとめ",
    streamer: "紫咲シオン",
    game: "魔女の家",
    genre: "horror",
    format: "multi",
    videos: [
      { title: "【魔女の家】初見プレイ！！魔女の家にお邪魔する！！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=qbMmwg43xJ8", publishedDate: "2020-04-17" },
      { title: "【魔女の家】初見プレイ！！怖すぎる家から脱出したい！！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=kymzBHvOJQ0", publishedDate: "2020-04-19" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-24"
  },
  {
    id: "single-300",
    title: "【1-2-Switch】負けたら服従！？てぇてぇ3Dコラボ！【#シオたま3D】",
    streamer: "紫咲シオン",
    game: "1-2-Switch",
    genre: "other",
    format: "single",
    videos: [
      { title: "【1-2-Switch】負けたら服従！？てぇてぇ3Dコラボ！【#シオたま3D】", url: "https://www.youtube.com/watch?v=qyW9bW2Ydac", publishedDate: "2019-07-06" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-24"
  },
  {
    id: "single-301",
    title: "【60seconds!】60秒で生死が決まる！家族を救いたい。【ホロライブ/紫咲シオン】",
    streamer: "紫咲シオン",
    game: "60 Seconds!",
    genre: "sim",
    format: "single",
    videos: [
      { title: "【60seconds!】60秒で生死が決まる！家族を救いたい。【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=D4ka04CDHWg", publishedDate: "2019-12-06" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-24"
  },
  {
    id: "single-302",
    title: "【7Days to Die】夜を乗り越えて生き残る！！ホロ鯖暮し！【ホロライブ/紫咲シオン】",
    streamer: "紫咲シオン",
    game: "7 Days to Die",
    genre: "sandbox",
    format: "single",
    videos: [
      { title: "【7Days to Die】夜を乗り越えて生き残る！！ホロ鯖暮し！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=jDjWHSKsXo4", publishedDate: "2020-02-12" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-24"
  },
  {
    id: "single-303",
    title: "【home sweet home】超ビビりが限界まで頑張るホラーゲーム。【ホロライブ/紫咲シオン】",
    streamer: "紫咲シオン",
    game: "HOME SWEET HOME",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【home sweet home】超ビビりが限界まで頑張るホラーゲーム。【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=kOZo-lf_EIU", publishedDate: "2020-01-25" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-24"
  },
  {
    id: "single-304",
    title: "【KIDS】キッズの人生。ガキが・・・！！【ホロライブ/紫咲シオン】",
    streamer: "紫咲シオン",
    game: "KIDS",
    genre: "other",
    format: "single",
    videos: [
      { title: "【KIDS】キッズの人生。ガキが・・・！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=FDT3CoKgfsk", publishedDate: "2020-07-17" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-24"
  },
  {
    id: "single-305",
    title: "【Maneater】話題のサメのゲーム！？最強のサメになるぞぉ！【ホロライブ/紫咲シオン】",
    streamer: "紫咲シオン",
    game: "Maneater",
    genre: "action",
    format: "single",
    videos: [
      { title: "【Maneater】話題のサメのゲーム！？最強のサメになるぞぉ！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=1GSP2lB9UaY", publishedDate: "2020-06-03" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-24"
  },
  {
    id: "single-306",
    title: "【PIEN】ぴえんに追いかけられるホラゲー🥺【ホロライブ/紫咲シオン】",
    streamer: "紫咲シオン",
    game: "PIEN",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【PIEN】ぴえんに追いかけられるホラゲー🥺【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=fdJ6BBOPtIQ", publishedDate: "2020-06-23" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-24"
  },
  {
    id: "single-307",
    title: "【Plug & Play】謎すぎるプラグの人生・・・。【ホロライブ/紫咲シオン】",
    streamer: "紫咲シオン",
    game: "Plug & Play",
    genre: "other",
    format: "single",
    videos: [
      { title: "【Plug & Play】謎すぎるプラグの人生・・・。【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=ao78lYcXNPI", publishedDate: "2020-07-07" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-24"
  },
  {
    id: "single-308",
    title: "【Project Winter】ホロライブプロジェクトウィンター！雪山人狼！？【ホロライブ/紫咲シオン視点】",
    streamer: "紫咲シオン",
    game: "Project Winter",
    genre: "other",
    format: "single",
    videos: [
      { title: "【Project Winter】ホロライブプロジェクトウィンター！雪山人狼！？【ホロライブ/紫咲シオン視点】", url: "https://www.youtube.com/watch?v=nZTnczM3QsQ", publishedDate: "2019-07-23" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-24"
  },
  {
    id: "single-309",
    title: "【UNO】3人でUNO真剣対決！！【ホロライブ/紫咲シオン/猫又おかゆ/戌神ころね】",
    streamer: "紫咲シオン",
    game: "UNO",
    genre: "other",
    format: "single",
    videos: [
      { title: "【UNO】3人でUNO真剣対決！！【ホロライブ/紫咲シオン/猫又おかゆ/戌神ころね】", url: "https://www.youtube.com/watch?v=LWpntGLC2hE", publishedDate: "2019-06-08" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-24"
  },
  {
    id: "single-310",
    title: "【VALORANT】好きなことやラント～！！【ホロライブ/紫咲シオン】",
    streamer: "紫咲シオン",
    game: "VALORANT",
    genre: "fps",
    format: "single",
    videos: [
      { title: "【VALORANT】好きなことやラント～！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=_xBNnrJBIKk", publishedDate: "2020-06-06" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-24"
  },
  {
    id: "single-311",
    title: "【#アズールレーン】幸運を見せつける！ホロ艦絶対コンプする！！【ホロライブ/紫咲シオン】",
    streamer: "紫咲シオン",
    game: "アズールレーン",
    genre: "other",
    format: "single",
    videos: [
      { title: "【#アズールレーン】幸運を見せつける！ホロ艦絶対コンプする！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=EbNU_CGkC7o", publishedDate: "2019-11-30" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-24"
  },
  {
    id: "single-312",
    title: "【お絵かきの森】神絵師と画伯のお絵かき！？視聴者参加型！！【ホロライブ/紫咲シオン】",
    streamer: "紫咲シオン",
    game: "おえかきの森",
    genre: "other",
    format: "single",
    videos: [
      { title: "【お絵かきの森】神絵師と画伯のお絵かき！？視聴者参加型！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=9WbBuKfAoJQ", publishedDate: "2020-07-19" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-24"
  },
  {
    id: "single-313",
    title: "【スーパードンキーコング】はじめてお猿さん達と遊ぶ！ウキッw【ホロライブ/紫咲シオン】",
    streamer: "紫咲シオン",
    game: "スーパードンキーコング",
    genre: "action",
    format: "single",
    videos: [
      { title: "【スーパードンキーコング】はじめてお猿さん達と遊ぶ！ウキッw【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=uCk-SOyNvoU", publishedDate: "2019-06-21" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-24"
  },
  {
    id: "single-314",
    title: "【スーパーマリオ64】 Let's Goマリオ！！ガチ初見で楽しむぞ！！【ホロライブ/紫咲シオン】",
    streamer: "紫咲シオン",
    game: "スーパーマリオ64",
    genre: "action",
    format: "single",
    videos: [
      { title: "【スーパーマリオ64】 Let's Goマリオ！！ガチ初見で楽しむぞ！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=Ywg19wEg_DQ", publishedDate: "2020-09-19" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-24"
  },
  {
    id: "single-315",
    title: "【マリオ35】バトロワのマリオ！？目指すは1位！！【ホロライブ/紫咲シオン】",
    streamer: "紫咲シオン",
    game: "スーパーマリオブラザーズ35",
    genre: "action",
    format: "single",
    videos: [
      { title: "【マリオ35】バトロワのマリオ！？目指すは1位！！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=sYvKXfTLj4o", publishedDate: "2020-10-11" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-24"
  },
  {
    id: "single-316",
    title: "【#るしおん】仲良しいちゃラブどうぶつタワーバトル！！【ホロライブ/紫咲シオン/潤羽るしあ】",
    streamer: "紫咲シオン",
    game: "どうぶつタワーバトル",
    genre: "other",
    format: "single",
    videos: [
      { title: "【#るしおん】仲良しいちゃラブどうぶつタワーバトル！！【ホロライブ/紫咲シオン/潤羽るしあ】", url: "https://www.youtube.com/watch?v=nRbgITUTwzE", publishedDate: "2020-07-09" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-24"
  },
  {
    id: "single-317",
    title: "【どうぶつの森＋】村長になりたかった。【ホロライブ/紫咲シオン】",
    streamer: "紫咲シオン",
    game: "どうぶつの森+",
    genre: "sim",
    format: "single",
    videos: [
      { title: "【どうぶつの森＋】村長になりたかった。【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=NRzF9-B5VfA", publishedDate: "2019-05-22" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-24"
  },
  {
    id: "single-318",
    title: "【パスパルトゥー】画伯絵を売ります！！新たな才能で儲けちゃうっ【ホロライブ/紫咲シオン】",
    streamer: "紫咲シオン",
    game: "Passpartout: The Starving Artist",
    genre: "other",
    format: "single",
    videos: [
      { title: "【パスパルトゥー】画伯絵を売ります！！新たな才能で儲けちゃうっ【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=qikL-EvHdao", publishedDate: "2020-09-29" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-24"
  },
  {
    id: "single-319",
    title: "【マリオスポーツミックス】勝たなきゃ食べられない・・！？闇 の タ コ パ 🔥【ホロライブ/紫咲シオン】",
    streamer: "紫咲シオン",
    game: "マリオスポーツミックス",
    genre: "sports",
    format: "single",
    videos: [
      { title: "【マリオスポーツミックス】勝たなきゃ食べられない・・！？闇 の タ コ パ 🔥【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=X2YG1iTrF5c", publishedDate: "2020-09-09" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-24"
  },
  {
    id: "single-320",
    title: "【リングフィットアドベンチャー】本気ダイエット！！引きこもりには鬼畜すぎる...【ホロライブ/紫咲シオン】",
    streamer: "紫咲シオン",
    game: "リングフィットアドベンチャー",
    genre: "sports",
    format: "single",
    videos: [
      { title: "【リングフィットアドベンチャー】本気ダイエット！！引きこもりには鬼畜すぎる...【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=ycB9wuGfRpw", publishedDate: "2019-11-16" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-24"
  },
  {
    id: "single-321",
    title: "【ルイージマンション3】おばけを怖がらせたい。初見プレイ！！【ホロライブ】",
    streamer: "紫咲シオン",
    game: "ルイージマンション3",
    genre: "action",
    format: "single",
    videos: [
      { title: "【ルイージマンション3】おばけを怖がらせたい。初見プレイ！！【ホロライブ】", url: "https://www.youtube.com/watch?v=ARkTOyfL8uU", publishedDate: "2019-11-03" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-24"
  },
  {
    id: "single-322",
    title: "【空気読み２】空気読むのだけは得意です！！任せろ！【ホロライブ/紫咲シオン】",
    streamer: "紫咲シオン",
    game: "空気読み。2",
    genre: "other",
    format: "single",
    videos: [
      { title: "【空気読み２】空気読むのだけは得意です！！任せろ！【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=5S9FVJHZkys", publishedDate: "2019-10-03" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-24"
  },
  {
    id: "single-323",
    title: "【青鬼】初見プレイだけど流石に怖くないやろｗｗｗ20万人まで…あれ？？【ホロライブ/紫咲シオン】",
    streamer: "紫咲シオン",
    game: "青鬼",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【青鬼】初見プレイだけど流石に怖くないやろｗｗｗ20万人まで…あれ？？【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=rmmpa4MBD2g", publishedDate: "2020-04-13" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-24"
  },
  {
    id: "single-324",
    title: "【天穂のサクナヒメ】初めての米作り【ホロライブ/紫咲シオン】",
    streamer: "紫咲シオン",
    game: "天穂のサクナヒメ",
    genre: "rpg",
    format: "single",
    videos: [
      { title: "【天穂のサクナヒメ】初めての米作り【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=hWmHf9L0nx8", publishedDate: "2020-11-17" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-24"
  },
  {
    id: "single-325",
    title: "【夜勤事件】人生初夜勤なんで優しくお願いします！！※ホラゲー閲覧注意※【ホロライブ/紫咲シオン】",
    streamer: "紫咲シオン",
    game: "夜勤事件",
    genre: "horror",
    format: "single",
    videos: [
      { title: "【夜勤事件】人生初夜勤なんで優しくお願いします！！※ホラゲー閲覧注意※【ホロライブ/紫咲シオン】", url: "https://www.youtube.com/watch?v=xTdPBJWJazc", publishedDate: "2020-03-02" }
    ],
    note: "専用再生リストなし",
    addedDate: "2026-11-24"
  }
];
