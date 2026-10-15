/**
 * 単発・PLなし実況ページ(singles.html)のサムネイル表示の回帰テスト。ブラウザ不要(node test-singles-thumbnails.js)。
 *
 * singles.js を最小限の DOM の上で実際に動かし、次を確かめる。
 *   1. 登録済みの全件にカードがあり、上部にサムネイル(16:9 の枠・alt・遅延読み込み)がある
 *   2. サムネイルの画像は「YouTubeで見る」と同じ動画URLの動画IDから作る(データの動画IDと一致)
 *   3. サムネイルのリンクは「YouTubeで見る」と同じ動画へ、別タブ・noopener で開く
 *   4. カードの情報(ゲーム名・形式バッジ・VTuber名・動画タイトル・動画数・YouTubeで見る・ゲーム詳細)を維持
 *   5. 画像が無いとき(YouTube の 120×90 の灰色画像・読み込み失敗)は 480px → 320px → 代替表示と下げ、繰り返さない
 *   6. 動画IDが取れないURLは推測せず代替表示
 *   7. ゲーム名・VTuber名の検索、形式の絞り込みは従来どおり
 *   8. singles.html(title・H1・description・canonical)は変更しない
 * 失敗が1件でもあれば終了コード1。
 */
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const { execFileSync } = require('child_process');

const ROOT = __dirname;
const read = (f) => fs.readFileSync(path.join(ROOT, f), 'utf8');
let pass = 0, fail = 0;
function check(name, ok, detail) {
  if (ok) { pass++; console.log('  [PASS] ' + name); } else { fail++; console.log('  [FAIL] ' + name + (detail ? '\n         ' + String(detail).slice(0, 400) : '')); }
}
console.log('=== 単発・PLなし実況ページ サムネイル表示 回帰テスト ===');

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
  doc.querySelector = () => null; doc.querySelectorAll = () => [];
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
  const grid = doc.getElementById('single-grid');
  return { doc, ctx, grid, cards: () => grid.children.filter((c) => c.tagName === 'ARTICLE') };
}

// ---- データ ----
const dctx = {}; vm.createContext(dctx);
for (const f of ['data-core.js', 'data-standalone.js', 'common.js']) {
  try { vm.runInContext(read(f), dctx); } catch (e) { /* common.js のページ用処理は document が無いと動かないが、関数定義だけ使う */ }
}
const PLAYS = vm.runInContext('STANDALONE_PLAYS', dctx);
// 一覧の表示順(追加日の新しい順・同じ追加日は登録順)。実装の並べ替えは使わず、登録位置を明示した比較で独立に作る
const byShownOrder = (list) => list.map((p, i) => ({ p, i }))
  .sort((a, b) => ((b.p.addedDate || '') > (a.p.addedDate || '') ? 1 : (b.p.addedDate || '') < (a.p.addedDate || '') ? -1 : a.i - b.i))
  .map((x) => x.p);
const SHOWN = byShownOrder(PLAYS);
// 形式ごとのバッジ表示(common.js の playFormatLabel の仕様)。実装の関数は使わず、期待値をここで固定する
const FORMAT_BADGE = { single: '単発', multi: '複数回・PLなし', 'mixed-playlist': '雑多PL内' };
// データの動画URLから動画IDを独立に取り出す(実装とは別の方法)
const idFromData = (url) => { const m = /^https:\/\/www\.youtube\.com\/watch\?v=([A-Za-z0-9_-]{11})$/.exec(url); return m ? m[1] : null; };

const r = renderSingles();
const cards = r.cards();

