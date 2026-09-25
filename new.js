/**
 * 新着再生リスト(new.html)。
 * 新着50件の選び方は computeNewList() にまとめてある。ページでは数MBある data-playlists.js を
 * 読み込まず、generate-list-data.js がこの同じ関数で事前に作った data-new.js(NEW_LIST)を使う。
 * NEW_LIST が使えない場合だけ data-playlists.js を読み込んで同じ関数で集計する(表示は同じ)。
 * 「NEW」バッジ(追加から14日以内)は閲覧した日を基準にするため、従来どおりページ側で判定する。
 */
const NEW_WITHIN_DAYS = 14;
const NEW_LIMIT = 50;
const NEW_LIST_VERSION = 1;

/** 全再生リストから追加日が新しい順(同日は更新日が新しい順)に50件を選ぶ(DOMに触れない純粋関数)。 */
function computeNewList(playlists) {
  return playlists.slice()
    .filter((p) => p.addedDate)
    .sort((a, b) => {
      const addedDiff = new Date(b.addedDate) - new Date(a.addedDate);
      if (addedDiff !== 0) return addedDiff;
      return new Date(b.updatedDate || 0) - new Date(a.updatedDate || 0);
    })
    .slice(0, NEW_LIMIT);
}

(function () {
  // generate-list-data.js から読み込まれた場合は集計関数の定義だけを提供し、描画はしない
  if (typeof window === "undefined" || window.__LIST_DATA_GENERATOR__) return;

  function renderNew(byAddedDate) {
    const now = new Date();
    const grid = document.getElementById("grid");
    const resultCount = document.getElementById("result-count");

    function rowOpts(item) {
      const added = new Date(item.addedDate + "T00:00:00");
      const days = (now - added) / (1000 * 60 * 60 * 24);
      return { showNewBadge: days <= NEW_WITHIN_DAYS, showAgency: true };
    }

    const setPageItems = initPagination((pageItems) => {
      renderTable(grid, pageItems, "新着の再生リストがありません。", rowOpts);
    }, 20);
    const sortLabels = { genre: "ジャンル", title: "タイトル", game: "ゲーム", agency: "事務所", streamer: "実況者", videoCount: "動画数", updatedDate: "更新日" };
    const render = initColumnSort((sortKey, dir) => {
      setPageItems(sortByColumn(byAddedDate, sortKey, dir));
      resultCount.textContent = "新着" + byAddedDate.length + "件を" + (sortKey ? sortLabels[sortKey] + "順" : "新着順") + "に表示中";
    });
    render();
  }

  if (typeof PLAYLISTS !== "undefined") {
    renderNew(computeNewList(getAllPlaylists()));
  } else if (typeof NEW_LIST !== "undefined" && NEW_LIST && NEW_LIST.version === NEW_LIST_VERSION && Array.isArray(NEW_LIST.items)) {
    renderNew(NEW_LIST.items);
  } else {
    loadPlaylistsData().then(() => renderNew(computeNewList(getAllPlaylists())));
  }
})();
