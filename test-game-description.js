/**
 * ゲーム詳細の meta description(buildGameDescription)の回帰テスト。ブラウザ不要(node test-game-description.js)。
 *
 *   1. 全ゲームで生成でき、正規ゲーム名で始まる。完全一致の重複が無い
 *   2. 挙げる VTuber は再生リスト件数 → 動画本数 → 最終更新日 → 名前(文字コード順)で決まり、実行ごとに変わらない
 *   3. VTuber は実際にそのゲームの再生リストがある正規 VTuber のみ・重複なし・途中で切らない
 *   4. 件数・本数・組数が元データと一致し、評価を表す言葉を含まない
 *   5. VTuber 1人 / 2人 / 3人 / 多数 / 長い名前 / 特殊文字の各ケース
 *   6. 再生リスト0件(noindex)と正規名の設計を保留中のゲーム(ポケポケ / Pocket、Overwatch / 2)は従来の文面
 *   7. game.js は description にこの関数を使い、title / canonical / og:image の生成は従来どおり
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
console.log('=== ゲーム詳細 description 回帰テスト ===');

function stub() { return new Proxy(function () {}, { get: (t, k) => (k === 'length' ? 0 : stub()), apply: () => stub() }); }
function load() {
  const storage = { getItem: () => null, setItem() {}, removeItem() {} };
  const ctx = { console, localStorage: storage, window: { __LIST_DATA_GENERATOR__: true, addEventListener() {}, location: { href: '' }, localStorage: storage },
    document: { addEventListener() {}, querySelector: () => null, querySelectorAll: () => [], getElementById: () => null, createElement: () => stub(), body: null, head: stub() } };
  vm.createContext(ctx);
  for (const f of ['data-core.js', 'data-playlists.js', 'data-standalone.js', 'common.js']) vm.runInContext(read(f), ctx, { filename: f });
  const src = read('game.js');
  vm.runInContext(src.slice(0, src.indexOf('(function () {')), ctx, { filename: 'game.js' }); // 描画処理(IIFE)は実行しない
  return ctx;
}
const ctx = load();
const GAMES = vm.runInContext('GAMES', ctx), STREAMERS = vm.runInContext('STREAMERS', ctx), PLAYLISTS = vm.runInContext('PLAYLISTS', ctx);
const STANDALONE = vm.runInContext('typeof STANDALONE_PLAYS !== "undefined" ? STANDALONE_PLAYS : []', ctx);
const streamerNames = new Set(STREAMERS.map((s) => s.name));
const streamersWithPlays = new Set(PLAYLISTS.map((p) => p.streamer));
const LEGACY = ['ポケモンカードゲーム Pokémon Trading Card Game Pocket', 'ポケポケ', 'Overwatch', 'Overwatch 2'];
const itemsOf = (g) => PLAYLISTS.filter((p) => p.game === g);
const build = (g) => ctx.buildGameDescription(g, itemsOf(g), STANDALONE.filter((p) => p.game === g));
const pick = (g) => ctx.pickGameDescriptionStreamers(itemsOf(g), STANDALONE.filter((p) => p.game === g)).map((s) => s.name);
const legacyText = (g) => {
  const it = itemsOf(g); const st = new Set(it.map((p) => p.streamer)); const v = it.reduce((a, p) => a + (p.videoCount || 0), 0);
  const lu = it.reduce((l, p) => { const d = p.updatedDate || p.addedDate || ''; return d && d > l ? d : l; }, '');
  return g + 'を実況しているVTuberの再生リスト・動画をまとめて紹介。実況VTuber' + st.size + '組・再生リスト' + it.length + '件' + (v ? '・動画' + v + '本' : '') + (lu ? '(最終更新: ' + ctx.formatDate(lu) + ')' : '') + '。';
};

// ---- 1. 全件生成 ----
const rows = GAMES.map((g) => { const items = itemsOf(g.name); return { name: g.name, items, streamers: new Set(items.map((p) => p.streamer)), d: build(g.name) }; });
check('1a. 全ゲーム(' + rows.length + ')で生成でき、ゲーム名で始まる', rows.every((r) => typeof r.d === 'string' && r.d.startsWith(r.name) && !/undefined|null|NaN/.test(r.d)));
check('1b. 完全一致の重複が無い', new Set(rows.map((r) => r.d)).size === rows.length);
const target = rows.filter((r) => r.items.length && !LEGACY.includes(r.name));
check('1c. 変更対象(再生リストあり・保留ゲーム以外 ' + target.length + ' 件)はすべて VTuber 名を1名以上含む', target.every((r) => pick(r.name).some((s) => r.d.includes(s))));

// ---- 2. 選定ルール ----
const again = load();
check('2a. 別の実行環境で作り直しても全件同じ(決定的)', rows.every((r) => again.buildGameDescription(r.name, r.items, STANDALONE.filter((p) => p.game === r.name)) === r.d));
const expectedOrder = (items) => {
  const m = new Map();
  for (const p of items) { const s = m.get(p.streamer) || { name: p.streamer, c: 0, v: 0, d: '' }; s.c++; s.v += p.videoCount || 0; const dt = p.updatedDate || p.addedDate || ''; if (dt > s.d) s.d = dt; m.set(p.streamer, s); }
  return [...m.values()].sort((a, b) => b.c - a.c || b.v - a.v || (a.d < b.d ? 1 : a.d > b.d ? -1 : 0) || (a.name < b.name ? -1 : a.name > b.name ? 1 : 0)).map((s) => s.name);
};
check('2b. 並び順 = 再生リスト件数 → 動画本数 → 最終更新日 → 名前(文字コード順)(全件を独立に計算して照合)', target.every((r) => JSON.stringify(pick(r.name)) === JSON.stringify(expectedOrder(r.items))));
const tie = [
  { streamer: 'B', videoCount: 5, updatedDate: '2026-01-01' }, { streamer: 'A', videoCount: 5, updatedDate: '2026-01-01' },
  { streamer: 'C', videoCount: 5, updatedDate: '2026-02-01' }, { streamer: 'D', videoCount: 9, updatedDate: '2025-01-01' }, { streamer: 'E', videoCount: 1 }, { streamer: 'E', videoCount: 1 },
];
check('2c. tie-break: 件数(E=2件)→ 本数(D)→ 更新日(C)→ 名前(A,B)・入力順に左右されない',
  JSON.stringify(ctx.pickGameDescriptionStreamers(tie, []).map((s) => s.name)) === '["E","D","C","A","B"]' && JSON.stringify(ctx.pickGameDescriptionStreamers(tie.slice().reverse(), []).map((s) => s.name)) === '["E","D","C","A","B"]');

// ---- 3. VTuber の対応関係 ----
const problems = [];
for (const r of target) {
  const shown = pick(r.name).slice(0, 3).filter((s) => r.d.includes(s));
  for (const s of shown) {
    if (!r.streamers.has(s)) problems.push(r.name + ': 再生リストの無いVTuber ' + s);
    if (!streamerNames.has(s)) problems.push(r.name + ': 正規VTuberでない ' + s);
    if (!streamersWithPlays.has(s)) problems.push(r.name + ': noindex VTuber ' + s);
  }
  if (new Set(shown).size !== shown.length) problems.push(r.name + ': 重複');
  if (JSON.stringify(pick(r.name).slice(0, shown.length)) !== JSON.stringify(shown)) problems.push(r.name + ': 選定順の先頭からでない');
}
check('3a. VTuber は実際にそのゲームの再生リストがある正規VTuberのみ・重複なし・選定順の先頭から', problems.length === 0, problems.slice(0, 5).join('\n         '));
check('3b. 挙げるのは最大3名・名前の合計30字まで(長い名前は切らずに数を減らす)', /const GAME_DESC_MAX_STREAMERS = 3;/.test(read('game.js')) && /const GAME_DESC_STREAMER_NAMES_MAX_CHARS = 30;/.test(read('game.js')));
const longA = 'あ'.repeat(20), longB = 'い'.repeat(15);
const dLong = ctx.buildGameDescription('G', [{ streamer: longA, videoCount: 3 }, { streamer: longA, videoCount: 1 }, { streamer: longB, videoCount: 5 }, { streamer: 'X', videoCount: 1 }], []);
check('3c. 長い名前: 名前を切らず、入りきらない分は挙げずに「など◯組」', dLong.includes(longA + '、Xなど3組') === false && dLong.includes(longA + 'など3組') && !dLong.includes(longB), dLong);

// ---- 4. 事実との一致 ----
const fact = [];
for (const r of target) {
  const v = r.items.reduce((s, p) => s + (p.videoCount || 0), 0);
  const lu = r.items.reduce((l, p) => { const d = p.updatedDate || p.addedDate || ''; return d && d > l ? d : l; }, '');
  if (!r.d.includes('の再生リスト' + r.items.length + '件')) fact.push(r.name + ': 件数');
  if (v && !r.d.includes('動画' + v + '本')) fact.push(r.name + ': 本数');
  if (lu && !r.d.includes('最終更新 ' + ctx.formatDate(lu))) fact.push(r.name + ': 最終更新');
  const shown = pick(r.name).slice(0, 3).filter((s) => r.d.includes(s)).length;
  if (shown < r.streamers.size && !r.d.includes('など' + r.streamers.size + '組')) fact.push(r.name + ': 組数');
}
check('4a. 再生リスト件数・動画本数・最終更新日・組数が元データと一致', fact.length === 0, fact.slice(0, 5).join(', '));
check('4b. 評価を表す言葉(人気・代表・有名・おすすめ・注目)を含まない', target.every((r) => !/人気|代表|有名|おすすめ|注目/.test(r.d.replace(r.name, ''))));

// ---- 5. ケース ----
const d1 = ctx.buildGameDescription('ELDEN RING', [{ streamer: '一人', videoCount: 21, updatedDate: '2026-01-02' }], []);
check('5a. VTuber 1人', d1 === 'ELDEN RINGのVTuber実況をまとめたページです。一人の再生リスト1件(動画21本・最終更新 2026/1/2)を掲載しています。', d1);
const d2 = ctx.buildGameDescription('G', [{ streamer: 'A', videoCount: 2 }, { streamer: 'B', videoCount: 1 }], []);
check('5b. VTuber 2人は「AとB」・日付が無ければ書かない', d2 === 'GのVTuber実況をまとめたページです。AとBの再生リスト2件(動画3本)を掲載しています。', d2);
const d3 = ctx.buildGameDescription('G', [{ streamer: 'A', videoCount: 3 }, { streamer: 'B', videoCount: 2 }, { streamer: 'C', videoCount: 1 }], []);
check('5c. VTuber 3人は全員を列挙(「など」なし)', d3 === 'GのVTuber実況をまとめたページです。A、B、Cの再生リスト3件(動画6本)を掲載しています。', d3);
const many = target.slice().sort((a, b) => b.streamers.size - a.streamers.size)[0];
check('5d. VTuber多数(' + many.name + ' ' + many.streamers.size + '組)は3名 + 「など' + many.streamers.size + '組」', many.d.includes('など' + many.streamers.size + '組の再生リスト') && pick(many.name).slice(0, 3).every((s) => many.d.includes(s)), many.d);
const dNone = ctx.buildGameDescription('G', [{ streamer: 'A' }], []);
check('5e. 動画本数・日付が無ければ括弧ごと書かない', dNone === 'GのVTuber実況をまとめたページです。Aの再生リスト1件を掲載しています。', dNone);
const special = target.filter((r) => /['"&<>]/.test(r.d));
check('5f. 特殊文字(\' 等)を含むゲーム名・VTuber名もそのまま生成(' + special.length + '件。setAttribute で設定するため HTML として解釈されない)',
  special.length > 0 && special.every((r) => r.d.startsWith(r.name)) && /upsertMeta\('meta\[name="description"\]', \{ name: "description", content: description \}\)/.test(read('common.js')));
const longest = target.slice().sort((a, b) => b.name.length - a.name.length)[0];
check('5g. 最も長いゲーム名(' + longest.name.length + '字)も切らずに先頭に入る', longest.d.startsWith(longest.name + 'のVTuber実況をまとめたページです。'));

// ---- 6. 従来の文面を維持するもの ----
const noPlays = rows.filter((r) => !r.items.length);
check('6a. 再生リスト0件(noindex ' + noPlays.length + '件)は従来の文面', noPlays.length > 0 && noPlays.every((r) => r.d === legacyText(r.name)));
check('6b. 正規名の設計を保留中のゲーム(' + LEGACY.join(' / ') + ')は従来の文面', LEGACY.every((g) => rows.some((r) => r.name === g) && build(g) === legacyText(g)));

// ---- 7. game.js での使い方 ----
const js = read('game.js');
check('7a. description は buildGameDescription、title / canonical / og:image の引数は従来どおり',
  /setPageMeta\(\s*gameDisplayName\(game\) \+ "を実況しているVTuber一覧 \| " \+ SITE_NAME,\s*buildGameDescription\(game, items, standalone\),\s*"\/game\.html\?game=" \+ encodeURIComponent\(game\),\s*representativeThumb \? getPlaylistThumbnailUrl\(representativeThumb\) : null\s*\);/.test(js));
check('7b. og:description / twitter:description は setPageMeta で meta description と同じ文', /upsertMeta\('meta\[property="og:description"\]', \{ property: "og:description", content: description \}\)/.test(read('common.js')) && /upsertMeta\('meta\[name="twitter:description"\]', \{ name: "twitter:description", content: description \}\)/.test(read('common.js')));

console.log('');
console.log('PASS: ' + pass + '  FAIL: ' + fail);
process.exit(fail ? 1 : 0);
