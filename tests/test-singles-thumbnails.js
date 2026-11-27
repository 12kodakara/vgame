/**
 * 単発・PLなし実況ページ(singles.html)の表の回帰テスト。ブラウザ不要(node tests/test-singles-thumbnails.js)。
 *
 * singles.js を最小限の DOM の上で実際に動かし、次を確かめる。
 *   1. 登録済みの全件が8列の行になり、初期表示は投稿日の新しい順・20件ずつ
 *   2〜4. サムネイルとタイトルは同じ動画へ別タブで開く。形式・ゲーム・事務所・実況者・動画数・投稿日・更新日
 *   5. 画像が無いときは 320px → 480px → 代替表示と下げ、繰り返さない
 *   6. 動画IDが取れないURLは推測せず代替表示
 *   7. 検索・絞り込み(複数条件を含む)
 *   8. singles.html(title・H1・description・canonical)は変更しない
 *   9. 並べ替え(投稿日・更新日・動画数)。日付が不明な行は「—」で、昇順・降順とも末尾。元データは変えない
 *  10. 複数回・PLなし(multi)は閉じた展開行に全動画(公開日・リンク)を登録順に並べ、ボタンで開閉する
 * 失敗が1件でもあれば終了コード1。
 */
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const ROOT = path.join(__dirname, '..');
const read = (f) => fs.readFileSync(path.join(ROOT, f), 'utf8');
let pass = 0, fail = 0;
function check(name, ok, detail) {
  if (ok) { pass++; console.log('  [PASS] ' + name); } else { fail++; console.log('  [FAIL] ' + name + (detail ? '\n         ' + String(detail).slice(0, 400) : '')); }
}
console.log('=== 単発・PLなし実況ページ 表の回帰テスト ===');