// ---- 1〜4. 全件のカード ----
{
  // 件数は固定しない(単発実況を追加しても壊れないように)。0件で「0 = 0」と通らないよう1件以上、id の重複なしも確かめる
  check('1a. 登録済みの全 ' + PLAYS.length + ' 件にカードがあり、件数表示も一致', PLAYS.length > 0 && new Set(PLAYS.map((p) => p.id)).size === PLAYS.length && cards.length === PLAYS.length && r.doc.getElementById('result-count').textContent === PLAYS.length + ' 件');
  const problems = [];
  cards.forEach((card, i) => {
    const item = SHOWN[i];
    const id = idFromData((item.videos[0] || {}).url || '');
    const thumb = card.children[0];
    if (!thumb || thumb.className !== 'singles-thumb' || thumb.tagName !== 'A') { problems.push(item.id + ': 先頭にサムネイルが無い'); return; }
    const img = thumb.byTag('img')[0];
    if (!img) { problems.push(item.id + ': img が無い'); return; }
    if (!id) problems.push(item.id + ': データに動画IDが無い');
    if (img.src !== 'https://i.ytimg.com/vi/' + id + '/hqdefault.jpg') problems.push(item.id + ': src ' + img.src);
    // srcset の幅指定は使わない(naturalWidth が画面の密度で割られ、YouTube の灰色画像を見分けられなくなるため)
    if (img.hasAttribute('srcset')) problems.push(item.id + ': srcset がある');
    if (img.width !== 480 || img.height !== 270) problems.push(item.id + ': 枠の大きさ ' + img.width + 'x' + img.height);
    if (!img.alt || !img.alt.includes(item.title)) problems.push(item.id + ': alt ' + img.alt);
    if (img.decoding !== 'async' || img.loading !== (i < 3 ? 'eager' : 'lazy')) problems.push(item.id + ': 読み込み設定 ' + img.loading + '/' + img.decoding);
    // 3. リンク先は「YouTubeで見る」と同じ動画
    const actions = card.byClass('play-actions')[0];
    const [yt, detail] = actions.byTag('a');
    if (thumb.href !== item.videos[0].url || yt.href !== item.videos[0].url || thumb.href !== yt.href) problems.push(item.id + ': リンク先 ' + thumb.href + ' / ' + yt.href);
    if (thumb.target !== '_blank' || !/\bnoopener\b/.test(thumb.rel)) problems.push(item.id + ': 外部リンクの属性 ' + thumb.target + ' ' + thumb.rel);
    // 4. カードの情報
    const h3 = card.byTag('h3')[0];
    const badge = h3.byClass('format-badge')[0];
    if (h3.textContent !== vm.runInContext('gameDisplayName', r.ctx)(item.game) + ' ' + badge.textContent || badge.textContent !== FORMAT_BADGE[item.format]) problems.push(item.id + ': ゲーム名・バッジ ' + h3.textContent);
    const ps = card.byTag('p');
    const streamerLink = ps[0].byTag('a')[0];
    if (!streamerLink || streamerLink.textContent !== item.streamer || streamerLink.href !== 'streamer.html?streamer=' + encodeURIComponent(item.streamer)) problems.push(item.id + ': VTuber名');
    if (ps[1].className !== 'singles-title' || ps[1].textContent !== item.title || ps[1].title !== item.title) problems.push(item.id + ': 動画タイトル(全文の title 属性)');
    if (ps[2].textContent !== '動画数: ' + item.videos.length + '本') problems.push(item.id + ': 動画数 ' + ps[2].textContent);
    if (yt.textContent !== 'YouTubeで見る' || yt.target !== '_blank' || yt.rel !== 'noopener') problems.push(item.id + ': YouTubeで見る');
    if (!detail || detail.textContent !== 'ゲーム詳細' || detail.href !== 'game.html?game=' + encodeURIComponent(item.game)) problems.push(item.id + ': ゲーム詳細 ' + (detail && detail.href));
  });
  check('1b〜4. 全カード: 先頭にサムネイル(16:9 の枠 480×270・alt・先頭3枚以外は遅延読み込み)、画像は動画IDから生成、リンクは「YouTubeで見る」と同じ動画、ほかの情報は維持', problems.length === 0, problems.slice(0, 6).join(' / '));
  const ids = cards.map((c) => (c.byTag('img')[0] || {}).src);
  check('2. サムネイルの動画IDはすべて別(同じ画像を重複して読み込まない)', new Set(ids).size === ids.length);
}

