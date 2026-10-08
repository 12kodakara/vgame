/**
 * VTuberのゲーム企画(data-core.js の GAME_EVENTS / PLAYLIST_EVENTS)の表示の回帰テスト。ブラウザ不要(node test-playlist-events.js)。
 *
 * 次を確かめる。
 *   1. 定義: 企画の再生リストは id で列挙され、再生リスト・企画・使用ゲームが存在し、game は再生リストの game と同じ
 *   2. 判定は id だけ(再生リスト名などの文字列からは判定しない)
 *   3. 簡易一覧(renderPlaylistDiscoverList): 企画の再生リストだけに「企画: ◯◯」「使用ゲーム」が出る。
 *      企画でない再生リストは表示が変わらない。タイトル・リンク・更新日は維持(ゲーム名を出さない一覧も確認)
 *   4. 一覧表(createRow): 企画の再生リストだけに補足行が出る。ほかのセル(ゲーム・動画数・更新日)は変わらない
 *   5. ゲーム詳細の再生リストカード(game.js): 企画の再生リストだけに補足行が出る。動画数・更新日は変わらない
 *   6. トップページ(data-home.js の最近更新)でも企画の再生リストにだけ出る
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
console.log('=== VTuberのゲーム企画(ホロライブ甲子園・にじさんじ甲子園)表示 回帰テスト ===');

// ---- 最小限の DOM(描画処理が触る操作だけを記録する) ----
class El {
  constructor(tag, doc) { this.tagName = String(tag).toUpperCase(); this.children = []; this.attrs = {}; this.listeners = {}; this.parent = null; this.hidden = false; this._text = ''; this.doc = doc; this.style = {}; this.dataset = {};
    const cls = new Set(); this.classList = { add: (...c) => c.forEach((x) => cls.add(x)), remove: (...c) => c.forEach((x) => cls.delete(x)), toggle: (c, f) => { const on = f === undefined ? !cls.has(c) : f; if (on) cls.add(c); else cls.delete(c); return on; }, contains: (c) => cls.has(c) || this.className.split(/\s+/).includes(c) }; }
  get className() { return this.attrs.class || ''; } set className(v) { this.attrs.class = String(v); }
  get id() { return this.attrs.id || ''; } set id(v) { this.attrs.id = v; }
  get textContent() { return this._text + this.children.map((c) => c.textContent).join(''); } set textContent(v) { this._text = String(v); this.children = []; }
  get innerText() { return this.textContent; }
  set innerHTML(v) { if (v === '') { this.children = []; this._text = ''; } }
  get innerHTML() { return ''; }
  get href() { return this.attrs.href || ''; } set href(v) { this.attrs.href = String(v); }
  get firstChild() { return this.children[0] || null; }
  // DocumentFragment は中身だけを移す(実際の DOM と同じ)
  appendChild(c) { if (c && c.tagName === '#FRAGMENT') { c.children.slice().forEach((x) => this.appendChild(x)); return c; } if (c && c.parent) c.remove(); if (c) { c.parent = this; this.children.push(c); } return c; }
  append(...cs) { cs.forEach((c) => this.appendChild(typeof c === 'string' ? Object.assign(new El('#text', this.doc), { _text: c }) : c)); }
  prepend(c) { c.parent = this; this.children.unshift(c); }
  insertBefore(c, ref) { const i = this.children.indexOf(ref); c.parent = this; if (i < 0) this.children.push(c); else this.children.splice(i, 0, c); return c; }
  replaceChildren(...cs) { this.children = []; this.append(...cs); }
  remove() { if (this.parent) this.parent.children = this.parent.children.filter((x) => x !== this); this.parent = null; }
  setAttribute(k, v) { this.attrs[k] = String(v); } getAttribute(k) { return k in this.attrs ? this.attrs[k] : null; } removeAttribute(k) { delete this.attrs[k]; } hasAttribute(k) { return k in this.attrs; }
  addEventListener(t, f) { (this.listeners[t] = this.listeners[t] || []).push(f); } removeEventListener() {}
  all() { const out = []; const walk = (e) => { for (const c of e.children) { out.push(c); walk(c); } }; walk(this); return out; }
  byClass(c) { return this.all().filter((e) => e.className.split(/\s+/).includes(c)); }
  querySelectorAll(sel) { const tag = /^[a-z]+$/i.test(sel) ? sel.toUpperCase() : null; return tag ? this.all().filter((e) => e.tagName === tag) : []; }
  querySelector(sel) { return this.querySelectorAll(sel)[0] || null; }
  closest() { return null; } matches() { return false; } contains() { return false; }
  getBoundingClientRect() { return { top: 0, left: 0, width: 0, height: 0, bottom: 0, right: 0 }; } getClientRects() { return []; }
  focus() {} blur() {} scrollIntoView() {} click() {}
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
function makeContext(doc, search, withEvents) {
  const storage = { getItem: () => null, setItem: () => {}, removeItem: () => {} };
  const ctx = {
    console, document: doc, localStorage: storage, sessionStorage: storage, navigator: { userAgent: 'node' }, URLSearchParams, URL, encodeURIComponent, decodeURIComponent,
    location: { search: search || '', href: 'https://vgame-navi.jp/' + (search || ''), pathname: '/', hash: '' },
    history: { replaceState() {}, pushState() {} }, setTimeout: () => 0, clearTimeout() {}, requestAnimationFrame: () => 0, matchMedia: () => ({ matches: false, addEventListener() {} }),
    IntersectionObserver: class { observe() {} disconnect() {} }, scrollTo() {}, innerWidth: 1366, innerHeight: 900,
  };
  ctx.window = ctx; ctx.window.addEventListener = () => {};
  vm.createContext(ctx);
  vm.runInContext(read('data-core.js'), ctx, { filename: 'data-core.js' });
  // 企画の定義が無い状態(変更前と同じ表示)と比べるため、定義を外した環境も作る
  if (!withEvents) vm.runInContext('PLAYLIST_EVENTS.length = 0;', ctx);
  for (const f of ['data-counts.js', 'data-playlists.js', 'common.js']) vm.runInContext(read(f), ctx, { filename: f });
  return ctx;
}

// ---- データ ----
const dctx = {}; vm.createContext(dctx);
for (const f of ['data-core.js', 'data-playlists.js']) vm.runInContext(read(f), dctx);
const GAMES = vm.runInContext('GAMES', dctx), PLAYLISTS = vm.runInContext('PLAYLISTS', dctx);
const GAME_EVENTS = vm.runInContext('GAME_EVENTS', dctx), PLAYLIST_EVENTS = vm.runInContext('PLAYLIST_EVENTS', dctx);
const byId = new Map(PLAYLISTS.map((p) => [p.id, p]));
const gameNames = new Set(GAMES.map((g) => g.name));
const eventName = new Map(GAME_EVENTS.map((e) => [e.id, e.name]));
const eventOf = new Map(PLAYLIST_EVENTS.map((e) => [e.playlist, e]));
const labelOf = (e) => '企画: ' + eventName.get(e.event) + (e.year ? String(e.year) : '');

// ---- 1. 定義 ----
{
  const problems = [];
  if (new Set(GAME_EVENTS.map((e) => e.id)).size !== GAME_EVENTS.length) problems.push('GAME_EVENTS の id が重複');
  if (eventOf.size !== PLAYLIST_EVENTS.length) problems.push('同じ再生リストが2回ある');
  for (const e of PLAYLIST_EVENTS) {
    const p = byId.get(e.playlist);
    if (!p) { problems.push('再生リストが無い: ' + e.playlist); continue; }
    if (!eventName.has(e.event)) problems.push(e.playlist + ': 企画が無い ' + e.event);
    if (!gameNames.has(e.game)) problems.push(e.playlist + ': 使用ゲームが GAMES に無い ' + e.game);
    if (e.game !== p.game) problems.push(e.playlist + ': 使用ゲーム ' + e.game + ' ≠ 再生リストの game ' + p.game);
    if ('year' in e && !(Number.isInteger(e.year) && e.year >= 2000 && e.year <= 2100)) problems.push(e.playlist + ': 開催年 ' + e.year);
  }
  check('1a. 企画の再生リスト(' + PLAYLIST_EVENTS.length + '件)は実在し、企画・使用ゲームが存在し、使用ゲーム = 再生リストの game', problems.length === 0, problems.join(' / '));
  const count = (id) => PLAYLIST_EVENTS.filter((e) => e.event === id).length;
  check('1b. ホロライブ甲子園 ' + count('hololive-koshien') + '件・にじさんじ甲子園 ' + count('nijisanji-koshien') + '件(確認済みの再生リストのみ)',
    count('hololive-koshien') === 3 && count('nijisanji-koshien') === 25);
  // 再生リスト名・動画タイトルで企画と確認できなかったもの・企画ではないものは入れない
  const excluded = ['holo-112', 'holo-037', 'holo-137', 'hd-0343', 'hd-0456', 'hd-1349', 'niji-sakusasaki-50', 'niji-takamiyarion-10',
    'niji-suzunananase-01', 'niji-usamiritopow-01', 'niji-honmahimawar-02', 'niji-vampkuzu-12'];
  check('1c. 対象外・保留の再生リスト(通常のパワプロ実況・ミリしらパワプロ杯・企画名が再生リスト名に無いもの・試走)は定義しない',
    excluded.every((id) => byId.has(id) && !eventOf.has(id)), excluded.filter((id) => eventOf.has(id) || !byId.has(id)).join(', '));
}

// ---- 2. 判定は id だけ ----
{
  const src = read('common.js');
  const m = src.match(/function playlistEventOf\(item\) \{[\s\S]*?\n\}/);
  const body = m ? m[0] : '';
  check('2a. playlistEventOf は再生リストの id だけで引く(title・甲子園などの文字列を見ない)',
    body && /item\.id/.test(body) && !/\.title|甲子園|includes\(|indexOf\(|match\(|test\(/.test(body), body.slice(0, 200));
}

// 定義と再生リストの game が食い違ったとき(後から game を変えた場合)は表示しない
{
  const ctx = makeContext(makeDocument(''), '', true);
  const ev = PLAYLIST_EVENTS[0], p = byId.get(ev.playlist);
  ctx.__ok = p; ctx.__moved = Object.assign({}, p, { game: 'パワフルプロ野球2026' }); ctx.__other = Object.assign({}, p, { id: 'no-such-id' });
  const r = vm.runInContext('[playlistEventOf(__ok), playlistEventOf(__moved), playlistEventOf(__other)]', ctx);
  check('2b. 再生リストの game が定義と違う・定義に無い id の場合は企画を表示しない(誤った使用ゲームを出さない)', r[0] && r[0].game === p.game && r[1] === null && r[2] === null);
}

// ---- 3. 簡易一覧(renderPlaylistDiscoverList) ----
const pawaItems = PLAYLISTS.filter((p) => /^パワフルプロ野球/.test(p.game));
const sampleItems = pawaItems.concat(PLAYLISTS.filter((p) => !/^パワフルプロ野球/.test(p.game)).slice(0, 30));
function renderDiscover(withEvents, opts) {
  const doc = makeDocument('<ol id="list"></ol>');
  const ctx = makeContext(doc, '', withEvents);
  ctx.__items = sampleItems; ctx.__opts = opts;
  vm.runInContext('renderPlaylistDiscoverList("list", __items, "", __opts);', ctx);
  return { lis: doc.getElementById('list').children, ctx };
}
{
  for (const [name, opts] of [['ゲーム名あり(トップページ・ジャンル・シリーズ)', {}], ['ゲーム名なし(ゲーム詳細の人気リスト)', { showGame: false }], ['VTuber名なし(VTuber詳細)', { showStreamer: false }]]) {
    const after = renderDiscover(true, opts), before = renderDiscover(false, opts);
    const problems = [];
    sampleItems.forEach((item, i) => {
      const li = after.lis[i], base = before.lis[i];
      const title = li.byClass('discover-title')[0], baseTitle = base.byClass('discover-title')[0];
      if (title.textContent !== item.title || title.href !== baseTitle.href) problems.push(item.id + ': タイトル・リンクが変わった');
      const meta = li.byClass('discover-meta')[0], baseMeta = base.byClass('discover-meta')[0];
      const labels = li.byClass('event-label');
      const ev = eventOf.get(item.id);
      if (!ev) {
        if (labels.length || meta.textContent !== baseMeta.textContent) problems.push(item.id + ': 企画でないのに表示が変わった');
        return;
      }
      if (labels.length !== 1 || labels[0].textContent !== labelOf(ev) || labels[0].tagName !== 'SPAN' || labels[0].getAttribute('href') !== null) problems.push(item.id + ': ラベル ' + (labels[0] ? labels[0].textContent : 'なし'));
      if (!meta.textContent.startsWith(labelOf(ev) + ' ／ 使用ゲーム: ' + ev.game + ' ／ ')) problems.push(item.id + ': 使用ゲームの表示 ' + meta.textContent);
      // 企画の補足を除いた残り(ゲーム名リンク・VTuber・更新日)は変更前と同じ
      if (!meta.textContent.endsWith(baseMeta.textContent)) problems.push(item.id + ': 既存のメタ情報が変わった ' + meta.textContent);
      const gameLinks = meta.byClass('game-link');
      if (opts.showGame !== false && (gameLinks.length !== 1 || gameLinks[0].href !== base.byClass('game-link')[0].href)) problems.push(item.id + ': ゲーム名リンクが変わった');
    });
    const shown = sampleItems.filter((x) => eventOf.has(x.id)).length;
    check('3. 簡易一覧・' + name + ': 企画の再生リスト ' + shown + '件だけに「企画」「使用ゲーム」、ほか ' + (sampleItems.length - shown) + '件は変更前と同じ表示', problems.length === 0 && shown === PLAYLIST_EVENTS.length, problems.slice(0, 5).join(' / '));
  }
}

// ---- 4. 一覧表(createRow) ----
{
  const doc = makeDocument(''), ctx = makeContext(doc, '', true);
  const bdoc = makeDocument(''), bctx = makeContext(bdoc, '', false);
  const problems = [];
  for (const item of sampleItems) {
    ctx.__item = item; bctx.__item = item;
    const tr = vm.runInContext('createRow(__item, { showAgency: true })', ctx), btr = vm.runInContext('createRow(__item, { showAgency: true })', bctx);
    const cells = tr.children.map((c) => c.textContent), bcells = btr.children.map((c) => c.textContent);
    const ev = eventOf.get(item.id);
    const evCells = tr.byClass('event-cell');
    if (!ev) { if (evCells.length || JSON.stringify(cells) !== JSON.stringify(bcells)) problems.push(item.id + ': 企画でないのに表示が変わった'); continue; }
    if (evCells.length !== 1 || evCells[0].textContent !== labelOf(ev) + ' 使用ゲーム: ' + ev.game) problems.push(item.id + ': 補足行 ' + (evCells[0] ? evCells[0].textContent : 'なし'));
    // タイトルのセル以外(ジャンル・ゲーム・VTuber・動画数・更新日など)は変更前と同じ
    const titleIdx = tr.children.findIndex((c) => c.className === 'title-cell');
    if (cells.length !== bcells.length || cells.some((t, i) => i !== titleIdx && t !== bcells[i])) problems.push(item.id + ': ほかのセルが変わった');
    if (cells[titleIdx] !== bcells[titleIdx] + evCells[0].textContent) problems.push(item.id + ': タイトルのセル');
  }
  check('4. 一覧表(createRow): 企画の再生リストだけに補足行、ほかのセル(ジャンル・ゲーム・動画数・更新日)と企画でない行は変更前と同じ', problems.length === 0, problems.slice(0, 5).join(' / '));
}

// ---- 5. ゲーム詳細の再生リストカード(game.js) ----
function renderGame(name, withEvents) {
  const doc = makeDocument(read('game.html'));
  const details = doc.getElementById('game-streamer-more'); if (details) details.appendChild(new El('summary', doc));
  // 全件を1ページに出す(ページ送りはこのテストの対象外)
  const ps = doc.getElementById('pagesize-select'); if (ps) Object.defineProperty(ps, 'value', { get: () => '100', set() {} });
  const ctx = makeContext(doc, '?game=' + encodeURIComponent(name), withEvents);
  vm.runInContext(read('data-series.js'), ctx, { filename: 'data-series.js' });
  vm.runInContext('startDetailPage = function (kind, key, getItems, render) { render(getItems(key), null); };', ctx);
  vm.runInContext('Math.random = () => 0.42;', ctx);
  vm.runInContext(read('game.js'), ctx, { filename: 'game.js' });
  return doc.getElementById('grid').children.filter((c) => c.className === 'playlist-card');
}
{
  const problems = []; let shown = 0, total = 0;
  for (const g of [...new Set(pawaItems.map((p) => p.game))]) {
    const cards = renderGame(g, true), base = renderGame(g, false);
    const items = PLAYLISTS.filter((p) => p.game === g);
    if (cards.length !== items.length) problems.push(g + ': カード ' + cards.length + ' ≠ 再生リスト ' + items.length);
    cards.forEach((card, i) => {
      total++;
      const title = card.getAttribute('aria-label').replace(/ を開く$/, '');
      const cand = items.filter((p) => p.title === title);
      const evs = card.byClass('playlist-card-event');
      const isEvent = cand.some((p) => eventOf.has(p.id));
      const keep = (c) => ['playlist-card-meta', 'playlist-card-date', 'playlist-card-title', 'playlist-card-streamer'].map((k) => (c.byClass(k)[0] || { textContent: '' }).textContent).join('|');
      if (keep(card) !== keep(base[i])) problems.push(g + ' / ' + title + ': 動画数・更新日・タイトル・VTuberが変わった');
      if (!isEvent) { if (evs.length) problems.push(g + ' / ' + title + ': 企画でないのに補足行'); return; }
      const ev = eventOf.get(cand.find((p) => eventOf.has(p.id)).id);
      shown++;
      if (evs.length !== 1 || evs[0].textContent !== labelOf(ev) + ' 使用ゲーム: ' + ev.game) problems.push(g + ' / ' + title + ': 補足行 ' + (evs[0] ? evs[0].textContent : 'なし'));
    });
  }
  check('5. ゲーム詳細のカード(パワプロ各作品 ' + total + '枚): 企画の再生リスト ' + shown + '枚だけに補足行、動画数・更新日・タイトル・VTuberは変更前と同じ', problems.length === 0 && shown === PLAYLIST_EVENTS.length, problems.slice(0, 5).join(' / '));
}

// ---- 6. トップページ(data-home.js の最近更新) ----
{
  const doc = makeDocument('<ol id="list"></ol>'), ctx = makeContext(doc, '', true);
  vm.runInContext(read('data-home.js'), ctx, { filename: 'data-home.js' });
  vm.runInContext('renderPlaylistDiscoverList("list", HOME_SUMMARY.recentUpdated, "");', ctx);
  const recent = vm.runInContext('HOME_SUMMARY.recentUpdated', ctx);
  const lis = doc.getElementById('list').children;
  const problems = [];
  recent.forEach((item, i) => {
    const labels = lis[i].byClass('event-label');
    const ev = eventOf.get(item.id);
    if (ev ? (labels.length !== 1 || labels[0].textContent !== labelOf(ev)) : labels.length) problems.push(item.id + ': ' + (labels[0] ? labels[0].textContent : 'なし'));
  });
  const evIds = recent.filter((x) => eventOf.has(x.id)).map((x) => x.id);
  check('6. トップページ「最近更新された再生リスト」: 企画の再生リスト(' + (evIds.join(', ') || 'なし') + ')にだけラベル', problems.length === 0, problems.join(' / '));
}

console.log('\nPASS: ' + pass + '  FAIL: ' + fail);
process.exit(fail ? 1 : 0);