// ---- 最小限の DOM(描画処理が触る操作だけを記録する) ----
class El {
  constructor(tag, doc) { this.tagName = String(tag).toUpperCase(); this.children = []; this.attrs = {}; this.listeners = {}; this.parent = null; this.hidden = false; this._text = ''; this.doc = doc; this.style = {}; this.value = ''; this.srcHistory = []; }
  get className() { return this.attrs.class || ''; } set className(v) { this.attrs.class = String(v); }
  get id() { return this.attrs.id || ''; } set id(v) { this.attrs.id = v; }
  get textContent() { return this._text + this.children.map((c) => c.textContent).join(''); } set textContent(v) { this._text = String(v); this.children = []; }
  set innerHTML(v) { if (v === '') { this.children = []; this._text = ''; } }
  get innerHTML() { return ''; }
  get href() { return this.attrs.href || ''; } set href(v) { this.attrs.href = String(v); }
  get src() { return this.attrs.src || ''; } set src(v) { this.attrs.src = String(v); this.srcHistory.push(String(v)); }
  get srcset() { return this.attrs.srcset || ''; } set srcset(v) { this.attrs.srcset = String(v); }
  get sizes() { return this.attrs.sizes || ''; } set sizes(v) { this.attrs.sizes = String(v); }
  get title() { return this.attrs.title || ''; } set title(v) { this.attrs.title = String(v); }
  appendChild(c) { if (c && c.tagName === '#FRAGMENT') { c.children.slice().forEach((x) => this.appendChild(x)); return c; } if (c && c.parent) c.remove(); if (c) { c.parent = this; this.children.push(c); } return c; }
  remove() { if (this.parent) this.parent.children = this.parent.children.filter((x) => x !== this); this.parent = null; }
  setAttribute(k, v) { this.attrs[k] = String(v); } getAttribute(k) { return k in this.attrs ? this.attrs[k] : null; } removeAttribute(k) { delete this.attrs[k]; } hasAttribute(k) { return k in this.attrs; }
  addEventListener(t, f) { (this.listeners[t] = this.listeners[t] || []).push(f); } removeEventListener() {}
  fire(t) { (this.listeners[t] || []).slice().forEach((f) => f({ type: t, target: this, preventDefault() {} })); }
  all() { const out = []; const walk = (e) => { for (const c of e.children) { out.push(c); walk(c); } }; walk(this); return out; }
  byClass(c) { return this.all().filter((e) => e.className.split(/\s+/).includes(c)); }
  byTag(t) { return this.all().filter((e) => e.tagName === t.toUpperCase()); }
  querySelectorAll() { return []; } querySelector() { return null; }
}
function makeDocument(html) {
  const doc = { byId: {}, listeners: {} };
  doc.createElement = (t) => new El(t, doc);
  doc.createTextNode = (t) => Object.assign(new El('#text', doc), { _text: String(t) });
  doc.createDocumentFragment = () => new El('#fragment', doc);
  doc.head = new El('head', doc); doc.body = new El('body', doc); doc.documentElement = new El('html', doc);
  for (const m of html.matchAll(/<([a-z0-9]+)([^>]*)\sid="([^"]+)"([^>]*)>/g)) {
    const e = new El(m[1], doc); e.id = m[3]; const cls = /class="([^"]*)"/.exec(m[2] + m[4]); if (cls) e.className = cls[1];
    doc.byId[m[3]] = e;
  }
  doc.getElementById = (id) => doc.byId[id] || null;
  doc.sortHeaders = [...html.matchAll(/<th class="sortable[^"]*" data-sort="([a-z]+)">/g)].map((m) => {
    const th = new El('th', doc); th.dataset = { sort: m[1] }; const arrow = new El('span', doc); th.querySelector = () => arrow; th.arrow = arrow; return th;
  });
  doc.querySelector = () => null; doc.querySelectorAll = (sel) => (/th\.sortable/.test(sel) ? doc.sortHeaders : []);
  doc.addEventListener = (t, f) => { (doc.listeners[t] = doc.listeners[t] || []).push(f); };
  doc.readyState = 'complete';
  return doc;
}
// standalone を渡すと data-standalone.js の代わりにその配列を使う(テスト用。本番ファイルは書き換えない)
function renderSingles(standalone, dpr) {
  const doc = makeDocument(read('singles.html'));
  const storage = { getItem: () => null, setItem: () => {}, removeItem: () => {} };
  const ctx = {
    console, document: doc, localStorage: storage, sessionStorage: storage, navigator: { userAgent: 'node' }, URLSearchParams, URL, encodeURIComponent, decodeURIComponent,
    location: { search: '', href: 'https://vgame-navi.jp/singles.html', pathname: '/singles.html', hash: '' },
    history: { replaceState() {}, pushState() {} }, setTimeout: (f) => { f(); return 0; }, clearTimeout() {}, requestAnimationFrame: () => 0,
    matchMedia: () => ({ matches: false, addEventListener() {} }), IntersectionObserver: class { observe() {} disconnect() {} }, scrollTo() {}, innerWidth: 1440, innerHeight: 900,
  };
  ctx.window = ctx; ctx.window.addEventListener = () => {};
  if (dpr) ctx.devicePixelRatio = dpr;
  vm.createContext(ctx);
  for (const f of ['data-core.js', 'data-counts.js']) vm.runInContext(read(f), ctx, { filename: f });
  if (standalone) ctx.STANDALONE_PLAYS = standalone; else vm.runInContext(read('data-standalone.js'), ctx, { filename: 'data-standalone.js' });
  vm.runInContext(read('common.js'), ctx, { filename: 'common.js' });
  vm.runInContext(read('singles.js'), ctx, { filename: 'singles.js' });
  const grid = doc.getElementById('grid');
  // 一覧は20件ずつのページ分け。ここでは全ページを順にめくって行を集め、1ページ目に戻す
  const next = doc.getElementById('page-next'), prev = doc.getElementById('page-prev');
  const flat = () => grid.children;
  const pageRows = () => flat().filter((c) => c.className.split(/\s+/).includes('singles-row'));
  const rows = () => {
    const all = pageRows().slice();
    while (next && !next.disabled && pageRows().length) { next.fire('click'); all.push(...pageRows()); }
    while (prev && !prev.disabled) prev.fire('click');
    return all;
  };
  const details = () => {
    const all = [];
    const take = () => all.push(...flat().filter((c) => c.className.split(/\s+/).includes('singles-detail-row')));
    take();
    while (next && !next.disabled && pageRows().length) { next.fire('click'); take(); }
    while (prev && !prev.disabled) prev.fire('click');
    return all;
  };
  return { doc, ctx, grid, rows, pageRows, details };
}

