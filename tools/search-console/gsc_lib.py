"""ぶいゲー Search Console 検索実績レポートの中核処理(標準ライブラリだけで動く部分)。

API への接続・認証は gsc_auth.py、コマンドは gsc_report.py。ここには通信を含めない
(テストでは query_fn を固定データに差し替えて動かす)。

- 日付: 日本時間(UTC+9)の「今日」から確定済みデータの遅れ(既定3日)を引いた日を最終日にする。
  ※ Search Console の1日の区切りは米国太平洋時間。日本時間で数えた日付とは数時間ずれる(レポートに明記する)。
- 取得: Search Analytics API(searchanalytics.query)。1回最大 25,000 行で startRow によるページング。
  dataState は "final"(確定済みのみ)。行数の上限に達したら「打ち切り」として記録する。
- 集計: CTR はクリック数 ÷ 表示回数で計算し直し、平均掲載順位は表示回数で重み付けした平均にする。
"""
from __future__ import annotations

import csv
import datetime as dt
import json
import math
import os
import re
from pathlib import Path
from typing import Callable, Iterable

JST = dt.timezone(dt.timedelta(hours=9), "JST")  # 日本は夏時間が無いので固定の +9 時間でよい
DEFAULT_SITE = "sc-domain:vgame-navi.jp"
SCOPES = ["https://www.googleapis.com/auth/webmasters.readonly"]
API_ROW_LIMIT = 25000          # searchanalytics.query の1回の最大行数
DEFAULT_MAX_ROWS = 100000      # 1つの集計で取得する行数の上限(超えたら打ち切りとして記録)
DEFAULT_LAG_DAYS = 3           # 確定済みデータになるまでの日数の目安
DEFAULT_PERIODS = (7, 28, 90)

# 集計の種類(dimensions)。totals は次元なし(匿名化された検索語句も含む合計)
DATASETS = {
    "totals": [],
    "daily": ["date"],
    "pages": ["page"],
    "queries": ["query"],
    "page_queries": ["page", "query"],
}

CAVEATS = [
    "Search Console の日付は米国太平洋時間で区切られる。期間は日本時間の今日から確定済みデータの遅れを引いて決めているため、日本時間の日付とは数時間ずれる。",
    "プライバシー保護のため、検索回数の少ない検索語句(匿名化された検索語句)は検索キーワード別・ページ×キーワード別の集計に含まれない。合計(totals)との差を「キーワード別に出ていない割合」として示す。",
    "API の行数制限(1回 25,000 行・1集計あたりの取得上限)とデータ量の上限により、行数の多い集計は全件ではない可能性がある(打ち切りは datasets.*.truncated に記録)。",
    "ページ別の集計と、ページ×キーワード別の合計は一致しない(集計方法と匿名化の違いのため)。",
    "表示回数の少ない行の CTR・平均掲載順位はぶれが大きい。ランキングでは「参考値」として分けている。",
]


# ============================================================
# 秘密の値を伏せる(ログ・エラー・レポートに出す文字列は必ず通す)
# ============================================================
_SECRET_PATTERNS = [
    re.compile(r"ya29\.[0-9A-Za-z_\-]+"),                 # アクセストークン
    re.compile(r"1//[0-9A-Za-z_\-]{10,}"),                # 更新トークン
    re.compile(r"GOCSPX-[0-9A-Za-z_\-]+"),                # クライアントシークレット
    re.compile(r'("?(?:client_secret|refresh_token|access_token|token|id_token)"?\s*[:=]\s*"?)[^"\s,&}]+', re.I),
    re.compile(r"([?&](?:key|access_token|token)=)[^&\s\"]+", re.I),
]


_SECRET_SHAPES = re.compile(r"ya29\.[0-9A-Za-z_\-]{10,}|1//[0-9A-Za-z_\-]{20,}|GOCSPX-[0-9A-Za-z_\-]{10,}")


def contains_secret(text: str, secrets: Iterable[str] = ()) -> bool:
    """保存前の確認。実際の秘密の値か、Google のトークン・シークレットに特有の形を含むか
    (検索語句や URL を誤って止めないよう、エラー文用の redact より狭く判定する)。"""
    return any(v and len(v) >= 6 and v in text for v in secrets) or bool(_SECRET_SHAPES.search(text))


