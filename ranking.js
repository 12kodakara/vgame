/**
 * 人気ランキング(ranking.html)。
 * 上位50件の選び方は computeRankingList() にまとめてある。ページでは数MBある data-playlists.js を
 * 読み込まず、generate-list-data.js がこの同じ関数で事前に作った data-ranking.js(RANKING_LIST)を使う。
 * RANKING_LIST が使えない場合だけ data-playlists.js を読み込んで同じ関数で集計する(表示は同じ)。
 */
const RANKING_LIMIT = 50;
const RANKING_LIST_VERSION = 1;

/** 全再生リストから人気順上位50件を選び、順位(_rank)を付けたコピーを返す(DOMに触れない純粋関数)。 */
function computeRankingList(playlists) {
  return playlists.slice()
    .sort((a, b) => calculatePopularity(b) - calculatePopularity(a))
    .slice(0, RANKING_LIMIT)
    .map((item, i) => Object.assign({}, item, { _rank: i + 1 }));
}

(function () {
  // generate-list-data.js から読み込まれた場合は集計関数の定義だけを提供し、描画はしない
  if (typeof window === "undefined" || window.__LIST_DATA_GENERATOR__) return;

  function renderRanking(topRanked) {
    const grid = document.getElementById("grid");
    const resultCount = document.getElementById("result-count");

    const setPageItems = initPagination((pageItems) => {
      renderTable(
        grid,
        pageItems,
        "ランキング対象の再生リストがありません。",
        (item) => ({ rank: item._rank, showAgency: true })
      );
    }, 20);
    const sortLabels = { genre: "ジャンル", title: "タイトル", game: "ゲーム", agency: "事務所", streamer: "実況者", videoCount: "動画数", updatedDate: "更新日" };
    const render = initColumnSort((sortKey, dir) => {
      setPageItems(sortByColumn(topRanked, sortKey, dir));
      resultCount.textContent = "上位" + topRanked.length + "件を" + (sortKey ? sortLabels[sortKey] + "順" : "人気順") + "に表示中";
    });
    render();
  }

  if (typeof PLAYLISTS !== "undefined") {
    renderRanking(computeRankingList(getAllPlaylists()));
  } else if (typeof RANKING_LIST !== "undefined" && RANKING_LIST && RANKING_LIST.version === RANKING_LIST_VERSION && Array.isArray(RANKING_LIST.items)) {
    renderRanking(RANKING_LIST.items);
  } else {
    loadPlaylistsData().then(() => renderRanking(computeRankingList(getAllPlaylists())));
  }
})();