// ---- データ ----
const dctx = {}; vm.createContext(dctx);
for (const f of ['data-core.js', 'data-standalone.js', 'common.js']) {
  try { vm.runInContext(read(f), dctx); } catch (e) { /* common.js のページ用処理は document が無いと動かないが、関数定義だけ使う */ }
}
const PLAYS = vm.runInContext('STANDALONE_PLAYS', dctx);
// 期待値は実装の関数を使わずに作る
const first = (p) => p.videos.map((v) => v.publishedDate).sort()[0];
const last = (p) => p.videos.map((v) => v.publishedDate).sort().slice(-1)[0];
// 追加日の新しい順(同日は登録順)を土台に、指定の値で並べる
const BASE = PLAYS.map((p, i) => ({ p, i }))
  .sort((a, b) => ((b.p.addedDate || '') > (a.p.addedDate || '') ? 1 : (b.p.addedDate || '') < (a.p.addedDate || '') ? -1 : a.i - b.i))
  .map((x) => x.p);
const ordered = (value, dir) => BASE.map((p, i) => ({ p, i, v: value(p) }))
  .sort((a, b) => (a.v === b.v ? a.i - b.i : (a.v < b.v ? -1 : 1) * dir)).map((x) => x.p);
const SHOWN = ordered(first, -1);
const FORMAT_BADGE = { single: '単発', multi: '複数回・PLなし', 'mixed-playlist': '雑多PL内' };
const idFromData = (url) => { const m = /^https:\/\/www\.youtube\.com\/watch\?v=([A-Za-z0-9_-]{11})$/.exec(url); return m ? m[1] : null; };
const slash = (d) => d.replace(/-/g, '/');
const keyOf = (row) => row.byClass('title-link')[0].href;
const urlsOf = (list) => list.map((p) => p.videos[0].url).join();

const r = renderSingles();
const rows = r.rows();

// ---- 1〜4. 全件の行 ----
{
  check('1a. 登録済みの全 ' + PLAYS.length + ' 件が行になり、初期表示は20件。件数と表示範囲を出す',
    PLAYS.length > 0 && new Set(PLAYS.map((p) => p.id)).size === PLAYS.length && rows.length === PLAYS.length && r.pageRows().length === Math.min(20, PLAYS.length) &&
    r.doc.getElementById('result-count').textContent.startsWith(PLAYS.length + ' 件 (投稿日の新しい順) — 1〜'), r.doc.getElementById('result-count').textContent);
  const problems = [];
  rows.forEach((row, i) => {
    const item = SHOWN[i];
    const url = item.videos[0].url, id = idFromData(url);
    const td = row.children;
    if (td.length !== 8) { problems.push(item.id + ': 列数 ' + td.length); return; }
    const thumb = td[1].byClass('row-thumb')[0], img = thumb && thumb.byTag('img')[0];
    if (!img) { problems.push(item.id + ': サムネイルが無い'); return; }
    if (img.src !== 'https://i.ytimg.com/vi/' + id + '/mqdefault.jpg') problems.push(item.id + ': src ' + img.src);
    if (!img.alt.includes(item.title) || img.loading !== (i < 3 ? 'eager' : 'lazy')) problems.push(item.id + ': alt・読み込み設定');
    const title = td[1].byClass('title-link')[0];
    if (title.textContent !== item.title || title.href !== url || thumb.href !== url) problems.push(item.id + ': タイトル・リンク先');
    if (title.target !== '_blank' || !/\bnoopener\b/.test(title.rel) || thumb.target !== '_blank' || !/\bnoopener\b/.test(thumb.rel)) problems.push(item.id + ': 外部リンクの属性');
    if (title.title !== item.title) problems.push(item.id + ': タイトル全文(title属性)');
    if (td[1].byClass('format-badge')[0].textContent !== FORMAT_BADGE[item.format] || title.byClass('format-badge').length) problems.push(item.id + ': 形式');
    if (!td[0].byClass('badge')[0] || !td[0].textContent) problems.push(item.id + ': ジャンル');
    const game = td[2].byTag('a')[0], agency = td[3].byTag('a')[0], streamer = td[4].byTag('a')[0];
    if (game.textContent !== item.game || game.href !== 'game.html?game=' + encodeURIComponent(item.game)) problems.push(item.id + ': ゲーム');
    if (!agency.textContent || agency.href !== 'streamers.html?agency=' + encodeURIComponent(agency.textContent)) problems.push(item.id + ': 事務所');
    if (streamer.textContent !== item.streamer || streamer.href !== 'streamer.html?streamer=' + encodeURIComponent(item.streamer)) problems.push(item.id + ': 実況者');
    if (!td[5].textContent.startsWith(item.videos.length + '本')) problems.push(item.id + ': 動画数 ' + td[5].textContent);
    if (td[6].textContent !== slash(first(item)) || td[7].textContent !== slash(last(item))) problems.push(item.id + ': 日付 ' + td[6].textContent + ' ' + td[7].textContent);
  });
  check('1b〜4. 全行: 投稿日の新しい順で、サムネイル・タイトル・形式・ジャンル・ゲーム・事務所・実況者・動画数・投稿日(最古)・更新日(最新)', problems.length === 0, problems.slice(0, 6).join(' / '));
  check('2. サムネイルの動画IDはすべて別', new Set(rows.map((c) => c.byTag('img')[0].src)).size === rows.length);
}

