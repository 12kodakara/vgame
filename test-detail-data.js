/**
 * 詳細ページ軽量化(data/games・data/streamers の分割データ)の回帰テスト。ブラウザ不要(node test-detail-data.js)。
 *
 *   1. 分割データが data-playlists.js から生成した最新の内容と一致する(鮮度)
 *   2. ファイル構成(64 + 64 ファイル・形式バージョン・各ファイルの番号)
 *   3. 生成側と common.js の振り分け計算(detailShardIndex)・定数が一致する
 *   4. 全再生リストが、ゲーム側・VTuber側それぞれにちょうど1回ずつ、元のレコードのまま入っている
 *   5. 関連ゲーム(上位15)・同じゲームを実況しているVTuber(上位10)が、全件から集計した結果と
 *      全ゲーム・全VTuberで一致する(ブラウザと同じ比較関数で並べて確認)
 *   6. game.html / streamer.html は data-playlists.js を初期読み込みせず、分割データを使う
 *   7. noindex(再生リスト0件のページ)・sitemap・robots が分割データ化の影響を受けていない
 *   8. 1ファイルあたりのサイズが上限内(データが増えたら DETAIL_SHARD_COUNT を見直す合図)
 * 失敗が1件でもあれば終了コード1。
 */
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const zlib = require('zlib');
const { execFileSync } = require('child_process');

const ROOT = __dirname;
const read = (f) => fs.readFileSync(path.join(ROOT, f), 'utf8');
let pass = 0, fail = 0;
function check(name, ok, detail) {
  if (ok) { pass++; console.log('  [PASS] ' + name); } else { fail++; console.log('  [FAIL] ' + name + (detail ? '\n         ' + String(detail).slice(0, 400) : '')); }
}
console.log('=== 詳細ページ軽量化 回帰テスト ===');

// ---- 1. 鮮度 ----
let freshMsg = '';
try { execFileSync(process.execPath, [path.join(ROOT, 'generate-detail-data.js'), '--check'], { stdio: 'pipe' }); }
catch (e) { freshMsg = String(e.stderr || e.stdout || e.message).trim() || 'NG'; }
check('1. 分割データが最新の data-playlists.js と一致する', !freshMsg, freshMsg);

// ---- データとブラウザ側関数の読み込み ----
function stub() { return new Proxy(function () {}, { get: (t, k) => (k === 'length' ? 0 : stub()), apply: () => stub() }); }
const storage = { getItem: () => null, setItem: () => {}, removeItem: () => {} };
const ctx = { console, localStorage: storage,
  window: { addEventListener() {}, localStorage: storage, location: { href: '' } },
  document: { addEventListener() {}, querySelector: () => null, querySelectorAll: () => [], getElementById: () => null, createElement: () => stub(), body: null, head: stub() } };
vm.createContext(ctx);
for (const f of ['data-core.js', 'data-playlists.js', 'data-standalone.js', 'common.js']) vm.runInContext(read(f), ctx, { filename: f });
const J = (expr) => JSON.parse(JSON.stringify(vm.runInContext(expr, ctx)));
const PLAYLISTS = J('PLAYLISTS'), STANDALONE = J('typeof STANDALONE_PLAYS === "undefined" ? [] : STANDALONE_PLAYS'), GAMES = J('GAMES');
const shardIndexBrowser = (k) => vm.runInContext('detailShardIndex(' + JSON.stringify(k) + ')', ctx);
const gameDisplayName = (k) => vm.runInContext('gameDisplayName(' + JSON.stringify(k) + ')', ctx);
const SHARD_COUNT = vm.runInContext('DETAIL_SHARD_COUNT', ctx), VERSION = vm.runInContext('DETAIL_DATA_VERSION', ctx);

// ---- 2. ファイル構成 ----
const gen = read('generate-detail-data.js');
const shards = { games: {}, streamers: {} };
const badHeader = [];
for (const kind of ['games', 'streamers']) {
  const dir = path.join(ROOT, 'data', kind);
  const files = fs.existsSync(dir) ? fs.readdirSync(dir).sort() : [];
  const expected = Array.from({ length: SHARD_COUNT }, (_, i) => String(i).padStart(2, '0') + '.js');
  check('2a. data/' + kind + ' は ' + SHARD_COUNT + ' ファイル(00.js〜' + expected[expected.length - 1] + ')', JSON.stringify(files) === JSON.stringify(expected), files.length + ' files');
  for (const f of files) {
    const text = fs.readFileSync(path.join(dir, f), 'utf8');
    const box = {}; const sctx = { registerDetailShard: (k, i, v, e) => { Object.assign(box, { k, i, v, e }); } }; vm.createContext(sctx);
    vm.runInContext(text, sctx);
    if (box.k !== kind || box.i !== Number(f.slice(0, 2)) || box.v !== VERSION) badHeader.push(kind + '/' + f);
    shards[kind][Number(f.slice(0, 2))] = { entries: JSON.parse(JSON.stringify(box.e || {})), bytes: Buffer.byteLength(text), gz: zlib.gzipSync(text).length };
  }
}
check('2b. 各ファイルの種別・番号・形式バージョンが正しい', badHeader.length === 0, badHeader.join(', '));

