/**
 * ゲームシリーズページ(series.html?series=…)。※LOCAL PoC・未公開(noindex・sitemap 対象外・サイト内リンクなし)
 * シリーズの作品は data-series.js(SERIES_PAGES)で明示的に列挙したものだけを使い、ゲーム名や series 欄から推測しない。
 * 集計は computeSeriesPage() にまとめてある(DOM に触れない純粋関数)。PoC では数MBある data-playlists.js を
 * 必要になった時点で読み込んで集計する(公開する場合は genre と同じく事前集計データに切り替える)。
 *
 * 役割分担: シリーズ → 各ゲーム詳細 → 実況。各作品の詳しい実況はゲーム詳細へ送り、YouTube への直接リンクは
 * 「最近更新された実況」の10件だけにする。
 */
const SERIES_RECENT_LIMIT = 10;
const SERIES_GAMES_SHOWN = 10;
const SERIES_STREAMERS_SHOWN = 12;

const cmpSeriesName = (a, b) => (a < b ? -1 : a > b ? 1 : 0);

/**
 * シリーズの集計を作る。
 *   games     : [ゲーム名, 実況VTuber数, 再生リスト数, 単発実況数](実況VTuber数 → 再生リスト数 → 名前の順)。実況0件の作品は含めない
 *   streamers : [VTuber名, 実況した作品数, 再生リスト数](作品数 → 再生リスト数 → 名前の順)。hubGame の再生リストは作品数に数えない
 *   hub       : hubGame の [実況VTuber数, 再生リスト数](無ければ null)
 *   recent    : 最近更新された再生リスト(hubGame を含む)
 *   standalone: 単発実況(既存の STANDALONE_PLAYS のうちシリーズの作品のもの)
 */
function computeSeriesPage(playlists, standalonePlays, def) {
  const titles = new Set(def.games);
  const inSeries = (game) => titles.has(game) || game === def.hubGame;
  const items = playlists.filter((p) => inSeries(p.game));
  const standalone = (standalonePlays || []).filter((p) => inSeries(p.game));

  const games = new Map(), streamers = new Map();
  const gameOf = (name) => games.get(name) || games.set(name, { streamers: new Set(), playlists: 0, standalone: 0 }).get(name);
  const streamerOf = (name) => streamers.get(name) || streamers.set(name, { titles: new Set(), playlists: 0 }).get(name);
  for (const p of items) {
    const g = gameOf(p.game); g.streamers.add(p.streamer); g.playlists += 1;
    const s = streamerOf(p.streamer); s.playlists += 1; if (titles.has(p.game)) s.titles.add(p.game);
  }
  for (const p of standalone) {
    const g = gameOf(p.game); g.streamers.add(p.streamer); g.standalone += 1;
    const s = streamerOf(p.streamer); if (titles.has(p.game)) s.titles.add(p.game);
  }

  const hubEntry = games.get(def.hubGame);
  const gameList = [...games.entries()].filter(([name]) => titles.has(name))
    .map(([name, g]) => [name, g.streamers.size, g.playlists, g.standalone])
    .sort((a, b) => b[1] - a[1] || b[2] - a[2] || cmpSeriesName(a[0], b[0]));
  const streamerList = [...streamers.entries()].map(([name, s]) => [name, s.titles.size, s.playlists])
    .sort((a, b) => b[1] - a[1] || b[2] - a[2] || cmpSeriesName(a[0], b[0]));
  const dateOf = (p) => p.updatedDate || p.addedDate || "";
  const recent = items.slice().sort((a, b) => cmpSeriesName(dateOf(b), dateOf(a)) || cmpSeriesName(a.id, b.id)).slice(0, SERIES_RECENT_LIMIT);

  return {
    stats: {
      games: gameList.length,
      streamers: streamerList.length,
      playlists: items.length,
      videos: items.reduce((sum, p) => sum + (p.videoCount || 0), 0),
      standalone: standalone.length,
    },
    games: gameList,
    streamers: streamerList,
    hub: hubEntry ? [hubEntry.streamers.size, hubEntry.playlists] : null,
    recent: recent,
    standalone: standalone,
  };
}

/** meta description(事実のみ。作品名は実況VTuberが多い順の先頭3作品)。 */
function buildSeriesDescription(def, page) {
  const top = page.games.slice(0, 3).map((g) => gameDisplayName(g[0])).join("、");
  return def.name + "のVTuber実況を作品別にまとめたページです。" + top + "など" + page.stats.games +
    "作品を実況したVTuber" + page.stats.streamers + "組の再生リスト" + page.stats.playlists + "件を掲載しています。";
}

