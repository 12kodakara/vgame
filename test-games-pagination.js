/**
 * ゲーム一覧(games-row.html)・ゲーム名検索(games.html)の24件ずつのページ分けの回帰テスト。ブラウザ不要(node test-games-pagination.js)。
 *
 * games-row.js / games.js を最小限の DOM の上で実際に動かし、次を確かめる。
 *   1. ページ分けの計算(pageRange・pageNumberItems)
 *   2. ゲーム一覧: 初期表示24件・2ページ目以降と最終ページの中身・前へ/次へ/ページ番号・URL の ?page=・戻る/進む・
 *      URL からの復元・かなの小見出しリンク(そのかなの先頭があるページへ移る)・前のページから続くかなの「(続き)」
 *   3. ゲーム名検索: 24件ずつ・並び順(関連度順/件数順)の維持・条件を変えたら1ページ目・URL の q/sort/page からの復元・戻る/進む
 *   4. 既存のページ切り替え(引数2つの呼び出し)は URL を変えない
 *   5. 単発実況の一覧(singles.html): 24件ずつ・全件を重複・欠落なく・URL と戻る・検索で1ページ目・遅延読み込み
 * 失敗が1件でもあれば終了コード1。
 */
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const ROOT = __dirname;
const read = (f) => fs.readFileSync(path.join(ROOT, f), 'utf8');
let pass = 0, fail = 0;
function check(name, ok, detail) {
  if (ok) { pass++; console.log('  [PASS] ' + name); } else { fail++; console.log('  [FAIL] ' + name + (detail ? '\n         ' + String(detail).slice(0, 400) : '')); }
}
console.log('=== ゲーム一覧・ゲーム名検索 24件ページ分け 回帰テスト ===');

