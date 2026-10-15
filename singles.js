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
  const initial = getQueryParam("q") || "";
  input.value = initial;

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

  function render() {
    const q = normalizeSearchText(input.value);
    const f = format.value;
    const items = (typeof STANDALONE_PLAYS === "undefined" ? [] : STANDALONE_PLAYS).filter((x) => {
      if (f && x.format !== f) return false;
      if (!q) return true;
      return normalizeSearchText([x.title, x.streamer, gameSearchText(x.game), x.note].filter(Boolean).join(" ")).includes(q);
    });
    count.textContent = items.length + " 件";
    grid.innerHTML = "";
    if (!items.length) {
      const empty = document.createElement("div");
      empty.className = "empty-state";
      empty.textContent = "条件に一致する実況はまだ登録されていません。";
      grid.appendChild(empty);
      return;
    }
    items.forEach((x, i) => grid.appendChild(createCard(x, i)));
  }

  input.addEventListener("input", debounce(render, 150));
  format.addEventListener("change", render);
  render();
})();
