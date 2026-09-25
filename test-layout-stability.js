/**
 * レイアウトシフト(CLS)対策の回帰テスト。ブラウザ不要(node test-layout-stability.js)。
 *
 *   1. スクロールバーの幅を常に確保する(PC で一覧描画後にスクロールバーが出てページ全体が横にずれるのを防ぐ)
 *   2. JS が後から中身を入れる要素(件数表示・VTuber見出し・掲載件数・人気コンテンツ・人気のゲーム)の場所を
 *      描画前から確保し、確保量が実際の表示(件数・1行の高さ)と一致する
 *   3. 一覧の描画前はページ送りを出さず、本文を画面の高さ以上にしてフッターを画面外に置く
 *      (一覧が入れば元に戻る・見つからないページは対象外で、描画後に空白を残さない)
 *   4. 最初から表示にした要素は、情報が無いときに JS が隠す
 *   5. 変えていないもの: AdSense コード・広告枠・主要な DOM 構造・SEO タグ
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
console.log('=== レイアウトシフト(CLS)対策 回帰テスト ===');

const css = read('style.css').replace(/\r\n/g, '\n');
const noComments = css.replace(/\/\*[\s\S]*?\*\//g, '');
/** セレクタ(完全一致)のルール本体を返す。 */
function rule(selector) {
  const esc = selector.replace(/[.*+?^${}()|[\]\\]/g, '\\$&').replace(/\s+/g, '\\s*');
  const m = new RegExp('(?:^|[}\\n])\\s*' + esc + '\\s*\\{([^}]*)\\}').exec(noComments);
  return m ? m[1] : null;
}
const has = (selector, decl) => { const body = rule(selector); return !!body && body.replace(/\s+/g, ' ').includes(decl); };

// ---- 1. スクロールバー ----
check('1. html { scrollbar-gutter: stable }', has('html', 'scrollbar-gutter: stable'));

// ---- 2. 描画前の場所の確保 ----
const LINE = 1.7; // html, body の line-height
check('2a. body の line-height が確保量の前提(1.7)のまま', has('html, body', 'line-height: 1.7'));
check('2b. #result-count は1行分(0.78rem × 1.7)を確保し、font-size は .result-count の 0.78rem のまま',
  has('#result-count', 'min-height: calc(0.78rem * 1.7)') && has('.result-count', 'font-size: 0.78rem'));
check('2c. .page-meta は1行分(0.74rem × 1.7)を確保', has('.page-meta', 'font-size: 0.74rem') && has('.page-meta', 'min-height: calc(0.74rem * 1.7)'));
check('2d. .hero-stats は空の間だけ1行分、480px 以下は2行分を確保(文字が入れば外れる)', /\.hero-stats\{margin:14px 0 0;font-size:\.82rem;color:var\(--text-dim\)\}/.test(noComments)
  && /\.hero-stats:empty\{min-height:calc\(\.82rem \* 1\.7\)\}/.test(noComments)
  && /@media \(max-width:480px\)\{\.hero-stats:empty\{min-height:calc\(\.82rem \* 1\.7 \* 2\)\}\}/.test(noComments));
// 人気コンテンツ: 5件 × (1行 + 上下余白 3px×2 + 区切り線1px) − 先頭の区切り線 + ul の上下余白 4px+8px
const li = rule('.sidebar-popular-list li') || '';
check('2e. 人気コンテンツの確保量の前提(ul 余白 4px/8px・li 余白 3px・区切り線 1px・先頭は線なし)',
  has('.sidebar-popular-list', 'padding: 4px 0 8px') && has('.sidebar-popular-list', 'font-size: 0.78rem') && /padding: 3px 12px/.test(li) && /border-top: 1px solid/.test(li) && has('.sidebar-popular-list li:first-child', 'border-top: none'));
