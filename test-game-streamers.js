/**
 * ゲーム詳細「このゲームを実況しているVTuber」全件リンク化の回帰テスト。ブラウザ不要(node test-game-streamers.js)。
 *
 * game.js の描画処理を最小限の DOM の上で全ゲームについて実際に動かし、次を確かめる。
 *   1. 実況しているVTuberが全員、通常の <a href> として描画時に DOM に入る(クリック後に生成しない)
 *      最初の10組は通常表示、11組目以降は <details>(初期状態は閉じる)の中
 *   2. リンク先は実在する正規VTuberのURL(streamerUrl 形式・sitemap と一致)・重複なし・noindex VTuber へのリンクなし
 *   3. 10組以下 / 11組以上 / 大量(100組超)の各ケース・再生リスト0件のゲームは欄ごと非表示
 *   4. 展開UIの構造(summary・残り組数・末尾の閉じるボタン)
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
console.log('=== ゲーム詳細「実況しているVTuber」全件リンク 回帰テスト ===');

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
const gameHtml = read('game.html');
// details 内の summary / 閉じるボタン(id を持たない summary は details の子として用意する)
// seriesPages を渡すと、data-series.js の代わりにその定義(テスト用 fixture)を使う。本番ファイルは書き換えない
function renderFor(name, seriesPages) {
  const doc = makeDocument(gameHtml);
  const details = doc.getElementById('game-streamer-more');
  const summary = new El('summary', doc); details.appendChild(summary);
  const storage = { getItem: () => null, setItem: () => {}, removeItem: () => {} };
  const ctx = {
    console, document: doc, localStorage: storage, sessionStorage: storage, navigator: { userAgent: 'node' }, URLSearchParams, URL, encodeURIComponent, decodeURIComponent,
    location: { search: '?game=' + encodeURIComponent(name), href: 'https://vgame-navi.jp/game.html?game=' + encodeURIComponent(name), pathname: '/game.html', hash: '' },
    history: { replaceState() {}, pushState() {} }, setTimeout: () => 0, clearTimeout() {}, requestAnimationFrame: () => 0, matchMedia: () => ({ matches: false, addEventListener() {} }),
    IntersectionObserver: class { observe() {} disconnect() {} }, scrollTo() {}, innerWidth: 1366, innerHeight: 900,
  };
  ctx.window = ctx; ctx.window.addEventListener = () => {};
  vm.createContext(ctx);
  // game.html と同じく data-series.js を読む。fixture のときは読まずに同名のグローバルとして置く(const は上書きできないため)
  if (seriesPages) ctx.SERIES_PAGES = seriesPages;
  for (const f of ['data-core.js', 'data-counts.js', 'data-playlists.js'].concat(seriesPages ? [] : ['data-series.js'], ['common.js'])) vm.runInContext(read(f), ctx, { filename: f });
  // 分割データの読み込み(非同期)を省き、全件データから同じ関数で渡す
  vm.runInContext('startDetailPage = function (kind, key, getItems, render) { render(getItems(key), null); };', ctx);
  vm.runInContext('Math.random = () => 0.42;', ctx); // 関連ゲームのシャッフルを固定(このテストの対象外)
  vm.runInContext(read('game.js'), ctx, { filename: 'game.js' });
  return { doc, ctx, details, summary };
}

// ---- データ ----
const dctx = {}; vm.createContext(dctx);
for (const f of ['data-core.js', 'data-playlists.js']) vm.runInContext(read(f), dctx);
const GAMES = vm.runInContext('GAMES', dctx), STREAMERS = vm.runInContext('STREAMERS', dctx), PLAYLISTS = vm.runInContext('PLAYLISTS', dctx);
const streamerNames = new Set(STREAMERS.map((s) => s.name)), withPlays = new Set(PLAYLISTS.map((p) => p.streamer));
const played = {}; for (const p of PLAYLISTS) (played[p.game] = played[p.game] || new Set()).add(p.streamer);
const xmlDecode = (s) => s.replace(/&apos;/g, "'").replace(/&quot;/g, '"').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&');
const sitemap = new Set([...read('sitemap.xml').matchAll(/<loc>([^<]*)<\/loc>/g)].map((m) => new URL(xmlDecode(m[1])).href));

// ---- 1〜3. 全ゲームで描画して検査 ----
const problems = []; let totalLinks = 0; const cases = { zero: 0, upTo10: 0, over10: 0, over100: 0 };
let listenerRenders = 0;
for (const g of GAMES) {
  let r;
  try { r = renderFor(g.name); } catch (e) { problems.push(g.name + ': 描画エラー ' + e.message); continue; }
  const exp = played[g.name] || new Set();
  const sec = r.doc.getElementById('game-streamer-section');
  const first = r.doc.getElementById('game-streamer-grid').querySelectorAll('a');
  const rest = r.doc.getElementById('game-streamer-rest').querySelectorAll('a');
  const all = [...first, ...rest]; totalLinks += all.length;
  if (exp.size === 0) { cases.zero++; if (!sec.hidden || all.length) problems.push(g.name + ': 0件なのに欄が表示'); continue; }
  if (exp.size <= 10) cases.upTo10++; else cases.over10++; if (exp.size > 100) cases.over100++;
  if (sec.hidden) problems.push(g.name + ': 欄が非表示');
  if (all.length !== exp.size) problems.push(g.name + ': リンク ' + all.length + ' ≠ 実況VTuber ' + exp.size);
  if (first.length !== Math.min(10, exp.size)) problems.push(g.name + ': 通常表示 ' + first.length + ' 組');
  if (r.details.hidden !== (exp.size <= 10) || r.details.open) problems.push(g.name + ': 折りたたみの初期状態が不正');
  if (exp.size > 10 && r.doc.getElementById('game-streamer-rest-count').textContent !== String(exp.size - 10)) problems.push(g.name + ': 残り組数の表示');
  const hrefs = all.map((a) => a.getAttribute('href'));
  if (new Set(hrefs).size !== hrefs.length) problems.push(g.name + ': 重複リンク');
  for (const href of hrefs) {
    const n = decodeURIComponent(href.slice('streamer.html?streamer='.length));
    if (!href.startsWith('streamer.html?streamer=') || href !== 'streamer.html?streamer=' + encodeURIComponent(n)) problems.push(g.name + ': URL 形式 ' + href);
    else if (!streamerNames.has(n)) problems.push(g.name + ': 存在しないVTuber ' + n);
    else if (!withPlays.has(n)) problems.push(g.name + ': noindex VTuber ' + n);
    else if (!exp.has(n)) problems.push(g.name + ': 実況していないVTuber ' + n);
    else if (!sitemap.has(new URL(href, 'https://vgame-navi.jp/').href)) problems.push(g.name + ': sitemap に無い ' + href);
  }
  // 11組以上: 末尾の「閉じる」を押しても一覧は作り直さない(リンクはクリック前から DOM にある)
  if (exp.size > 10) {
    const before = rest.length;
    r.details.open = true; r.doc.getElementById('game-streamer-close').click();
    if (r.details.open || r.doc.getElementById('game-streamer-rest').querySelectorAll('a').length !== before) listenerRenders++;
  }
}
check('1a. 全ゲーム(' + GAMES.length + ')を描画し、実況しているVTuberが全員 <a href> として DOM に入る(計 ' + totalLinks + ' リンク)', problems.length === 0, problems.slice(0, 5).join('\n         '));
check('1b. 末尾の「閉じる」は details を閉じるだけで、リンクを作り直さない', listenerRenders === 0, listenerRenders + ' 件');
const js = read('game.js');
const block = (/const STREAMERS_SHOWN_INITIALLY = 10;([\s\S]*?)\/\/ ---------- 関連ゲーム/.exec(js) || [])[1] || '';
const listenerBody = (/addEventListener\("click", \(\) => \{([\s\S]*?)\}\);/.exec(block) || [])[1] || 'x';
check('1c. クリック時にリンクを生成する処理が無い(addCards / createStreamerCard はイベントの外)', !/addCards|createStreamerCard|appendChild/.test(listenerBody) && /addCards\(streamerRest, restStreamers\);/.test(block));
check('3a. ケースを網羅: 0件 ' + cases.zero + ' / 10組以下 ' + cases.upTo10 + ' / 11組以上 ' + cases.over10 + ' / 100組超 ' + cases.over100, cases.zero > 0 && cases.upTo10 > 0 && cases.over10 > 0 && cases.over100 > 0);

// ---- 4. 展開UI ----
check('4a. game.html: 11組目以降は <details id="game-streamer-more" hidden> の中の #game-streamer-rest(streamer-grid)',
  /<details class="more-details" id="game-streamer-more" hidden>\s*<summary><span class="more-details-open">ほか<span id="game-streamer-rest-count"><\/span>組のVTuberを表示<\/span><span class="more-details-close">閉じる<\/span><\/summary>\s*<ul class="streamer-grid" id="game-streamer-rest"><\/ul>\s*<button type="button" class="more-toggle" id="game-streamer-close">閉じる ↑<\/button>\s*<\/details>/.test(gameHtml));
check('4b. 旧「もっと見る」ボタン(クリックで一覧を作り直す方式)が残っていない', !/<button[^>]*id="game-streamer-more"/.test(gameHtml) && !/streamerMoreBtn|renderStreamerGrid/.test(js));
check('4c. CSS: 折りたたみ内の streamer-grid にも余白', /\.more-details > \.index-list,\s*\.more-details > \.streamer-grid \{/.test(read('style.css')));

// ---- 5. メタデータ ----
check('5a. title / description / canonical の生成(setPageMeta 呼び出し)は従来どおり(GAME_PAGE_ROLES のゲームだけ title を差し替え)',
  /setPageMeta\(\s*\(role \? role\.title : gameDisplayName\(game\) \+ "を実況しているVTuber一覧"\) \+ " \| " \+ SITE_NAME,\s*buildGameDescription\(game, items, standalone\),\s*"\/game\.html\?game=" \+ encodeURIComponent\(game\),/.test(js));
check('5b. 見出しは従来どおり(元のHTMLに canonical なし)', /<h2>このゲームを実況しているVTuber<\/h2>/.test(gameHtml) && !/<link rel="canonical"/.test(gameHtml));
const sample = renderFor('Minecraft');
check('5c. 描画後の title / canonical(最大件数のゲームで確認)',
  sample.doc.title === 'Minecraftを実況しているVTuber一覧 | ぶいゲー'
  && sample.doc.head.children.some((e) => e.tagName === 'LINK' && e.getAttribute('rel') === 'canonical' && e.getAttribute('href') === 'https://vgame-navi.jp/game.html?game=Minecraft'), sample.doc.title);
// 役割を明記したページ(GAME_PAGE_ROLES): title・H1・冒頭文だけが変わり、URL・canonical はゲーム名のまま
const rolePage = renderFor('ポケモンシリーズ');
const roleCanonical = rolePage.doc.head.children.find((e) => e.tagName === 'LINK' && e.getAttribute('rel') === 'canonical');
check('5d. 旧「ポケモンシリーズ」: title・H1・冒頭文は役割(複数作品まとめ)を示し、canonical は従来の URL のまま',
  rolePage.doc.title === '複数のポケモン作品をまたぐVTuber実況・企画の再生リスト | ぶいゲー'
  && rolePage.doc.getElementById('page-title').textContent === 'ポケモン(複数作品まとめ)'
  && /^複数のポケモン作品をまたいで実況した再生リスト/.test(rolePage.doc.getElementById('page-lead').textContent)
  && roleCanonical && roleCanonical.getAttribute('href') === 'https://vgame-navi.jp/game.html?game=' + encodeURIComponent('ポケモンシリーズ'),
  rolePage.doc.title + ' / ' + rolePage.doc.getElementById('page-title').textContent + ' / ' + (roleCanonical && roleCanonical.getAttribute('href')));
const kirbyHub = renderFor('星のカービィシリーズ');
const kirbyHubCanonical = kirbyHub.doc.head.children.find((e) => e.tagName === 'LINK' && e.getAttribute('rel') === 'canonical');
const kirbyHubRobots = kirbyHub.doc.head.children.find((e) => e.tagName === 'META' && e.getAttribute('name') === 'robots');
check('5e. 旧「星のカービィシリーズ」: title・H1・パンくず・冒頭文は役割(複数作品まとめ)を示し、canonical は従来の URL のまま・noindex なし',
  kirbyHub.doc.title === '複数のカービィ作品にわたるVTuber実況の再生リスト | ぶいゲー'
  && kirbyHub.doc.getElementById('page-title').textContent === 'カービィ(複数作品まとめ)'
  && kirbyHub.doc.getElementById('breadcrumb-current').textContent === 'カービィ(複数作品まとめ)'
  && /^複数のカービィ作品をひとつにまとめた、VTuberの実況再生リスト/.test(kirbyHub.doc.getElementById('page-lead').textContent)
  && kirbyHubCanonical && kirbyHubCanonical.getAttribute('href') === 'https://vgame-navi.jp/game.html?game=' + encodeURIComponent('星のカービィシリーズ') && !kirbyHubRobots,
  kirbyHub.doc.title + ' / ' + kirbyHub.doc.getElementById('page-title').textContent + ' / ' + (kirbyHubCanonical && kirbyHubCanonical.getAttribute('href')));

// ---- 6. 公開中のゲームシリーズページへの導線(data-series.js の publish: true だけ) ----
const seriesCtx = {}; vm.createContext(seriesCtx); vm.runInContext(read('data-series.js'), seriesCtx);
const SERIES = JSON.parse(JSON.stringify(vm.runInContext('SERIES_PAGES', seriesCtx)));
// fixture の土台は「すべて未公開」(実データの公開状態に左右されない)。そこから指定したシリーズだけ publish: true にする
const BASE = JSON.parse(JSON.stringify(SERIES)); Object.values(BASE).forEach((d) => { d.publish = false; });
const withPublish = (ids) => { const s = JSON.parse(JSON.stringify(BASE)); ids.forEach((id) => { s[id].publish = true; }); return s; };
const seriesLinkOf = (r) => r.doc.getElementById('page-meta').all().find((e) => e.tagName === 'A' && /series\.html/.test(e.href)) || null;
const metaText = (r) => r.doc.getElementById('page-meta').textContent;
const SV = 'ポケットモンスター スカーレット・バイオレット', HUB = SERIES.pokemon.hubGame, DUNGEON = '不思議のダンジョンシリーズ', JUDGE = (SERIES.ryugagotoku.relatedGames || [])[0], KIRBY = SERIES.kirby.games.find((g) => PLAYLISTS.some((p) => p.game === g));
// game.js の描画処理(IIFE)より前(定数と関数の定義だけ)を読み込み、期待値の計算に使う
const gctx = {}; vm.createContext(gctx); vm.runInContext(read('game.js').slice(0, read('game.js').indexOf('(function () {')), gctx);
/** そのゲームのシリーズ表示の期待値(公開シリーズならリンク、そうでなければ GAMES の series 欄の文字だけ) */
const expectedMeta = (g, defs) => {
  const link = gctx.publishedSeriesLinkOf(g, defs);
  if (link) return { href: 'series.html?series=' + encodeURIComponent(link.id), text: (link.kind === 'hub' ? '作品別に探す: ' + link.name + 'のVTuber実況(作品別一覧)' : 'シリーズ: ' + link.name + 'の作品別一覧') };
  const cat = GAMES.find((x) => x.name === g);
  return { href: null, text: cat && cat.series ? 'シリーズ: ' + cat.series : '' };
};
const metaMatches = (r, exp) => { const a = seriesLinkOf(r); return (exp.href ? !!a && a.href === exp.href : !a) && metaText(r) === exp.text; };

