/**
 * canonical / sitemap の整合性の回帰テスト。ブラウザ不要(node test-seo-canonical.js)。
 *
 *   1. クエリで対象が決まるページ(game.html / streamer.html / games-row.html)の元のHTMLには
 *      canonical・og:url を書かない。JS(setPageMeta)が唯一の canonical として自分自身のURLを挿入する
 *      (Google: 元のHTMLと異なるURLへ JS で canonical を変更しない)
 *   2. それ以外の公開HTMLは、元のHTMLに canonical を1つだけ持つ
 *   3. JS が挿入する canonical のURLは、sitemap の URL と(URL として)完全に一致する
 *      (全ゲーム・全VTuber・50音行。sitemap 側は XML エスケープを戻して比較)
 *   4. 対象が無い/不正なページは noindex(canonical を持たない)
 *   5. sitemap: 重複なし・noindex 対象(再生リスト0件)を含まない・存在しないゲーム/VTuberを含まない
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
console.log('=== canonical / sitemap 整合性 回帰テスト ===');

const DYNAMIC = ['game.html', 'streamer.html', 'games-row.html'];
const EXCLUDED = ['google41e3144bfd576539.html'];
const pages = fs.readdirSync(ROOT).filter((f) => f.endsWith('.html') && !EXCLUDED.includes(f));
const canonicalTags = (html) => html.match(/<link rel="canonical"[^>]*>/g) || [];

// ---- 1. / 2. 元のHTMLの canonical ----
for (const page of DYNAMIC) {
  const html = read(page);
  check('1a. ' + page + ': 元のHTMLに canonical / og:url が無い', canonicalTags(html).length === 0 && !/<meta property="og:url"/.test(html));
}
const common = read('common.js');
check('1b. setPageMeta は canonical が無ければ作り、SITE_URL + パスを入れる(og:url も同じ値)',
  /let link = document\.querySelector\('link\[rel="canonical"\]'\);\s*if \(!link\) \{\s*link = document\.createElement\("link"\);\s*link\.setAttribute\("rel", "canonical"\);\s*document\.head\.appendChild\(link\);\s*\}\s*link\.setAttribute\("href", url\);\s*upsertMeta\('meta\[property="og:url"\]'/.test(common)
  && /const url = SITE_URL \+ canonicalPath;/.test(common));
check('1c. game.js / streamer.js / games-row.js は gameUrl / streamerUrl と同じ形式のパスで setPageMeta を呼ぶ',
  /"\/game\.html\?game=" \+ encodeURIComponent\(game\)/.test(read('game.js')) && /"\/streamer\.html\?streamer=" \+ encodeURIComponent\(streamer\)/.test(read('streamer.js'))
  && /"\/games-row\.html\?row=" \+ encodeURIComponent\(rowGroup\.row\)/.test(read('games-row.js'))
  && /return "game\.html\?game=" \+ encodeURIComponent\(gameName\);/.test(common) && /return "streamer\.html\?streamer=" \+ encodeURIComponent\(streamerName\);/.test(common));
const others = pages.filter((p) => !DYNAMIC.includes(p));
const bad = others.filter((p) => canonicalTags(read(p)).length !== 1);
check('2. その他の公開HTML(' + others.length + '件)は元のHTMLに canonical が1つだけ', bad.length === 0, bad.join(', '));

// ---- 3. JS の canonical と sitemap の一致 ----
const ctx = {}; vm.createContext(ctx);
for (const f of ['data-core.js', 'data-playlists.js']) vm.runInContext(read(f), ctx, { filename: f });
const SITE_URL = vm.runInContext('SITE_URL', ctx);
const GAMES = vm.runInContext('GAMES', ctx), STREAMERS = vm.runInContext('STREAMERS', ctx), PLAYLISTS = vm.runInContext('PLAYLISTS', ctx);
const xmlDecode = (s) => s.replace(/&apos;/g, "'").replace(/&quot;/g, '"').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&');
const locs = [...read('sitemap.xml').matchAll(/<loc>([^<]*)<\/loc>/g)].map((m) => xmlDecode(m[1]));
const locSet = new Set(locs.map((u) => new URL(u).href));
const gamesWithPlays = new Set(PLAYLISTS.map((p) => p.game)), streamersWithPlays = new Set(PLAYLISTS.map((p) => p.streamer));
const canon = (p) => new URL(SITE_URL + p).href;
const gameMiss = GAMES.filter((g) => gamesWithPlays.has(g.name) && !locSet.has(canon('/game.html?game=' + encodeURIComponent(g.name))));
check('3a. 再生リストのある全ゲーム(' + gamesWithPlays.size + ')の canonical が sitemap に同じURLで載っている', gameMiss.length === 0, gameMiss.slice(0, 3).map((g) => g.name).join(', '));
const streamerMiss = STREAMERS.filter((s) => streamersWithPlays.has(s.name) && !locSet.has(canon('/streamer.html?streamer=' + encodeURIComponent(s.name))));
check('3b. 再生リストのある全VTuber(' + [...streamersWithPlays].length + ')の canonical が sitemap に同じURLで載っている', streamerMiss.length === 0, streamerMiss.slice(0, 3).map((s) => s.name).join(', '));
const kanaBlock = (/const KANA_ROW_GROUPS = \[([\s\S]*?)\n\];/.exec(common.replace(/\r\n/g, '\n')) || [])[1] || '';
const rowNames = [...kanaBlock.matchAll(/row: "([^"]+)"/g)].map((m) => m[1]);
const rowMiss = rowNames.filter((r) => !locSet.has(canon('/games-row.html?row=' + encodeURIComponent(r))));
check('3c. 50音行(common.js の KANA_ROW_GROUPS ' + rowNames.length + '行)の canonical が sitemap に同じURLで載っている', rowNames.length === 10 && rowMiss.length === 0, rowMiss.join(', '));
for (const p of others.filter((p) => !/^(404|search|singles)\.html$/.test(p))) {
  const href = (canonicalTags(read(p))[0] || '').replace(/.*href="([^"]+)".*/, '$1');
  if (!locSet.has(new URL(href).href)) check('3d. ' + p + ' の canonical が sitemap にある', false, href);
}
check('3d. 静的ページの canonical はすべて sitemap にある(404 / search / singles を除く)', true);

