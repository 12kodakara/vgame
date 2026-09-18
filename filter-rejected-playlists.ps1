<#
.SYNOPSIS
  人間確認で reject 確定済みの playlist を、候補生成の前段で取り除く独立した前処理。

.DESCRIPTION
  reports/playlist-operations/rejected-playlists.json に記録された playlist を、
  discover-playlists.ps1 の出力(候補の入力データ)から除外した新しいJSONを書き出す。

  設計方針:
    - match-playlist-candidates.ps1 / resolve-game-id.ps1 の判定ロジックには一切触れない。
      本スクリプトは「入力データから既知rejectを間引く」だけの前処理である。
    - 本番 data-playlists.js には一切関与しない(登録済みplaylistの削除・変更はしない)。
    - rejected-playlists.json が存在しない場合は何も除外せず、入力をそのまま複製する
      (機構を導入していない環境でも従来どおり動く)。

  除外の粒度(scope):
    playlist         … その playlistId を入力データから丸ごと取り除く。
                       以後どのゲームにも一致しなくなる。
    game-assignment  … playlistId は残し、「その playlist を特定ゲームへ割り当てた候補」
                       だけを後段で落とす。入力データ段階では playlist を消せないため、
                       本スクリプトは除外対象の組を -PairReport に書き出し、
                       呼び出し側(run-playlist-cycle.ps1)が候補生成後に適用する。

.PARAMETER DiscoveredJson
  discover-playlists.ps1 と同じ形式の入力JSON(必須)。

.PARAMETER OutJson
  除外後のJSONの出力先(必須)。

.PARAMETER RejectedJson
  reject記録の場所。既定は reports/playlist-operations/rejected-playlists.json。

.PARAMETER PairReport
  scope=game-assignment の除外対象(playlistId + game)を書き出すJSONの出力先(任意)。

.EXAMPLE
  .\filter-rejected-playlists.ps1 -DiscoveredJson merged.json -OutJson merged-filtered.json
#>
param(
  [Parameter(Mandatory = $true)][string]$DiscoveredJson,
  [Parameter(Mandatory = $true)][string]$OutJson,
  [string]$RejectedJson,
  [string]$PairReport
)

$ErrorActionPreference = "Stop"
if (-not $RejectedJson) { $RejectedJson = Join-Path $PSScriptRoot "reports\playlist-operations\rejected-playlists.json" }

if (-not (Test-Path $DiscoveredJson)) { Write-Error "入力JSONが見つかりません: $DiscoveredJson"; exit 1 }

$discovered = Get-Content $DiscoveredJson -Raw -Encoding UTF8 | ConvertFrom-Json

# ---- reject記録の読み込み(無ければ除外なしで通す) ----
$playlistScope = @{}   # playlistId -> 記録
$pairScope = @{}       # "playlistId|game" -> 記録
$rejectedCount = 0
if (Test-Path $RejectedJson) {
  $rj = Get-Content $RejectedJson -Raw -Encoding UTF8 | ConvertFrom-Json
  foreach ($r in @($rj.rejected)) {
    if (-not $r.playlistId) { continue }
    $rejectedCount++
    if ($r.scope -eq "game-assignment" -and $r.game) {
      $pairScope["$($r.playlistId)|$($r.game)"] = $r
    } else {
      $playlistScope[$r.playlistId] = $r
    }
  }
  Write-Output "reject記録を読み込みました: $RejectedJson （$rejectedCount 件）"
} else {
  Write-Output "reject記録がありません（$RejectedJson）。除外は行いません。"
}

# ---- 入力から scope=playlist のものを間引く ----
$removed = New-Object System.Collections.Generic.List[object]
$out = @()
$before = 0
foreach ($entry in @($discovered)) {
  $kept = New-Object System.Collections.Generic.List[object]
  foreach ($pl in @($entry.playlists)) {
    $before++
    if ($pl.playlistId -and $playlistScope.ContainsKey($pl.playlistId)) {
      $removed.Add([PSCustomObject]@{
        streamer = $entry.streamer; playlistId = $pl.playlistId; title = $pl.title
        reason = $playlistScope[$pl.playlistId].reason
      })
      continue
    }
    $kept.Add($pl)
  }
  # 元の構造(streamer/group/channelId/status等)は保ったまま playlists だけ差し替える
  $copy = $entry | Select-Object -Property *
  $copy.playlists = $kept.ToArray()
  $out += $copy
}
$after = 0
foreach ($e in $out) { $after += @($e.playlists).Count }

($out | ConvertTo-Json -Depth 8) | Set-Content -Path $OutJson -Encoding UTF8

Write-Output ("playlist除外(scope=playlist): {0} 件 / 入力 {1} 件 -> 出力 {2} 件" -f $removed.Count, $before, $after)
foreach ($r in $removed) { Write-Output ("  - {0} / 「{1}」 ({2})" -f $r.streamer, $r.title, $r.playlistId) }

if ($pairScope.Count -gt 0) {
  Write-Output ("候補生成後に落とす組(scope=game-assignment): {0} 件" -f $pairScope.Count)
  foreach ($k in $pairScope.Keys) { Write-Output ("  - {0}" -f $k) }
}

if ($PairReport) {
  $pairs = @($pairScope.Keys | ForEach-Object {
    $parts = $_ -split '\|', 2
    [PSCustomObject]@{ playlistId = $parts[0]; game = $parts[1]; reason = $pairScope[$_].reason }
  })
  ($pairs | ConvertTo-Json -Depth 5) | Set-Content -Path $PairReport -Encoding UTF8
  Write-Output "game-assignment除外リストを書き出しました: $PairReport"
}

Write-Output "出力しました: $OutJson"
