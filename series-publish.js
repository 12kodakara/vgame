/**
 * ゲームシリーズページ(series.html?series=<ID>)の公開判定。sitemap・公開ファイル・公開前チェックが共通で使う。
 *
 * 公開する = data-series.js の publish が true、かつ series.js の公開条件(meetsSeriesPageThreshold)を満たす。
 * 判定は series.js の computeSeriesPage / meetsSeriesPageThreshold をそのまま使い、ここで条件を作り直さない
 * (ページ側の index / noindex 判定と必ず一致させるため)。
 *
 *   node series-publish.js           … 公開シリーズのID・URL・内部リンク対象を表示
 *   node series-publish.js --json    … 同じ内容をJSONで出力(PowerShell から読むため ASCII にエスケープ)
 *   --root <dir>    データを読むフォルダ(既定: このファイルのフォルダ)
 *   --series <file> シリーズ定義(既定: <root>/data-series.js)。テストで fixture を使うときに指定する
 *
 * 内部リンク対象(gameLinks): 公開シリーズの本編の作品と hubGame → シリーズID。
 * relatedGames(別シリーズの関連作品)は含めない(ゲーム詳細で親子関係を誤らないため)。
 */
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');

/** シリーズページの URL(series.js の canonical と同じ形)。 */
function seriesUrlPath(id) {
  return '/series.html?series=' + encodeURIComponent(id);
}

/** データを読み込み、series.js の関数を使える状態にする。 */
function loadSeriesContext(root, seriesFile) {
  const ctx = {};
  vm.createContext(ctx);
  for (const f of ['data-core.js', 'data-playlists.js', 'data-standalone.js']) {
    vm.runInContext(fs.readFileSync(path.join(root, f), 'utf8'), ctx, { filename: f });
  }
  vm.runInContext(fs.readFileSync(seriesFile || path.join(root, 'data-series.js'), 'utf8'), ctx, { filename: 'data-series.js' });
  vm.runInContext(fs.readFileSync(path.join(root, 'series.js'), 'utf8'), ctx, { filename: 'series.js' });
  return ctx;
}

/** 公開するシリーズの判定結果。 */
function getSeriesPublication(root, seriesFile) {
  const ctx = loadSeriesContext(root, seriesFile);
  const pick = (name) => vm.runInContext('typeof ' + name + ' === "undefined" ? undefined : ' + name, ctx);
  const series = pick('SERIES_PAGES') || {};
  const playlists = pick('PLAYLISTS') || [];
  const standalone = pick('STANDALONE_PLAYS') || [];
  const published = [], skipped = [];
  for (const id of Object.keys(series)) {
    const def = series[id];
    // code: not-published(publish が true でない)/ below-threshold(publish: true なのに公開条件を満たさない。check-site がエラーにする)
    if (def.publish !== true) { skipped.push({ id, code: 'not-published', reason: 'publish が true でない' }); continue; }
    if (!ctx.meetsSeriesPageThreshold(ctx.computeSeriesPage(playlists, standalone, def))) { skipped.push({ id, code: 'below-threshold', reason: '公開条件を満たさない' }); continue; }
    published.push(id);
  }
  const gameLinks = {};
  for (const id of published) {
    const def = series[id];
    for (const g of def.games.concat(def.hubGame ? [def.hubGame] : [])) gameLinks[g] = id;
  }
  return { published, urls: published.map(seriesUrlPath), gameLinks, skipped };
}

module.exports = { seriesUrlPath, getSeriesPublication };

if (require.main === module) {
  const args = process.argv.slice(2);
  const opt = (name) => { const i = args.indexOf(name); return i >= 0 ? args[i + 1] : undefined; };
  const root = path.resolve(opt('--root') || __dirname);
  const seriesFile = opt('--series') ? path.resolve(opt('--series')) : undefined;
  const result = getSeriesPublication(root, seriesFile);
  if (args.includes('--json')) {
    process.stdout.write(JSON.stringify(result).replace(/[^\x00-\x7e]/g, (c) => '\\u' + c.charCodeAt(0).toString(16).padStart(4, '0')));
  } else {
    console.log('公開するシリーズ: ' + (result.published.length ? result.published.join(', ') : 'なし'));
    result.urls.forEach((u) => console.log('  ' + u));
    result.skipped.forEach((s) => console.log('  公開しない: ' + s.id + '(' + s.reason + ')'));
  }
}