// A. 実データ: data-series.js の publish の値どおり(公開シリーズの作品・hubGame だけにリンク。今は3シリーズとも未公開なので0件)
const realPublished = Object.keys(SERIES).filter((id) => SERIES[id].publish === true);
check('6a. 実データ: publish は true / false のどちらか(公開中: ' + (realPublished.join(', ') || 'なし') + ')', Object.values(SERIES).every((d) => typeof d.publish === 'boolean'));
const realPages = [SV, HUB, JUDGE, KIRBY, DUNGEON, 'Minecraft'].map((g) => [g, renderFor(g)]);
check('6b. 実データ: 作品・hubGame・関連作品・未公開シリーズ・無関係のゲームのシリーズ表示とリンクが、publish の値どおり',
  realPages.every(([g, r]) => metaMatches(r, expectedMeta(g, SERIES))), realPages.filter(([g, r]) => !metaMatches(r, expectedMeta(g, SERIES))).map(([g, r]) => g + '=' + metaText(r)).join(' / '));
check('6c. 実データ: 公開シリーズ以外へのリンクは出ない(関連作品・GAMES の series 欄だけがポケモンのゲーム・無関係のゲームは常に文字だけ)',
  [JUDGE, DUNGEON, 'Minecraft'].every((g) => !seriesLinkOf(realPages.find(([x]) => x === g)[1])) &&
  realPages.every(([, r]) => !seriesLinkOf(r) || realPublished.some((id) => seriesLinkOf(r).href === 'series.html?series=' + encodeURIComponent(id))));

