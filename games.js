(function () {
  const container = document.getElementById("category-list");
  const ul = document.createElement("ul");
  ul.className = "index-list";
  renderGameRowIndex(ul);
  container.innerHTML = "";
  container.appendChild(ul);

  // ---------- ゲーム名検索(927件のGAMESカタログ全体が対象) ----------
  // data-playlists.js(約2.4MB)は読み込まず、games.htmlに既に読み込まれている
  // data-core.js(GAMES)・data-counts.js(PLAYLIST_COUNTS_BY_GAME)だけで完結させる。
  // スコアリングは search.js / common.js の検索サジェストと同じ考え方
  // (完全一致 > 前方一致 > 部分一致)を再利用し、ロジックを重複実装しない。
  const input = document.getElementById("game-search-input");
  const sortSelect = document.getElementById("game-sort-select");
  const countEl = document.getElementById("game-search-count");
  const emptyEl = document.getElementById("game-search-empty");
  const resultsEl = document.getElementById("game-search-results");
  const clearBtn = document.getElementById("game-search-clear");

  function countOf(name) {
    return PLAYLIST_COUNTS_BY_GAME[name] || 0;
  }

  function scoreGame(g, q) {
    const nameNorm = normalizeSearchText(g.name);
    if (nameNorm === q) return 100;
    if (nameNorm.startsWith(q)) return 90;
    if (gameSearchText(g.name).includes(q)) return 70;
    return 0;
  }

  function render() {
    const raw = input.value.trim();
    const q = normalizeSearchText(raw);

    if (!q) {
      container.hidden = false;
      sortSelect.hidden = true;
      countEl.hidden = true;
      emptyEl.hidden = true;
      resultsEl.hidden = true;
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
      emptyEl.hidden = false;
      return;
    }

    emptyEl.hidden = true;
    countEl.hidden = false;
    countEl.textContent = GAMES.length + "ゲーム中 " + matches.length + "件";
    resultsEl.hidden = false;
    resultsEl.innerHTML = "";
    matches.forEach(({ g }) => {
      resultsEl.appendChild(createCountIndexItem(gameUrl(g.name), gameDisplayName(g.name), countOf(g.name)));
    });
  }

  input.addEventListener("input", debounce(render, 150));
  sortSelect.addEventListener("change", render);
  clearBtn.addEventListener("click", () => {
    input.value = "";
    render();
    input.focus();
  });
})();
