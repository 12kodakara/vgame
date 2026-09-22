(function () {
  const streamer = getQueryParam("streamer") || "";

  // 実況者一覧(STREAMERS)に無く、再生リスト・単発実況も1件も無い名前は存在しないVTuberとして扱う。
  // STREAMERSに登録済みで再生リストがまだ無いVTuberは、従来どおり空のページ(noindex)を表示する。
  const hasAnyPlay =
    getPlaylistsByStreamer(streamer).length > 0 ||
    (typeof STANDALONE_PLAYS !== "undefined" && STANDALONE_PLAYS.some((p) => p.streamer === streamer));
  if (!streamerByName[streamer] && !hasAnyPlay) {
    renderNotFoundPage({
      title: streamer ? "VTuberが見つかりません" : "VTuberが指定されていません",
      message: streamer
        ? "「" + streamer + "」というVTuberは、ぶいゲーに登録されていません。名前が変わったか、URLが間違っている可能性があります。"
        : "表示するVTuberが指定されていません。",
      backHref: "streamers.html",
      backLabel: "VTuber一覧へ戻る",
      docTitle: "VTuberが見つかりません | " + SITE_NAME,
    });
    return;
  }

  document.getElementById("page-title").textContent = streamer
    ? streamer + " の再生リスト"
    : "実況者が指定されていません";
  document.getElementById("breadcrumb-current").textContent = streamer || "不明な実況者";

  const roster = streamerByName[streamer];
  const metaEl = document.getElementById("page-meta");
  if (metaEl && roster && roster.group) {
    metaEl.textContent = "所属: " + roster.group;
    metaEl.hidden = false;
  }

  const iconEl = document.getElementById("streamer-icon");
  if (iconEl && roster && roster.icon) {
    iconEl.addEventListener("error", () => { iconEl.hidden = true; }, { once: true });
    iconEl.src = roster.icon;
    iconEl.alt = streamer + " のアイコン";
    iconEl.hidden = false;
  }

  const socialLinksEl = document.getElementById("social-links");
  const youtubeLinkEl = document.getElementById("social-youtube");
  const xLinkEl = document.getElementById("social-x");
  let hasSocialLink = false;
  if (roster && roster.youtube) {
    youtubeLinkEl.href = roster.youtube;
    youtubeLinkEl.hidden = false;
    hasSocialLink = true;
  }
  if (roster && roster.x) {
    xLinkEl.href = roster.x;
    xLinkEl.hidden = false;
    hasSocialLink = true;
  }
  if (socialLinksEl && hasSocialLink) socialLinksEl.hidden = false;

  const items = getPlaylistsByStreamer(streamer);
  const standalone = (typeof STANDALONE_PLAYS === "undefined" ? [] : STANDALONE_PLAYS).filter((p) => p.streamer === streamer);

  // 再生リスト・単発実況が1件も無いVTuberは、ページの本題である再生リストが
  // 空のままになるため、検索結果には出さない(noindex)が、他ページからの
  // リンクは辿れるようにする(follow)。STREAMERS(data-core.js)にだけ登録
  // されていてPLAYLISTS側のデータがまだ無い実況者が対象。
  if (streamer && items.length === 0 && standalone.length === 0) {
    let robotsMeta = document.querySelector('meta[name="robots"]');
    if (!robotsMeta) {
      robotsMeta = document.createElement("meta");
      robotsMeta.setAttribute("name", "robots");
      document.head.appendChild(robotsMeta);
    }
    robotsMeta.setAttribute("content", "noindex,follow");
  }

  // ---------- 統計(実況したゲーム数・再生リスト数) ----------
  const gameCounts = {};
  const gameOrder = [];
  function bumpGame(name) {
    if (!gameCounts[name]) {
      gameCounts[name] = 0;
      gameOrder.push(name);
    }
    gameCounts[name] += 1;
  }
  items.forEach((p) => bumpGame(p.game));
  standalone.forEach((p) => bumpGame(p.game));

  const totalVideos =
    items.reduce((sum, p) => sum + (p.videoCount || 0), 0) +
    standalone.reduce((sum, p) => sum + standalonePlayCount(p), 0);

  document.getElementById("stat-games").textContent = gameOrder.length ? gameOrder.length + "種類" : "-";
  document.getElementById("stat-playlists").textContent = items.length + "件";
  document.getElementById("stat-videos").textContent = totalVideos ? totalVideos + "本" : "-";

  if (streamer) {
    const statsSummary =
      "実況したゲーム" + gameOrder.length + "種類・再生リスト" + items.length + "件" +
      (totalVideos ? "・動画" + totalVideos + "本" : "") + "を掲載。";
    const representativeThumb = items.find((p) => getPlaylistThumbnailUrl(p));
    setPageMeta(
      streamer + "のゲーム実況・再生リスト一覧 | " + SITE_NAME,
      streamer + "が実況したゲームの一覧と再生リストをまとめて紹介。" + statsSummary,
      "/streamer.html?streamer=" + encodeURIComponent(streamer),
      representativeThumb ? getPlaylistThumbnailUrl(representativeThumb) : (roster && roster.icon) || null
    );
    recordRecentlyViewed("streamer", { key: streamer, label: streamer, url: streamerUrl(streamer) });
    initFavoriteButton(document.getElementById("favorite-btn"), "streamer", { key: streamer, label: streamer, url: streamerUrl(streamer) });
  }

  // 補助セクション(人気実況・最近更新)が「すべての再生リスト」と実質同じ内容に
  // なる場合、その補助セクションごと非表示にする。件数の一致ではなく、
  // 一意なplaylist id集合が完全に一致するか(＝メイン一覧に無い項目も、
  // メイン一覧にしか無い項目も無いか)で判定するため、データが増減しても
  // 閾値の手動調整なしに自動で正しく動作する。
  function isSameItemSet(subset, mainSet) {
    if (subset.length !== mainSet.length) return false;
    const mainIds = new Set(mainSet.map((p) => p.id));
    return subset.every((p) => mainIds.has(p.id));
  }

  // ---------- 人気実況(このVTuberの再生リストのうち人気度が高い上位5件) ----------
  const popularItems = items
    .slice()
    .sort((a, b) => calculatePopularity(b) - calculatePopularity(a))
    .slice(0, 5);
  if (document.getElementById("streamer-popular-section") && popularItems.length && !isSameItemSet(popularItems, items)) {
    document.getElementById("streamer-popular-section").hidden = false;
    renderPlaylistDiscoverList("streamer-popular-list", popularItems, "", { showStreamer: false });
  }

  // ---------- 最近更新された実況(このVTuberの再生リストのうち更新日が新しい上位5件) ----------
  const recentUpdated = items
    .filter((p) => p.updatedDate || p.addedDate)
    .slice()
    .sort((a, b) => new Date(b.updatedDate || b.addedDate) - new Date(a.updatedDate || a.addedDate))
    .slice(0, 5);
  if (document.getElementById("streamer-recent-section") && recentUpdated.length && !isSameItemSet(recentUpdated, items)) {
    document.getElementById("streamer-recent-section").hidden = false;
    renderPlaylistDiscoverList("streamer-recent-list", recentUpdated, "", { showStreamer: false });
  }

  // ---------- 同じ事務所・グループのVTuber ----------
  const myAgency = (roster && roster.group ? roster.group : "その他").split(" ")[0];
  const streamerPlaylistCounts = typeof PLAYLIST_COUNTS_BY_STREAMER === "undefined" ? {} : PLAYLIST_COUNTS_BY_STREAMER;
  const agencyMates = STREAMERS
    .filter((s) => s.name !== streamer && (s.group || "その他").split(" ")[0] === myAgency)
    .map((s) => ({ name: s.name, count: streamerPlaylistCounts[s.name] || 0 }))
    .sort((a, b) => b.count - a.count || a.name.localeCompare(b.name, "ja"))
    .slice(0, 10);

  const agencySection = document.getElementById("streamer-agency-section");
  const agencyGrid = document.getElementById("streamer-agency-grid");
  if (agencySection && agencyGrid && roster && roster.group && agencyMates.length) {
    agencySection.hidden = false;
    agencyGrid.innerHTML = "";
    agencyMates.forEach(({ name, count }) => {
      agencyGrid.appendChild(createStreamerCard(name, count));
    });
  }

  // ---------- このVTuberが実況したゲーム一覧 ----------
  const GAMES_SHOWN_INITIALLY = 10;
  const gamesSection = document.getElementById("streamer-games-section");
  const gamesList = document.getElementById("streamer-games-list");
  const gamesMoreBtn = document.getElementById("streamer-games-more");
  const gameList = gameOrder
    .map((name) => ({ name: name, count: gameCounts[name] }))
    .sort((a, b) => b.count - a.count || gameDisplayName(a.name).localeCompare(gameDisplayName(b.name), "ja"));
  if (gamesSection && gamesList && gameList.length) {
    gamesSection.hidden = false;

    function renderGameList(expanded) {
      gamesList.innerHTML = "";
      const visible = expanded ? gameList : gameList.slice(0, GAMES_SHOWN_INITIALLY);
      visible.forEach(({ name, count }) => {
        gamesList.appendChild(createCountIndexItem(gameUrl(name), gameDisplayName(name), count));
      });
    }

    let gamesExpanded = false;
    renderGameList(gamesExpanded);

    if (gamesMoreBtn && gameList.length > GAMES_SHOWN_INITIALLY) {
      gamesMoreBtn.hidden = false;
      gamesMoreBtn.textContent = "もっと見る →";
      gamesMoreBtn.addEventListener("click", () => {
        gamesExpanded = !gamesExpanded;
        renderGameList(gamesExpanded);
        gamesMoreBtn.textContent = gamesExpanded ? "元に戻す ←" : "もっと見る →";
        gamesMoreBtn.setAttribute("aria-expanded", String(gamesExpanded));
      });
    }
  }

  // ---------- よく実況しているジャンル ----------
  const genreCounts = {};
  const genreOrder = [];
  items.forEach((p) => {
    if (!genreCounts[p.genre]) {
      genreCounts[p.genre] = 0;
      genreOrder.push(p.genre);
    }
    genreCounts[p.genre] += 1;
  });
  const genreList = genreOrder
    .map((id) => ({ id: id, label: (genreById[id] || genreById.other).label, count: genreCounts[id] }))
    .sort((a, b) => b.count - a.count || a.label.localeCompare(b.label, "ja"));

  const genresSection = document.getElementById("streamer-genres-section");
  const genresListEl = document.getElementById("streamer-genres-list");
  if (genresSection && genresListEl && genreList.length) {
    genresSection.hidden = false;
    genresListEl.innerHTML = "";
    genreList.forEach(({ id, label, count }) => {
      const href = "playlists.html?streamer=" + encodeURIComponent(streamer) + "&genre=" + encodeURIComponent(id);
      genresListEl.appendChild(createCountIndexItem(href, label, count));
    });
  }

  // ---------- 同じゲームを実況しているVTuber ----------
  // このVTuberが実況したゲームと、他のVTuberが実況しているゲームの一致数を集計し、
  // 一致数が多いVTuberを上位表示する(本人は除外)。手動登録ではなく既存データから自動算出。
  const myGames = new Set(gameOrder);
  const overlapGames = {};
  const overlapOrder = [];
  getAllPlaylists().forEach((p) => {
    if (p.streamer === streamer || !myGames.has(p.game)) return;
    if (!overlapGames[p.streamer]) {
      overlapGames[p.streamer] = new Set();
      overlapOrder.push(p.streamer);
    }
    overlapGames[p.streamer].add(p.game);
  });
  const relatedStreamers = overlapOrder
    .map((name) => ({ name: name, count: overlapGames[name].size }))
    .sort((a, b) => b.count - a.count || a.name.localeCompare(b.name, "ja"))
    .slice(0, 10);

  const relatedSection = document.getElementById("streamer-related-section");
  const relatedGrid = document.getElementById("streamer-related-grid");
  if (relatedSection && relatedGrid && relatedStreamers.length) {
    relatedSection.hidden = false;
    relatedGrid.innerHTML = "";
    relatedStreamers.forEach(({ name, count }) => {
      relatedGrid.appendChild(createStreamerCard(name, count));
    });
  }

  const grid = document.getElementById("grid");
  document.getElementById("result-count").textContent = items.length + " 件の再生リスト / " + standalone.length + " 件の単発・PLなし実況";

  const setPageItems = initPagination((pageItems) => {
    renderTable(grid, pageItems, "この実況者の再生リストはまだ登録されていません。", { showStreamer: false });
  }, 20);
  const render = initColumnSort((sortKey, dir) => {
    setPageItems(sortByColumn(items, sortKey, dir));
  }, "updatedDate", -1);
  render();

  const section = document.getElementById("standalone-section");
  const sg = document.getElementById("standalone-grid");
  const ss = document.getElementById("standalone-summary");
  if (section && standalone.length) {
    section.hidden = false;
    const counts = { single: 0, multi: 0, "mixed-playlist": 0 };
    standalone.forEach((x) => { if (counts[x.format] != null) counts[x.format]++; });
    ss.innerHTML = "";
    Object.keys(counts).filter((k) => counts[k]).forEach((k) => {
      const chip = document.createElement("span");
      chip.className = "summary-chip";
      chip.textContent = playFormatLabel(k) + " " + counts[k] + "件";
      ss.appendChild(chip);
    });
    standalone.forEach((x) => sg.appendChild(createStandaloneCard(x, { showGame: true })));
  }
})();
