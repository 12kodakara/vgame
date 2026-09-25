/**
 * 画像読み込み最適化の回帰テスト。ブラウザ不要(node test-image-loading.js)。
 *
 *   1. VTuberアイコン(yt3)の表示サイズ向けURL(sizedIconSources)が、全アイコンで正しい形になる
 *      (1x/2x/3x の srcset・元の解像度を超えない・サイズ指定以外の部分は元URLのまま・対象外URLはそのまま)
 *   2. 実際の描画関数(createStreamerCard / createPlaylistThumbnail)が作る <img> の
 *      src / srcset / alt / loading / decoding / width・height / 失敗時の切り替えが正しい
 *   3. 各表示箇所の cssPx 指定が style.css の実際の表示サイズと一致する
 *   4. 再生リストのサムネイル・og:image・リンクは変えていない
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
console.log('=== 画像読み込み最適化 回帰テスト ===');

// ---- 最小限の DOM(描画関数が作る要素と属性を記録する) ----
class FakeElement {
  constructor(tag) { this.tagName = String(tag).toUpperCase(); this.children = []; this.attrs = {}; this.listeners = {}; this.className = ''; this.parent = null; }
  appendChild(c) { c.parent = this; this.children.push(c); return c; }
  prepend(c) { c.parent = this; this.children.unshift(c); }
  remove() { if (this.parent) this.parent.children = this.parent.children.filter((x) => x !== this); this.parent = null; }
  addEventListener(type, fn, opts) { (this.listeners[type] = this.listeners[type] || []).push({ fn, once: !!(opts && opts.once) }); }
  fire(type) { const ls = this.listeners[type] || []; this.listeners[type] = ls.filter((l) => !l.once); ls.forEach((l) => l.fn()); }
  setAttribute(k, v) { this.attrs[k] = String(v); }
  getAttribute(k) { return k in this.attrs ? this.attrs[k] : null; }
  set innerHTML(v) { if (v === '') this.children = []; }
  get innerHTML() { return ''; }
  find(pred) { for (const c of this.children) { if (pred(c)) return c; const r = c.find(pred); if (r) return r; } return null; }
}
function stubElement() { return new Proxy(function () {}, { get: (t, k) => (k === 'length' ? 0 : stubElement()), apply: () => stubElement() }); }
const storage = { getItem: () => null, setItem: () => {}, removeItem: () => {} };
const ctx = {
  console, localStorage: storage,
  window: { __LIST_DATA_GENERATOR__: true, addEventListener() {}, localStorage: storage, location: { href: '' } },
  document: { addEventListener() {}, querySelector: () => null, querySelectorAll: () => [], getElementById: () => null, createElement: () => stubElement(), body: null, head: stubElement() },
};
vm.createContext(ctx);
for (const f of ['data-core.js', 'data-playlists.js', 'common.js']) vm.runInContext(read(f), ctx, { filename: f });
ctx.document.createElement = (tag) => new FakeElement(tag);
const run = (expr) => vm.runInContext(expr, ctx);

const STREAMERS = run('STREAMERS');
const withIcon = STREAMERS.filter((s) => s.icon);

// ---- 1. URL 変換 ----
const sized = (url, px) => JSON.parse(JSON.stringify(run('sizedIconSources(' + JSON.stringify(url) + ', ' + px + ')')));
const YT3 = /^(https:\/\/yt3\.(?:ggpht|googleusercontent)\.com\/[^=?#]+)=s(\d+)((?:-[a-z0-9]+)*)$/i;
check('1a. 全アイコン(' + withIcon.length + '件)が yt3 のサイズ指定付きURLである(変換の対象)', withIcon.length > 0 && withIcon.every((s) => YT3.test(s.icon)),
  withIcon.filter((s) => !YT3.test(s.icon)).map((s) => s.name + ' ' + s.icon).slice(0, 3).join('\n'));
const urlProblems = [];
for (const s of withIcon) {
  const [, base, orig, suffix] = YT3.exec(s.icon);
  for (const px of [36, 64, 72, 120]) {
    const r = sized(s.icon, px);
    const want = [1, 2, 3].map((d) => base + '=s' + Math.min(Number(orig), Math.ceil(px * d)) + suffix);
    if (r.srcset !== want[0] + ' 1x, ' + want[1] + ' 2x, ' + want[2] + ' 3x' || r.src !== want[1]) urlProblems.push(s.name + ' ' + px + 'px → ' + JSON.stringify(r));
  }
}
check('1b. 全アイコン×4サイズで srcset が 1x/2x/3x の表示サイズ版・src が 2x 版(サイズ指定以外は元URLのまま)', urlProblems.length === 0, urlProblems.slice(0, 3).join('\n'));
check('1c. 元の解像度より大きくしない', sized('https://yt3.ggpht.com/abc=s100-c-k-no-rj', 64).srcset === 'https://yt3.ggpht.com/abc=s64-c-k-no-rj 1x, https://yt3.ggpht.com/abc=s100-c-k-no-rj 2x, https://yt3.ggpht.com/abc=s100-c-k-no-rj 3x');
check('1d. 対象外のURL(yt3以外・サイズ指定なし・空)は元のまま・srcset なし',
  JSON.stringify(sized('https://i.ytimg.com/vi/abc/mqdefault.jpg', 64)) === JSON.stringify({ src: 'https://i.ytimg.com/vi/abc/mqdefault.jpg', srcset: '' })
  && JSON.stringify(sized('https://yt3.ggpht.com/abc', 64)) === JSON.stringify({ src: 'https://yt3.ggpht.com/abc', srcset: '' })
  && sized('', 64).srcset === '');
check('1e. 生成されるサイズは表示サイズの3倍まで(64px → 最大 s192・ぼやけない解像度)', /=s192-/.test(sized(withIcon[0].icon, 64).srcset.split(', ')[2]));

// ---- 2. 実際の描画関数 ----
const iconStreamer = withIcon.find((s) => /^[^"\\]+$/.test(s.name));
const card = run('createStreamerCard(' + JSON.stringify(iconStreamer.name) + ', 5)');
const cardImg = card.find((e) => e.tagName === 'IMG');
const cardSizes = sized(iconStreamer.icon, 64);
check('2a. VTuberカード: <img> の srcset / src が 64px 表示向け', !!cardImg && cardImg.srcset === cardSizes.srcset && cardImg.src === cardSizes.src, cardImg && cardImg.srcset);
check('2b. VTuberカード: alt=""(名前が同じリンク内に文字である装飾画像)・loading=lazy・クラス維持',
  cardImg && cardImg.alt === '' && cardImg.loading === 'lazy' && cardImg.className === 'streamer-card-icon');
check('2c. VTuberカード: リンク先は従来どおり streamerUrl()', card.children[0].tagName === 'A' && card.children[0].href === run('streamerUrl(' + JSON.stringify(iconStreamer.name) + ')'));
cardImg.fire('error');
check('2d. VTuberカード: アイコン読み込み失敗時は頭文字のプレースホルダーへ切り替わる',
  !card.find((e) => e.tagName === 'IMG') && !!card.find((e) => e.className === 'streamer-card-icon streamer-card-icon--placeholder' && e.textContent === iconStreamer.name.charAt(0)));

const playlists = run('PLAYLISTS');
const withThumb = playlists.find((p) => run('getPlaylistThumbnailUrl(' + JSON.stringify(p) + ')') && STREAMERS.some((s) => s.name === p.streamer && s.icon));
const thumbOpts = '{ width: 120, height: 68, containerClass: "row-thumb", placeholderClass: "row-thumb-placeholder" }';
const thumb = run('createPlaylistThumbnail(' + JSON.stringify(withThumb) + ', ' + thumbOpts + ')');
const tImg = thumb.children[0];
check('2e. 再生リストサムネイル: src は従来どおり thumbnailUrl(mqdefault)で srcset なし', tImg.src === withThumb.thumbnailUrl && !tImg.srcset && /\/mqdefault(_live)?\.jpg$/.test(tImg.src), tImg.src);
check('2f. 再生リストサムネイル: loading=lazy・decoding=async・width/height=120×68・alt=""',
  tImg.loading === 'lazy' && tImg.decoding === 'async' && tImg.width === 120 && tImg.height === 68 && tImg.alt === '');
tImg.fire('error');
const fImg = thumb.children[0];
const fSizes = sized(STREAMERS.find((s) => s.name === withThumb.streamer).icon, 120);
check('2g. サムネイル失敗時のVTuberアイコン: 枠の幅(120px)向けの srcset・lazy・async・width/height を維持',
  fImg && fImg.tagName === 'IMG' && fImg.srcset === fSizes.srcset && fImg.src === fSizes.src && fImg.loading === 'lazy' && fImg.decoding === 'async' && fImg.width === 120 && fImg.height === 68, fImg && fImg.srcset);
fImg.fire('error');
check('2h. アイコンも失敗したら頭文字のプレースホルダー(画像欠落の空枠にしない)', thumb.children.length === 1 && thumb.children[0].tagName === 'SPAN' && thumb.children[0].className === 'row-thumb-placeholder');
const noThumb = Object.assign({}, withThumb, { thumbnailUrl: 'https://i.ytimg.com/img/no_thumbnail.jpg' });
const nImg = run('createPlaylistThumbnail(' + JSON.stringify(noThumb) + ', ' + thumbOpts + ')').children[0];
check('2i. サムネイル無しの再生リストは最初からVTuberアイコン(サイズ指定版)', nImg.tagName === 'IMG' && nImg.srcset === fSizes.srcset);

// ---- 3. 表示サイズとの一致・各ページの設定 ----
const css = read('style.css');
const cssPx = (sel, prop) => { const m = new RegExp('\\n' + sel.replace(/\./g, '\\.') + '\\s*\\{([^}]*)\\}').exec(css); const v = m && new RegExp('(?:^|[;\\s])' + prop + ':\\s*(\\d+)px').exec(m[1]); return v ? Number(v[1]) : null; };
const common = read('common.js'), search = read('search.js'), streamer = read('streamer.js');
check('3a. .streamer-card-icon は 64px 四方 = createStreamerCard の指定', cssPx('.streamer-card-icon', 'width') === 64 && cssPx('.streamer-card-icon', 'height') === 64 && /setIconImageSource\(img, s\.icon, 64\)/.test(common));
check('3b. .streamer-icon(VTuber詳細の見出し)は 72px 四方 = streamer.js の指定', cssPx('.streamer-icon', 'width') === 72 && cssPx('.streamer-icon', 'height') === 72 && /setIconImageSource\(iconEl, roster\.icon, 72\)/.test(streamer));
check('3c. .search-result-icon は 36px 四方 = search.js の指定', cssPx('.search-result-icon', 'width') === 36 && /setIconImageSource\(img, s\.icon, 36\)/.test(search));
check('3d. サムネイル枠 .row-thumb / .playlist-card-thumb は幅 120px 以下(アイコン代替は枠の幅で指定)', cssPx('.row-thumb', 'width') === 120 && cssPx('.playlist-card-thumb', 'width') === 120 && /setIconImageSource\(img, iconUrl, width\)/.test(common));
check('3e. アイコンを直接 src に入れる箇所が残っていない(表示サイズ版を経由する)',
  !/\.src = (s\.icon|iconUrl|roster\.icon)/.test(common + search + streamer));
check('3f. VTuber詳細の見出しアイコン(ファーストビュー)は lazy にしない', !/iconEl\.loading/.test(streamer) && !/id="streamer-icon"[^>]*loading=/.test(read('streamer.html')));
check('3g. VTuber詳細の見出しアイコンの alt は従来どおり「名前 のアイコン」', /iconEl\.alt = streamer \+ " のアイコン"/.test(streamer));

// ---- 4. 変えていないもの ----
check('4a. og:image はVTuberアイコンの元URL(またはサムネイル)のまま', /representativeThumb \? getPlaylistThumbnailUrl\(representativeThumb\) : \(roster && roster\.icon\) \|\| null/.test(streamer));
const rawIcons = [...read('data-core.js').matchAll(/icon: "([^"]*)"/g)].map((m) => m[1]);
check('4b. 描画後もデータ側のアイコンURL(STREAMERS)は data-core.js の元URLのまま',
  JSON.stringify(run('STREAMERS.filter((s) => s.icon).map((s) => s.icon)')) === JSON.stringify(rawIcons));
check('4c. 再生リストのサムネイルは全件 i.ytimg.com の元URLのまま', playlists.every((p) => !p.thumbnailUrl || /^https:\/\/i\.ytimg\.com\//.test(p.thumbnailUrl)));

console.log('');
console.log('PASS: ' + pass + '  FAIL: ' + fail);
process.exit(fail ? 1 : 0);
