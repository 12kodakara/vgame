<#
.SYNOPSIS
  単発実況(STANDALONE_PLAYS)を通常の再生リスト(PLAYLISTS)へ、人の承認を経て移行する。
  既定はすべて「確認だけ」。データを書き換えるのは -Action apply -Apply のときだけ。

.DESCRIPTION
  候補検出 → 内容確認 → 人の承認 → 安全性の再検証 → 移行の適用(判定・適用の中身は standalone-migration-approval.ps1)

    1. 候補検出: report-standalone-followups.ps1 で reports\standalone-followups.json を作る(YouTube API・キャッシュつき)
    2. -Action init    : レポートから候補を作り、状態ファイルに取り込む(新しい候補は pending)
    3. -Action list    : 候補・状態・適用できるか(理由)を表示する(reports\standalone-migration\candidates.md にも書く)
    4. -Action approve -Id <候補>  : 承認する(状態ファイルだけを変える)。適用できない候補は承認できない
       -Action reject  -Id <候補>  : 却下する / -Action reset -Id <候補>: pending に戻す
    5. -Action apply   : approved の候補を再検証して、適用できるかを表示する(dry-run。データは変えない)
       -Action apply -Apply : 再検証に通った approved の候補だけを適用する(1件ずつ。失敗したらそこで止めて元に戻す)

  状態(状態ファイルの status): pending(未確認)/ approved(承認済み)/ rejected(却下)/ applied(適用済み)/ error(適用時のエラー)
  -Id は候補のキー(<単発実況ID>|<type>|<再生リストID>)か、候補が1つだけの単発実況ID。

  -Apply の条件(どれかを満たさなければ何も書き換えない):
    YouTube APIキーがある(移行先の再生リストの中身・所有チャンネルを適用直前に取り直す)/
    data-playlists.js・data-standalone.js に未コミットの変更が無い(適用結果を git diff で確認・取り消せるように)

  適用後にすること(このスクリプトは行わない):
    node generate-home-data.js / generate-detail-data.js / generate-list-data.js / generate-genre-data.js、generate-counts.ps1、
    fetch-thumbnails.ps1・update-dates.ps1(新しい再生リストのサムネイル・更新日)、validate-data.ps1・check-site.ps1 → git diff を確認して commit
  取り消し: git checkout -- data-playlists.js data-standalone.js(commit 前)、または reports\standalone-migration\backups\<日時-ID>\ から戻す

  書き込む場所: reports\standalone-migration\(状態・ログ・一時ファイル・バックアップ。git 管理外・公開対象外)。
  APIキーは表示・保存しない。

.EXAMPLE
  .\report-standalone-followups.ps1
  .\migrate-standalone.ps1 -Action init
  .\migrate-standalone.ps1 -Action list
  .\migrate-standalone.ps1 -Action approve -Id single-001 -Note "動画タイトルで同じ実況と確認"
  .\migrate-standalone.ps1 -Action apply           # dry-run
  .\migrate-standalone.ps1 -Action apply -Apply    # 適用
#>
param(
  [ValidateSet('init', 'list', 'approve', 'reject', 'reset', 'apply')]
  [string]$Action = 'list',
  [string[]]$Id = @(),
  [string]$Note = '',
  [string]$Report = 'reports\standalone-followups.json',
  [string]$WorkDir = 'reports\standalone-migration',
  [switch]$Apply,
  [switch]$Offline,
  [int]$MaxUnits = 50,
  [string]$ApiKey = $env:YOUTUBE_API_KEY
)
$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir 'standalone-matching.ps1')
. (Join-Path $scriptDir 'standalone-followups.ps1')
. (Join-Path $scriptDir 'standalone-migration-approval.ps1')

# ---- 書き込み先の確認(リポジトリ内なら reports\ の下だけ) ----
$rootFull = [IO.Path]::GetFullPath($scriptDir).TrimEnd('\')
$sep = [IO.Path]::DirectorySeparatorChar
function Resolve-RepoPath([string]$p) { return [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($p)) { $p } else { Join-Path $scriptDir $p })) }
$workFull = Resolve-RepoPath $WorkDir
$reportsFull = Join-Path $rootFull 'reports'
if ($workFull.StartsWith($rootFull + $sep, [StringComparison]::OrdinalIgnoreCase) -and -not $workFull.StartsWith($reportsFull + $sep, [StringComparison]::OrdinalIgnoreCase)) {
  Write-Error "-WorkDir はリポジトリ内なら reports\ の下にしてください(git 管理外・公開対象外の場所): $WorkDir"; exit 1
}
$stateFile = Join-Path $workFull 'approvals.json'
$logFile = Join-Path $workFull 'log.jsonl'
$now = Get-Date
if ($Apply -and $Action -ne 'apply') { Write-Error '-Apply は -Action apply のときだけ使えます'; exit 1 }

