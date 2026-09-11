(function () {
  const container = document.getElementById("category-list");
  container.innerHTML = "";

  const agencies = [];
  const byAgency = {};
  STREAMERS.forEach((s) => {
    const agency = (s.group || "その他").split(" ")[0];
    if (!byAgency[agency]) {
      byAgency[agency] = [];
      agencies.push(agency);
    }
    byAgency[agency].push(s);
  });

  const nav = document.createElement("div");
  nav.className = "kana-nav";
  container.appendChild(nav);

  const boxByAgency = {};

  agencies.forEach((agency) => {
    const box = document.createElement("div");
    box.className = "agency-box";

    const headerRow = document.createElement("div");
    headerRow.className = "menu-row agency-header-row";

    const label = document.createElement("span");
    label.className = "agency-header-label";
    label.textContent = agency;
    headerRow.appendChild(label);

    box.appendChild(headerRow);

    const body = document.createElement("div");
    body.className = "agency-body";

    const units = [];
    const byUnit = {};
    byAgency[agency].forEach((s) => {
      const unit = s.group || "その他";
      if (!byUnit[unit]) {
        byUnit[unit] = [];
        units.push(unit);
      }
      byUnit[unit].push(s);
    });

    units.forEach((unit) => {
      const section = document.createElement("div");
      section.className = "section-box";

      const label = unitLabelOf(unit);
      if (label) {
        const h2 = document.createElement("h2");
        h2.textContent = label;
        section.appendChild(h2);
      }

      const ul = document.createElement("ul");
      ul.className = "streamer-grid";
      byUnit[unit].forEach((s) => {
        const count = PLAYLIST_COUNTS_BY_STREAMER[s.name] || 0;
        ul.appendChild(createStreamerCard(s.name, count));
      });
      section.appendChild(ul);

      body.appendChild(section);
    });

    box.appendChild(body);
    container.appendChild(box);
    boxByAgency[agency] = box;

    const navBtn = document.createElement("button");
    navBtn.type = "button";
    navBtn.textContent = agency;
    navBtn.addEventListener("click", () => {
      box.scrollIntoView({ behavior: "smooth", block: "start" });
    });
    nav.appendChild(navBtn);
  });

  const targetAgency = getQueryParam("agency");
  if (targetAgency && boxByAgency[targetAgency]) {
    requestAnimationFrame(() => {
      boxByAgency[targetAgency].scrollIntoView({ block: "start" });
    });
  }
})();
