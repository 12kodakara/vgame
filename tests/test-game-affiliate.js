/**
 * ゲーム詳細の「関連商品」欄(楽天アフィリエイト)の回帰テスト。ブラウザ不要(node tests/test-game-affiliate.js)。
 *
 *   1. URL検証: 楽天の正規アフィリエイトリンク(https・許可ホスト)だけを通す
 *   2. 表示データ: 未登録ゲームは0件、不正URL・空の商品名は除外、件数上限、label は trim
 *   3. 描画: 登録ありで欄を表示、rel / target / textContent(HTMLとして解釈しない)、未登録で非表示
 *   3b. 画像付きカード: 画像URLの検証、カード構造、読み込み失敗時のフォールバック、imageUrl なしはテキストリンク
 *   3c. カードのスタイル: 縦横比維持・切り抜きなし・省略なし・列数
 *   4. game.html: 欄の位置(紹介欄の後・関連ゲームの前)、PR表記、初期 hidden、画像・価格要素なし、読み込み順
 *   5. data-affiliate.js: 登録データが正しい形式(全件が表示条件を満たす)
 *   6. build-public.ps1 / privacy.html への反映
 * 失敗が1件でもあれば終了コード1。
 */
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const ROOT = path.join(__dirname, '..');
const read = (f) => fs.readFileSync(path.join(ROOT, f), 'utf8');
let pass = 0, fail = 0;
function check(name, ok, detail) {
  if (ok) { pass++; console.log('  [PASS] ' + name); } else { fail++; console.log('  [FAIL] ' + name + (detail ? '\n         ' + String(detail).slice(0, 400) : '')); }
}
console.log('=== ゲーム詳細 関連商品(楽天アフィリエイト)回帰テスト ===');

// game.js の描画処理(IIFE)より前の関数定義だけを読み込む
const ctx = { console, URL };
vm.createContext(ctx);
const src = read('game.js');
vm.runInContext(src.slice(0, src.indexOf('(function () {')), ctx, { filename: 'game.js' });
vm.runInContext(read('data-affiliate.js'), ctx, { filename: 'data-affiliate.js' });
const { isRakutenAffiliateUrl, affiliateItemsOf, renderAffiliateSection } = ctx;
const MAX = vm.runInContext('AFFILIATE_MAX_ITEMS', ctx);
const DATA = vm.runInContext('GAME_AFFILIATE', ctx);

// 1. URL検証
const okUrls = [
  'https://hb.afl.rakuten.co.jp/ichiba/1a2b3c4d.5e6f7a8b.1a2b3c4e.9f8e7d6c/?pc=https%3A%2F%2Fitem.rakuten.co.jp%2Fshop%2Fitem%2F',
  'https://hb.afl.rakuten.co.jp/hgc/1a2b3c4d.5e6f7a8b.1a2b3c4e.9f8e7d6c/',
];
const ngUrls = [
  'https://a.r10.to/hAbCdE', 'https://sub.hb.afl.rakuten.co.jp/ichiba/x/', 'https://afl.rakuten.co.jp/ichiba/x/',
  'http://hb.afl.rakuten.co.jp/ichiba/x/', 'javascript:alert(1)', 'https://item.rakuten.co.jp/shop/item/',
  'https://hb.afl.rakuten.co.jp.evil.invalid/ichiba/x/', 'https://evil.invalid/?u=https://hb.afl.rakuten.co.jp/',
  'https://user:pass@hb.afl.rakuten.co.jp/ichiba/x/', 'https://hb.afl.rakuten.co.jp:8443/ichiba/x/',
  '//hb.afl.rakuten.co.jp/ichiba/x/', 'data:text/html,<a>', '', null, undefined, 123,
];
check('正規の楽天アフィリエイトURLを許可', okUrls.every(isRakutenAffiliateUrl), okUrls.filter((u) => !isRakutenAffiliateUrl(u)));
check('正規以外のURLを拒否', ngUrls.every((u) => !isRakutenAffiliateUrl(u)), ngUrls.filter((u) => isRakutenAffiliateUrl(u)));

