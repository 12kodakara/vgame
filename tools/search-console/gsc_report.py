"""ぶいゲー Search Console 検索実績レポート(ローカル実行・読み取り専用)。

使い方(リポジトリのフォルダで実行):
  python -m pip install -r tools\\search-console\\requirements.txt   … 初回だけ(Google 公式ライブラリ)
  python tools\\search-console\\gsc_report.py --auth                  … 初回だけ。ブラウザで Google アカウントを認証してトークンを保存
  python tools\\search-console\\gsc_report.py                         … 直近7日・28日・90日(と前期間)を取得してレポートを作る
  python tools\\search-console\\gsc_report.py --mock fixtures.json    … 固定データで動作確認(API・認証を使わない)
  python tools/search-console/gsc_report.py --auth-mode adc --out-dir <フォルダ>
                                                                 … GitHub Actions(Workload Identity 連携)。.github/workflows/search-console-weekly.yml から実行

保存先: %LOCALAPPDATA%\\vgame-seo\\reports\\<作成日時>\\(リポジトリの外。サイトのデータ・ビルドには影響しない)
  <期間>_pages.csv / _queries.csv / _page_queries.csv / _daily.csv / _compare_pages.csv / _compare_queries.csv / _ranking.csv、
  summary.json / report.json / summary.md
終了コード: 0 = 成功 / 2 = 認証・設定の問題 / 3 = 一部の取得に失敗(取れた分は保存)
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import gsc_lib as lib  # noqa: E402

REPO_ROOT = HERE.parent.parent


def parse_args(argv=None):
    ap = argparse.ArgumentParser(description="ぶいゲー Search Console 検索実績レポート(読み取り専用)")
    ap.add_argument("--auth", action="store_true", help="ブラウザで Google アカウントを認証してトークンを保存する(初回・トークン失効時。--auth-mode oauth のときだけ)")
    ap.add_argument("--auth-mode", choices=["oauth", "adc"], default="oauth",
                    help="oauth = ローカルのデスクトップアプリ用 OAuth(既定)/ adc = GitHub Actions の Workload Identity 連携(google-github-actions/auth の後に実行)")
    ap.add_argument("--site", default=lib.DEFAULT_SITE, help=f"Search Console のプロパティ(既定: {lib.DEFAULT_SITE})")
    ap.add_argument("--periods", default=",".join(str(p) for p in lib.DEFAULT_PERIODS), help="期間の日数(カンマ区切り。既定: 7,28,90)")
    ap.add_argument("--end", help="最終日(YYYY-MM-DD・日本時間)。省略時は今日から --lag-days を引いた日")
    ap.add_argument("--lag-days", type=int, default=lib.DEFAULT_LAG_DAYS, help="確定済みデータになるまでの日数(既定: 3)")
    ap.add_argument("--max-rows", type=int, default=lib.DEFAULT_MAX_ROWS, help="1つの集計で取得する最大行数(既定: 100000)")
    ap.add_argument("--out-dir", help="保存先フォルダ(既定: %%LOCALAPPDATA%%\\vgame-seo\\reports\\<作成日時>)")
    ap.add_argument("--mock", help="API の代わりに使う固定データ(JSON)。認証・通信をしない")
    return ap.parse_args(argv)


def mock_query_fn(path: Path):
    """固定データ: {"responses": [{"match": {"dimensions": [...], "startDate": "...", "startRow": 0}, "response": {...}}, ...], "default": {...}}"""
    spec = json.loads(Path(path).read_text(encoding="utf-8"))

    def fn(body):
        for r in spec.get("responses", []):
            m = r.get("match", {})
            if all(body.get(k) == v for k, v in m.items()):
                if r.get("error"):
                    raise RuntimeError(r["error"])
                return r.get("response", {})
        return spec.get("default", {"rows": []})
    return fn


def main(argv=None, out=print, now: dt.datetime | None = None) -> int:
    a = parse_args(argv)
    p = lib.paths()
    secrets: list[str] = []
    try:
        for k in ("dir", "reports"):
            lib.ensure_outside_repo(p[k], REPO_ROOT)
        if a.mock:
            query_fn = mock_query_fn(Path(a.mock))
        elif a.auth_mode == "adc":
            # GitHub Actions: OAuth クライアント情報・トークンは使わない(Workload Identity 連携の短期の認証情報だけ)
            import gsc_auth as auth
            if a.auth:
                raise ValueError("--auth はローカルの OAuth 認証用です(--auth-mode adc では使えません)")
            creds = auth.load_adc_credentials()
            query_fn = auth.build_query_fn(creds, a.site)
        else:
            import gsc_auth as auth
            secrets = auth.secrets_in_files(p["client"], p["token"])
            if a.auth:
                auth.load_credentials(p["client"], p["token"], allow_browser=True)
                out(f"認証が完了し、トークンを保存しました(保存先: {p['token']}。内容は表示しません)")
                return 0
            creds = auth.load_credentials(p["client"], p["token"], allow_browser=False)
            secrets = auth.secrets_in_files(p["client"], p["token"])
            query_fn = auth.build_query_fn(creds, a.site)
        lengths = [int(x) for x in a.periods.split(",") if x.strip()]
        end = dt.date.fromisoformat(a.end) if a.end else lib.default_end(now, a.lag_days)
        periods = lib.build_periods(end, lengths)
        out_dir = Path(a.out_dir) if a.out_dir else p["reports"] / (now or dt.datetime.now(dt.timezone.utc)).astimezone(lib.JST).strftime("%Y%m%d-%H%M%S")
        lib.ensure_outside_repo(out_dir, REPO_ROOT)
    except Exception as e:  # noqa: BLE001 - 認証・設定の問題は伏せ字にして終了コード2
        out("エラー: " + lib.redact(str(e), secrets))
        return 2

    out(f"取得: {a.site} / 最終日 {end.isoformat()}(日本時間・確定済みデータ) / 期間 {', '.join(x['name'] for x in periods)}")
    report = lib.build_report(query_fn, a.site, periods, max_rows=a.max_rows, secrets=secrets, generated_at=now)
    files = lib.write_report(report, out_dir, secrets)
    out(f"保存: {out_dir}({len(files)} ファイル) / API リクエスト {report['apiRequests']} 回 / 取得エラー {len(report['errors'])} 件")
    for e in report["errors"]:
        out(f"  取得エラー: {e['period']} {e['dataset']}({e['range']}): {e['message']}")
    if not report["complete"]:
        out("  注意: 全件ではない集計があります(summary.md の「注意」を参照)")
    return 3 if report["errors"] else 0


if __name__ == "__main__":
    sys.exit(main())
