/**
 * 人気ランキング・新着ページ軽量化(data-ranking.js / data-new.js)の回帰テスト。ブラウザ不要(node test-list-data.js)。
 *
 *   1. data-ranking.js / data-new.js が data-playlists.js から生成した最新の内容と一致する(鮮度)
 *   2. ランキング上位50件が、全再生リストから人気順に並べた結果と一致する(順位・並び順・レコード)
 *   3. 新着50件が、全再生リストから追加日順(同日は更新日順)に並べた結果と一致する
 *   4. ranking.html / new.html は data-playlists.js を初期読み込みせず、事前集計を使う
 *      (事前集計が使えない場合は data-playlists.js を読み込んで同じ関数で集計する)
 *   5. SEO(noindex でない・canonical・sitemap・robots)が変わっていない
 *   6. 事前集計が軽量である
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
console.log('=== 人気ランキング・新着ページ軽量化 回帰テスト ===');

// ---- 1. 鮮度 ----
let freshMsg = '';
try { execFileSync(process.execPath, [path.join(ROOT, 'generate-list-data.js'), '--check'], { stdio: 'pipe' }); }
catch (e) { freshMsg = String(e.stderr || e.stdout || e.message).trim() || 'NG'; }
check('1. data-ranking.js / data-new.js が最新の data-playlists.js と一致する', !freshMsg, freshMsg);

// ---- データの読み込み(ページのスクリプトは使わず、全件から独立に計算して照合する) ----
const ctx = {}; vm.createContext(ctx);
for (const f of ['data-core.js', 'data-playlists.js', 'data-ranking.js', 'data-new.js']) vm.runInContext(read(f), ctx, { filename: f });
const J = (e) => JSON.parse(JSON.stringify(vm.runInContext(e, ctx)));
const PLAYLISTS = J('PLAYLISTS'), RANKING = J('RANKING_LIST'), NEWL = J('NEW_LIST');
const common = read('common.js');
// 人気度の定義が common.js の calculatePopularity と同じであること(テストの前提)
check('2a. calculatePopularity の定義がテストの前提(popularity || videoCount)と同じ', /function calculatePopularity\(item\) \{\s*return \(item && \(item\.popularity \|\| item\.videoCount\)\) \|\| 0;\s*\}/.test(common));
const popularity = (p) => (p && (p.popularity || p.videoCount)) || 0;

// ---- 2. ランキング ----
const expectedRanking = PLAYLISTS.slice().sort((a, b) => popularity(b) - popularity(a)).slice(0, 50)
  .map((p, i) => Object.assign({}, p, { _rank: i + 1 }));
check('2b. RANKING_LIST は version 1・50件', RANKING.version === 1 && RANKING.items.length === 50, RANKING.items && RANKING.items.length);
check('2c. 上位50件の順位・並び順・レコードが全件からの人気順と完全一致', JSON.stringify(RANKING.items) === JSON.stringify(expectedRanking));
check('2d. 上位50件の人気度は降順で、51位以下に上位より人気の再生リストが無い',
  RANKING.items.every((p, i) => i === 0 || popularity(RANKING.items[i - 1]) >= popularity(p))
  && PLAYLISTS.every((p) => RANKING.items.some((r) => r.id === p.id) || popularity(p) <= popularity(RANKING.items[49])));

// ---- 3. 新着 ----
const expectedNew = PLAYLISTS.slice().filter((p) => p.addedDate).sort((a, b) => {
  const d = new Date(b.addedDate) - new Date(a.addedDate);
  return d !== 0 ? d : new Date(b.updatedDate || 0) - new Date(a.updatedDate || 0);
}).slice(0, 50);
check('3a. NEW_LIST は version 1・50件', NEWL.version === 1 && NEWL.items.length === 50, NEWL.items && NEWL.items.length);
check('3b. 新着50件の並び順・レコードが全件からの追加日順と完全一致', JSON.stringify(NEWL.items) === JSON.stringify(expectedNew));
const newestAdded = PLAYLISTS.filter((p) => p.addedDate).map((p) => p.addedDate).sort().pop();
check('3c. 新着の先頭が全体の最新追加日', NEWL.items[0].addedDate === newestAdded, NEWL.items[0].addedDate + ' / ' + newestAdded);
const byId = new Map(PLAYLISTS.map((p) => [p.id, p]));
check('3d. 新着の各レコードが元データと完全一致(表示・リンクに必要な項目の欠落なし)', NEWL.items.every((p) => JSON.stringify(byId.get(p.id)) === JSON.stringify(p)));
check('3e. ランキングの各レコードも順位以外は元データと完全一致', RANKING.items.every((p) => { const c = Object.assign({}, p); delete c._rank; return JSON.stringify(byId.get(p.id)) === JSON.stringify(c); }));

// ---- 4. ページの読み込み構成 ----
for (const [page, data, js, variable] of [['ranking.html', 'data-ranking.js', 'ranking.js', 'RANKING_LIST'], ['new.html', 'data-new.js', 'new.js', 'NEW_LIST']]) {
  const html = read(page);
  const scripts = [...html.matchAll(/<script src="([^"]+)"><\/script>/g)].map((m) => m[1]);
  check('4a. ' + page + ' は data-playlists.js を初期読み込みしない', !scripts.includes('data-playlists.js'), scripts.join(', '));
  check('4b. ' + page + ' は ' + data + ' → common.js → ' + js + ' の順で読み込む',
    scripts.indexOf(data) >= 0 && scripts.indexOf(data) < scripts.indexOf('common.js') && scripts.indexOf('common.js') < scripts.indexOf(js), scripts.join(', '));
  check('4c. ' + page + ' の <body> に data-lazy-playlists がある(サイドバー検索サジェスト用)', /<body[^>]* data-lazy-playlists>/.test(html));
  const src = read(js);
  check('4d. ' + js + ': 事前集計(' + variable + ')が使えない場合は data-playlists.js を読み込んで同じ関数で集計する',
    new RegExp('typeof ' + variable + ' !== "undefined"').test(src) && /loadPlaylistsData\(\)\.then\(\(\) => render\w+\(compute\w+List\(getAllPlaylists\(\)\)\)\)/.test(src));
}
for (const page of ['playlists.html', 'search.html']) check('4e. ' + page + ' は従来どおり data-playlists.js を読み込む(全件の絞り込み・横断検索に必要)', read(page).includes('<script src="data-playlists.js"></script>'));

// ---- 5. SEO ----
const sitemap = read('sitemap.xml'), robots = read('robots.txt');
for (const page of ['ranking.html', 'new.html']) {
  const html = read(page);
  check('5a. ' + page + ' は noindex ではない', !/<meta name="robots" content="[^"]*noindex/.test(html));
  check('5b. ' + page + ' の canonical / og:url が本番URL', html.includes('<link rel="canonical" href="https://vgame-navi.jp/' + page + '">') && html.includes('<meta property="og:url" content="https://vgame-navi.jp/' + page + '">'));
  check('5c. sitemap に ' + page + ' が載っている', sitemap.includes('<loc>https://vgame-navi.jp/' + page + '</loc>'));
}
check('5d. robots.txt はサイト全体を許可している', /^Allow: \/$/m.test(robots) && !/^Disallow: \/$/m.test(robots));

// ---- 6. サイズ ----
for (const f of ['data-ranking.js', 'data-new.js']) check('6. ' + f + ' は 60KB 未満(全データは約2.4MB)', Buffer.byteLength(read(f)) < 60 * 1024, Buffer.byteLength(read(f)) + ' bytes');

console.log('');
console.log('PASS: ' + pass + '  FAIL: ' + fail);
process.exit(fail ? 1 : 0);
