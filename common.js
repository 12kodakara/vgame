/**
 * ページ共通で使うユーティリティ・テーブル描画・サイドバー処理。
 * data-core.js (GENRES, STREAMERS, GAMES) より後に読み込むこと。
 * PLAYLISTS/STANDALONE_PLAYS を使う関数(allPlayEntries 等)を呼ぶページでは
 * data-playlists.js も先に読み込んでおくこと。
 */

const genreById = Object.fromEntries(GENRES.map((g) => [g.id, g]));

const agencyByStreamer = {};
STREAMERS.forEach((s) => {
  agencyByStreamer[s.name] = (s.group || "その他").split(" ")[0];
});
function agencyOf(streamerName) {
  return agencyByStreamer[streamerName] || "その他";
}

const streamerByName = Object.fromEntries(STREAMERS.map((s) => [s.name, s]));

/**
 * ============================================================
 * 再生リストへのデータアクセス
 * ============================================================
 * UI側(各ページのJS)はPLAYLISTS配列を直接検索・走査せず、必ずここの
 * 関数を経由すること。将来、件数が増えて data/games/*.js のようにファイルを
 * 分割したり、取得方法(fetch等)を変える場合も、変更箇所をここだけに
 * 閉じ込められる。
 * getPlaylistsByGame / getPlaylistsByStreamer は初回呼び出し時に1回だけ
 * ゲーム別・実況者別の索引(Map)を作り、以降はO(1)で参照する
 * (ページ側で PLAYLISTS.filter(...) を毎回行っていた6,500件の全件走査を
 * 索引参照に置き換えるパフォーマンス改善も兼ねている)。
 */
let _playlistsByGameIndex = null;
let _playlistsByStreamerIndex = null;

function buildPlaylistIndexes() {
  _playlistsByGameIndex = new Map();
  _playlistsByStreamerIndex = new Map();
  getAllPlaylists().forEach((p) => {
    if (!_playlistsByGameIndex.has(p.game)) _playlistsByGameIndex.set(p.game, []);
    _playlistsByGameIndex.get(p.game).push(p);
    if (!_playlistsByStreamerIndex.has(p.streamer)) _playlistsByStreamerIndex.set(p.streamer, []);
    _playlistsByStreamerIndex.get(p.streamer).push(p);
  });
}

/** 全再生リストを返す(data-playlists.js を読み込んでいないページでは空配列)。 */
function getAllPlaylists() {
  return typeof PLAYLISTS === "undefined" ? [] : PLAYLISTS;
}

/**
 * data-playlists.js を最初から読み込まないページ(トップページ。数MBあるため、
 * 初期表示には事前集計の data-home.js を使う)で、再生リスト全体が必要になった時点に
 * 1回だけ読み込む。既に読み込み済みなら即座に解決する。
 * 読み込み後は、空配列を前提に作られていた索引・キャッシュを作り直させる。
 */
let _playlistsDataPromise = null;
function loadPlaylistsData() {
  if (typeof PLAYLISTS !== "undefined") return Promise.resolve();
  if (!_playlistsDataPromise) {
    _playlistsDataPromise = new Promise((resolve, reject) => {
      const script = document.createElement("script");
      script.src = "data-playlists.js";
      script.onload = () => {
        _playlistsByGameIndex = null;
        _playlistsByStreamerIndex = null;
        _searchSuggestPlaylistIndexCache = null;
        resolve();
      };
      script.onerror = () => {
        _playlistsDataPromise = null;
        reject(new Error("data-playlists.js を読み込めませんでした"));
      };
      document.head.appendChild(script);
    });
  }
  return _playlistsDataPromise;
}

/** このページが「再生リストを必要になった時点で読み込む」設定か(<body data-lazy-playlists>)。 */
function isLazyPlaylistsPage() {
  return !!(document.body && document.body.hasAttribute("data-lazy-playlists"));
}

/** 指定したゲーム名の再生リストだけを返す(該当が無ければ空配列)。 */
function getPlaylistsByGame(gameName) {
  if (!_playlistsByGameIndex) buildPlaylistIndexes();
  return _playlistsByGameIndex.get(gameName) || [];
}

/** 指定した実況者名の再生リストだけを返す(該当が無ければ空配列)。 */
function getPlaylistsByStreamer(streamerName) {
  if (!_playlistsByStreamerIndex) buildPlaylistIndexes();
  return _playlistsByStreamerIndex.get(streamerName) || [];
}

/**
 * 各HTMLの <head> に書かれた canonical / og:url の「ドメイン部分」を
 * data-core.js の SITE_URL に合わせて上書きする(パス部分はHTMLに書かれた
 * ものをそのまま使う)。各HTMLのcanonical/og:url自体は既に正しい公開URLを
 * 直接記述しているため通常はここで書き換わる内容は無いが、SITE_URLとの
 * 不一致(ドメイン変更時の更新漏れ等)を防ぐ保険として実行している。
 * game.html/streamer.html等が後から呼ぶ setPageMeta() は、そのページの
 * 正しいパスを使って改めて上書きするので、ここでの処理と競合しない。
 *
 * SITE_URL が GitHub Pages のプロジェクトページ(例: ".../vgame")のように
 * パスの一部を含む場合、絶対URLの pathname にもそのパスが含まれるため、
 * 単純に "SITE_URL + pathname" で連結すると "/vgame/vgame/..." のように
 * 重複してしまう。そのため、URLのオリジン(ドメイン部分)が既に SITE_URL の
 * オリジンと一致する場合はパスに一切手を加えず、オリジンが異なる場合
 * (ドメイン移行時)のみオリジン部分だけを置き換える。
 */
function syncSiteUrl() {
  function withSiteUrl(url) {
    try {
      const siteOrigin = new URL(SITE_URL).origin;
      const u = new URL(url, SITE_URL);
      if (u.origin === siteOrigin) return url;
      return siteOrigin + u.pathname + u.search + u.hash;
    } catch (e) {
      return url;
    }
  }
  const canonical = document.querySelector('link[rel="canonical"]');
  if (canonical) canonical.setAttribute("href", withSiteUrl(canonical.getAttribute("href")));
  const ogUrl = document.querySelector('meta[property="og:url"]');
  if (ogUrl) ogUrl.setAttribute("content", withSiteUrl(ogUrl.getAttribute("content")));
  // og:image/twitter:image はサイト共通のOGP画像(og-image.png)を指す静的タグ
  // (game.html/streamer.html では後から setPageMeta() が個別画像で上書きする)。
  // ドメイン部分だけをここで SITE_URL に合わせる。
  const ogImage = document.querySelector('meta[property="og:image"]');
  if (ogImage) ogImage.setAttribute("content", withSiteUrl(ogImage.getAttribute("content")));
  const twitterImage = document.querySelector('meta[name="twitter:image"]');
  if (twitterImage) twitterImage.setAttribute("content", withSiteUrl(twitterImage.getAttribute("content")));
}
syncSiteUrl();

/**
 * 画面に表示されている .breadcrumb-wiki(リンク+末尾の現在ページ名)から
 * BreadcrumbList構造化データ(JSON-LD)を生成し、<head>に追加/更新する。
 * ページ独自のJSがタイトルを決めるページ(game.html/streamer.html等)では、
 * パンくずの末尾(#breadcrumb-current)がまだ空の間は何もしない
 * (setPageMeta() が呼ばれるタイミングで確定した内容を使って再実行される)。
 */
function injectBreadcrumbJsonLd() {
  const nav = document.querySelector(".breadcrumb-wiki");
  if (!nav) return;

  const items = [];
  let currentText = "";
  nav.childNodes.forEach((node) => {
    if (node.nodeType === 1 && node.tagName === "A") {
      items.push({ name: node.textContent.trim(), href: node.getAttribute("href") });
    } else {
      const text = (node.textContent || "").replace(/[›\s]+/g, " ").trim();
      if (text) currentText = text;
    }
  });
  if (!currentText || !items.length) return;
  items.push({ name: currentText, href: null });

  const data = {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: items.map((it, i) => {
      const li = { "@type": "ListItem", position: i + 1, name: it.name };
      if (it.href) li.item = new URL(it.href, SITE_URL).href;
      return li;
    }),
  };

  let script = document.getElementById("breadcrumb-jsonld");
  if (!script) {
    script = document.createElement("script");
    script.type = "application/ld+json";
    script.id = "breadcrumb-jsonld";
    document.head.appendChild(script);
  }
  script.textContent = JSON.stringify(data);
}

