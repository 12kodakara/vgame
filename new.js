/**
 * 新着再生リスト(new.html)。
 * 新着50件の選び方は computeNewList() にまとめてある。ページでは数MBある data-playlists.js を
 * 読み込まず、generate-list-data.js がこの同じ関数で事前に作った data-new.js(NEW_LIST)を使う。
 * NEW_LIST が使えない場合だけ data-playlists.js を読み込んで同じ関数で集計する(表示は同じ)。
 * 「NEW」バッジ(追加から14日以内)は閲覧した日を基準にするため、従来どおりページ側で判定する。
 *
 * 検索・絞り込み・人気5ゲームの通常非表示・ページ送りは再生リスト一覧(playlists.js)と共通(common.js)。
 * 検索語・絞り込みを指定したときだけ data-playlists.js を読み込み(1回だけ)、全再生リストを追加日の新しい順で
 * 絞り込む。条件をすべて外すと新着50件の表示に戻る。並び替え・ページ送り・表示件数の変更では読み込まない。
 */
const NEW_WITHIN_DAYS = 14;
const NEW_LIMIT = 50;
const NEW_LIST_VERSION = 1;

/**
 * 全再生リストから追加日が新しい順(同日は更新日が新しい順)に limit 件(省略時50件)を選ぶ(DOMに触れない純粋関数)。
 * limit に Infinity を渡すと全件を同じ順で返す(全件から絞り込むとき用)。
 */
function computeNewList(playlists, limit) {
  return playlists.slice()
    .filter((p) => p.addedDate)
    .sort((a, b) => {
      const addedDiff = new Date(b.addedDate) - new Date(a.addedDate);
      if (addedDiff !== 0) return addedDiff;
      return new Date(b.updatedDate || 0) - new Date(a.updatedDate || 0);
    })
    .slice(0, limit == null ? NEW_LIMIT : limit);
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

    const sortLabels = { genre: "ジャンル", title: "タイトル", game: "ゲーム", agency: "事務所", streamer: "実況者", videoCount: "動画数", updatedDate: "更新日" };
    let sortKey = null;
    let sortDir = 0;
    let allByAddedDate = null; // 全件を追加日順に並べたもの(読み込み後に1回だけ作る)
    let requestSeq = 0;        // 読み込み中に条件が変わったとき、古い結果で上書きしないための番号
    let summary = { shown: 0, full: false, hidden: 0 };

    const setPageItems = initPagination((pageItems, start) => {
      renderTable(grid, pageItems, "条件に一致する再生リストが見つかりませんでした。", rowOpts);
      if (grid.hasAttribute("aria-busy")) return; // 全件の読み込み中は「読み込み中」の表示を残す
      const order = sortKey ? sortLabels[sortKey] + "順" : "追加日の新しい順";
      const range = (summary.shown ? start + 1 : 0) + "〜" + (start + pageItems.length) + " 件目を表示";
      resultCount.textContent = summary.full
        ? "全再生リストから " + summary.shown + " 件が該当 (" + order + listHiddenNote(summary.hidden) + ") — " + range
        : "新着" + byAddedDate.length + "件のうち " + summary.shown + " 件を" + order + "に表示中" +
          (summary.hidden ? " (" + listHiddenNote(summary.hidden).slice(1) + ")" : "") + " — " + range;
    }, 20, { topBar: document.getElementById("pagination-top"), scrollTarget: resultCount });

    function show(items, full, hidden) {
      grid.removeAttribute("aria-busy");
      summary = { shown: items.length, full: full, hidden: hidden };
      setPageItems(sortByColumn(items, sortKey, sortDir));
    }

    function showLoadError(seq) {
      if (seq !== requestSeq) return;
      grid.removeAttribute("aria-busy");
      resultCount.textContent = "全再生リストを読み込めませんでした。";
      const retry = document.createElement("button");
      retry.type = "button";
      retry.className = "result-retry";
      retry.textContent = "再読み込み";
      retry.addEventListener("click", render);
      resultCount.appendChild(document.createTextNode(" "));
      resultCount.appendChild(retry);
    }

    function render() {
      const seq = ++requestSeq;
      const filters = controls.getFilters();
      if (!hasPlaylistListFilters(filters)) {
        // 条件なし: 新着50件(人気5ゲームは外す)。全件データは読み込まない
        const result = filterPlaylistsForList(byAddedDate, filters);
        show(result.items, false, result.hiddenCount);
        return;
      }
      if (typeof PLAYLISTS !== "undefined") {
        if (!allByAddedDate) allByAddedDate = computeNewList(getAllPlaylists(), Infinity);
        const result = filterPlaylistsForList(allByAddedDate, filters);
        show(result.items, true, result.hiddenCount);
        return;
      }
      // 検索・絞り込みを指定した: 全件データを読み込む(読み込み中・連続操作でも読み込みは1回。失敗時は再試行できる)
      grid.setAttribute("aria-busy", "true");
      resultCount.textContent = "全再生リストを読み込み中…";
      loadPlaylistsData().then(() => { if (seq === requestSeq) render(); }, () => showLoadError(seq));
    }

    const controls = initPlaylistListControls(render);

    const triggerSort = initColumnSort((key, dir) => {
      sortKey = key;
      sortDir = dir;
      render();
    });
    triggerSort();
  }

  if (typeof PLAYLISTS !== "undefined") {
    renderNew(computeNewList(getAllPlaylists()));
  } else if (typeof NEW_LIST !== "undefined" && NEW_LIST && NEW_LIST.version === NEW_LIST_VERSION && Array.isArray(NEW_LIST.items)) {
    renderNew(NEW_LIST.items);
  } else {
    loadPlaylistsData().then(() => renderNew(computeNewList(getAllPlaylists())));
  }
})();
