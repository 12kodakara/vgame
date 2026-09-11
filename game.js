(function () {
  const game = getQueryParam("game") || "";

  document.getElementById("page-title").textContent = game
    ? gameDisplayName(game)
    : "ゲームが指定されていません";
  document.getElementById("breadcrumb-current").textContent = game ? gameDisplayName(game) : "不明なゲーム";
  const pageLeadEl = document.getElementById("page-lead");
  if (pageLeadEl && game) {
    pageLeadEl.textContent = "VTuberによる" + gameDisplayName(game) + "実況・再生リストをまとめています。";
  }

  if (game) {
    recordRecentlyViewed("game", { key: game, label: gameDisplayName(game), url: gameUrl(game) });
    initFavoriteButton(document.getElementById("favorite-btn"), "game", { key: game, label: gameDisplayName(game), url: gameUrl(game) });
  }

  const catalog = gameCatalogOf(game);
  const metaEl = document.getElementById("page-meta");
  if (metaEl && catalog && catalog.series) {
    metaEl.textContent = "シリーズ: " + catalog.series;
    metaEl.hidden = false;
  }

  const items = getPlaylistsByGame(game);
  const standalone = (typeof STANDALONE_PLAYS === "undefined" ? [] : STANDALONE_PLAYS).filter((p) => p.game === game);

  // ---------- 統計(実況VTuber数・再生リスト数・動画数・最終更新日) ----------
  const streamerNames = new Set();
  items.forEach((p) => streamerNames.add(p.streamer));
  standalone.forEach((p) => streamerNames.add(p.streamer));

  const totalVideos =
    items.reduce((sum, p) => sum + (p.videoCount || 0), 0) +
    standalone.reduce((sum, p) => sum + standalonePlayCount(p), 0);

  const lastUpdated = items.reduce((latest, p) => {
    const d = p.updatedDate || p.addedDate || "";
    return d && d > latest ? d : latest;
  }, "");

  document.getElementById("stat-streamers").textContent = streamerNames.size ? streamerNames.size + "組" : "-";
  document.getElementById("stat-playlists").textContent = items.length + "件";
  document.getElementById("stat-videos").textContent = totalVideos ? totalVideos + "本" : "-";
  document.getElementById("stat-updated").textContent = lastUpdated ? formatDate(lastUpdated) : "-";

  if (game) {
    const statsSummary =
      "実況VTuber" + streamerNames.size + "組・再生リスト" + items.length + "件" +
      (totalVideos ? "・動画" + totalVideos + "本" : "") +
      (lastUpdated ? "(最終更新: " + formatDate(lastUpdated) + ")" : "") + "。";
    const representativeThumb = items.find((p) => getPlaylistThumbnailUrl(p));
    setPageMeta(
      gameDisplayName(game) + "を実況しているVTuber一覧 | " + SITE_NAME,
      gameDisplayName(game) + "を実況しているVTuberの再生リスト・動画をまとめて紹介。" + statsSummary,
      "/game.html?game=" + encodeURIComponent(game),
      representativeThumb ? getPlaylistThumbnailUrl(representativeThumb) : null
    );
  }

  // ---------- 人気実況(このゲームの再生リストのうち人気度が高い上位5件) ----------
  const popularItems = items
    .slice()
    .sort((a, b) => calculatePopularity(b) - calculatePopularity(a))
    .slice(0, 5);
  if (document.getElementById("game-popular-section") && popularItems.length) {
    document.getElementById("game-popular-section").hidden = false;
    renderPlaylistDiscoverList("game-popular-list", popularItems, "", { showGame: false });
  }

  // ---------- 最近更新された実況(このゲームの再生リストのうち更新日が新しい上位5件) ----------
  const recentItems = items
    .filter((p) => p.updatedDate || p.addedDate)
    .slice()
    .sort((a, b) => new Date(b.updatedDate || b.addedDate) - new Date(a.updatedDate || a.addedDate))
    .slice(0, 5);
  if (document.getElementById("game-recent-section") && recentItems.length) {
    document.getElementById("game-recent-section").hidden = false;
    renderPlaylistDiscoverList("game-recent-list", recentItems, "", { showGame: false });
  }

  // ---------- このゲームを実況しているVTuber ----------
  const streamerStats = {};
  const streamerOrder = [];
  function bumpStreamer(name, videoCount) {
    if (!streamerStats[name]) {
      streamerStats[name] = { playlistCount: 0, videoCount: 0 };
      streamerOrder.push(name);
    }
    streamerStats[name].playlistCount += 1;
    streamerStats[name].videoCount += videoCount;
  }
  items.forEach((p) => bumpStreamer(p.streamer, p.videoCount || 0));
  standalone.forEach((p) => bumpStreamer(p.streamer, standalonePlayCount(p)));

  const streamerList = streamerOrder
    .map((name) => ({ name: name, stat: streamerStats[name] }))
    .sort((a, b) => b.stat.videoCount - a.stat.videoCount || a.name.localeCompare(b.name, "ja"));

  const STREAMERS_SHOWN_INITIALLY = 30;
  const streamerSection = document.getElementById("game-streamer-section");
  const streamerGrid = document.getElementById("game-streamer-grid");
  const streamerMoreBtn = document.getElementById("game-streamer-more");
  if (streamerSection && streamerGrid && streamerList.length) {
    streamerSection.hidden = false;

    function renderStreamerGrid(expanded) {
      streamerGrid.innerHTML = "";
      const visible = expanded ? streamerList : streamerList.slice(0, STREAMERS_SHOWN_INITIALLY);
      visible.forEach(({ name, stat }) => {
        streamerGrid.appendChild(createStreamerCard(name, stat.playlistCount));
      });
    }

    let streamersExpanded = false;
    renderStreamerGrid(streamersExpanded);

    if (streamerMoreBtn && streamerList.length > STREAMERS_SHOWN_INITIALLY) {
      streamerMoreBtn.hidden = false;
      streamerMoreBtn.addEventListener("click", () => {
        streamersExpanded = !streamersExpanded;
        renderStreamerGrid(streamersExpanded);
        streamerMoreBtn.textContent = streamersExpanded ? "元に戻す ←" : "すべてを見る →";
      });
    }
  }

  // ---------- 関連ゲーム ----------
  // 「このゲームを実況しているVTuberが、他にどのゲームを実況しているか」を
  // PLAYLISTS全体から集計し、重複度(件数)が高いゲームを関連ゲームとして表示する。
  // 手動登録ではなく既存データからの自動算出。対象ゲーム自身は除外する。
  const relatedCounts = {};
  const relatedOrder = [];
  getAllPlaylists().forEach((p) => {
    if (p.game === game || !streamerNames.has(p.streamer)) return;
    if (!relatedCounts[p.game]) {
      relatedCounts[p.game] = 0;
      relatedOrder.push(p.game);
    }
    relatedCounts[p.game] += 1;
  });
  // 上位候補(最大15件)まではしっかり関連性を確保しつつ、その中からシャッフルして
  // 6件だけ表示することで、毎回同じ顔ぶれにならないようにする(表示のたびに変わる)。
  const relatedCandidates = relatedOrder
    .map((name) => ({ name: name, count: relatedCounts[name] }))
    .sort((a, b) => b.count - a.count || gameDisplayName(a.name).localeCompare(gameDisplayName(b.name), "ja"))
    .slice(0, 15);
  for (let i = relatedCandidates.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [relatedCandidates[i], relatedCandidates[j]] = [relatedCandidates[j], relatedCandidates[i]];
  }
  const relatedGames = relatedCandidates.slice(0, 6);

  const relatedSection = document.getElementById("game-related-section");
  const relatedList = document.getElementById("game-related-list");
  if (relatedSection && relatedList && relatedGames.length) {
    relatedSection.hidden = false;
    relatedList.innerHTML = "";
    relatedGames.forEach(({ name, count }) => {
      relatedList.appendChild(createCountIndexItem(gameUrl(name), gameDisplayName(name), count));
    });
  }

  // ---------- 独自編集コンテンツ(data-game-editorial.js に登録されているゲームのみ表示) ----------
  // GAME_EDITORIAL に該当ゲームのキーが無い場合は何も表示しない(従来のページ構成のまま)。
  const editorial = (typeof GAME_EDITORIAL === "undefined" ? null : GAME_EDITORIAL[game]) || null;
  if (editorial) {
    const introBox = document.getElementById("game-editorial-intro-box");
    const introEl = document.getElementById("game-editorial-intro");
    if (introBox && introEl && editorial.intro) {
      introEl.textContent = editorial.intro;
      introBox.hidden = false;
    }

    const watchingBox = document.getElementById("game-editorial-watching-box");
    const watchingEl = document.getElementById("game-editorial-watching");
    if (watchingBox && watchingEl && editorial.watchingPoints) {
      watchingEl.textContent = editorial.watchingPoints;
      watchingBox.hidden = false;
    }

    const howToBox = document.getElementById("game-editorial-howto-box");
    const howToEl = document.getElementById("game-editorial-howto");
    if (howToBox && howToEl && editorial.howToFind) {
      howToEl.textContent = editorial.howToFind;
      howToBox.hidden = false;

      const linksList = document.getElementById("game-editorial-links");
      if (linksList) {
        linksList.innerHTML = "";
        [
          { href: "streamers.html", label: "🎥 VTuberから探す" },
          { href: "ranking.html", label: "🏆 人気ランキング" },
          { href: "new.html", label: "🆕 新着／最近更新" },
          { href: "playlists.html", label: "📺 再生リスト一覧" },
        ].forEach(({ href, label }) => {
          const li = document.createElement("li");
          const a = document.createElement("a");
          a.href = href;
          a.textContent = label;
          li.appendChild(a);
          linksList.appendChild(li);
        });
      }
    }

    const recommendBox = document.getElementById("game-editorial-recommend-box");
    const recommendEl = document.getElementById("game-editorial-recommend");
    if (recommendBox && recommendEl && editorial.recommendedFor) {
      recommendEl.textContent = editorial.recommendedFor;
      recommendBox.hidden = false;
    }
  }

  // ---------- 再生リストカード ----------
  function createPlaylistCard(item) {
    const genre = genreById[item.genre] || genreById.other;

    const article = document.createElement("article");
    article.className = "playlist-card";
    article.tabIndex = 0;
    article.setAttribute("role", "button");
    article.setAttribute("aria-label", item.title + " を開く");

    // サムネイル優先順位: ①再生リストのサムネイル → ②VTuberアイコン → ③頭文字。
    // (優先順位・失敗時の切り替えは createPlaylistThumbnail 側で共通管理)
    article.appendChild(createPlaylistThumbnail(item, {
      width: 120,
      height: 68,
      containerTag: "div",
      containerClass: "playlist-card-thumb",
      placeholderClass: "playlist-card-thumb-placeholder",
    }));

    const body = document.createElement("div");
    body.className = "playlist-card-body";

    const top = document.createElement("div");
    top.className = "playlist-card-top";
    const badge = document.createElement("span");
    badge.className = "badge badge--" + genre.color;
    badge.textContent = genre.label;
    top.appendChild(badge);
    const dateSpan = document.createElement("span");
    dateSpan.className = "playlist-card-date";
    const d = item.updatedDate || item.addedDate;
    dateSpan.textContent = d ? formatDate(d) + " 更新" : "";
    top.appendChild(dateSpan);
    body.appendChild(top);

    const h3 = document.createElement("h3");
    h3.className = "playlist-card-title";
    h3.textContent = item.title;
    body.appendChild(h3);

    const streamerLink = document.createElement("a");
    streamerLink.className = "playlist-card-streamer";
    streamerLink.href = streamerUrl(item.streamer);
    streamerLink.textContent = item.streamer;
    body.appendChild(streamerLink);

    const meta = document.createElement("p");
    meta.className = "playlist-card-meta";
    meta.textContent = "動画数: " + (item.videoCount ? item.videoCount + "本" : "-");
    body.appendChild(meta);

    article.appendChild(body);

    const open = () => {
      recordRecentlyViewed("playlist", playlistRecentEntry(item));
      window.open(playlistUrl(item), "_blank", "noopener");
    };
    article.addEventListener("click", (e) => {
      if (e.target.closest("a")) return;
      open();
    });
    article.addEventListener("keydown", (e) => {
      if (e.target.closest("a")) return;
      if (e.key === "Enter" || e.key === " ") {
        e.preventDefault();
        open();
      }
    });

    return article;
  }

  function renderCards(container, pageItems, emptyMessage) {
    container.innerHTML = "";
    if (!pageItems.length) {
      const empty = document.createElement("div");
      empty.className = "empty-state";
      empty.textContent = emptyMessage;
      container.appendChild(empty);
      return;
    }
    const fragment = document.createDocumentFragment();
    pageItems.forEach((item) => fragment.appendChild(createPlaylistCard(item)));
    container.appendChild(fragment);
  }

  const grid = document.getElementById("grid");
  document.getElementById("result-count").textContent =
    items.length + " 件の再生リスト / " + standalone.length + " 件の単発・PLなし実況";

  const setPageItems = initPagination((pageItems) => {
    renderCards(grid, pageItems, "このゲームの再生リストはまだ登録されていません。");
  }, 20);

  const sortSelect = document.getElementById("sort-select");
  function applySort() {
    const key = sortSelect ? sortSelect.value : "updatedDate";
    const dir = key === "streamer" ? 1 : -1;
    setPageItems(sortByColumn(items, key, dir));
  }
  if (sortSelect) sortSelect.addEventListener("change", applySort);
  applySort();

  // ---------- 単発・専用再生リストなし実況(既存機能のまま) ----------
  const section = document.getElementById("standalone-section");
  const sg = document.getElementById("standalone-grid");
  const ss = document.getElementById("standalone-summary");
  if (section && standalone.length) {
    section.hidden = false;
    ss.innerHTML = "";
    const chip = document.createElement("span");
    chip.className = "summary-chip";
    chip.textContent = standalone.length + "件";
    ss.appendChild(chip);
    standalone.forEach((x) => sg.appendChild(createStandaloneCard(x, { showGame: false })));
  }
})();
