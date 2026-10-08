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

  // ---------- サムネイル(YouTube動画のサムネイル画像) ----------
  // 画像URLは登録済みの動画URL(「YouTubeで見る」と同じURL)の動画IDから作る。手動では登録しない。
  // 動画IDが取れないURL(雑多な再生リストのURLなど)は推測で補わず、代替表示にする。
  function youtubeVideoIdOf(url) {
    let u;
    try { u = new URL(url); } catch (e) { return null; }
    let id = null;
    if (/^(www\.|m\.)?youtube\.com$/.test(u.hostname) && u.pathname === "/watch") id = u.searchParams.get("v");
    else if (u.hostname === "youtu.be") id = u.pathname.slice(1);
    return id && /^[A-Za-z0-9_-]{11}$/.test(id) ? id : null;
  }
  const thumbUrl = (id, size) => "https://i.ytimg.com/vi/" + id + "/" + size + ".jpg";
  // 読み込む順。高解像度の画面では 640px から、それ以外は 480px から始め、無ければ 320px へ下げる。
  // (srcset の幅指定を使うと naturalWidth が画面の密度で割られ、下の 120×90 の判定ができなくなるため使わない)
  // 段数が決まっているので、失敗しても再読み込みを繰り返さない
  const THUMB_STAGES = (window.devicePixelRatio || 1) >= 1.5 ? ["sddefault", "hqdefault", "mqdefault"] : ["hqdefault", "mqdefault"];

  function createThumb(item, url, eager) {
    const link = document.createElement("a");
    link.className = "singles-thumb";
    link.href = url;
    link.target = "_blank";
    link.rel = "noopener noreferrer";

    function showFallback() {
      link.innerHTML = "";
      const fallback = document.createElement("span");
      fallback.className = "singles-thumb-fallback";
      fallback.textContent = "▶ YouTubeで見る";
      link.appendChild(fallback);
      link.setAttribute("aria-label", (item.title || gameDisplayName(item.game)) + "(YouTubeで見る)");
    }

    const id = youtubeVideoIdOf(url);
    if (!id) {
      showFallback();
      return link;
    }
    const img = document.createElement("img");
    img.width = 480;
    img.height = 270;
    img.alt = (item.title || gameDisplayName(item.game)) + "(YouTube動画のサムネイル)";
    img.decoding = "async";
    img.loading = eager ? "eager" : "lazy";
    let stage = 0;
    function apply() {
      img.src = thumbUrl(id, THUMB_STAGES[stage]);
    }
    function next() {
      stage++;
      if (stage >= THUMB_STAGES.length) showFallback();
      else apply();
    }
    // 存在しないサイズには YouTube が 120×90 の灰色画像を HTTP 404 で返す(error にならず表示される)ため、その大きさなら次へ
    img.addEventListener("load", () => { if (img.naturalWidth === 120 && img.naturalHeight === 90) next(); });
    img.addEventListener("error", next);
    apply();
    link.appendChild(img);
    return link;
  }

  function createCard(item, index) {
    const article = document.createElement("article");
    article.className = "play-card singles-card";

    const url = standalonePrimaryUrl(item);
    // 最初の1行分(PCで3枚)は最初の画面に入るので遅延読み込みしない
    if (url) article.appendChild(createThumb(item, url, index < 3));

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