// B. fixture(pokemon だけ publish: true)
const pk = withPublish(['pokemon']);
const svPage = renderFor(SV, pk), hubPage = renderFor(HUB, pk);
const svLink = seriesLinkOf(svPage), hubLink = seriesLinkOf(hubPage);
check('6d. 公開(pokemon): 作品ページに「シリーズ: ポケモンシリーズの作品別一覧」のリンク(series.html?series=pokemon)',
  !!svLink && svLink.href === 'series.html?series=pokemon' && metaText(svPage) === 'シリーズ: ポケモンシリーズの作品別一覧', svLink && svLink.href + ' / ' + metaText(svPage));
check('6e. 公開(pokemon): hubGame(旧ページ)に「作品別に探す: ポケモンシリーズのVTuber実況(作品別一覧)」のリンク',
  !!hubLink && hubLink.href === 'series.html?series=pokemon' && metaText(hubPage) === '作品別に探す: ポケモンシリーズのVTuber実況(作品別一覧)', hubLink && metaText(hubPage));
check('6f. 公開(pokemon): 旧ページの title・H1 は変わらない(導線はシリーズ表示の行だけ)',
  hubPage.doc.title === renderFor(HUB).doc.title && hubPage.doc.getElementById('page-title').textContent === 'ポケモン(複数作品まとめ)');
