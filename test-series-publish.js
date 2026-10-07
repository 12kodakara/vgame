/**
 * ゲームシリーズページの公開基盤(series-publish.js と、それを使う sitemap・build-public・check-site)の回帰テスト。
 * 本番の data-series.js は書き換えない。公開状態の切り替えは一時フォルダの fixture だけで試す。
 *
 *   1. 実データ: data-series.js の publish の値から期待値を計算し、公開判定・sitemap・series.html の noindex・
 *      内部リンク対象がそれと一致する(どのシリーズを公開していても、していなくても成り立つ)
 *   2. fixture(すべて未公開の定義を土台に、指定したシリーズだけ publish: true にする):
 *      publish: true のシリーズだけが公開対象になる。公開条件を満たさなければ true でも公開しない。
 *      内部リンク対象は本編の作品と hubGame だけ(relatedGames は入れない)
 *   3. 通し(PowerShell がある環境のみ。作業ツリーを一時フォルダにコピーし、未公開 / pokemon だけ公開 / 不正な公開 を再現):
 *      generate-sitemap / build-public / check-site が公開シリーズだけを扱い、不正な状態はエラーにする
 * 失敗が1件でもあれば終了コード1。
 */
'use strict';
const fs = require('fs');
const os = require('os');
const path = require('path');
const vm = require('vm');
const { execFileSync } = require('child_process');
const { getSeriesPublication, seriesUrlPath } = require('./series-publish.js');

const ROOT = __dirname;
let pass = 0, fail = 0;
function check(name, ok, detail) {
  if (ok) { pass++; console.log('  [PASS] ' + name); } else { fail++; console.log('  [FAIL] ' + name + (detail ? '\n         ' + String(detail).slice(0, 400) : '')); }
}
console.log('=== ゲームシリーズページ 公開基盤テスト ===');

const SITE = 'https://vgame-navi.jp';
const NOINDEX = '<meta name="robots" content="noindex,follow">';
const PUBLISH_TRUE = /^(\s*)publish(\s*:\s*)true/gm;
const seriesSrc = fs.readFileSync(path.join(ROOT, 'data-series.js'), 'utf8');
const seriesHtml = fs.readFileSync(path.join(ROOT, 'series.html'), 'utf8');
/** すべてのシリーズを未公開にした定義(実データの公開状態に左右されない fixture の土台) */
const baseSrc = seriesSrc.replace(PUBLISH_TRUE, '$1publish$2false');
/** 未公開の土台から、指定したシリーズだけ publish: true にした定義 */
const publishOnly = (ids) => ids.reduce((s, id) => s.replace(new RegExp('(\\n  ' + id + ': \\{[\\s\\S]*?publish: )false'), '$1true'), baseSrc);
/** series.html の元HTMLの noindex あり / なし(実データの状態に左右されない) */
const htmlNoindex = seriesHtml.includes(NOINDEX) ? seriesHtml : seriesHtml.replace(/(<meta name="viewport"[^>]*>)(\r?\n)/, '$1$2' + NOINDEX + '$2');
const htmlIndex = htmlNoindex.replace(/<meta name="robots" content="noindex,follow">\r?\n/, '');
const loadSeries = (src) => { const c = {}; vm.createContext(c); vm.runInContext(src, c); return JSON.parse(JSON.stringify(vm.runInContext('SERIES_PAGES', c))); };
const SERIES = loadSeries(seriesSrc);
const linkTargetsOf = (ids, defs) => ids.flatMap((id) => defs[id].games.concat(defs[id].hubGame ? [defs[id].hubGame] : [])).sort();
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'vgame-series-publish-'));
const fixture = (name, text) => { const f = path.join(tmp, name); fs.writeFileSync(f, text); return f; };