/**
 * トップページ専用: WebSite + SearchAction構造化データ(JSON-LD)を<head>に追加する。
 * Googleがサイトリンク検索ボックスの表示を検討する際の手がかりになる
 * (表示するかどうかはGoogle側の判断のため保証はない)。home.js からのみ呼び出す。
 */
function injectWebSiteJsonLd() {
  const data = {
    "@context": "https://schema.org",
    "@type": "WebSite",
    name: SITE_NAME,
    url: SITE_URL + "/",
    potentialAction: {
      "@type": "SearchAction",
      target: SITE_URL + "/search.html?q={search_term_string}",
      "query-input": "required name=search_term_string",
    },
  };
  const script = document.createElement("script");
  script.type = "application/ld+json";
  script.id = "website-jsonld";
  script.textContent = JSON.stringify(data);
  document.head.appendChild(script);
}
injectBreadcrumbJsonLd();

/**
 * STREAMERSの group("ホロライブ 0期生"など)から事務所名を除いた
 * ユニット名("0期生")を返す。group が事務所名と完全一致する場合(例: "ぶいすぽ")は
 * ユニット名が存在しないとみなし、空文字を返す。
 */
function unitLabelOf(group) {
  const value = group || "その他";
  const agency = value.split(" ")[0];
  return value.slice(agency.length).trim();
}

function uniqueSorted(values) {
  return Array.from(new Set(values)).sort((a, b) => a.localeCompare(b, "ja"));
}

/** カタカナをひらがなに変換する(長音符・濁点結合文字等はそのまま)。 */
function katakanaToHiragana(str) {
  return str.replace(/[ァ-ヶ]/g, (ch) => String.fromCharCode(ch.charCodeAt(0) - 0x60));
}

/**
 * 検索用の文字列を正規化する。
 * NFKCで全角英数字・全角スペース等を揃え、カタカナ→ひらがな変換で表記揺れ
 * (例: 「サイレン」⇔「さいれん」)も吸収し、大文字小文字も吸収する。
 */
function normalizeSearchText(value) {
  return katakanaToHiragana(String(value == null ? "" : value).normalize("NFKC"))
    .toLowerCase()
    .trim()
    .replace(/\s+/g, " ");
}

const gameByName = Object.fromEntries(GAMES.map((g) => [g.name, g]));

function gameCatalogOf(gameName) {
  return gameByName[gameName] || null;
}

/** 検索対象にするゲーム名・日本語名・読み・別名・シリーズを1本の文字列にする。 */
function gameSearchText(gameName) {
  const game = gameCatalogOf(gameName);
  if (!game) return normalizeSearchText(gameName);

  return normalizeSearchText([
    game.name,
    game.nameJa,
    game.kana,
    ...(game.aliases || []),
    game.series,
  ].filter(Boolean).join(" "));
}

function playFormatLabel(format) {
  return ({ single: "単発", multi: "複数回・PLなし", "mixed-playlist": "雑多PL内" })[format] || "再生リスト";
}

function standalonePlayCount(item) {
  return item.videoCount || ((item.videos || []).length);
}

function standalonePrimaryUrl(item) {
  if (item.format === "mixed-playlist" && item.mixedPlaylistUrl) return item.mixedPlaylistUrl;
  const first = (item.videos || [])[0];
  return first ? first.url : "";
}

function allPlayEntries() {
  const playlistEntries = getAllPlaylists().map((p) => Object.assign({ format: "series", sourceType: "playlist" }, p));
  const standaloneEntries = (typeof STANDALONE_PLAYS === "undefined" ? [] : STANDALONE_PLAYS).map((p) => Object.assign({ sourceType: "standalone" }, p));
  return playlistEntries.concat(standaloneEntries);
}

function searchScore(item, rawQuery) {
  const q = normalizeSearchText(rawQuery);
  if (!q) return 0;
  const game = normalizeSearchText(gameSearchText(item.game));
  const gameName = normalizeSearchText(item.game);
  const title = normalizeSearchText(item.title);
  const streamer = normalizeSearchText(item.streamer);
  if (gameName === q || streamer === q || title === q) return 100;
  if (gameName.startsWith(q) || streamer.startsWith(q) || title.startsWith(q)) return 80;
  if (game.includes(q)) return 70;
  if (title.includes(q) || streamer.includes(q)) return 60;
  return 0;
}
function gameDisplayName(gameName) {
  return gameName;
}

/**
 * 50音順(あいうえお順)のグループ分け用テーブル。
 * 濁音・半濁音・小書き文字は、対応する清音の文字にまとめる。
 */
const KANA_NORMALIZE = {
  ぁ: "あ", ぃ: "い", ぅ: "う", ぇ: "え", ぉ: "お", ゔ: "う",
  が: "か", ぎ: "き", ぐ: "く", げ: "け", ご: "こ",
  ざ: "さ", じ: "し", ず: "す", ぜ: "せ", ぞ: "そ",
  だ: "た", ぢ: "ち", づ: "つ", で: "て", ど: "と", っ: "つ",
  ば: "は", び: "ひ", ぶ: "ふ", べ: "へ", ぼ: "ほ",
  ぱ: "は", ぴ: "ひ", ぷ: "ふ", ぺ: "へ", ぽ: "ほ",
  ゃ: "や", ゅ: "ゆ", ょ: "よ", ゎ: "わ",
  ゐ: "わ", ゑ: "わ",
};

const KANA_ORDER =
  "あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをん".split("");

/**
 * 行(あ・か・さ…)ごとの構成文字。ゲーム一覧ページの2段ナビで使用。
 */
const KANA_ROW_GROUPS = [
  { row: "あ", members: ["あ", "い", "う", "え", "お"] },
  { row: "か", members: ["か", "き", "く", "け", "こ"] },
  { row: "さ", members: ["さ", "し", "す", "せ", "そ"] },
  { row: "た", members: ["た", "ち", "つ", "て", "と"] },
  { row: "な", members: ["な", "に", "ぬ", "ね", "の"] },
  { row: "は", members: ["は", "ひ", "ふ", "へ", "ほ"] },
  { row: "ま", members: ["ま", "み", "む", "め", "も"] },
  { row: "や", members: ["や", "ゆ", "よ"] },
  { row: "ら", members: ["ら", "り", "る", "れ", "ろ"] },
  { row: "わ", members: ["わ", "を", "ん"] },
];

function kanaGroupOf(kana) {
  const c = (kana || "").charAt(0);
  const base = KANA_NORMALIZE[c] || c;
  return KANA_ORDER.indexOf(base) !== -1 ? base : "他";
}

/**
 * GAMES配列を kana(読み仮名) の50音順に並べ、頭文字(あ・い・う…)ごとに
 * { row: "あ", names: [ゲーム名, ...] } の配列にまとめて返す。
 */
function groupGamesByKana() {
  const byGroup = {};
  GAMES.forEach((g) => {
    const key = kanaGroupOf(g.kana || g.name);
    if (!byGroup[key]) byGroup[key] = [];
    byGroup[key].push(g);
  });

  const groups = [];
  KANA_ORDER.concat("他").forEach((label) => {
    if (!byGroup[label]) return;
    const names = byGroup[label]
      .slice()
      .sort((a, b) => {
        if (a.order != null && b.order != null) return a.order - b.order;
        return (a.kana || a.name).localeCompare(b.kana || b.name, "ja");
      })
      .map((g) => g.name);
    groups.push({ row: label, names: names });
  });
  return groups;
}

function getQueryParam(name) {
  return new URLSearchParams(window.location.search).get(name);
}

/**
 * 関数の呼び出しを遅延させ、短時間に連続で呼ばれた場合は最後の1回だけ実行する。
 * 検索欄に入力するたびに大量データ(数千件)を再描画するような処理を、
 * 入力が落ち着くまで待ってから1回だけ行うようにするために使う。
 */
function debounce(fn, delayMs) {
  let timer = null;
  return function debounced(...args) {
    clearTimeout(timer);
    timer = setTimeout(() => fn.apply(this, args), delayMs);
  };
}

/**
 * ページタイトル・description・OGPタグ(og:title/og:description/og:url)・
 * canonicalリンクをまとめて更新する。ゲーム別・実況者別ページなど、内容に応じて
 * これらを動的に変えるページで使う。
 * canonicalPath : サイトルートからの相対パス(例: "/game.html?game=Minecraft")。
 *                 渡した場合のみ canonical と og:url を SITE_URL + canonicalPath で
 *                 設定・更新する(省略時は canonical に触れない)。
 * imageUrl      : SNSシェア用画像(og:image/twitter:image)。渡した場合のみ設定し、
 *                 twitter:card も "summary_large_image" に切り替える
 *                 (代表的な再生リストのサムネイルなど、既に存在するURLを渡す想定。
 *                 画像を新規生成・アップロードする仕組みではない)。
 */