// C. 関係ないゲーム / GAMES の series 欄だけがポケモンのゲーム / 未公開のシリーズ
const dungeon = renderFor(DUNGEON, pk), mc = renderFor('Minecraft', pk), kirbyPage = renderFor(KIRBY, pk);
check('6g. 公開(pokemon): 無関係のゲーム・GAMES の series 欄だけがポケモンの「' + DUNGEON + '」・未公開シリーズの作品にはリンクが出ない',
  !seriesLinkOf(dungeon) && !seriesLinkOf(mc) && !seriesLinkOf(kirbyPage) && metaText(dungeon) === 'シリーズ: ポケモンシリーズ');
// D. 関連作品(relatedGames)は所属として扱わない
const ryu = withPublish(['ryugagotoku']);
const judgePage = renderFor(JUDGE, ryu), kiwamiPage = renderFor(SERIES.ryugagotoku.games.find((g) => g === '龍が如く極'), ryu);
check('6h. 公開(ryugagotoku): 本編(龍が如く極)には series=ryugagotoku のリンク、関連作品(' + JUDGE + ')には出ない',
  !!seriesLinkOf(kiwamiPage) && seriesLinkOf(kiwamiPage).href === 'series.html?series=ryugagotoku' && !seriesLinkOf(judgePage));
