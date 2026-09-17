<#
.SYNOPSIS
  discover-playlists.ps1 が出力したJSON(実況者ごとのYouTube再生リスト一覧)を、
  既存のGAMESデータと照合し、「再生リスト0件/1件のゲームに追加できそうな
  候補」を人間レビュー用に抽出します。YouTube APIへのアクセスはこの
  スクリプトでは一切行いません(discover-playlists.ps1 の結果を再利用するだけ)。

.DESCRIPTION
  candidate(候補抽出) → validation(このスクリプトのFalse Positiveチェック) →
  human review(人間が -Json の出力を見て判断) → staging(承認したものだけ
  手動でdata-playlists.jsに追記) → production、という流れの
  「candidate〜validation」部分を担います。

  data-playlists.js / data-core.js は一切書き換えません。

  マッチングは common.js の normalizeSearchText/katakanaToHiragana と
  同じ考え方(全角半角統一・カタカナをひらがなに変換・大文字小文字無視)を
  PowerShell側で再現し、サイト本体の検索と矛盾しない基準で照合します。

  False Positive対策(STEP6):
    - 既にdata-playlists.jsに登録済みのplaylistIdは候補から除外(重複防止)
    - タイトル・説明文に「切り抜き」「まとめ」「shorts」「ショート」「PV」
      「トレーラー」「体験版」「デモ版」「宣伝」「告知」等が含まれる場合は
      likelyNonGame=true として警告付きで出力(自動除外はしない。人間が
      最終判断できるよう情報として残す)
    - ゲーム名が2文字以下など極端に短い/曖昧な場合は突き合わせの対象外
      (誤検知が多くなるため)
    - 1件のプレイリストが複数ゲーム名に一致する場合は ambiguousMatch=true
      にして両方を候補に残す(勝手にどちらか一方に決め打ちしない)
    - シリーズの集約名(例:「〇〇シリーズ」)自体への一致は confidence を
      下げて出力する(具体的な個別タイトルの誤検知を招きやすいため)

  出力される候補はすべて「要人間確認」であり、実在確認・削除済み/非公開で
  ないかの確認・本編プレイであることの確認は人間が行ってください。

.PARAMETER DiscoveredJson
  discover-playlists.ps1 が出力したJSONファイルのパス(必須)。

.PARAMETER Json
  候補一覧をJSON形式で出力する場合の出力先パス。

.PARAMETER GapOnly
  指定すると、再生リスト0件・1件のゲーム(拡充候補)に一致した場合のみ
  候補として出力します(既定は全ゲームを対象にしつつ、ギャップ対象かどうかを
  isGapGame フィールドで示す)。

.EXAMPLE
  .\match-playlist-candidates.ps1 -DiscoveredJson discovered-playlists.json -Json reports/playlist-candidates.json

.EXAMPLE
  # 動作確認用サンプル(実データではありません)
  .\match-playlist-candidates.ps1 -DiscoveredJson discovered-playlists.sample.json -GapOnly
#>
param(
  [Parameter(Mandatory = $true)][string]$DiscoveredJson,
  [string]$Json,
  [switch]$GapOnly
)

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$corePath = Join-Path $scriptDir "data-core.js"
$playlistsPath = Join-Path $scriptDir "data-playlists.js"

if (-not (Test-Path $DiscoveredJson)) { Write-Error "指定されたファイルが見つかりません: $DiscoveredJson"; exit 1 }
if (-not (Test-Path $corePath)) { Write-Error "data-core.js が見つかりません: $corePath"; exit 1 }
if (-not (Test-Path $playlistsPath)) { Write-Error "data-playlists.js が見つかりません: $playlistsPath"; exit 1 }

