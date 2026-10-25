/**
 * 検索候補(attachSearchSuggest)の表示位置の回帰テスト。ブラウザ不要(node test-search-suggest-position.js)。
 *
 * iPhone Safari では、キーボードが出るとページを動かさずに表示範囲(visualViewport)だけがずれ、
 * 一度だけ計算した位置のまま候補が入力欄に重なることがあった。最小限の DOM の上で次を確かめる。
 *   1. 候補は入力欄の直下(下端 + 4px)・同じ幅で表示する(PC 幅・スマホ幅)
 *   2. 表示中は、スクロール・画面サイズの変化・visualViewport の resize / scroll で位置を計算し直し、入力欄に追従する
 *   3. キーボード表示中(見えている範囲が狭い)は、はみ出さない高さに抑え、広いときは CSS の上限のまま
 *   4. 入力欄が見えている範囲の外に出たら、古い位置に残さず閉じる
 *   5. リスナーは表示中だけ登録し、閉じたら外す(何度開閉しても重複しない)
 *   6. 候補の選択(↓・Enter)、Esc で閉じる操作は従来どおり
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
console.log('=== 検索候補の表示位置 回帰テスト ===');

// ---- 最小限の DOM ----
class El {
  constructor(tag) { this.tagName = String(tag).toUpperCase(); this.children = []; this.attrs = {}; this.listeners = {}; this.parent = null; this.hidden = false; this._text = ''; this.style = {}; this.dataset = {};
    const cls = new Set(); this.classList = { add: (...c) => c.forEach((x) => cls.add(x)), remove: (...c) => c.forEach((x) => cls.delete(x)), toggle: (c, f) => { const on = f === undefined ? !cls.has(c) : f; if (on) cls.add(c); else cls.delete(c); return on; }, contains: (c) => cls.has(c) }; }
  get className() { return this.attrs.class || ''; } set className(v) { this.attrs.class = String(v); }
  get textContent() { return this._text + this.children.map((c) => c.textContent).join(''); } set textContent(v) { this._text = String(v); this.children = []; }
  set innerHTML(v) { if (v === '') { this.children = []; this._text = ''; } } get innerHTML() { return ''; }
  appendChild(c) { c.parent = this; this.children.push(c); return c; }
  setAttribute(k, v) { this.attrs[k] = String(v); } getAttribute(k) { return k in this.attrs ? this.attrs[k] : null; } removeAttribute(k) { delete this.attrs[k]; } hasAttribute(k) { return k in this.attrs; }
  addEventListener(t, f) { (this.listeners[t] = this.listeners[t] || []).push(f); } removeEventListener() {}
  fire(t, ev) { (this.listeners[t] || []).slice().forEach((f) => f(Object.assign({ type: t, target: this, preventDefault() { this.prevented = true; } }, ev || {}))); }
  querySelectorAll() { return []; } querySelector() { return null; }
  getBoundingClientRect() { return this.rect; }
  focus() {} blur() {} scrollIntoView() {}
}
// 追加・削除を数えるイベントの的(window・visualViewport)
function makeTarget() {
  const t = { listeners: {} };
  t.addEventListener = (type, f) => { (t.listeners[type] = t.listeners[type] || []).push(f); };
  t.removeEventListener = (type, f) => { t.listeners[type] = (t.listeners[type] || []).filter((x) => x !== f); };
  t.fire = (type) => (t.listeners[type] || []).slice().forEach((f) => f({ type }));
  t.count = (type) => (t.listeners[type] || []).length;
  return t;
}

// width: 画面幅(PC 1366 / スマホ 390)。入力欄の位置は input.rect を書き換えて再現する
function setup(width) {
  const doc = { body: new El('body'), head: new El('head'), listeners: {}, readyState: 'loading', activeElement: null };
  doc.createElement = (t) => new El(t); doc.createDocumentFragment = () => new El('#fragment');
  doc.getElementById = () => null; doc.querySelector = () => null; doc.querySelectorAll = () => [];
  doc.addEventListener = (t, f) => { (doc.listeners[t] = doc.listeners[t] || []).push(f); };
  const win = makeTarget();
  const vv = Object.assign(makeTarget(), { offsetTop: 0, height: 800, width });
  const frames = [];
  const timers = [];
  const storage = { data: {}, getItem(k) { return this.data[k] || null; }, setItem(k, v) { this.data[k] = String(v); }, removeItem(k) { delete this.data[k]; } };
  const ctx = {
    console, document: doc, localStorage: storage, sessionStorage: storage, navigator: { userAgent: 'node' }, URLSearchParams, URL, encodeURIComponent, decodeURIComponent,
    location: { search: '', href: 'https://vgame-navi.jp/', pathname: '/', hash: '' }, history: { replaceState() {}, pushState() {} },
    setTimeout: (f) => { timers.push(f); return timers.length; }, clearTimeout() {},
    requestAnimationFrame: (f) => { frames.push(f); return frames.length; }, cancelAnimationFrame: (id) => { frames[id - 1] = null; },
    matchMedia: () => ({ matches: false, addEventListener() {} }), innerWidth: width, innerHeight: 800, visualViewport: vv,
  };
  ctx.window = ctx;
  ctx.addEventListener = win.addEventListener; ctx.removeEventListener = win.removeEventListener;
  vm.createContext(ctx);
  for (const f of ['data-core.js', 'data-counts.js', 'common.js']) vm.runInContext(read(f), ctx, { filename: f });
  const input = new El('input');
  input.value = '';
  input.rect = { top: 100, bottom: 136, left: 20, right: width - 20, width: width - 40, height: 36 };
  vm.runInContext('attachSearchSuggest', ctx)(input);
  const list = doc.body.children.find((c) => c.className === 'search-suggest-list');
  const flushTimers = () => { while (timers.length) timers.shift()(); };
  const flushFrames = () => { while (frames.length) { const f = frames.shift(); if (f) f(); } };
  const type = (v) => { input.value = v; doc.activeElement = input; input.fire('input'); flushTimers(); };
  return { ctx, doc, win, vv, input, list, type, flushFrames, flushTimers };
}
const items = (list) => list.children.filter((c) => /search-suggest-item(?!--footer)/.test(c.className) && !/footer/.test(c.className));

for (const [label, width] of [['PC', 1366], ['スマホ', 390]]) {
  const s = setup(width);
  s.type('マイ');
  check('1. [' + label + '] 候補は入力欄の直下(下端+4px)・入力欄と同じ幅で表示する', !s.list.hidden && items(s.list).length > 0 && s.list.style.top === '140px' && s.list.style.left === '20px' && s.list.style.width === (width - 40) + 'px');
  check('3a. [' + label + '] 見えている範囲が広いときは、高さを CSS の上限(340px)のままにする', s.list.style.maxHeight === '');
  check('5a. [' + label + '] 表示中だけスクロール・画面サイズ・visualViewport のリスナーを1つずつ登録する', s.win.count('scroll') === 1 && s.win.count('resize') === 1 && s.vv.count('resize') === 1 && s.vv.count('scroll') === 1);

  // ページのスクロールで入力欄が上へ動いた
  s.input.rect = Object.assign({}, s.input.rect, { top: 40, bottom: 76 });
  s.win.fire('scroll'); s.win.fire('scroll'); s.flushFrames();
  check('2a. [' + label + '] スクロールで入力欄が動いたら、その直下へ追従する(1フレームにまとめて計算)', s.list.style.top === '80px' && !s.list.hidden);

  // iPhone Safari: キーボードが出て、表示範囲だけがずれて狭くなる(入力欄の画面上の位置もずれる)
  s.input.rect = Object.assign({}, s.input.rect, { top: 300, bottom: 336 });
  Object.assign(s.vv, { offsetTop: 250, height: 330 });
  s.vv.fire('resize'); s.vv.fire('scroll'); s.flushFrames();
  check('2b. [' + label + '] visualViewport の resize・scroll(キーボード表示)でも入力欄の直下へ追従する', s.list.style.top === '340px' && !s.list.hidden);
  check('3b. [' + label + '] キーボード表示中は、見えている範囲の下端からはみ出さない高さに抑える(下限120px)', s.list.style.maxHeight === Math.max(Math.floor(250 + 330 - 340 - 8), 120) + 'px');

  // 画面の向きの変更など
  s.input.rect = Object.assign({}, s.input.rect, { left: 30, width: width - 60 });
  Object.assign(s.vv, { offsetTop: 0, height: 800 });
  s.win.fire('resize'); s.flushFrames();
  check('2c. [' + label + '] 画面サイズが変わったら、位置と幅を計算し直し、高さの制限も外す', s.list.style.left === '30px' && s.list.style.width === (width - 60) + 'px' && s.list.style.maxHeight === '');

  // 候補の選択と閉じる操作
  s.input.fire('keydown', { key: 'ArrowDown' });
  check('6a. [' + label + '] ↓で1件目を選択状態にする', items(s.list)[0].classList.contains('active'));
  s.input.fire('keydown', { key: 'Escape' });
  check('6b. [' + label + '] Esc で閉じ、リスナーを外す', s.list.hidden && s.win.count('scroll') === 0 && s.win.count('resize') === 0 && s.vv.count('resize') === 0 && s.vv.count('scroll') === 0);

  // 何度開閉しても重複しない
  for (let i = 0; i < 5; i++) { s.type('マイ' + 'ン'.repeat(i % 2)); s.input.fire('blur'); s.flushTimers(); }
  s.type('マイ');
  check('5b. [' + label + '] 何度開閉しても、表示中のリスナーは1つずつ(重複しない)', !s.list.hidden && s.win.count('scroll') === 1 && s.vv.count('resize') === 1);

  // 入力欄が見えている範囲の外へ出た
  s.input.rect = Object.assign({}, s.input.rect, { top: -200, bottom: -164 });
  s.win.fire('scroll'); s.flushFrames();
  check('4. [' + label + '] 入力欄が見えている範囲の外へ出たら、古い位置に残さず閉じ、リスナーを外す', s.list.hidden && s.win.count('scroll') === 0 && s.vv.count('scroll') === 0);
}

// visualViewport が無いブラウザ(古いブラウザ)でも動く
{
  const s = setup(1366);
  delete s.ctx.visualViewport;
  s.type('マイ');
  check('7. visualViewport が無くても、innerHeight で見えている範囲を求めて表示する', !s.list.hidden && s.list.style.top === '140px' && s.win.count('scroll') === 1);
}

console.log('\nPASS: ' + pass + '  FAIL: ' + fail);
process.exit(fail ? 1 : 0);
