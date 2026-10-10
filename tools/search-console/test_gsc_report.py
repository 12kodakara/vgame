"""Search Console レポートのテスト(API・認証・ブラウザは使わない)。
  python tools\\search-console\\test_gsc_report.py
"""
from __future__ import annotations

import csv
import datetime as dt
import hashlib
import io
import json
import os
import re
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import gsc_lib as lib  # noqa: E402
import gsc_report  # noqa: E402

REPO = HERE.parent.parent
# 偽の秘密の値(本物と同じ形)。ソースに本物と同じ形の文字列を書くと秘密情報の検出ツールが反応するため、実行時に組み立てる
FAKE_SECRET = "GOC" + "SPX-" + "FAKEsecretValue1234567890"
FAKE_ACCESS = "ya" + "29." + "FAKEaccessTokenValue_abcdefghijkl"
FAKE_REFRESH = "1/" + "/0" + "FAKErefreshTokenValue_abcdefghijklmn"


def fake_api(rows_by_dims: dict, fail: dict | None = None, calls: list | None = None):
    """searchanalytics.query の真似。rows_by_dims[(dims, start)] = API 形式の行。rowLimit / startRow でページングする。"""
    def fn(body):
        if calls is not None:
            calls.append(dict(body))
        key = (tuple(body["dimensions"]), body["startDate"])
        if fail and key in fail:
            raise RuntimeError(fail[key])
        allrows = rows_by_dims.get(key, rows_by_dims.get((tuple(body["dimensions"]), "*"), []))
        s, n = body["startRow"], body["rowLimit"]
        page = allrows[s:s + n]
        return {"rows": page} if page else {}
    return fn


def r(keys, clicks, impr, pos):
    return {"keys": keys, "clicks": clicks, "impressions": impr, "ctr": (clicks / impr if impr else 0), "position": pos}


