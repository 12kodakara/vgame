/**
 * ゲームシリーズページ(series.html?series=…)。※LOCAL PoC・未公開(noindex・sitemap 対象外・サイト内リンクなし)
 * シリーズの作品は data-series.js(SERIES_PAGES)で明示的に列挙したものだけを使い、ゲーム名や series 欄から推測しない。
 * 集計は computeSeriesPage() にまとめてある(DOM に触れない純粋関数)。PoC では数MBある data-playlists.js を
 * 必要になった時点で読み込んで集計する(公開する場合は genre と同じく事前集計データに切り替える)。
 *
 * ページ固有の価値は「同じシリーズの複数作品を横断して実況を探せること」。主導線はシリーズ → 各ゲーム詳細で、
 * 実況そのもの(再生リスト・単発実況)は少数だけ見せ、詳しくはゲーム詳細・単発実況一覧へ送る。
 */
const SERIES_RECENT_LIMIT = 5;
const SERIES_STREAMERS_LIMIT = 24;
const SERIES_STANDALONE_LIMIT = 3;
// 公開条件(どれか1つでも欠けると noindex)。根拠は _seo/monetization-growth-audit.md(改善 #1)
const SERIES_MIN_TITLES = 3;          // 実況のある作品数
const SERIES_MIN_CROSS_STREAMERS = 10; // 2作品以上を実況したVTuber(シリーズを横断して探す意味がある)
const SERIES_MIN_STREAMERS = 20;      // 実況VTuber数 …または
const SERIES_MIN_CONTENT = 40;        // 再生リスト+単発実況の件数(どちらかを満たせばよい)

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
      crossStreamers: streamerList.filter((s) => s[1] >= 2).length,
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

/** 公開条件を満たすか(作品数・横断VTuber数は必須。量は VTuber数か実況件数のどちらか)。 */
function meetsSeriesPageThreshold(page) {
  const s = page.stats;
  return s.games >= SERIES_MIN_TITLES && s.crossStreamers >= SERIES_MIN_CROSS_STREAMERS &&
    (s.streamers >= SERIES_MIN_STREAMERS || s.playlists + s.standalone >= SERIES_MIN_CONTENT);
}

/** meta description(事実のみ。ゲーム名・VTuber名は並べない)。 */
function buildSeriesDescription(def, page) {
  return def.name + page.stats.games + "作品のVTuberによるゲーム実況を、作品別にまとめたページです。実況VTuber" +
    page.stats.streamers + "組・再生リスト" + page.stats.playlists + "件を掲載しています。";
}

