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

  groups.forEach((group) => {
    const section = document.createElement("div");
    section.className = "section-box";
    section.id = "kana-" + group.row;

    const h2 = document.createElement("h2");
    h2.textContent = group.row;
    section.appendChild(h2);

    const ul = document.createElement("ul");
    ul.className = "index-list";
    group.names.forEach((name) => {
      const count = PLAYLIST_COUNTS_BY_GAME[name] || 0;
      ul.appendChild(createCountIndexItem(gameUrl(name), gameDisplayName(name), count));
    });
    section.appendChild(ul);

    container.appendChild(section);
  });
})();