class TestCore(unittest.TestCase):
    def test_2_parse_and_ctr(self):
        row = lib.normalize_row({"keys": ["https://vgame-navi.jp/", "ぶいゲー"], "clicks": 3, "impressions": 40, "ctr": 0.999, "position": 2.5}, ["page", "query"])
        self.assertEqual(row["page"], "https://vgame-navi.jp/")
        self.assertEqual(row["query"], "ぶいゲー")
        self.assertAlmostEqual(row["ctr"], 3 / 40)   # API の ctr ではなく計算し直す
        self.assertEqual(lib.normalize_row({"keys": ["x"]}, ["page"])["impressions"], 0.0)

    def test_3_empty(self):
        ds = lib.fetch_dataset(fake_api({}), "2026-10-01", "2026-10-07", ["page"])
        self.assertEqual(ds["rows"], [])
        self.assertFalse(ds["truncated"])
        self.assertEqual(lib.aggregate([]), {"clicks": 0.0, "impressions": 0.0, "ctr": 0.0, "position": 0.0})
        self.assertIsNone(lib.coverage([], [])["query_impressions_share"])

    def test_4_paging_and_truncation(self):
        rows = [r([f"q{i}"], 1, 10, 5) for i in range(7)]
        calls = []
        ds = lib.fetch_dataset(fake_api({(("query",), "2026-10-01"): rows}, calls=calls), "2026-10-01", "2026-10-07", ["query"], row_limit=3)
        self.assertEqual([x["query"] for x in ds["rows"]], [f"q{i}" for i in range(7)])   # 重複・欠けなし
        self.assertEqual([c["startRow"] for c in calls], [0, 3, 6])
        self.assertEqual(ds["requests"], 3)
        self.assertFalse(ds["truncated"])
        calls.clear()
        ds = lib.fetch_dataset(fake_api({(("query",), "2026-10-01"): rows}, calls=calls), "2026-10-01", "2026-10-07", ["query"], row_limit=3, max_rows=5)
        self.assertEqual(len(ds["rows"]), 5)
        self.assertTrue(ds["truncated"])                                                 # 上限で打ち切ったことを記録
        self.assertEqual([c["rowLimit"] for c in calls], [3, 2])
        exact = lib.fetch_dataset(fake_api({(("query",), "2026-10-01"): rows[:6]}), "2026-10-01", "2026-10-07", ["query"], row_limit=3)
        self.assertEqual(len(exact["rows"]), 6)                                          # ちょうど割り切れる行数でも止まる
        self.assertTrue(all(c["dataState"] == "final" and c["type"] == "web" for c in calls))

    def test_5_dates(self):
        now = dt.datetime(2026, 10, 9, 16, 0, tzinfo=dt.timezone.utc)                   # 日本時間 10/10 01:00
        self.assertEqual(lib.today_jst(now), dt.date(2026, 10, 10))
        self.assertEqual(lib.default_end(now, 3), dt.date(2026, 10, 7))
        self.assertEqual(lib.today_jst(dt.datetime(2026, 10, 9, 14, 59, tzinfo=dt.timezone.utc)), dt.date(2026, 10, 9))
        ps = {p["name"]: p for p in lib.build_periods(dt.date(2026, 10, 6))}
        self.assertEqual(ps["7d"]["current"], ("2026-09-30", "2026-10-06"))
        self.assertEqual(ps["7d"]["previous"], ("2026-09-23", "2026-09-29"))
        self.assertEqual(ps["28d"]["current"], ("2026-09-09", "2026-10-06"))
        self.assertEqual(ps["28d"]["previous"], ("2026-08-12", "2026-09-08"))
        self.assertEqual(ps["90d"]["current"], ("2026-07-09", "2026-10-06"))
        self.assertEqual(ps["90d"]["previous"], ("2026-04-10", "2026-07-08"))
        with self.assertRaises(ValueError):
            lib.today_jst(dt.datetime(2026, 10, 9))                                     # タイムゾーンなしは受け付けない

    def test_7_aggregate_weighted(self):
        rows = [lib.normalize_row(r(["a"], 10, 100, 2.0), ["page"]), lib.normalize_row(r(["b"], 0, 300, 10.0), ["page"])]
        a = lib.aggregate(rows)
        self.assertEqual((a["clicks"], a["impressions"]), (10.0, 400.0))
        self.assertAlmostEqual(a["ctr"], 10 / 400)
        self.assertAlmostEqual(a["position"], (2 * 100 + 10 * 300) / 400)            # 表示回数で重み付け
        cmp = {x["page"]: x for x in lib.compare([rows[0]], [lib.normalize_row(r(["a"], 5, 50, 4.0), ["page"]), rows[1]], ["page"])}
        self.assertEqual(cmp["a"]["status"], "both")
        self.assertAlmostEqual(cmp["a"]["clicks_change"], 1.0)
        self.assertAlmostEqual(cmp["a"]["position_improvement"], 2.0)                 # 4位 → 2位 は改善
        self.assertEqual(cmp["b"]["status"], "lost")
        self.assertIsNone(cmp["b"]["position_improvement"])

    def test_ranking_rules(self):
        cur = [lib.normalize_row(x, ["page"]) for x in [r(["/low-ctr"], 2, 1000, 3.0), r(["/page2"], 1, 500, 14.0), r(["/good"], 120, 1000, 2.0),
                                                        r(["/tiny"], 0, 20, 3.0), r(["/drop"], 5, 150, 6.0)]]
        prev = [lib.normalize_row(x, ["page"]) for x in [r(["/low-ctr"], 3, 900, 3.2), r(["/page2"], 1, 450, 15.0), r(["/good"], 110, 950, 2.1),
                                                         r(["/tiny"], 0, 18, 3.0), r(["/drop"], 30, 600, 4.0), r(["/gone"], 10, 300, 5.0)]]
        pq = [lib.normalize_row(r(["/low-ctr", "クエリA"], 1, 600, 3.0), ["page", "query"])]
        ranking = lib.rank_candidates(lib.compare(cur, prev, ["page"]), pq, 28)
        pages = [x["page"] for x in ranking]
        self.assertNotIn("/good", pages)                                                 # CTR が目安以上・変化なしは候補にしない
        self.assertIn("/low-ctr", pages)
        self.assertIn("/page2", pages)
        self.assertIn("/gone", pages)
        tiny = [x for x in ranking if x["page"] == "/tiny"]
        self.assertTrue(not tiny or tiny[0]["reliability"] == "参考値(データ少)")      # データが少ないものは参考値
        normal = [x for x in ranking if x["reliability"] == "通常"]
        self.assertEqual(ranking[:len(normal)], normal)                                  # 参考値は通常の後ろ
        low = [x for x in ranking if x["page"] == "/low-ctr"][0]
        self.assertEqual(low["top_queries"][0]["query"], "クエリA")
        self.assertTrue(any("title" in a for a in low["actions"]))
        drop = [x for x in ranking if x["page"] == "/drop"][0]
        self.assertTrue(any("前期間比" in s for s in drop["reasons"]) and drop["lost_clicks"] == 25)
        self.assertEqual([x["rank"] for x in ranking], list(range(1, len(ranking) + 1)))

    def test_8_redact(self):
        s = lib.redact(f'error key={FAKE_SECRET} "access_token": "{FAKE_ACCESS}" refresh {FAKE_REFRESH} https://x/?key=AIzaFAKE&y=1', [])
        for v in (FAKE_SECRET, FAKE_ACCESS, FAKE_REFRESH, "AIzaFAKE"):
            self.assertNotIn(v, s)
        self.assertTrue(lib.contains_secret(f"x {FAKE_ACCESS}"))
        self.assertFalse(lib.contains_secret("検索語句 token の使い方 / https://vgame-navi.jp/game.html?game=key"))   # 通常の語句は止めない


