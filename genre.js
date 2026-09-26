/**
 * ジャンル別のVTuber実況ページ(genre.html?genre=…)。
 * 集計(ゲーム一覧・VTuber一覧・最近更新された再生リスト・統計)は computeGenrePage() にまとめてあり、
 * ページでは数MBある data-playlists.js を読み込まず、generate-genre-data.js がこの同じ関数で事前に作った
 * data-genres.js(GENRE_PAGES)を使う。GENRE_PAGES が使えない場合だけ data-playlists.js を読み込んで集計する。
 * ジャンルは各再生リストの genre(サイト全体の絞り込み・バッジと同じ既存分類)をそのまま使い、ゲーム名から推測しない。
 *
 * 公開するジャンルは GENRE_PAGE_IDS だけ(効果測定のため、まずホラーの1ページのみ)。
 * それ以外の genre 指定は「見つかりません」(noindex)として扱う。
 */
const GENRE_PAGE_IDS = ["horror"];
const GENRE_PAGES_VERSION = 1;
const GENRE_RECENT_LIMIT = 10;
// ページ固有の表示文言(ジャンル名は GENRES の label から作らず、自然な呼び方をここで決める)
const GENRE_PAGE_TEXT = {
  horror: { name: "ホラーゲーム" },
};

const cmpName = (a, b) => (a < b ? -1 : a > b ? 1 : 0);

/** 指定ジャンルの再生リストから、ページに出す集計を作る(DOM に触れない純粋関数)。 */
function computeGenrePage(playlists, genreId) {
  const items = playlists.filter((p) => p.genre === genreId);
  const games = new Map(), streamers = new Map();
  for (const p of items) {
    const g = games.get(p.game) || { streamers: new Set(), playlists: 0 };
    g.streamers.add(p.streamer); g.playlists += 1; games.set(p.game, g);
    const s = streamers.get(p.streamer) || { games: new Set(), playlists: 0 };
    s.games.add(p.game); s.playlists += 1; streamers.set(p.streamer, s);
  }
  // ゲーム: 実況VTuber数 → 再生リスト数 → 名前(文字コード順)。VTuber: 実況したゲーム数 → 再生リスト数 → 名前
  const gameList = [...games.entries()].map(([name, g]) => [name, g.streamers.size, g.playlists])
    .sort((a, b) => b[1] - a[1] || b[2] - a[2] || cmpName(a[0], b[0]));
  const streamerList = [...streamers.entries()].map(([name, s]) => [name, s.games.size, s.playlists])
    .sort((a, b) => b[1] - a[1] || b[2] - a[2] || cmpName(a[0], b[0]));
  const dateOf = (p) => p.updatedDate || p.addedDate || "";
  const recent = items.slice().sort((a, b) => cmpName(dateOf(b), dateOf(a)) || cmpName(a.id, b.id)).slice(0, GENRE_RECENT_LIMIT);
  return {
    stats: { games: gameList.length, streamers: streamerList.length, playlists: items.length, videos: items.reduce((sum, p) => sum + (p.videoCount || 0), 0) },
    games: gameList,
    streamers: streamerList,
    recent: recent,
  };
}

/** ページの meta description(事実のみ。ゲーム名は実況VTuberが多い順の先頭3作品)。 */
function buildGenreDescription(genreId, page) {
  const name = GENRE_PAGE_TEXT[genreId].name;
  const top = page.games.slice(0, 3).map((g) => g[0]).join("、");
  return "VTuberの" + name + "実況をまとめたページです。" + top + "など" + page.stats.games + "作品を実況したVTuber" +
    page.stats.streamers + "組の再生リスト" + page.stats.playlists + "件を掲載しています。";
}

