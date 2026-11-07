/**
 * 再生リスト一覧(playlists.html)。全再生リスト(data-playlists.js)を対象に、更新日の新しい順で表示する。
 * 検索・絞り込み・人気5ゲームの通常非表示・ページ送りは新着再生リスト(new.js)と共通(common.js)。
 */
(function () {
  const grid = document.getElementById("grid");
  const resultCount = document.getElementById("result-count");

  let sortKey = "updatedDate";
  let sortDir = -1;
  let summary = { shown: 0, total: 0, hidden: 0 };

  const setPageItems = initPagination((pageItems, start) => {
    renderTable(grid, pageItems, "条件に一致する再生リストが見つかりませんでした。", { showAgency: true });
    resultCount.textContent =
      summary.shown + " 件が該当 (全 " + summary.total + " 件中" + listHiddenNote(summary.hidden) + ") — " +
      (summary.shown ? start + 1 : 0) + "〜" + (start + pageItems.length) + " 件目を表示";
  }, 20, { topBar: document.getElementById("pagination-top"), scrollTarget: resultCount });

  function render() {
    const all = getAllPlaylists();
    const result = filterPlaylistsForList(all, controls.getFilters());
    summary = { shown: result.items.length, total: all.length, hidden: result.hiddenCount };
    // 条件・並び順が変わったら1ページ目から
    setPageItems(sortByColumn(result.items, sortKey, sortDir));
  }

  const controls = initPlaylistListControls(render);

  const triggerSort = initColumnSort((key, dir) => {
    sortKey = key;
    sortDir = dir;
    render();
  }, "updatedDate", -1);

  triggerSort();
})();