// ---- 最小限の DOM(test-streamer-games.js と同じもの) ----
class El {
  constructor(tag, doc) { this.tagName = String(tag).toUpperCase(); this.children = []; this.attrs = {}; this.listeners = {}; this.parent = null; this.hidden = false; this.open = false; this._text = ''; this.style = {}; this.dataset = {}; this.doc = doc;
    const cls = new Set(); this.classList = { add: (...c) => c.forEach((x) => cls.add(x)), remove: (...c) => c.forEach((x) => cls.delete(x)), toggle: (c, f) => { const on = f === undefined ? !cls.has(c) : f; if (on) cls.add(c); else cls.delete(c); return on; }, contains: (c) => cls.has(c) }; }
  get className() { return this.attrs.class || ''; } set className(v) { this.attrs.class = String(v); }
  get id() { return this.attrs.id || ''; } set id(v) { this.attrs.id = v; }
  get textContent() { return this._text + this.children.map((c) => c.textContent).join(''); } set textContent(v) { this._text = String(v); this.children = []; }
  get innerText() { return this.textContent; }
  set innerHTML(v) { if (v === '') { this.children = []; this._text = ''; } }
  get innerHTML() { return ''; }
  get href() { return this.attrs.href || ''; } set href(v) { this.attrs.href = String(v); }
  get firstChild() { return this.children[0] || null; }
  appendChild(c) { if (c && c.parent) c.remove(); if (c) { c.parent = this; this.children.push(c); } return c; }
  append(...cs) { cs.forEach((c) => this.appendChild(typeof c === 'string' ? Object.assign(new El('#text', this.doc), { _text: c }) : c)); }
  prepend(c) { c.parent = this; this.children.unshift(c); }
  insertBefore(c, ref) { const i = this.children.indexOf(ref); c.parent = this; if (i < 0) this.children.push(c); else this.children.splice(i, 0, c); return c; }
  replaceChildren(...cs) { this.children = []; this.append(...cs); }
  remove() { if (this.parent) this.parent.children = this.parent.children.filter((x) => x !== this); this.parent = null; }
  setAttribute(k, v) { this.attrs[k] = String(v); } getAttribute(k) { return k in this.attrs ? this.attrs[k] : null; } removeAttribute(k) { delete this.attrs[k]; } hasAttribute(k) { return k in this.attrs; }
  addEventListener(t, f) { (this.listeners[t] = this.listeners[t] || []).push(f); } removeEventListener() {}
  all() { const out = []; const walk = (e) => { for (const c of e.children) { out.push(c); walk(c); } }; walk(this); return out; }
  querySelectorAll(sel) { const tag = /^[a-z]+$/i.test(sel) ? sel.toUpperCase() : null; return tag ? this.all().filter((e) => e.tagName === tag) : []; }
  querySelector(sel) { return this.querySelectorAll(sel)[0] || null; }
  closest() { return null; } matches() { return false; } contains() { return false; }
  getBoundingClientRect() { return { top: 0, left: 0, width: 0, height: 0, bottom: 0, right: 0 }; } getClientRects() { return []; }
  focus() {} blur() {} scrollIntoView() { this.scrolled = (this.scrolled || 0) + 1; } click() { (this.listeners.click || []).forEach((f) => f({ preventDefault() {}, target: this })); }
  cloneNode() { return new El(this.tagName, this.doc); }
}
function makeDocument(html) {
  const doc = { byId: {}, title: '', listeners: {} };
  doc.createElement = (t) => new El(t, doc);
  doc.createTextNode = (t) => Object.assign(new El('#text', doc), { _text: String(t) });
  doc.createDocumentFragment = () => new El('#fragment', doc);
  doc.head = new El('head', doc); doc.body = new El('body', doc); doc.documentElement = new El('html', doc);
  doc.body.classList.contains = () => false;
  for (const m of html.matchAll(/<([a-z0-9]+)([^>]*)\sid="([^"]+)"([^>]*)>/g)) {
    const e = new El(m[1], doc); e.id = m[3]; const attrs = m[2] + m[4];
    e.hidden = /\shidden(\s|$|>)/.test(attrs + ' '); const cls = /class="([^"]*)"/.exec(attrs); if (cls) e.className = cls[1];
    doc.byId[m[3]] = e;
  }
  doc.getElementById = (id) => doc.byId[id] || null;
  doc.querySelector = (sel) => (/^#[\w-]+$/.test(sel) ? doc.getElementById(sel.slice(1)) : null);
  doc.querySelectorAll = () => [];
  doc.addEventListener = (t, f) => { (doc.listeners[t] = doc.listeners[t] || []).push(f); };
  doc.readyState = 'complete';
  doc.activeElement = null;
  return doc;
}

// ---- ページを動かす(URL・履歴・戻る/進むも最小限で再現する) ----
function openPage(html, script, href, extraData) {
  const doc = makeDocument(html ? read(html) : '');
  const storage = { getItem: () => null, setItem: () => {}, removeItem: () => {} };
  const timers = [], listeners = {};
  const stack = [href]; let pos = 0;
  const loc = {};
  const setLoc = (h) => { const u = new URL(h); loc.href = u.href; loc.search = u.search; loc.hash = u.hash; loc.pathname = u.pathname; };
  setLoc(href);
  const history = {
    pushState(_s, _t, url) { stack.splice(pos + 1); stack.push(new URL(url, loc.href).href); pos = stack.length - 1; setLoc(stack[pos]); },
    replaceState(_s, _t, url) { stack[pos] = new URL(url, loc.href).href; setLoc(stack[pos]); },
  };
  const ctx = {
    console, document: doc, localStorage: storage, sessionStorage: storage, navigator: { userAgent: 'node' }, URLSearchParams, URL, encodeURIComponent, decodeURIComponent,
    location: loc, history, setTimeout: (f) => { timers.push(f); return timers.length; }, clearTimeout() {}, requestAnimationFrame: () => 0,
    matchMedia: () => ({ matches: false, addEventListener() {} }), IntersectionObserver: class { observe() {} disconnect() {} }, scrollTo() {}, innerWidth: 1366, innerHeight: 900,
  };
  ctx.window = ctx;
  ctx.window.addEventListener = (t, f) => { (listeners[t] = listeners[t] || []).push(f); };
  vm.createContext(ctx);
  for (const f of ['data-core.js', 'data-counts.js', ...(extraData || []), 'common.js']) vm.runInContext(read(f), ctx, { filename: f });
  if (script) vm.runInContext(read(script), ctx, { filename: script });
  const go = (d) => { pos += d; setLoc(stack[pos]); (listeners.popstate || []).forEach((f) => f({})); };
  return { doc, ctx, loc, back: () => go(-1), forward: () => go(1), flush: () => { while (timers.length) timers.shift()(); }, stackLen: () => stack.length };
}
const liTexts = (el) => el.querySelectorAll('li').map((li) => li.querySelector('a').textContent);
const pageParam = (loc) => new URL(loc.href).searchParams.get('page');
const qParam = (loc, k) => new URL(loc.href).searchParams.get(k);
const numButtons = (doc) => doc.getElementById('page-numbers').children.filter((c) => c.tagName === 'BUTTON');
const clickNum = (doc, n) => numButtons(doc).find((b) => b.textContent === String(n)).click();
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);

