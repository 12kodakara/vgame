(function () {
  // 単発・PLなし実況(STANDALONE_PLAYS)がまだ1件も登録されていない間は、
  // 常に「まだ登録されていません」だけが表示される空のページになるため、
  // 検索結果には出さない(noindex)。他ページからのリンクは辿れるようにする
  // (follow)。データが追加され次第、次回の表示から自動的に解除される。
  if ((typeof STANDALONE_PLAYS === "undefined" ? [] : STANDALONE_PLAYS).length === 0) {
    let robotsMeta = document.querySelector('meta[name="robots"]');
    if (!robotsMeta) {
      robotsMeta = document.createElement("meta");
      robotsMeta.setAttribute("name", "robots");
      document.head.appendChild(robotsMeta);
    }
    robotsMeta.setAttribute("content", "noindex,follow");
  }

  const input = document.getElementById("single-search");
  const format = document.getElementById("format-select");
  const grid = document.getElementById("single-grid");
  const count = document.getElementById("result-count");

  // サムネイル(YouTube動画のサムネイル画像)は common.js の createStandaloneThumbnail(作品・VTuber詳細・検索と共通)
  function createCard(item, index) {
    const article = document.createElement("article");
    article.className = "play-card singles-card";

    const url = standalonePrimaryUrl(item);
    // 最初の1行分(PCで3枚)は最初の画面に入るので遅延読み込みしない
    if (url) article.appendChild(createStandaloneThumbnail(item, url, index < 3));

    const h3 = document.createElement("h3");
    h3.appendChild(document.createTextNode(gameDisplayName(item.game) + " "));
    const badge = document.createElement("span");
    badge.className = "format-badge";
    badge.textContent = playFormatLabel(item.format);
    h3.appendChild(badge);
    article.appendChild(h3);

    const pStreamer = document.createElement("p");
    const streamerLink = document.createElement("a");
    streamerLink.href = streamerUrl(item.streamer);
    streamerLink.textContent = item.streamer;
    pStreamer.appendChild(streamerLink);
    article.appendChild(pStreamer);

    // 動画タイトルは2行まで表示し、全文は title 属性(マウスを重ねる)と読み上げで確認できる
    const pTitle = document.createElement("p");
    pTitle.className = "singles-title";
    pTitle.textContent = item.title || "";
    if (item.title) pTitle.title = item.title;
    article.appendChild(pTitle);

    const pCount = document.createElement("p");
    pCount.textContent = "動画数: " + standalonePlayCount(item) + "本";
    article.appendChild(pCount);

    const actions = document.createElement("div");
    actions.className = "play-actions";
    if (url) {
      const a = document.createElement("a");
      a.href = url;
      a.target = "_blank";
      a.rel = "noopener";
      a.textContent = "YouTubeで見る";
      actions.appendChild(a);
    }
    const gameDetailLink = document.createElement("a");
    gameDetailLink.href = gameUrl(item.game);
    gameDetailLink.textContent = "ゲーム詳細";
    actions.appendChild(gameDetailLink);
    article.appendChild(actions);

    return article;
  }

  // 24件ずつページ分けし、そのページの分だけ描画する。ページ番号は URL の ?page= に残し、戻る・進むで復元する。
  // 遅延読み込みしないのは従来どおり一覧全体の先頭3件(1ページ目の最初の1行)だけ
  const PAGE_SIZE = 24;
  const pagination = document.getElementById("pagination");
  const setItems = initPagination((pageItems, start) => {
    grid.innerHTML = "";
    pageItems.forEach((x, i) => grid.appendChild(createCard(x, start + i)));
  }, PAGE_SIZE, { pageNumbers: document.getElementById("page-numbers"), urlParam: "page", scrollTarget: count });

  // 検索語・形式を URL に書く(入力のたびに履歴を増やさないよう置き換える。条件が変わったら1ページ目に戻す)
  function writeQueryToUrl() {
    const url = new URL(window.location.href);
    const raw = input.value.trim();
    if (raw) url.searchParams.set("q", raw); else url.searchParams.delete("q");
    if (format.value) url.searchParams.set("format", format.value); else url.searchParams.delete("format");
    url.searchParams.delete("page");
    if (url.href !== window.location.href) history.replaceState(null, "", url.href);
  }
  function readQueryFromUrl() {
    input.value = getQueryParam("q") || "";
    const f = getQueryParam("format") || "";
    format.value = Array.from(format.options || []).some((o) => o.value === f) ? f : "";
  }

  function render(page) {
    const q = normalizeSearchText(input.value);
    const f = format.value;
    const items = (typeof STANDALONE_PLAYS === "undefined" ? [] : STANDALONE_PLAYS).filter((x) => {
      if (f && x.format !== f) return false;
      if (!q) return true;
      return normalizeSearchText([x.title, x.streamer, gameSearchText(x.game), x.note].filter(Boolean).join(" ")).includes(q);
    });
    // 追加日(addedDate)の新しい順。filter が作った表示用の配列だけを並べ替え、元データ(STANDALONE_PLAYS)は変えない。
    // sort は安定ソートなので、同じ追加日の中は登録順のまま。追加日の無いものは最後に回す。
    items.sort((a, b) => (b.addedDate || "").localeCompare(a.addedDate || ""));
    count.textContent = items.length + " 件";
    pagination.hidden = items.length <= PAGE_SIZE;
    if (!items.length) {
      grid.innerHTML = "";
      const empty = document.createElement("div");
      empty.className = "empty-state";
      empty.textContent = "条件に一致する実況はまだ登録されていません。";
      grid.appendChild(empty);
      return;
    }
    setItems(items, { page: page || 1 });
  }

  // 条件が変わったときは1ページ目から(URL の page も外す)
  function onConditionChange() {
    writeQueryToUrl();
    render(1);
  }

  input.addEventListener("input", debounce(onConditionChange, 150));
  format.addEventListener("change", onConditionChange);
  // 戻る・進む: URL の条件とページ番号から表示し直す
  window.addEventListener("popstate", () => {
    readQueryFromUrl();
    render(readPageFromUrl("page"));
  });
  readQueryFromUrl();
  render(readPageFromUrl("page"));
})();