function Find-Candidate($state, [string]$idOrKey) {
  $c = @($state.candidates | Where-Object { $_.key -eq $idOrKey })
  if ($c.Count -eq 1) { return $c[0] }
  $c = @($state.candidates | Where-Object { $_.standaloneId -eq $idOrKey })
  if ($c.Count -eq 1) { return $c[0] }
  if ($c.Count -gt 1) { throw "単発実況 $idOrKey の候補が $($c.Count) つあります。キーで指定してください: $(@($c | ForEach-Object { $_.key }) -join ' / ')" }
  throw "候補が見つかりません: $idOrKey"
}

function Write-CandidateList($state) {
  $order = @{ approved = 0; error = 1; pending = 2; rejected = 3; applied = 4 }
  $md = New-Object System.Text.StringBuilder
  [void]$md.AppendLine('# 単発実況 → 再生リスト 移行候補(承認状態)')
  [void]$md.AppendLine('')
  [void]$md.AppendLine("- 更新: $($state.updatedAt) / 元のレポート: $($state.reportGeneratedAt)")
  [void]$md.AppendLine('- 状態: ' + ((@('pending', 'approved', 'rejected', 'applied', 'error') | ForEach-Object { $s = $_; "$s $(@($state.candidates | Where-Object { $_.status -eq $s }).Count)" }) -join ' / '))
  [void]$md.AppendLine('- 承認しても、適用(-Action apply -Apply)するまでデータは変わらない。適用前に YouTube API で再検証する')
  Write-Output ("候補 {0} 件 / " -f @($state.candidates).Count + ((@('pending', 'approved', 'rejected', 'applied', 'error') | ForEach-Object { $s = $_; "$s $(@($state.candidates | Where-Object { $_.status -eq $s }).Count)" }) -join ' / '))
  foreach ($c in @($state.candidates | Sort-Object { $order[$_.status] }, standaloneId)) {
    $okText = $(if ($c.status -eq 'applied') { '適用済み' } elseif ($c.eligible) { '適用可(承認・再検証が必要)' } else { '適用不可(要確認)' })
    $sa = $c.standalone
    $lines = @(
      "## [$($c.status)] $($c.key)"
      "- VTuber: $($c.streamer) / ゲーム: $($c.game) / ランク: $($c.rank)$(if ($c.inLatestReport -eq $false) { ' / ※最新のレポートに無い' })"
      "- 現在の単発実況: $($c.standaloneId)「$($sa.title)」 format=$($sa.format) / 動画 $(@($sa.videoIds).Count) 本: $(@($sa.videoIds) -join ', ')"
      "- 移行先: $(if ($c.type -eq 'new-playlist') { '新規登録 ' + $c.newPlaylistId } else { '登録済み ' + $c.target.registeredId }) / 再生リストID $($c.playlistId)「$($c.target.title)」 / 動画数 $(if ($null -ne $c.target.count) { $c.target.count } else { '不明' }) / 既存の動画: $(if ($c.target.videoInPlaylist -eq $true) { 'あり(レポート時点)' } else { '未確認' })"
      "- 重複: $(@($c.duplicates) -join ' / ')"
      "- 企画の疑い: $(if (@($c.blockers | Where-Object { $_ -match '企画' }).Count) { @($c.blockers | Where-Object { $_ -match '企画' }) -join ' / ' } else { 'なし' })"
      "- 可否: $okText"
    )
    foreach ($b in @($c.blockers)) { $lines += "  - 理由: $b" }
    foreach ($w in @($c.warnings)) { $lines += "  - 注意: $w" }
    if ($c.error) { $lines += "  - エラー: $($c.error)" }
    foreach ($l in $lines) { Write-Output $l; [void]$md.AppendLine($l) }
    Write-Output ''; [void]$md.AppendLine('')
  }
  if (-not (Test-Path -LiteralPath $workFull)) { New-Item -ItemType Directory -Path $workFull -Force | Out-Null }
  [IO.File]::WriteAllText((Join-Path $workFull 'candidates.md'), $md.ToString(), (New-Object System.Text.UTF8Encoding($false)))
  Write-Output "一覧: $(Join-Path $workFull 'candidates.md')"
}