def redact(text, secrets: Iterable[str] = ()) -> str:
    s = "" if text is None else str(text)
    for v in secrets:
        if v and len(v) >= 6:
            s = s.replace(v, "***")
    for p in _SECRET_PATTERNS:
        s = p.sub(lambda m: (m.group(1) if m.groups() else "") + "***", s)
    return s


# ============================================================
# 保存先(リポジトリの外のローカル専用フォルダ)
# ============================================================
def seo_dir() -> Path:
    base = os.environ.get("VGAME_SEO_DIR")
    if base:
        return Path(base)
    local = os.environ.get("LOCALAPPDATA")
    if not local:
        raise RuntimeError("LOCALAPPDATA が設定されていません(保存先を決められない)")
    return Path(local) / "vgame-seo"


def paths() -> dict:
    d = seo_dir()
    return {"dir": d, "client": d / "oauth-client.json", "token": d / "token.json", "reports": d / "reports"}


def ensure_outside_repo(p: Path, repo_root: Path) -> None:
    """レポート・トークンをリポジトリの中に置かない(誤って commit・公開しないため)。"""
    rp, rr = p.resolve(), repo_root.resolve()
    if rp == rr or rr in rp.parents:
        raise ValueError(f"保存先がリポジトリの中です。リポジトリの外を指定してください: {p}")


# ============================================================
# 期間(日本時間)
# ============================================================
def today_jst(now: dt.datetime | None = None) -> dt.date:
    now = now or dt.datetime.now(dt.timezone.utc)
    if now.tzinfo is None:
        raise ValueError("now にはタイムゾーン付きの日時を渡すこと")
    return now.astimezone(JST).date()


def build_periods(end: dt.date, lengths=DEFAULT_PERIODS) -> list[dict]:
    """直近 N 日(最終日 end を含む)と、その直前の同じ長さの期間。"""
    out = []
    for n in lengths:
        if n < 1:
            raise ValueError(f"期間の日数が不正です: {n}")
        cur_start = end - dt.timedelta(days=n - 1)
        prev_end = cur_start - dt.timedelta(days=1)
        prev_start = prev_end - dt.timedelta(days=n - 1)
        out.append({"name": f"{n}d", "days": n, "current": (cur_start.isoformat(), end.isoformat()),
                    "previous": (prev_start.isoformat(), prev_end.isoformat())})
    return out


def default_end(now: dt.datetime | None = None, lag_days: int = DEFAULT_LAG_DAYS) -> dt.date:
    return today_jst(now) - dt.timedelta(days=lag_days)


# ============================================================
# 取得(ページング)
# ============================================================
class GscApiError(Exception):
    """API の失敗(メッセージは伏せ字済み)。"""


def normalize_row(row: dict, dimensions: list[str]) -> dict:
    keys = row.get("keys") or []
    out = {d: (keys[i] if i < len(keys) else "") for i, d in enumerate(dimensions)}
    clicks = float(row.get("clicks", 0) or 0)
    impressions = float(row.get("impressions", 0) or 0)
    out.update({"clicks": clicks, "impressions": impressions,
                "ctr": (clicks / impressions) if impressions else 0.0,   # API の値ではなく計算し直す
                "position": float(row.get("position", 0) or 0)})
    return out


def fetch_dataset(query_fn: Callable[[dict], dict], start: str, end: str, dimensions: list[str],
                  max_rows: int = DEFAULT_MAX_ROWS, row_limit: int = API_ROW_LIMIT, secrets: Iterable[str] = ()) -> dict:
    """1つの集計を全ページ取得する。query_fn(body) → API の応答(dict)。失敗しても再試行しない。"""
    rows: list[dict] = []
    requests = 0
    truncated = False
    start_row = 0
    while True:
        limit = min(row_limit, max_rows - len(rows))
        if limit <= 0:
            truncated = True
            break
        body = {"startDate": start, "endDate": end, "dimensions": list(dimensions), "type": "web",
                "dataState": "final", "rowLimit": limit, "startRow": start_row}
        try:
            resp = query_fn(body) or {}
        except Exception as e:  # noqa: BLE001 - API ライブラリの例外をまとめて伏せ字にする
            raise GscApiError(redact(f"{type(e).__name__}: {e}", secrets)) from None
        requests += 1
        page = resp.get("rows") or []
        rows.extend(normalize_row(r, dimensions) for r in page)
        if len(page) < limit:
            break
        start_row += len(page)
        if len(rows) >= max_rows:
            truncated = True
            break
    return {"dimensions": list(dimensions), "start": start, "end": end, "rows": rows, "requests": requests, "truncated": truncated}


