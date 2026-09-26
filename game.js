/**
 * ゲーム詳細ページの meta description(og:description / twitter:description も同じ文)を作る(DOM に触れない純粋関数)。
 * そのゲームを実況しているVTuberを、登録データから決まる順(このゲームの再生リスト件数が多い順 → 同数なら動画本数の
 * 合計が多い順 → 最終更新日が新しい順 → 名前の文字コード順)に最大3名まで挙げ、事実(VTuber名・組数・再生リスト件数・
 * 動画本数・最終更新日)だけで説明する。評価を表す言葉(人気・代表等)は使わない。名前は途中で切らず、長い場合は挙げる数を減らす。
 * 再生リストが1件も無い(noindex の)ゲームと、GAME_DESC_LEGACY_GAMES のゲームは従来の文面のまま。
 *   items: そのゲームの再生リスト / standalone: 単発実況
 */
const GAME_DESC_MAX_STREAMERS = 3;
const GAME_DESC_STREAMER_NAMES_MAX_CHARS = 30;
// 正規ゲーム名の設計(統合・分割)を保留中のゲーム。再生リストとの対応が今後変わりうるため、
// VTuber名を挙げず従来の文面のままにする(ポケポケ / Pocket、Overwatch / Overwatch 2)。
const GAME_DESC_LEGACY_GAMES = new Set([
  "ポケモンカードゲーム Pokémon Trading Card Game Pocket",
  "ポケポケ",
  "Overwatch",
  "Overwatch 2",
]);

function pickGameDescriptionStreamers(items, standalone) {
  const stats = new Map();
  const bump = (streamer, videos, date) => {
    const s = stats.get(streamer) || { name: streamer, count: 0, videos: 0, latest: "" };
    s.count += 1;
    s.videos += videos;
    if (date && date > s.latest) s.latest = date;
    stats.set(streamer, s);
  };
  items.forEach((p) => bump(p.streamer, p.videoCount || 0, p.updatedDate || p.addedDate || ""));
  (standalone || []).forEach((p) => bump(p.streamer, standalonePlayCount(p), p.addedDate || ""));
  return [...stats.values()].sort((a, b) =>
    b.count - a.count || b.videos - a.videos || (a.latest < b.latest ? 1 : a.latest > b.latest ? -1 : 0) || (a.name < b.name ? -1 : a.name > b.name ? 1 : 0));
}

function buildGameDescription(game, items, standalone) {
  const streamers = pickGameDescriptionStreamers(items, standalone);
  const totalVideos = items.reduce((sum, p) => sum + (p.videoCount || 0), 0) +
    (standalone || []).reduce((sum, p) => sum + standalonePlayCount(p), 0);
  const lastUpdated = items.reduce((latest, p) => {
    const d = p.updatedDate || p.addedDate || "";
    return d && d > latest ? d : latest;
  }, "");
  if (!items.length || GAME_DESC_LEGACY_GAMES.has(game)) {
    return gameDisplayName(game) + "を実況しているVTuberの再生リスト・動画をまとめて紹介。実況VTuber" + streamers.length + "組・再生リスト" + items.length + "件" +
      (totalVideos ? "・動画" + totalVideos + "本" : "") + (lastUpdated ? "(最終更新: " + formatDate(lastUpdated) + ")" : "") + "。";
  }
  const named = [];
  let chars = 0;
  for (const s of streamers.slice(0, GAME_DESC_MAX_STREAMERS)) {
    if (named.length && chars + s.name.length > GAME_DESC_STREAMER_NAMES_MAX_CHARS) break;
    named.push(s.name);
    chars += s.name.length;
  }
  const who = named.length === streamers.length
    ? (named.length === 2 ? named[0] + "と" + named[1] : named.join("、"))
    : named.join("、") + "など" + streamers.length + "組";
  const details = [];
  if (totalVideos) details.push("動画" + totalVideos + "本");
  if (lastUpdated) details.push("最終更新 " + formatDate(lastUpdated));
  return gameDisplayName(game) + "のVTuber実況をまとめたページです。" + who + "の再生リスト" + items.length + "件" +
    (details.length ? "(" + details.join("・") + ")" : "") + "を掲載しています。";
}

