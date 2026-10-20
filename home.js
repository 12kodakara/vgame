/**
 * トップページ(index.html)専用スクリプト。
 * ファーストビュー下の発見コンテンツ5種を表示する。
 *   🔥 人気のゲーム / 🔄 最近更新された再生リスト / ⭐ 今週のおすすめVTuber
 *   🎮 ゲームから探す(五十音行タイル) / 🎥 VTuberから探す(事務所タイル)
 *
 * 再生リストを使う集計(件数・人気のゲーム・最近更新・おすすめVTuberの候補)は
 * computeHomeSummary() にまとめてある。トップページでは数MBある data-playlists.js を
 * 読み込まず、generate-home-data.js がこの同じ関数で事前に作った data-home.js
 * (HOME_SUMMARY)を使って表示する。HOME_SUMMARY が無い・形式が合わない場合だけ、
 * data-playlists.js を後から読み込んで同じ関数で集計する(表示内容は同じ)。
 * data-core.js → data-counts.js → data-home.js → common.js の後に読み込むこと。
 */

const HOME_LIST_LIMIT = 5;
const HOME_STREAMER_LIMIT = 10;
// 3: 「最近更新された再生リスト」から除外する VTuber を追加(古い data-home.js が残っていても使わず、その場で集計し直す)
const HOME_SUMMARY_VERSION = 3;
// 「最近更新された再生リスト」に表示しない VTuber(STREAMERS の name と完全一致で判定する)。
// この欄だけの除外で、VTuberページ・ゲームページ・検索・登録データには影響しない
const HOME_RECENT_UPDATED_EXCLUDED_STREAMERS = new Set(["博衣こより"]);

// ⭐ 今週のおすすめVTuber: 毎週月曜 04:00(日本時間)に入れ替える週替わりの紹介。閲覧数・配信頻度・登録本数では選ばない。
//   新規登録枠(初回掲載から30日以内)2組 → 発掘枠(掲載作品1〜3)4組 → 一般枠4組の順に埋め、足りない枠は一般枠で補う。
//   同じグループは2組まで。前週の選出者は外し(10組に足りない場合だけ戻す)、長く選ばれていない人から選ぶ。
//   選出履歴は保存せず、第0週から同じ計算をやり直して求める(同じ週・同じデータなら結果は必ず同じ)。
const WEEKLY_PICK_SLOTS = { fresh: 2, discovery: 4 };
const WEEKLY_PICK_GROUP_MAX = 2;
const WEEKLY_PICK_FRESH_DAYS = 30;
const WEEKLY_PICK_DISCOVERY_MAX_GAMES = 3;
const WEEKLY_PICK_EPOCH = Date.UTC(2026, 9, 11, 19, 0, 0); // 第0週の開始 = 2026-10-12(月)04:00 JST
const WEEKLY_PICK_WEEK_MS = 7 * 24 * 60 * 60 * 1000;

/** 週の番号(第0週より前は第0週として扱う)。 */
function weeklyPickWeekIndex(nowMs) {
  return Math.max(0, Math.floor((nowMs - WEEKLY_PICK_EPOCH) / WEEKLY_PICK_WEEK_MS));
}

/** 文字列の32bitハッシュ(FNV-1a)。同じ週の並びを毎回同じにするために使う。 */
function weeklyPickHash(text) {
  let h = 2166136261;
  for (let i = 0; i < text.length; i++) {
    h ^= text.charCodeAt(i);
    h = Math.imul(h, 16777619) >>> 0;
  }
  return h;
}

/**
 * 1週分の選出(DOMに触れない純粋関数)。
 *   candidates: [VTuber名, 掲載件数, 掲載作品数, 初回掲載日(YYYY-MM-DD)] / week: 週の番号
 *   lastPicked: 名前 → 最後に選ばれた週 / prevPicked: 前週の選出者(Set) / groupOf: 名前 → グループ
 */
function pickWeeklyStreamers(candidates, week, lastPicked, prevPicked, groupOf) {
  const startMs = WEEKLY_PICK_EPOCH + week * WEEKLY_PICK_WEEK_MS;
  const jstDate = (ms) => new Date(ms + 9 * 60 * 60 * 1000).toISOString().slice(0, 10);
  const startDate = jstDate(startMs);
  const freshFrom = jstDate(startMs - WEEKLY_PICK_FRESH_DAYS * 24 * 60 * 60 * 1000);
  const last = (name) => (Object.prototype.hasOwnProperty.call(lastPicked, name) ? lastPicked[name] : -1);
  const order = candidates
    .filter((c) => !c[3] || c[3] <= startDate) // その週の開始時点で掲載済みのVTuberだけ
    .slice()
    .sort((a, b) => last(a[0]) - last(b[0]) ||
      weeklyPickHash(week + "|" + a[0]) - weeklyPickHash(week + "|" + b[0]) || (a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : 0));
  const isFresh = (c) => !!c[3] && c[3] >= freshFrom;
  const picked = [];
  const groupCount = {};
  const fill = (test, n, allowPrev) => {
    for (const c of order) {
      if (n <= 0) break;
      const g = groupOf(c[0]);
      if (!test(c) || picked.indexOf(c) >= 0 || (groupCount[g] || 0) >= WEEKLY_PICK_GROUP_MAX) continue;
      if (!allowPrev && prevPicked.has(c[0])) continue;
      picked.push(c);
      groupCount[g] = (groupCount[g] || 0) + 1;
      n--;
    }
  };
  fill(isFresh, WEEKLY_PICK_SLOTS.fresh, false);
  fill((c) => !isFresh(c) && c[2] <= WEEKLY_PICK_DISCOVERY_MAX_GAMES, WEEKLY_PICK_SLOTS.discovery, false);
  fill(() => true, HOME_STREAMER_LIMIT - picked.length, false); // 一般枠と、足りない枠の補充
  fill(() => true, HOME_STREAMER_LIMIT - picked.length, true);  // それでも足りないときだけ前週の選出者も対象
  return picked;
}

