(function () {
  const container = document.getElementById("category-list");
  const ul = document.createElement("ul");
  ul.className = "index-list";
  renderGameRowIndex(ul);
  container.innerHTML = "";
  container.appendChild(ul);

  // ---------- ゲーム名検索(GAMESカタログ全体が対象。結果は24件ずつページ分けする) ----------
  // data-playlists.js(約2.4MB)は読み込まず、games.htmlに既に読み込まれている
  // data-core.js(GAMES)・data-counts.js(再生リスト・単発実況の件数)だけで完結させる。
  // スコアリングは search.js / common.js の検索サジェストと同じ考え方
  // (完全一致 > 前方一致 > 部分一致)を再利用し、ロジックを重複実装しない。
  const input = document.getElementById("game-search-input");
  const sortSelect = document.getElementById("game-sort-select");
  const countEl = document.getElementById("game-search-count");
  const emptyEl = document.getElementById("game-search-empty");
  const resultsEl = document.getElementById("game-search-results");
  const clearBtn = document.getElementById("game-search-clear");

  function countOf(name) {
    return listingCountOfGame(name);
  }

  function scoreGame(g, q) {
    const nameNorm = normalizeSearchText(g.name);
    if (nameNorm === q) return 100;
    if (nameNorm.startsWith(q)) return 90;
    if (gameSearchText(g.name).includes(q)) return 70;
    return 0;
  }

  // 検索条件(q・sort)とページ番号は URL に残し、戻る・進む・再読み込みで復元する
  const PAGE_SIZE = 24;
  const pagination = document.getElementById("pagination");
  const setItems = initPagination((pageItems) => {
    resultsEl.innerHTML = "";
    const fragment = document.createDocumentFragment();
    pageItems.forEach(({ g }) => {
      fragment.appendChild(createCountIndexItem(gameUrl(g.name), gameDisplayName(g.name), countOf(g.name)));
    });
    resultsEl.appendChild(fragment);
  }, PAGE_SIZE, { pageNumbers: document.getElementById("page-numbers"), urlParam: "page", scrollTarget: countEl });

  // 検索条件を URL に書く(入力のたびに履歴を増やさないよう置き換える。条件が変わったら1ページ目に戻す)
  function writeQueryToUrl() {
    const url = new URL(window.location.href);
    const raw = input.value.trim();
    if (raw) url.searchParams.set("q", raw); else url.searchParams.delete("q");
    if (raw && sortSelect.value === "count") url.searchParams.set("sort", "count"); else url.searchParams.delete("sort");
    url.searchParams.delete("page");
    if (url.href !== window.location.href) history.replaceState(null, "", url.href);
  }

  function readQueryFromUrl() {
    input.value = getQueryParam("q") || "";
    sortSelect.value = getQueryParam("sort") === "count" ? "count" : "relevance";
  }

  function render(page) {
    const raw = input.value.trim();
    const q = normalizeSearchText(raw);

    if (!q) {
      container.hidden = false;
      sortSelect.hidden = true;
      countEl.hidden = true;
      emptyEl.hidden = true;
      resultsEl.hidden = true;
      pagination.hidden = true;
      return;
    }

    container.hidden = true;
    sortSelect.hidden = false;

    const matches = GAMES.map((g) => ({ g: g, score: scoreGame(g, q) })).filter((x) => x.score > 0);

    if (sortSelect.value === "count") {
      matches.sort((a, b) => countOf(b.g.name) - countOf(a.g.name));
    } else {
      matches.sort((a, b) => b.score - a.score || countOf(b.g.name) - countOf(a.g.name));
    }

    if (!matches.length) {
      countEl.hidden = true;
      resultsEl.hidden = true;
      pagination.hidden = true;
      emptyEl.hidden = false;
      return;
    }

    emptyEl.hidden = true;
    countEl.hidden = false;
    countEl.textContent = GAMES.length + "ゲーム中 " + matches.length + "件";
    resultsEl.hidden = false;
    pagination.hidden = matches.length <= PAGE_SIZE;
    setItems(matches, { page: page || 1 });
  }

  // 条件が変わったときは1ページ目から(URL の page も外す)
  function onConditionChange() {
    writeQueryToUrl();
    render(1);
  }

  input.addEventListener("input", debounce(onConditionChange, 150));
  sortSelect.addEventListener("change", onConditionChange);
  clearBtn.addEventListener("click", () => {
    input.value = "";
    onConditionChange();
    input.focus();
  });
  // 戻る・進む: URL の検索条件とページ番号から表示し直す
  window.addEventListener("popstate", () => {
    readQueryFromUrl();
    render(readPageFromUrl("page"));
  });

  // 初期表示: URL に検索条件があれば、そのページから表示する
  readQueryFromUrl();
  if (input.value) render(readPageFromUrl("page"));
})();