// ---- 5. 画像が無いときの切り替え ----
{
  const card = cards[5];
  const thumb = card.children[0], img = thumb.byTag('img')[0];
  const id = idFromData(SHOWN[5].videos[0].url);
  const u = (s) => 'https://i.ytimg.com/vi/' + id + '/' + s + '.jpg';
  // 通常の画面: 1段目(480px)が YouTube の灰色画像(120×90)
  img.naturalWidth = 120; img.naturalHeight = 90; img.fire('load');
  const s2 = img.src;
  img.fire('error'); // 2段目(320px)が読み込み失敗
  const fellBack = !thumb.byTag('img').length && thumb.byClass('singles-thumb-fallback').length === 1;
  const before = img.srcHistory.length;
  img.fire('error'); img.fire('load'); // 代替表示の後に来たイベントでは何もしない
  check('5a. 画像が無いときは 480px → 320px → 代替表示「▶ YouTubeで見る」と下げ、リンクと aria-label は残る',
    img.srcHistory[0] === u('hqdefault') && s2 === u('mqdefault') && fellBack && thumb.href === SHOWN[5].videos[0].url && !!thumb.getAttribute('aria-label'), [img.srcHistory.join(','), fellBack].join(' | '));
  check('5b. 読み込み直しは段数(2回)までで、代替表示の後は繰り返さない', img.srcHistory.length === 2 && img.srcHistory.length === before, img.srcHistory.join(' , '));
  // 高解像度の画面(2倍): 640px → 480px → 320px → 代替表示
  const hd = renderSingles(null, 2), hcard = hd.cards()[5], himg = hcard.children[0].byTag('img')[0];
  const first = himg.src;
  himg.naturalWidth = 120; himg.naturalHeight = 90; himg.fire('load'); himg.fire('error'); himg.fire('load');
  const hFell = !hcard.children[0].byTag('img').length; himg.fire('error');
  check('5e. 高解像度の画面では 640px から始め、480px → 320px → 代替表示(最大3回)',
    first === u('sddefault') && himg.srcHistory.join() === [u('sddefault'), u('hqdefault'), u('mqdefault')].join() && hFell && himg.srcHistory.length === 3, himg.srcHistory.join(' , '));
  // 正常な画像(320×180 など)では切り替えない
  const ok = cards[6].byTag('img')[0]; ok.naturalWidth = 480; ok.naturalHeight = 360; ok.fire('load');
  check('5c. 正常に読み込めた画像はそのまま(切り替えない)', ok.srcHistory.length === 1 && cards[6].children[0].byTag('img').length === 1);
  // 1枚が失敗しても他のカードは変わらない
  check('5d. 1枚の失敗は他のカードに影響しない', cards.filter((c) => c.children[0].byTag('img').length).length === cards.length - 1);
}

// ---- 6. 動画IDが取れないURL ----
{
  const base = PLAYS[0];
  const fixture = [
    Object.assign({}, base, { id: 'fx-mixed', format: 'mixed-playlist', mixedPlaylistUrl: 'https://www.youtube.com/playlist?list=PLxxxxxxxxxxxx' }),
    Object.assign({}, base, { id: 'fx-bad', videos: [{ title: 'x', url: 'https://video.invalid/watch?v=Ac-DypNuXyc', publishedDate: '2026-01-01' }] }),
    Object.assign({}, base, { id: 'fx-short', videos: [{ title: 'x', url: 'https://youtu.be/Ac-DypNuXyc', publishedDate: '2026-01-01' }] }),
  ];
  const fr = renderSingles(fixture), fc = fr.cards();
  const kinds = fc.map((c) => (c.children[0].byTag('img')[0] ? c.children[0].byTag('img')[0].src : 'fallback'));
  check('6. 動画IDの無いURL(再生リスト・YouTube以外)は推測せず代替表示、youtu.be 形式は動画IDを使う',
    kinds[0] === 'fallback' && kinds[1] === 'fallback' && kinds[2] === 'https://i.ytimg.com/vi/Ac-DypNuXyc/hqdefault.jpg', kinds.join(' | '));
}

