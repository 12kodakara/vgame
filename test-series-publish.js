/**
 * ゲームシリーズページの公開基盤(series-publish.js と、それを使う sitemap・build-public・check-site)の回帰テスト。
 * 本番の data-series.js は書き換えない。publish: true は一時フォルダの fixture だけで試す。
 *
 *   1. 実データ: publish: false のシリーズは公開対象にならない(sitemap・公開ファイル・内部リンク対象のどれにも入らない)
 *   2. fixture: publish: true のシリーズだけが公開対象になる。公開条件を満たさなければ true でも公開しない。
 *      内部リンク対象は本編の作品と hubGame だけ(relatedGames は入れない)
 *   3. 通し(PowerShell がある環境のみ。作業ツリーを一時フォルダにコピーして実行):
 *      generate-sitemap / build-public / check-site が公開シリーズだけを扱う
 * 失敗が1件でもあれば終了コード1。
 */
'use strict';
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');
const { getSeriesPublication, seriesUrlPath } = require('./series-publish.js');

const ROOT = __dirname;
let pass = 0, fail = 0;
function check(name, ok, detail) {
  if (ok) { pass++; console.log('  [PASS] ' + name); } else { fail++; console.log('  [FAIL] ' + name + (detail ? '\n         ' + String(detail).slice(0, 400) : '')); }
}
console.log('=== ゲームシリーズページ 公開基盤テスト ===');

const seriesSrc = fs.readFileSync(path.join(ROOT, 'data-series.js'), 'utf8');
/** 指定したシリーズだけ publish: true にした定義(本番ファイルは変えない) */
const publishOnly = (ids, src = seriesSrc) => ids.reduce((s, id) => s.replace(new RegExp('(\\n  ' + id + ': \\{[\\s\\S]*?publish: )false'), '$1true'), src);
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'vgame-series-publish-'));
const fixture = (name, text) => { const f = path.join(tmp, name); fs.writeFileSync(f, text); return f; };

