(function () {
  const container = document.getElementById("category-list");
  const ul = document.createElement("ul");
  ul.className = "index-list";
  renderGameRowIndex(ul);
  container.innerHTML = "";
  container.appendChild(ul);
})();
