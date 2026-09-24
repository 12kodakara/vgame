/**
 * ゲーム詳細・VTuber詳細ページ用の分割データ data/games/NN.js・data/streamers/NN.js を生成する
 * (自動生成物。手編集しないこと)。
 *
 * 詳細ページは数MBある data-playlists.js を読み込まず、表示するゲーム/VTuberが入っている
 * 分割ファイル1つだけを読み込む。分割は名前のハッシュ(common.js の detailShardIndex と同じ
 * FNV-1a 32bit)で DETAIL_SHARD_COUNT 個に振り分けるため、ゲームやVTuberが増えても
 * ファイル数は増えない(1ファイルあたりの件数が増えるだけ)。
 *
 * 各エントリの内容:
 *   playlists … そのゲーム(またはVTuber)の再生リスト(data-playlists.js のレコードそのまま・元の順序)
 *   related   … 関連ゲーム / 同じゲームを実況しているVTuber の候補と件数([名前, 件数] の配列)。
 *               game.js / streamer.js と同じ定義で全再生リストから集計し、表示件数(15 / 10)番目の
 *               件数以上をすべて残す(同点の並び順はブラウザ側で従来どおり決めるため)。
 *
 * 使い方(リポジトリのルートで実行):
 *   node generate-detail-data.js           … data/games・data/streamers を書き出す(同じ内容なら書き換えない)
 *   node generate-detail-data.js --check   … 最新データと一致するかだけ確認する(一致しなければ終了コード1)
 */
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const ROOT = __dirname;
const DETAIL_SHARD_COUNT = 64;           // common.js の DETAIL_SHARD_COUNT と同じ値
const DETAIL_DATA_VERSION = 1;           // common.js の DETAIL_DATA_VERSION と同じ値
const GAME_RELATED_LIMIT = 15;           // game.js: 関連ゲームの候補数
const STREAMER_RELATED_LIMIT = 10;       // streamer.js: 同じゲームを実況しているVTuberの表示数
const KINDS = { games: 'games', streamers: 'streamers' };

