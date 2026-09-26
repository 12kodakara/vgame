/**
 * VTuber詳細「このVTuberが実況したゲーム」全件リンク化の回帰テスト。ブラウザ不要(node test-streamer-games.js)。
 *
 * streamer.js の描画処理を最小限の DOM の上で全VTuberについて実際に動かし、次を確かめる。
 *   1. 実況したゲームが全件、通常の <a href> として描画時に DOM に入る(クリック後に生成しない)
 *      最初の10件は通常表示、11件目以降は <details>(初期状態は閉じる)の中
 *   2. リンク先は実在する正規ゲームのURL(gameUrl 形式・sitemap と一致)・重複なし・noindex ゲームへのリンクなし
 *   3. 10件以下 / 11件以上 / 大量(100件超)の各ケース・0件の VTuber は欄ごと非表示
 *   4. 展開UIの構造(summary・残り件数・末尾の閉じるボタン)と CSS
 *   5. title / description / H1 / canonical を変えていない
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
console.log('=== VTuber詳細「実況したゲーム」全件リンク 回帰テスト ===');

// ---- 最小限の DOM(描画処理が触る操作だけを記録する) ----
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
  focus() {} blur() {} scrollIntoView() {} click() { (this.listeners.click || []).forEach((f) => f({ preventDefault() {}, target: this })); }
  cloneNode() { return new El(this.tagName, this.doc); }
}
function makeDocument(html) {
  const doc = { byId: {}, title: '', listeners: {} };
  doc.createElement = (t) => new El(t, doc);
  doc.createTextNode = (t) => Object.assign(new El('#text', doc), { _text: String(t) });
  doc.createDocumentFragment = () => new El('#fragment', doc);
  doc.head = new El('head', doc); doc.body = new El('body', doc); doc.documentElement = new El('html', doc);
  doc.body.classList.contains = () => false;
  // HTML 中の id を持つ要素(hidden 属性・details の初期状態も反映)
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
const streamerHtml = read('streamer.html');
// details 内の summary / 閉じるボタン(id を持たない summary は details の子として用意する)
function renderFor(name) {
  const doc = makeDocument(streamerHtml);
  const details = doc.getElementById('streamer-games-more');
  const summary = new El('summary', doc); details.appendChild(summary);
  const storage = { getItem: () => null, setItem: () => {}, removeItem: () => {} };
  const ctx = {
    console, document: doc, localStorage: storage, sessionStorage: storage, navigator: { userAgent: 'node' }, URLSearchParams, URL, encodeURIComponent, decodeURIComponent,
    location: { search: '?streamer=' + encodeURIComponent(name), href: 'https://vgame-navi.jp/streamer.html?streamer=' + encodeURIComponent(name), pathname: '/streamer.html', hash: '' },
    history: { replaceState() {}, pushState() {} }, setTimeout: () => 0, clearTimeout() {}, requestAnimationFrame: () => 0, matchMedia: () => ({ matches: false, addEventListener() {} }),
    IntersectionObserver: class { observe() {} disconnect() {} }, scrollTo() {}, innerWidth: 1366, innerHeight: 900,
  };
  ctx.window = ctx; ctx.window.addEventListener = () => {};
  vm.createContext(ctx);
  for (const f of ['data-core.js', 'data-counts.js', 'data-playlists.js', 'common.js']) vm.runInContext(read(f), ctx, { filename: f });
  // 分割データの読み込み(非同期)を省き、全件データから同じ関数で渡す
  vm.runInContext('startDetailPage = function (kind, key, getItems, render) { render(getItems(key), null); };', ctx);
  vm.runInContext(read('streamer.js'), ctx, { filename: 'streamer.js' });
  return { doc, ctx, details, summary };
}

// ---- データ ----
const dctx = {}; vm.createContext(dctx);
for (const f of ['data-core.js', 'data-playlists.js']) vm.runInContext(read(f), dctx);
const GAMES = vm.runInContext('GAMES', dctx), STREAMERS = vm.runInContext('STREAMERS', dctx), PLAYLISTS = vm.runInContext('PLAYLISTS', dctx);
const gameNames = new Set(GAMES.map((g) => g.name)), withPlays = new Set(PLAYLISTS.map((p) => p.game));
const played = {}; for (const p of PLAYLISTS) (played[p.streamer] = played[p.streamer] || new Set()).add(p.game);
const xmlDecode = (s) => s.replace(/&apos;/g, "'").replace(/&quot;/g, '"').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&');
const sitemap = new Set([...read('sitemap.xml').matchAll(/<loc>([^<]*)<\/loc>/g)].map((m) => new URL(xmlDecode(m[1])).href));

// ---- 1〜3. 全VTuberで描画して検査 ----
const problems = []; let totalLinks = 0; const cases = { zero: 0, upTo10: 0, over10: 0, over100: 0 };
let listenerRenders = 0;
for (const s of STREAMERS) {
  let r;
  try { r = renderFor(s.name); } catch (e) { problems.push(s.name + ': 描画エラー ' + e.message); continue; }
  const exp = played[s.name] || new Set();
  const sec = r.doc.getElementById('streamer-games-section');
  const first = r.doc.getElementById('streamer-games-list').querySelectorAll('a');
  const rest = r.doc.getElementById('streamer-games-rest').querySelectorAll('a');
  const all = [...first, ...rest]; totalLinks += all.length;
  if (exp.size === 0) { cases.zero++; if (!sec.hidden || all.length) problems.push(s.name + ': 0件なのに欄が表示'); continue; }
  if (exp.size <= 10) cases.upTo10++; else cases.over10++; if (exp.size > 100) cases.over100++;
  if (sec.hidden) problems.push(s.name + ': 欄が非表示');
  if (all.length !== exp.size) problems.push(s.name + ': リンク ' + all.length + ' ≠ 実況ゲーム ' + exp.size);
  if (first.length !== Math.min(10, exp.size)) problems.push(s.name + ': 通常表示 ' + first.length + ' 件');
  if (r.details.hidden !== (exp.size <= 10) || r.details.open) problems.push(s.name + ': 折りたたみの初期状態が不正');
  if (exp.size > 10 && r.doc.getElementById('streamer-games-rest-count').textContent !== String(exp.size - 10)) problems.push(s.name + ': 残り件数の表示');
  const hrefs = all.map((a) => a.getAttribute('href'));
  if (new Set(hrefs).size !== hrefs.length) problems.push(s.name + ': 重複リンク');
  for (const href of hrefs) {
    const g = decodeURIComponent(href.slice('game.html?game='.length));
    if (!href.startsWith('game.html?game=') || href !== 'game.html?game=' + encodeURIComponent(g)) problems.push(s.name + ': URL 形式 ' + href);
    else if (!gameNames.has(g)) problems.push(s.name + ': 存在しないゲーム ' + g);
    else if (!withPlays.has(g)) problems.push(s.name + ': noindex ゲーム ' + g);
    else if (!exp.has(g)) problems.push(s.name + ': 実況していないゲーム ' + g);
    else if (!sitemap.has(new URL(href, 'https://vgame-navi.jp/').href)) problems.push(s.name + ': sitemap に無い ' + href);
  }
  // 11件以上: 末尾の「閉じる」を押しても一覧は作り直さない(リンクはクリック前から DOM にある)
  if (exp.size > 10) {
    const before = rest.length;
    r.details.open = true; r.doc.getElementById('streamer-games-close').click();
    if (r.details.open || r.doc.getElementById('streamer-games-rest').querySelectorAll('a').length !== before) listenerRenders++;
  }
}
check('1a. 全VTuber(' + STREAMERS.length + ')を描画し、実況したゲームが全件 <a href> として DOM に入る(計 ' + totalLinks + ' リンク)', problems.length === 0, problems.slice(0, 5).join('\n         '));
check('1b. 末尾の「閉じる」は details を閉じるだけで、リンクを作り直さない', listenerRenders === 0, listenerRenders + ' 件');
const js = read('streamer.js');
const gamesBlock = (/\/\/ ---------- このVTuberが実況したゲーム一覧 ----------([\s\S]*?)\/\/ ---------- よく実況しているジャンル/.exec(js) || [])[1] || '';
const listenerBody = (/addEventListener\("click", \(\) => \{([\s\S]*?)\}\);/.exec(gamesBlock) || [])[1] || 'x';
check('1c. クリック時にリンクを生成する処理が無い(addItems / createCountIndexItem はイベントの外)', !/addItems|createCountIndexItem|appendChild/.test(listenerBody) && /addItems\(gamesRest, rest\);/.test(gamesBlock));
check('3a. ケースを網羅: 0件 ' + cases.zero + ' / 10件以下 ' + cases.upTo10 + ' / 11件以上 ' + cases.over10 + ' / 100件超 ' + cases.over100, cases.zero > 0 && cases.upTo10 > 0 && cases.over10 > 0 && cases.over100 > 0);

// ---- 4. 展開UI ----
check('4a. streamer.html: 11件目以降は <details id="streamer-games-more" hidden> の中の #streamer-games-rest(index-list)',
  /<details class="more-details" id="streamer-games-more" hidden>\s*<summary><span class="more-details-open">ほか<span id="streamer-games-rest-count"><\/span>件のゲームを表示<\/span><span class="more-details-close">閉じる<\/span><\/summary>\s*<ul class="index-list" id="streamer-games-rest"><\/ul>\s*<button type="button" class="more-toggle" id="streamer-games-close">閉じる ↑<\/button>\s*<\/details>/.test(streamerHtml));
check('4a2. 「最近更新された実況」(「すべての再生リスト」の先頭5件と同じ内容)は置かない',
  !/streamer-recent|最近更新された実況/.test(streamerHtml) && !/streamer-recent|recentUpdated/.test(js));
check('4b. 旧「もっと見る」ボタン(クリックで一覧を作り直す方式)が残っていない', !/<button[^>]*id="streamer-games-more"/.test(streamerHtml) && !/gamesMoreBtn|renderGameList/.test(js));
const css = read('style.css');
check('4c. CSS: summary はリンク風・開閉で文言と ▼▲ が切り替わる', /\.more-details > summary \{[^}]*list-style: none;/.test(css) && /\.more-details\[open\] \.more-details-open/.test(css) && /\.more-details\[open\] > summary::after \{\s*content: " ▲";/.test(css));

// ---- 5. メタデータ ----
// description は buildStreamerDescription で作る(内容は test-streamer-description.js で検査)
check('5a. title / canonical の生成(setPageMeta 呼び出し)は従来どおり・description は buildStreamerDescription',
  /setPageMeta\(\s*streamer \+ "のゲーム実況・再生リスト一覧 \| " \+ SITE_NAME,\s*buildStreamerDescription\(streamer, items, standalone\),\s*"\/streamer\.html\?streamer=" \+ encodeURIComponent\(streamer\),/.test(js));
check('5b. H1・見出しは従来どおり(元のHTMLに canonical なし)', /<h1 class="page-title" id="page-title">実況者の再生リスト<\/h1>/.test(streamerHtml) && /<h2>このVTuberが実況したゲーム<\/h2>/.test(streamerHtml) && !/<link rel="canonical"/.test(streamerHtml));
const sample = renderFor('姫森ルーナ');
check('5c. 描画後の title / canonical(大量ゲームVTuberで確認)',
  sample.doc.title === '姫森ルーナのゲーム実況・再生リスト一覧 | ぶいゲー'
  && sample.doc.head.children.some((e) => e.tagName === 'LINK' && e.getAttribute('rel') === 'canonical' && e.getAttribute('href') === 'https://vgame-navi.jp/streamer.html?streamer=' + encodeURIComponent('姫森ルーナ')), sample.doc.title);

console.log('');
console.log('PASS: ' + pass + '  FAIL: ' + fail);
process.exit(fail ? 1 : 0);