# ============================================================
# 集計・比較
# ============================================================
def aggregate(rows: Iterable[dict]) -> dict:
    """クリック・表示回数は合計、CTR は合計から計算、平均掲載順位は表示回数で重み付けした平均。"""
    clicks = impressions = weighted = 0.0
    for r in rows:
        clicks += r["clicks"]
        impressions += r["impressions"]
        weighted += r["position"] * r["impressions"]
    return {"clicks": clicks, "impressions": impressions, "ctr": (clicks / impressions) if impressions else 0.0,
            "position": (weighted / impressions) if impressions else 0.0}


def group_by(rows: Iterable[dict], key_fields: list[str]) -> dict:
    groups: dict = {}
    for r in rows:
        groups.setdefault(tuple(r[k] for k in key_fields), []).append(r)
    return {k: aggregate(v) for k, v in groups.items()}


def _pct(cur: float, prev: float):
    return None if not prev else (cur - prev) / prev


def compare(cur_rows: list[dict], prev_rows: list[dict], key_fields: list[str]) -> list[dict]:
    cur, prev = group_by(cur_rows, key_fields), group_by(prev_rows, key_fields)
    out = []
    for k in sorted(set(cur) | set(prev)):
        c = cur.get(k, {"clicks": 0.0, "impressions": 0.0, "ctr": 0.0, "position": 0.0})
        p = prev.get(k, {"clicks": 0.0, "impressions": 0.0, "ctr": 0.0, "position": 0.0})
        status = "new" if k not in prev else ("lost" if k not in cur else "both")
        row = {f: v for f, v in zip(key_fields, k)}
        row.update({"status": status, "clicks": c["clicks"], "clicks_prev": p["clicks"], "clicks_diff": c["clicks"] - p["clicks"],
                    "clicks_change": _pct(c["clicks"], p["clicks"]), "impressions": c["impressions"], "impressions_prev": p["impressions"],
                    "impressions_diff": c["impressions"] - p["impressions"], "impressions_change": _pct(c["impressions"], p["impressions"]),
                    "ctr": c["ctr"], "ctr_prev": p["ctr"], "ctr_diff": c["ctr"] - p["ctr"], "position": c["position"], "position_prev": p["position"],
                    # 順位は小さいほど良いので「前期間 − 今期間」が正なら改善(どちらかが表示なしなら比較しない)
                    "position_improvement": (p["position"] - c["position"]) if status == "both" else None})
        out.append(row)
    out.sort(key=lambda r: (-r["impressions"], -r["impressions_prev"]))
    return out


def coverage(totals_rows: list[dict], query_rows: list[dict]) -> dict:
    """キーワード別の合計が全体(次元なしの合計)に占める割合。残りは匿名化された検索語句など。"""
    t, q = aggregate(totals_rows), aggregate(query_rows)
    return {"total_clicks": t["clicks"], "total_impressions": t["impressions"], "query_clicks": q["clicks"], "query_impressions": q["impressions"],
            "query_clicks_share": (q["clicks"] / t["clicks"]) if t["clicks"] else None,
            "query_impressions_share": (q["impressions"] / t["impressions"]) if t["impressions"] else None}


# ============================================================
# SEO 改善候補ランキング(ページ単位)
# ============================================================
# 掲載順位ごとの CTR の目安(一般的な傾向の概算。サイトにより大きく違うため「目安との差」を見るだけに使う)
EXPECTED_CTR = [(1, 0.28), (2, 0.15), (3, 0.10), (4, 0.07), (5, 0.05), (6, 0.04), (7, 0.03), (8, 0.025), (9, 0.02), (10, 0.018),
                (15, 0.01), (20, 0.007), (30, 0.004), (50, 0.002), (100, 0.001)]
