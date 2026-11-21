/**
 * ============================================================
 * ゲーム別の関連商品リンク(楽天アフィリエイト・手動登録)
 * ============================================================
 *
 * game.html で、ここに登録されているゲームだけ「関連商品(PR)」欄を表示する
 * (未登録のゲームは欄ごと非表示で、従来どおりのページ構成のまま)。
 *
 * キーは GAMES(data-core.js)/ PLAYLISTS(data-playlists.js)の
 * game名と完全一致させること(data-game-editorial.js と同じ規則)。
 *
 * 各ゲームの値は商品リンクの配列。1件は次の項目を持つ。
 *   label    : リンクとして表示する商品名(テキストのみ。HTMLは書かない)
 *   url      : 楽天アフィリエイトの管理画面で作成したリンクURL
 *              (https://hb.afl.rakuten.co.jp/... のみ。短縮URL等は表示されない)
 *   imageUrl : (任意)商品画像のURL。楽天アフィリエイトの商品リンク作成画面で出力される
 *              HTMLの <img src="..."> の値をそのまま使う。ホストが game.js の
 *              RAKUTEN_AFFILIATE_IMAGE_HOSTS に無い場合は無視され、テキストリンクで表示される
 *
 * 表示上のルール(game.js 側で処理):
 *   - imageUrl があれば「画像 + 商品名」のカード、無ければテキストリンク
 *   - 価格・在庫・レビュー評価は表示しない
 *   - 楽天の正規アフィリエイトURL以外・label が空の項目は表示しない
 *   - 1ゲームあたり最大 AFFILIATE_MAX_ITEMS 件(game.js)まで
 *
 * 追加例:
 *   "ゲーム名": [
 *     { label: "商品名", url: "https://hb.afl.rakuten.co.jp/ichiba/xxxxxxxx.xxxxxxxx/?pc=..." },
 *   ],
 */
const GAME_AFFILIATE = {
  "FINAL FANTASY X": [
    { label: "FINAL FANTASY X/X-2 HD Remaster（Nintendo Switch 2版）", url: "https://hb.afl.rakuten.co.jp/ichiba/59cae608.450475ce.59cae609.4c700fba/?pc=https%3A%2F%2Fitem.rakuten.co.jp%2Fbook%2F18669707%2F&link_type=hybrid_url&ut=eyJwYWdlIjoiaXRlbSIsInR5cGUiOiJoeWJyaWRfdXJsIiwic2l6ZSI6IjI0MHgyNDAiLCJuYW0iOjEsIm5hbXAiOiJyaWdodCIsImNvbSI6MSwiY29tcCI6ImRvd24iLCJwcmljZSI6MSwiYm9yIjoxLCJjb2wiOjEsImJidG4iOjEsInByb2QiOjAsImFtcCI6ZmFsc2V9",
      imageUrl: "https://hbb.afl.rakuten.co.jp/hgb/59cae608.450475ce.59cae609.4c700fba/?me_id=1213310&item_id=21990014&pc=https%3A%2F%2Fthumbnail.image.rakuten.co.jp%2F%400_mall%2Fbook%2Fcabinet%2F2195%2F4988601012195.jpg%3F_ex%3D400x400&s=400x400&t=pict" },
  ],
  "Minecraft": [
    { label: "Minecraft（Nintendo Switch版）", url: "https://hb.afl.rakuten.co.jp/ichiba/59cc15fb.d7b56169.59cc15fc.fa4317aa/?pc=https%3A%2F%2Fitem.rakuten.co.jp%2Fyamada-denki%2F2815330013%2F&link_type=pict&ut=eyJwYWdlIjoiaXRlbSIsInR5cGUiOiJwaWN0Iiwic2l6ZSI6IjQwMHg0MDAiLCJuYW0iOjEsIm5hbXAiOiJyaWdodCIsImNvbSI6MSwiY29tcCI6ImRvd24iLCJwcmljZSI6MCwiYm9yIjoxLCJjb2wiOjEsImJidG4iOjEsInByb2QiOjAsImFtcCI6ZmFsc2V9",
      imageUrl: "https://hbb.afl.rakuten.co.jp/hgb/59cc15fb.d7b56169.59cc15fc.fa4317aa/?me_id=1357621&item_id=10176517&pc=https%3A%2F%2Fthumbnail.image.rakuten.co.jp%2F%400_mall%2Fyamada-denki%2Fcabinet%2Fa07000110%2F2815330013.jpg%3F_ex%3D400x400&s=400x400&t=pict" },
  ],
};
