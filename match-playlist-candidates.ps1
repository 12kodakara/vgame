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
    - 部分一致ガード(第4回データ拡充で追加): 単にゲーム名の文字列が
      含まれているだけではHIGHにしない。次の2点を機械的に確認する。
        (1) 境界の強さ … 一致箇所の隣が漢字やASCII英数字である場合は
            「より長い別タイトルの一部」とみなしてLOWにする
            (例:「刀剣乱舞無双」を「刀剣乱舞」、「超魔界村」を「魔界村」と
             誤認するケースを実データで確認したため)。
            ひらがな・記号・空白の隣接は助詞や装飾のため強い境界として扱う。
        (2) 名前の識別力 … そのゲーム名が別の登録済みゲーム名の一部に
            なっている場合はMEDIUMに留める
            (例:「ゼルダの伝説」は「ゼルダの伝説 ブレス オブ ザ ワイルド」の
             一部であり、タイトルに含まれていてもどの作品か特定できない)。
      いずれもGAMESカタログと文字種だけから導く一般規則で、
      個別タイトルのハードコードは行わない。
    - シリーズ関係は既存の series フィールド(集約名の判定)以外には使わない。
      「同じシリーズだと思われる」という推測でconfidenceを上げることはしない。

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

# ---- 部分一致ガード(第4回データ拡充で追加) ----
# Normalize-SearchText は空白を完全に除去するため、
#   「聖剣伝説3 トライアルズオブマナ」→「聖剣伝説3とらいあるずおぶまな」
# のように、元タイトルで空白に区切られていた語まで地続きに見えてしまう。
# その結果「一致箇所の隣が何の文字か」で境界の強さを判断できなくなる。
# そこで「空白を1個に潰しただけのテキスト(collapsed)」と
# 「空白を除去したテキスト(stripped)」を同時に作り、
# stripped 上の位置から collapsed 上の位置を引けるようにインデックス表(map)を持つ。
function Build-MatchText([string]$s) {
  if (-not $s) { return [PSCustomObject]@{ stripped = ""; collapsed = ""; map = @() } }
  $n = $s.Normalize([System.Text.NormalizationForm]::FormKC)
  $n = ConvertTo-Hiragana $n
  $n = $n.ToLowerInvariant().Trim()
  $n = ($n -replace '\s+', ' ')
  $sb = New-Object System.Text.StringBuilder
  $map = New-Object System.Collections.Generic.List[int]
  for ($i = 0; $i -lt $n.Length; $i++) {
    if ($n[$i] -eq ' ') { continue }
    [void]$sb.Append($n[$i])
    $map.Add($i)
  }
  return [PSCustomObject]@{ stripped = $sb.ToString(); collapsed = $n; map = $map.ToArray() }
}

# 一致箇所の隣がこの種類の文字である場合、「より長い語の一部を切り出しただけ」
# である可能性が高いとみなす(=境界が弱い)。
#   - 漢字        : 「刀剣乱舞」+「無双」、「超」+「魔界村」のような別タイトルの複合語
#   - ASCII英数字 : 「太鼓の達人」+「Nintendo」のような続き
# ひらがな・長音符・記号・絵文字・空白は、助詞や装飾として自然に隣接するため
# 弱い境界とはみなさない(例:「海こんにゃくで仁王2」「PIENぴえん」「壺おじさん」は
# いずれも正しい一致であり、これらまで落とすと正常な候補を壊してしまう)。
function Test-WeakBoundaryChar([char]$ch) {
  if ($ch -ge [char]0x3400 -and $ch -le [char]0x9FFF) { return $true }  # CJK統合漢字(拡張A含む)
  if ($ch -eq [char]0x3005) { return $true }                            # 々(踊り字)
  if ($ch -ge 'a' -and $ch -le 'z') { return $true }
  if ($ch -ge '0' -and $ch -le '9') { return $true }
  return $false
}

