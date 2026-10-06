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
  }
];
