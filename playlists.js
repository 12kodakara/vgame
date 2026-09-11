(function () {
  const grid = document.getElementById("grid");
  const resultCount = document.getElementById("result-count");
  const searchInput = document.getElementById("search-input");
  const gameSelect = document.getElementById("game-select");
  const streamerSelect = document.getElementById("streamer-select");
  const genreSelect = document.getElementById("genre-select");
  const agencySelect = document.getElementById("agency-select");
  const pagesizeSelect = document.getElementById("pagesize-select");
  const pagePrev = document.getElementById("page-prev");
  const pageNext = document.getElementById("page-next");
  const pageIndicator = document.getElementById("page-indicator");
  const pageJumpForm = document.getElementById("page-jump-form");
  const pageJumpInput = document.getElementById("page-jump-input");

  let currentPage = 1;
  let totalPages = 1;
  let currentSortKey = "updatedDate";
  let currentSortDir = -1;

  const triggerSort = initColumnSort((sortKey, dir) => {
    currentSortKey = sortKey;
    currentSortDir = dir;
    currentPage = 1;
    render();
  }, "updatedDate", -1);

  const agencies = [];
  STREAMERS.forEach((s) => {
    const agency = agencyOf(s.name);
    if (agencies.indexOf(agency) === -1) agencies.push(agency);
  });

  function populateSelect(selectEl, values, allLabel) {
    selectEl.innerHTML = "";
    const allOpt = document.createElement("option");
    allOpt.value = "";
    allOpt.textContent = allLabel;
    selectEl.appendChild(allOpt);
    values.forEach((v) => {
      const opt = document.createElement("option");
      opt.value = v;
      opt.textContent = v;
      selectEl.appendChild(opt);
    });
  }

  function populateStreamerSelect(agency) {
    const current = streamerSelect.value;
    const names = uniqueSorted(
      getAllPlaylists().filter((p) => !agency || agencyOf(p.streamer) === agency).map((p) => p.streamer)
    );
    populateSelect(streamerSelect, names, "すべて");
    if (names.indexOf(current) !== -1) streamerSelect.value = current;
  }

  function populateGenreSelect() {
    genreSelect.innerHTML = "";
    const allOpt = document.createElement("option");
    allOpt.value = "";
    allOpt.textContent = "すべてのジャンル";
    genreSelect.appendChild(allOpt);
    GENRES.forEach((g) => {
      const opt = document.createElement("option");
      opt.value = g.id;
      opt.textContent = g.label;
      genreSelect.appendChild(opt);
    });
  }

  function applyInitialParams() {
    const q = getQueryParam("q");
    const g = getQueryParam("genre");
    const game = getQueryParam("game");
    const agency = getQueryParam("agency");
    if (q) searchInput.value = q;
    if (g) genreSelect.value = g;
    if (game) gameSelect.value = game;
    if (agency) agencySelect.value = agency;
  }

  function matchesFilters(item) {
    const q = normalizeSearchText(searchInput.value);
    const game = gameSelect.value;
    const streamer = streamerSelect.value;
    const genre = genreSelect.value;
    const agency = agencySelect.value;

    if (game && item.game !== game) return false;
    if (streamer && item.streamer !== streamer) return false;
    if (genre && item.genre !== genre) return false;
    if (agency && agencyOf(item.streamer) !== agency) return false;

    if (q) {
      const haystack = normalizeSearchText([
        item.title,
        item.streamer,
        item.note,
        gameSearchText(item.game),
      ].filter(Boolean).join(" "));
      if (!haystack.includes(q)) return false;
    }
    return true;
  }

  function render() {
    const filtered = sortByColumn(getAllPlaylists().filter(matchesFilters), currentSortKey, currentSortDir);
    const pageSize = parseInt(pagesizeSelect.value, 10);
    totalPages = Math.max(1, Math.ceil(filtered.length / pageSize));
    if (currentPage > totalPages) currentPage = totalPages;
    if (currentPage < 1) currentPage = 1;

    const start = (currentPage - 1) * pageSize;
    const pageItems = filtered.slice(start, start + pageSize);

    renderTable(grid, pageItems, "条件に一致する再生リストが見つかりませんでした。", { showAgency: true });
    resultCount.textContent =
      filtered.length + " 件が該当 (全 " + getAllPlaylists().length + " 件中) — " +
      (filtered.length ? start + 1 : 0) + "〜" + (start + pageItems.length) + " 件目を表示";

    pageIndicator.textContent = currentPage + " / " + totalPages + " ページ";
    pagePrev.disabled = currentPage <= 1;
    pageNext.disabled = currentPage >= totalPages;
    if (pageJumpInput) {
      pageJumpInput.max = String(totalPages);
      pageJumpInput.placeholder = String(currentPage);
    }
  }

  function renderFromFilterChange() {
    currentPage = 1;
    render();
  }

  populateSelect(gameSelect, uniqueSorted(getAllPlaylists().map((p) => p.game)), "すべてのゲーム");
  Array.from(gameSelect.options).forEach((opt) => {
    if (opt.value) opt.textContent = gameDisplayName(opt.value);
  });
  populateSelect(agencySelect, agencies, "すべての事務所");
  populateGenreSelect();
  applyInitialParams();
  populateStreamerSelect(agencySelect.value);
  const initialStreamer = getQueryParam("streamer");
  if (initialStreamer) streamerSelect.value = initialStreamer;

  agencySelect.addEventListener("change", () => {
    populateStreamerSelect(agencySelect.value);
    renderFromFilterChange();
  });

  // 検索欄はキー入力のたびに数千件を再描画しないよう、入力が落ち着いてから絞り込む。
  // セレクト(ゲーム/実況者/ジャンル)は選択確定時に1回だけ発火する change のみを見る
  // (input と change の両方を登録すると、選択のたびに二重で再描画してしまうため)。
  searchInput.addEventListener("input", debounce(renderFromFilterChange, 150));
  [gameSelect, streamerSelect, genreSelect].forEach((el) => {
    el.addEventListener("change", renderFromFilterChange);
  });

  pagesizeSelect.addEventListener("change", renderFromFilterChange);

  pagePrev.addEventListener("click", () => {
    currentPage -= 1;
    render();
  });
  pageNext.addEventListener("click", () => {
    currentPage += 1;
    render();
  });
  if (pageJumpForm) {
    pageJumpForm.addEventListener("submit", (e) => {
      e.preventDefault();
      const page = parseInt(pageJumpInput.value, 10);
      if (!page) return;
      currentPage = Math.min(Math.max(page, 1), totalPages);
      render();
      pageJumpInput.value = "";
    });
  }

  triggerSort();
})();