# Test-BoundaryMatch を通った一致について、さらに「強い境界で一致しているか」を判定する。
# 強い境界 = 前後が「文字列の端 / 空白 / 記号・絵文字 / ひらがな」のいずれか。
# 複数箇所で一致する場合は、1箇所でも強い境界があれば true を返す。
function Test-CleanBoundaryMatch($ctx, [string]$needle) {
  if (-not $needle -or -not $ctx -or -not $ctx.stripped) { return $false }
  $hay = $ctx.stripped
  $idx = $hay.IndexOf($needle)
  while ($idx -ge 0) {
    $ok = $true
    $prevPos = $ctx.map[$idx] - 1
    if ($prevPos -ge 0 -and (Test-WeakBoundaryChar $ctx.collapsed[$prevPos])) { $ok = $false }
    if ($ok) {
      $nextPos = $ctx.map[$idx + $needle.Length - 1] + 1
      if ($nextPos -lt $ctx.collapsed.Length -and (Test-WeakBoundaryChar $ctx.collapsed[$nextPos])) { $ok = $false }
    }
    if ($ok) { return $true }
    $idx = $hay.IndexOf($needle, $idx + 1)
  }
  return $false
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

# ---- 識別力チェック(第4回データ拡充で追加) ----
# あるゲーム名が、別の登録済みゲーム名の一部になっている場合、
# タイトルにその名前が含まれていても「どの作品か」を一意に特定できない。
#   例:「ゼルダの伝説」は「ゼルダの伝説 ブレス オブ ザ ワイルド」等13件の一部
#      「星のカービィ」は「星のカービィ スーパーデラックス」等7件の一部
#      「魔界村」は「大魔界村」「帰ってきた魔界村」の一部
# このようなゲーム名への一致は HIGH に昇格させず MEDIUM(要人間確認)に留める。
# 個別タイトルのハードコードではなく、GAMESカタログの包含関係だけから機械的に導く。
$normNameList = New-Object System.Collections.Generic.List[string]
$normNameOf = @{}
foreach ($o in $gameObjs) {
  $gn = Field $o "name"
  if (-not $gn) { continue }
  $nrm = Normalize-SearchText $gn
  $normNameOf[$gn] = $nrm
  $normNameList.Add($nrm)
}
$normNames = $normNameList.ToArray()
$nonDiscriminativeGames = @{}
foreach ($gn in $normNameOf.Keys) {
  $me = $normNameOf[$gn]
  $meLen = $me.Length
  foreach ($other in $normNames) {
    # 自分より長い名前だけを調べれば十分(同じ長さで内容が違えば包含しない)
    if ($other.Length -le $meLen) { continue }
    if ($other.Contains($me)) { $nonDiscriminativeGames[$gn] = $true; break }
  }
}
Write-Output ("識別力チェック: {0} / {1} 件のゲーム名が、より具体的な登録名の一部です(HIGHに昇格させません)。" -f $nonDiscriminativeGames.Count, $normNameOf.Count)

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

    $titleCtx = Build-MatchText $pl.title
    $normTitle = $titleCtx.stripped
    $normDesc = Normalize-SearchText $pl.description

    $titleMatches = New-Object System.Collections.Generic.List[object]
    $matchedGames = @{}
    foreach ($t in $matchTargets) {
      if ($matchedGames.ContainsKey($t.gameName)) { continue } # 同じゲームへの重複一致は1回だけ記録
      if (Test-BoundaryMatch $normTitle $t.matchText) {
        $matchedGames[$t.gameName] = $true
        $titleMatches.Add([PSCustomObject]@{
          game = $t.gameName
          via = $(if ($t.isAlias) { "alias" } else { "name" })
          isUmbrella = $t.isUmbrella
          currentPlaylistCount = $t.playlistCount
          # タイトル全体がゲーム名そのものなら最も強い一致
          exactTitle = ($normTitle -eq $t.matchText)
          # 前後が「端 / 空白 / 記号 / ひらがな」で区切られた一致かどうか
          cleanBoundary = (Test-CleanBoundaryMatch $titleCtx $t.matchText)
          # より具体的な登録名の一部にあたるゲーム名かどうか
          nonDiscriminative = $nonDiscriminativeGames.ContainsKey($t.gameName)
        })
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
      # ---- confidence の定義(第4回データ拡充で再定義) ----
      #   HIGH   : ゲームを一意に特定できる強い一致
      #            (タイトル全体一致、または 強い境界での正式名一致 かつ
      #             そのゲーム名が他の登録名の一部になっていない)
      #   MEDIUM : 関連性は高いが、どの作品かの確定に人間確認が必要
      #            (より具体的な登録名が存在する / aliasesでの一致)
      #   LOW    : 部分一致・曖昧一致・誤判定可能性あり
      #            (既存の失格条件、または境界の弱い部分一致)
      #   迷う場合はHIGHに上げず、MEDIUM/LOWへ落とす(件数より安全性を優先)。
      $weakBoundary = (-not $m.cleanBoundary -and -not $m.exactTitle)
      $confidence =
        if ($lowConf -or $weakBoundary) { "LOW" }
        elseif ($m.nonDiscriminative) { "MEDIUM" }
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
        exactTitle          = $m.exactTitle
        cleanBoundary       = $m.cleanBoundary
        weakBoundaryMatch   = $weakBoundary
        nonDiscriminativeName = $m.nonDiscriminative
        warning        = $(
          $w = @()
          if ($weakBoundary) { $w += "部分一致です(一致箇所の隣が漢字/英数字。より長い別タイトルの一部の可能性)" }
          if ($m.nonDiscriminative) { $w += "「$($m.game)」はより具体的な登録ゲーム名の一部です(どの作品か特定できないため要確認)" }
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