// ---- 3. 振り分け計算の一致 ----
check('3a. DETAIL_SHARD_COUNT / DETAIL_DATA_VERSION が生成側と同じ',
  new RegExp('const DETAIL_SHARD_COUNT = ' + SHARD_COUNT + ';').test(gen) && new RegExp('const DETAIL_DATA_VERSION = ' + VERSION + ';').test(gen));
const misplaced = [];
const all = { games: {}, streamers: {} };
for (const kind of ['games', 'streamers']) for (const [i, s] of Object.entries(shards[kind])) for (const [key, entry] of Object.entries(s.entries)) {
  if (shardIndexBrowser(key) !== Number(i)) misplaced.push(kind + ':' + key);
  all[kind][key] = entry;
}
check('3b. すべてのエントリが、ブラウザ(common.js)が探しにいくファイルに入っている', misplaced.length === 0, misplaced.slice(0, 5).join(', '));

// ---- 4. 再生リストの過不足 ----
for (const [kind, field] of [['games', 'game'], ['streamers', 'streamer']]) {
  const expected = {};
  PLAYLISTS.forEach((p) => { (expected[p[field]] = expected[p[field]] || []).push(p); });
  const keysOk = JSON.stringify(Object.keys(expected).sort()) === JSON.stringify(Object.keys(all[kind]).filter((k) => all[kind][k].playlists.length).sort());
  const mism = Object.keys(expected).filter((k) => !all[kind][k] || JSON.stringify(all[kind][k].playlists) !== JSON.stringify(expected[k]));
  const total = Object.values(all[kind]).reduce((s, e) => s + e.playlists.length, 0);
  check('4. ' + kind + ': 全 ' + PLAYLISTS.length + ' 件がちょうど1回ずつ・元のレコードと順序のまま入っている', keysOk && mism.length === 0 && total === PLAYLISTS.length, 'total=' + total + ' mismatch=' + mism.slice(0, 5).join(', '));
}
const gamesWithoutData = GAMES.filter((g) => !PLAYLISTS.some((p) => p.game === g.name) && !STANDALONE.some((p) => p.game === g.name)).map((g) => g.name);
check('4b. 再生リスト0件のゲームにはエントリが無い(ページは従来どおり noindex になる)', gamesWithoutData.every((n) => !all.games[n]), gamesWithoutData.filter((n) => all.games[n]).join(', '));

// ---- 5. 関連表示の一致(全件) ----
const byCountThenName = (display) => (a, b) => b.count - a.count || display(a.name).localeCompare(display(b.name), 'ja');
const relFail = [];
const gameNames = new Set([...PLAYLISTS.map((p) => p.game), ...STANDALONE.map((p) => p.game)]);
for (const game of gameNames) {
  const streamerNames = new Set([...PLAYLISTS.filter((p) => p.game === game), ...STANDALONE.filter((p) => p.game === game)].map((p) => p.streamer));
  const counts = {}, order = [];
  PLAYLISTS.forEach((p) => { if (p.game === game || !streamerNames.has(p.streamer)) return; if (!counts[p.game]) { counts[p.game] = 0; order.push(p.game); } counts[p.game]++; });
  const brute = order.map((n) => ({ name: n, count: counts[n] })).sort(byCountThenName(gameDisplayName)).slice(0, 15);
  const fromData = ((all.games[game] || {}).related || []).map(([n, c]) => ({ name: n, count: c })).sort(byCountThenName(gameDisplayName)).slice(0, 15);
  if (JSON.stringify(brute) !== JSON.stringify(fromData)) relFail.push('game:' + game);
}
const streamerNamesAll = new Set([...PLAYLISTS.map((p) => p.streamer), ...STANDALONE.map((p) => p.streamer)]);
for (const s of streamerNamesAll) {
  const myGames = new Set([...PLAYLISTS.filter((p) => p.streamer === s), ...STANDALONE.filter((p) => p.streamer === s)].map((p) => p.game));
  const sets = {}, order = [];
  PLAYLISTS.forEach((p) => { if (p.streamer === s || !myGames.has(p.game)) return; if (!sets[p.streamer]) { sets[p.streamer] = new Set(); order.push(p.streamer); } sets[p.streamer].add(p.game); });
  const brute = order.map((n) => ({ name: n, count: sets[n].size })).sort(byCountThenName((x) => x)).slice(0, 10);
  const fromData = ((all.streamers[s] || {}).related || []).map(([n, c]) => ({ name: n, count: c })).sort(byCountThenName((x) => x)).slice(0, 10);
  if (JSON.stringify(brute) !== JSON.stringify(fromData)) relFail.push('streamer:' + s);
}
check('5. 関連ゲーム上位15(' + gameNames.size + 'ゲーム)・関連VTuber上位10(' + streamerNamesAll.size + '人)が全件集計と一致', relFail.length === 0, relFail.slice(0, 5).join(', '));