/** common.js の detailShardIndex と同じ FNV-1a(UTF-16 コード単位) */
function detailShardIndex(key) {
  let h = 0x811c9dc5;
  for (let i = 0; i < key.length; i++) {
    h ^= key.charCodeAt(i);
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h % DETAIL_SHARD_COUNT;
}

function loadData() {
  const ctx = {};
  vm.createContext(ctx);
  for (const f of ['data-core.js', 'data-playlists.js', 'data-standalone.js']) {
    vm.runInContext(fs.readFileSync(path.join(ROOT, f), 'utf8'), ctx, { filename: f });
  }
  const pick = (name) => JSON.parse(JSON.stringify(vm.runInContext('typeof ' + name + ' === "undefined" ? [] : ' + name, ctx)));
  return { playlists: pick('PLAYLISTS'), standalone: pick('STANDALONE_PLAYS') };
}

/** 件数の多い順で limit 番目の件数以上の候補をすべて返す(同点は切らない)。順序は元データの出現順。 */
function keepTopWithTies(order, counts, limit) {
  const sorted = order.map((k) => counts[k]).sort((a, b) => b - a);
  if (!sorted.length) return [];
  const threshold = sorted.length >= limit ? sorted[limit - 1] : 0;
  return order.filter((k) => counts[k] >= threshold).map((k) => [k, counts[k]]);
}

function buildEntries(playlists, standalone) {
  const byGame = new Map(), byStreamer = new Map();
  const push = (m, k, p) => { if (!m.has(k)) m.set(k, []); m.get(k).push(p); };
  playlists.forEach((p) => { push(byGame, p.game, p); push(byStreamer, p.streamer, p); });

  // game.js: streamerNames = そのゲームの再生リスト・単発実況の実況者。
  //          関連ゲーム = 全再生リストのうち「別のゲーム かつ 実況者が streamerNames に含まれる」をゲームごとに数える。
  const gameNames = new Set([...byGame.keys(), ...standalone.map((p) => p.game)]);
  const games = {};
  for (const game of gameNames) {
    const streamerNames = new Set();
    (byGame.get(game) || []).forEach((p) => streamerNames.add(p.streamer));
    standalone.filter((p) => p.game === game).forEach((p) => streamerNames.add(p.streamer));
    const counts = {}, order = [];
    playlists.forEach((p) => {
      if (p.game === game || !streamerNames.has(p.streamer)) return;
      if (!counts[p.game]) { counts[p.game] = 0; order.push(p.game); }
      counts[p.game] += 1;
    });
    games[game] = { playlists: byGame.get(game) || [], related: keepTopWithTies(order, counts, GAME_RELATED_LIMIT) };
  }

  // streamer.js: myGames = その実況者の再生リスト・単発実況のゲーム。
  //              同じゲームを実況しているVTuber = 全再生リストのうち「本人以外 かつ ゲームが myGames に含まれる」を
  //              実況者ごとに(ゲームの種類数で)数える。
  const streamerNames = new Set([...byStreamer.keys(), ...standalone.map((p) => p.streamer)]);
  const streamers = {};
  for (const streamer of streamerNames) {
    const myGames = new Set();
    (byStreamer.get(streamer) || []).forEach((p) => myGames.add(p.game));
    standalone.filter((p) => p.streamer === streamer).forEach((p) => myGames.add(p.game));
    const sets = {}, order = [];
    playlists.forEach((p) => {
      if (p.streamer === streamer || !myGames.has(p.game)) return;
      if (!sets[p.streamer]) { sets[p.streamer] = new Set(); order.push(p.streamer); }
      sets[p.streamer].add(p.game);
    });
    const counts = {}; order.forEach((k) => { counts[k] = sets[k].size; });
    streamers[streamer] = { playlists: byStreamer.get(streamer) || [], related: keepTopWithTies(order, counts, STREAMER_RELATED_LIMIT) };
  }
  return { games, streamers };
}

function renderShard(kind, index, entries) {
  const body = {};
  Object.keys(entries).sort().forEach((k) => { body[k] = entries[k]; });   // 決定的な出力のため名前順
  return '/* 自動生成(generate-detail-data.js)。手編集しないこと。 */\n'
    + 'registerDetailShard(' + JSON.stringify(kind) + ', ' + index + ', ' + DETAIL_DATA_VERSION + ', '
    + JSON.stringify(body) + ');\n';
}

function buildFiles() {
  const { playlists, standalone } = loadData();
  if (!playlists.length) throw new Error('PLAYLISTS が空です。data-playlists.js を確認してください。');
  const { games, streamers } = buildEntries(playlists, standalone);
  const files = new Map();
  for (const [kind, map] of [[KINDS.games, games], [KINDS.streamers, streamers]]) {
    const shards = Array.from({ length: DETAIL_SHARD_COUNT }, () => ({}));
    for (const [key, entry] of Object.entries(map)) shards[detailShardIndex(key)][key] = entry;
    shards.forEach((entries, i) => {
      files.set(path.join('data', kind, String(i).padStart(2, '0') + '.js'), renderShard(kind, i, entries));
    });
  }
  return files;
}

const files = buildFiles();
const check = process.argv.includes('--check');
let stale = [];
for (const [rel, text] of files) {
  const abs = path.join(ROOT, rel);
  const cur = fs.existsSync(abs) ? fs.readFileSync(abs, 'utf8').replace(/\r\n/g, '\n') : null;
  if (cur !== text) stale.push(rel);
}
// 生成対象外の古いファイルが残っていないか
for (const kind of Object.values(KINDS)) {
  const dir = path.join(ROOT, 'data', kind);
  if (!fs.existsSync(dir)) continue;
  for (const f of fs.readdirSync(dir)) if (!files.has(path.join('data', kind, f))) stale.push(path.join('data', kind, f) + ' (不要)');
}

if (check) {
  if (!stale.length) { console.log('詳細ページ用データ(' + files.size + 'ファイル)は最新です。'); process.exit(0); }
  console.error('詳細ページ用データが data-playlists.js と一致しません(' + stale.length + '件)。node generate-detail-data.js を実行してください。\n  ' + stale.slice(0, 10).join('\n  '));
  process.exit(1);
}

for (const kind of Object.values(KINDS)) fs.mkdirSync(path.join(ROOT, 'data', kind), { recursive: true });
let written = 0;
for (const [rel, text] of files) {
  const abs = path.join(ROOT, rel);
  const cur = fs.existsSync(abs) ? fs.readFileSync(abs, 'utf8').replace(/\r\n/g, '\n') : null;
  if (cur !== text) { fs.writeFileSync(abs, text, 'utf8'); written++; }
}
for (const s of stale.filter((x) => x.endsWith(' (不要)'))) fs.unlinkSync(path.join(ROOT, s.replace(' (不要)', '')));
const total = [...files.values()].reduce((sum, t) => sum + Buffer.byteLength(t), 0);
console.log('詳細ページ用データ: ' + files.size + 'ファイル / ' + total + ' bytes(更新 ' + written + '件)');
