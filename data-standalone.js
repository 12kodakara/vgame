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
];
