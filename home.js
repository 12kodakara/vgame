/**
 * トップページ(index.html)専用スクリプト。
 * ファーストビュー下の発見コンテンツ5種を PLAYLISTS / GAMES / STREAMERS から集計して表示する。
 *   🔥 人気のゲーム / 🔄 最近更新された再生リスト / ⭐ 人気／注目VTuber
 *   🎮 ゲームから探す(五十音行タイル) / 🎥 VTuberから探す(事務所タイル)
 * data-core.js → data-playlists.js → common.js の後に読み込むこと。
 */
(function () {
  const LIST_LIMIT = 5;

  /** PLAYLISTS を getKey(playlist) の返り値でグルーピングし、popularity合計・件数の多い順に並べる。 */
  function aggregateBy(getKey) {
    const stats = {};
    const order = [];
    getAllPlaylists().forEach((p) => {
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

  // 検索ボックス直下の掲載件数(トップページを「検索できるデータベース」だと
  // 一目で伝えるための数値。固定値にせず読み込んだデータから毎回集計する)。
  const heroStats = document.getElementById("hero-stats");
  const allPlaylists = getAllPlaylists();
  if (heroStats && allPlaylists.length) {
    const gameCount = new Set(allPlaylists.map((p) => p.game)).size;
    const streamerCount = new Set(allPlaylists.map((p) => p.streamer)).size;
    heroStats.textContent = allPlaylists.length.toLocaleString("ja-JP") + "件の実況再生リストを掲載 ／ "
      + gameCount.toLocaleString("ja-JP") + "ゲーム ／ "
      + streamerCount.toLocaleString("ja-JP") + "VTuber掲載";
    heroStats.hidden = false;
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

  // 🔥 人気のゲーム(再生リストのpopularity合計が高いゲーム上位)
  const topGames = aggregateBy((p) => p.game).slice(0, LIST_LIMIT);
  renderDiscoverList("discover-popular-games", topGames, "まだ再生リストが登録されていません。", (body, item) => {
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

  // 🔄 最近更新された再生リスト(updatedDate優先、無ければaddedDateが新しい上位)
  const recentUpdated = allPlaylists.filter((p) => p.updatedDate || p.addedDate)
    .slice()
    .sort((a, b) => new Date(b.updatedDate || b.addedDate) - new Date(a.updatedDate || a.addedDate))
    .slice(0, LIST_LIMIT);
  renderPlaylistDiscoverList("discover-recent-updated", recentUpdated, "更新された再生リストはまだありません。");

  // ⭐ 人気／注目VTuber(再生リストのpopularity合計が高い実況者上位、20件)
  const topStreamers = aggregateBy((p) => p.streamer).slice(0, 20);
  const streamerGrid = document.getElementById("discover-popular-streamers");
  if (streamerGrid) {
    streamerGrid.innerHTML = "";

    if (!topStreamers.length) {
      const empty = document.createElement("div");
      empty.className = "empty-state";
      empty.textContent = "実況者データがまだありません。";
      streamerGrid.appendChild(empty);
    } else {
      topStreamers.forEach((item) => {
        streamerGrid.appendChild(createStreamerCard(item.key, item.count));
      });
    }
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
