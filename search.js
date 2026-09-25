(function () {
  const input = document.getElementById("q");
  const form = document.getElementById("search-form");
  const pagesizeSelect = document.getElementById("pagesize-select");
  const playTbody = document.getElementById("play-results");
  input.value = getQueryParam("q") || "";

  let currentPlaylistMatches = [];
  let currentPlaylistEmptyMessage = "該当する再生リストが見つかりませんでした。";
  const renderPlaylistTable = initColumnSort((sortKey, dir) => {
    renderTable(playTbody, sortByColumn(currentPlaylistMatches, sortKey, dir), currentPlaylistEmptyMessage, { showAgency: true });
  }, "updatedDate", -1);

  function pageSize() {
    const raw = pagesizeSelect ? parseInt(pagesizeSelect.value, 10) : 20;
    return raw > 0 ? raw : 20;
  }

  function renderEmpty(el, msg) {
    el.innerHTML = "";
    const div = document.createElement("div");
    div.className = "empty-state";
    div.textContent = msg;
    el.appendChild(div);
  }

  function resultItem(heading, meta) {
    const div = document.createElement("div");
    div.className = "search-result-item";
    const h3 = document.createElement("h3");
    h3.appendChild(heading);
    div.appendChild(h3);
    const metaDiv = document.createElement("div");
    metaDiv.className = "search-result-meta";
    if (typeof meta === "string") {
      metaDiv.textContent = meta;
    } else {
      metaDiv.appendChild(meta);
    }
    div.appendChild(metaDiv);
    return div;
  }

  function streamerResultItem(s) {
    const div = document.createElement("div");
    div.className = "search-result-item search-result-item--streamer";

    function showPlaceholder() {
      const placeholder = document.createElement("span");
      placeholder.className = "search-result-icon search-result-icon--placeholder";
      placeholder.textContent = s.name.charAt(0);
      div.prepend(placeholder);
    }

    if (s.icon) {
      const img = document.createElement("img");
      img.className = "search-result-icon";
      setIconImageSource(img, s.icon, 36); // .search-result-icon は 36px 四方
      img.alt = "";
      img.loading = "lazy";
      img.addEventListener("error", () => { img.remove(); showPlaceholder(); }, { once: true });
      div.appendChild(img);
    } else {
      showPlaceholder();
    }

    const textWrap = document.createElement("div");
    textWrap.className = "search-result-text";
    const h3 = document.createElement("h3");
    const a = document.createElement("a");
    a.href = streamerUrl(s.name);
    a.textContent = s.name;
    h3.appendChild(a);
    textWrap.appendChild(h3);
    const metaDiv = document.createElement("div");
    metaDiv.className = "search-result-meta";
    metaDiv.textContent = s.group || "";
    textWrap.appendChild(metaDiv);
    div.appendChild(textWrap);

    return div;
  }

  function renderResults(el, items, buildItem) {
    el.innerHTML = "";
    if (!items.length) {
      renderEmpty(el, "該当なし");
      return;
    }
    items.forEach((item) => el.appendChild(buildItem(item)));
  }

  function createStandaloneSearchCard(item) {
    const article = document.createElement("article");
    article.className = "play-card";

    const h3 = document.createElement("h3");
    const gameLink = document.createElement("a");
    gameLink.href = gameUrl(item.game);
    gameLink.textContent = gameDisplayName(item.game);
    h3.appendChild(gameLink);
    h3.appendChild(document.createTextNode(" "));
    const badge = document.createElement("span");
    badge.className = "format-badge";
    badge.textContent = playFormatLabel(item.format);
    h3.appendChild(badge);
    article.appendChild(h3);

    const pStreamer = document.createElement("p");
    const streamerLink = document.createElement("a");
    streamerLink.href = streamerUrl(item.streamer);
    streamerLink.textContent = item.streamer;
    pStreamer.appendChild(streamerLink);
    article.appendChild(pStreamer);

    const pTitle = document.createElement("p");
    pTitle.textContent = item.title || "";
    article.appendChild(pTitle);

    const actions = document.createElement("div");
    actions.className = "play-actions";
    const url = standalonePrimaryUrl(item);
    if (url) {
      const a = document.createElement("a");
      a.href = url;
      a.target = "_blank";
      a.rel = "noopener";
      a.textContent = "YouTubeで見る";
      actions.appendChild(a);
    }
    article.appendChild(actions);

    return article;
  }

  /** 2文字列の最長共通部分文字列(連続一致)の長さ。0件検索時の「近い候補」提案に使う簡易な近似一致。 */
  function longestCommonSubstringLength(a, b) {
    if (!a || !b) return 0;
    let best = 0;
    let prevRow = new Array(b.length + 1).fill(0);
    for (let i = 1; i <= a.length; i++) {
      const row = new Array(b.length + 1).fill(0);
      for (let j = 1; j <= b.length; j++) {
        if (a[i - 1] === b[j - 1]) {
          row[j] = prevRow[j - 1] + 1;
          if (row[j] > best) best = row[j];
        }
      }
      prevRow = row;
    }
    return best;
  }

  function findCloseGames(q, limit) {
    return GAMES
      .map((g) => ({ g, lcs: longestCommonSubstringLength(q, gameSearchText(g.name)) }))
      .filter((x) => x.lcs >= 2)
      .sort((a, b) => b.lcs - a.lcs)
      .slice(0, limit)
      .map((x) => x.g);
  }

  function findCloseStreamers(q, limit) {
    return STREAMERS
      .map((s) => ({
        s,
        lcs: longestCommonSubstringLength(q, normalizeSearchText([s.name, s.kana, s.aliases && s.aliases.join(" ")].filter(Boolean).join(" "))),
      }))
      .filter((x) => x.lcs >= 2)
      .sort((a, b) => b.lcs - a.lcs)
      .slice(0, limit)
      .map((x) => x.s);
  }

  function topGamesByCount(limit, exclude) {
    const counts = typeof PLAYLIST_COUNTS_BY_GAME === "undefined" ? {} : PLAYLIST_COUNTS_BY_GAME;
    const excludeSet = new Set((exclude || []).map((g) => g.name));
    return Object.keys(counts)
      .filter((name) => !excludeSet.has(name))
      .sort((a, b) => counts[b] - counts[a])
      .slice(0, limit)
      .map((name) => ({ name, count: counts[name] }));
  }

  function topStreamersByCount(limit, exclude) {
    const counts = typeof PLAYLIST_COUNTS_BY_STREAMER === "undefined" ? {} : PLAYLIST_COUNTS_BY_STREAMER;
    const excludeSet = new Set((exclude || []).map((s) => s.name));
    return Object.keys(counts)
      .filter((name) => !excludeSet.has(name))
      .sort((a, b) => counts[b] - counts[a])
      .slice(0, limit)
      .map((name) => ({ name, count: counts[name] }));
  }

  /**
   * ゲーム/VTuber/再生リスト/単発実況のすべてで0件だった場合に、
   * 「入力語に近いゲーム・VTuber」「人気のゲーム・VTuber」を代わりに提示する。
   * aliasesで拾いきれない表記ゆれ・誤字でも、何かしら次の行動につなげられるようにする。
   */
  function renderEmptyStateFallback(raw, q) {
    const section = document.getElementById("search-empty-section");
    const counts = typeof PLAYLIST_COUNTS_BY_GAME === "undefined" ? {} : PLAYLIST_COUNTS_BY_GAME;
    const streamerCounts = typeof PLAYLIST_COUNTS_BY_STREAMER === "undefined" ? {} : PLAYLIST_COUNTS_BY_STREAMER;

    document.getElementById("search-empty-term").textContent = raw;

    const closeGames = findCloseGames(q, 5);
    const closeGamesWrap = document.getElementById("search-empty-close-games-wrap");
    const closeGamesList = document.getElementById("search-empty-close-games");
    closeGamesList.innerHTML = "";
    closeGames.forEach((g) => closeGamesList.appendChild(createCountIndexItem(gameUrl(g.name), gameDisplayName(g.name), counts[g.name] || 0)));
    closeGamesWrap.hidden = !closeGames.length;

    const closeStreamers = findCloseStreamers(q, 6);
    const closeStreamersWrap = document.getElementById("search-empty-close-streamers-wrap");
    const closeStreamersList = document.getElementById("search-empty-close-streamers");
    closeStreamersList.innerHTML = "";
    closeStreamers.forEach((s) => closeStreamersList.appendChild(createStreamerCard(s.name, streamerCounts[s.name] || 0)));
    closeStreamersWrap.hidden = !closeStreamers.length;

    const popularGames = topGamesByCount(5, closeGames);
    const popularGamesWrap = document.getElementById("search-empty-popular-games-wrap");
    const popularGamesList = document.getElementById("search-empty-popular-games");
    popularGamesList.innerHTML = "";
    popularGames.forEach(({ name, count }) => popularGamesList.appendChild(createCountIndexItem(gameUrl(name), gameDisplayName(name), count)));
    popularGamesWrap.hidden = !popularGames.length;

    const popularStreamers = topStreamersByCount(6, closeStreamers);
    const popularStreamersWrap = document.getElementById("search-empty-popular-streamers-wrap");
    const popularStreamersList = document.getElementById("search-empty-popular-streamers");
    popularStreamersList.innerHTML = "";
    popularStreamers.forEach(({ name, count }) => popularStreamersList.appendChild(createStreamerCard(name, count)));
    popularStreamersWrap.hidden = !popularStreamers.length;

    section.hidden = false;
  }

  function render() {
    const raw = input.value.trim();
    const q = normalizeSearchText(raw);
    const ge = document.getElementById("game-results");
    const se = document.getElementById("streamer-results");
    const playCount = document.getElementById("play-result-count");
    const standaloneSection = document.getElementById("standalone-section");
    const standaloneResults = document.getElementById("standalone-results");
    const standaloneCount = document.getElementById("standalone-result-count");

    document.title = raw ? "「" + raw + "」の検索結果 | " + SITE_NAME : "サイト内検索 | " + SITE_NAME;

    const emptySection = document.getElementById("search-empty-section");

    if (!q) {
      renderEmpty(ge, "検索語を入力してください。");
      renderEmpty(se, "検索語を入力してください。");
      currentPlaylistEmptyMessage = "検索語を入力してください。";
      currentPlaylistMatches = [];
      renderPlaylistTable();
      playCount.textContent = "";
      standaloneSection.hidden = true;
      document.getElementById("search-summary").textContent = "";
      emptySection.hidden = true;
      return;
    }

    const limit = pageSize();

    const games = GAMES.map((g) => ({
      g,
      score: normalizeSearchText(g.name) === q ? 100
        : normalizeSearchText(g.name).startsWith(q) ? 90
        : gameSearchText(g.name).includes(q) ? 70
        : 0,
    })).filter((x) => x.score).sort((a, b) => b.score - a.score).slice(0, limit);

    const sts = STREAMERS.map((s) => {
      const nameNorm = normalizeSearchText(s.name);
      const hay = normalizeSearchText([s.name, s.kana, s.aliases && s.aliases.join(" ")].filter(Boolean).join(" "));
      const score = nameNorm === q ? 100
        : nameNorm.startsWith(q) ? 90
        : hay.includes(q) ? 70
        : 0;
      return { s, score };
    }).filter((x) => x.score).sort((a, b) => b.score - a.score).map((x) => x.s).slice(0, limit);

    const scoredEntries = allPlayEntries()
      .map((p) => ({ p, score: searchScore(p, raw) }))
      .filter((x) => x.score)
      .sort((a, b) => b.score - a.score);

    const playlistMatches = scoredEntries
      .filter((x) => x.p.sourceType === "playlist")
      .map((x) => x.p)
      .slice(0, limit);

    const standaloneMatches = scoredEntries
      .filter((x) => x.p.sourceType === "standalone")
      .map((x) => x.p)
      .slice(0, limit);

    renderResults(ge, games, (x) => {
      const a = document.createElement("a");
      a.href = gameUrl(x.g.name);
      a.textContent = gameDisplayName(x.g.name);
      return resultItem(a, x.g.series ? "シリーズ: " + x.g.series : "");
    });

    renderResults(se, sts, streamerResultItem);

    currentPlaylistEmptyMessage = "該当する再生リストが見つかりませんでした。";
    currentPlaylistMatches = playlistMatches;
    renderPlaylistTable();
    playCount.textContent = playlistMatches.length + " 件";

    standaloneResults.innerHTML = "";
    if (standaloneMatches.length) {
      standaloneSection.hidden = false;
      standaloneCount.textContent = standaloneMatches.length + " 件";
      standaloneMatches.forEach((x) => standaloneResults.appendChild(createStandaloneSearchCard(x)));
    } else {
      standaloneSection.hidden = true;
    }

    document.getElementById("search-summary").textContent =
      "「" + raw + "」の検索結果：ゲーム " + games.length + " / VTuber " + sts.length +
      " / 再生リスト " + playlistMatches.length + " / 単発 " + standaloneMatches.length;

    if (!games.length && !sts.length && !playlistMatches.length && !standaloneMatches.length) {
      renderEmptyStateFallback(raw, q);
    } else {
      emptySection.hidden = true;
    }
  }

  form.addEventListener("submit", (e) => {
    e.preventDefault();
    const term = input.value.trim();
    if (term) addRecentSearch(term);
    history.replaceState(null, "", "search.html?q=" + encodeURIComponent(term));
    render();
  });
  if (pagesizeSelect) pagesizeSelect.addEventListener("change", render);
  render();
})();
