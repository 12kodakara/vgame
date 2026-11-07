/**
 * 再生リスト一覧(playlists.html)・新着再生リスト(new.html)の統一と、人気5ゲームの通常非表示の回帰テスト。
 * ブラウザ不要(node tests/test-playlist-list-pages.js)。
 *
 *   1. 人気5ゲームは正式名の完全一致で通常表示から外し、別作品(Minecraft Dungeons など)は外さない
 *   2. ゲームの絞り込み・ゲーム名/別名の検索では表示に戻し、VTuber名・ジャンルなどの条件では外したまま
 *   3. 外した件数(hiddenCount)・件数計算はページ送りの前に正しく出る
 *   4. 新着: computeNewList の既定(50件)は従来どおりで、Infinity で全件を同じ順に返す
 *   5. 両ページの検索欄・絞り込み・表の列・上下のページ送りが同じ構成で、新着は data-playlists.js を初期読み込みしない
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
console.log('=== 再生リスト一覧・新着再生リスト 回帰テスト ===');

const storage = { getItem: () => null, setItem: () => {}, removeItem: () => {} };
const ctx = {
  console, localStorage: storage,
  window: { __LIST_DATA_GENERATOR__: true, addEventListener() {}, localStorage: storage, location: { href: '' } },
  document: { addEventListener() {}, querySelector: () => null, querySelectorAll: () => [], getElementById: () => null, createElement: () => ({}), body: null, head: {} },
};
vm.createContext(ctx);
for (const f of ['data-core.js', 'data-counts.js', 'data-playlists.js', 'data-new.js', 'common.js', 'new.js']) vm.runInContext(read(f), ctx, { filename: f });
const run = (expr) => vm.runInContext(expr, ctx);
const filter = (filters) => JSON.parse(JSON.stringify(run('filterPlaylistsForList(PLAYLISTS, ' + JSON.stringify(filters) + ')')));
const ALL = JSON.parse(JSON.stringify(run('PLAYLISTS')));
const FIVE = ['Minecraft', 'Grand Theft Auto V', 'Apex Legends', 'VALORANT', 'League of Legends'];
const countOf = (items, game) => items.filter((p) => p.game === game).length;

// ---- 1. 通常表示 ----
const base = filter({});
const fiveTotal = ALL.filter((p) => FIVE.includes(p.game)).length;
check('1a. 条件なしでは5ゲームを1件も出さない', FIVE.every((g) => countOf(base.items, g) === 0));
check('1b. 外した件数 = 5ゲームの全件数、表示 + 外した = 全件', base.hiddenCount === fiveTotal && base.items.length + base.hiddenCount === ALL.length, base.hiddenCount + ' / ' + fiveTotal);
check('1c. 別作品(Minecraft Dungeons・League of Legends: Wild Rift)は外さない',
  countOf(base.items, 'Minecraft Dungeons') === countOf(ALL, 'Minecraft Dungeons') && countOf(ALL, 'Minecraft Dungeons') > 0
  && countOf(base.items, 'League of Legends: Wild Rift') === countOf(ALL, 'League of Legends: Wild Rift') && countOf(ALL, 'League of Legends: Wild Rift') > 0);
check('1d. 判定は正式名の完全一致(5つ以外の名前は対象外)', FIVE.every((g) => run('isListHiddenGame(' + JSON.stringify(g) + ')')) && !run('isListHiddenGame("Minecraft Dungeons")') && !run('isListHiddenGame("minecraft")'));
check('1e. 5ゲームの正式名がゲームマスターに存在する', FIVE.every((g) => run('!!gameCatalogOf(' + JSON.stringify(g) + ')')));

// ---- 2. 明示指定で表示に戻す ----
for (const g of FIVE) {
  const r = filter({ game: g });
  check('2a. ゲームの絞り込みで「' + g + '」を選ぶと全件表示', r.items.length === countOf(ALL, g) && r.hiddenCount === 0, r.items.length + ' / ' + countOf(ALL, g));
}
for (const [q, g] of [['マイクラ', 'Minecraft'], ['Minecraft', 'Minecraft'], ['GTA', 'Grand Theft Auto V'], ['APEX', 'Apex Legends'], ['VALORANT', 'VALORANT'], ['ヴァロラント', 'VALORANT'], ['LoL', 'League of Legends'], ['League of Legends', 'League of Legends']]) {
  const r = filter({ q });
  check('2b. 検索「' + q + '」で ' + g + ' を全件表示', countOf(r.items, g) === countOf(ALL, g), countOf(r.items, g) + ' / ' + countOf(ALL, g));
}
const peko = filter({ q: '兎田ぺこら' });
const pekoHidden = ALL.filter((p) => p.streamer === '兎田ぺこら' && FIVE.includes(p.game)).length;
check('2c. VTuber名だけの検索では5ゲームを外したまま(外した件数も正しい)', FIVE.every((g) => countOf(peko.items, g) === 0) && peko.hiddenCount === pekoHidden, peko.hiddenCount + ' / ' + pekoHidden);
const partial = filter({ q: 'a' });
check('2e. 1文字などの部分一致では戻さない', FIVE.every((g) => countOf(partial.items, g) === 0));
const genreSandbox = filter({ genre: 'sandbox' });
const sandboxHidden = ALL.filter((p) => p.genre === 'sandbox' && FIVE.includes(p.game)).length;
check('2f. ジャンルの絞り込みだけでは外したまま(件数は hiddenCount に出る)', countOf(genreSandbox.items, 'Minecraft') === 0 && sandboxHidden > 0 && genreSandbox.hiddenCount === sandboxHidden, genreSandbox.hiddenCount + ' / ' + sandboxHidden);
check('2g. hasPlaylistListFilters: 空白だけの検索語は条件なし、どれか1つ指定で条件あり',
  !run('hasPlaylistListFilters({q:"  ",genre:"",game:"",agency:"",streamer:""})') && run('hasPlaylistListFilters({q:"",genre:"",game:"",agency:"",streamer:"兎田ぺこら"})'));

// ---- 3. 元データは変えない ----
check('3a. 絞り込みは元の PLAYLISTS を変えない', JSON.stringify(run('PLAYLISTS')) === JSON.stringify(ALL));
check('3b. 並び順は渡した順のまま(ページ送りの前に外す)', JSON.stringify(base.items.map((p) => p.id)) === JSON.stringify(ALL.filter((p) => !FIVE.includes(p.game)).map((p) => p.id)));

// ---- 4. 新着 ----
const NEWL = JSON.parse(JSON.stringify(run('NEW_LIST')));
check('4a. computeNewList の既定は50件で data-new.js と同じ(生成仕様は変えていない)', JSON.stringify(run('computeNewList(PLAYLISTS)')) === JSON.stringify(NEWL.items));
const full = JSON.parse(JSON.stringify(run('computeNewList(PLAYLISTS, Infinity)')));
check('4b. computeNewList(全件, Infinity) は追加日のある全件を同じ順で返す(先頭50件は新着と一致)',
  full.length === ALL.filter((p) => p.addedDate).length && JSON.stringify(full.slice(0, 50)) === JSON.stringify(NEWL.items));

// ---- 5. ページ構成 ----
const pick = (html, re) => ((re.exec(html) || [''])[0]).replace(/\r\n/g, '\n');
const PAGES = ['playlists.html', 'new.html'];
const controls = PAGES.map((p) => pick(read(p), /<form class="controls"[\s\S]*?<\/form>/));
const theads = PAGES.map((p) => pick(read(p), /<thead>[\s\S]*?<\/thead>/));
const tops = PAGES.map((p) => pick(read(p), /<div class="pagination pagination-top"[\s\S]*?<\/div>/));
check('5a. 両ページの検索欄・絞り込み(折りたたみ)・表示件数が同じ', controls[0] && controls[0] === controls[1]
  && ['search-input', 'list-filters', 'genre-select', 'game-select', 'agency-select', 'streamer-select', 'pagesize-select'].every((id) => controls[0].includes('id="' + id + '"')));
check('5b. 表示件数の初期値は20件', /<option value="20" selected>20件表示<\/option>/.test(controls[0]));
check('5c. 両ページの表の列(見出し)が同じ', theads[0] && theads[0] === theads[1]);
check('5d. 両ページとも表の上にもページ送りがあり、下のページ送りも残る', tops[0] && tops[0] === tops[1] && PAGES.every((p) => read(p).includes('id="pagination"')));
check('5e. 両ページとも同じ表のスタイル(body.playlists-page)', PAGES.every((p) => /<body class="playlists-page"/.test(read(p))));
const newScripts = [...read('new.html').matchAll(/<script src="([^"]+)"><\/script>/g)].map((m) => m[1]);
check('5f. new.html は data-playlists.js を初期読み込みせず、件数索引(data-counts.js)で選択肢を作る', !newScripts.includes('data-playlists.js') && newScripts.includes('data-counts.js'));
const newJs = read('new.js');
check('5g. new.js: 全件の読み込みは検索・絞り込みを指定したときだけ(条件なしは新着50件のまま)',
  /if \(!hasPlaylistListFilters\(filters\)\) \{[\s\S]*?filterPlaylistsForList\(byAddedDate, filters\)[\s\S]*?return;\s*\}/.test(newJs)
  && (newJs.match(/loadPlaylistsData\(\)/g) || []).length === 2);
check('5h. new.js: 読み込み中に条件が変わったら古い結果で上書きしない・失敗時は再試行できる',
  /seq === requestSeq/.test(newJs) && /showLoadError\(seq\)/.test(newJs) && /retry\.addEventListener\("click", render\)/.test(newJs));
check('5i. playlists.js / new.js とも共通の絞り込み(initPlaylistListControls・filterPlaylistsForList)を使う',
  ['playlists.js', 'new.js'].every((f) => /initPlaylistListControls\(render\)/.test(read(f)) && /filterPlaylistsForList\(/.test(read(f))));

console.log('');
console.log('PASS: ' + pass + '  FAIL: ' + fail);
process.exit(fail ? 1 : 0);