// ---- 4. 対象が無いページ ----
check('4a. games-row.js: 行が無い/不正なときは noindex,follow', /if \(!rowGroup\) \{[\s\S]{0,400}robotsMeta\.setAttribute\("content", "noindex,follow"\);\s*return;/.test(read('games-row.js')));
check('4b. 見つからないゲーム/VTuber(renderNotFoundPage)は noindex,follow', /function renderNotFoundPage[\s\S]{0,2500}robotsMeta\.setAttribute\("content", "noindex,follow"\)/.test(common));
check('4c. 再生リスト0件のゲーム/VTuberは noindex,follow', /items\.length === 0 && standalone\.length === 0\) \{[\s\S]{0,600}"noindex,follow"/.test(read('game.js')) && /items\.length === 0 && standalone\.length === 0\) \{[\s\S]{0,600}"noindex,follow"/.test(read('streamer.js')));

// ---- 5. sitemap ----
check('5a. sitemap に重複URLが無い', locSet.size === locs.length, locs.length - locSet.size + ' 件重複');
const noPlayGames = GAMES.filter((g) => !gamesWithPlays.has(g.name)).map((g) => canon('/game.html?game=' + encodeURIComponent(g.name)));
const noPlayStreamers = STREAMERS.filter((s) => !streamersWithPlays.has(s.name)).map((s) => canon('/streamer.html?streamer=' + encodeURIComponent(s.name)));
check('5b. 再生リスト0件(noindex)のゲーム/VTuberを sitemap に載せていない', [...noPlayGames, ...noPlayStreamers].every((u) => !locSet.has(u)));
const known = new Set([...GAMES.map((g) => canon('/game.html?game=' + encodeURIComponent(g.name))), ...STREAMERS.map((s) => canon('/streamer.html?streamer=' + encodeURIComponent(s.name)))]);
const unknown = [...locSet].filter((u) => /\/(game|streamer)\.html\?/.test(u) && !known.has(u));
check('5c. sitemap に存在しないゲーム/VTuberのURLが無い', unknown.length === 0, unknown.slice(0, 3).join(', '));
check('5d. sitemap に noindex の静的ページ(search / 404 / singles 以外の noindex)が無い',
  pages.filter((p) => /<meta name="robots" content="[^"]*noindex/.test(read(p))).every((p) => !locSet.has(new URL(SITE_URL + '/' + p).href) || p === 'singles.html'));

console.log('');
console.log('PASS: ' + pass + '  FAIL: ' + fail);
process.exit(fail ? 1 : 0);