# ---- パーサ(find-expansion-candidates.ps1 と同じ手法) ----
function Get-ArrayInner([string]$name, [string]$text) {
  $marker = "const $name = ["
  $start = $text.IndexOf($marker)
  if ($start -lt 0) { return $null }
  $i = $start + $marker.Length
  $depth = 1; $inString = $false; $escape = $false
  for ($p = $i; $p -lt $text.Length; $p++) {
    $ch = $text[$p]
    if ($inString) {
      if ($escape) { $escape = $false; continue }
      if ($ch -eq '\') { $escape = $true; continue }
      if ($ch -eq '"') { $inString = $false }
      continue
    }
    if ($ch -eq '"') { $inString = $true; continue }
    if ($ch -eq '/' -and $p + 1 -lt $text.Length -and $text[$p + 1] -eq '/') {
      while ($p -lt $text.Length -and $text[$p] -ne "`n") { $p++ }
      continue
    }
    if ($ch -eq '/' -and $p + 1 -lt $text.Length -and $text[$p + 1] -eq '*') {
      $p += 2
      while ($p + 1 -lt $text.Length -and -not ($text[$p] -eq '*' -and $text[$p + 1] -eq '/')) { $p++ }
      $p++
      continue
    }
    if ($ch -eq '[') { $depth++ }
    elseif ($ch -eq ']') {
      $depth--
      if ($depth -eq 0) { return $text.Substring($i, $p - $i) }
    }
  }
  throw "$name 配列の終端が見つかりません。"
}

function Get-Objects([string]$inner) {
  $results = @(); $depth = 0; $start = -1; $inString = $false; $escape = $false
  for ($i = 0; $i -lt $inner.Length; $i++) {
    $ch = $inner[$i]
    if ($inString) {
      if ($escape) { $escape = $false; continue }
      if ($ch -eq '\') { $escape = $true; continue }
      if ($ch -eq '"') { $inString = $false }
      continue
    }
    if ($ch -eq '"') { $inString = $true; continue }
    if ($ch -eq '/' -and $i + 1 -lt $inner.Length -and $inner[$i + 1] -eq '/') {
      while ($i -lt $inner.Length -and $inner[$i] -ne "`n") { $i++ }
      continue
    }
    if ($ch -eq '/' -and $i + 1 -lt $inner.Length -and $inner[$i + 1] -eq '*') {
      $i += 2
      while ($i + 1 -lt $inner.Length -and -not ($inner[$i] -eq '*' -and $inner[$i + 1] -eq '/')) { $i++ }
      $i++
      continue
    }
    if ($ch -eq '{') { if ($depth -eq 0) { $start = $i }; $depth++ }
    elseif ($ch -eq '}') { $depth--; if ($depth -eq 0 -and $start -ge 0) { $results += $inner.Substring($start, $i - $start + 1); $start = -1 } }
  }
  return $results
}

$script:fieldRegexCache = @{}
function Field([string]$obj, [string]$name) {
  if (-not $script:fieldRegexCache.ContainsKey($name)) {
    $script:fieldRegexCache[$name] = [regex]::new([regex]::Escape($name) + '\s*:\s*"((?:\\.|[^"])*)"')
  }
  $m = $script:fieldRegexCache[$name].Match($obj)
  if ($m.Success) { return ($m.Groups[1].Value -replace '\\"', '"' -replace '\\\\', '\') }
  return ""
}

function FieldArray([string]$obj, [string]$name) {
  $m = [regex]::Match($obj, [regex]::Escape($name) + '\s*:\s*\[([^\]]*)\]')
  if (-not $m.Success) { return @() }
  return @([regex]::Matches($m.Groups[1].Value, '"((?:\\.|[^"])*)"') | ForEach-Object { $_.Groups[1].Value })
}

# ---- common.js の normalizeSearchText / katakanaToHiragana を移植
#      (サイト本体の検索と矛盾しない基準で照合するため、同じ正規化ロジックを使う) ----
function ConvertTo-Hiragana([string]$s) {
  $sb = New-Object System.Text.StringBuilder
  foreach ($ch in $s.ToCharArray()) {
    if ($ch -ge [char]0x30A1 -and $ch -le [char]0x30F6) {
      [void]$sb.Append([char]([int]$ch - 0x60))
    } else {
      [void]$sb.Append($ch)
    }
  }
  return $sb.ToString()
}

# 単純な部分文字列一致だと、"MOTHER"が"MOTHER3"に、"ピクミン"が"ピクミン3"に、
# "raft"が"crafter"に、"龍が如く"が"龍が如く2"にそれぞれ意図せず一致してしまう
# (=続編・別タイトルを旧作/別ゲームと誤認する)ことを実データで確認したため、
# 一致箇所の直後がASCII数字、または一致文字列の末尾と直後の文字がともにASCII英字
# である場合は「単語の続き」とみなして一致を無効化する(境界チェック)。
function Test-BoundaryMatch([string]$haystack, [string]$needle) {
  if (-not $needle) { return $false }
  $idx = $haystack.IndexOf($needle)
  while ($idx -ge 0) {
    $endIdx = $idx + $needle.Length
    $rejected = $false
    if ($endIdx -lt $haystack.Length) {
      $nextCh = $haystack[$endIdx]
      $lastCh = $needle[$needle.Length - 1]
      $nextIsDigit = ($nextCh -ge '0' -and $nextCh -le '9')
      $nextIsAsciiLetter = ($nextCh -ge 'a' -and $nextCh -le 'z')
      $lastIsAsciiLetter = ($lastCh -ge 'a' -and $lastCh -le 'z')
      if ($nextIsDigit -or ($nextIsAsciiLetter -and $lastIsAsciiLetter)) { $rejected = $true }
    }
    # 先頭側も同様にチェックする("Mine Craft"を空白除去した"minecraft"に対し
    # "Raft"が末尾4文字"raft"としてASCII英字の続きから偶然一致してしまう実例を
    # 第2回データ拡充で確認したため追加)。
    if (-not $rejected -and $idx -gt 0) {
      $prevCh = $haystack[$idx - 1]
      $firstCh = $needle[0]
      $prevIsAsciiLetterOrDigit = (($prevCh -ge 'a' -and $prevCh -le 'z') -or ($prevCh -ge '0' -and $prevCh -le '9'))
      $firstIsAsciiLetter = ($firstCh -ge 'a' -and $firstCh -le 'z')
      if ($prevIsAsciiLetterOrDigit -and $firstIsAsciiLetter) { $rejected = $true }
    }
    if (-not $rejected) { return $true }
    $idx = $haystack.IndexOf($needle, $idx + 1)
  }
  return $false
}

function Normalize-SearchText([string]$s) {
  if (-not $s) { return "" }
  $n = $s.Normalize([System.Text.NormalizationForm]::FormKC)
  $n = ConvertTo-Hiragana $n
  # common.js の normalizeSearchText とは異なり、ここでは空白を完全に除去する。
  # YouTube側のタイトル表記(例:「牧場物語ワンダフルライフ」)がサイト内の
  # 表記(例:「牧場物語 ワンダフルライフ」)とスペースの有無だけ違うと、
  # より具体的な個別タイトル側が一致せず、代わりに手前の総称的な名前
  # (「牧場物語」)だけが誤って一致してしまう実害を確認したための対応。
  return ($n.ToLowerInvariant().Trim() -replace '\s+', '')
}

# ---- False Positive警告キーワード(STEP6) ----
$nonGameKeywords = @(
  "切り抜き", "きりぬき", "まとめ", "shorts", "ショート", "sh0rts",
  "pv", "トレーラー", "trailer", "体験版", "デモ版", "でも版",
  "宣伝", "告知", "cm", "announcement", "配信告知", "予告",
  # 実際の候補データで確認した「同時視聴(watching party)」= 実況・自分でのプレイではなく
  # 他コンテンツを見るだけの配信であるケースを検知するためのキーワード(第2回データ拡充で追加)
  "同時視聴", "視聴会", "watchingparty"
)

# ---- データ読み込み ----
$coreText = [System.IO.File]::ReadAllText($corePath, [System.Text.Encoding]::UTF8)
$playlistsText = [System.IO.File]::ReadAllText($playlistsPath, [System.Text.Encoding]::UTF8)
$gameObjs = Get-Objects (Get-ArrayInner "GAMES" $coreText)
$playlistObjs = Get-Objects (Get-ArrayInner "PLAYLISTS" $playlistsText)

$existingPlaylistIds = @{}
$gamePlaylistCount = @{}
foreach ($obj in $playlistObjs) {
  $playlistIdValue = Field $obj "playlistId"
  if ($playlistIdValue) { $existingPlaylistIds[$playlistIdValue] = $true }
  $g = Field $obj "game"
  if ($g) { if (-not $gamePlaylistCount.ContainsKey($g)) { $gamePlaylistCount[$g] = 0 }; $gamePlaylistCount[$g] = $gamePlaylistCount[$g] + 1 }
}

# ---- 突き合わせ用のゲーム名候補(name + aliases。短すぎる名前は除外) ----
$matchTargets = New-Object System.Collections.Generic.List[object]
foreach ($o in $gameObjs) {
  $name = Field $o "name"
  if (-not $name) { continue }
  $series = Field $o "series"
  $isSeriesUmbrella = ($name -eq $series)
  $count = if ($gamePlaylistCount.ContainsKey($name)) { $gamePlaylistCount[$name] } else { 0 }
  $candidates = @($name) + @(FieldArray $o "aliases")
  foreach ($c in $candidates) {
    if (-not $c -or $c.Length -lt 3) { continue } # 2文字以下は誤検知が多いため対象外
    $matchTargets.Add([PSCustomObject]@{
      matchText  = Normalize-SearchText $c
      gameName   = $name
      isAlias    = ($c -ne $name)
      isUmbrella = $isSeriesUmbrella
      playlistCount = $count
    })
  }
}
# 長い一致を優先して誤検知を減らすため、突き合わせ文字列が長い順に並べる
$matchTargets = @($matchTargets | Sort-Object { $_.matchText.Length } -Descending)

# ---- discover-playlists.ps1 の出力を読み込み ----
$discovered = Get-Content $DiscoveredJson -Raw -Encoding UTF8 | ConvertFrom-Json

$results = New-Object System.Collections.Generic.List[object]
$seq = 0
$currentStreamerNames = @{}
foreach ($o in (Get-Objects (Get-ArrayInner "STREAMERS" $coreText))) { $n = Field $o "name"; if ($n) { $currentStreamerNames[$n] = $true } }

foreach ($entry in $discovered) {
  $streamer = $entry.streamer
  # discover-playlists.ps1 はSTREAMERSの公式youtubeフィールドから解決したチャンネルのみを
  # 対象にする設計のため、streamer名が現在のSTREAMERSに実在するかだけを再確認する
  # (入力JSONが古い/加工されている場合の保険。ここでは公式チャンネルIDそのものの真正性までは
  # 検証できないため、STREAMERS登録有無の確認にとどめる)。
  $officialChannelMatch = $currentStreamerNames.ContainsKey($streamer)
  foreach ($pl in $entry.playlists) {
    if (-not $pl.playlistId -or -not $pl.title) { continue }
    if ($existingPlaylistIds.ContainsKey($pl.playlistId)) { continue } # 登録済みは除外(重複防止)

    $normTitle = Normalize-SearchText $pl.title
    $normDesc = Normalize-SearchText $pl.description

    $titleMatches = New-Object System.Collections.Generic.List[object]
    $matchedGames = @{}
    foreach ($t in $matchTargets) {
      if ($matchedGames.ContainsKey($t.gameName)) { continue } # 同じゲームへの重複一致は1回だけ記録
      if (Test-BoundaryMatch $normTitle $t.matchText) {
        $matchedGames[$t.gameName] = $true
        $titleMatches.Add([PSCustomObject]@{ game = $t.gameName; via = $(if ($t.isAlias) { "alias" } else { "name" }); isUmbrella = $t.isUmbrella; currentPlaylistCount = $t.playlistCount })
      }
    }
    if ($titleMatches.Count -eq 0) { continue }

    $isNonGame = $false
    foreach ($kw in $nonGameKeywords) {
      if ($normTitle.Contains($kw) -or $normDesc.Contains($kw)) { $isNonGame = $true; break }
    }

    foreach ($m in $titleMatches) {
      if ($GapOnly -and $m.currentPlaylistCount -ge 2) { continue }
      $seq++
      $ambiguous = ($titleMatches.Count -gt 1)
      # itemCount=0(空のplaylist)は、第1サイクルの本番反映確認で「投入対象外」と
      # 判定した既存の品質ルールをここに反映する(HIGHに昇格させない)。
      $isEmpty = ($null -ne $pl.itemCount -and [int]$pl.itemCount -eq 0)
      $lowConf = ($m.isUmbrella -or $isNonGame -or $ambiguous -or -not $officialChannelMatch -or $isEmpty)
      $confidence =
        if ($lowConf) { "LOW" }
        elseif ($m.via -eq "alias") { "MEDIUM" }
        else { "HIGH" }
      $results.Add([PSCustomObject][ordered]@{
        candidateId    = "match-" + $seq.ToString("D4")
        streamer       = $streamer
        channelId      = $entry.channelId
        officialChannelMatch = $officialChannelMatch
        game           = $m.game
        matchVia       = $m.via
        isGapGame      = ($m.currentPlaylistCount -le 1)
        currentPlaylistCount = $m.currentPlaylistCount
        ambiguousMatch = $ambiguous
        otherMatches   = @($titleMatches | Where-Object { $_.game -ne $m.game } | ForEach-Object { $_.game })
        title          = $pl.title
        playlistId     = $pl.playlistId
        playlistUrl    = "https://www.youtube.com/playlist?list=" + $pl.playlistId
        itemCount      = $pl.itemCount
        emptyPlaylist  = $isEmpty
        publishedAt    = $pl.publishedAt
        likelyNonGame  = $isNonGame
        confidence     = $confidence
        warning        = $(
          $w = @()
          if (-not $officialChannelMatch) { $w += "STREAMERSに現在登録されているVTuber名と確認できません" }
          if ($isNonGame) { $w += "タイトル/説明文に切り抜き・宣伝等を示す語が含まれます" }
          if ($m.isUmbrella) { $w += "シリーズ集約名への一致です(具体的な個別タイトルではない可能性)" }
          if ($ambiguous) { $w += "複数ゲームに一致しています(要目視確認): " + (($titleMatches | ForEach-Object { $_.game }) -join ", ") }
          if ($isEmpty) { $w += "itemCount=0(空のplaylistの可能性、要人間確認)" }
          $w -join " / "
        )
      })
    }
  }
}

Write-Output "=== ぶいゲー 再生リスト候補マッチング (match-playlist-candidates.ps1) ==="
Write-Output "入力: $DiscoveredJson"
Write-Output "※ YouTube APIへのアクセスはこのスクリプトでは行っていません(discover-playlists.ps1の結果を再利用)。"
Write-Output ""
Write-Output "候補件数: $($results.Count)"
Write-Output ("  HIGH: {0}  MEDIUM: {1}  LOW: {2}" -f @($results | Where-Object { $_.confidence -eq "HIGH" }).Count, @($results | Where-Object { $_.confidence -eq "MEDIUM" }).Count, @($results | Where-Object { $_.confidence -eq "LOW" }).Count)
Write-Output "  うち要注意(likelyNonGame): $(@($results | Where-Object { $_.likelyNonGame }).Count)"
Write-Output "  うちギャップ対象ゲーム(0/1件): $(@($results | Where-Object { $_.isGapGame }).Count)"
Write-Output ""
foreach ($r in ($results | Select-Object -First 20)) {
  Write-Output ("  [{0}] {1} / {2} <- 「{3}」{4}" -f $r.candidateId, $r.game, $r.streamer, $r.title, $(if ($r.warning) { " ⚠ " + $r.warning } else { "" }))
}
Write-Output ""
Write-Output "重要: これらは自動登録されません。実在確認・削除済み/非公開でないかの確認・"
Write-Output "本編プレイであることの確認を人間が行ったうえで、承認したものだけを手動で"
Write-Output "data-playlists.js に追記してください。"

if ($Json) {
  $jsonDir = Split-Path -Parent $Json
  if ($jsonDir -and -not (Test-Path $jsonDir)) { New-Item -ItemType Directory -Path $jsonDir -Force | Out-Null }
  $report = [ordered]@{
    generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
    source      = $DiscoveredJson
    note        = "自動登録はしていません。人間の確認前提の候補一覧です。"
    candidates  = $results
  }
  ($report | ConvertTo-Json -Depth 8) | Set-Content -Path $Json -Encoding UTF8
  Write-Output ""
  Write-Output "候補一覧をJSONで出力しました: $Json"
}

exit 0