(function () {
  if (typeof window === "undefined") return;

  const seriesId = getQueryParam("series") || "";
  const def = typeof SERIES_PAGES !== "undefined" && Object.prototype.hasOwnProperty.call(SERIES_PAGES, seriesId) ? SERIES_PAGES[seriesId] : null;
  if (!def) {
    renderNotFoundPage({
      title: "シリーズが見つかりません",
      message: "指定されたシリーズのページはありません。ゲーム一覧からお探しください。",
      backHref: "games.html",
      backLabel: "ゲーム一覧へ",
      docTitle: "シリーズが見つかりません | " + SITE_NAME,
    });
    return;
  }

  function fillMore(detailsId, countId, listId, rest, add) {
    if (!rest.length) return;
    const list = document.getElementById(listId);
    list.innerHTML = "";
    add(list, rest);
    document.getElementById(countId).textContent = rest.length;
    document.getElementById(detailsId).hidden = false;
  }

  function render(page) {
    document.getElementById("page-title").textContent = def.name + "のVTuber実況";
    document.getElementById("breadcrumb-current").textContent = def.name;
    document.querySelectorAll("[data-series-name]").forEach((el) => { el.textContent = def.name; });

    document.getElementById("stat-games").textContent = formatNumberJa(page.stats.games) + "作品";
    document.getElementById("stat-streamers").textContent = formatNumberJa(page.stats.streamers) + "組";
    document.getElementById("stat-playlists").textContent = formatNumberJa(page.stats.playlists) + "件";
    document.getElementById("stat-videos").textContent = page.stats.videos ? formatNumberJa(page.stats.videos) + "本" : "-";

    // 作品一覧: 各ゲーム詳細へのリンク。件数は「この作品を実況しているVTuberの組数・再生リスト数」
    const addGames = (list, entries) => entries.forEach(([name, streamerCount, playlistCount, standaloneCount]) => {
      const li = createCountIndexItem(gameUrl(name), gameDisplayName(name), streamerCount);
      li.querySelector(".count").textContent = "(" + streamerCount + "組・再生リスト" + playlistCount + "件" +
        (standaloneCount ? "・単発" + standaloneCount + "件" : "") + ")";
      list.appendChild(li);
    });
    const gamesList = document.getElementById("series-games-list");
    gamesList.innerHTML = "";
    if (page.games.length) addGames(gamesList, page.games.slice(0, SERIES_GAMES_SHOWN));
    else gamesList.innerHTML = '<li class="empty-state">まだ実況が登録されていません。</li>';
    fillMore("series-games-more", "series-games-rest-count", "series-games-rest", page.games.slice(SERIES_GAMES_SHOWN), addGames);

    // 複数作品をまとめた再生リストは既存のゲームページ(hubGame)へ
    if (page.hub) {
      const hubLink = document.getElementById("series-hub-link");
      hubLink.href = gameUrl(def.hubGame);
      hubLink.textContent = gameDisplayName(def.hubGame);
      document.getElementById("series-hub-count").textContent = "(" + page.hub[0] + "組・再生リスト" + page.hub[1] + "件)";
      document.getElementById("series-hub-note").hidden = false;
    }

    // VTuber一覧: 件数はシリーズ内の再生リスト数(カードの共通表示)。並びは実況した作品数の多い順
    const addStreamers = (list, entries) => entries.forEach(([name, , playlistCount]) => list.appendChild(createStreamerCard(name, playlistCount)));
    const streamerGrid = document.getElementById("series-streamers-grid");
    streamerGrid.innerHTML = "";
    addStreamers(streamerGrid, page.streamers.slice(0, SERIES_STREAMERS_SHOWN));
    fillMore("series-streamers-more", "series-streamers-rest-count", "series-streamers-rest", page.streamers.slice(SERIES_STREAMERS_SHOWN), addStreamers);
    document.getElementById("series-streamers-section").hidden = !page.streamers.length;

    // 実況を見る: 最近更新された再生リスト(既存の一覧表示)と、単発実況(既存のカード)
    renderPlaylistDiscoverList("series-recent-list", page.recent, "まだ実況が登録されていません。", {});
    document.getElementById("series-recent-section").hidden = false;
    if (page.standalone.length) {
      const grid = document.getElementById("series-standalone-grid");
      grid.innerHTML = "";
      page.standalone.forEach((x) => grid.appendChild(createStandaloneCard(x, { showGame: true })));
      document.getElementById("series-standalone-block").hidden = false;
    }

    const representative = page.recent.find((p) => getPlaylistThumbnailUrl(p));
    setPageMeta(
      def.name + "の実況VTuber・作品別一覧 | " + SITE_NAME,
      buildSeriesDescription(def, page),
      "/series.html?series=" + encodeURIComponent(seriesId),
      representative ? getPlaylistThumbnailUrl(representative) : null
    );
  }

  const standalonePlays = typeof STANDALONE_PLAYS === "undefined" ? [] : STANDALONE_PLAYS;
  loadPlaylistsData().then(() => render(computeSeriesPage(getAllPlaylists(), standalonePlays, def)));
})();
