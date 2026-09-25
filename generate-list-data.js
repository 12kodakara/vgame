/**
 * 人気ランキング・新着ページ用の事前集計 data-ranking.js / data-new.js を生成する
 * (自動生成物。手編集しないこと)。
 *
 * ranking.html / new.html は数MBある data-playlists.js を読み込まず、ここで作る上位50件で表示する。
 * 選び方はブラウザと同じ ranking.js の computeRankingList() / new.js の computeNewList() をそのまま使う
 * (人気度は common.js の calculatePopularity())。選び方のロジックをここに複製しない。
 *
 * 使い方(リポジトリのルートで実行):
 *   node generate-list-data.js           … 書き出す(内容が同じなら書き換えない)
 *   node generate-list-data.js --check   … 最新データと一致するかだけ確認する(一致しなければ終了コード1)
 */
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const ROOT = __dirname;
const OUTPUTS = [
  { file: 'data-ranking.js', variable: 'RANKING_LIST', version: 1, compute: 'computeRankingList(getAllPlaylists())',
    title: '人気ランキング(ranking.html)用の上位50件', source: 'ranking.js の computeRankingList()' },
  { file: 'data-new.js', variable: 'NEW_LIST', version: 1, compute: 'computeNewList(getAllPlaylists())',
    title: '新着再生リスト(new.html)用の50件', source: 'new.js の computeNewList()' },
];

function stubElement() {
  // common.js の読み込み時に DOM を触られても落ちないための最小限のダミー
  return new Proxy(function () {}, { get: (t, k) => (k === 'length' ? 0 : stubElement()), apply: () => stubElement() });
}

function loadContext() {
  const storage = { getItem: () => null, setItem: () => {}, removeItem: () => {} };
  const ctx = {
    console, localStorage: storage,
    window: { __LIST_DATA_GENERATOR__: true, addEventListener() {}, localStorage: storage, location: { href: '' } },
    document: { addEventListener() {}, querySelector: () => null, querySelectorAll: () => [], getElementById: () => null,
      createElement: () => stubElement(), body: null, head: stubElement() },
  };
  vm.createContext(ctx);
  for (const f of ['data-core.js', 'data-playlists.js', 'common.js', 'ranking.js', 'new.js']) {
    vm.runInContext(fs.readFileSync(path.join(ROOT, f), 'utf8'), ctx, { filename: f });
  }
  if (!vm.runInContext('getAllPlaylists().length', ctx)) throw new Error('PLAYLISTS が空です。data-playlists.js を確認してください。');
  return ctx;
}

function render(out, items) {
  return [
    '/**',
    ' * ' + out.title + '(自動生成ファイル。手編集しないこと)。',
    ' * generate-list-data.js が data-playlists.js から ' + out.source + ' で生成する。',
    ' */',
    'const ' + out.variable + ' = ' + JSON.stringify({ version: out.version, items: items }, null, 1) + ';',
    '',
  ].join('\n');
}

const ctx = loadContext();
const check = process.argv.includes('--check');
const stale = [];
for (const out of OUTPUTS) {
  // vm 内のオブジェクトを通常の JSON に落とす(プロトタイプを持ち込まない)
  const items = JSON.parse(JSON.stringify(vm.runInContext(out.compute, ctx)));
  const text = render(out, items);
  const abs = path.join(ROOT, out.file);
  const cur = fs.existsSync(abs) ? fs.readFileSync(abs, 'utf8').replace(/\r\n/g, '\n') : null;
  if (cur === text) { console.log(out.file + ' は最新です' + (check ? '。' : '(変更なし)。')); continue; }
  stale.push(out.file);
  if (!check) { fs.writeFileSync(abs, text, 'utf8'); console.log(out.file + ' を生成しました: ' + items.length + '件 / ' + Buffer.byteLength(text) + ' bytes'); }
}
if (check && stale.length) {
  console.error(stale.join(', ') + ' が data-playlists.js と一致しません。node generate-list-data.js を実行してください。');
  process.exit(1);
}
