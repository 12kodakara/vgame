"""Search Console API の認証(デスクトップアプリ用 OAuth 2.0・読み取り専用スコープ)。

- クライアント情報: %LOCALAPPDATA%\\vgame-seo\\oauth-client.json(リポジトリには置かない)
- トークン       : %LOCALAPPDATA%\\vgame-seo\\token.json(初回のブラウザ認証のあとに保存。表示・ログ出力はしない)
- ブラウザ認証は gsc_report.py --auth を人が実行したときだけ行う(自動では行わない)
- OAuth アプリが「テスト中」の間は、更新トークンが発行から7日ほどで無効になる。
  無効になったら --auth で認証し直す(自動でブラウザは開かない)

Google のライブラリは、実際に認証・API を使うときだけ読み込む(モックのテストではライブラリ不要)。
"""
from __future__ import annotations

import json
from pathlib import Path

from gsc_lib import SCOPES, redact

INSTALL_HINT = "必要なライブラリがありません。次を実行してください: python -m pip install -r tools\\search-console\\requirements.txt"


class AuthError(Exception):
    """認証の失敗(メッセージに秘密の値は含めない)。"""


def secrets_in_files(client_path: Path, token_path: Path) -> list[str]:
    """伏せ字にする値(クライアントシークレット・トークン)。値は返すだけで表示しない。"""
    out = []
    for p, keys in ((client_path, ("client_secret",)), (token_path, ("token", "refresh_token", "client_secret"))):
        try:
            data = json.loads(Path(p).read_text(encoding="utf-8"))
        except Exception:  # noqa: BLE001 - 無い・壊れている場合は伏せる値なし
            continue
        for section in (data, data.get("installed") or {}, data.get("web") or {}):
            for k in keys:
                v = section.get(k) if isinstance(section, dict) else None
                if isinstance(v, str) and v:
                    out.append(v)
    return out


def check_client_file(client_path: Path) -> None:
    if not client_path.exists():
        raise AuthError(f"OAuth クライアント情報のファイルがありません: {client_path}(Google Cloud でデスクトップアプリ用の OAuth クライアントを作成し、この場所に保存してください)")
    try:
        data = json.loads(client_path.read_text(encoding="utf-8"))
    except Exception:  # noqa: BLE001
        raise AuthError(f"OAuth クライアント情報のファイルを JSON として読めません: {client_path}") from None
    if "installed" not in data:
        raise AuthError("OAuth クライアント情報がデスクトップアプリ用(installed)ではありません。デスクトップアプリとして作成し直してください")


def _save_token(creds, token_path: Path) -> None:
    token_path.parent.mkdir(parents=True, exist_ok=True)
    tmp = token_path.with_suffix(".tmp")
    tmp.write_text(creds.to_json(), encoding="utf-8")   # 内容は表示しない
    tmp.replace(token_path)


def load_credentials(client_path: Path, token_path: Path, allow_browser: bool = False):
    """保存済みのトークンを読み、必要なら更新する。allow_browser=True のときだけブラウザ認証を行う。"""
    check_client_file(client_path)
    secrets = secrets_in_files(client_path, token_path)
    try:
        from google.auth.exceptions import RefreshError
        from google.auth.transport.requests import Request
        from google.oauth2.credentials import Credentials
        from google_auth_oauthlib.flow import InstalledAppFlow
    except ImportError:
        raise AuthError(INSTALL_HINT) from None

    creds = None
    if token_path.exists() and not allow_browser:
        try:
            creds = Credentials.from_authorized_user_file(str(token_path), SCOPES)
        except Exception as e:  # noqa: BLE001
            raise AuthError(redact(f"保存済みトークンを読めません(--auth で認証し直してください): {type(e).__name__}", secrets)) from None
        if set(creds.scopes or []) - set(SCOPES):
            raise AuthError("保存済みトークンに読み取り専用以外の権限が含まれています。--auth で認証し直してください")
        if not creds.valid:
            if creds.expired and creds.refresh_token:
                try:
                    creds.refresh(Request())
                except RefreshError:
                    raise AuthError("更新トークンが無効です(OAuth アプリが「テスト中」の間は発行から約7日で無効になります)。"
                                    "python tools\\search-console\\gsc_report.py --auth で認証し直してください") from None
                _save_token(creds, token_path)
            else:
                raise AuthError("保存済みトークンが使えません。--auth で認証し直してください")
        return creds

    if not allow_browser:
        raise AuthError("まだ認証していません。最初に python tools\\search-console\\gsc_report.py --auth を実行し、ブラウザで Google アカウントを認証してください")

    flow = InstalledAppFlow.from_client_secrets_file(str(client_path), SCOPES)
    creds = flow.run_local_server(port=0, open_browser=True,
                                  authorization_prompt_message="ブラウザで Google アカウントの認証画面を開きます(開かない場合は次の URL を開いてください): {url}",
                                  success_message="認証が完了しました。このタブを閉じて、ターミナルに戻ってください。")
    if set(creds.scopes or SCOPES) - set(SCOPES):
        raise AuthError("読み取り専用以外の権限が付与されたため保存しません")
    _save_token(creds, token_path)
    return creds


def build_query_fn(creds, site: str):
    """searchanalytics.query を呼ぶ関数(gsc_lib.fetch_dataset に渡す)。"""
    try:
        from googleapiclient.discovery import build
    except ImportError:
        raise AuthError(INSTALL_HINT) from None
    service = build("searchconsole", "v1", credentials=creds, cache_discovery=False)
    return lambda body: service.searchanalytics().query(siteUrl=site, body=body).execute(num_retries=0)
