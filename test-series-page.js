/**
 * ゲームシリーズページ(series.html。LOCAL PoC・未公開)の回帰テスト。ブラウザ不要(node test-series-page.js)。
 *
 *   1. data-series.js の定義が GAMES と整合する(存在・重複・複数シリーズ所属・関連作品の名前)
 *   2. 集計(作品・関連作品・VTuber・横断数・再生リスト・動画)が全件から独立に計算した結果と一致する
 *   3. 関連作品(relatedGames)は本編の作品一覧・作品数と分かれ、本編の作品として扱われない
 *   4. 関連作品の無いシリーズの title / description / 概要文は従来どおり
 *   5. 龍が如くシリーズ: 本編12作品(実況0件の龍が如く2は出さない)・関連は JUDGE の2作品・逆転裁判などが混ざらない
 *   6. PoC のまま: 元HTMLは noindex・canonical を書かない・sitemap に無い・サイト内からリンクしない・publish は false
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
console.log('=== ゲームシリーズページ(LOCAL PoC)回帰テスト ===');

// ---- データ ----
const ctx = { formatNumberJa: (n) => Number(n).toLocaleString('ja-JP'), SITE_NAME: 'ぶいゲー' };
vm.createContext(ctx);
for (const f of ['data-core.js', 'data-playlists.js', 'data-standalone.js', 'data-series.js', 'series.js']) vm.runInContext(read(f), ctx, { filename: f });
const J = (e) => JSON.parse(JSON.stringify(vm.runInContext(e, ctx)));
const PLAYLISTS = J('PLAYLISTS'), GAMES = J('GAMES'), STANDALONE = J('STANDALONE_PLAYS'), SERIES = J('SERIES_PAGES');
const compute = (def) => ctx.computeSeriesPage(PLAYLISTS, STANDALONE, def);
const gameByName = new Map(GAMES.map((g) => [g.name, g]));
const ids = Object.keys(SERIES);

// ---- 1. 定義の整合性 ----
const owner = new Map(), defProblems = [];
for (const id of ids) {
  const d = SERIES[id];
  const all = d.games.concat(d.relatedGames || []);
  if (d.hubGame && !gameByName.has(d.hubGame)) defProblems.push(id + ': hubGame なし ' + d.hubGame);
  all.forEach((g) => { if (!gameByName.has(g)) defProblems.push(id + ': GAMES になし ' + g); });
  if (new Set(all).size !== all.length) defProblems.push(id + ': 重複あり');
  all.forEach((g) => { if (owner.has(g) && owner.get(g) !== id) defProblems.push(g + ' が ' + owner.get(g) + ' と ' + id + ' の両方'); owner.set(g, id); });
  if ((d.relatedGames || []).length && !d.relatedLabel) defProblems.push(id + ': relatedLabel なし');
  if (all.includes(d.hubGame)) defProblems.push(id + ': hubGame が作品にも入っている');
}
check('1a. 全シリーズの作品・関連作品・hubGame が GAMES にあり、重複・複数シリーズ所属がない', !defProblems.length, defProblems.join(' / '));
check('1b. シリーズIDは英小文字・数字だけ(URL に使う)', ids.every((id) => /^[a-z0-9]+$/.test(id)), ids.join(','));

// ---- 2. 集計を独立に計算して照合 ----
function expected(d) {
  const main = new Set(d.games), rel = new Set(d.relatedGames || []), titles = new Set([...main, ...rel]);
  const inS = (g) => titles.has(g) || g === d.hubGame;
  const pls = PLAYLISTS.filter((p) => inS(p.game)), sps = STANDALONE.filter((p) => inS(p.game));
  const per = new Map();
  for (const p of pls.concat(sps)) { if (!per.has(p.streamer)) per.set(p.streamer, new Set()); if (titles.has(p.game)) per.get(p.streamer).add(p.game); }
  const played = (set) => [...set].filter((g) => pls.some((p) => p.game === g) || sps.some((p) => p.game === g));
  return {
    games: played(main).sort(), related: played(rel).sort(), streamers: per.size,
    cross: [...per.values()].filter((s) => s.size >= 2).length, playlists: pls.length,
    videos: pls.reduce((a, p) => a + (p.videoCount || 0), 0), standalone: sps.length,
  };
}
for (const id of ids) {
  const d = SERIES[id], page = compute(d), e = expected(d);
  const got = { games: page.games.map((r) => r[0]).sort(), related: page.related.map((r) => r[0]).sort(), streamers: page.stats.streamers,
    cross: page.stats.crossStreamers, playlists: page.stats.playlists, videos: page.stats.videos, standalone: page.stats.standalone };
  check('2. ' + id + ': 集計が全件からの独立計算と一致(作品' + e.games.length + '・関連' + e.related.length + '・VTuber' + e.streamers + '・横断' + e.cross + '・再生リスト' + e.playlists + ')',
    JSON.stringify(got) === JSON.stringify(e) && page.stats.games === e.games.length && page.stats.relatedGames === e.related.length,
    JSON.stringify({ got, e }));
}

// ---- 3. 関連作品は本編と分かれる ----
for (const id of ids) {
  const d = SERIES[id], page = compute(d), rel = new Set(d.relatedGames || []);
  check('3. ' + id + ': 本編の作品一覧に関連作品が入らず、関連作品の一覧に本編の作品が入らない',
    page.games.every((r) => !rel.has(r[0])) && page.related.every((r) => rel.has(r[0])));
}

// ---- 4. 関連作品の無いシリーズの文面は従来どおり ----
for (const id of ids.filter((x) => !(SERIES[x].relatedGames || []).length)) {
  const d = SERIES[id], page = compute(d), s = page.stats;
  const oldDesc = d.name + s.games + '作品のVTuberによるゲーム実況を、作品別にまとめたページです。実況VTuber' + s.streamers + '組・再生リスト' + s.playlists + '件を掲載しています。';
  const oldSummary = d.name + 'の' + s.games + '作品を、' + s.streamers + '組のVTuberが実況しています(うち' + s.crossStreamers +
    '組は複数の作品を実況)。再生リスト' + ctx.formatNumberJa(s.playlists) + '件・単発実況' + s.standalone + '件・動画' + ctx.formatNumberJa(s.videos) + '本を作品ごとに探せます。';
  check('4. ' + id + ': description・概要文が従来の文面と同じ(関連作品なし)',
    ctx.buildSeriesDescription(d, page) === oldDesc && ctx.buildSeriesSummary(d, page) === oldSummary && page.related.length === 0);
}

// ---- 5. 龍が如くシリーズ ----
const ryu = SERIES.ryugagotoku;
check('5a. ryugagotoku が定義されている(表示名「龍が如くシリーズ」・hubGame「龍が如くシリーズ」・publish false)',
  !!ryu && ryu.name === '龍が如くシリーズ' && ryu.hubGame === '龍が如くシリーズ' && ryu.publish === false);
if (ryu) {
  const page = compute(ryu);
  check('5b. 本編の作品は GAMES の series が「龍が如くシリーズ」の全作品(hub を除く13作品)と一致',
    JSON.stringify(ryu.games.slice().sort()) === JSON.stringify(GAMES.filter((g) => g.series === '龍が如くシリーズ' && g.name !== '龍が如くシリーズ').map((g) => g.name).sort()));
  check('5c. 表示する本編は12作品(実況0件の「龍が如く2」は出さない)', page.stats.games === 12 && !page.games.some((r) => r[0] === '龍が如く2'), page.games.map((r) => r[0]).join(','));
  check('5d. 関連作品は JUDGEシリーズの2作品だけ', ryu.relatedLabel === 'JUDGEシリーズ' &&
    JSON.stringify(page.related.map((r) => r[0]).sort()) === JSON.stringify(['JUDGE EYES:死神の遺言', 'LOST JUDGMENT:裁かれざる記憶'].sort()));
  check('5e. JUDGE の2作品は GAMES 上も龍が如くシリーズの作品になっていない(ゲーム詳細の「シリーズ: …」で親子を誤らない)',
    (ryu.relatedGames || []).every((g) => gameByName.get(g).series !== ryu.name));
  const allNames = ryu.games.concat(ryu.relatedGames || []);
  check('5f. 名前に「龍」を含むだけの別シリーズ(大逆転裁判など)が混ざらない', allNames.every((g) => /龍が如く|JUDGE|JUDGMENT/.test(g)), allNames.join(','));
  const desc = ctx.buildSeriesDescription(ryu, page), summary = ctx.buildSeriesSummary(ryu, page);
  check('5g. description は本編の作品数と「関連するJUDGEシリーズ」の作品数を分けて書く',
    desc.startsWith('龍が如くシリーズ12作品と関連するJUDGEシリーズ2作品の') && !/龍が如くシリーズ14作品/.test(desc), desc);
  check('5h. 概要文も「関連するJUDGEシリーズの2作品」と書き、JUDGE を本編として数えない', summary.startsWith('龍が如くシリーズの12作品と、関連するJUDGEシリーズの2作品を、'), summary);
  check('5i. relatedNote が JUDGE を別シリーズと明記している', /別のシリーズ/.test(ryu.relatedNote || '') && /龍が如くシリーズの作品ではありません/.test(ryu.relatedNote || ''), ryu.relatedNote);
  check('5j. 公開条件(作品3・横断10・VTuber20 または 40件)を満たす', ctx.meetsSeriesPageThreshold(page), JSON.stringify(page.stats));
}

// ---- 6. PoC のまま ----
const html = read('series.html');
check('6a. series.html は noindex,follow で、canonical を元HTMLに書かない', /<meta name="robots" content="noindex,follow">/.test(html) && !/rel="canonical"/.test(html));
check('6b. 関連作品の表示枠は最初は隠れている(関連作品の無いシリーズでは出ない)', /<div id="series-related-block" hidden>/.test(html));
check('6b2. 関連作品を含む見出し(VTuber・最近の再生リスト)に関連シリーズ名を入れる枠があり、どちらも最初は隠れたセクションの中',
  (html.match(/<span data-series-related><\/span>/g) || []).length === 2 &&
  /<section class="section-box" id="series-streamers-section" hidden>[\s\S]*?data-series-related[\s\S]*?<\/section>/.test(html) &&
  /<section class="section-box" id="series-recent-section" hidden>[\s\S]*?data-series-related[\s\S]*?<\/section>/.test(html));
const sjs = read('series.js');
check('6b3. 作品数タイルは関連作品があるときだけ「本編＋関連」(14作品のように合算しない)・ラベルは描画前に入れる',
  /formatNumberJa\(page\.stats\.games\) \+\s*\(page\.stats\.relatedGames \? "＋" \+ formatNumberJa\(page\.stats\.relatedGames\) : ""\) \+ "作品"/.test(sjs) &&
  /id="stat-games-label">作品数<\/span>/.test(html) && /def\.relatedGames && def\.relatedGames\.length\) \{[\s\S]{0,200}?getElementById\("stat-games-label"\)[\s\S]{0,300}?"\(＋関連: " \+ def\.relatedLabel \+ "\)"/.test(html));
check('6c. 全シリーズが publish: false', ids.every((id) => SERIES[id].publish === false));
check('6d. sitemap に series.html が無い', !/series\.html/.test(read('sitemap.xml')));
// 対象はページ(HTML)と、ページが <script src> で読み込むスクリプトだけ(series-publish.js のような
// ビルド用の node スクリプトはページに読み込まれない)。data-series.js は定義(コメントに URL の形式を書いているだけ)なので対象外
const htmlFiles = fs.readdirSync(ROOT).filter((f) => f.endsWith('.html'));
const pageScripts = new Set(htmlFiles.flatMap((f) => [...read(f).matchAll(/<script[^>]*\ssrc="([^"?#]+)"/g)].map((m) => m[1])));
// game.js は公開中(publish: true)のシリーズへだけ導線を出す(publishedSeriesLinkOf → seriesPageHref)。
// その経路以外で series.html を書いていないことをここで確かめ、実際の表示は test-game-streamers.js(6a〜6i)で確かめる
const linkers = htmlFiles.concat([...pageScripts].filter((f) => fs.existsSync(path.join(ROOT, f))))
  .filter((f) => !/^(series\.(html|js)|data-series\.js)$/.test(f))
  .filter((f) => /series\.html/.test(f === 'game.js' ? read(f).replace('const seriesPageHref = (id) => "series.html?series=" + encodeURIComponent(id);', '') : read(f)));
check('6e. サイト内のほかのページ・スクリプトから series.html へリンクしていない(game.js は公開シリーズ用の1か所だけ)', !linkers.length, linkers.join(','));
check('6e2. game.js の series.html は seriesPageHref の1か所だけで、publishedSeriesLinkOf(publish: true のみ)の結果にだけ使う',
  (read('game.js').match(/series\.html/g) || []).length === 1 && /const seriesLink = publishedSeriesLinkOf\(game, [^\n]*\);\s*if \(metaEl && seriesLink\) \{[\s\S]{0,200}?a\.href = seriesPageHref\(seriesLink\.id\);/.test(read('game.js')));

console.log('\nPASS: ' + pass + '  FAIL: ' + fail);
process.exit(fail ? 1 : 0);