// 2. 表示データ
const sample = {
  'テストゲーム': [
    { label: '  商品A  ', url: okUrls[0] },
    { label: '', url: okUrls[1] },
    { label: '不正URL', url: 'https://shop.invalid/' },
    null,
    { label: '商品B', url: okUrls[1] },
    { label: '短縮URL(許可対象外)', url: 'https://a.r10.to/hAbCdE' },
  ],
  '多数': Array.from({ length: MAX + 3 }, (_, i) => ({ label: '商品' + i, url: okUrls[1] })),
  '配列以外': { label: 'x', url: okUrls[0] },
};
const a = affiliateItemsOf('テストゲーム', sample);
check('不正URL・空の商品名・null を除外', a.length === 2 && a[0].label === '商品A' && a[1].label === '商品B', JSON.stringify(a));
check('未登録ゲームは0件', affiliateItemsOf('未登録', sample).length === 0 && affiliateItemsOf('toString', sample).length === 0);
check('データ未定義でも0件', affiliateItemsOf('テストゲーム', null).length === 0);
check('配列以外の値は0件', affiliateItemsOf('配列以外', sample).length === 0);
check('件数上限 ' + MAX + ' 件', affiliateItemsOf('多数', sample).length === MAX);

// 3. 描画(最小限の疑似DOM)
function fakeDoc() {
  const mk = (tag) => ({
    tagName: tag, children: [], attrs: {}, hidden: true, textContent: '',
    get firstChild() { return this.children[0] || null; },
    appendChild(c) { this.children.push(c); return c; },
    removeChild(c) { this.children.splice(this.children.indexOf(c), 1); return c; },
    listeners: {},
    addEventListener(type, fn) { this.listeners[type] = fn; },
    set innerHTML(v) { throw new Error('innerHTML は使わない'); },
  });
  const els = { 'game-affiliate-section': mk('section'), 'game-affiliate-list': mk('ul') };
  return { els, getElementById: (id) => els[id] || null, createElement: mk };
}
const evil = [{ label: '<img src=x onerror=alert(1)>', url: okUrls[0] }];
let d = fakeDoc();
const shown = renderAffiliateSection(d, affiliateItemsOf('x', { x: evil }));
const li = d.els['game-affiliate-list'].children[0];
const link = li && li.children[0];
check('登録ありで欄を表示', shown === true && d.els['game-affiliate-section'].hidden === false);
check('rel="sponsored noopener noreferrer" / target=_blank', link && link.rel === 'sponsored noopener noreferrer' && link.target === '_blank', link && link.rel);
check('商品名は textContent で設定(HTMLとして解釈しない)', link && link.tagName === 'a' && link.textContent === evil[0].label && link.children.length === 0);
check('href は検証済みURL', link && link.href === okUrls[0]);
d = fakeDoc();
check('未登録で欄を非表示', renderAffiliateSection(d, affiliateItemsOf('未登録', sample)) === false && d.els['game-affiliate-section'].hidden === true && d.els['game-affiliate-list'].children.length === 0);
check('要素が無いページでも例外なし', renderAffiliateSection({ getElementById: () => null }, a) === false);

// 3b. 画像付きカード
const IMAGE_HOSTS = vm.runInContext('RAKUTEN_AFFILIATE_IMAGE_HOSTS', ctx);
check('画像の許可ホストは公式画面で確認した hbb.afl.rakuten.co.jp のみ', IMAGE_HOSTS.size === 1 && IMAGE_HOSTS.has('hbb.afl.rakuten.co.jp'), [...IMAGE_HOSTS]);
const officialImg = 'https://hbb.afl.rakuten.co.jp/hgb/59cae608.450475ce.59cae609.4c700fba/?me_id=1&item_id=2&s=400x400&t=pict';
check('hbb.afl.rakuten.co.jp の https 画像URLを許可', vm.runInContext('isRakutenAffiliateImageUrl', ctx)(officialImg));
const notImgHosts = [okUrls[1], 'http://hbb.afl.rakuten.co.jp/hgb/x/', 'https://x.hbb.afl.rakuten.co.jp/hgb/x/', 'https://hbb.afl.rakuten.co.jp.evil.invalid/hgb/x/',
  'https://thumbnail.image.rakuten.co.jp/@0_mall/book/a.jpg', 'https://u:p@hbb.afl.rakuten.co.jp/hgb/x/', 'https://hbb.afl.rakuten.co.jp:8443/hgb/x/'];