(function () {
  const game = getQueryParam("game") || "";

  // このゲームの再生リスト(items)と関連ゲームの候補(related)を受け取って描画する。
  //   通常は分割データ(data/games/NN.js)から受け取る。related は [[ゲーム名, 件数], ...]。
  //   data-playlists.js を使う従来の経路では related が null になり、下で全件から集計する。
  startDetailPage("games", game, getPlaylistsByGame, renderGamePage);

  function renderGamePage(items, relatedFromData) {
    // ゲーム一覧(GAMES)に無く、再生リスト・単発実況も1件も無い名前は存在しないゲームとして扱う。
    // GAMESに登録済みで再生リストがまだ無いゲームは、従来どおり空のページ(noindex)を表示する。
    const hasAnyPlay =
      items.length > 0 ||
      (typeof STANDALONE_PLAYS !== "undefined" && STANDALONE_PLAYS.some((p) => p.game === game));
    if (!gameCatalogOf(game) && !hasAnyPlay) {
      renderNotFoundPage({
        title: game ? "ゲームが見つかりません" : "ゲームが指定されていません",
        message: game
          ? "「" + game + "」というゲームは、ぶいゲーに登録されていません。名前が変わったか、URLが間違っている可能性があります。"
          : "表示するゲームが指定されていません。",
        backHref: "games.html",
        backLabel: "ゲーム一覧へ戻る",
        docTitle: "ゲームが見つかりません | " + SITE_NAME,
      });
      return;
    }

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

    const standalone = (typeof STANDALONE_PLAYS === "undefined" ? [] : STANDALONE_PLAYS).filter((p) => p.game === game);

    // 再生リスト・単発実況が1件も無いゲームは、実質的に中身が無い空のページに
    // なるため、検索結果には出さない(noindex)が、他ページからのリンクは辿れる
    // ようにする(follow)。GAMES(data-core.js)にだけ登録されていて
    // PLAYLISTS側のデータがまだ無いゲームが対象。
    if (game && items.length === 0 && standalone.length === 0) {
      let robotsMeta = document.querySelector('meta[name="robots"]');
      if (!robotsMeta) {
        robotsMeta = document.createElement("meta");
        robotsMeta.setAttribute("name", "robots");
        document.head.appendChild(robotsMeta);
      }
      robotsMeta.setAttribute("content", "noindex,follow");
    }

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

    document.getElementById("stat-streamers").textContent = streamerNames.size ? formatNumberJa(streamerNames.size) + "組" : "-";
    document.getElementById("stat-playlists").textContent = formatNumberJa(items.length) + "件";
    document.getElementById("stat-videos").textContent = totalVideos ? formatNumberJa(totalVideos) + "本" : "-";
    document.getElementById("stat-updated").textContent = lastUpdated ? formatDate(lastUpdated) : "-";

    // ---------- 実況データサマリー ----------
    // 上の統計(実況VTuber数・再生リスト数・動画数・最終更新日)だけを使って短い文章にする。
    // ゲーム内容・発売日等の推測は一切行わない。再生リストが1件以上あるゲームでは全件表示する
    // (許可リストは使わず、既存の集計結果 items/streamerNames/totalVideos/lastUpdated から動的に
    // 生成しているため、927ゲームへの対応は自動的に完了している)。0件・未取得の項目は文章に含めない。
    const summaryWrap = document.getElementById("game-summary-wrap");
    const summaryNote = document.getElementById("game-summary-note");
    if (summaryWrap && summaryNote && items.length > 0 && streamerNames.size > 0) {
      // VTuberが1名だけの場合に限り、実データから確実に取れる名前をそのまま文章に入れる。
      // 2名以上のときは個人名を列挙せず人数だけを使う。
      const soleStreamer = streamerNames.size === 1 ? streamerNames.values().next().value : null;
      let summaryText = soleStreamer
        ? soleStreamer + "による" + formatNumberJa(items.length) + "件の実況再生リストを掲載しています。"
        : formatNumberJa(streamerNames.size) + "名のVTuberによる" + formatNumberJa(items.length) + "件の実況再生リストを掲載しています。";

      const detailParts = [];
      if (totalVideos > 0) detailParts.push("登録動画は" + formatNumberJa(totalVideos) + "本");
      if (lastUpdated) detailParts.push("最終更新は" + formatDateJa(lastUpdated) + "です");
      if (detailParts.length) summaryText += detailParts.join("、") + "。";

      summaryNote.textContent = summaryText;
      summaryWrap.hidden = false;
    }

    if (game) {
      const representativeThumb = items.find((p) => getPlaylistThumbnailUrl(p));
      setPageMeta(
        gameDisplayName(game) + "を実況しているVTuber一覧 | " + SITE_NAME,
        buildGameDescription(game, items, standalone),
        "/game.html?game=" + encodeURIComponent(game),
        representativeThumb ? getPlaylistThumbnailUrl(representativeThumb) : null
      );
    }

    // 「人気実況」が「再生リストを探す」の実データ集合と実質同じ内容になる場合、
    // セクションごと非表示にする。件数の一致ではなく、一意なplaylist id集合が
    // 完全に一致するかで判定するため、データが増減しても自動で正しく動作する。
    function isSameItemSet(subset, mainSet) {
      if (subset.length !== mainSet.length) return false;
      const mainIds = new Set(mainSet.map((p) => p.id));
      return subset.every((p) => mainIds.has(p.id));
    }

    // ---------- 人気実況(上位3件) ----------
    // ランキングロジック自体は従来と同じ(popularity降順)で、表示件数のみ絞り込む。
    // 「最近更新」は「再生リストを探す」の並び替えと役割が重複するため、
    // ゲーム詳細ページの表示からは削除した(データ・他ページの機能はそのまま)。
    const popularItems = items
      .slice()
      .sort((a, b) => calculatePopularity(b) - calculatePopularity(a))
      .slice(0, 3);

    const featuredSection = document.getElementById("game-featured-section");

    if (featuredSection && popularItems.length && !isSameItemSet(popularItems, items)) {
      featuredSection.hidden = false;
      renderPlaylistDiscoverList("game-popular-list", popularItems, "", { showGame: false });
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

    const STREAMERS_SHOWN_INITIALLY = 10;
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
          streamerMoreBtn.textContent = streamersExpanded ? "閉じる" : "もっと見る";
          streamerMoreBtn.setAttribute("aria-expanded", String(streamersExpanded));
        });
      }
    }

    // ---------- 関連ゲーム ----------
    // 「このゲームを実況しているVTuberが、他にどのゲームを実況しているか」を
    // PLAYLISTS全体から集計し、重複度(件数)が高いゲームを関連ゲームとして表示する。
    // 手動登録ではなく既存データからの自動算出。対象ゲーム自身は除外する。
    // 分割データには、この集計結果のうち15番目の件数以上の候補が入っている(並び順はここで決める)。
    let relatedEntries;
    if (relatedFromData) {
      relatedEntries = relatedFromData.map(([name, count]) => ({ name: name, count: count }));
    } else {
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
      relatedEntries = relatedOrder.map((name) => ({ name: name, count: relatedCounts[name] }));
    }
    // 上位候補(最大15件)まではしっかり関連性を確保しつつ、その中からシャッフルして
    // 6件だけ表示することで、毎回同じ顔ぶれにならないようにする(表示のたびに変わる)。
    const relatedCandidates = relatedEntries
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

    // ---------- 独自編集コンテンツ(data-game-editorial.js に登録されているゲームのみ、折りたたみで表示) ----------
    // GAME_EDITORIAL に該当ゲームのキーが無い場合は折りたたみ自体を表示しない(従来のページ構成のまま)。
    const editorial = (typeof GAME_EDITORIAL === "undefined" ? null : GAME_EDITORIAL[game]) || null;
    if (editorial) {
      const editorialSection = document.getElementById("game-editorial-section");
      const editorialToggle = document.getElementById("game-editorial-toggle");
      const editorialToggleLabel = document.getElementById("game-editorial-toggle-label");
      const editorialArrow = editorialToggle ? editorialToggle.querySelector(".editorial-toggle-arrow") : null;
      const editorialPanel = document.getElementById("game-editorial-panel");

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
      }

      const recommendBox = document.getElementById("game-editorial-recommend-box");
      const recommendEl = document.getElementById("game-editorial-recommend");
      if (recommendBox && recommendEl && editorial.recommendedFor) {
        recommendEl.textContent = editorial.recommendedFor;
        recommendBox.hidden = false;
      }

      // 折りたたみ本体の表示・開閉(ボタンを押すたびに開く/閉じるを繰り返せる)。
      if (editorialSection) editorialSection.hidden = false;
      if (editorialToggleLabel) editorialToggleLabel.textContent = gameDisplayName(game) + "の実況について・探し方";
      if (editorialToggle && editorialPanel) {
        editorialToggle.addEventListener("click", () => {
          const nowExpanded = editorialToggle.getAttribute("aria-expanded") !== "true";
          editorialToggle.setAttribute("aria-expanded", String(nowExpanded));
          editorialPanel.hidden = !nowExpanded;
          if (editorialArrow) editorialArrow.textContent = nowExpanded ? "▲" : "▼";
        });
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
    }, 10);

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
  }
})();