/**
 * 存在しないゲーム/VTuberのURLを開いたときの「見つかりません」表示。
 * 見出し・パンくずを差し替え、統計や各セクションを隠して、一覧へ戻る導線だけを出す。
 * URLの値は利用者の入力なので、DOM APIと textContent だけで組み立てる。
 * 隠す要素はCSS側で display が指定されているものがあるため、hidden属性ではなく style で隠す。
 *
 * opts: title(見出し) / message(説明文) / backHref / backLabel(戻り先リンク) / docTitle(<title>)
 */
function renderNotFoundPage(opts) {
  const content = document.querySelector("main.wiki-content .content-box");
  const titleEl = document.getElementById("page-title");
  if (titleEl) titleEl.textContent = opts.title;
  const breadcrumbEl = document.getElementById("breadcrumb-current");
  if (breadcrumbEl) breadcrumbEl.textContent = opts.title;
  const favoriteBtn = document.getElementById("favorite-btn");
  if (favoriteBtn) favoriteBtn.style.display = "none";

  if (content) {
    Array.from(content.children).forEach((el) => {
      const keep = el.matches(".breadcrumb-wiki") || el.contains(titleEl);
      if (!keep) el.style.display = "none";
    });
    const box = document.createElement("section");
    box.className = "section-box";
    const message = document.createElement("p");
    message.className = "page-lead";
    message.textContent = opts.message;
    const back = document.createElement("p");
    const link = document.createElement("a");
    link.href = opts.backHref;
    link.textContent = opts.backLabel;
    back.appendChild(link);
    box.appendChild(message);
    box.appendChild(back);
    content.appendChild(box);
  }

  document.title = opts.docTitle;
  let robotsMeta = document.querySelector('meta[name="robots"]');
  if (!robotsMeta) {
    robotsMeta = document.createElement("meta");
    robotsMeta.setAttribute("name", "robots");
    document.head.appendChild(robotsMeta);
  }
  robotsMeta.setAttribute("content", "noindex,follow");
}

function setPageMeta(title, description, canonicalPath, imageUrl) {
  document.title = title;

  function upsertMeta(selector, attrs) {
    let el = document.querySelector(selector);
    if (!el) {
      el = document.createElement("meta");
      Object.keys(attrs).forEach((key) => { if (key !== "content") el.setAttribute(key, attrs[key]); });
      document.head.appendChild(el);
    }
    el.setAttribute("content", attrs.content);
  }

  upsertMeta('meta[name="description"]', { name: "description", content: description });
  upsertMeta('meta[property="og:title"]', { property: "og:title", content: title });
  upsertMeta('meta[property="og:description"]', { property: "og:description", content: description });
  upsertMeta('meta[name="twitter:title"]', { name: "twitter:title", content: title });
  upsertMeta('meta[name="twitter:description"]', { name: "twitter:description", content: description });

  if (canonicalPath) {
    const url = SITE_URL + canonicalPath;
    let link = document.querySelector('link[rel="canonical"]');
    if (!link) {
      link = document.createElement("link");
      link.setAttribute("rel", "canonical");
      document.head.appendChild(link);
    }
    link.setAttribute("href", url);
    upsertMeta('meta[property="og:url"]', { property: "og:url", content: url });
  }

  if (imageUrl) {
    upsertMeta('meta[property="og:image"]', { property: "og:image", content: imageUrl });
    upsertMeta('meta[name="twitter:image"]', { name: "twitter:image", content: imageUrl });
    upsertMeta('meta[name="twitter:card"]', { name: "twitter:card", content: "summary_large_image" });
  }

  injectBreadcrumbJsonLd();
}

/**
 * 単発・専用再生リストなし実況(STANDALONE_PLAYS)1件分の <article class="play-card"> を作る。
 * opts.showGame: trueならタイトル行にゲーム名リンクを表示(実況者別ページ用)。
 *                falseなら実況者名リンクを表示(ゲーム別・検索ページ用)。
 */
function createStandaloneCard(item, opts) {
  opts = opts || {};
  const article = document.createElement("article");
  article.className = "play-card";

  const h3 = document.createElement("h3");
  if (opts.showGame) {
    const gameLink = document.createElement("a");
    gameLink.href = gameUrl(item.game);
    gameLink.textContent = gameDisplayName(item.game);
    h3.appendChild(gameLink);
    h3.appendChild(document.createTextNode(" "));
  } else {
    h3.appendChild(document.createTextNode(item.title + " "));
  }
  const badge = document.createElement("span");
  badge.className = "format-badge";
  badge.textContent = playFormatLabel(item.format);
  h3.appendChild(badge);
  article.appendChild(h3);

  const p1 = document.createElement("p");
  if (opts.showGame) {
    p1.textContent = item.title || "";
  } else {
    const streamerLink = document.createElement("a");
    streamerLink.href = streamerUrl(item.streamer);
    streamerLink.textContent = item.streamer;
    p1.appendChild(streamerLink);
  }
  article.appendChild(p1);

  const p2 = document.createElement("p");
  p2.textContent = "動画数: " + standalonePlayCount(item) + "本";
  article.appendChild(p2);

  const actions = document.createElement("div");
  actions.className = "play-actions";
  const url = standalonePrimaryUrl(item);
  if (url) {
    const a = document.createElement("a");
    a.href = url;
    a.target = "_blank";
    a.rel = "noopener";
    a.textContent = "YouTubeで見る";
    actions.appendChild(a);
  }
  if (opts.showGameDetailLink) {
    const a = document.createElement("a");
    a.href = gameUrl(item.game);
    a.textContent = "ゲーム詳細";
    actions.appendChild(a);
  }
  article.appendChild(actions);

  return article;
}

/**
 * 実況者カード <li class="streamer-card"> を1件作る(アイコン画像・失敗時は
 * 頭文字のプレースホルダー・名前・件数)。streamers.html・game.html(このゲームを
 * 実況しているVTuber)・トップページ(人気VTuber)で同じ見た目のカードが
 * 必要なため共通化している。アイコンは一覧内で多数作られるため遅延読み込みにする。
 */
function createStreamerCard(name, count) {
  const s = streamerByName[name];
  const li = document.createElement("li");
  li.className = "streamer-card";

  const a = document.createElement("a");
  a.href = streamerUrl(name);

  function showPlaceholder() {
    const placeholder = document.createElement("span");
    placeholder.className = "streamer-card-icon streamer-card-icon--placeholder";
    placeholder.textContent = name.charAt(0);
    a.prepend(placeholder);
  }

  if (s && s.icon) {
    const img = document.createElement("img");
    img.className = "streamer-card-icon";
    img.src = s.icon;
    img.alt = "";
    img.loading = "lazy";
    img.addEventListener("error", () => { img.remove(); showPlaceholder(); }, { once: true });
    a.appendChild(img);
  } else {
    showPlaceholder();
  }

  const nameSpan = document.createElement("span");
  nameSpan.className = "streamer-card-name";
  nameSpan.textContent = name;
  a.appendChild(nameSpan);

  const countSpan = document.createElement("span");
  countSpan.className = "count";
  countSpan.textContent = "(" + count + "件)";
  a.appendChild(countSpan);

  li.appendChild(a);
  return li;
}

/**
 * 索引一覧の1行 <li><a>ラベル</a><span class="count">(N件)</span></li> を作る。
 * 五十音行索引・実況したゲーム一覧など、同じ形の行が複数ページで必要なため共通化している。
 * innerHTML文字列組み立てではなく textContent を使うので、ラベルのエスケープも不要。
 */
function createCountIndexItem(url, label, count) {
  const li = document.createElement("li");

  const a = document.createElement("a");
  a.href = url;
  a.textContent = label;
  li.appendChild(a);

  const countSpan = document.createElement("span");
  countSpan.className = "count";
  countSpan.textContent = "(" + count + "件)";
  li.appendChild(countSpan);

  return li;
}

/**
 * 五十音行ごとのゲーム件数索引(あ行〜わ行、全10行)を container(<ul>)に描画する。
 * games.html・トップページの「ゲームから探す」で同じ内容が必要なため共通化している。
 */