// E. kirby だけ公開: 旧ページ(hubGame)は役割の title・H1 のまま、シリーズ表示の行だけがシリーズページへのリンクになる
const kb = withPublish(['kirby']);
const kirbyHubPub = renderFor(SERIES.kirby.hubGame, kb), kirbyHubLink = seriesLinkOf(kirbyHubPub);
check('6j. 公開(kirby): 旧ページに「作品別に探す: 星のカービィシリーズのVTuber実況(作品別一覧)」のリンク、title・H1 は役割のまま',
  !!kirbyHubLink && kirbyHubLink.href === 'series.html?series=kirby' && metaText(kirbyHubPub) === '作品別に探す: 星のカービィシリーズのVTuber実況(作品別一覧)'
  && kirbyHubPub.doc.title === kirbyHub.doc.title && kirbyHubPub.doc.getElementById('page-title').textContent === 'カービィ(複数作品まとめ)', kirbyHubLink && metaText(kirbyHubPub));
// 公開判定(series-publish.js)の内部リンク対象と、ゲーム詳細の判定が一致する
const { getSeriesPublication } = require('./series-publish.js');
const os = require('os');
const fx = path.join(os.tmpdir(), 'vgame-series-links-' + process.pid + '.js');
fs.writeFileSync(fx, 'const SERIES_PAGES = ' + JSON.stringify(pk) + ';');
const pub = getSeriesPublication(ROOT, fx); fs.unlinkSync(fx);
const linked = GAMES.map((g) => g.name).filter((g) => gctx.publishedSeriesLinkOf(g, pk));
check('6i. ゲーム詳細の判定(publishedSeriesLinkOf)が series-publish.js の内部リンク対象と一致(' + linked.length + '件)',
  JSON.stringify(linked.slice().sort()) === JSON.stringify(Object.keys(pub.gameLinks).sort()) && linked.every((g) => pub.gameLinks[g] === 'pokemon'));

console.log('');
console.log('PASS: ' + pass + '  FAIL: ' + fail);
process.exit(fail ? 1 : 0);