// ---- 7. 検索・絞り込み ----
{
  const s = renderSingles();
  const input = s.doc.getElementById('single-search'), format = s.doc.getElementById('format-select');
  const search = (q) => { input.value = q; input.fire('input'); return s.cards().map((c) => c.byTag('h3')[0].textContent + '/' + c.byTag('p')[0].textContent); };
  const byGame = search('夜勤清掃');
  const byStreamer = search('熱千めら');
  const none = search('存在しないゲーム名');
  const emptyShown = s.grid.byClass('empty-state').length === 1;
  search('');
  format.value = 'multi'; format.fire('change'); const multi = s.cards().length;
  format.value = 'single'; format.fire('change'); const single = s.cards().length;
  const exp = (pred) => PLAYS.filter(pred).length;
  check('7. 検索・絞り込み: ゲーム名「夜勤清掃」' + byGame.length + '件・VTuber名「熱千めら」' + byStreamer.length + '件・該当なしは空表示・形式「複数回」' + multi + '件・「単発」' + single + '件',
    byGame.length === exp((x) => x.game === '夜勤清掃') && byStreamer.length === exp((x) => x.streamer === '熱千めら') && none.length === 0 && emptyShown &&
    multi === exp((x) => x.format === 'multi') && single === exp((x) => x.format === 'single'), [byGame.length, byStreamer.length, none.length, emptyShown, multi, single].join(','));
  // 検索で作り直しても、サムネイルのURLは同じ(ブラウザのキャッシュが使われる)
  // 形式の絞り込み(single / multi / すべて)ごとに、表示されるカードのサムネイルが、その条件に合う実況の先頭の動画と同じ順で一致するかを見る
  const thumbsFor = (f) => { format.value = f; format.fire('change'); return s.cards().map((c) => c.byTag('img')[0].src).join(); };
  const expectThumbs = (f) => SHOWN.filter((x) => !f || x.format === f).map((x) => 'https://i.ytimg.com/vi/' + idFromData(x.videos[0].url) + '/hqdefault.jpg').join();
  const thumbFails = ['single', 'multi', ''].filter((f) => thumbsFor(f) !== expectThumbs(f));
  check('7b. 作り直し後もサムネイルの URL は同じ(単発・複数回・すべての絞り込みそれぞれ)', thumbFails.length === 0, thumbFails.map((f) => f || 'すべて').join(','));
}

// ---- 9. 並び順(追加日の新しい順・同じ追加日は登録順・元データは変えない) ----
{
  const s = renderSingles();
  const shownIds = s.cards().map((c) => c.byTag('img')[0].src);
  const expectIds = SHOWN.map((x) => 'https://i.ytimg.com/vi/' + idFromData(x.videos[0].url) + '/hqdefault.jpg');
  const dates = SHOWN.map((x) => x.addedDate || '');
  const desc = dates.every((d, i) => i === 0 || dates[i - 1] >= d);
  const srcOrder = vm.runInContext('STANDALONE_PLAYS', s.ctx).map((x) => x.id).join();
  check('9a. 一覧は追加日の新しい順(先頭 ' + dates[0] + '・末尾 ' + dates[dates.length - 1] + ')で、同じ追加日の中は登録順',
    shownIds.join() === expectIds.join() && desc, shownIds.slice(0, 3).join(' , '));
  check('9b. 並べ替えは表示用の配列だけで、元データ(STANDALONE_PLAYS)の順番は変わらない', srcOrder === PLAYS.map((x) => x.id).join());
  // 追加日の無いものは最後、同じ日付の中は登録順(テスト用データで確かめる)
  const base = PLAYS[0];
  const fx = [['fx-a', '2026-01-01'], ['fx-b', '2026-03-01'], ['fx-c', undefined], ['fx-d', '2026-03-01'], ['fx-e', '2026-02-01']]
    .map(([id, d], i) => Object.assign({}, base, { id, addedDate: d, videos: [{ title: id, url: 'https://www.youtube.com/watch?v=fixture000' + i, publishedDate: '2026-01-01' }] }));
  const order = renderSingles(fx).cards().map((c) => (/\/vi\/fixture000(\d)\//.exec(c.byTag('img')[0].src) || [])[1]);
  check('9c. 同じ追加日は登録順、追加日の無いものは最後(fx-b → fx-d → fx-e → fx-a → fx-c)', order.join() === ['1', '3', '4', '0', '2'].join(), order.join());
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
