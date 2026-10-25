(function () {
  const rowParam = getQueryParam("row") || "";
  const rowGroup = KANA_ROW_GROUPS.find((r) => r.row === rowParam);

  document.getElementById("page-title").textContent = rowGroup
    ? rowGroup.row + "行のゲーム一覧"
    : "行が指定されていません";
  document.getElementById("breadcrumb-current").textContent = rowGroup
    ? rowGroup.row + "行"
    : "不明な行";

  const container = document.getElementById("category-list");
  container.innerHTML = "";

  const nav = document.createElement("div");
  nav.className = "kana-nav";
  KANA_ROW_GROUPS.forEach((r) => {
    const a = document.createElement("a");
    a.href = "games-row.html?row=" + encodeURIComponent(r.row);
    a.textContent = r.row;
    if (rowGroup && r.row === rowGroup.row) a.classList.add("active");
    nav.appendChild(a);
  });
  container.appendChild(nav);

  // 行が無い・不正な行のページは中身の無い案内だけなので、検索結果には出さない(リンクは辿れる)
  if (!rowGroup) {
    let robotsMeta = document.querySelector('meta[name="robots"]');
    if (!robotsMeta) {
      robotsMeta = document.createElement("meta");
      robotsMeta.setAttribute("name", "robots");
      document.head.appendChild(robotsMeta);
    }
    robotsMeta.setAttribute("content", "noindex,follow");
    return;
  }

  const groups = groupGamesByKana().filter((g) => rowGroup.members.indexOf(g.row) !== -1);
  const totalGames = groups.reduce((sum, g) => sum + g.names.length, 0);

  setPageMeta(
    rowGroup.row + "行のゲーム一覧 | " + SITE_NAME,
    "VTuberが実況したゲームのうち、「" + rowGroup.row + "行」で始まるタイトルの一覧です。全" + totalGames + "件のゲームからVTuberの実況・再生リストを探せます。",
    "/games-row.html?row=" + encodeURIComponent(rowGroup.row)
  );

  const subNav = document.createElement("div");
  subNav.className = "kana-nav kana-subnav";
  groups.forEach((group) => {
    const a = document.createElement("a");
    a.href = "#kana-" + group.row;
    a.textContent = group.row;
    subNav.appendChild(a);
  });
  container.appendChild(subNav);

  if (!groups.length) {
    const empty = document.createElement("div");
    empty.className = "empty-state";
    empty.textContent = "この行に該当するゲームはまだ登録されていません。";
    container.appendChild(empty);
    return;
  }

  // 行のゲームを1列に並べ、24件ずつページ分けする(そのページの分だけ描画する)。
  // ページ番号は URL の ?page= に残し、戻る・進むで復元する
  const PAGE_SIZE = 24;
  const entries = [];
  const firstIndexOfGroup = {};
  groups.forEach((group) => {
    firstIndexOfGroup[group.row] = entries.length;
    group.names.forEach((name, i) => entries.push({ group: group.row, name: name, continued: i > 0 }));
  });

  const listEl = document.createElement("div");
  container.appendChild(listEl);

  // そのページの分を、かな(小見出し)ごとにまとめて描画する。前のページから続くかなは「(続き)」を付ける
  const setItems = initPagination((pageItems) => {
    listEl.innerHTML = "";
    let section = null, ul = null, current = null;
    pageItems.forEach((entry, i) => {
      if (entry.group !== current) {
        current = entry.group;
        section = document.createElement("div");
        section.className = "section-box";
        const startsHere = !(i === 0 && entry.continued);
        if (startsHere) section.id = "kana-" + entry.group;
        const h2 = document.createElement("h2");
        h2.textContent = entry.group + (startsHere ? "" : "(続き)");
        section.appendChild(h2);
        ul = document.createElement("ul");
        ul.className = "index-list";
        section.appendChild(ul);
        listEl.appendChild(section);
      }
      ul.appendChild(createCountIndexItem(gameUrl(entry.name), gameDisplayName(entry.name), listingCountOfGame(entry.name)));
    });
  }, PAGE_SIZE, { pageNumbers: document.getElementById("page-numbers"), urlParam: "page", scrollTarget: subNav });

  // 小見出しのリンク: そのかなの先頭があるページへ移ってから、その見出しへスクロールする
  subNav.querySelectorAll("a").forEach((a) => {
    a.addEventListener("click", (e) => {
      e.preventDefault();
      const row = a.getAttribute("href").slice("#kana-".length);
      setItems.goTo(setItems.pageOf(firstIndexOfGroup[row]));
      const target = document.getElementById("kana-" + row);
      if (target) target.scrollIntoView({ block: "start" });
    });
  });

  // 初期表示: URL の ?page=、無ければ #kana-◯ のかながあるページ
  const hashRow = decodeURIComponent((window.location.hash || "").replace(/^#kana-/, ""));
  const initialPage = getQueryParam("page") ? readPageFromUrl("page")
    : (hashRow && firstIndexOfGroup[hashRow] != null ? setItems.pageOf(firstIndexOfGroup[hashRow]) : 1);
  document.getElementById("pagination").hidden = entries.length <= PAGE_SIZE;
  setItems(entries, { page: initialPage });
  if (hashRow && !getQueryParam("page")) {
    const target = document.getElementById("kana-" + hashRow);
    if (target) target.scrollIntoView({ block: "start" });
  }
  window.addEventListener("popstate", () => setItems.showPage(readPageFromUrl("page")));
})();