function renderGameRowIndex(container) {
  if (!container) return;
  container.innerHTML = "";

  const countByKana = {};
  groupGamesByKana().forEach((group) => { countByKana[group.row] = group.names.length; });

  KANA_ROW_GROUPS.forEach((rowGroup) => {
    const count = rowGroup.members.reduce((sum, k) => sum + (countByKana[k] || 0), 0);
    container.appendChild(createCountIndexItem(
      "games-row.html?row=" + encodeURIComponent(rowGroup.row),
      rowGroup.row + "行",
      count
    ));
  });
}

function playlistUrl(item) {
  return "https://www.youtube.com/playlist?list=" + encodeURIComponent(item.playlistId);
}

/**
 * ============================================================
 * 再生リストサムネイル
 * ============================================================
 * item.thumbnailUrl は fetch-thumbnails.ps1 が YouTube Data API
 * (playlists.list、50件まとめ取得)で事前に取得し、data-playlists.js に
 * 保存した値をそのまま使う。ページ閲覧時にAPIへアクセスすることは無い。
 */

/**
 * YouTube が「サムネイルなし」の再生リストに返す灰色のプレースホルダー画像。
 * HTTP 404 だが画像本体が付いて返るため、ブラウザは error を発火せずそのまま表示し、
 * VTuberアイコンへのフォールバックが働かない。サムネイル未取得と同じ扱いにする。
 */
const YOUTUBE_NO_THUMBNAIL_URL = /^https?:\/\/i\.ytimg\.com\/img\/no_thumbnail\.jpg$/;

/** 再生リストのサムネイルURL(未取得・YouTubeのプレースホルダーなら null)。API通信は行わない。 */
function getPlaylistThumbnailUrl(item) {
  const url = (item && item.thumbnailUrl) || null;
  if (url && YOUTUBE_NO_THUMBNAIL_URL.test(url)) return null;
  return url;
}

/**
 * 再生リストの「人気度」を1つの値に集約する関数。現段階では手動設定の
 * popularity(データ側)を最優先し、未設定(0/undefined)の場合は動画数を
 * 代用スコアとして使う。将来的に更新日の新しさ・クリック数・閲覧数などを
 * 組み合わせたスコアリングへ変える場合も、呼び出し側(ランキング・
 * 「人気実況」セクション等)は item.popularity を直接参照せずこの関数を
 * 通すことで、変更箇所をここ1つに閉じ込められる。
 */
function calculatePopularity(item) {
  return (item && (item.popularity || item.videoCount)) || 0;
}

/**
 * ============================================================
 * 最近見た履歴・お気に入り(localStorageのみ、バックエンド無し)
 * ============================================================
 * プライベートブラウジングや設定でlocalStorageが使えない環境でも致命的な
 * エラーにならないよう、読み書きは必ず safeStorageGet/Set 経由で行う
 * (失敗時は「保存できない」だけにして機能自体は静かに無効化する)。
 */
const RECENTLY_VIEWED_KEY = "vgame_recently_viewed_v1";
const RECENTLY_VIEWED_LIMIT = 20;
const FAVORITES_KEY = "vgame_favorites_v1";

function safeStorageGet(key) {
  try {
    return window.localStorage.getItem(key);
  } catch (e) {
    return null;
  }
}

function safeStorageSet(key, value) {
  try {
    window.localStorage.setItem(key, value);
    return true;
  } catch (e) {
    return false;
  }
}

function loadJsonRecord(key, shape) {
  const raw = safeStorageGet(key);
  let parsed = null;
  if (raw) {
    try {
      parsed = JSON.parse(raw);
    } catch (e) {
      parsed = null;
    }
  }
  const result = {};
  Object.keys(shape).forEach((k) => {
    result[k] = (parsed && Array.isArray(parsed[k])) ? parsed[k] : [];
  });
  return result;
}

/**
 * 最近見たゲーム/VTuber/再生リストを記録する。type: "game" | "streamer" | "playlist"。
 * entry: { key(重複判定用の一意な値), label(表示名), url(リンク先), sub(補足、省略可) }
 * 同じkeyが既にあれば先頭へ移動(重複を増やさない)。最大 RECENTLY_VIEWED_LIMIT 件。
 */
function recordRecentlyViewed(type, entry) {
  if (!entry || !entry.key) return;
  const data = loadJsonRecord(RECENTLY_VIEWED_KEY, { game: [], streamer: [], playlist: [] });
  if (!data[type]) return;
  const filtered = data[type].filter((x) => x.key !== entry.key);
  filtered.unshift({ key: entry.key, label: entry.label, url: entry.url, sub: entry.sub || "", viewedAt: Date.now() });
  data[type] = filtered.slice(0, RECENTLY_VIEWED_LIMIT);
  safeStorageSet(RECENTLY_VIEWED_KEY, JSON.stringify(data));
}

/** type別、または省略時は3種類を viewedAt 降順にまとめた配列を返す。 */
function getRecentlyViewed(type) {
  const data = loadJsonRecord(RECENTLY_VIEWED_KEY, { game: [], streamer: [], playlist: [] });
  if (type) return data[type] || [];
  return []
    .concat(data.game.map((x) => Object.assign({ type: "game" }, x)))
    .concat(data.streamer.map((x) => Object.assign({ type: "streamer" }, x)))
    .concat(data.playlist.map((x) => Object.assign({ type: "playlist" }, x)))
    .sort((a, b) => b.viewedAt - a.viewedAt);
}

/** クリック/タップで実際にリンクへ遷移するタイミングでのみ記録する(表示だけでは記録しない)。 */
function attachRecentlyViewedTracking(el, type, entry) {
  el.addEventListener("click", () => recordRecentlyViewed(type, entry));
}

/** 再生リスト(item)を「最近見た再生リスト」のentry形式に変換する共通ヘルパー。 */
function playlistRecentEntry(item) {
  return {
    key: item.id || item.playlistId || item.title,
    label: item.title,
    url: playlistUrl(item),
    sub: item.streamer + " ／ " + gameDisplayName(item.game),
  };
}

function loadFavorites() {
  return loadJsonRecord(FAVORITES_KEY, { game: [], streamer: [] });
}

function isFavorite(type, key) {
  const data = loadFavorites();
  return !!(data[type] && data[type].some((x) => x.key === key));
}

/** お気に入りの追加/削除を切り替える。戻り値: 切り替え後にお気に入りかどうか(true/false)。 */
function toggleFavorite(type, entry) {
  const data = loadFavorites();
  if (!data[type]) return false;
  const exists = data[type].some((x) => x.key === entry.key);
  if (exists) {
    data[type] = data[type].filter((x) => x.key !== entry.key);
  } else {
    data[type] = [{ key: entry.key, label: entry.label, url: entry.url }].concat(data[type]);
  }
  safeStorageSet(FAVORITES_KEY, JSON.stringify(data));
  return !exists;
}

/**
 * ゲーム/VTuber詳細ページの☆ボタンを初期化する。button要素に現在の状態を
 * 反映し、クリックでお気に入りを切り替える。
 */
function initFavoriteButton(button, type, entry) {
  if (!button) return;
  function render(active) {
    button.innerHTML = "";
    const star = document.createElement("span");
    star.className = "favorite-btn-star";
    star.textContent = active ? "★" : "☆";
    button.appendChild(star);
    button.appendChild(document.createTextNode(active ? " お気に入り済み" : " お気に入りに追加"));
    button.setAttribute("aria-pressed", String(active));
  }
  render(isFavorite(type, entry.key));
  button.addEventListener("click", () => {
    const active = toggleFavorite(type, entry);
    render(active);
  });
}

/**
 * ============================================================
 * 最近の検索語(localStorageのみ、個人情報は保存しない)
 * ============================================================
 * 検索ボックスで実際に検索を実行した語句だけを最大5件、新しい順で保存する。
 * 入力途中の文字列は保存しない(送信・候補選択のタイミングでのみ記録)。
 */
const RECENT_SEARCHES_KEY = "vgame_recent_searches_v1";
const RECENT_SEARCHES_LIMIT = 5;

function getRecentSearches() {
  const raw = safeStorageGet(RECENT_SEARCHES_KEY);
  if (!raw) return [];
  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed.filter((x) => typeof x === "string") : [];
  } catch (e) {
    return [];
  }
}

