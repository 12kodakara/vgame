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
// index 対象のVTuber = 再生リストか単発実況があるVTuber(streamer.js の noindex 条件と同じ)
const streamersWithPlays = new Set(PLAYLISTS.map((p) => p.streamer).concat(STANDALONE.map((p) => p.streamer)));
const saOf = (g) => STANDALONE.filter((p) => p.game === g);
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
const rows = GAMES.map((g) => { const items = itemsOf(g.name); const sa = saOf(g.name); return { name: g.name, items, sa, streamers: new Set(items.map((p) => p.streamer).concat(sa.map((p) => p.streamer))), d: build(g.name) }; });
// GAME_PAGE_ROLES(役割を明記するページ)は description の書き出しが subject になる。それ以外はゲーム名で始まる
const ROLES = vm.runInContext('GAME_PAGE_ROLES', ctx);
const roleOf = (g) => (Object.prototype.hasOwnProperty.call(ROLES, g) ? ROLES[g] : null);
check('1a. 全ゲーム(' + rows.length + ')で生成でき、ゲーム名(役割を明記するページは subject)で始まる',
  rows.every((r) => typeof r.d === 'string' && r.d.startsWith(roleOf(r.name) ? roleOf(r.name).subject : r.name) && !/undefined|null|NaN/.test(r.d)));
check('1b. 完全一致の重複が無い', new Set(rows.map((r) => r.d)).size === rows.length);
const target = rows.filter((r) => (r.items.length || r.sa.length) && !LEGACY.includes(r.name));
check('1c. 変更対象(再生リストか単発実況あり・保留ゲーム以外 ' + target.length + ' 件)はすべて VTuber 名を1名以上含む', target.every((r) => pick(r.name).some((s) => r.d.includes(s))));

// ---- 2. 選定ルール ----
const again = load();
check('2a. 別の実行環境で作り直しても全件同じ(決定的)', rows.every((r) => again.buildGameDescription(r.name, r.items, STANDALONE.filter((p) => p.game === r.name)) === r.d));
// 単発実況も1件として数える(本数は動画数、日付は addedDate)
const expectedOrder = (items, sa) => {
  const m = new Map();
  const add = (name, v, dt) => { const s = m.get(name) || { name, c: 0, v: 0, d: '' }; s.c++; s.v += v; if (dt > s.d) s.d = dt; m.set(name, s); };
  for (const p of items) add(p.streamer, p.videoCount || 0, p.updatedDate || p.addedDate || '');
  for (const p of sa || []) add(p.streamer, ctx.standalonePlayCount(p), p.addedDate || '');
  return [...m.values()].sort((a, b) => b.c - a.c || b.v - a.v || (a.d < b.d ? 1 : a.d > b.d ? -1 : 0) || (a.name < b.name ? -1 : a.name > b.name ? 1 : 0)).map((s) => s.name);
};
check('2b. 並び順 = 件数(再生リスト+単発実況) → 動画本数 → 最終更新日 → 名前(文字コード順)(全件を独立に計算して照合)', target.every((r) => JSON.stringify(pick(r.name)) === JSON.stringify(expectedOrder(r.items, r.sa))));
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
    if (!r.streamers.has(s)) problems.push(r.name + ': 再生リストも単発実況も無いVTuber ' + s);
    if (!streamerNames.has(s)) problems.push(r.name + ': 正規VTuberでない ' + s);
    if (!streamersWithPlays.has(s)) problems.push(r.name + ': noindex VTuber ' + s);
  }
  if (new Set(shown).size !== shown.length) problems.push(r.name + ': 重複');
  if (JSON.stringify(pick(r.name).slice(0, shown.length)) !== JSON.stringify(shown)) problems.push(r.name + ': 選定順の先頭からでない');
}
check('3a. VTuber は実際にそのゲームの再生リストか単発実況がある正規VTuberのみ・重複なし・選定順の先頭から', problems.length === 0, problems.slice(0, 5).join('\n         '));
check('3b. 挙げるのは最大3名・名前の合計30字まで(長い名前は切らずに数を減らす)', /const GAME_DESC_MAX_STREAMERS = 3;/.test(read('game.js')) && /const GAME_DESC_STREAMER_NAMES_MAX_CHARS = 30;/.test(read('game.js')));
const longA = 'あ'.repeat(20), longB = 'い'.repeat(15);
const dLong = ctx.buildGameDescription('G', [{ streamer: longA, videoCount: 3 }, { streamer: longA, videoCount: 1 }, { streamer: longB, videoCount: 5 }, { streamer: 'X', videoCount: 1 }], []);
check('3c. 長い名前: 名前を切らず、入りきらない分は挙げずに「など◯組」', dLong.includes(longA + '、Xなど3組') === false && dLong.includes(longA + 'など3組') && !dLong.includes(longB), dLong);

