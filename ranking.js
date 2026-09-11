(function () {
  const RANKING_LIMIT = 50;
  const byPopularity = getAllPlaylists().slice().sort((a, b) => calculatePopularity(b) - calculatePopularity(a));
  byPopularity.forEach((item, i) => { item._rank = i + 1; });
  const topRanked = byPopularity.slice(0, RANKING_LIMIT);

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
})();
