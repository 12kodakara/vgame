/**
 * トップページ(index.html)専用スクリプト。
 * ファーストビュー下の発見コンテンツ5種を表示する。
 *   🔥 人気のゲーム / 🔄 最近更新された再生リスト / ⭐ 人気／注目VTuber
 *   🎮 ゲームから探す(五十音行タイル) / 🎥 VTuberから探す(事務所タイル)
 *
 * 再生リストを使う集計(件数・人気のゲーム・最近更新・人気VTuber)は
 * computeHomeSummary() にまとめてある。トップページでは数MBある data-playlists.js を
 * 読み込まず、generate-home-data.js がこの同じ関数で事前に作った data-home.js
 * (HOME_SUMMARY)を使って表示する。HOME_SUMMARY が無い・形式が合わない場合だけ、
 * data-playlists.js を後から読み込んで同じ関数で集計する(表示内容は同じ)。
 * data-core.js → data-counts.js → data-home.js → common.js の後に読み込むこと。
 */

const HOME_LIST_LIMIT = 5;
const HOME_STREAMER_LIMIT = 10;
const HOME_SUMMARY_VERSION = 1;

/**
 * 再生リスト一覧からトップページ用の集計を作る(DOMに触れない純粋関数)。
 * generate-home-data.js(ビルド時)と、HOME_SUMMARY が使えない場合のページ側の両方から呼ぶ。
 */
function computeHomeSummary(playlists) {
  /** playlists を getKey(playlist) の返り値でグルーピングし、popularity合計・件数の多い順に並べる。 */
  function aggregateBy(getKey) {
    const stats = {};
    const order = [];
    playlists.forEach((p) => {
      const key = getKey(p);
      if (!key) return;
      if (!stats[key]) {
        stats[key] = { key: key, score: 0, count: 0 };
        order.push(key);
      }
      stats[key].score += calculatePopularity(p);
      stats[key].count += 1;
    });
    return order
      .map((k) => stats[k])
      .sort((a, b) => b.score - a.score || b.count - a.count);
  }

  // 🔄 最近更新された再生リスト(updatedDate優先、無ければaddedDateが新しい上位)
  const recentUpdated = playlists.filter((p) => p.updatedDate || p.addedDate)
    .slice()
    .sort((a, b) => new Date(b.updatedDate || b.addedDate) - new Date(a.updatedDate || a.addedDate))
    .slice(0, HOME_LIST_LIMIT);

  return {
    version: HOME_SUMMARY_VERSION,
    playlistCount: playlists.length,
    gameCount: new Set(playlists.map((p) => p.game)).size,
    streamerCount: new Set(playlists.map((p) => p.streamer)).size,
    topGames: aggregateBy((p) => p.game).slice(0, HOME_LIST_LIMIT).map((x) => ({ key: x.key, count: x.count })),
    recentUpdated: recentUpdated,
    topStreamers: aggregateBy((p) => p.streamer).slice(0, HOME_STREAMER_LIMIT).map((x) => ({ key: x.key, count: x.count })),
  };
}

/** HOME_SUMMARY がこのページで使える形かどうか(古い形式・生成失敗を検出する)。 */
function isUsableHomeSummary(summary) {
  return !!summary && summary.version === HOME_SUMMARY_VERSION
    && Array.isArray(summary.topGames) && Array.isArray(summary.recentUpdated)
    && Array.isArray(summary.topStreamers) && typeof summary.playlistCount === "number";
}