// ---- 4. 事実との一致 ----
const fact = [];
for (const r of target) {
  const v = r.items.reduce((s, p) => s + (p.videoCount || 0), 0) + r.sa.reduce((s, p) => s + ctx.standalonePlayCount(p), 0);
  const lu = r.items.reduce((l, p) => { const d = p.updatedDate || p.addedDate || ''; return d && d > l ? d : l; }, '');
  // 件数は実在するものだけ: 再生リストのみ / 再生リスト・単発実況 / 単発実況のみ
  const contents = 'の' + [r.items.length ? '再生リスト' + r.items.length + '件' : '', r.sa.length ? '単発実況' + r.sa.length + '件' : ''].filter(Boolean).join('・');
  if (!r.d.includes(contents)) fact.push(r.name + ': 件数');
  if (!r.items.length && r.d.includes('再生リスト')) fact.push(r.name + ': 再生リストが無いのに再生リストと書いている');
  if (v && !r.d.includes('動画' + v + '本')) fact.push(r.name + ': 本数');
  if (lu && !r.d.includes('最終更新 ' + ctx.formatDate(lu))) fact.push(r.name + ': 最終更新');
  const shown = pick(r.name).slice(0, 3).filter((s) => r.d.includes(s)).length;
  if (shown < r.streamers.size && !r.d.includes('など' + r.streamers.size + '組')) fact.push(r.name + ': 組数');
}
check('4a. 再生リスト・単発実況の件数・動画本数・最終更新日・組数が元データと一致', fact.length === 0, fact.slice(0, 5).join(', '));
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
const dMix = ctx.buildGameDescription('G', [{ streamer: 'A', videoCount: 2 }], [{ streamer: 'B', videos: [{ url: 'u' }] }]);
check('5h. 再生リスト+単発実況: 両方の件数を書く', dMix === 'GのVTuber実況をまとめたページです。AとBの再生リスト1件・単発実況1件(動画3本)を掲載しています。', dMix);
const dSingle = ctx.buildGameDescription('G', [], [{ streamer: 'B', videos: [{ url: 'u' }] }]);
check('5i. 単発実況のみ: 「再生リスト」と書かない', dSingle === 'GのVTuber実況をまとめたページです。Bの単発実況1件(動画1本)を掲載しています。', dSingle);

// ---- 6. 従来の文面を維持するもの ----
const noPlays = rows.filter((r) => !r.items.length && !r.sa.length);
check('6a. 再生リストも単発実況も0件(noindex ' + noPlays.length + '件)は従来の文面', noPlays.length > 0 && noPlays.every((r) => r.d === legacyText(r.name)));
check('6b. 正規名の設計を保留中のゲーム(' + LEGACY.join(' / ') + ')は従来の文面', LEGACY.every((g) => rows.some((r) => r.name === g) && build(g) === legacyText(g)));

// ---- 7. game.js での使い方 ----
const js = read('game.js');
check('7a. description は buildGameDescription、title / canonical / og:image の引数は従来どおり(GAME_PAGE_ROLES のゲームだけ title を差し替え)',
  /setPageMeta\(\s*\(role \? role\.title : gameDisplayName\(game\) \+ "を実況しているVTuber一覧"\) \+ " \| " \+ SITE_NAME,\s*buildGameDescription\(game, items, standalone\),\s*"\/game\.html\?game=" \+ encodeURIComponent\(game\),\s*representativeThumb \? getPlaylistThumbnailUrl\(representativeThumb\) : null\s*\);/.test(js));
// ---- 8. 役割を明記するページ(GAME_PAGE_ROLES) ----
const roleKeys = Object.keys(ROLES);
check('8a. GAME_PAGE_ROLES のキーはすべて GAMES にあるゲーム', roleKeys.length > 0 && roleKeys.every((g) => GAMES.some((x) => x.name === g)), roleKeys.join(','));
check('8b. 役割の文面(heading / title / lead / subject)はすべてあり、件数などの数字を直書きしない',
  roleKeys.every((g) => ['heading', 'title', 'lead', 'subject'].every((k) => typeof ROLES[g][k] === 'string' && ROLES[g][k] && !/[0-9０-９]/.test(ROLES[g][k]))));
check('8c. 役割を明記するページの description も件数・VTuber名は自動生成(元データと一致)',
  roleKeys.every((g) => { const it = itemsOf(g); const d = build(g); return d.startsWith(ROLES[g].subject + 'をまとめたページです。') && d.includes('再生リスト' + it.length + '件') && pick(g).some((s) => d.includes(s)); }));
check('8d. 役割の文面に元のゲーム名(例: ポケモンシリーズ)を使わない(同名のシリーズページと検索意図を分けるため)',
  roleKeys.every((g) => ['heading', 'title', 'subject'].every((k) => !ROLES[g][k].includes(g))));
check('8e. 役割を明記するページは旧ポケモン・旧カービィの2件だけ(他のゲームの title・description は変えない)',
  JSON.stringify(roleKeys.slice().sort()) === JSON.stringify(['ポケモンシリーズ', '星のカービィシリーズ'].sort()), roleKeys.join(','));
const KIRBY_HUB = '星のカービィシリーズ', kirbyHubItems = itemsOf(KIRBY_HUB);
check('8f. 旧「星のカービィシリーズ」: description は役割(複数作品にわたる実況)で始まり、件数・VTuber名は元データから(再生リスト' + kirbyHubItems.length + '件)',
  kirbyHubItems.length > 0 && build(KIRBY_HUB).startsWith('複数のカービィ作品にわたるVTuber実況をまとめたページです。')
  && build(KIRBY_HUB).includes('再生リスト' + kirbyHubItems.length + '件') && pick(KIRBY_HUB).some((s) => build(KIRBY_HUB).includes(s)), build(KIRBY_HUB));
check('8g. 旧カービィの文面はポケモンの流用ではなく、掲載していない「企画」を書かない',
  ['heading', 'title', 'lead', 'subject'].every((k) => ROLES[KIRBY_HUB][k] !== ROLES['ポケモンシリーズ'][k] && !/ポケモン|企画/.test(ROLES[KIRBY_HUB][k])));

check('7b. og:description / twitter:description は setPageMeta で meta description と同じ文', /upsertMeta\('meta\[property="og:description"\]', \{ property: "og:description", content: description \}\)/.test(read('common.js')) && /upsertMeta\('meta\[name="twitter:description"\]', \{ name: "twitter:description", content: description \}\)/.test(read('common.js')));

console.log('');
console.log('PASS: ' + pass + '  FAIL: ' + fail);
process.exit(fail ? 1 : 0);
