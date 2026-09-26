/**
 * ジャンル別ページ(genre.html)用の事前集計 data-genres.js を生成する(自動生成物。手編集しないこと)。
 *
 * genre.html は数MBある data-playlists.js を読み込まず、ここで作る集計で表示する。
 * 集計はブラウザと同じ genre.js の computeGenrePage() をそのまま使い、対象は GENRE_PAGE_IDS のジャンルだけ。
 *
 * 使い方(リポジトリのルートで実行):
 *   node generate-genre-data.js           … 書き出す(内容が同じなら書き換えない)
 *   node generate-genre-data.js --check   … 最新データと一致するかだけ確認する(一致しなければ終了コード1)
 */
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const ROOT = __dirname;
const OUT_FILE = 'data-genres.js';

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
  for (const f of ['data-core.js', 'data-playlists.js', 'common.js', 'genre.js']) {
    vm.runInContext(fs.readFileSync(path.join(ROOT, f), 'utf8'), ctx, { filename: f });
  }
  if (!vm.runInContext('getAllPlaylists().length', ctx)) throw new Error('PLAYLISTS が空です。data-playlists.js を確認してください。');
  return ctx;
}

const ctx = loadContext();
const ids = JSON.parse(JSON.stringify(vm.runInContext('GENRE_PAGE_IDS', ctx)));
const version = vm.runInContext('GENRE_PAGES_VERSION', ctx);
const genres = {};
for (const id of ids) genres[id] = JSON.parse(JSON.stringify(vm.runInContext('computeGenrePage(getAllPlaylists(), ' + JSON.stringify(id) + ')', ctx)));

const text = [
  '/**',
  ' * ジャンル別ページ(genre.html)用の集計(自動生成ファイル。手編集しないこと)。',
  ' * generate-genre-data.js が data-playlists.js から genre.js の computeGenrePage() で生成する。',
  ' */',
  'const GENRE_PAGES = ' + JSON.stringify({ version: version, genres: genres }, null, 1) + ';',
  '',
].join('\n');

const check = process.argv.includes('--check');
const abs = path.join(ROOT, OUT_FILE);
const cur = fs.existsSync(abs) ? fs.readFileSync(abs, 'utf8').replace(/\r\n/g, '\n') : null;
if (cur === text) {
  console.log(OUT_FILE + ' は最新です' + (check ? '。' : '(変更なし)。'));
} else if (check) {
  console.error(OUT_FILE + ' が data-playlists.js と一致しません。node generate-genre-data.js を実行してください。');
  process.exit(1);
} else {
  fs.writeFileSync(abs, text, 'utf8');
  console.log(OUT_FILE + ' を生成しました: ' + ids.map((id) => id + '(ゲーム' + genres[id].stats.games + '・VTuber' + genres[id].stats.streamers + '・再生リスト' + genres[id].stats.playlists + ')').join(', ') + ' / ' + Buffer.byteLength(text) + ' bytes');
}
