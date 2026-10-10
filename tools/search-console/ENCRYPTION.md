# Search Console 週次レポートの暗号化と復号(age)

`.github/workflows/search-console-weekly.yml` は、毎週月曜 9:00(日本時間)ごろに Search Console のデータを取得し、
**age の公開鍵で暗号化したファイルだけ**を GitHub Actions の Artifacts に30日間保存します。
リポジトリは公開されているため、Artifacts は GitHub にログインした誰でもダウンロードできますが、
復号できるのは自宅PCの秘密鍵を持っている人だけです。

| もの | 置き場所 | 公開してよいか |
|---|---|---|
| 公開鍵(`age1...`) | GitHub の Actions Variables `GSC_AGE_RECIPIENT` | よい(暗号化にしか使えない) |
| 秘密鍵(`AGE-SECRET-KEY-...`) | 自宅PCの `%LOCALAPPDATA%\vgame-seo\age\vgame-gsc.key` だけ | **だめ**(GitHub・リポジトリ・Secrets・クラウドに置かない) |

## 1. 鍵ペアの作り方(初回だけ・自宅PC)

```powershell
winget install --id FiloSottile.age -e
$dir = "$env:LOCALAPPDATA\vgame-seo\age"
New-Item -ItemType Directory -Force $dir | Out-Null
icacls $dir /inheritance:r /grant:r "${env:USERNAME}:(OI)(CI)F"   # 自分だけが読めるようにする
age-keygen -o "$dir\vgame-gsc.key"                                # 画面に出るのは公開鍵だけ
```

画面の `Public key: age1...` を、リポジトリの Settings → Secrets and variables → Actions → **Variables** に
`GSC_AGE_RECIPIENT` として登録します(Secrets ではなく Variables)。

公開鍵と秘密鍵が対応しているかは、次で確認できます(出るのは公開鍵だけ):

```powershell
age-keygen -y "$env:LOCALAPPDATA\vgame-seo\age\vgame-gsc.key"   # 表示された age1... が GSC_AGE_RECIPIENT と同じなら正しい
```

**バックアップ:** 秘密鍵をなくすと、それまでのレポートは復号できません(Search Console のデータは16か月分まで取り直せます)。
USB メモリやパスワード管理ソフトなど、ネットにつながらない場所にコピーしてください。

## 2. レポートの復号(Windows)

1. GitHub の Actions →「search console weekly report」→ 対象の実行 → **Artifacts** から
   `search-console-report-<番号>` をダウンロードする(zip で保存される)。
   コマンドなら: `gh run download <実行ID> -n search-console-report-<番号> -D "$env:USERPROFILE\Downloads"`
2. リポジトリのフォルダで次を実行する:

```powershell
.\tools\search-console\decrypt-report.ps1 "$env:USERPROFILE\Downloads\search-console-report-<番号>.zip"
```

`%LOCALAPPDATA%\vgame-seo\reports\actions-search-console-report-<日付>-run<番号>\` に
CSV・`summary.json`・`report.json`・`summary.md` が展開されます(リポジトリの外)。
復号した途中の tar.gz は自動で削除されます。

手で復号する場合:

```powershell
age -d -i "$env:LOCALAPPDATA\vgame-seo\age\vgame-gsc.key" -o report.tar.gz search-console-report-<日付>-run<番号>.tar.gz.age
tar -xzf report.tar.gz -C <展開先>
Remove-Item report.tar.gz
```

## 3. 鍵の作り直し(漏れたかもしれないとき・PCを替えるとき)

1. 新しい鍵ペアを作る(手順1。ファイル名を変えて作り、古い鍵は復号用にしばらく残す)。
2. `GSC_AGE_RECIPIENT` を新しい公開鍵に変える。以後のレポートは新しい鍵でしか復号できない。
3. 古い秘密鍵が漏れた場合は、30日以内の Artifacts を Actions の画面から削除する(保存期間が過ぎれば自動で消える)。

## 4. 守ること

- 復号したレポートをリポジトリのフォルダに置かない・commit しない(`decrypt-report.ps1` はリポジトリの中への展開を止める)。
- 秘密鍵を GitHub(Secrets を含む)・リポジトリ・チャット・クラウド同期フォルダに置かない。
- Actions のログには件数(API リクエスト数・エラー数)だけが出る。検索語句・URL・数値はログに出さない。