// ---- 1. ページ分けの計算 ----
const L = openPage(null, null, 'https://vgame-navi.jp/');
const J = (e) => JSON.parse(JSON.stringify(vm.runInContext(e, L.ctx)));
check('1a. pageRange: 236件・24件ずつは10ページ。1ページ目は0〜24、最終ページは216〜236(20件)', same(J('pageRange(236, 1, 24)'), { page: 1, totalPages: 10, start: 0, end: 24 }) && same(J('pageRange(236, 10, 24)'), { page: 10, totalPages: 10, start: 216, end: 236 }));
check('1b. pageRange: 範囲外・不正なページは1〜最終ページに収める。0件でも1ページ', J('pageRange(236, 99, 24)').page === 10 && J('pageRange(236, 0, 24)').page === 1 && J('pageRange(236, "x", 24)').page === 1 && J('pageRange(0, 1, 24)').totalPages === 1);
check('1c. pageNumberItems: 先頭・末尾・現在の前後2ページ。間は「…」、1ページだけ空く所は番号', same(J('pageNumberItems(6, 12)'), [1, '…', 4, 5, 6, 7, 8, '…', 12]) && same(J('pageNumberItems(1, 10)'), [1, 2, 3, '…', 10]) && same(J('pageNumberItems(4, 10)'), [1, 2, 3, 4, 5, 6, '…', 10]) && same(J('pageNumberItems(1, 1)'), [1]));