class TestCli(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.seo = Path(self.tmp.name) / "vgame-seo"
        self.seo.mkdir()
        self.old = os.environ.get("VGAME_SEO_DIR")
        os.environ["VGAME_SEO_DIR"] = str(self.seo)
        self.now = dt.datetime(2026, 10, 9, 3, 0, tzinfo=dt.timezone.utc)

    def tearDown(self):
        if self.old is None:
            os.environ.pop("VGAME_SEO_DIR", None)
        else:
            os.environ["VGAME_SEO_DIR"] = self.old
        self.tmp.cleanup()

    def run_main(self, argv):
        lines = []
        code = gsc_report.main(argv, out=lines.append, now=self.now)
        return code, "\n".join(lines)

    def write_mock(self, spec):
        p = Path(self.tmp.name) / "mock.json"
        p.write_text(json.dumps(spec, ensure_ascii=False), encoding="utf-8")
        return str(p)

    def test_1_no_credentials(self):
        code, text = self.run_main([])
        self.assertEqual(code, 2)
        self.assertIn("OAuth クライアント情報のファイルがありません", text)
        (self.seo / "oauth-client.json").write_text(json.dumps({"web": {"client_id": "x", "client_secret": FAKE_SECRET}}), encoding="utf-8")
        code, text = self.run_main([])
        self.assertEqual(code, 2)
        self.assertIn("デスクトップアプリ用", text)
        self.assertNotIn(FAKE_SECRET, text)
        (self.seo / "oauth-client.json").write_text(json.dumps({"installed": {"client_id": "x", "client_secret": FAKE_SECRET}}), encoding="utf-8")
        code, text = self.run_main([])
        self.assertEqual(code, 2)                                                       # ライブラリなし → 案内 / ありでトークンなし → 認証の案内
        self.assertTrue("pip install" in text or "--auth" in text, text)
        self.assertNotIn(FAKE_SECRET, text)

    def test_6_output_and_9_api_error(self):
        pages = [r(["https://vgame-navi.jp/"], 50, 2000, 4.0), r(["https://vgame-navi.jp/game.html?game=a"], 1, 900, 8.0)]
        spec = {"responses": [
            {"match": {"dimensions": [], "startDate": "2026-09-30"}, "response": {"rows": [r([], 60, 3200, 5.0)]}},
            {"match": {"dimensions": ["page"], "startDate": "2026-09-30"}, "response": {"rows": pages}},
            {"match": {"dimensions": ["page"], "startDate": "2026-09-23"}, "response": {"rows": [r(["https://vgame-navi.jp/"], 40, 1800, 4.5)]}},
            {"match": {"dimensions": ["query"], "startDate": "2026-09-30"}, "response": {"rows": [r(["ぶいゲー"], 30, 1200, 3.0)]}},
            {"match": {"dimensions": ["page", "query"], "startDate": "2026-09-30"}, "error": f"HttpError 500 when requesting https://x/?key={FAKE_SECRET} {FAKE_ACCESS}"},
        ], "default": {}}
        out_dir = Path(self.tmp.name) / "out"
        code, text = self.run_main(["--mock", self.write_mock(spec), "--periods", "7", "--out-dir", str(out_dir)])
        self.assertEqual(code, 3)                                                       # 一部の取得に失敗 → 3。取れた分は保存
        files = {p.name for p in out_dir.iterdir()}
        for f in ("7d_pages.csv", "7d_queries.csv", "7d_daily.csv", "7d_compare_pages.csv", "7d_compare_queries.csv", "7d_ranking.csv", "summary.json", "report.json", "summary.md"):
            self.assertIn(f, files)
        self.assertNotIn("7d_page_queries.csv", files)                                  # 失敗した集計は出さない
        raw = (out_dir / "7d_pages.csv").read_bytes()
        self.assertTrue(raw.startswith(b"\xef\xbb\xbf"))                                 # Excel 用の BOM
        rows = list(csv.DictReader(io.StringIO(raw.decode("utf-8-sig"))))
        self.assertEqual([x["page"] for x in rows], ["https://vgame-navi.jp/", "https://vgame-navi.jp/game.html?game=a"])
        self.assertAlmostEqual(float(rows[0]["ctr"]), 50 / 2000)
        summary = json.loads((out_dir / "summary.json").read_text(encoding="utf-8"))
        self.assertFalse(summary["complete"])
        self.assertEqual(summary["errors"][0]["dataset"], "page_queries")
        self.assertAlmostEqual(summary["periods"]["7d"]["coverage"]["query_impressions_share"], 1200 / 3200)
        self.assertTrue(summary["caveats"])
        alltext = text + "".join(p.read_text(encoding="utf-8-sig") for p in out_dir.iterdir())
        for v in (FAKE_SECRET, FAKE_ACCESS):
            self.assertNotIn(v, alltext)                                                # エラー文の秘密の値は伏せる
        md = (out_dir / "summary.md").read_text(encoding="utf-8")
        self.assertIn("匿名化", md)

    def test_3b_empty_cli(self):
        out_dir = Path(self.tmp.name) / "empty"
        code, text = self.run_main(["--mock", self.write_mock({"default": {}}), "--out-dir", str(out_dir)])
        self.assertEqual(code, 0)
        s = json.loads((out_dir / "summary.json").read_text(encoding="utf-8"))
        self.assertEqual(sorted(s["periods"]), ["28d", "7d", "90d"])
        self.assertEqual(s["periods"]["28d"]["totals"]["impressions"], 0.0)
        with open(out_dir / "28d_ranking.csv", encoding="utf-8-sig") as f:
            self.assertEqual(len(list(csv.reader(f))), 1)                                # 見出しだけ
        self.assertEqual(s["apiRequests"], 3 * 8)                                        # 期間3つ × (今期間5集計 + 前期間3集計)

    def test_8b_secrets_not_in_output_with_files(self):
        (self.seo / "oauth-client.json").write_text(json.dumps({"installed": {"client_id": "x", "client_secret": FAKE_SECRET}}), encoding="utf-8")
        (self.seo / "token.json").write_text(json.dumps({"token": FAKE_ACCESS, "refresh_token": FAKE_REFRESH}), encoding="utf-8")
        import gsc_auth
        sec = gsc_auth.secrets_in_files(self.seo / "oauth-client.json", self.seo / "token.json")
        self.assertEqual(sorted(sec), sorted([FAKE_SECRET, FAKE_ACCESS, FAKE_REFRESH]))
        buf = io.StringIO()
        with redirect_stdout(buf):
            code, text = self.run_main([])
        self.assertEqual(code, 2)
        for v in (FAKE_SECRET, FAKE_ACCESS, FAKE_REFRESH):
            self.assertNotIn(v, text + buf.getvalue())

    def test_10_no_site_impact(self):
        out_in_repo = REPO / "reports" / "gsc-test"
        code, text = self.run_main(["--mock", self.write_mock({"default": {}}), "--out-dir", str(out_in_repo)])
        self.assertEqual(code, 2)                                                       # リポジトリの中には保存しない
        self.assertFalse(out_in_repo.exists())
        os.environ["VGAME_SEO_DIR"] = str(REPO / "tmp-seo")
        code, text = self.run_main(["--mock", self.write_mock({"default": {}})])
        self.assertEqual(code, 2)
        self.assertFalse((REPO / "tmp-seo").exists())
        build = (REPO / "build-public.ps1").read_text(encoding="utf-8-sig")
        self.assertNotIn("tools", build)                                                 # 公開用ビルドの対象に入らない
        ignored = subprocess.run(["git", "check-ignore", "-q", "tools/search-console/__pycache__/gsc_lib.cpython-312.pyc"], cwd=REPO).returncode
        self.assertEqual(ignored, 0)                                                     # Python の一時ファイルは git 管理外


class TestNoDataChange(unittest.TestCase):
    FILES = ["data-standalone.js", "data-playlists.js", "data-core.js", "data-home.js", "data-series.js", "sitemap.xml", "robots.txt"]

    def test_10b_data_unchanged(self):
        before = {f: hashlib.sha256((REPO / f).read_bytes()).hexdigest() for f in self.FILES}
        with tempfile.TemporaryDirectory() as t:
            old = os.environ.get("VGAME_SEO_DIR")
            os.environ["VGAME_SEO_DIR"] = t
            try:
                spec = Path(t) / "m.json"
                spec.write_text("{}", encoding="utf-8")
                self.assertEqual(gsc_report.main(["--mock", str(spec)], out=lambda *_: None), 0)
            finally:
                if old is None:
                    os.environ.pop("VGAME_SEO_DIR", None)
                else:
                    os.environ["VGAME_SEO_DIR"] = old
        after = {f: hashlib.sha256((REPO / f).read_bytes()).hexdigest() for f in self.FILES}
        self.assertEqual(before, after)


class TestAdc(unittest.TestCase):
    """GitHub Actions(Workload Identity 連携)用の --auth-mode adc。認証・通信は置き換える。"""
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.seo = Path(self.tmp.name) / "vgame-seo"
        self.seo.mkdir()
        self.old = os.environ.get("VGAME_SEO_DIR")
        os.environ["VGAME_SEO_DIR"] = str(self.seo)
        import gsc_auth
        self.auth = gsc_auth
        self.orig = (gsc_auth.load_adc_credentials, gsc_auth.build_query_fn)

    def tearDown(self):
        self.auth.load_adc_credentials, self.auth.build_query_fn = self.orig
        if self.old is None:
            os.environ.pop("VGAME_SEO_DIR", None)
        else:
            os.environ["VGAME_SEO_DIR"] = self.old
        self.tmp.cleanup()

    def run_main(self, argv):
        lines = []
        code = gsc_report.main(argv, out=lines.append, now=dt.datetime(2026, 10, 12, 0, 5, tzinfo=dt.timezone.utc))
        return code, "\n".join(lines)

    def test_adc_success_without_oauth_files(self):
        seen = {}
        self.auth.load_adc_credentials = lambda: "CREDS"
        self.auth.build_query_fn = lambda creds, site: (seen.update(creds=creds, site=site), fake_api({(("page",), "*"): [r(["https://vgame-navi.jp/"], 1, 10, 3.0)]}))[1]
        out_dir = Path(self.tmp.name) / "report"
        code, text = self.run_main(["--auth-mode", "adc", "--out-dir", str(out_dir)])
        self.assertEqual(code, 0, text)
        self.assertEqual(seen, {"creds": "CREDS", "site": "sc-domain:vgame-navi.jp"})
        self.assertTrue((out_dir / "summary.json").exists())
        self.assertEqual(sorted(p.name for p in self.seo.iterdir()), [])                 # OAuth クライアント情報・トークンは使わず作らない
        self.assertIn("2026-10-09", text)                                                # 月曜 9:05(日本時間)実行 → 最終日は3日前

    def test_adc_missing_credentials(self):
        class DefaultCredentialsError(Exception):
            pass

        def boom(scopes=None):
            raise DefaultCredentialsError(f"File {FAKE_ACCESS} was not found")
        with self.assertRaises(self.auth.AuthError) as cm:
            self.auth.load_adc_credentials(default_fn=boom)
        msg = str(cm.exception)
        self.assertIn("Workload Identity", msg)
        self.assertNotIn(FAKE_ACCESS, msg)                                               # 例外の中身(パス・値)は出さない
        got = {}
        self.assertEqual(self.auth.load_adc_credentials(default_fn=lambda scopes=None: (got.setdefault("scopes", scopes), ("CREDS", "proj"))[1]), "CREDS")
        self.assertEqual(got["scopes"], lib.SCOPES)                                      # 読み取り専用スコープだけを要求
        self.auth.load_adc_credentials = lambda: (_ for _ in ()).throw(self.auth.AuthError("Workload Identity 連携の認証情報が見つかりません"))
        code, text = self.run_main(["--auth-mode", "adc", "--out-dir", str(Path(self.tmp.name) / "x")])
        self.assertEqual(code, 2)
        self.assertIn("Workload Identity", text)

    def test_adc_rejects_browser_auth(self):
        self.auth.load_adc_credentials = lambda: self.fail("呼ばれてはいけない")
        code, text = self.run_main(["--auth-mode", "adc", "--auth"])
        self.assertEqual(code, 2)
        self.assertIn("--auth はローカルの OAuth 認証用", text)


class TestWorkflow(unittest.TestCase):
    """.github/workflows/search-console-weekly.yml の安全条件(静的な確認)。"""
    PATH = REPO / ".github" / "workflows" / "search-console-weekly.yml"

    def setUp(self):
        self.y = self.PATH.read_text(encoding="utf-8")

    def test_permissions_minimal(self):
        block = re.search(r"^permissions:\n((?:  .*\n)+)", self.y, re.M).group(1)
        keys = sorted(re.findall(r"^  ([a-z-]+):\s*(\S+)", block, re.M))
        self.assertEqual(keys, [("contents", "read"), ("id-token", "write")])
        self.assertNotRegex(self.y, r"(?m)^[ \t]+permissions:")                        # ジョブ単位で権限を足していない

    def test_auth_wif_only(self):
        self.assertIn("uses: google-github-actions/auth@v", self.y)
        self.assertIn("workload_identity_provider: projects/478334341544/locations/global/workloadIdentityPools/vgame-github-actions/providers/github-actions", self.y)
        self.assertIn("service_account: vgame-search-console-reader@vgame-search-console.iam.gserviceaccount.com", self.y)
        self.assertNotIn("credentials_json", self.y)                                     # JSON の秘密鍵は使わない
        self.assertNotRegex(self.y, r"\$\{\{\s*secrets\.")                              # Secrets も使わない
        self.assertIn("persist-credentials: false", self.y)

    def test_schedule_and_artifacts(self):
        self.assertIn('cron: "0 0 * * 1"', self.y)                                       # 月曜 00:00 UTC = 日本時間 9:00
        self.assertIn("workflow_dispatch:", self.y)
        self.assertIn("retention-days: 30", self.y)
        self.assertIn("--auth-mode adc", self.y)
        self.assertIn("if: github.repository == '12kodakara/vgame'", self.y)            # フォーク先では動かさない
        self.assertNotRegex(self.y, r"git (commit|push)|gh-pages|actions/deploy-pages")  # リポジトリ・公開サイトに保存しない

    def test_age_encryption(self):
        steps = re.split(r"(?m)^      - name: ", self.y)[1:]
        names = [s.split("\n", 1)[0] for s in steps]
        step = lambda key: next(s for s in steps if s.startswith(key))
        # アップロードするのは暗号化済みのフォルダだけ(平文のレポートのフォルダは指定しない)
        uploads = [s for s in steps if "actions/upload-artifact@" in s]
        self.assertEqual(len(uploads), 1)
        self.assertIn("path: ${{ runner.temp }}/gsc-upload", uploads[0])
        self.assertNotIn("gsc-report", uploads[0].replace("search-console-report-", ""))
        self.assertIn("if: always() && steps.verify.outcome == 'success'", uploads[0])
        # 公開鍵は Actions Variables から読む。秘密鍵(-i / identity)は使わない
        self.assertIn("${{ vars.GSC_AGE_RECIPIENT }}", self.y)
        self.assertRegex(step("age で暗号化"), r'age -r "\$GSC_AGE_RECIPIENT" -o ')
        self.assertNotRegex(self.y, r"age (-d|--decrypt)|age-keygen|AGE-SECRET-KEY| -i ")
        # 公開鍵の確認は取得より前、暗号化は認証ファイルの確認のあと、確認はアップロードの前
        order = lambda key: next(i for i, n in enumerate(names) if n.startswith(key))
        self.assertLess(order("暗号化用の公開鍵を確認"), order("Search Console から取得"))
        self.assertLess(order("認証ファイルがレポートに入っていない"), order("age で暗号化"))
        self.assertLess(order("age で暗号化"), order("平文のレポートを削除"))
        self.assertLess(order("平文のレポートを削除"), order("Artifacts に保存"))
        self.assertIn("if: always() && steps.credcheck.outcome == 'success'", step("age で暗号化"))
        self.assertIn("if: always()", step("平文のレポートを削除"))
        self.assertIn("age-encryption.org/v1", step("アップロードするのが暗号化済みファイルだけか確認"))
        self.assertIn("! -name '*.tar.gz.age'", step("アップロードするのが暗号化済みファイルだけか確認"))
        # ログに出すのは件数だけ(要約で検索語句・URL・数値を書かない)
        summary = step("結果の要約")
        self.assertNotRegex(summary, r"query|page|clicks|impressions|rankingTop")
        self.assertNotRegex(self.y, r"(?m)^\s*(cat|type) .*gsc-report|set -x")

    def test_recipient_format_check(self):
        # 公開鍵の形の確認(bech32 の文字だけ・age1 + 58文字)は、登録済みの形を通し、壊れた値は通さない
        pat = re.search(r"grep -Eq '(\^age1[^']+)'", self.y).group(1)
        ok = "age1" + "qpzry9x8gf2tvdw0s3jn54khce6mua7lqpzry9x8gf2tvdw0s3jn54khce"
        self.assertEqual(len(ok), 62)
        self.assertRegex(ok, pat)
        for bad in ("", "age1short", ok.upper(), "AGE-SECRET-KEY-1" + "Q" * 58, ok[:-1] + "b"):
            self.assertNotRegex(bad, pat)

    def test_other_workflows_unchanged(self):
        for f in ("home-data.yml", "refresh-playlist-meta.yml"):
            rc = subprocess.run(["git", "diff", "--quiet", "HEAD", "--", f".github/workflows/{f}"], cwd=REPO).returncode
            self.assertEqual(rc, 0, f)


if __name__ == "__main__":
    unittest.main(verbosity=2)