switch ($Action) {
  'init' {
    $reportFull = Resolve-RepoPath $Report
    if (-not (Test-Path -LiteralPath $reportFull)) { Write-Error "レポートがありません。先に report-standalone-followups.ps1 を実行してください: $Report"; exit 1 }
    $rep = [IO.File]::ReadAllText($reportFull, [Text.Encoding]::UTF8) | ConvertFrom-Json
    $site = Read-MigrationSiteData $scriptDir
    $cands = New-MigrationCandidates $rep $site
    $state = Merge-MigrationCandidates (Read-MigrationState $stateFile) $cands $site $now ([string]$rep.generatedAt)
    Write-MigrationState $state $stateFile $now
    Write-MigrationLog $logFile $now 'init' ([ordered]@{ report = [string]$rep.generatedAt; candidates = @($state.candidates).Count })
    Write-Output "レポート $($rep.generatedAt)($($rep.mode))から候補 $(@($cands).Count) 件を取り込みました(データは変更していません)"
    Write-CandidateList $state
  }
  'list' { Write-CandidateList (Read-MigrationState $stateFile) }
  { $_ -in 'approve', 'reject', 'reset' } {
    if (-not $Id.Count) { Write-Error '-Id を指定してください'; exit 1 }
    $state = Read-MigrationState $stateFile
    foreach ($x in $Id) {
      $c = Find-Candidate $state $x
      [void](Set-MigrationDecision $state $c.key $Action $now $Note)
      Write-MigrationLog $logFile $now $Action ([ordered]@{ key = $c.key; note = $Note })
      Write-Output "$($c.key): $($c.status)(状態ファイルだけを変更。データは変更していません)"
    }
    Write-MigrationState $state $stateFile $now
  }
  'apply' {
    $state = Read-MigrationState $stateFile
    $targets = @($state.candidates | Where-Object { $_.status -eq 'approved' })
    if ($Id.Count) { $keys = @($Id | ForEach-Object { (Find-Candidate $state $_).key }); $targets = @($targets | Where-Object { $keys -contains $_.key }) }
    if (-not $targets.Count) { Write-Output '承認済み(approved)の候補がありません。何も変更していません'; exit 0 }
    $useApi = (-not $Offline) -and [bool]$ApiKey
    if ($Apply) {
      if (-not $useApi) { Write-Error '-Apply には YouTube APIキー(移行先の再確認)が必要です。何も変更していません'; exit 1 }
      $dirty = @(& git -C $scriptDir status --porcelain -- data-playlists.js data-standalone.js)
      if ($LASTEXITCODE -ne 0) { Write-Error 'git の状態を確認できません。何も変更していません'; exit 1 }
      if ($dirty.Count) { Write-Error "data-playlists.js / data-standalone.js に未コミットの変更があります。先に確認してください。何も変更していません: $($dirty -join ', ')"; exit 1 }
    }
    $client = $null
    if ($useApi) {
      $httpGet = { param($endpoint, $query) Invoke-RestMethod -Uri ("https://www.googleapis.com/youtube/v3/" + $endpoint + "?" + $query + "&key=" + [uri]::EscapeDataString($ApiKey)) -Method Get -TimeoutSec 30 }
      $client = New-FollowupApiClient $httpGet $MaxUnits $null $now $ApiKey
    }
    Write-Output "=== 移行の$(if ($Apply) { '適用' } else { '確認(dry-run。データは変更しない)' }) / 対象 $($targets.Count) 件 / 確認方法: $(if ($useApi) { 'YouTube API' } else { 'API なし(移行先の再確認はしない)' }) ==="
    foreach ($c in $targets) {
      $site = Read-MigrationSiteData $scriptDir   # 1件ごとに読み直す(前の適用の結果を反映する)
      $live = $(if ($client) { Get-MigrationLiveTarget $client $c.playlistId } else { $null })
      if (-not $live) {
        $chk = Test-MigrationCandidate $c $site $null
        Write-Output "- $($c.key): API なしのため移行先は再確認していない。データだけの確認: $(if ($chk.eligible) { '問題なし' } else { @($chk.blockers) -join ' / ' })"
        Write-MigrationLog $logFile $now 'apply-check-offline' ([ordered]@{ key = $c.key; eligible = $chk.eligible; blockers = @($chk.blockers) })
        continue
      }
      $res = Invoke-MigrationApply $c $site @{ root = $scriptDir; workDir = $workFull; now = $now; dryRun = (-not $Apply); live = $live }
      Write-Output "- $($c.key): $($res.message)"
      foreach ($b in @($res.blockers)) { Write-Output "    理由: $b" }
      foreach ($w in @($res.warnings)) { Write-Output "    注意: $w" }
      Write-MigrationLog $logFile $now $(if ($Apply) { 'apply' } else { 'apply-dry-run' }) ([ordered]@{ key = $c.key; ok = $res.ok; applied = $res.applied; message = $res.message; blockers = @($res.blockers); backupDir = $res.backupDir; newPlaylist = $res.newPlaylist })
      if ($Apply) {
        if ($res.applied) {
          Set-MigrationProp $c 'status' 'applied'; Set-MigrationProp $c 'appliedAt' $now.ToString('s'); Set-MigrationProp $c 'backupDir' $res.backupDir; Set-MigrationProp $c 'error' $null
          Add-MigrationHistory $c $now 'applied' $res.message
          Write-MigrationState $state $stateFile $now
        } else {
          Set-MigrationProp $c 'status' 'error'; Set-MigrationProp $c 'error' ($res.message + ': ' + (@($res.blockers) -join ' / '))
          Add-MigrationHistory $c $now 'error' $c.error
          Write-MigrationState $state $stateFile $now
          Write-Output '適用できない候補があったため、ここで止めました(以降の候補は処理していません)'
          break
        }
      }
    }
    if ($client) { Write-Output "API ユニット: $($client.units)(上限 $MaxUnits)" }
    if ($Apply -and @($state.candidates | Where-Object { $_.status -eq 'applied' -and $_.appliedAt -eq $now.ToString('s') }).Count) {
      Write-Output '次に: 派生データの再生成(node generate-*.js・generate-counts.ps1)・fetch-thumbnails.ps1・update-dates.ps1・validate-data.ps1・check-site.ps1 → git diff を確認して commit'
    }
  }
}
exit 0
