/**
 * VTuber詳細の meta description(buildStreamerDescription)の回帰テスト。ブラウザ不要(node test-streamer-description.js)。
 *
 *   1. 全VTuberで生成でき、VTuber名で始まり、空・undefined 等が無い。完全一致の重複が無い
 *   2. 挙げるゲームは再生リスト件数 → 動画本数 → 最終更新日 → 名前(文字コード順)で決まり、実行ごとに変わらない
 *   3. ゲーム名は正規名(GAMES の name)のみ・別名なし・再生リストのあるゲームのみ・重複なし・途中で切らない
 *   4. 件数・本数・種類数が元データと一致し、評価を表す言葉を含まない
 *   5. ゲーム1件 / 2件 / 3件 / 多数 / 長いゲーム名 / 特殊文字 / 0件(従来文面)の各ケース
 *   6. streamer.js は description にこの関数を使い、title / canonical の生成は従来どおり
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
console.log('=== VTuber詳細 description 回帰テスト ===');

function stub() { return new Proxy(function () {}, { get: (t, k) => (k === 'length' ? 0 : stub()), apply: () => stub() }); }
function load() {
  const storage = { getItem: () => null, setItem() {}, removeItem() {} };
  const ctx = { console, localStorage: storage, window: { __LIST_DATA_GENERATOR__: true, addEventListener() {}, location: { href: '' }, localStorage: storage },
    document: { addEventListener() {}, querySelector: () => null, querySelectorAll: () => [], getElementById: () => null, createElement: () => stub(), body: null, head: stub() } };
  vm.createContext(ctx);
  for (const f of ['data-core.js', 'data-playlists.js', 'data-standalone.js', 'common.js']) vm.runInContext(read(f), ctx, { filename: f });
  const src = read('streamer.js');
  vm.runInContext(src.slice(0, src.indexOf('(function () {')), ctx, { filename: 'streamer.js' }); // 描画処理(IIFE)は実行しない
  return ctx;
}
const ctx = load();
const GAMES = vm.runInContext('GAMES', ctx), STREAMERS = vm.runInContext('STREAMERS', ctx), PLAYLISTS = vm.runInContext('PLAYLISTS', ctx);
const STANDALONE = vm.runInContext('typeof STANDALONE_PLAYS !== "undefined" ? STANDALONE_PLAYS : []', ctx);
const names = new Set(GAMES.map((g) => g.name));
const aliases = new Set(GAMES.flatMap((g) => [...(g.aliases || []), ...(g.nameJa ? [g.nameJa] : [])]).filter((a) => !names.has(a)));
const withPlays = new Set(PLAYLISTS.map((p) => p.game));
const build = (name) => ctx.buildStreamerDescription(name, PLAYLISTS.filter((p) => p.streamer === name), STANDALONE.filter((p) => p.streamer === name));
const pick = (name) => ctx.pickStreamerDescriptionGames(PLAYLISTS.filter((p) => p.streamer === name), STANDALONE.filter((p) => p.streamer === name)).map((g) => g.name);

// ---- 1. 全件生成 ----
const rows = STREAMERS.map((s) => {
  const items = PLAYLISTS.filter((p) => p.streamer === s.name);
  return { name: s.name, items, games: new Set(items.map((p) => p.game)), d: build(s.name) };
});
check('1a. 全VTuber(' + rows.length + ')で生成でき、VTuber名で始まる', rows.every((r) => typeof r.d === 'string' && r.d.startsWith(r.name) && !/undefined|null|NaN/.test(r.d)));
check('1b. 完全一致の重複が無い', new Set(rows.map((r) => r.d)).size === rows.length);
const withGames = rows.filter((r) => r.games.size);
check('1c. 実況ゲームのある全VTuber(' + withGames.length + ')でゲーム名を1件以上含む', withGames.every((r) => [...r.games].some((g) => r.d.includes(g))));

// ---- 2. 選定ルール ----
const again = load();
check('2a. 別の実行環境で作り直しても全件同じ(決定的)', rows.every((r) => again.buildStreamerDescription(r.name, r.items, STANDALONE.filter((p) => p.streamer === r.name)) === r.d));
const expectedOrder = (items) => {
  const m = new Map();
  for (const p of items) { const s = m.get(p.game) || { name: p.game, c: 0, v: 0, d: '' }; s.c++; s.v += p.videoCount || 0; const dt = p.updatedDate || p.addedDate || ''; if (dt > s.d) s.d = dt; m.set(p.game, s); }
  return [...m.values()].sort((a, b) => b.c - a.c || b.v - a.v || (a.d < b.d ? 1 : a.d > b.d ? -1 : 0) || (a.name < b.name ? -1 : a.name > b.name ? 1 : 0)).map((s) => s.name);
};
check('2b. 並び順 = 再生リスト件数 → 動画本数 → 最終更新日 → 名前(文字コード順)(全件を独立に計算して照合)', withGames.every((r) => JSON.stringify(pick(r.name)) === JSON.stringify(expectedOrder(r.items))));
const tie = [
  { game: 'B', videoCount: 5, updatedDate: '2026-01-01' }, { game: 'A', videoCount: 5, updatedDate: '2026-01-01' },
  { game: 'C', videoCount: 5, updatedDate: '2026-02-01' }, { game: 'D', videoCount: 9, updatedDate: '2025-01-01' }, { game: 'E', videoCount: 1 }, { game: 'E', videoCount: 1 },
];
check('2c. tie-break: 件数(E=2件)→ 本数(D)→ 更新日(C)→ 名前(A,B)', JSON.stringify(ctx.pickStreamerDescriptionGames(tie, []).map((g) => g.name)) === '["E","D","C","A","B"]');
check('2d. 表示順は入力の順番に左右されない', JSON.stringify(ctx.pickStreamerDescriptionGames(tie.slice().reverse(), []).map((g) => g.name)) === '["E","D","C","A","B"]');

// ---- 3. ゲーム名 ----
const problems = [];
for (const r of withGames) {
  const shown = pick(r.name).slice(0, 3).filter((g) => r.d.includes(g));
  for (const g of shown) {
    if (!names.has(g)) problems.push(r.name + ': 正規名でない ' + g);
    if (aliases.has(g)) problems.push(r.name + ': 別名 ' + g);
    if (!withPlays.has(g)) problems.push(r.name + ': 再生リストの無いゲーム ' + g);
  }
  if (new Set(shown).size !== shown.length) problems.push(r.name + ': 重複');
  // 挙げたゲームは選定順の先頭から連続(途中を飛ばしたり切ったりしない)
  const expected = pick(r.name).slice(0, shown.length);
  if (JSON.stringify(expected) !== JSON.stringify(shown)) problems.push(r.name + ': 選定順と不一致 ' + JSON.stringify(shown));
}
check('3a. ゲーム名は正規名のみ・別名なし・再生リストのあるゲームのみ・重複なし・選定順の先頭から', problems.length === 0, problems.slice(0, 5).join('\n         '));
const ctxSrc = read('streamer.js');
check('3b. 挙げるのは最大3件・ゲーム名の合計40字まで(長い名前は切らずに数を減らす)', /const STREAMER_DESC_MAX_GAMES = 3;/.test(ctxSrc) && /const STREAMER_DESC_GAME_NAMES_MAX_CHARS = 40;/.test(ctxSrc));
const longName = 'あ'.repeat(30), longName2 = 'い'.repeat(25);
const dLong = ctx.buildStreamerDescription('テスト', [{ game: longName, videoCount: 3 }, { game: longName, videoCount: 1 }, { game: longName2, videoCount: 1 }, { game: 'X', videoCount: 1 }], []);
// 並び: longName(2件)→ X と longName2 は同数・同本数・更新日なしのため名前の文字コード順で X が先 → longName2 は40字を超えるので挙げない
check('3c. 長いゲーム名: 名前を切らず、入りきらない分は挙げずに「など◯種類」', dLong.includes(longName + '、Xなど3種類のゲーム') && !dLong.includes(longName2), dLong);

// ---- 4. 事実との一致 ----
const factProblems = [];
for (const r of withGames) {
  const v = r.items.reduce((s, p) => s + (p.videoCount || 0), 0);
  if (!r.d.includes('再生リスト' + r.items.length + '件')) factProblems.push(r.name + ': 件数');
  if (v && !r.d.includes('(動画' + v + '本)')) factProblems.push(r.name + ': 本数');
  const shown = pick(r.name).slice(0, 3).filter((g) => r.d.includes(g)).length;
  if (shown < r.games.size && !r.d.includes('など' + r.games.size + '種類のゲーム')) factProblems.push(r.name + ': 種類数');
}
check('4a. 再生リスト件数・動画本数・種類数が元データと一致', factProblems.length === 0, factProblems.slice(0, 5).join(', '));
check('4b. 評価を表す言葉(人気・おすすめ・注目・得意・代表・メイン)を含まない', rows.every((r) => !/人気|おすすめ|注目|得意|代表|メイン/.test(r.d.replace(r.name, ''))));

// ---- 5. ケース ----
const d1 = ctx.buildStreamerDescription('一人', [{ game: 'ELDEN RING', videoCount: 21 }], []);
check('5a. ゲーム1件', d1 === '一人のゲーム実況をまとめたページです。ELDEN RINGの再生リスト1件(動画21本)を掲載しています。', d1);
const d2 = ctx.buildStreamerDescription('二人', [{ game: 'A', videoCount: 2 }, { game: 'B', videoCount: 1 }], []);
check('5b. ゲーム2件は「AとB」', d2 === '二人のゲーム実況をまとめたページです。AとBの再生リスト2件(動画3本)を掲載しています。', d2);
const d3 = ctx.buildStreamerDescription('三人', [{ game: 'A', videoCount: 3 }, { game: 'B', videoCount: 2 }, { game: 'C', videoCount: 1 }], []);
check('5c. ゲーム3件は全件を列挙(「など」なし)', d3 === '三人のゲーム実況をまとめたページです。A、B、Cの再生リスト3件(動画6本)を掲載しています。', d3);
const many = withGames.slice().sort((a, b) => b.games.size - a.games.size)[0];
check('5d. ゲーム多数(' + many.name + ' ' + many.games.size + '種類)は3件 + 「など' + many.games.size + '種類のゲーム」', many.d.includes('など' + many.games.size + '種類のゲーム') && pick(many.name).slice(0, 3).every((g) => many.d.includes(g)), many.d);
const d0v = ctx.buildStreamerDescription('本数なし', [{ game: 'A' }], []);
check('5e. 動画本数が不明なら本数を書かない', d0v === '本数なしのゲーム実況をまとめたページです。Aの再生リスト1件を掲載しています。', d0v);
const special = rows.filter((r) => /['"&<>]/.test(r.d));
check('5f. 特殊文字(\' 等)を含む名前・ゲーム名もそのまま生成(' + special.length + '件。setAttribute で設定するため HTML として解釈されない)',
  special.length > 0 && special.every((r) => r.d.startsWith(r.name)) && /upsertMeta\('meta\[name="description"\]', \{ name: "description", content: description \}\)/.test(read('common.js')));
const zero = rows.filter((r) => !r.games.size);
check('5g. 実況ゲーム0件(' + zero.length + '人・noindex)は従来の文面', zero.every((r) => r.d === r.name + 'が実況したゲームの一覧と再生リストをまとめて紹介。実況したゲーム0種類・再生リスト0件を掲載。'));

// ---- 6. streamer.js での使い方 ----
check('6a. description は buildStreamerDescription、title / canonical / og:image の引数は従来どおり',
  /setPageMeta\(\s*streamer \+ "のゲーム実況・再生リスト一覧 \| " \+ SITE_NAME,\s*buildStreamerDescription\(streamer, items, standalone\),\s*"\/streamer\.html\?streamer=" \+ encodeURIComponent\(streamer\),\s*representativeThumb \? getPlaylistThumbnailUrl\(representativeThumb\) : \(roster && roster\.icon\) \|\| null\s*\);/.test(ctxSrc));
check('6b. og:description / twitter:description は setPageMeta で meta description と同じ文', /upsertMeta\('meta\[property="og:description"\]', \{ property: "og:description", content: description \}\)/.test(read('common.js')) && /upsertMeta\('meta\[name="twitter:description"\]', \{ name: "twitter:description", content: description \}\)/.test(read('common.js')));

console.log('');
console.log('PASS: ' + pass + '  FAIL: ' + fail);
process.exit(fail ? 1 : 0);