(function () {
  // generate-home-data.js から読み込まれた場合は集計関数の定義だけを提供し、描画はしない
  if (typeof window === "undefined" || window.__HOME_SUMMARY_GENERATOR__) return;

  /**
   * 「人気のゲーム」用。ゲーム単位の集計(item.streamer等を持たない)なので、
   * サムネイル付きの再生リスト一覧(renderPlaylistDiscoverList、common.js)とは
   * 別に、行の中身を buildBody に委ねる簡易版として残している。
   */
  function renderDiscoverList(containerId, items, emptyMessage, buildBody) {
    const list = document.getElementById(containerId);
    if (!list) return;
    list.innerHTML = "";

    if (!items.length) {
      const li = document.createElement("li");
      li.className = "empty-state";
      li.textContent = emptyMessage;
      list.appendChild(li);
      return;
    }

    items.forEach((item, i) => {
      const li = document.createElement("li");
      li.className = "discover-item";

      const rank = document.createElement("span");
      rank.className = "discover-rank";
      rank.textContent = "#" + (i + 1);
      li.appendChild(rank);

      const body = document.createElement("div");
      body.className = "discover-body";
      buildBody(body, item);
      li.appendChild(body);

      list.appendChild(li);
    });
  }

  /** 再生リストの集計を使う部分(件数・人気のゲーム・最近更新・人気VTuber)を描画する。 */
  function renderPlaylistSections(summary) {
    // 検索ボックス直下の掲載件数(トップページを「検索できるデータベース」だと
    // 一目で伝えるための数値。固定値にせずデータから毎回集計する)。
    const heroStats = document.getElementById("hero-stats");
    if (heroStats && summary.playlistCount) {
      heroStats.textContent = summary.playlistCount.toLocaleString("ja-JP") + "件の実況再生リストを掲載 ／ "
        + summary.gameCount.toLocaleString("ja-JP") + "ゲーム ／ "
        + summary.streamerCount.toLocaleString("ja-JP") + "VTuber掲載";
      heroStats.hidden = false;
    }

    // 🔥 人気のゲーム(再生リストのpopularity合計が高いゲーム上位)
    renderDiscoverList("discover-popular-games", summary.topGames, "まだ再生リストが登録されていません。", (body, item) => {
      const a = document.createElement("a");
      a.className = "discover-title";
      a.href = gameUrl(item.key);
      a.textContent = gameDisplayName(item.key);
      body.appendChild(a);

      const meta = document.createElement("div");
      meta.className = "discover-meta";
      meta.textContent = "再生リスト " + item.count + "件";
      body.appendChild(meta);
    });

    // 🔄 最近更新された再生リスト
    renderPlaylistDiscoverList("discover-recent-updated", summary.recentUpdated, "更新された再生リストはまだありません。");

    // ⭐ 人気／注目VTuber(再生リストのpopularity合計が高い実況者上位、10件)
    const streamerGrid = document.getElementById("discover-popular-streamers");
    if (streamerGrid) {
      streamerGrid.innerHTML = "";

      if (!summary.topStreamers.length) {
        const empty = document.createElement("div");
        empty.className = "empty-state";
        empty.textContent = "実況者データがまだありません。";
        streamerGrid.appendChild(empty);
      } else {
        summary.topStreamers.forEach((item) => {
          streamerGrid.appendChild(createStreamerCard(item.key, item.count));
        });
      }
    }
  }

  // 🕒 最近見た実況(localStorageのみ。閲覧履歴がない場合はセクション自体を出さない)
  const recentViewedSection = document.getElementById("recent-viewed-section");
  const recentViewedList = document.getElementById("recent-viewed-list");
  if (recentViewedSection && recentViewedList) {
    const RECENT_VIEWED_ICON = { game: "🎮", streamer: "🎥", playlist: "📺" };
    const recentViewed = getRecentlyViewed().slice(0, 10);
    if (recentViewed.length) {
      recentViewedSection.hidden = false;
      recentViewedList.innerHTML = "";
      recentViewed.forEach((entry) => {
        const li = document.createElement("li");
        const a = document.createElement("a");
        a.href = entry.url;
        if (entry.type === "playlist") {
          a.target = "_blank";
          a.rel = "noopener";
        }
        a.textContent = (RECENT_VIEWED_ICON[entry.type] || "") + " " + entry.label;
        li.appendChild(a);
        if (entry.sub) {
          const sub = document.createElement("span");
          sub.className = "count";
          sub.textContent = entry.sub;
          li.appendChild(sub);
        }
        recentViewedList.appendChild(li);
      });
    }
  }

  // ⭐ お気に入り(localStorageのみ。未登録の場合はセクション自体を出さない)
  const favoritesSection = document.getElementById("favorites-section");
  const favoritesList = document.getElementById("favorites-list");
  if (favoritesSection && favoritesList) {
    const FAVORITE_ICON = { game: "🎮", streamer: "🎥" };
    const favData = loadFavorites();
    const favorites = favData.game.map((x) => Object.assign({ type: "game" }, x))
      .concat(favData.streamer.map((x) => Object.assign({ type: "streamer" }, x)));
    if (favorites.length) {
      favoritesSection.hidden = false;
      favoritesList.innerHTML = "";
      favorites.forEach((entry) => {
        const li = document.createElement("li");
        const a = document.createElement("a");
        a.href = entry.url;
        a.textContent = (FAVORITE_ICON[entry.type] || "") + " " + entry.label;
        li.appendChild(a);
        favoritesList.appendChild(li);
      });
    }
  }

  // 件数・人気のゲーム・最近更新・人気VTuber:
  //   通常は事前集計(data-home.js)を使う。data-playlists.js が既に読み込まれている場合や、
  //   事前集計が使えない場合は、全再生リストから同じ関数で集計する。
  if (typeof PLAYLISTS !== "undefined") {
    renderPlaylistSections(computeHomeSummary(getAllPlaylists()));
  } else if (typeof HOME_SUMMARY !== "undefined" && isUsableHomeSummary(HOME_SUMMARY)) {
    renderPlaylistSections(HOME_SUMMARY);
  } else {
    loadPlaylistsData().then(() => renderPlaylistSections(computeHomeSummary(getAllPlaylists())));
  }

  // 🎮 ゲームから探す(五十音行タイル。games.html と同じ行別件数)
  renderGameRowIndex(document.getElementById("discover-game-rows"));

  // 🎥 VTuberから探す(事務所タイル)
  const agencyList = document.getElementById("discover-agencies");
  if (agencyList) {
    agencyList.innerHTML = "";
    const order = [];
    const countByAgency = {};
    STREAMERS.forEach((s) => {
      const agency = (s.group || "その他").split(" ")[0];
      if (!countByAgency[agency]) {
        countByAgency[agency] = 0;
        order.push(agency);
      }
      countByAgency[agency] += 1;
    });

    order.forEach((agency) => {
      const li = document.createElement("li");
      li.className = "agency-tile";

      const a = document.createElement("a");
      a.href = "streamers.html?agency=" + encodeURIComponent(agency);

      const nameSpan = document.createElement("span");
      nameSpan.className = "agency-tile-name";
      nameSpan.textContent = agency;
      a.appendChild(nameSpan);

      const countSpan = document.createElement("span");
      countSpan.className = "agency-tile-count";
      countSpan.textContent = countByAgency[agency] + "名";
      a.appendChild(countSpan);

      li.appendChild(a);
      agencyList.appendChild(li);
    });
  }

  injectWebSiteJsonLd();
})();