LOW_DATA_IMPRESSIONS = {7: 30, 28: 100, 90: 300}   # これ未満の表示回数は「参考値」


def expected_ctr(position: float) -> float:
    if position <= 0:
        return 0.0
    prev_p, prev_v = EXPECTED_CTR[0]
    if position <= prev_p:
        return prev_v
    for p, v in EXPECTED_CTR[1:]:
        if position <= p:
            return prev_v + (v - prev_v) * (position - prev_p) / (p - prev_p)
        prev_p, prev_v = p, v
    return EXPECTED_CTR[-1][1]


def low_data_threshold(days: int) -> int:
    if days in LOW_DATA_IMPRESSIONS:
        return LOW_DATA_IMPRESSIONS[days]
    return max(10, round(100 * days / 28))


def rank_candidates(page_compare: list[dict], page_query_rows: list[dict], days: int, top_queries: int = 3) -> list[dict]:
    """ページ別の比較から改善候補を並べる。掲載順位だけで決めず、表示回数・CTR・クリック・前期間との変化を合わせて見る。"""
    threshold = low_data_threshold(days)
    queries_by_page: dict = {}
    for r in page_query_rows:
        queries_by_page.setdefault(r["page"], []).append(r)
    out = []
    for r in page_compare:
        if r["impressions"] <= 0 and r["impressions_prev"] <= 0:
            continue
        impr, clicks, ctr, pos = r["impressions"], r["clicks"], r["ctr"], r["position"]
        reasons, actions = [], []
        potential = 0.0
        if impr > 0 and 0 < pos <= 10:
            exp = expected_ctr(pos)
            potential = max(0.0, exp * impr - clicks)
            if ctr < exp * 0.6:
                reasons.append(f"表示回数 {impr:.0f} 回・平均 {pos:.1f} 位に対して CTR {ctr:.1%}(目安 {exp:.1%})")
                actions.append("title・description を検索意図に合わせて見直す")
        elif impr > 0 and 10 < pos <= 20:
            potential = max(0.0, expected_ctr(10) * impr - clicks)
            reasons.append(f"2ページ目(平均 {pos:.1f} 位)で表示回数 {impr:.0f} 回")
            actions.append("内容の充実・内部リンクで1ページ目を目指す")
        elif impr > 0 and pos > 20:
            potential = max(0.0, expected_ctr(20) * impr - clicks) * 0.5
        lost = max(0.0, r["clicks_prev"] - clicks)
        ich = r["impressions_change"]
        if r["status"] == "lost":
            reasons.append("今期間は表示なし(前期間はあり)")
            actions.append("インデックス・URL変更・noindex の有無を確認する")
        elif ich is not None and r["impressions_prev"] >= threshold and ich <= -0.3:
            reasons.append(f"表示回数が前期間比 {ich:+.0%}")
            actions.append("順位の下落・競合・季節要因を確認する")
        if r["position_improvement"] is not None and r["position_improvement"] <= -3 and impr >= threshold:
            reasons.append(f"平均掲載順位が {-r['position_improvement']:.1f} 位下落")
        if ich is not None and ich >= 0.5 and impr >= threshold:
            reasons.append(f"表示回数が前期間比 {ich:+.0%}(伸びている)")
            actions.append("伸びている検索語句に合わせて内容を強化する")
        if not reasons:
            continue
        score = potential + lost
        tq = sorted(queries_by_page.get(r["page"], []), key=lambda x: -x["impressions"])[:top_queries]
        out.append({"page": r["page"], "score": round(score, 2), "reliability": "参考値(データ少)" if max(impr, r["impressions_prev"]) < threshold else "通常",
                    "impressions": impr, "clicks": clicks, "ctr": ctr, "position": pos, "impressions_prev": r["impressions_prev"],
                    "clicks_prev": r["clicks_prev"], "impressions_change": ich, "potential_clicks": round(potential, 2), "lost_clicks": lost,
                    "reasons": reasons, "actions": sorted(set(actions), key=actions.index),
                    "top_queries": [{"query": q["query"], "impressions": q["impressions"], "clicks": q["clicks"], "position": q["position"]} for q in tq]})
    out.sort(key=lambda x: (x["reliability"] != "通常", -x["score"], -x["impressions"]))
    for i, x in enumerate(out, 1):
        x["rank"] = i
    return out


