/**
 * 単発・専用再生リストなし実況(singles.html)。表の見た目・検索と絞り込み・ページ送りは
 * 新着再生リスト(new.html)と共通(style.css の body.playlists-page と common.js)。
 * 投稿日は登録済み動画の公開日(publishedDate)のうち最も古い日、更新日は最も新しい日。
 * サイトへの登録日(addedDate)は表示にも並べ替えの対象にも使わない。
 */
(function () {
  const plays = typeof STANDALONE_PLAYS === "undefined" ? [] : STANDALONE_PLAYS;

  // 単発・PLなし実況(STANDALONE_PLAYS)がまだ1件も登録されていない間は、
  // 常に「まだ登録されていません」だけが表示される空のページになるため、
  // 検索結果には出さない(noindex)。他ページからのリンクは辿れるようにする
  // (follow)。データが追加され次第、次回の表示から自動的に解除される。
  if (plays.length === 0) {
    let robotsMeta = document.querySelector('meta[name="robots"]');
    if (!robotsMeta) {
      robotsMeta = document.createElement("meta");
      robotsMeta.setAttribute("name", "robots");
      document.head.appendChild(robotsMeta);
    }
    robotsMeta.setAttribute("content", "noindex,follow");
  }

  const UNKNOWN = "—";
  const COLUMNS = 8;
  const SORT_LABELS = {
    "posted-desc": "投稿日の新しい順", "posted-asc": "投稿日の古い順",
    "updated-desc": "更新日の新しい順", "updated-asc": "更新日の古い順",
    "count-desc": "動画数の多い順", "count-asc": "動画数の少ない順",
  };

  // 狭いジャンル列で長いジャンル名を2行にするときの、区切りのよい折り返し位置(ここ以外では折り返さない)
  const GENRE_BREAKS = {
    sandbox: ["サンド", "ボックス"],
    puzzle: ["パズル・", "謎解き"],
    sim: ["シミュレー", "ション"],
  };

  const grid = document.getElementById("grid");
  const resultCount = document.getElementById("result-count");
  const sortSelect = document.getElementById("sort-select");
  const sortHeaders = Array.from(document.querySelectorAll(".wiki-table th.sortable[data-sort]"));

  /** 実在する YYYY-MM-DD ならそのまま、それ以外は null */
  function validDate(value) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(value || "")) return null;
    const d = new Date(value + "T00:00:00Z");
    return !isNaN(d.getTime()) && d.toISOString().slice(0, 10) === value ? value : null;
  }
  function dateText(value) {
    return validDate(value) ? value.replace(/-/g, "/") : UNKNOWN;
  }

  // 表示用の行データ。1本でも公開日が分からない(または未登録の動画がある)場合は、
  // 最古・最新を確定できないので投稿日・更新日とも null にする。元データは変えない。
  // 並びの基準は追加日の新しい順(同じ日は登録順)で、並べ替えで同じ値の中はこの順になる。
  const rows = plays.map((item) => {
    const videos = item.videos || [];
    const dates = videos.map((v) => validDate(v.publishedDate));
    const known = dates.length > 0 && dates.length >= standalonePlayCount(item) && dates.every(Boolean);
    const sorted = known ? dates.slice().sort() : [];
    return {
      item: item,
      posted: known ? sorted[0] : null,
      updated: known ? sorted[sorted.length - 1] : null,
      count: standalonePlayCount(item),
    };
  }).sort((a, b) => (b.item.addedDate || "").localeCompare(a.item.addedDate || ""));

  let sortKey = "posted";
  let sortDir = -1; // 1: 昇順 / -1: 降順

  /** 現在の並べ替えを当てる。日付が不明な行は昇順・降順どちらでも末尾 */
  function sortRows(list) {
    return list.slice().sort((a, b) => {
      const va = a[sortKey];
      const vb = b[sortKey];
      if (va === null || vb === null) return (va === null) - (vb === null);
      if (va === vb) return 0;
      return (va < vb ? -1 : 1) * sortDir;
    });
  }

  function cell(className, label, child) {
    const td = document.createElement("td");
    td.className = className;
    if (label) td.setAttribute("data-label", label);
    if (child !== undefined) td.appendChild(typeof child === "string" ? document.createTextNode(child) : child);
    return td;
  }
  function link(className, href, text) {
    const a = document.createElement("a");
    a.className = className;
    a.href = href;
    a.textContent = text;
    return a;
  }
  function externalLink(className, href, text) {
    const a = link(className, href, text);
    a.target = "_blank";
    a.rel = "noopener";
    return a;
  }

  /** 展開行: 登録されている全動画を登録順に、公開日と YouTube へのリンクで並べる */
  function createDetailRow(item, id) {
    const tr = document.createElement("tr");
    tr.className = "singles-detail-row";
    tr.id = id;
    const td = document.createElement("td");
    td.colSpan = COLUMNS;
    const list = document.createElement("ol");
    list.className = "singles-videos";
    (item.videos || []).forEach((v) => {
      const li = document.createElement("li");
      const date = document.createElement(validDate(v.publishedDate) ? "time" : "span");
      date.className = "singles-video-date";
      if (validDate(v.publishedDate)) date.dateTime = v.publishedDate;
      date.textContent = dateText(v.publishedDate);
      li.appendChild(date);
      li.appendChild(document.createTextNode(" "));
      li.appendChild(externalLink("singles-video-link", v.url, v.title || v.url));
      list.appendChild(li);
    });
    td.appendChild(list);
    tr.appendChild(td);
    return tr;
  }

  /** 1件分の行(multi で2本以上なら、その下に閉じた状態の展開行も返す) */
  function createRows(row, index) {
    const item = row.item;
    const genre = genreById[item.genre] || genreById.other;
    const url = standalonePrimaryUrl(item);
    const alt = index % 2 === 1 ? " is-alt" : "";
    const tr = document.createElement("tr");
    tr.className = "singles-row" + alt;

    const badge = document.createElement("span");
    badge.className = "badge badge--" + genre.color;
    const parts = GENRE_BREAKS[genre.id];
    if (parts && parts.join("") === genre.label) {
      parts.forEach((part, i) => {
        if (i) badge.appendChild(document.createElement("wbr"));
        badge.appendChild(document.createTextNode(part));
      });
    } else {
      badge.textContent = genre.label;
    }
    tr.appendChild(cell("col-genre", "ジャンル", badge));

    const titleRow = document.createElement("div");
    titleRow.className = "row-title-row";
    if (url) {
      // 最初の数行は最初の画面に入るので遅延読み込みしない。枠は小さいので 320px の画像から読む
      const thumb = createStandaloneThumbnail(item, url, index < 3, ["mqdefault", "hqdefault"]);
      thumb.className = "row-thumb";
      titleRow.appendChild(thumb);
    }
    const text = document.createElement("div");
    text.className = "row-title-text";
    // 長いタイトルは CSS で3行までにする。全文はマウスを重ねると表示する
    const title = url ? externalLink("title-link", url, item.title) : document.createElement("span");
    if (!url) {
      title.className = "title-link";
      title.textContent = item.title;
    }
    title.title = item.title;
    text.appendChild(title);
    const format = document.createElement("span");
    format.className = "format-badge";
    format.textContent = playFormatLabel(item.format);
    text.appendChild(format);
    titleRow.appendChild(text);
    tr.appendChild(cell("title-cell", "", titleRow));

    tr.appendChild(cell("col-game", "ゲーム", link("game-link", gameUrl(item.game), gameDisplayName(item.game))));
    const agency = agencyOf(item.streamer);
    tr.appendChild(cell("col-agency", "事務所", link("agency-link", "streamers.html?agency=" + encodeURIComponent(agency), agency)));
    tr.appendChild(cell("col-streamer", "VTuber", link("streamer-link", streamerUrl(item.streamer), item.streamer)));

    const countCell = cell("col-count", "動画数", row.count ? row.count + "本" : UNKNOWN);
    tr.appendChild(countCell);
    tr.appendChild(cell("col-date", "投稿日", dateText(row.posted)));
    tr.appendChild(cell("col-date", "更新日", dateText(row.updated)));

    if (item.format !== "multi" || (item.videos || []).length < 2) return [tr];

    const detail = createDetailRow(item, "videos-" + item.id);
    detail.className += alt;
    detail.hidden = true;
    const toggle = document.createElement("button");
    toggle.type = "button";
    toggle.className = "singles-toggle";
    toggle.setAttribute("aria-controls", detail.id);
    function apply() {
      toggle.textContent = detail.hidden ? "▼ 一覧" : "▲ 閉じる";
      toggle.setAttribute("aria-expanded", String(!detail.hidden));
      toggle.setAttribute("aria-label", item.title + " の全" + item.videos.length + "本" + (detail.hidden ? "を表示" : "を閉じる"));
    }
    toggle.addEventListener("click", () => { detail.hidden = !detail.hidden; apply(); });
    apply();
    countCell.appendChild(toggle);
    return [tr, detail];
  }

  const setPageItems = initPagination((pageItems, start) => {
    grid.innerHTML = "";
    if (!pageItems.length) {
      const tr = document.createElement("tr");
      const empty = document.createElement("div");
      empty.className = "empty-state";
      empty.textContent = "条件に一致する実況はまだ登録されていません。";
      const td = cell("", "", empty);
      td.colSpan = COLUMNS;
      tr.appendChild(td);
      grid.appendChild(tr);
    }
    const fragment = document.createDocumentFragment();
    pageItems.forEach((row, i) => createRows(row, start + i).forEach((tr) => fragment.appendChild(tr)));
    grid.appendChild(fragment);
    resultCount.textContent = total + " 件" + (total === plays.length ? "" : "が該当(全" + plays.length + "件)") +
      " (" + SORT_LABELS[sortKey + (sortDir === 1 ? "-asc" : "-desc")] + ") — " +
      (total ? start + 1 : 0) + "〜" + (start + pageItems.length) + " 件目を表示";
  }, 20, { topBar: document.getElementById("pagination-top"), urlParam: "page", scrollTarget: resultCount });

  let total = 0;

  function render(page) {
    const f = controls.getFilters();
    const q = normalizeSearchText(f.q);
    const filtered = rows.filter(({ item }) => {
      if (f.format && item.format !== f.format) return false;
      if (f.genre && item.genre !== f.genre) return false;
      if (f.game && item.game !== f.game) return false;
      if (f.agency && agencyOf(item.streamer) !== f.agency) return false;
      if (f.streamer && item.streamer !== f.streamer) return false;
      if (!q) return true;
      return normalizeSearchText([item.title, item.streamer, gameSearchText(item.game), item.note].filter(Boolean).join(" ")).includes(q);
    });
    total = filtered.length;
    setPageItems(sortRows(filtered), { page: page || 1 });
  }

  // 検索語・絞り込みを URL に書く(入力のたびに履歴を増やさないよう置き換える。条件が変わったら1ページ目に戻す)
  function writeQueryToUrl() {
    const url = new URL(window.location.href);
    const f = controls.getFilters();
    ["q", "genre", "game", "agency", "streamer", "format"].forEach((name) => {
      const value = (f[name] || "").trim();
      if (value) url.searchParams.set(name, value); else url.searchParams.delete(name);
    });
    url.searchParams.delete("page");
    if (url.href !== window.location.href) history.replaceState(null, "", url.href);
  }

  const controls = initPlaylistListControls(() => {
    writeQueryToUrl();
    render(1);
  }, {
    gameCounts: typeof STANDALONE_COUNTS_BY_GAME === "undefined" ? {} : STANDALONE_COUNTS_BY_GAME,
    streamerCounts: typeof STANDALONE_COUNTS_BY_STREAMER === "undefined" ? {} : STANDALONE_COUNTS_BY_STREAMER,
    extraSelects: [{ el: document.getElementById("format-select"), param: "format" }],
  });

  // 表示件数の変更は initPagination が1ページ目から描き直すので、URL の page だけ外す
  document.getElementById("pagesize-select").addEventListener("change", () => writePageToUrl("page", 1, false));

  // 並べ替え: 列見出し(スマホ幅ではセレクト)。同じ列をもう一度押すと昇順・降順が入れ替わる
  function updateSortIndicators() {
    sortHeaders.forEach((th) => {
      const active = th.dataset.sort === sortKey;
      th.querySelector(".sort-arrow").textContent = active ? (sortDir === 1 ? "▲" : "▼") : "";
      if (active) th.setAttribute("aria-sort", sortDir === 1 ? "ascending" : "descending");
      else th.removeAttribute("aria-sort");
    });
    sortSelect.value = sortKey + (sortDir === 1 ? "-asc" : "-desc");
  }
  function changeSort(key, dir) {
    sortKey = key;
    sortDir = dir;
    updateSortIndicators();
    writePageToUrl("page", 1, false);
    render(1);
  }
  sortHeaders.forEach((th) => {
    th.addEventListener("click", () => changeSort(th.dataset.sort, th.dataset.sort === sortKey ? -sortDir : -1));
  });
  sortSelect.addEventListener("change", () => {
    const [key, dir] = sortSelect.value.split("-");
    changeSort(key, dir === "asc" ? 1 : -1);
  });

  // 戻る・進む: URL の条件とページ番号から表示し直す
  window.addEventListener("popstate", () => {
    controls.readFromUrl();
    render(readPageFromUrl("page"));
  });
  updateSortIndicators();
  render(readPageFromUrl("page"));
})();