try {
  // ---- 1. 実データ(publish の値から期待値を計算して照合) ----
  const real = getSeriesPublication(ROOT);
  const flagged = Object.keys(SERIES).filter((id) => SERIES[id].publish === true);
  check('1a. 実データ: 公開対象 = publish: true のシリーズ(' + (flagged.join(', ') || 'なし') + ')。publish: false は「publish が true でない」で公開しない',
    JSON.stringify(real.published) === JSON.stringify(flagged) &&
    real.skipped.every((s) => s.code === 'not-published' && SERIES[s.id].publish !== true) && real.skipped.length === Object.keys(SERIES).length - flagged.length,
    JSON.stringify(real));
  check('1b. 実データ: publish: true なのに公開条件を満たさないシリーズが無い(ゲーム詳細の導線が noindex のページを指さない)',
    !real.skipped.some((s) => s.code === 'below-threshold'), JSON.stringify(real.skipped));
  // 行頭のプロパティだけを見る(ファイル先頭の説明コメントに「publish : true のときだけ…」とあるため)
  check('1b2. publish の判定用の検索はコメントではなくプロパティに当たる(土台は true 0件、fixture の true は検出する)',
    !/^\s*publish\s*:\s*true/m.test(baseSrc) && /^\s*publish\s*:\s*true/m.test(publishOnly(['kirby'])));
  const realSitemap = fs.readFileSync(path.join(ROOT, 'sitemap.xml'), 'utf8');
  const sitemapSeriesOf = (xml) => [...xml.matchAll(/<loc>([^<]*series\.html[^<]*)<\/loc>/g)].map((m) => m[1]).sort();
  check('1c. 実データ: sitemap.xml のシリーズURL = 公開シリーズのURL(' + real.urls.length + '件。未公開シリーズは載らない)',
    JSON.stringify(sitemapSeriesOf(realSitemap)) === JSON.stringify(real.urls.map((u) => SITE + u).sort()), JSON.stringify(sitemapSeriesOf(realSitemap)));
  check('1d. 実データ: 内部リンク対象 = 公開シリーズの本編の作品と hubGame(関連作品・未公開シリーズの作品は入らない)',
    JSON.stringify(Object.keys(real.gameLinks).sort()) === JSON.stringify(linkTargetsOf(real.published, SERIES)) &&
    Object.keys(SERIES).every((id) => (SERIES[id].relatedGames || []).every((g) => !(g in real.gameLinks))));
  check('1e. 実データ: series.html の元HTMLの noindex は「公開シリーズが無いときだけ」ある(' + (real.published.length ? '公開あり → noindex なし' : '公開なし → noindex あり') + ')',
    seriesHtml.includes(NOINDEX) === (real.published.length === 0));

  // ---- 2. fixture(すべて未公開の土台から作る) ----
  const none = getSeriesPublication(ROOT, fixture('none.js', baseSrc));
  check('2a. fixture(すべて未公開): 公開対象0件・内部リンク対象0件', none.published.length === 0 && Object.keys(none.gameLinks).length === 0 && none.skipped.every((s) => s.code === 'not-published'));
  const pk = getSeriesPublication(ROOT, fixture('pokemon.js', publishOnly(['pokemon'])));
  check('2b. fixture(pokemon だけ publish: true): 公開対象は pokemon だけ・URL は series.html?series=pokemon(canonical と同じ形)',
    JSON.stringify(pk.published) === '["pokemon"]' && JSON.stringify(pk.urls) === JSON.stringify(['/series.html?series=pokemon']) && seriesUrlPath('pokemon') === '/series.html?series=pokemon', JSON.stringify(pk.published));
  check('2c. fixture(pokemon だけ): 内部リンク対象は pokemon の本編の作品と hubGame だけ(kirby・ryugagotoku の作品は入らない)',
    JSON.stringify(Object.keys(pk.gameLinks).sort()) === JSON.stringify(linkTargetsOf(['pokemon'], SERIES)) && Object.values(pk.gameLinks).every((v) => v === 'pokemon') &&
    ['kirby', 'ryugagotoku'].every((id) => SERIES[id].games.every((g) => !(g in pk.gameLinks))));
  const kirby = getSeriesPublication(ROOT, fixture('kirby.js', publishOnly(['kirby'])));
  check('2c2. fixture(kirby だけ): 同じ仕組みで kirby だけが公開対象になる(ポケモン専用ではない)',
    JSON.stringify(kirby.published) === '["kirby"]' && JSON.stringify(Object.keys(kirby.gameLinks).sort()) === JSON.stringify(linkTargetsOf(['kirby'], SERIES)));
  const ryu = getSeriesPublication(ROOT, fixture('ryu.js', publishOnly(['ryugagotoku'])));
  check('2d. fixture(ryugagotoku): 関連作品(JUDGE)は内部リンク対象に入れない(別シリーズの親にしない)',
    ryu.published[0] === 'ryugagotoku' && (SERIES.ryugagotoku.relatedGames || []).every((g) => !(g in ryu.gameLinks)) && SERIES.ryugagotoku.games.every((g) => ryu.gameLinks[g] === 'ryugagotoku'));
  const thin = fixture('thin.js', 'const SERIES_PAGES = { thin: { name: "テスト用シリーズ", publish: true, hubGame: "", games: ["龍が如く3"] } };');
  const thinRes = getSeriesPublication(ROOT, thin);
  check('2e. fixture: publish: true でも公開条件(作品3以上など)を満たさなければ公開しない(code: below-threshold)',
    thinRes.published.length === 0 && thinRes.skipped[0].code === 'below-threshold', JSON.stringify(thinRes));
  const all = getSeriesPublication(ROOT, fixture('all.js', publishOnly(['pokemon', 'kirby', 'ryugagotoku'])));
  check('2f. fixture(3つとも true): 3つとも公開対象・作品の重複なし', all.published.length === 3 && new Set(Object.keys(all.gameLinks)).size === Object.keys(all.gameLinks).length);

  // ---- 3. 通し(作業ツリーのコピーで、未公開 / pokemon だけ公開 / 不正な公開 を再現) ----
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
    const setState = (dataSrc, html) => { fs.writeFileSync(path.join(site, 'data-series.js'), dataSrc); fs.writeFileSync(path.join(site, 'series.html'), html); };
    const sitemapXml = () => fs.readFileSync(path.join(site, 'sitemap.xml'), 'utf8');
    const nonSeriesUrls = (xml) => [...xml.matchAll(/<loc>([^<]*)<\/loc>/g)].map((m) => m[1]).filter((u) => !/series\.html/.test(u));
    const inPublic = (f) => fs.existsSync(path.join(site, 'public', f));
    const publicLinksToSeries = () => fs.readdirSync(path.join(site, 'public')).filter((f) => /\.html$/.test(f)).filter((f) => /href="[^"]*series\.html/.test(fs.readFileSync(path.join(site, 'public', f), 'utf8')));

    // A. すべて未公開(元HTMLに noindex)
    setState(baseSrc, htmlNoindex);
    check('3a. 未公開: generate-sitemap は成功し、シリーズURLは0件・それ以外のURLは実データの sitemap と同じ',
      run('generate-sitemap.ps1') === 0 && sitemapSeriesOf(sitemapXml()).length === 0 && JSON.stringify(nonSeriesUrls(sitemapXml())) === JSON.stringify(nonSeriesUrls(realSitemap)));
    // data-series.js はゲーム詳細が公開シリーズへの導線に使うため常に含める(シリーズページ本体は含めない)
    check('3b. 未公開: build-public の公開ファイルに series.html・series.js が入らない(data-series.js はゲーム詳細用に入る)',
      run('build-public.ps1') === 0 && !inPublic('series.html') && !inPublic('series.js') && inPublic('data-series.js'));
    check('3b2. 未公開: build-public 後の公開物(HTML)に、series.html へのリンクを書いたページが無い', publicLinksToSeries().length === 0, publicLinksToSeries().join(','));
    check('3c. 未公開: check-site は成功(series.html の noindex あり)', run('check-site.ps1') === 0);

    // B/C. pokemon だけ公開(元HTMLの noindex は外す = 公開時の手順)。kirby・ryugagotoku は未公開のまま
    setState(publishOnly(['pokemon']), htmlIndex);
    check('3d. 公開(pokemon だけ): sitemap のシリーズURLは series.html?series=pokemon の1件だけ(kirby・ryugagotoku は無い)・ほかのURLは変わらない',
      run('generate-sitemap.ps1') === 0 && JSON.stringify(sitemapSeriesOf(sitemapXml())) === JSON.stringify([SITE + '/series.html?series=pokemon']) &&
      JSON.stringify(nonSeriesUrls(sitemapXml())) === JSON.stringify(nonSeriesUrls(realSitemap)), JSON.stringify(sitemapSeriesOf(sitemapXml())));
    check('3e. 公開(pokemon だけ): build-public の公開ファイルに series.html・series.js・data-series.js が入り、公開する series.html に noindex が無い',
      run('build-public.ps1') === 0 && ['series.html', 'series.js', 'data-series.js'].every(inPublic) && !fs.readFileSync(path.join(site, 'public', 'series.html'), 'utf8').includes(NOINDEX));
    check('3e2. 公開(pokemon だけ): 公開する data-series.js でも kirby・ryugagotoku は publish: false のまま',
      (() => { const d = loadSeries(fs.readFileSync(path.join(site, 'public', 'data-series.js'), 'utf8')); return d.pokemon.publish === true && d.kirby.publish === false && d.ryugagotoku.publish === false; })());
    check('3f. 公開(pokemon だけ)+ noindex を外した: check-site は成功', run('check-site.ps1') === 0);

    // D. 不正な状態は check-site がエラーにする(安全装置)
    setState(publishOnly(['pokemon']), htmlNoindex);
    check('3g. 公開(pokemon)なのに series.html に noindex が残っている: check-site はエラー', run('check-site.ps1') === 1);
    setState(baseSrc, htmlIndex);
    check('3h. 未公開なのに series.html の noindex が無い: check-site はエラー', run('check-site.ps1') === 1);
    // publish: true なのに公開条件を満たさないシリーズ(ゲーム詳細が noindex のページへ導線を出してしまう)はエラー
    setState(baseSrc.replace(/\n};\s*$/, '\n  thintest: { name: "テスト用シリーズ", publish: true, hubGame: "", games: ["ポケモンスナップ"] },\n};\n'), htmlNoindex);
    check('3i. publish: true なのに公開条件を満たさないシリーズがある: check-site はエラー', run('check-site.ps1') === 1);
    setState(baseSrc, htmlNoindex);
    check('3j. 未公開の正しい状態に戻すと check-site は成功', run('check-site.ps1') === 0);
  }
} finally {
  fs.rmSync(tmp, { recursive: true, force: true });
}

console.log('\nPASS: ' + pass + '  FAIL: ' + fail);
process.exit(fail ? 1 : 0);