check('2f. 人気コンテンツは空の間だけ5件分を確保', has('.sidebar-popular-list:empty', 'min-height: calc(12px + 5 * (0.78rem * 1.7 + 7px) - 1px)'));
const common = read('common.js');
check('2g. 人気コンテンツは JS が常に上位5件を描画する(確保量の前提)', /\.slice\(0, 5\);[\s\S]{0,200}list\.innerHTML = "";/.test(common) && /function initSidebarPopular\(\)/.test(common));
check('2h. 「人気のゲーム」は空の間だけ 356px(5件)を確保', /#discover-popular-games:empty\{min-height:356px\}/.test(noComments));
const summaryCtx = {}; vm.createContext(summaryCtx); vm.runInContext(read('data-home.js'), summaryCtx);
check('2i. data-home.js の人気のゲームは5件(確保量の前提)', vm.runInContext('HOME_SUMMARY.topGames.length', summaryCtx) === 5);

// ---- 3. 一覧の描画前 ----
check('3a. 一覧(#grid)が空の間はページ送りを出さない', has('main:has(#grid:empty) #pagination', 'display: none'));
check('3b. 一覧(#grid / #category-list)が空の間だけ本文を画面の高さ以上にする(見つからないページは除く)',
  has('body:not(.is-not-found-page) .wiki-body:has(#grid:empty),\nbody:not(.is-not-found-page) .wiki-body:has(#category-list:empty)', 'min-height: 100vh'));
check('3c. .wiki-body 自体には無条件の min-height を付けない(描画後に空白を残さない)', !/min-height/.test(rule('.wiki-body') || ''));
check('3d. フッターを隠すルールが無い', !/\.wiki-footer[^{]*\{[^}]*(display:\s*none|visibility:\s*hidden)/.test(noComments));
check('3e. 見つからないページでは本文の高さの確保を外す(renderNotFoundPage が body に目印を付ける)', /function renderNotFoundPage\(opts\) \{[\s\S]{0,200}document\.body\.classList\.add\("is-not-found-page"\)/.test(common));
for (const page of ['ranking.html', 'new.html', 'playlists.html', 'game.html', 'streamer.html']) {
  const html = read(page);
  const main = (/<main[\s\S]*<\/main>/.exec(html) || [''])[0];
  check('3f. ' + page + ': <main> 内に空の #grid・#pagination・#result-count がある(対策の前提)',
    /id="grid"><\/(tbody|div)>/.test(main) && main.includes('id="pagination"') && /<p class="result-count" id="result-count"><\/p>/.test(main));
}
for (const page of ['games.html', 'streamers.html']) check('3g. ' + page + ': <main> 内に空の #category-list がある', /<div id="category-list"><\/div>/.test(read(page)));

// ---- 4. 最初から表示にした要素 ----
const streamerHtml = read('streamer.html'), streamerJs = read('streamer.js');
check('4a. VTuber詳細: アイコン・所属・SNSリンク欄・YouTubeリンクは最初から表示(hidden なし)',
  /<img id="streamer-icon" class="streamer-icon" alt="">/.test(streamerHtml) && /<p class="page-meta" id="page-meta"><\/p>/.test(streamerHtml)
  && /<div class="social-links" id="social-links">/.test(streamerHtml) && /<a id="social-youtube"(?![^>]*hidden)[^>]*>/.test(streamerHtml));
check('4b. VTuber詳細: X のリンクは従来どおり hidden(持っていないVTuberがいるため)', /<a id="social-x"[^>]* hidden /.test(streamerHtml));
check('4c. VTuber詳細: 情報が無いときはアイコン・所属・YouTube・X・SNS欄を隠す(見つからないページの判定より前)',
  /iconEl\.hidden = !\(roster && roster\.icon\);[\s\S]*metaEl\.hidden = !\(roster && roster\.group\);[\s\S]*youtubeLinkEl\.hidden = !\(roster && roster\.youtube\);[\s\S]*xLinkEl\.hidden = !\(roster && roster\.x\);[\s\S]*socialLinksEl\.hidden = !\(roster && \(roster\.youtube \|\| roster\.x\)\);[\s\S]*if \(!roster && !hasAnyPlay\) \{\s*renderNotFoundPage/.test(streamerJs));
check('4d. VTuber詳細: アイコン読み込み失敗時は従来どおり隠す・alt は「名前 のアイコン」',
  /iconEl\.addEventListener\("error", \(\) => \{ iconEl\.hidden = true; \}, \{ once: true \}\)/.test(streamerJs) && /iconEl\.alt = streamer \+ " のアイコン"/.test(streamerJs));
const coreCtx = {}; vm.createContext(coreCtx); vm.runInContext(read('data-core.js'), coreCtx);
const S = vm.runInContext('STREAMERS', coreCtx);
check('4e. 全VTuberがアイコン・所属・YouTube を持つ(最初から表示にする前提)', S.every((s) => s.icon && s.group && s.youtube), S.filter((s) => !(s.icon && s.group && s.youtube)).map((s) => s.name).join(', '));
check('4f. トップ: 掲載件数は最初から表示し、件数が無いときだけ隠す',
  /<p class="hero-stats" id="hero-stats"><\/p>/.test(read('index.html')) && /heroStats\.hidden = false;\s*\} else if \(heroStats\) \{\s*heroStats\.hidden = true;/.test(read('home.js')));

// ---- 5. 変えていないもの ----
const ADS = '<script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-7076920165915227"';
const pages = fs.readdirSync(ROOT).filter((f) => f.endsWith('.html'));
const adsPages = pages.filter((f) => read(f).includes('adsbygoogle'));
check('5a. AdSense の読み込みタグは各ページ1つで、クライアントIDは従来どおり', adsPages.length > 0 && adsPages.every((f) => read(f).split(ADS).length === 2), adsPages.filter((f) => read(f).split(ADS).length !== 2).join(', '));
check('5b. 手動の広告枠(<ins class="adsbygoogle">)を追加していない', pages.every((f) => !/<ins class="adsbygoogle"/.test(read(f))));
check('5c. 広告関連のセレクタ(adsbygoogle・google-auto-placed・aswift)に CSS を当てていない', !/adsbygoogle|google-auto-placed|aswift/.test(noComments));
for (const page of ['index.html', 'game.html', 'streamer.html', 'games.html', 'streamers.html', 'ranking.html', 'new.html']) {
  const html = read(page);
  check('5d. ' + page + ': header・サイドバー・main・footer の構造と canonical が従来どおり',
    /<header class="wiki-banner">/.test(html) && /<aside class="wiki-sidebar" id="wiki-sidebar">/.test(html) && /<main class="wiki-content">/.test(html)
    && /<footer class="wiki-footer">[\s\S]*privacy\.html[\s\S]*<\/footer>/.test(html) && /<link rel="canonical" href="https:\/\/vgame-navi\.jp\//.test(html));
}

console.log('');
console.log('PASS: ' + pass + '  FAIL: ' + fail);
process.exit(fail ? 1 : 0);