try {
  // ---- 1. 実データ ----
  const real = getSeriesPublication(ROOT);
  check('1a. 実データ: 公開するシリーズは0件(pokemon・kirby・ryugagotoku はすべて publish: false)',
    real.published.length === 0 && real.skipped.length === 3 && real.skipped.every((s) => s.reason === 'publish が true でない'), JSON.stringify(real));
  // 行頭のプロパティだけを見る(ファイル先頭の説明コメントに「publish : true のときだけ…」とあるため)
  check('1b. 実データ: data-series.js に publish: true が1つも無い', !/^\s*publish\s*:\s*true/m.test(seriesSrc));
  check('1b2. 判定用の検索はコメントではなくプロパティに当たる(fixture の true は検出する)', /^\s*publish\s*:\s*true/m.test(publishOnly(['kirby'])));
  check('1c. 実データ: sitemap.xml に series.html が無い', !/series\.html/.test(fs.readFileSync(path.join(ROOT, 'sitemap.xml'), 'utf8')));
  check('1d. 実データ: 内部リンク対象も0件', Object.keys(real.gameLinks).length === 0);

  // ---- 2. fixture ----
  const kirby = getSeriesPublication(ROOT, fixture('kirby.js', publishOnly(['kirby'])));
  check('2a. fixture(kirby だけ publish: true): 公開対象は kirby だけ', JSON.stringify(kirby.published) === '["kirby"]', JSON.stringify(kirby.published));
  check('2b. 公開URLは series.html?series=<ID>(canonical と同じ形)', JSON.stringify(kirby.urls) === JSON.stringify(['/series.html?series=kirby']) && seriesUrlPath('kirby') === '/series.html?series=kirby');
  const ctx = {}; require('vm').createContext(ctx); require('vm').runInContext(seriesSrc, ctx);
  const SERIES = JSON.parse(JSON.stringify(require('vm').runInContext('SERIES_PAGES', ctx)));
  const kirbyLinks = Object.keys(kirby.gameLinks).sort();
  check('2c. 内部リンク対象は kirby の本編の作品と hubGame だけ(ほかのシリーズの作品は入らない)',
    JSON.stringify(kirbyLinks) === JSON.stringify(SERIES.kirby.games.concat([SERIES.kirby.hubGame]).sort()) && Object.values(kirby.gameLinks).every((v) => v === 'kirby'));
  const ryu = getSeriesPublication(ROOT, fixture('ryu.js', publishOnly(['ryugagotoku'])));
  check('2d. fixture(ryugagotoku): 関連作品(JUDGE)は内部リンク対象に入れない(別シリーズの親にしない)',
    ryu.published[0] === 'ryugagotoku' && (SERIES.ryugagotoku.relatedGames || []).every((g) => !(g in ryu.gameLinks)) && SERIES.ryugagotoku.games.every((g) => ryu.gameLinks[g] === 'ryugagotoku'));
  const thin = fixture('thin.js', 'const SERIES_PAGES = { thin: { name: "テスト用シリーズ", publish: true, hubGame: "", games: ["龍が如く3"] } };');
  const thinRes = getSeriesPublication(ROOT, thin);
  check('2e. fixture: publish: true でも公開条件(作品3以上など)を満たさなければ公開しない',
    thinRes.published.length === 0 && thinRes.skipped[0].reason === '公開条件を満たさない', JSON.stringify(thinRes));
  const all = getSeriesPublication(ROOT, fixture('all.js', publishOnly(['pokemon', 'kirby', 'ryugagotoku'])));
  check('2f. fixture(3つとも true): 3つとも公開対象・作品の重複なし', all.published.length === 3 && new Set(Object.keys(all.gameLinks)).size === Object.keys(all.gameLinks).length);

  // ---- 3. 通し(作業ツリーのコピーで実行) ----
  let ps = null;
  try { execFileSync('powershell.exe', ['-NoProfile', '-Command', 'exit 0'], { stdio: 'ignore' }); ps = 'powershell.exe'; } catch (e) { /* PowerShell なし */ }
  if (!ps) {
    console.log('  [SKIP] 3. PowerShell が無い環境のため、sitemap・build-public・check-site の通しテストを省略');
  } else {
    const site = path.join(tmp, 'site');
    const skip = new Set(['.git', 'public', 'reports', 'node_modules', '.claude']);
    fs.cpSync(ROOT, site, { recursive: true, filter: (src) => !skip.has(path.basename(src)) || path.dirname(src) !== ROOT });
    const run = (script) => {
      try { execFileSync(ps, ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', path.join(site, script)], { cwd: site, stdio: 'pipe' }); return 0; }
      catch (e) { return e.status || 1; }
    };
    const sitemapSeries = () => [...fs.readFileSync(path.join(site, 'sitemap.xml'), 'utf8').matchAll(/<loc>([^<]*series\.html[^<]*)<\/loc>/g)].map((m) => m[1]);
    const htmlPath = path.join(site, 'series.html');
    const html = fs.readFileSync(htmlPath, 'utf8');

    // 未公開(実データのまま)
    const before = fs.readFileSync(path.join(site, 'sitemap.xml'), 'utf8');
    check('3a. 未公開: generate-sitemap は成功し、sitemap は変わらない(シリーズなし)', run('generate-sitemap.ps1') === 0 && fs.readFileSync(path.join(site, 'sitemap.xml'), 'utf8') === before && sitemapSeries().length === 0);
    check('3b. 未公開: build-public の公開ファイルに series.html・series.js・data-series.js が入らない',
      run('build-public.ps1') === 0 && ['series.html', 'series.js', 'data-series.js'].every((f) => !fs.existsSync(path.join(site, 'public', f))));
    check('3c. 未公開: check-site は成功(series.html の noindex あり)', run('check-site.ps1') === 0);

    // fixture で kirby を公開(元HTMLの noindex は外す = 公開時の手順)
    fs.writeFileSync(path.join(site, 'data-series.js'), publishOnly(['kirby']));
    fs.writeFileSync(htmlPath, html.replace(/<meta name="robots" content="noindex,follow">\r?\n/, ''));
    check('3d. 公開(kirby): sitemap に series.html?series=kirby が1件だけ入る',
      run('generate-sitemap.ps1') === 0 && JSON.stringify(sitemapSeries()) === JSON.stringify(['https://vgame-navi.jp/series.html?series=kirby']), JSON.stringify(sitemapSeries()));
    check('3e. 公開(kirby): build-public の公開ファイルに series.html・series.js・data-series.js が入る',
      run('build-public.ps1') === 0 && ['series.html', 'series.js', 'data-series.js'].every((f) => fs.existsSync(path.join(site, 'public', f))));
    check('3f. 公開(kirby)+ noindex を外した: check-site は成功', run('check-site.ps1') === 0);
    fs.writeFileSync(htmlPath, html);
    check('3g. 公開(kirby)なのに series.html に noindex が残っている: check-site はエラー', run('check-site.ps1') === 1);
    fs.writeFileSync(path.join(site, 'data-series.js'), seriesSrc);
    fs.writeFileSync(htmlPath, html.replace(/<meta name="robots" content="noindex,follow">\r?\n/, ''));
    check('3h. 未公開なのに series.html の noindex が無い: check-site はエラー', run('check-site.ps1') === 1);
  }
} finally {
  fs.rmSync(tmp, { recursive: true, force: true });
}

console.log('\nPASS: ' + pass + '  FAIL: ' + fail);
process.exit(fail ? 1 : 0);