const notImgResults = notImgHosts.map((u) => affiliateItemsOf('x', { x: [{ label: '商品', url: okUrls[0], imageUrl: u }] }));
check('許可外の画像URL(リンク用ホスト・http・サブドメイン・偽ホスト・直リンク・ポート等)は無視してテキストリンク',
  notImgResults.every((r) => r.length === 1 && !('imageUrl' in r[0])), notImgHosts.filter((u, i) => 'imageUrl' in notImgResults[i][0]));
// 以下はテスト専用の架空ホストを一時的に許可して、カード表示の仕組みだけを確認する
const TEST_IMG_HOST = 'img.test.invalid';
const testImg = 'https://' + TEST_IMG_HOST + '/a.jpg';
IMAGE_HOSTS.add(TEST_IMG_HOST);
const badImgs = ['http://' + TEST_IMG_HOST + '/a.jpg', 'javascript:alert(1)', 'https://' + TEST_IMG_HOST + '.evil.invalid/a.jpg',
  'https://u:p@' + TEST_IMG_HOST + '/a.jpg', 'https://' + TEST_IMG_HOST + ':8443/a.jpg', 'data:image/png;base64,AAAA', '', 123];
const okImg = affiliateItemsOf('x', { x: [{ label: 'カード商品', url: okUrls[0], imageUrl: testImg }] });
const badResults = badImgs.map((u) => affiliateItemsOf('x', { x: [{ label: '画像不正', url: okUrls[1], imageUrl: u }] }));
check('許可ホストの https 画像URLだけ残す', okImg[0].imageUrl === testImg && badResults.every((r) => r.length === 1 && !('imageUrl' in r[0])),
  JSON.stringify(badImgs.filter((u, i) => badResults[i].length !== 1 || 'imageUrl' in badResults[i][0])));
check('不正な画像URLでも商品自体はテキストリンクで表示', badResults.every((r) => r.length === 1 && r[0].url === okUrls[1]));
d = fakeDoc();
renderAffiliateSection(d, [{ label: '<b>カード</b>', url: okUrls[0], imageUrl: testImg }, { label: 'テキスト', url: okUrls[1] }]);
const [cardLi, textLi] = d.els['game-affiliate-list'].children;
const cardA = cardLi.children[0];
const [imgBox, nameEl] = cardA.children;
const imgEl = imgBox && imgBox.children[0];
check('カード: li.affiliate-card > a(画像枠 + 商品名を1つのリンクで包む)', cardLi.className === 'affiliate-card' && cardA.tagName === 'a' && cardA.className === 'affiliate-card-link' && cardLi.children.length === 1);
check('カード: href / target / rel を維持', cardA.href === okUrls[0] && cardA.target === '_blank' && cardA.rel === 'sponsored noopener noreferrer');
check('カード: 画像は img 要素の src プロパティで設定・alt 空・遅延読み込み', imgEl && imgEl.tagName === 'img' && imgEl.src === testImg && imgEl.alt === '' && imgEl.loading === 'lazy');
check('カード: 商品名は画像の下に textContent で設定', imgBox.className === 'affiliate-card-image' && nameEl.className === 'affiliate-card-name' && nameEl.textContent === '<b>カード</b>' && nameEl.children.length === 0);
imgBox.hidden = false;
imgEl.listeners.error && imgEl.listeners.error();
check('画像の読み込み失敗時は画像枠を隠し、商品名のリンクは残る', imgBox.hidden === true && nameEl.textContent && cardA.href === okUrls[0]);
check('imageUrl なしは従来のテキストリンク', !textLi.className && textLi.children[0].textContent === 'テキスト' && textLi.children[0].children.length === 0 && textLi.children[0].rel === 'sponsored noopener noreferrer');
IMAGE_HOSTS.delete(TEST_IMG_HOST);