// ---- 6. ページの読み込み構成 ----
for (const [page, js, kind] of [['game.html', 'game.js', 'games'], ['streamer.html', 'streamer.js', 'streamers']]) {
  const html = read(page);
  const scripts = [...html.matchAll(/<script src="([^"]+)"><\/script>/g)].map((m) => m[1]);
  check('6a. ' + page + ' は data-playlists.js を初期読み込みしない', !scripts.includes('data-playlists.js'), scripts.join(', '));
  check('6b. ' + page + ' の <body> に data-lazy-playlists がある(サイドバー検索サジェスト用)', /<body[^>]* data-lazy-playlists>/.test(html));
  check('6c. ' + page + ': common.js → ' + js + ' の順で読み込む', scripts.indexOf('common.js') >= 0 && scripts.indexOf('common.js') < scripts.indexOf(js));
  check('6d. ' + js + ' は startDetailPage("' + kind + '", …) で分割データから描画する', new RegExp('startDetailPage\\("' + kind + '", ').test(read(js)));
}
const common = read('common.js');
check('6e. common.js: 分割データが使えない場合は data-playlists.js を読み込んで従来どおり描画する',
  /\.catch\(\(\) => loadPlaylistsData\(\)\.then\(\(\) => render\(getItemsFromAll\(key\), null\)\)\);/.test(common));
for (const page of ['playlists.html', 'search.html']) check('6f. ' + page + ' は従来どおり data-playlists.js を読み込む', read(page).includes('<script src="data-playlists.js"></script>'));
for (const page of ['new.html', 'ranking.html']) check('6f. ' + page + ' は data-playlists.js を初期読み込みしない(事前集計で表示)', !read(page).includes('<script src="data-playlists.js"></script>'));

// ---- 7. SEO ----
const sitemap = read('sitemap.xml');
const xmlDecode = (t) => t.replace(/&apos;/g, "'").replace(/&quot;/g, '"').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&');
const gamesInSitemap = [...sitemap.matchAll(/<loc>https:\/\/vgame-navi\.jp\/game\.html\?game=([^<]+)<\/loc>/g)].map((m) => decodeURIComponent(xmlDecode(m[1])));
check('7a. sitemap のゲーム詳細URLはすべて分割データにエントリがある(空ページを載せていない)', gamesInSitemap.length > 0 && gamesInSitemap.every((g) => all.games[g] && all.games[g].playlists.length), gamesInSitemap.filter((g) => !all.games[g]).slice(0, 5).join(', '));
const streamersInSitemap = [...sitemap.matchAll(/<loc>https:\/\/vgame-navi\.jp\/streamer\.html\?streamer=([^<]+)<\/loc>/g)].map((m) => decodeURIComponent(xmlDecode(m[1])));
check('7b. sitemap のVTuber詳細URLはすべて分割データにエントリがある', streamersInSitemap.length > 0 && streamersInSitemap.every((s) => all.streamers[s] && all.streamers[s].playlists.length), streamersInSitemap.filter((s) => !(all.streamers[s] && all.streamers[s].playlists.length)).slice(0, 5).join(', '));
check('7c. sitemap に data/ のファイルが載っていない', !/<loc>[^<]*\/data\//.test(sitemap));
const robots = read('robots.txt');
check('7d. robots.txt は data/ を拒否していない(検索エンジンが詳細ページを描画できる)', !/^Disallow: \/(data)?\/?$/m.test(robots) && /^Allow: \/$/m.test(robots));
for (const page of ['game.html', 'streamer.html']) check('7e. ' + page + ' の初期HTMLは noindex ではない(noindex は再生リスト0件のときだけ JS で付与)', !/<meta name="robots" content="[^"]*noindex/.test(read(page)));

// ---- 8. サイズ ----
const gzs = ['games', 'streamers'].flatMap((k) => Object.values(shards[k]).map((s) => s.gz));
const maxGz = Math.max(...gzs), totalBytes = ['games', 'streamers'].flatMap((k) => Object.values(shards[k]).map((s) => s.bytes)).reduce((a, b) => a + b, 0);
check('8a. 1ファイルの最大サイズが gzip 後 100KB 未満(全データは約445KB)', maxGz < 100 * 1024, 'max ' + maxGz + ' bytes');
check('8b. 分割データ全体が 12MB 未満(リポジトリを肥大化させない)', totalBytes < 12 * 1024 * 1024, totalBytes + ' bytes');
console.log('     (参考) ファイル数 ' + gzs.length + ' / 合計 ' + totalBytes + ' bytes / 最大 gzip ' + maxGz + ' bytes)');

console.log('');
console.log('PASS: ' + pass + '  FAIL: ' + fail);
process.exit(fail ? 1 : 0);