// ---- 10. 複数回・PLなし(multi)の展開 ----
{
  const s = renderSingles();
  const multi = SHOWN.filter((p) => p.format === 'multi' && p.videos.length >= 2);
  const details = s.details();
  const problems = [];
  details.forEach((d, i) => {
    const item = multi[i];
    if (!d.hidden || d.children[0].colSpan !== 8) problems.push(item.id + ': 初期状態・列結合');
    const links = d.byTag('a');
    if (links.length !== item.videos.length || links.some((a, k) => a.href !== item.videos[k].url || a.textContent !== item.videos[k].title || a.target !== '_blank' || a.rel !== 'noopener')) problems.push(item.id + ': リンク');
    const times = d.byTag('time');
    if (times.length !== item.videos.length || times.some((t, k) => t.textContent !== slash(item.videos[k].publishedDate))) problems.push(item.id + ': 公開日');
  });
  check('10a. 複数回・PLなしの全 ' + multi.length + ' 件: 閉じた展開行に全動画(公開日・リンク)を登録順に並べる。単発には付けない',
    multi.length > 0 && details.length === multi.length && problems.length === 0 && s.rows().every((row, i) => row.byClass('singles-toggle').length === (SHOWN[i].format === 'multi' && SHOWN[i].videos.length >= 2 ? 1 : 0)), problems.slice(0, 5).join(' / '));
  const s2 = renderSingles([multi[0]]);
  const btn = s2.pageRows()[0].byClass('singles-toggle')[0], d = s2.grid.children[1];
  const closed = [d.hidden, btn.getAttribute('aria-expanded'), btn.textContent].join();
  btn.fire('click'); const open = [d.hidden, btn.getAttribute('aria-expanded'), btn.textContent].join();
  btn.fire('click');
  check('10b. ボタンで開閉し、状態がボタンの文字と aria-expanded に出る', closed === 'true,false,▼ 一覧' && open === 'false,true,▲ 閉じる' && d.hidden === true, closed + ' | ' + open);
}

// ---- 5. 画像が無いときの切り替え ----
{
  const row = rows[5];
  const thumb = row.byClass('row-thumb')[0], img = thumb.byTag('img')[0];
  const id = idFromData(SHOWN[5].videos[0].url);
  const u = (n) => 'https://i.ytimg.com/vi/' + id + '/' + n + '.jpg';
  img.naturalWidth = 120; img.naturalHeight = 90; img.fire('load');
  img.fire('error');
  const fellBack = !thumb.byTag('img').length && thumb.byClass('singles-thumb-fallback').length === 1;
  img.fire('error'); img.fire('load');
  check('5a. 320px → 480px → 代替表示と下げて繰り返さず、枠とリンクは残る',
    img.srcHistory.join() === [u('mqdefault'), u('hqdefault')].join() && fellBack && thumb.className === 'row-thumb' && thumb.href === SHOWN[5].videos[0].url && !!thumb.getAttribute('aria-label'), img.srcHistory.join());
}

