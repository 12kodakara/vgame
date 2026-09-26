/**
 * ジャンル別ページ(genre.html、PoC はホラーのみ)の回帰テスト。ブラウザ不要(node test-genre-page.js)。
 *
 *   1. data-genres.js が最新の data-playlists.js と一致する(鮮度)
 *   2. 公開ジャンルはホラーだけ(genre.js・data-genres.js・sitemap がそろっている)
 *   3. 集計(統計・ゲーム一覧・VTuber一覧・最近更新)が全件から独立に計算した結果と一致し、並び順が決定的
 *   4. 情報量がページとして十分(薄いページにしない下限)
 *   5. リンク先はすべて実在する正規のゲーム / VTuber(index 対象)
 *   6. title / description / canonical / 見つからないジャンルの扱い / 元のHTMLに canonical を書かない
 *   7. 入口はホラーのゲーム詳細だけ(再生リストの過半数がホラーのとき)
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
console.log('=== ジャンル別ページ(ホラー PoC)回帰テスト ===');

// ---- 1. 鮮度 ----
let freshMsg = '';
try { execFileSync(process.execPath, [path.join(ROOT, 'generate-genre-data.js'), '--check'], { stdio: 'pipe' }); }
catch (e) { freshMsg = String(e.stderr || e.stdout || e.message).trim() || 'NG'; }
check('1. data-genres.js が最新の data-playlists.js と一致する', !freshMsg, freshMsg);

// ---- データ(ページのスクリプトは使わず、全件から独立に計算して照合する) ----
const ctx = {}; vm.createContext(ctx);
for (const f of ['data-core.js', 'data-playlists.js', 'data-genres.js']) vm.runInContext(read(f), ctx, { filename: f });
const J = (e) => JSON.parse(JSON.stringify(vm.runInContext(e, ctx)));
const PLAYLISTS = J('PLAYLISTS'), GAMES = J('GAMES'), STREAMERS = J('STREAMERS'), DATA = J('GENRE_PAGES');
const js = read('genre.js');

// ---- 2. 公開ジャンル ----
check('2a. genre.js の公開ジャンルは ["horror"] のみ', /const GENRE_PAGE_IDS = \["horror"\];/.test(js));
check('2b. data-genres.js に入っているのは horror のみ(version 1)', DATA.version === 1 && JSON.stringify(Object.keys(DATA.genres)) === '["horror"]');
const genreLocs = [...read('sitemap.xml').matchAll(/<loc>([^<]*genre\.html[^<]*)<\/loc>/g)].map((m) => m[1]);
check('2c. sitemap のジャンルURLはホラーの1件だけ', JSON.stringify(genreLocs) === '["https://vgame-navi.jp/genre.html?genre=horror"]', JSON.stringify(genreLocs));
check('2d. generate-sitemap.ps1 のジャンル一覧も horror のみ', /\$genrePages = @\("horror"\)/.test(read('generate-sitemap.ps1')));

// ---- 3. 集計 ----
const h = PLAYLISTS.filter((p) => p.genre === 'horror');
const cmp = (a, b) => (a < b ? -1 : a > b ? 1 : 0);
const games = {}, streamers = {};
h.forEach((p) => { (games[p.game] = games[p.game] || { s: new Set(), n: 0 }).s.add(p.streamer); games[p.game].n++; (streamers[p.streamer] = streamers[p.streamer] || { g: new Set(), n: 0 }).g.add(p.game); streamers[p.streamer].n++; });
const expGames = Object.entries(games).map(([k, v]) => [k, v.s.size, v.n]).sort((a, b) => b[1] - a[1] || b[2] - a[2] || cmp(a[0], b[0]));
const expStreamers = Object.entries(streamers).map(([k, v]) => [k, v.g.size, v.n]).sort((a, b) => b[1] - a[1] || b[2] - a[2] || cmp(a[0], b[0]));
const dateOf = (p) => p.updatedDate || p.addedDate || '';
const expRecent = h.slice().sort((a, b) => cmp(dateOf(b), dateOf(a)) || cmp(a.id, b.id)).slice(0, 10);
const H = DATA.genres.horror;
check('3a. 統計(ゲーム・VTuber・再生リスト・動画)が全件からの計算と一致',
  JSON.stringify(H.stats) === JSON.stringify({ games: expGames.length, streamers: expStreamers.length, playlists: h.length, videos: h.reduce((s, p) => s + (p.videoCount || 0), 0) }), JSON.stringify(H.stats));
check('3b. ゲーム一覧 = 実況VTuber数 → 再生リスト数 → 名前(文字コード順)', JSON.stringify(H.games) === JSON.stringify(expGames));
check('3c. VTuber一覧 = 実況した作品数 → 再生リスト数 → 名前(文字コード順)', JSON.stringify(H.streamers) === JSON.stringify(expStreamers));
check('3d. 最近更新 = 更新日(なければ追加日)が新しい10件、同日は id 順・レコードは元データのまま', JSON.stringify(H.recent) === JSON.stringify(expRecent));
check('3e. 分類はホラーの再生リストのみ(ゲーム名からの推測なし)', H.recent.every((p) => p.genre === 'horror') && !/includes\(|test\(|match\(/.test((/function computeGenrePage[\s\S]*?\n\}/.exec(js) || [''])[0].replace('p.genre === genreId', '')));

// ---- 4. 情報量 ----
check('4. 薄いページにしない下限: ゲーム20以上・VTuber50以上・再生リスト100以上(現在 ' + H.stats.games + ' / ' + H.stats.streamers + ' / ' + H.stats.playlists + ')',
  H.stats.games >= 20 && H.stats.streamers >= 50 && H.stats.playlists >= 100);

// ---- 5. リンク先 ----
const gameNames = new Set(GAMES.map((g) => g.name)), streamerNames = new Set(STREAMERS.map((s) => s.name));
const withPlaysG = new Set(PLAYLISTS.map((p) => p.game)), withPlaysS = new Set(PLAYLISTS.map((p) => p.streamer));
check('5a. ゲーム一覧はすべて実在・再生リストありのゲーム(重複なし)', H.games.every(([n]) => gameNames.has(n) && withPlaysG.has(n)) && new Set(H.games.map((g) => g[0])).size === H.games.length);
check('5b. VTuber一覧はすべて実在・再生リストありのVTuber(重複なし)', H.streamers.every(([n]) => streamerNames.has(n) && withPlaysS.has(n)) && new Set(H.streamers.map((s) => s[0])).size === H.streamers.length);
check('5c. リンクは gameUrl / streamerUrl / 既存の再生リスト表示で作る', /createCountIndexItem\(gameUrl\(name\)/.test(js) && /createStreamerCard\(name, playlistCount\)/.test(js) && /renderPlaylistDiscoverList\("genre-recent-list", page\.recent/.test(js));

// ---- 6. SEO ----
const html = read('genre.html');
check('6a. 元のHTMLに canonical / og:url が無い(JS が自URLを1つだけ挿入)', !/<link rel="canonical"/.test(html) && !/<meta property="og:url"/.test(html));
check('6b. setPageMeta: title「…を実況しているVTuber・実況一覧 | ぶいゲー」・canonical /genre.html?genre=…',
  /text\.name \+ "を実況しているVTuber・実況一覧 \| " \+ SITE_NAME,\s*buildGenreDescription\(genreId, page\),\s*"\/genre\.html\?genre=" \+ encodeURIComponent\(genreId\),/.test(js));
const dctx = { console }; vm.createContext(dctx); vm.runInContext(read('genre.js').replace(/\(function \(\) \{[\s\S]*$/, ''), dctx);
const desc = dctx.buildGenreDescription('horror', H);
check('6c. description は事実のみ(先頭3作品・作品数・VTuber数・再生リスト数)', desc === 'VTuberのホラーゲーム実況をまとめたページです。' + H.games.slice(0, 3).map((g) => g[0]).join('、') + 'など' + H.stats.games + '作品を実況したVTuber' + H.stats.streamers + '組の再生リスト' + H.stats.playlists + '件を掲載しています。', desc);
check('6d. 公開ジャンル以外・指定なしは renderNotFoundPage(noindex)', /if \(!GENRE_PAGE_IDS\.includes\(genreId\)\) \{\s*renderNotFoundPage\(/.test(js));
check('6e. H1 と 全件データを読み込まない構成(data-genres.js → common.js → genre.js)',
  /<h1 class="page-title" id="page-title">/.test(html) && !/data-playlists\.js/.test(html) && /<script src="data-genres\.js"><\/script>\s*<script src="common\.js"><\/script>\s*<script src="genre\.js"><\/script>/.test(html));

check('6f. レイアウトシフト対策: 説明文は元のHTMLに記載・VTuber欄と最近更新欄は中身が入るまで hidden・ゲーム一覧が空の間は本文の高さを確保',
  /<p class="page-lead" id="page-lead">ホラーゲームを実況しているVTuber/.test(html) && /id="genre-streamers-section" hidden>/.test(html) && /id="genre-recent-section" hidden>/.test(html)
  && /document\.getElementById\("genre-streamers-section"\)\.hidden = false;/.test(js) && /document\.getElementById\("genre-recent-section"\)\.hidden = false;/.test(js)
  && /\.wiki-body:has\(#genre-games-list:empty\)/.test(read('style.css')));

// ---- 7. 入口 ----
check('7a. ゲーム詳細の入口は hidden で置き、再生リストの過半数がホラーのときだけ表示',
  /<p id="game-genre-link" hidden><a class="more-link" href="genre\.html\?genre=horror">/.test(read('game.html')) && /items\.filter\(\(p\) => p\.genre === "horror"\)\.length \* 2 > items\.length/.test(read('game.js')));
const pageFiles = fs.readdirSync(ROOT).filter((f) => f.endsWith('.html') && f !== 'genre.html');
const linking = pageFiles.filter((f) => /genre\.html/.test(read(f)));
check('7b. genre.html へのリンクを持つHTMLは game.html だけ(サイト全体への一括追加なし)', JSON.stringify(linking) === '["game.html"]', linking.join(', '));

console.log('');
console.log('PASS: ' + pass + '  FAIL: ' + fail);
process.exit(fail ? 1 : 0);