/** nowMs の週の「今週のおすすめVTuber」。第0週から順に計算して、前週の選出者と最後に選ばれた週を求める。 */
function weeklyStreamerPicks(candidates, nowMs, groupOf) {
  const target = weeklyPickWeekIndex(nowMs);
  const lastPicked = {};
  let prev = new Set();
  let picks = [];
  for (let w = 0; w <= target; w++) {
    picks = pickWeeklyStreamers(candidates, w, lastPicked, prev, groupOf);
    picks.forEach((c) => { lastPicked[c[0]] = w; });
    prev = new Set(picks.map((c) => c[0]));
  }
  return picks;
}

/**
 * 再生リスト一覧からトップページ用の集計を作る(DOMに触れない純粋関数)。
 * generate-home-data.js(ビルド時)と、HOME_SUMMARY が使えない場合のページ側の両方から呼ぶ。
 */
function computeHomeSummary(playlists, standalonePlays) {
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

  // ⭐ 今週のおすすめVTuber の候補: 再生リストか単発実況が1件以上あるVTuber全員(名前順)。
  //   [名前, 掲載件数(再生リスト+単発実況), 掲載作品数, 初回掲載日]。選出は表示時に週ごとに行う(weeklyStreamerPicks)。
  function streamerPickCandidates() {
    const byStreamer = {};
    playlists.concat(standalonePlays || []).forEach((p) => {
      if (!p.streamer) return;
      const b = byStreamer[p.streamer] || (byStreamer[p.streamer] = { count: 0, games: new Set(), first: "" });
      b.count += 1;
      b.games.add(p.game);
      if (p.addedDate && (!b.first || p.addedDate < b.first)) b.first = p.addedDate;
    });
    return Object.keys(byStreamer).sort().map((k) => [k, byStreamer[k].count, byStreamer[k].games.size, byStreamer[k].first]);
  }

  // 🔄 最近更新された再生リスト(updatedDate優先、無ければaddedDateが新しい上位)
  //   除外する VTuber は上位を選ぶ前に外すので、表示件数(HOME_LIST_LIMIT)は変わらない
  const recentUpdated = playlists.filter((p) => (p.updatedDate || p.addedDate) && !HOME_RECENT_UPDATED_EXCLUDED_STREAMERS.has(p.streamer))
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
    streamerPicks: streamerPickCandidates(),
  };
}

/** HOME_SUMMARY がこのページで使える形かどうか(古い形式・生成失敗を検出する)。 */
function isUsableHomeSummary(summary) {
  return !!summary && summary.version === HOME_SUMMARY_VERSION
    && Array.isArray(summary.topGames) && Array.isArray(summary.recentUpdated)
    && Array.isArray(summary.streamerPicks) && typeof summary.playlistCount === "number";
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
    // 表示位置は HTML で最初から確保している(描画時に下の内容が押し下げられないように)。件数が無いときだけ隠す。
    const heroStats = document.getElementById("hero-stats");
    if (heroStats && summary.playlistCount) {
      heroStats.textContent = summary.playlistCount.toLocaleString("ja-JP") + "件の実況再生リストを掲載 ／ "
        + summary.gameCount.toLocaleString("ja-JP") + "ゲーム ／ "
        + summary.streamerCount.toLocaleString("ja-JP") + "VTuber掲載";
      heroStats.hidden = false;
    } else if (heroStats) {
      heroStats.hidden = true;
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

    // ⭐ 今週のおすすめVTuber(週替わり10組。選び方は weeklyStreamerPicks)
    const streamerGrid = document.getElementById("discover-popular-streamers");
    if (streamerGrid) {
      streamerGrid.innerHTML = "";
      const picks = weeklyStreamerPicks(summary.streamerPicks, Date.now(), (name) => (streamerByName[name] || {}).group || "");

      if (!picks.length) {
        const empty = document.createElement("div");
        empty.className = "empty-state";
        empty.textContent = "実況者データがまだありません。";
        streamerGrid.appendChild(empty);
      } else {
        picks.forEach((c) => {
          streamerGrid.appendChild(createStreamerCard(c[0], c[1]));
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
    renderPlaylistSections(computeHomeSummary(getAllPlaylists(), typeof STANDALONE_PLAYS === "undefined" ? [] : STANDALONE_PLAYS));
  } else if (typeof HOME_SUMMARY !== "undefined" && isUsableHomeSummary(HOME_SUMMARY)) {
    renderPlaylistSections(HOME_SUMMARY);
  } else {
    loadPlaylistsData().then(() => renderPlaylistSections(computeHomeSummary(getAllPlaylists(), typeof STANDALONE_PLAYS === "undefined" ? [] : STANDALONE_PLAYS)));
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
