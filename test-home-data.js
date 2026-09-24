/**
 * トップページ軽量化(data-home.js)の回帰テスト。ブラウザ不要(node test-home-data.js)。
 *
 *   1. data-home.js が data-playlists.js から生成した最新の内容と一致する(鮮度)
 *   2. HOME_SUMMARY の件数・並び順が全再生リストから求めた値と整合する
 *   3. index.html は data-home.js を読み込み、data-playlists.js を初期読み込みしない
 *   4. 一覧系のページは従来どおり data-playlists.js を読み込み、data-lazy-playlists を持つのは
 *      トップページと詳細ページ(game.html / streamer.html。分割データを使う。test-detail-data.js で検査)だけ
 *   5. home.js / common.js に、遅延読み込みと事前集計の経路が揃っている
 *   6. トップページの導線・検索・内部リンク・構造化データ・noindex・sitemap・robots を壊していない
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
  if (ok) { pass++; console.log('  [PASS] ' + name); } else { fail++; console.log('  [FAIL] ' + name + (detail ? '\n         ' + detail : '')); }
}

console.log('=== トップページ軽量化 回帰テスト ===');

// ---- 1. 鮮度 ----
let fresh = true, freshMsg = '';
try { execFileSync(process.execPath, [path.join(ROOT, 'generate-home-data.js'), '--check'], { stdio: 'pipe' }); }
catch (e) { fresh = false; freshMsg = String(e.stderr || e.stdout || e.message).trim(); }
check('1. data-home.js が最新の data-playlists.js と一致する', fresh, freshMsg);

// ---- 2. 整合性 ----
const ctx = {}; vm.createContext(ctx);
for (const f of ['data-core.js', 'data-playlists.js', 'data-home.js']) vm.runInContext(read(f), ctx, { filename: f });
const playlists = vm.runInContext('PLAYLISTS', ctx);
const s = JSON.parse(JSON.stringify(vm.runInContext('HOME_SUMMARY', ctx)));
const popularity = (p) => (p && (p.popularity || p.videoCount)) || 0;   // common.js calculatePopularity と同じ定義であることは 5. で確認
check('2a. version = 1', s.version === 1);
check('2b. 掲載件数が PLAYLISTS の件数と一致', s.playlistCount === playlists.length, s.playlistCount + ' / ' + playlists.length);
check('2c. ゲーム数が PLAYLISTS のゲーム種類数と一致', s.gameCount === new Set(playlists.map((p) => p.game)).size);
check('2d. VTuber数が PLAYLISTS の実況者種類数と一致', s.streamerCount === new Set(playlists.map((p) => p.streamer)).size);
const scoreBy = (key) => { const m = new Map(); for (const p of playlists) { const k = p[key]; const v = m.get(k) || { score: 0, count: 0 }; v.score += popularity(p); v.count++; m.set(k, v); } return m; };
const gameScore = scoreBy('game'), streamerScore = scoreBy('streamer');
const sortedDesc = (arr, m) => arr.every((x, i) => i === 0 || m.get(arr[i - 1].key).score >= m.get(x.key).score);
check('2e. 人気のゲームは5件・人気スコア降順・件数が実データと一致', s.topGames.length === 5 && sortedDesc(s.topGames, gameScore) && s.topGames.every((x) => gameScore.get(x.key).count === x.count));
const maxGame = Math.max(...[...gameScore.values()].map((v) => v.score));
check('2f. 人気のゲーム1位が全ゲーム中の最高スコア', gameScore.get(s.topGames[0].key).score === maxGame);
check('2g. 人気VTuberは10件・人気スコア降順・件数が実データと一致', s.topStreamers.length === 10 && sortedDesc(s.topStreamers, streamerScore) && s.topStreamers.every((x) => streamerScore.get(x.key).count === x.count));
const dateOf = (p) => new Date(p.updatedDate || p.addedDate).getTime();
const newest = Math.max(...playlists.filter((p) => p.updatedDate || p.addedDate).map(dateOf));
check('2h. 最近更新は5件・日付降順・先頭が全体の最新日付', s.recentUpdated.length === 5 && s.recentUpdated.every((p, i) => i === 0 || dateOf(s.recentUpdated[i - 1]) >= dateOf(p)) && dateOf(s.recentUpdated[0]) === newest);
const byId = new Map(playlists.map((p) => [p.id, p]));
check('2i. 最近更新の各項目は PLAYLISTS の該当レコードと完全一致(表示に必要な項目の欠落なし)', s.recentUpdated.every((p) => JSON.stringify(byId.get(p.id)) === JSON.stringify(p)));
check('2j. data-home.js は 20KB 未満(軽量であること)', Buffer.byteLength(read('data-home.js')) < 20 * 1024, Buffer.byteLength(read('data-home.js')) + ' bytes');

// ---- 3. index.html の読み込み構成 ----
const index = read('index.html');
const scripts = [...index.matchAll(/<script src="([^"]+)"><\/script>/g)].map((m) => m[1]);
check('3a. index.html は data-home.js を読み込む', scripts.includes('data-home.js'), scripts.join(', '));
check('3b. index.html は data-playlists.js を初期読み込みしない', !scripts.includes('data-playlists.js'));
check('3c. 読み込み順が data-core → data-counts → data-home → common → home', JSON.stringify(scripts) === JSON.stringify(['data-core.js', 'data-counts.js', 'data-home.js', 'common.js', 'home.js']), scripts.join(', '));
check('3d. index.html の <body> に data-lazy-playlists がある(検索サジェスト用の遅延読み込み)', /<body data-lazy-playlists>/.test(index));
check('3e. canonical / og:url / description / og:title は従来どおり', /<link rel="canonical" href="https:\/\/vgame-navi\.jp\/">/.test(index) && /<meta property="og:url" content="https:\/\/vgame-navi\.jp\/">/.test(index) && /<meta name="description" content="VTuberのゲーム実況を探す。/.test(index) && /<meta property="og:title"/.test(index));

// ---- 4. 他ページの読み込み構成 ----
// 詳細ページ(game.html / streamer.html)は分割データ(data/games・data/streamers)で表示する。
// その検査は test-detail-data.js で行う。ここでは一覧系のページが従来どおりであることを確認する。
const needsPlaylists = ['playlists.html', 'new.html', 'ranking.html', 'search.html'];
for (const f of needsPlaylists) check('4. ' + f + ' は従来どおり data-playlists.js を読み込む', read(f).includes('<script src="data-playlists.js"></script>'));
for (const f of ['game.html', 'streamer.html']) check('4. ' + f + ' は data-playlists.js を初期読み込みしない(分割データで表示)', !read(f).includes('<script src="data-playlists.js"></script>'));
const lazyPages = fs.readdirSync(ROOT).filter((f) => f.endsWith('.html') && read(f).includes('data-lazy-playlists')).sort();
check('4. data-lazy-playlists を持つのは index.html・game.html・streamer.html だけ', JSON.stringify(lazyPages) === JSON.stringify(['game.html', 'index.html', 'streamer.html']), lazyPages.join(', '));

// ---- 5. 経路の存在 ----
const home = read('home.js'), common = read('common.js');
check('5a. home.js: HOME_SUMMARY が使えない場合は data-playlists.js を読み込んで同じ関数で集計する', /loadPlaylistsData\(\)\.then\(\(\) => renderPlaylistSections\(computeHomeSummary\(getAllPlaylists\(\)\)\)\)/.test(home));
check('5b. common.js: loadPlaylistsData / isLazyPlaylistsPage が定義されている', /function loadPlaylistsData\(\)/.test(common) && /function isLazyPlaylistsPage\(\)/.test(common));
check('5c. common.js: 検索欄の focus / input で遅延読み込みする', (common.match(/ensurePlaylistsForSuggest\(\);/g) || []).length === 2);
check('5d. calculatePopularity の定義がテストの前提(popularity || videoCount)と同じ', /function calculatePopularity\(item\) \{\s*return \(item && \(item\.popularity \|\| item\.videoCount\)\) \|\| 0;\s*\}/.test(common));

// ---- 6. 導線・検索・内部リンク・SEO(軽量化で壊していないこと) ----
const hrefs = [...index.matchAll(/href="([^"#]+)"/g)].map((m) => m[1]);
const localHrefs = hrefs.filter((h) => !/^(https?:|data:|mailto:)/.test(h));
const missingTargets = localHrefs.map((h) => h.split('?')[0]).filter((h) => !fs.existsSync(path.join(ROOT, h)));
check('6a. index.html の内部リンク先がすべて存在する', missingTargets.length === 0, missingTargets.join(', '));
check('6b. ゲーム一覧(games.html)・VTuber一覧(streamers.html)への導線がある', localHrefs.includes('games.html') && localHrefs.includes('streamers.html'));
check('6c. ゲーム詳細・VTuber詳細・事務所別一覧への導線を home.js が描画する',
  /a\.href = gameUrl\(item\.key\)/.test(home) && /createStreamerCard\(item\.key, item\.count\)/.test(home) && /"streamers\.html\?agency="/.test(home)
  && /function gameUrl\(gameName\) \{\s*return "game\.html\?game=" \+ encodeURIComponent\(gameName\);/.test(common)
  && /function streamerUrl\(streamerName\) \{\s*return "streamer\.html\?streamer=" \+ encodeURIComponent\(streamerName\);/.test(common));
check('6d. 検索フォーム(サイドバー・トップ)は search.html へ送信する',
  (index.match(/onsubmit="return wikiSearchSubmit\(this\)"/g) || []).length === 2
  && /window\.location\.href = "search\.html" \+ \(q \? "\?q=" \+ encodeURIComponent\(q\) : ""\);/.test(common));
check('6e. 構造化データ(WebSite / SearchAction)を出力する', /injectWebSiteJsonLd\(\);/.test(home));
check('6f. トップページは noindex ではない', !/<meta name="robots" content="[^"]*noindex/.test(index));
const sitemap = read('sitemap.xml');
check('6g. sitemap にトップ・ゲーム一覧・VTuber一覧が載っている',
  sitemap.includes('<loc>https://vgame-navi.jp/</loc>') && sitemap.includes('<loc>https://vgame-navi.jp/games.html</loc>') && sitemap.includes('<loc>https://vgame-navi.jp/streamers.html</loc>'));
check('6h. sitemap に data-home.js 等のデータファイルが載っていない', !/<loc>[^<]*\.(js|json|ps1)<\/loc>/.test(sitemap));
const robots = read('robots.txt');
check('6i. robots.txt はサイト全体を許可し、sitemap を案内している', /^User-agent: \*$/m.test(robots) && /^Allow: \/$/m.test(robots) && /^Sitemap: https:\/\/vgame-navi\.jp\/sitemap\.xml$/m.test(robots) && !/^Disallow: \/$/m.test(robots));

console.log('');
console.log('PASS: ' + pass + '  FAIL: ' + fail);
process.exit(fail ? 1 : 0);
