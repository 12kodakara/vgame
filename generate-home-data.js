/**
 * トップページ用の事前集計 data-home.js を生成する(自動生成物。手編集しないこと)。
 *
 * トップページは数MBある data-playlists.js を初期表示で読み込まず、ここで作る
 * HOME_SUMMARY(掲載件数・人気のゲーム・最近更新された再生リスト・人気VTuber)で表示する。
 * 集計はブラウザと同じ home.js の computeHomeSummary() をそのまま使う
 * (人気度は common.js の calculatePopularity())。集計ロジックをここに複製しない。
 *
 * 使い方(リポジトリのルートで実行):
 *   node generate-home-data.js           … data-home.js を書き出す(内容が同じなら書き換えない)
 *   node generate-home-data.js --check   … data-home.js が最新データと一致するかだけ確認する
 *                                          (一致しなければ終了コード1)
 *
 * data-playlists.js / data-core.js を更新したら必ず実行する。GitHub Actions の
 * playlist metadata refresh と home data の各 workflow が自動で実行している。
 */
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const ROOT = __dirname;
const OUT = path.join(ROOT, 'data-home.js');

function stubElement() {
  // common.js の読み込み時に DOM を触られても落ちないための最小限のダミー
  return new Proxy(function () {}, {
    get: (t, k) => (k === 'length' ? 0 : stubElement()),
    apply: () => stubElement(),
  });
}

function computeSummary() {
  const storage = { getItem: () => null, setItem: () => {}, removeItem: () => {} };
  const ctx = {
    console,
    window: { __HOME_SUMMARY_GENERATOR__: true, addEventListener() {}, localStorage: storage, location: { href: '' } },
    document: {
      addEventListener() {}, querySelector: () => null, querySelectorAll: () => [],
      getElementById: () => null, createElement: () => stubElement(), body: null, head: stubElement(),
    },
    localStorage: storage,
  };
  vm.createContext(ctx);
  for (const f of ['data-core.js', 'data-playlists.js', 'common.js', 'home.js']) {
    vm.runInContext(fs.readFileSync(path.join(ROOT, f), 'utf8'), ctx, { filename: f });
  }
  const playlists = vm.runInContext('getAllPlaylists()', ctx);
  if (!playlists.length) throw new Error('PLAYLISTS が空です。data-playlists.js を確認してください。');
  const summary = vm.runInContext('computeHomeSummary(getAllPlaylists())', ctx);
  // vm 内のオブジェクトを通常の JSON に落とす(プロトタイプを持ち込まない)
  return JSON.parse(JSON.stringify(summary));
}

function render(summary) {
  return [
    '/**',
    ' * トップページ用の事前集計(自動生成ファイル。手編集しないこと)。',
    ' * generate-home-data.js が data-playlists.js から home.js の computeHomeSummary() で生成する。',
    ' * トップページは数MBある data-playlists.js の代わりにこれを読み込んで初期表示する。',
    ' */',
    'const HOME_SUMMARY = ' + JSON.stringify(summary, null, 2) + ';',
    '',
  ].join('\n');
}

const text = render(computeSummary());
const current = fs.existsSync(OUT) ? fs.readFileSync(OUT, 'utf8').replace(/\r\n/g, '\n') : null;

if (process.argv.includes('--check')) {
  if (current === text) {
    console.log('data-home.js は最新です。');
    process.exit(0);
  }
  console.error('data-home.js が data-playlists.js と一致しません。node generate-home-data.js を実行してください。');
  process.exit(1);
}

if (current === text) {
  console.log('data-home.js は最新です(変更なし)。');
} else {
  fs.writeFileSync(OUT, text, 'utf8');
  console.log('data-home.js を生成しました: ' + Buffer.byteLength(text) + ' bytes');
}