function addRecentSearch(term) {
  const value = String(term == null ? "" : term).trim();
  if (!value) return;
  const normalized = normalizeSearchText(value);
  const filtered = getRecentSearches().filter((x) => normalizeSearchText(x) !== normalized);
  filtered.unshift(value);
  safeStorageSet(RECENT_SEARCHES_KEY, JSON.stringify(filtered.slice(0, RECENT_SEARCHES_LIMIT)));
}

function clearRecentSearches() {
  safeStorageSet(RECENT_SEARCHES_KEY, JSON.stringify([]));
}

/** サムネイルもVTuberアイコンも無い/失敗した場合の、実況者名の頭文字プレースホルダー。 */
function createThumbnailPlaceholder(streamerName, placeholderClass) {
  const span = document.createElement("span");
  span.className = placeholderClass;
  span.textContent = (streamerName || "?").charAt(0);
  return span;
}

/**
 * 再生リスト1件分のサムネイルを安全に生成する。
 * 優先順位: ① item.thumbnailUrl(YouTube再生リストのサムネイル)
 *          ② VTuberアイコン(streamerByName から取得)
 *          ③ 実況者名の頭文字
 * どちらの画像も読み込みに失敗した場合は自動的に次の候補へ1段階だけ切り替える
 * (失敗イベントは { once: true } で1回しか登録しないため、無限に読み込みを
 * 再試行することはない)。innerHTMLへ外部データを直接流し込むことはせず、
 * DOM APIと textContent のみを使う。
 *
 * options:
 *   width / height   : <img> の width/height 属性(レイアウトシフト防止用の整数px)。
 *                       既定は一覧向けの 320×180。
 *   containerTag      : ラッパー要素のタグ名。既定 "span"。
 *   containerClass    : ラッパー要素のクラス名。
 *   imgClass          : <img> のクラス名(ラッパー側のCSSで表示サイズ・角丸・
 *                        object-fit 等を制御する場合は省略可)。
 *   placeholderClass  : プレースホルダーのクラス名。
 *   alt               : 代替テキスト。タイトル等が同じリンク内に文字として
 *                        存在する装飾目的の場合は既定の "" のままにする。
 */
function createPlaylistThumbnail(item, options) {
  options = options || {};
  const width = options.width || 320;
  const height = options.height || 180;
  const containerTag = options.containerTag || "span";
  const containerClass = options.containerClass || "";
  const imgClass = options.imgClass || "";
  const placeholderClass = options.placeholderClass || "";
  const alt = options.alt || "";

  const wrap = document.createElement(containerTag);
  if (containerClass) wrap.className = containerClass;

  const streamer = streamerByName[item.streamer];
  const iconUrl = (streamer && streamer.icon) || null;
  const thumbnailUrl = getPlaylistThumbnailUrl(item);

  function showPlaceholder() {
    wrap.innerHTML = "";
    wrap.appendChild(createThumbnailPlaceholder(item.streamer, placeholderClass));
  }

  function showIcon() {
    if (!iconUrl) {
      showPlaceholder();
      return;
    }
    wrap.innerHTML = "";
    const img = document.createElement("img");
    if (imgClass) img.className = imgClass;
    img.src = iconUrl;
    img.width = width;
    img.height = height;
    img.alt = alt;
    img.loading = "lazy";
    img.decoding = "async";
    img.addEventListener("error", showPlaceholder, { once: true });
    wrap.appendChild(img);
  }

  if (thumbnailUrl) {
    const img = document.createElement("img");
    if (imgClass) img.className = imgClass;
    img.src = thumbnailUrl;
    img.width = width;
    img.height = height;
    img.alt = alt;
    img.loading = "lazy";
    img.decoding = "async";
    img.addEventListener("error", showIcon, { once: true });
    wrap.appendChild(img);
  } else if (iconUrl) {
    showIcon();
  } else {
    showPlaceholder();
  }

  return wrap;
}

/**
 * 再生リストの簡易一覧(順位+サムネイル+タイトル+メタ情報)を container
 * (<ol>/<ul> の id)へ描画する。トップページの「最近追加された実況」、
 * ゲーム/VTuber詳細ページの「人気実況」「最近更新された実況」など、
 * 見た目が共通の箇所で使う(元々ページごとに似た描画処理が重複していたため
 * ここへ集約した)。
 * opts.showGame     : メタ行にゲーム名リンクを表示するか(既定 true。
 *                      ゲーム詳細ページ内で使う場合はゲーム名が自明なので false)。
 * opts.showStreamer : メタ行にVTuber名リンクを表示するか(既定 true。
 *                      VTuber詳細ページ内で使う場合は false)。
 * opts.dateLabel    : 日付の後に付ける文字列(既定 " 更新"。追加日を出す場合は " 追加" 等)。
 * opts.dateField    : 表示する日付フィールド。"updated"(既定、updatedDate優先・
 *                      無ければaddedDate)または "added"(常にaddedDateを表示。
 *                      「最近追加された実況」のように追加日そのものを見せたい場合)。
 */
function renderPlaylistDiscoverList(containerId, items, emptyMessage, opts) {
  opts = opts || {};
  const showGame = opts.showGame !== false;
  const showStreamer = opts.showStreamer !== false;
  const dateLabel = opts.dateLabel || " 更新";
  const dateField = opts.dateField || "updated";
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

    li.appendChild(createPlaylistThumbnail(item, {
      width: 120,
      height: 68,
      containerClass: "row-thumb",
      placeholderClass: "row-thumb-placeholder",
    }));

    const body = document.createElement("div");
    body.className = "discover-body";

    const a = document.createElement("a");
    a.className = "discover-title";
    a.href = playlistUrl(item);
    a.target = "_blank";
    a.rel = "noopener";
    a.textContent = item.title;
    attachRecentlyViewedTracking(a, "playlist", playlistRecentEntry(item));
    body.appendChild(a);

    const meta = document.createElement("div");
    meta.className = "discover-meta";
    if (showGame) {
      const gameLink = document.createElement("a");
      gameLink.className = "game-link";
      gameLink.href = gameUrl(item.game);
      gameLink.textContent = gameDisplayName(item.game);
      meta.appendChild(gameLink);
      meta.appendChild(document.createTextNode(" ／ "));
    }
    if (showStreamer) {
      const streamerLink = document.createElement("a");
      streamerLink.className = "streamer-link";
      streamerLink.href = streamerUrl(item.streamer);
      streamerLink.textContent = item.streamer;
      meta.appendChild(streamerLink);
      meta.appendChild(document.createTextNode(" ／ "));
    }
    const d = dateField === "added" ? item.addedDate : (item.updatedDate || item.addedDate);
    meta.appendChild(document.createTextNode(formatDate(d) + dateLabel));
    body.appendChild(meta);

    li.appendChild(body);
    list.appendChild(li);
  });
}

/**
 * ゲーム別・実況者別ページへのURLを組み立てる。
 * サイト内でゲーム別・実況者別ページへリンクする箇所は必ずこの2関数を経由させること。
 * 将来 /games/<slug>/ ・ /vtubers/<slug>/ のようなパス形式のURLに移行する場合、
 * この関数の実装だけを変更すれば全ページのリンクに反映される(呼び出し側の変更は不要)。
 * その場合は GAMES/STREAMERS にスラッグ用のフィールドを追加し、ホスティング側で
 * 該当パスへの静的ファイル出力(またはリライトルール)を用意すること。
 */
function gameUrl(gameName) {
  return "game.html?game=" + encodeURIComponent(gameName);
}
function streamerUrl(streamerName) {
  return "streamer.html?streamer=" + encodeURIComponent(streamerName);
}

function formatDate(dateStr) {
  if (!dateStr) return "";
  const d = new Date(dateStr + "T00:00:00");
  if (isNaN(d.getTime())) return dateStr;
  return d.getFullYear() + "/" + (d.getMonth() + 1) + "/" + d.getDate();
}

/** 文章中で使う「2026年9月7日」形式の日付表記(一覧・カードの表記は formatDate のまま変更しない)。 */
function formatDateJa(dateStr) {
  if (!dateStr) return "";
  const d = new Date(dateStr + "T00:00:00");
  if (isNaN(d.getTime())) return dateStr;
  return d.getFullYear() + "年" + (d.getMonth() + 1) + "月" + d.getDate() + "日";
}

/** 数値を3桁区切りにする(例: 13114 → "13,114")。 */
function formatNumberJa(n) {
  return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ",");
}

/**
 * 再生リスト1件分の <tr> を作成する。
 * opts.rank          : 数値を渡すとランキング番号列を表示
 * opts.showNewBadge  : trueでタイトル横に「NEW」バッジを表示
 */