// ---- 6. 動画IDが取れないURL ----
{
  const base = PLAYS[0];
  const fixture = [
    Object.assign({}, base, { id: 'fx-bad', videos: [{ title: 'x', url: 'https://video.invalid/watch?v=Ac-DypNuXyc', publishedDate: '2026-02-01' }] }),
    Object.assign({}, base, { id: 'fx-short', videos: [{ title: 'x', url: 'https://youtu.be/Ac-DypNuXyc', publishedDate: '2026-01-01' }] }),
  ];
  const kinds = renderSingles(fixture).rows().map((c) => (c.byTag('img')[0] ? c.byTag('img')[0].src : 'fallback'));
  check('6. 動画IDの無いURLは推測せず代替表示、youtu.be 形式は動画IDを使う', kinds.join() === 'fallback,https://i.ytimg.com/vi/Ac-DypNuXyc/mqdefault.jpg', kinds.join(' | '));
}

// ---- 7. 検索・絞り込み ----
{
  const s = renderSingles();
  const el = (id) => s.doc.getElementById(id);
  const set = (values) => {
    ['search-input', 'genre-select', 'game-select', 'agency-select', 'streamer-select', 'format-select'].forEach((id) => { el(id).value = values[id] || ''; });
    el('search-input').fire('input'); return s.rows();
  };
  const exp = (pred) => urlsOf(SHOWN.filter(pred));
  const got = (list) => list.map(keyOf).join();
  const one = PLAYS.find((p) => p.format === 'multi');
  const agencyOf = vm.runInContext('agencyOf', s.ctx);
  const cases = [
    [{ 'search-input': '夜勤清掃' }, (p) => [p.title, p.game, p.note].join(' ').includes('夜勤清掃')],
    [{ 'genre-select': one.genre }, (p) => p.genre === one.genre],
    [{ 'game-select': one.game }, (p) => p.game === one.game],
    [{ 'agency-select': agencyOf(one.streamer) }, (p) => agencyOf(p.streamer) === agencyOf(one.streamer)],
    [{ 'streamer-select': one.streamer }, (p) => p.streamer === one.streamer],
    [{ 'format-select': 'single' }, (p) => p.format === 'single'],
    [{ 'format-select': 'multi' }, (p) => p.format === 'multi'],
    [{ 'genre-select': one.genre, 'agency-select': agencyOf(one.streamer), 'format-select': 'multi' }, (p) => p.genre === one.genre && agencyOf(p.streamer) === agencyOf(one.streamer) && p.format === 'multi'],
  ];
  const bad = cases.map(([v, pred], i) => (got(set(v)) === exp(pred) && exp(pred) ? null : i)).filter((x) => x !== null);
  const none = set({ 'search-input': '存在しないゲーム名' });
  check('7. キーワード・ジャンル・ゲーム・事務所・実況者・形式と、その組み合わせで絞り込める。該当なしは空表示', bad.length === 0 && none.length === 0 && s.grid.byClass('empty-state').length === 1, 'cases ' + bad.join());
  set({}); el('page-next').fire('click');
  el('format-select').value = 'single'; el('format-select').fire('change');
  check('7b. 条件を変えると1ページ目に戻る', el('page-indicator').textContent.startsWith('1 / '));
}