// ---- 2. ゲーム一覧(は行: いちばん多い行) ----
const ROW = 'は';
const groupsOfRow = J('groupGamesByKana()').filter((g) => J('KANA_ROW_GROUPS').find((r) => r.row === ROW).members.includes(g.row));
const expected = groupsOfRow.flatMap((g) => g.names.map((n) => J('gameDisplayName(' + JSON.stringify(n) + ')')));
const startOf = {}; let idx = 0; for (const g of groupsOfRow) { startOf[g.row] = idx; idx += g.names.length; }
const pages = Math.ceil(expected.length / 24);
const rowUrl = 'https://vgame-navi.jp/games-row.html?row=' + encodeURIComponent(ROW);
let p = openPage('games-row.html', 'games-row.js', rowUrl);
const list = () => p.doc.getElementById('category-list').children[2];
check('2a. 初期表示は24件(全' + expected.length + '件・' + pages + 'ページ)。1ページ分だけを描画し、ページ切り替えを表示する', same(liTexts(list()), expected.slice(0, 24)) && !p.doc.getElementById('pagination').hidden && p.doc.getElementById('page-indicator').textContent === '1 / ' + pages + ' ページ');
p.doc.getElementById('page-next').click();
check('2b. 次へで2ページ目(25〜48件目)。URL に ?page=2 を残し(row も保つ)、履歴に積み、一覧の先頭へスクロールする', same(liTexts(list()), expected.slice(24, 48)) && pageParam(p.loc) === '2' && qParam(p.loc, 'row') === ROW && p.stackLen() === 2 && p.doc.getElementById('category-list').children[1].scrolled === 1);
clickNum(p.doc, pages);
check('2c. ページ番号で最終ページ。残りの件数(' + (expected.length - (pages - 1) * 24) + '件)だけを表示し、次へは押せない', same(liTexts(list()), expected.slice((pages - 1) * 24)) && p.doc.getElementById('page-next').disabled && numButtons(p.doc).find((b) => b.getAttribute('aria-current') === 'page').textContent === String(pages));
p.doc.getElementById('page-prev').click();
check('2d. 前へで1つ前のページ', same(liTexts(list()), expected.slice((pages - 2) * 24, (pages - 1) * 24)) && pageParam(p.loc) === String(pages - 1));
p.back();
check('2e. 戻るで直前のページ(最終ページ)を復元する', pageParam(p.loc) === String(pages) && same(liTexts(list()), expected.slice((pages - 1) * 24)));
p.back(); p.back();
const atFirst = pageParam(p.loc) === null && same(liTexts(list()), expected.slice(0, 24));
p.forward();
check('2f. さらに戻ると1ページ目(URL の page なし)。進むでまた2ページ目', atFirst && pageParam(p.loc) === '2' && same(liTexts(list()), expected.slice(24, 48)));
p = openPage('games-row.html', 'games-row.js', rowUrl + '&page=3');
check('2g. URL の ?page=3 から3ページ目を表示する', same(liTexts(list()), expected.slice(48, 72)) && p.doc.getElementById('page-indicator').textContent === '3 / ' + pages + ' ページ');
const groupAt48 = groupsOfRow.find((g) => startOf[g.row] <= 48 && 48 < startOf[g.row] + g.names.length).row;
const secs = list().children;
check('2h. 前のページから続くかなは「(続き)」の見出し(id なし)、そのページで始まるかなは見出しに id', (startOf[groupAt48] < 48 ? secs[0].children[0].textContent === groupAt48 + '(続き)' && secs[0].id === '' : secs[0].id === 'kana-' + groupAt48) && secs.slice(1).every((s) => s.id === 'kana-' + s.children[0].textContent));
const lastGroup = groupsOfRow[groupsOfRow.length - 1].row;
const expPage = Math.floor(startOf[lastGroup] / 24) + 1;
p.doc.getElementById('category-list').children[1].querySelectorAll('a').find((a) => a.textContent === lastGroup).click();
check('2i. かなの小見出しリンク(' + lastGroup + ')で、そのかなの先頭があるページ(' + expPage + 'ページ目)へ移り、その見出しがある', pageParam(p.loc) === (expPage > 1 ? String(expPage) : null) && list().children.some((s) => s.id === 'kana-' + lastGroup));
p = openPage('games-row.html', 'games-row.js', rowUrl + '#kana-' + encodeURIComponent(lastGroup));
check('2j. URL の #kana-' + lastGroup + '(page なし)からも、そのかながあるページを表示する', list().children.some((s) => s.id === 'kana-' + lastGroup) && p.doc.getElementById('page-indicator').textContent === expPage + ' / ' + pages + ' ページ');
p = openPage('games-row.html', 'games-row.js', 'https://vgame-navi.jp/games-row.html?row=' + encodeURIComponent('わ'));
check('2k. 24件以下の行(わ行)はページ切り替えを出さない', p.doc.getElementById('pagination').hidden && liTexts(list()).length > 0 && liTexts(list()).length <= 24);