function createRow(item, opts) {
  opts = opts || {};
  const genre = genreById[item.genre] || genreById.other;
  const tr = document.createElement("tr");
  tr.tabIndex = 0;
  tr.setAttribute("role", "button");
  tr.setAttribute("aria-label", item.title + " を開く");

  const cells = [];

  if (opts.rank) {
    const rankTd = document.createElement("td");
    rankTd.className = "rank-cell";
    rankTd.textContent = "#" + opts.rank;
    cells.push(rankTd);
  }

  const genreTd = document.createElement("td");
  genreTd.className = "col-genre";
  genreTd.setAttribute("data-label", "ジャンル");
  const badge = document.createElement("span");
  badge.className = "badge badge--" + genre.color;
  badge.textContent = genre.label;
  genreTd.appendChild(badge);
  cells.push(genreTd);

  const titleTd = document.createElement("td");
  titleTd.className = "title-cell";

  const titleRow = document.createElement("div");
  titleRow.className = "row-title-row";

  // 再生リストサムネイル(無ければVTuberアイコン、それも無ければ頭文字)。
  // PC表では表の列は増やさず、タイトルセル内に小さな16:9画像として表示する。
  // スマホのカード表示でもタイトル先頭の同サイズのサムネイルになる
  // (表示サイズ自体は style.css の .row-thumb 側で調整する)。
  // loading="lazy" によりブラウザが画面内に入るまで読み込みを遅らせるため、
  // 現在のページに描画した分だけが対象になる(全件を先読みすることはない)。
  titleRow.appendChild(createPlaylistThumbnail(item, {
    width: 120,
    height: 68,
    containerClass: "row-thumb",
    placeholderClass: "row-thumb-placeholder",
  }));

  const titleTextWrap = document.createElement("div");
  titleTextWrap.className = "row-title-text";
  const titleLink = document.createElement("span");
  titleLink.className = "title-link";
  titleLink.textContent = item.title;
  titleTextWrap.appendChild(titleLink);
  if (opts.showNewBadge) {
    const nb = document.createElement("span");
    nb.className = "new-badge";
    nb.textContent = "NEW";
    titleTextWrap.appendChild(nb);
  }
  if (item.note) {
    const note = document.createElement("div");
    note.className = "note-cell";
    note.textContent = item.note;
    titleTextWrap.appendChild(note);
  }
  titleRow.appendChild(titleTextWrap);

  titleTd.appendChild(titleRow);
  cells.push(titleTd);

  const gameTd = document.createElement("td");
  gameTd.className = "col-game";
  gameTd.setAttribute("data-label", "ゲーム");
  const gameLink = document.createElement("a");
  gameLink.className = "game-link";
  gameLink.href = gameUrl(item.game);
  gameLink.textContent = gameDisplayName(item.game);
  gameTd.appendChild(gameLink);
  cells.push(gameTd);

  if (opts.showAgency) {
    const agency = agencyOf(item.streamer);
    const agencyTd = document.createElement("td");
    agencyTd.className = "col-agency";
    agencyTd.setAttribute("data-label", "事務所");
    const agencyLink = document.createElement("a");
    agencyLink.className = "agency-link";
    agencyLink.href = "streamers.html?agency=" + encodeURIComponent(agency);
    agencyLink.textContent = agency;
    agencyTd.appendChild(agencyLink);
    cells.push(agencyTd);
  }

  if (opts.showStreamer !== false) {
    const streamerTd = document.createElement("td");
    streamerTd.className = "col-streamer";
    streamerTd.setAttribute("data-label", "VTuber");
    const streamerLink = document.createElement("a");
    streamerLink.className = "streamer-link";
    streamerLink.href = streamerUrl(item.streamer);
    streamerLink.textContent = item.streamer;
    streamerTd.appendChild(streamerLink);
    cells.push(streamerTd);
  }

  const countTd = document.createElement("td");
  countTd.className = "col-count";
  countTd.setAttribute("data-label", "動画数");
  countTd.textContent = item.videoCount ? item.videoCount + "本" : "-";
  cells.push(countTd);

  const dateTd = document.createElement("td");
  dateTd.className = "col-date";
  dateTd.setAttribute("data-label", "更新日");
  const updateDate = item.updatedDate || item.addedDate;
  dateTd.textContent = updateDate ? formatDate(updateDate) : "-";
  cells.push(dateTd);

  cells.forEach((td) => tr.appendChild(td));

  const open = () => {
    recordRecentlyViewed("playlist", playlistRecentEntry(item));
    window.open(playlistUrl(item), "_blank", "noopener");
  };
  tr.addEventListener("click", (e) => {
    if (e.target.closest("a")) return;
    open();
  });
  tr.addEventListener("keydown", (e) => {
    if (e.target.closest("a")) return;
    if (e.key === "Enter" || e.key === " ") {
      e.preventDefault();
      open();
    }
  });

  return tr;
}

/**
 * items を <tbody> にテーブル行として描画する。
 * container が空になる場合は emptyMessage を表示する。
 * rowOpts は固定オブジェクト、または (item, index) => opts の関数を渡せる。
 */
function renderTable(tbody, items, emptyMessage, rowOpts) {
  if (!tbody) return;
  tbody.innerHTML = "";

  if (!items.length) {
    const tr = document.createElement("tr");
    const td = document.createElement("td");
    td.colSpan = 8;
    const empty = document.createElement("div");
    empty.className = "empty-state";
    empty.textContent = emptyMessage || "該当する再生リストが見つかりませんでした。";
    td.appendChild(empty);
    tr.appendChild(td);
    tbody.appendChild(tr);
    return;
  }

  // ページ内の行(最大100件、initPaginationのページサイズ上限)をまとめて
  // 1回だけtbodyに挿入する(1件ずつappendChildすると、その都度レイアウトの
  // 再計算対象になり得るため)。
  const fragment = document.createDocumentFragment();
  items.forEach((item, i) => {
    const opts = typeof rowOpts === "function" ? rowOpts(item, i) : rowOpts;
    fragment.appendChild(createRow(item, opts));
  });
  tbody.appendChild(fragment);
}

/**
 * 表示件数セレクト(#pagesize-select)・前へ/次へボタン(#page-prev/#page-next)・
 * ページ表示(#page-indicator)を使ったページネーションを初期化する。
 * これらの要素が無いページでは何もせず、渡された items をそのまま1ページとして描画する。
 *
 * renderPage(pageItems): そのページ分の items を描画するコールバック。
 * defaultPageSize: 初期表示件数(省略時20)。
 * 戻り値: setItems(items) — 一覧の中身(検索条件やソート順が変わった時)を渡して
 *         1ページ目から描画し直す関数。
 */
function initPagination(renderPage, defaultPageSize) {
  const pagesizeSelect = document.getElementById("pagesize-select");
  const pagePrev = document.getElementById("page-prev");
  const pageNext = document.getElementById("page-next");
  const pageIndicator = document.getElementById("page-indicator");
  const pageJumpForm = document.getElementById("page-jump-form");
  const pageJumpInput = document.getElementById("page-jump-input");

  if (pagesizeSelect) pagesizeSelect.value = String(defaultPageSize || 20);

  let items = [];
  let currentPage = 1;
  let totalPages = 1;

  function pageSize() {
    const raw = pagesizeSelect ? parseInt(pagesizeSelect.value, 10) : defaultPageSize || 20;
    return raw > 0 ? raw : (defaultPageSize || 20);
  }

  function render() {
    const size = pageSize();
    totalPages = Math.max(1, Math.ceil(items.length / size));
    if (currentPage > totalPages) currentPage = totalPages;
    if (currentPage < 1) currentPage = 1;
    const start = (currentPage - 1) * size;
    renderPage(items.slice(start, start + size));
    if (pageIndicator) pageIndicator.textContent = currentPage + " / " + totalPages + " ページ";
    if (pagePrev) pagePrev.disabled = currentPage <= 1;
    if (pageNext) pageNext.disabled = currentPage >= totalPages;
    if (pageJumpInput) {
      pageJumpInput.max = String(totalPages);
      pageJumpInput.placeholder = String(currentPage);
    }
  }

  if (pagesizeSelect) pagesizeSelect.addEventListener("change", () => { currentPage = 1; render(); });
  if (pagePrev) pagePrev.addEventListener("click", () => { currentPage -= 1; render(); });
  if (pageNext) pageNext.addEventListener("click", () => { currentPage += 1; render(); });
  if (pageJumpForm) {
    pageJumpForm.addEventListener("submit", (e) => {
      e.preventDefault();
      const page = parseInt(pageJumpInput.value, 10);
      if (!page) return;
      currentPage = Math.min(Math.max(page, 1), totalPages);
      render();
      pageJumpInput.value = "";
    });
  }

  return function setItems(newItems) {
    items = newItems;
    currentPage = 1;
    render();
  };
}