// 3c. カードのスタイル(縦横比維持・切り抜きなし・省略なし・列数)
const css = read('style.css');
const affCss = css.slice(css.indexOf('/* ---------- 関連商品'));
check('画像は object-fit: contain(切り抜かない)', /\.affiliate-card-image img \{[^}]*object-fit: contain/.test(affCss) && !/object-fit: cover/.test(affCss));
check('商品名を省略しない(ellipsis・line-clamp なし)', !/text-overflow|line-clamp/.test(affCss));
check('PC 3列 / 720px以下 1列', /\.affiliate-list \{[^}]*repeat\(3, minmax\(0, 1fr\)\)/.test(affCss) && /@media \(max-width: 720px\) \{\s*\.affiliate-list \{\s*grid-template-columns: 1fr;/.test(affCss));
check('hidden の画像枠は非表示', /\.affiliate-card-image\[hidden\] \{\s*display: none;/.test(affCss));
const affSrc = src.slice(src.indexOf('// ---------- 関連商品'), src.indexOf('const GAME_DESC_MAX_STREAMERS'));
check('関連商品の処理で innerHTML / insertAdjacentHTML を使わない', !/innerHTML|insertAdjacentHTML|outerHTML/.test(affSrc));

// 4. game.html
const html = read('game.html');
const iAff = html.indexOf('id="game-affiliate-section"');
const iEdit = html.indexOf('id="game-editorial-section"');
const iRel = html.indexOf('id="game-related-section"');
check('紹介欄の後・関連ゲームの前に配置', iEdit > 0 && iAff > iEdit && iRel > iAff);
const secHtml = html.slice(html.lastIndexOf('<section', iAff), html.indexOf('</section>', iAff));
check('初期状態は hidden', /<section[^>]*id="game-affiliate-section"[^>]*\bhidden\b/.test(html));
check('「PR」表記', /<span class="pr-label">PR<\/span>/.test(secHtml));
check('「楽天アフィリエイトを利用しています」表記', secHtml.includes('楽天アフィリエイトを利用しています'));
check('商品画像・価格の要素なし', !/<img|price|価格:/i.test(secHtml.replace('価格・在庫はリンク先でご確認ください', '')));
const sAff = html.indexOf('<script src="data-affiliate.js">'), sGame = html.indexOf('<script src="game.js">');
check('data-affiliate.js を game.js より前に読み込み', sAff > 0 && sGame > sAff);
check('game.js は IIFE 内で関連商品を描画', /renderAffiliateSection\(document, affiliateItemsOf\(game,/.test(src));

// 5. 登録データの形式
const keys = Object.keys(DATA);
const badEntries = keys.filter((k) => !Array.isArray(DATA[k]) || DATA[k].length === 0 || affiliateItemsOf(k, DATA).length !== DATA[k].length);
check('data-affiliate.js の登録データが全件表示条件を満たす(現在 ' + keys.length + ' ゲーム)', badEntries.length === 0, badEntries);
const droppedImages = keys.filter((k) => DATA[k].some((it, i) => it.imageUrl !== undefined && affiliateItemsOf(k, DATA)[i].imageUrl !== it.imageUrl));
check('登録済みの imageUrl はすべて許可ホストで、カード表示される', droppedImages.length === 0, droppedImages);

// 6. 公開ビルド・プライバシーポリシー
check('build-public.ps1 の公開対象に data-affiliate.js', /"data-affiliate\.js"/.test(read('build-public.ps1')));
const privacy = read('privacy.html');
check('privacy.html に楽天アフィリエイト利用を明記', privacy.includes('「楽天アフィリエイト」を利用しています') && !privacy.includes('当サイトでは今後、Amazon・楽天市場等'));

console.log(`\n結果: ${pass} 件成功 / ${fail} 件失敗`);
process.exit(fail ? 1 : 0);