# ============================================================
# 出力(CSV は Excel で開けるよう BOM 付き UTF-8、JSON は UTF-8)
# ============================================================
def _cell(v):
    if isinstance(v, float):
        return f"{v:.6g}" if not math.isnan(v) else ""
    if isinstance(v, (list, dict)):
        return json.dumps(v, ensure_ascii=False)
    return "" if v is None else v


def write_csv(path: Path, rows: list[dict], fields: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8-sig", newline="") as f:
        w = csv.writer(f)
        w.writerow(fields)
        for r in rows:
            w.writerow([_cell(r.get(k)) for k in fields])


def write_json(path: Path, obj, secrets: Iterable[str] = ()) -> None:
    text = json.dumps(obj, ensure_ascii=False, indent=1)
    if contains_secret(text, secrets):
        raise ValueError("出力に秘密の値らしき文字列が含まれていたため保存しない")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


METRICS = ["clicks", "impressions", "ctr", "position"]
COMPARE_FIELDS = ["status", "clicks", "clicks_prev", "clicks_diff", "clicks_change", "impressions", "impressions_prev", "impressions_diff",
                  "impressions_change", "ctr", "ctr_prev", "ctr_diff", "position", "position_prev", "position_improvement"]
RANK_FIELDS = ["rank", "reliability", "score", "page", "impressions", "clicks", "ctr", "position", "impressions_prev", "clicks_prev",
               "impressions_change", "potential_clicks", "lost_clicks", "reasons", "actions", "top_queries"]


def build_report(query_fn: Callable[[dict], dict], site: str, periods: list[dict], max_rows: int = DEFAULT_MAX_ROWS,
                 secrets: Iterable[str] = (), generated_at: dt.datetime | None = None) -> dict:
    """全期間・全集計を取得してレポートを組み立てる。1つの集計が失敗しても他は続け、errors に記録する。"""
    generated_at = generated_at or dt.datetime.now(dt.timezone.utc)
    report = {"site": site, "generatedAt": generated_at.astimezone(JST).isoformat(timespec="seconds"), "timezone": "日本時間(UTC+9)で期間を決定",
              "dataState": "final", "searchType": "web", "caveats": CAVEATS, "periods": {}, "errors": [], "apiRequests": 0}
    for p in periods:
        pr = {"days": p["days"], "current": p["current"], "previous": p["previous"], "datasets": {}, "data": {}, "previousData": {}}
        for name, dims in DATASETS.items():
            for which, (s, e) in (("current", p["current"]), ("previous", p["previous"])):
                if which == "previous" and name not in ("totals", "pages", "queries"):
                    continue   # 前期間との比較はページ別・キーワード別・合計だけ(行数を抑える)
                try:
                    ds = fetch_dataset(query_fn, s, e, dims, max_rows=max_rows, secrets=secrets)
                except GscApiError as err:
                    report["errors"].append({"period": p["name"], "dataset": name, "range": which, "message": str(err)})
                    continue
                report["apiRequests"] += ds["requests"]
                pr["datasets"][f"{name}:{which}"] = {"rows": len(ds["rows"]), "requests": ds["requests"], "truncated": ds["truncated"], "start": s, "end": e}
                (pr["data"] if which == "current" else pr["previousData"])[name] = ds["rows"]
        d, pd = pr["data"], pr["previousData"]
        if "totals" in d:
            pr["totals"] = aggregate(d["totals"])
        if "totals" in pd:
            pr["totalsPrevious"] = aggregate(pd["totals"])
        if "totals" in d and "queries" in d:
            pr["coverage"] = coverage(d["totals"], d["queries"])
        if "pages" in d and "pages" in pd:
            pr["comparePages"] = compare(d["pages"], pd["pages"], ["page"])
            pr["ranking"] = rank_candidates(pr["comparePages"], d.get("page_queries", []), p["days"])
        if "queries" in d and "queries" in pd:
            pr["compareQueries"] = compare(d["queries"], pd["queries"], ["query"])
        pr["truncated"] = any(v["truncated"] for v in pr["datasets"].values())
        report["periods"][p["name"]] = pr
    report["complete"] = not report["errors"] and not any(v.get("truncated") for v in report["periods"].values())
    return report


def write_report(report: dict, out_dir: Path, secrets: Iterable[str] = ()) -> list[Path]:
    """CSV(集計ごと)と JSON(全体・要約)を書く。書いたファイルの一覧を返す。"""
    written = []
    for name, pr in report["periods"].items():
        d = pr["data"]
        files = [("pages", d.get("pages"), ["page"] + METRICS), ("queries", d.get("queries"), ["query"] + METRICS),
                 ("page_queries", d.get("page_queries"), ["page", "query"] + METRICS), ("daily", d.get("daily"), ["date"] + METRICS),
                 ("compare_pages", pr.get("comparePages"), ["page"] + COMPARE_FIELDS), ("compare_queries", pr.get("compareQueries"), ["query"] + COMPARE_FIELDS),
                 ("ranking", pr.get("ranking"), RANK_FIELDS)]
        for fname, rows, fields in files:
            if rows is None:
                continue
            if fname in ("pages", "queries", "page_queries"):
                rows = sorted(rows, key=lambda r: (-r["impressions"], -r["clicks"]))
            elif fname == "daily":
                rows = sorted(rows, key=lambda r: r["date"])
            path = out_dir / f"{name}_{fname}.csv"
            write_csv(path, rows, fields)
            written.append(path)
    summary = {k: v for k, v in report.items() if k != "periods"}
    summary["periods"] = {n: {k: v for k, v in pr.items() if k not in ("data", "previousData", "comparePages", "compareQueries", "ranking")} |
                          {"rankingTop10": (pr.get("ranking") or [])[:10]} for n, pr in report["periods"].items()}
    write_json(out_dir / "summary.json", summary, secrets)
    write_json(out_dir / "report.json", report, secrets)
    written += [out_dir / "summary.json", out_dir / "report.json"]
    md = [f"# Search Console 検索実績レポート({report['site']})", "", f"- 作成: {report['generatedAt']} / 確定済みデータ(final)・ウェブ検索",
          f"- API リクエスト: {report['apiRequests']} 回 / 取得エラー: {len(report['errors'])} 件 / 全件取得: {'はい' if report['complete'] else 'いいえ(注意を参照)'}", "", "## 注意"]
    md += [f"- {c}" for c in report["caveats"]]
    for e in report["errors"]:
        md.append(f"- 取得エラー: {e['period']} {e['dataset']}({e['range']}): {e['message']}")
    for name, pr in report["periods"].items():
        t = pr.get("totals") or {}
        md += ["", f"## {name}({pr['current'][0]}〜{pr['current'][1]}、前期間 {pr['previous'][0]}〜{pr['previous'][1]})",
               f"- 合計: クリック {t.get('clicks', 0):.0f} / 表示 {t.get('impressions', 0):.0f} / CTR {t.get('ctr', 0):.2%} / 平均順位 {t.get('position', 0):.1f}"]
        cv = pr.get("coverage") or {}
        if cv.get("query_impressions_share") is not None:
            md.append(f"- キーワード別に出ている割合: 表示回数の {cv['query_impressions_share']:.0%}(残りは匿名化された検索語句など)")
        if pr.get("truncated"):
            md.append("- **行数の上限で打ち切った集計がある(全件ではない)**")
        for c in (pr.get("ranking") or [])[:10]:
            md.append(f"  {c['rank']}. [{c['reliability']}] {c['page']} — {' / '.join(c['reasons'])} → {' / '.join(c['actions']) or '経過観察'}")
    md_text = "\n".join(md) + "\n"
    if contains_secret(md_text, secrets):
        raise ValueError("出力に秘密の値らしき文字列が含まれていたため保存しない")
    (out_dir / "summary.md").write_text(md_text, encoding="utf-8")
    written.append(out_dir / "summary.md")
    return written