/**
 * items を sortKey(genre/title/game/agency/streamer/videoCount/updatedDate)で
 * 並び替える。sortKey が null、または dir が 0(偽値)の場合は並び替えを行わず
 * items をそのまま返す(未ソート = 元の順序)。dir は 1 なら昇順、-1 なら降順。
 */
function sortByColumn(items, sortKey, dir) {
  if (!sortKey || !dir) return items;
  function value(item) {
    if (sortKey === "genre") return (genreById[item.genre] || genreById.other).label;
    if (sortKey === "videoCount") return item.videoCount || 0;
    if (sortKey === "updatedDate") return item.updatedDate || item.addedDate || "";
    if (sortKey === "agency") return agencyOf(item.streamer);
    return item[sortKey] || "";
  }
  return items.slice().sort((a, b) => {
    const va = value(a);
    const vb = value(b);
    if (typeof va === "number" && typeof vb === "number") return (va - vb) * dir;
    return String(va).localeCompare(String(vb), "ja") * dir;
  });
}

/**
 * テーブル見出し(data-sort 属性付きの <th class="sortable">、複数可)を
 * クリックで 未ソート → 昇順(▲) → 降順(▼) → 未ソート と切り替えられるようにする。
 * 別の見出しをクリックすると、その列の昇順から始まる(切り替え中の見出しの矢印は消える)。
 * クリックのたびに render(sortKey, dir) を呼び出す。見出しが無いページでは
 * render(defaultKey, defaultDir) を1回呼ぶだけのno-opトリガーを返す。
 * defaultKey/defaultDir: 初期表示時のソート列と方向(省略時は未ソート)。
 * 戻り値: 現在の並び替え状態で render を呼び出すトリガー関数(初回描画にも使う)。
 */
function initColumnSort(render, defaultKey, defaultDir) {
  let sortKey = defaultKey || null;
  let dir = defaultDir || 0;
  const sortableHeaders = document.querySelectorAll(".wiki-table th.sortable[data-sort]");
  if (!sortableHeaders.length) return () => render(sortKey, dir);

  function updateIndicators() {
    sortableHeaders.forEach((th) => {
      const arrow = th.querySelector(".sort-arrow");
      if (!arrow) return;
      arrow.textContent = th.dataset.sort === sortKey ? (dir === 1 ? "▲" : dir === -1 ? "▼" : "") : "";
    });
  }
  updateIndicators();

  sortableHeaders.forEach((th) => {
    th.addEventListener("click", () => {
      const key = th.dataset.sort;
      if (sortKey === key) {
        dir = dir === 1 ? -1 : dir === -1 ? 0 : 1;
        if (dir === 0) sortKey = null;
      } else {
        sortKey = key;
        dir = 1;
      }
      updateIndicators();
      render(sortKey, dir);
    });
  });

  return () => render(sortKey, dir);
}

/**
 * サイドバー「人気コンテンツ」の上位5ゲームを data-counts.js の
 * PLAYLIST_COUNTS_BY_GAME(件数索引)から描画する。全ページで軽量に動くよう、
 * 数MBある data-playlists.js には依存しない(未読み込みのページでは何も表示しない)。
 */
function initSidebarPopular() {
  const list = document.getElementById("sidebar-popular-games");
  if (!list) return;

  const counts = typeof PLAYLIST_COUNTS_BY_GAME === "undefined" ? {} : PLAYLIST_COUNTS_BY_GAME;
  const topNames = Object.keys(counts)
    .sort((a, b) => counts[b] - counts[a])
    .slice(0, 5);

  list.innerHTML = "";
  if (!topNames.length) {
    const li = document.createElement("li");
    li.className = "sidebar-popular-empty";
    li.textContent = "データがまだありません。";
    list.appendChild(li);
    return;
  }

  topNames.forEach((name, i) => {
    const li = document.createElement("li");

    const rank = document.createElement("span");
    rank.className = "rank";
    rank.textContent = "#" + (i + 1);
    li.appendChild(rank);

    const a = document.createElement("a");
    a.href = gameUrl(name);
    a.textContent = gameDisplayName(name);
    a.title = gameDisplayName(name);
    li.appendChild(a);

    list.appendChild(li);
  });
}

/**
 * サイドバー「ランダムで実況を探す」ボタン。data-counts.js の件数索引から
 * 実際に再生リストのあるゲーム/実況者をランダムに1件選び、その詳細ページへ移動する。
 */
function initSidebarRandom() {
  const btn = document.getElementById("sidebar-random-btn");
  if (!btn) return;

  btn.addEventListener("click", () => {
    const gameCounts = typeof PLAYLIST_COUNTS_BY_GAME === "undefined" ? {} : PLAYLIST_COUNTS_BY_GAME;
    const streamerCounts = typeof PLAYLIST_COUNTS_BY_STREAMER === "undefined" ? {} : PLAYLIST_COUNTS_BY_STREAMER;
    const gameKeys = Object.keys(gameCounts);
    const streamerKeys = Object.keys(streamerCounts);
    if (!gameKeys.length && !streamerKeys.length) return;

    const pickGame = streamerKeys.length ? (gameKeys.length ? Math.random() < 0.5 : false) : true;
    if (pickGame) {
      window.location.href = gameUrl(gameKeys[Math.floor(Math.random() * gameKeys.length)]);
    } else {
      window.location.href = streamerUrl(streamerKeys[Math.floor(Math.random() * streamerKeys.length)]);
    }
  });
}

/**
 * スマートフォン表示でのサイドバー開閉(ハンバーガーメニュー)。
 * PC(720px超)ではCSS側でボタンを非表示にし、サイドバーは常時表示のまま。
 */
function initMobileMenu() {
  const toggle = document.getElementById("mobile-menu-toggle");
  const sidebar = document.getElementById("wiki-sidebar");
  if (!toggle || !sidebar) return;

  toggle.addEventListener("click", () => {
    const isOpen = sidebar.classList.toggle("is-open");
    toggle.setAttribute("aria-expanded", String(isOpen));
    toggle.innerHTML = isOpen
      ? '<span aria-hidden="true">✕</span> 閉じる'
      : '<span aria-hidden="true">☰</span> メニュー';
  });
}

/**
 * サイドバー検索フォームの送信ハンドラ。
 * playlists.html にキーワード付きで遷移する。
 */
function wikiSearchSubmit(form) {
  const q = form.q.value.trim();
  if (q) addRecentSearch(q);
  window.location.href = "search.html" + (q ? "?q=" + encodeURIComponent(q) : "");
  return false;
}

/**
 * ============================================================
 * 検索サジェスト(入力候補)
 * ============================================================
 * サイドバー検索・トップページのメイン検索・サイト内検索ページの入力欄に、
 * 入力中の文字列に応じてゲーム/VTuber/再生リストの候補をリアルタイム表示する。
 * 候補をクリックすると該当ページ(ゲーム別/実況者別ページ、または再生リストは
 * YouTube)へ直接移動する。既存の「Enterで送信 → search.htmlへ遷移」という
 * 横断検索の動作(wikiSearchSubmit / search.js の submit ハンドラ)はそのまま維持し、
 * 候補を選ばず送信した場合は従来通り動作する。
 */
const SEARCH_SUGGEST_TYPE_LABELS = { game: "ゲーム", streamer: "VTuber", playlist: "再生リスト", recent: "履歴" };

let _searchSuggestPlaylistIndexCache = null;
/** PLAYLISTS の title を正規化した索引を(初回利用時に)作って使い回す。件数が多いため。 */
function searchSuggestPlaylistIndex() {
  if (!_searchSuggestPlaylistIndexCache) {
    _searchSuggestPlaylistIndexCache = getAllPlaylists().map((p) => ({
      p: p,
      normTitle: normalizeSearchText(p.title),
    }));
  }
  return _searchSuggestPlaylistIndexCache;
}

/**
 * rawQuery に一致するゲーム/VTuber/再生リストの候補を、種類ごとの偏りを抑えつつ
 * スコア順(完全一致 > 前方一致 > 部分一致)に最大 limit 件返す。
 */