(function () {
  // generate-genre-data.js から読み込まれた場合は集計関数の定義だけを提供し、描画はしない
  if (typeof window === "undefined" || window.__LIST_DATA_GENERATOR__) return;

  const genreId = getQueryParam("genre") || "";

  if (!GENRE_PAGE_IDS.includes(genreId)) {
    renderNotFoundPage({
      title: "ジャンルが見つかりません",
      message: "指定されたジャンルのページはありません。再生リスト一覧のジャンル絞り込みからお探しください。",
      backHref: "playlists.html",
      backLabel: "再生リスト一覧へ",
      docTitle: "ジャンルが見つかりません | " + SITE_NAME,
    });
    return;
  }

  function render(page) {
    const text = GENRE_PAGE_TEXT[genreId];
    document.getElementById("page-title").textContent = text.name + "のVTuber実況";
    document.getElementById("breadcrumb-current").textContent = text.name;

    document.getElementById("stat-games").textContent = formatNumberJa(page.stats.games) + "作品";
    document.getElementById("stat-streamers").textContent = formatNumberJa(page.stats.streamers) + "組";
    document.getElementById("stat-playlists").textContent = formatNumberJa(page.stats.playlists) + "件";
    document.getElementById("stat-videos").textContent = page.stats.videos ? formatNumberJa(page.stats.videos) + "本" : "-";

    // ゲーム一覧(最初の20件を表示し、残りは <details> 内。リンクは最初から DOM にある)
    const GAMES_SHOWN = 20;
    const gamesList = document.getElementById("genre-games-list");
    const gamesRest = document.getElementById("genre-games-rest");
    const addGames = (list, entries) => entries.forEach(([name, streamerCount]) => {
      // 件数は「このジャンルでそのゲームを実況しているVTuberの組数」
      const li = createCountIndexItem(gameUrl(name), gameDisplayName(name), streamerCount);
      li.querySelector(".count").textContent = "(" + streamerCount + "組)";
      list.appendChild(li);
    });
    gamesList.innerHTML = "";
    addGames(gamesList, page.games.slice(0, GAMES_SHOWN));
    const restGames = page.games.slice(GAMES_SHOWN);
    if (restGames.length) {
      gamesRest.innerHTML = "";
      addGames(gamesRest, restGames);
      document.getElementById("genre-games-rest-count").textContent = restGames.length;
      document.getElementById("genre-games-more").hidden = false;
    }

    // VTuber一覧(最初の12組を表示し、残りは <details> 内)
    const STREAMERS_SHOWN = 12;
    const streamerGrid = document.getElementById("genre-streamers-grid");
    const streamerRest = document.getElementById("genre-streamers-rest");
    const addStreamers = (list, entries) => entries.forEach(([name, , playlistCount]) => {
      list.appendChild(createStreamerCard(name, playlistCount));
    });
    streamerGrid.innerHTML = "";
    addStreamers(streamerGrid, page.streamers.slice(0, STREAMERS_SHOWN));
    // VTuber欄・最近更新欄は中身が入ってから表示する(空のまま描画されてから押し下げられるレイアウトシフトを防ぐ)
    document.getElementById("genre-streamers-section").hidden = false;
    const restStreamers = page.streamers.slice(STREAMERS_SHOWN);
    if (restStreamers.length) {
      streamerRest.innerHTML = "";
      addStreamers(streamerRest, restStreamers);
      document.getElementById("genre-streamers-rest-count").textContent = restStreamers.length;
      document.getElementById("genre-streamers-more").hidden = false;
    }

    // 最近更新された再生リスト(YouTube への導線は既存の一覧表示を再利用)
    renderPlaylistDiscoverList("genre-recent-list", page.recent, "", {});
    document.getElementById("genre-recent-section").hidden = false;

    const representative = page.recent.find((p) => getPlaylistThumbnailUrl(p));
    setPageMeta(
      text.name + "を実況しているVTuber・実況一覧 | " + SITE_NAME,
      buildGenreDescription(genreId, page),
      "/genre.html?genre=" + encodeURIComponent(genreId),
      representative ? getPlaylistThumbnailUrl(representative) : null
    );
  }

  const data = typeof GENRE_PAGES !== "undefined" && GENRE_PAGES && GENRE_PAGES.version === GENRE_PAGES_VERSION && GENRE_PAGES.genres
    ? GENRE_PAGES.genres[genreId] : null;
  if (data) render(data);
  else loadPlaylistsData().then(() => render(computeGenrePage(getAllPlaylists(), genreId)));
})();