/** 冒頭の概要(既存データから作る2文)。 */
function buildSeriesSummary(def, page) {
  const s = page.stats;
  return def.name + "の" + s.games + "作品を、" + s.streamers + "組のVTuberが実況しています(うち" + s.crossStreamers +
    "組は複数の作品を実況)。再生リスト" + formatNumberJa(s.playlists) + "件・単発実況" + s.standalone + "件・動画" + formatNumberJa(s.videos) + "本を作品ごとに探せます。";
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

  function render(page) {
    document.getElementById("page-title").textContent = def.name + "のVTuber実況";
    document.getElementById("breadcrumb-current").textContent = def.name;
    document.querySelectorAll("[data-series-name]").forEach((el) => { el.textContent = def.name; });
    document.getElementById("page-lead").textContent = buildSeriesSummary(def, page);

    document.getElementById("stat-games").textContent = formatNumberJa(page.stats.games) + "作品";
    document.getElementById("stat-streamers").textContent = formatNumberJa(page.stats.streamers) + "組";
    document.getElementById("stat-playlists").textContent = formatNumberJa(page.stats.playlists) + "件";
    document.getElementById("stat-standalone").textContent = formatNumberJa(page.stats.standalone) + "件";

    // 作品一覧(主導線): 全作品を各ゲーム詳細へのリンクとして並べる。件数は実況VTuber数・再生リスト数・単発実況数
    const gamesList = document.getElementById("series-games-list");
    gamesList.innerHTML = "";
    page.games.forEach(([name, streamerCount, playlistCount, standaloneCount]) => {
      const li = createCountIndexItem(gameUrl(name), gameDisplayName(name), streamerCount);
      li.querySelector(".count").textContent = "(" + streamerCount + "組・再生リスト" + playlistCount + "件" +
        (standaloneCount ? "・単発" + standaloneCount + "件" : "") + ")";
      gamesList.appendChild(li);
    });
    if (!page.games.length) gamesList.innerHTML = '<li class="empty-state">まだ実況が登録されていません。</li>';

    // 複数の作品をまとめた再生リストは既存のゲームページ(hubGame)へ
    if (page.hub) {
      const hubLink = document.getElementById("series-hub-link");
      hubLink.href = gameUrl(def.hubGame);
      hubLink.textContent = gameDisplayName(def.hubGame);
      document.getElementById("series-hub-count").textContent = "(" + page.hub[0] + "組・再生リスト" + page.hub[1] + "件)";
      document.getElementById("series-hub-note").hidden = false;
    }

    // VTuber: 実況した作品数の多い順に上位だけ(ページが VTuber 一覧で埋まらないよう上限あり)。件数表示も作品数
    const shown = page.streamers.slice(0, SERIES_STREAMERS_LIMIT);
    const streamerGrid = document.getElementById("series-streamers-grid");
    streamerGrid.innerHTML = "";
    shown.forEach(([name, titleCount, playlistCount]) => {
      const card = createStreamerCard(name, playlistCount);
      card.querySelector(".count").textContent = "(" + titleCount + "作品)";
      streamerGrid.appendChild(card);
    });
    const restCount = page.streamers.length - shown.length;
    document.getElementById("series-streamers-rest").textContent = restCount > 0 ? "ほか" + restCount + "組のVTuberは、各作品のページで確認できます。" : "";
    document.getElementById("series-streamers-section").hidden = !page.streamers.length;

    // 実況を見る: 最近更新された再生リストを少数だけ(既存の一覧表示)。単発実況は既存のカードで上限まで
    renderPlaylistDiscoverList("series-recent-list", page.recent, "まだ実況が登録されていません。", {});
    document.getElementById("series-recent-section").hidden = false;
    if (page.standalone.length) {
      const grid = document.getElementById("series-standalone-grid");
      grid.innerHTML = "";
      page.standalone.slice(0, SERIES_STANDALONE_LIMIT).forEach((x) => grid.appendChild(createStandaloneCard(x, { showGame: true })));
      document.getElementById("series-standalone-block").hidden = false;
    }

    // index は「公開扱い(publish: true)」かつ公開条件を満たすときだけ。それ以外は noindex を付ける
    // (PoC 中は元HTMLにも noindex を書いてある。公開時はそれを外し、ここでの判定だけにする)
    if (!(def.publish === true && meetsSeriesPageThreshold(page))) {
      let robotsMeta = document.querySelector('meta[name="robots"]');
      if (!robotsMeta) {
        robotsMeta = document.createElement("meta");
        robotsMeta.setAttribute("name", "robots");
        document.head.appendChild(robotsMeta);
      }
      robotsMeta.setAttribute("content", "noindex,follow");
    }

    const representative = page.recent.find((p) => getPlaylistThumbnailUrl(p));
    setPageMeta(
      def.name + "のVTuber実況・作品別一覧 | " + SITE_NAME,
      buildSeriesDescription(def, page),
      "/series.html?series=" + encodeURIComponent(seriesId),
      representative ? getPlaylistThumbnailUrl(representative) : null
    );
  }

  const standalonePlays = typeof STANDALONE_PLAYS === "undefined" ? [] : STANDALONE_PLAYS;
  loadPlaylistsData().then(() => render(computeSeriesPage(getAllPlaylists(), standalonePlays, def)));
})();