// ---- 9. 並べ替え ----
{
  const s = renderSingles();
  const th = (k) => s.doc.sortHeaders.find((h) => h.dataset.sort === k);
  const arrows = () => s.doc.sortHeaders.map((h) => h.dataset.sort + h.arrow.textContent).join();
  const initial = arrows();
  const bad = [];
  for (const [key, value] of [['posted', first], ['updated', last], ['count', (p) => p.videos.length]]) {
    // 現在の列でなければ降順から始まり、もう一度押すと昇順
    for (const dir of key === 'posted' ? [1, -1] : [-1, 1]) {
      s.doc.getElementById('page-next').fire('click');
      th(key).fire('click');
      if (!s.doc.getElementById('page-indicator').textContent.startsWith('1 / ')) bad.push(key + dir + ' page');
      if (s.rows().map(keyOf).join() !== urlsOf(ordered(value, dir))) bad.push(key + dir);
      if (th(key).arrow.textContent !== (dir === 1 ? '▲' : '▼') || th(key).getAttribute('aria-sort') !== (dir === 1 ? 'ascending' : 'descending')) bad.push(key + dir + ' arrow');
    }
  }
  check('9a. 初期は投稿日の降順。投稿日・更新日・動画数を全件に対して昇順・降順で並べ替え、1ページ目に戻って矢印を出す', initial === 'count,posted▼,updated' && bad.length === 0, initial + ' ' + bad.join());
  const sel = s.doc.getElementById('sort-select'); sel.value = 'count-asc'; sel.fire('change');
  check('9b. 並べ替えセレクト(スマホ幅)でも並べ替えられる', s.rows().map(keyOf).join() === urlsOf(ordered((p) => p.videos.length, 1)));
  check('9c. 元データ(STANDALONE_PLAYS)の順番は変わらない', vm.runInContext('STANDALONE_PLAYS', s.ctx).map((x) => x.id).join() === PLAYS.map((x) => x.id).join());
  const v = (n, d) => ({ title: 't' + n, url: 'https://www.youtube.com/watch?v=fixture000' + n, publishedDate: d });
  const mk = (id, videos, extra) => Object.assign({}, PLAYS[0], { id, title: id, format: videos.length > 1 ? 'multi' : 'single', videos }, extra || {});
  const fx = renderSingles([mk('none', [v(0)]), mk('old', [v(1, '2025-01-01')]), mk('partial', [v(2, '2027-01-01'), v(3, '')]), mk('new', [v(4, '2026-03-02'), v(5, '2026-01-05')]),
    mk('invalid', [v(6, '2026-02-30')]), mk('short', [v(7, '2026-05-05')], { videoCount: 3 })]);
  const titles = () => fx.rows().map((c) => c.byClass('title-link')[0].textContent).join();
  const unknown = fx.rows().filter((c) => c.children[6].textContent === '—' && c.children[7].textContent === '—').length;
  const desc = titles(); fx.doc.sortHeaders.find((h) => h.dataset.sort === 'posted').fire('click'); const asc = titles();
  const multiRow = fx.rows().find((c) => c.byClass('title-link')[0].textContent === 'new');
  check('9d. 公開日が1本でも不明・不正・未登録なら「—」で、昇順・降順とも末尾。複数本は最古を投稿日・最新を更新日',
    unknown === 4 && desc.startsWith('new,old,') && asc.startsWith('old,new,') && multiRow.children[6].textContent === '2026/01/05' && multiRow.children[7].textContent === '2026/03/02', [unknown, desc, asc].join(' | '));
}

// ---- 8. singles.html の検索向け情報は変えない ----
// (共通メニューの追加などページ全体の変更はありうるため、ファイルの差分ではなく title・H1・description・canonical を直接確かめる)
{
  const html = read('singles.html');
  const count = (s) => html.split(s).length - 1;
  check('8. singles.html(title・H1・description・canonical)は変更なし',
    count('<title>単発・専用再生リストなし実況一覧 | ぶいゲー</title>') === 1 && count('<h1 class="page-title">単発・専用再生リストなし実況</h1>') === 1 &&
    count('<meta name="description" content="VTuberの単発ゲーム実況、複数回プレイだが専用再生リストがない実況、雑多な再生リストに混在する実況をまとめています。">') === 1 &&
    count('<link rel="canonical" href="https://vgame-navi.jp/singles.html">') === 1);
}

console.log('\nPASS: ' + pass + '  FAIL: ' + fail);
process.exit(fail ? 1 : 0);
