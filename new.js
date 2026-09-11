(function () {
  const NEW_WITHIN_DAYS = 14;
  const NEW_LIMIT = 50;
  const now = new Date();

  const byAddedDate = getAllPlaylists().slice()
    .filter((p) => p.addedDate)
    .sort((a, b) => {
      const addedDiff = new Date(b.addedDate) - new Date(a.addedDate);
      if (addedDiff !== 0) return addedDiff;
      return new Date(b.updatedDate || 0) - new Date(a.updatedDate || 0);
    })
    .slice(0, NEW_LIMIT);

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
})();