// ---- 3. ゲーム名検索 ----
const Q = 'の';
const nameByLabel = Object.fromEntries(J('GAMES').map((g) => [J('gameDisplayName(' + JSON.stringify(g.name) + ')'), g.name]));
const countOfLabel = (t) => J('listingCountOfGame(' + JSON.stringify(nameByLabel[t]) + ')');
p = openPage('games.html', 'games.js', 'https://vgame-navi.jp/games.html');
const input = p.doc.getElementById('game-search-input'), sort = p.doc.getElementById('game-sort-select'), results = p.doc.getElementById('game-search-results');
sort.value = 'relevance';
const typeQuery = (v) => { input.value = v; (input.listeners.input || []).forEach((f) => f({})); p.flush(); };
check('3a. 検索前はページ切り替えを出さない', p.doc.getElementById('pagination').hidden && results.hidden);
typeQuery(Q);
const total = J('GAMES.filter((g) => gameSearchText(g.name).includes(normalizeSearchText(' + JSON.stringify(Q) + '))).length');
check('3b. 検索結果は24件ずつ(全' + total + '件)。URL に q を残し、page は付けない', total > 48 && liTexts(results).length === 24 && qParam(p.loc, 'q') === Q && pageParam(p.loc) === null && !p.doc.getElementById('pagination').hidden);
const relFirst = liTexts(results);
p.doc.getElementById('page-next').click();
check('3c. 次へで2ページ目。検索条件(q)を保ったまま ?page=2', pageParam(p.loc) === '2' && qParam(p.loc, 'q') === Q && !same(liTexts(results), relFirst) && liTexts(results).length === 24);
sort.value = 'count'; (sort.listeners.change || []).forEach((f) => f({}));
const counts = liTexts(results).map(countOfLabel);
check('3d. 並び順を変えると1ページ目に戻り(page なし・sort=count)、件数の多い順で並ぶ', pageParam(p.loc) === null && qParam(p.loc, 'sort') === 'count' && counts.every((c, i) => i === 0 || counts[i - 1] >= c));
clickNum(p.doc, 2);
const counts2 = liTexts(results).map(countOfLabel);
check('3e. 件数順のまま2ページ目に移れる(1ページ目の最後の件数以下が並ぶ)', pageParam(p.loc) === '2' && qParam(p.loc, 'sort') === 'count' && counts2.every((c) => c <= counts[counts.length - 1]));
typeQuery(Q + 'あ');
check('3f. 検索語を変えると1ページ目に戻る(page を外す)', pageParam(p.loc) === null && qParam(p.loc, 'q') === Q + 'あ');
typeQuery(Q);
p.doc.getElementById('page-next').click(); p.doc.getElementById('page-next').click();
p.back();
check('3g. 戻るで直前のページと検索条件を復元する', pageParam(p.loc) === '2' && input.value === Q && liTexts(results).length === 24 && p.doc.getElementById('page-indicator').textContent.startsWith('2 / '));
p = openPage('games.html', 'games.js', 'https://vgame-navi.jp/games.html?q=' + encodeURIComponent(Q) + '&sort=count&page=2');
check('3h. URL の q・sort・page から検索結果の2ページ目を復元する', p.doc.getElementById('game-search-input').value === Q && p.doc.getElementById('game-sort-select').value === 'count' && p.doc.getElementById('page-indicator').textContent.startsWith('2 / ') && liTexts(p.doc.getElementById('game-search-results')).length === 24);
p = openPage('games.html', 'games.js', 'https://vgame-navi.jp/games.html?q=' + encodeURIComponent('マインクラフト'));
check('3i. 結果が24件以下ならページ切り替えを出さない', p.doc.getElementById('pagination').hidden && liTexts(p.doc.getElementById('game-search-results')).length >= 1);