function buildSearchSuggestions(rawQuery, limit) {
  const raw = String(rawQuery == null ? "" : rawQuery).trim();
  if (!raw) return [];
  const q = normalizeSearchText(raw);
  if (!q) return [];

  const results = [];

  GAMES.forEach((g) => {
    const nameNorm = normalizeSearchText(g.name);
    const score = nameNorm === q ? 100
      : nameNorm.startsWith(q) ? 90
      : gameSearchText(g.name).includes(q) ? 70
      : 0;
    if (!score) return;
    results.push({ type: "game", label: gameDisplayName(g.name), sub: g.series || "", score: score, key: g.name });
  });

  STREAMERS.forEach((s) => {
    const hay = normalizeSearchText([s.name, s.kana, s.aliases && s.aliases.join(" ")].filter(Boolean).join(" "));
    if (!hay.includes(q)) return;
    const nameNorm = normalizeSearchText(s.name);
    const score = nameNorm === q ? 100 : nameNorm.startsWith(q) ? 90 : 70;
    results.push({ type: "streamer", label: s.name, sub: s.group || "", score: score, key: s.name });
  });

  searchSuggestPlaylistIndex().forEach((entry) => {
    if (!entry.normTitle.includes(q)) return;
    const score = entry.normTitle === q ? 100 : entry.normTitle.startsWith(q) ? 90 : 60;
    results.push({
      type: "playlist",
      label: entry.p.title,
      sub: entry.p.streamer + " ／ " + gameDisplayName(entry.p.game),
      score: score,
      playlist: entry.p,
    });
  });

  results.sort((a, b) => b.score - a.score);

  const perTypeCap = { game: 5, streamer: 5, playlist: 5 };
  const counts = { game: 0, streamer: 0, playlist: 0 };
  const picked = [];
  for (let i = 0; i < results.length && picked.length < limit; i++) {
    const r = results[i];
    if (counts[r.type] >= perTypeCap[r.type]) continue;
    counts[r.type] += 1;
    picked.push(r);
  }
  return picked;
}

function searchSuggestGoTo(item) {
  if (item.type === "game") {
    window.location.href = gameUrl(item.key);
  } else if (item.type === "streamer") {
    window.location.href = streamerUrl(item.key);
  } else if (item.type === "playlist") {
    window.open(playlistUrl(item.playlist), "_blank", "noopener");
  } else if (item.type === "recent") {
    addRecentSearch(item.key);
    window.location.href = "search.html?q=" + encodeURIComponent(item.key);
  }
}

/**
 * input(検索ボックス)1つ分のサジェスト機能を組み立てる。
 * ドロップダウンは document.body 直下に position:fixed で配置し、サイドバーの
 * overflow(スクロール領域)に切り取られないようにする。
 */
function attachSearchSuggest(input) {
  const list = document.createElement("ul");
  list.className = "search-suggest-list";
  list.setAttribute("role", "listbox");
  list.hidden = true;
  document.body.appendChild(list);

  let currentItems = [];
  let activeIndex = -1;
  let debounceTimer = null;

  function positionList() {
    const rect = input.getBoundingClientRect();
    list.style.left = rect.left + "px";
    list.style.top = rect.bottom + 4 + "px";
    list.style.width = rect.width + "px";
  }

  function closeList() {
    list.hidden = true;
    list.innerHTML = "";
    currentItems = [];
    activeIndex = -1;
  }

  function updateActive() {
    Array.from(list.children).forEach((li, i) => {
      li.classList.toggle("active", i === activeIndex);
    });
  }

  function showList(items, opts) {
    currentItems = items;
    activeIndex = -1;
    list.innerHTML = "";

    if (!items.length) {
      closeList();
      return;
    }

    items.forEach((item) => {
      const li = document.createElement("li");
      li.className = "search-suggest-item";
      li.setAttribute("role", "option");

      const badge = document.createElement("span");
      badge.className = "search-suggest-badge search-suggest-badge--" + item.type;
      badge.textContent = SEARCH_SUGGEST_TYPE_LABELS[item.type];
      li.appendChild(badge);

      const textWrap = document.createElement("span");
      textWrap.className = "search-suggest-text";

      const main = document.createElement("span");
      main.className = "search-suggest-main";
      main.textContent = item.label;
      textWrap.appendChild(main);

      if (item.sub) {
        const sub = document.createElement("span");
        sub.className = "search-suggest-sub";
        sub.textContent = item.sub;
        textWrap.appendChild(sub);
      }
      li.appendChild(textWrap);

      li.addEventListener("mousedown", (e) => {
        e.preventDefault();
        if (item.type !== "recent" && input.value.trim()) addRecentSearch(input.value);
        searchSuggestGoTo(item);
        closeList();
      });

      list.appendChild(li);
    });

    if (opts && opts.onClear) {
      const footer = document.createElement("li");
      footer.className = "search-suggest-item search-suggest-item--footer";
      footer.setAttribute("role", "none");
      const clearBtn = document.createElement("button");
      clearBtn.type = "button";
      clearBtn.className = "search-suggest-clear";
      clearBtn.textContent = "検索履歴を削除";
      clearBtn.addEventListener("mousedown", (e) => {
        e.preventDefault();
        opts.onClear();
        closeList();
      });
      footer.appendChild(clearBtn);
      list.appendChild(footer);
    }

    positionList();
    list.hidden = false;
  }

  function showRecentSearches() {
    const recent = getRecentSearches();
    if (!recent.length) {
      closeList();
      return;
    }
    showList(recent.map((term) => ({ type: "recent", label: term, key: term })), {
      onClear: () => { clearRecentSearches(); },
    });
  }

  // 再生リストを遅延読み込みするページ(トップページ)では、検索欄を操作した時点で
  // data-playlists.js を読み込む。読み込みまでの間もゲーム/VTuberの候補は表示し、
  // 読み込みが済んだら(まだ入力中であれば)再生リストを含めた候補に出し直す。
  function ensurePlaylistsForSuggest() {
    if (typeof PLAYLISTS !== "undefined" || !isLazyPlaylistsPage()) return;
    loadPlaylistsData().then(() => {
      if (document.activeElement === input && input.value.trim()) {
        showList(buildSearchSuggestions(input.value, 8));
      }
    }).catch(() => { /* 読み込めない場合はゲーム/VTuberの候補のみ(従来の他ページと同じ) */ });
  }

  input.addEventListener("input", () => {
    ensurePlaylistsForSuggest();
    clearTimeout(debounceTimer);
    const value = input.value;
    debounceTimer = setTimeout(() => {
      if (value.trim()) {
        showList(buildSearchSuggestions(value, 8));
      } else {
        showRecentSearches();
      }
    }, 120);
  });

  input.addEventListener("focus", () => {
    ensurePlaylistsForSuggest();
    if (input.value.trim()) {
      showList(buildSearchSuggestions(input.value, 8));
    } else {
      showRecentSearches();
    }
  });

  input.addEventListener("keydown", (e) => {
    if (list.hidden || !currentItems.length) return;
    if (e.key === "ArrowDown") {
      e.preventDefault();
      activeIndex = Math.min(activeIndex + 1, currentItems.length - 1);
      updateActive();
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      activeIndex = Math.max(activeIndex - 1, 0);
      updateActive();
    } else if (e.key === "Enter") {
      if (activeIndex >= 0) {
        e.preventDefault();
        const item = currentItems[activeIndex];
        if (item.type !== "recent" && input.value.trim()) addRecentSearch(input.value);
        searchSuggestGoTo(item);
        closeList();
      }
    } else if (e.key === "Escape") {
      closeList();
    }
  });

  input.addEventListener("blur", () => {
    setTimeout(closeList, 100);
  });

  window.addEventListener("scroll", closeList, { passive: true, capture: true });
  window.addEventListener("resize", closeList);
}

/**
 * サイドバー検索・トップページのメイン検索・サイト内検索ページの入力欄に
 * 検索サジェストを組み込む。対象が無いページでは何もしない。
 */
function initSearchSuggest() {
  if (typeof GAMES === "undefined" || typeof STREAMERS === "undefined") return;
  const inputs = document.querySelectorAll(
    '.menu-search input[type="search"], .hero-search input[type="search"], #search-form #q'
  );
  inputs.forEach(attachSearchSuggest);
}

document.addEventListener("DOMContentLoaded", () => {
  initSidebarPopular();
  initSidebarRandom();
  initMobileMenu();
  initSearchSuggest();
});