// ---- 5. 単発実況の一覧(singles.html) ----
const SA = (() => { const c = {}; vm.createContext(c); vm.runInContext(read('data-standalone.js'), c); return JSON.parse(JSON.stringify(vm.runInContext('STANDALONE_PLAYS', c))); })();
const shownIds = SA.map((x, i) => ({ x, i })).sort((a, b) => ((b.x.addedDate || '') > (a.x.addedDate || '') ? 1 : (b.x.addedDate || '') < (a.x.addedDate || '') ? -1 : a.i - b.i)).map((o) => o.x.id);
const sPages = Math.ceil(SA.length / 24);
p = openPage('singles.html', 'singles.js', 'https://vgame-navi.jp/singles.html', ['data-standalone.js']);
const cardsOnPage = () => p.doc.getElementById('single-grid').children.filter((c) => c.tagName === 'ARTICLE');
// カードの「YouTubeで見る」のリンクから、どの単発実況かを特定する(動画URLは単発実況ごとに異なる)
const idOfCard = (c) => { const url = c.querySelectorAll('a').find((a) => a.textContent === 'YouTubeで見る').href; return SA.find((x) => (x.videos[0] || {}).url === url).id; };
const perPage = [], seen = [];
for (let i = 0; i < sPages; i++) { perPage.push(cardsOnPage().length); seen.push(...cardsOnPage().map(idOfCard)); if (i < sPages - 1) p.doc.getElementById('page-next').click(); }
const expCounts = Array.from({ length: sPages }, (_, i) => Math.min(24, SA.length - i * 24));
check('5a. 単発実況 ' + SA.length + ' 件を24件ずつ(' + expCounts.join('・') + '件)に分けて表示する', same(perPage, expCounts) && p.doc.getElementById('page-next').disabled && p.doc.getElementById('result-count').textContent === SA.length + ' 件');
check('5b. 全ページを通して、追加日の新しい順のまま重複・欠落なく全件が並ぶ', seen.length === SA.length && new Set(seen).size === SA.length && same(seen, shownIds));
check('5c. ページを移ると URL に ?page= を残し、戻るで直前のページを復元する', pageParam(p.loc) === String(sPages) && (p.back(), pageParam(p.loc) === String(sPages - 1) && same(cardsOnPage().map(idOfCard), shownIds.slice((sPages - 2) * 24, (sPages - 1) * 24))));
const sInput = p.doc.getElementById('single-search');
sInput.value = '熱千めら'; (sInput.listeners.input || []).forEach((f) => f({})); p.flush();
check('5d. 検索語を変えると1ページ目に戻り(page を外して q を残す)、24件以下ならページ切り替えを出さない', pageParam(p.loc) === null && qParam(p.loc, 'q') === '熱千めら' && cardsOnPage().length > 0 && p.doc.getElementById('pagination').hidden);
p = openPage('singles.html', 'singles.js', 'https://vgame-navi.jp/singles.html?page=' + sPages, ['data-standalone.js']);
const lastImgs = cardsOnPage().map((c) => c.querySelectorAll('img')[0]).filter(Boolean);
check('5e. URL の ?page= から最終ページを表示し、2ページ目以降のサムネイルは遅延読み込みのまま', same(cardsOnPage().map(idOfCard), shownIds.slice((sPages - 1) * 24)) && lastImgs.length > 0 && lastImgs.every((img) => img.loading === 'lazy'), p.doc.getElementById('page-indicator').textContent + ' cards=' + cardsOnPage().length);

// ---- 4. 既存のページ切り替え(引数2つで呼ぶページ)は URL を変えない ----
check('4a. URL への記録は urlParam を渡したときだけ。既存の呼び出し(new/ranking/game/streamer)は渡していない', /if \(opts\.urlParam\) writePageToUrl/.test(read('common.js')) && ['new.js', 'ranking.js', 'game.js', 'streamer.js'].every((f) => !/urlParam/.test(read(f))));

console.log('\nPASS: ' + pass + '  FAIL: ' + fail);
process.exit(fail ? 1 : 0);
