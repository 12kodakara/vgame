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

# 商標記号・曲がった引用符の前処理(改善⑥で追加)。
#   NFKC は「™」(U+2122)を英字「TM」、「℠」(U+2120)を「SM」に展開するため、
#   「UNDERTALE™」が「undertaletm」になり、英字続きとして境界チェックで落ちていた。
#   商標記号はゲーム名の一部として意味を持たないので NFKC の前に取り除く。
#   また「Marvel’s」(U+2019)と正式名「Marvel's」(U+0027)は NFKC では揃わないため、
#   曲がった引用符 ‘ ’ (U+2018 / U+2019) を ASCII の ' に揃える。
#   どちらも記号の置き換えだけで、英数字・かな・漢字は一切変えない。
function Remove-TrademarkAndCurlyQuote([string]$s) {
  if (-not $s) { return $s }
  return (($s -replace '[\u2122\u2120]', '') -replace '[\u2018\u2019]', "'")
}

function Normalize-SearchText([string]$s) {
  if (-not $s) { return "" }
  $n = (Remove-TrademarkAndCurlyQuote $s).Normalize([System.Text.NormalizationForm]::FormKC)
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
  $n = (Remove-TrademarkAndCurlyQuote $s).Normalize([System.Text.NormalizationForm]::FormKC)
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

# ---- 版語(版・派生・集約を示す語)の辞書 ----
#   Normalize-SearchText 後の表記で定義する(NFKC -> カタカナはひらがな -> 小文字 -> 空白除去)。
#   同じ意味の別表記は1つのクラスにまとめる。クラスにまとめる理由:
#   「マリオカート8DX」(title) と「マリオカート8 デラックス」(登録名) のように、
#   同じ版を指しながら表記が違うものを同一視できないと、正しい既存判定まで
#   manual-review へ落としてしまうため。
# 原則B(版語があるのに裏付けが無ければHIGHに上げない)の対象外とするクラス。
#   拡張/DLC は「本編gameへ統合する」のが既存の運用規則で、既存17件に例外がない。
#   DLC語があることを理由に HIGH を落とすと、その正しい運用まで人間確認へ送ってしまう。
$script:EditionClassesExemptFromCap = @("dlc")

$script:EditionTokenClasses = [ordered]@{
  remake     = @("りめいく", "remake")
  remaster   = @("りますたー", "りますたーど", "remaster", "remastered")
  hd2d       = @("hd-2d", "hd2d")
  hd         = @("hd")
  dx         = @("dx", "deluxe", "でらっくす")
  definitive = @("definitive")
  dlc        = @("dlc", "expansion", "拡張", "追加こんてんつ")
  collection = @("collection", "これくしょん", "selection", "せれくしょん", "trilogy", "とりろじー", "anthology", "合集", "三部作")
  aggregate  = @("i・ii", "i&ii", "i・ii・iii", "1・2", "1&2", "1+2", "1.5+2.5", "123", "456")
}

# 版語のうち ASCII の英数字・記号だけで構成されるものは、長い語の一部を切り出した
# だけの誤検知が起きやすい。前後の文字も見て境界を確かめる。
#   例: 「ドキドキ文芸部(DDLC)」の "ddlc" から "dlc" を切り出してはいけない
#       「beatmania IIDX」の "iidx" から "dx" を切り出してはいけない
#   一方「マリオカート8dx」の "8dx" は直前が数字なので "dx" として認めてよい。
function Test-EditionTokenPresent([string]$haystack, [string]$token) {
  if (-not $haystack -or -not $token) { return $false }
  $asciiOnly = ($token -match '^[a-z0-9\-\+\.&]+$')
  $hasDigit = ($token -match '[0-9]')
  $idx = $haystack.IndexOf($token)
  while ($idx -ge 0) {
    $ok = $true
    if ($asciiOnly) {
      if ($idx -gt 0) {
        $p = $haystack[$idx - 1]
        if ($p -ge "a" -and $p -le "z") { $ok = $false }
        if ($ok -and $hasDigit -and $p -ge "0" -and $p -le "9") { $ok = $false }
      }
      $e = $idx + $token.Length
      if ($ok -and $e -lt $haystack.Length) {
        $n = $haystack[$e]
        if ($n -ge "a" -and $n -le "z") { $ok = $false }
        if ($ok -and $hasDigit -and $n -ge "0" -and $n -le "9") { $ok = $false }
      }
    }
    if ($ok) { return $true }
    $idx = $haystack.IndexOf($token, $idx + 1)
  }
  return $false
}

# 正規化済みテキストに含まれる版語クラスの集合を返す。
function Get-EditionClasses([string]$normText) {
  $set = New-Object 'System.Collections.Generic.HashSet[string]'
  if (-not $normText) { return $set }
  foreach ($cls in $script:EditionTokenClasses.Keys) {
    foreach ($tok in $script:EditionTokenClasses[$cls]) {
      if (Test-EditionTokenPresent $normText $tok) { [void]$set.Add($cls); break }
    }
  }
  return $set
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
# 長い一致を優先して誤検知を減らすため、突き合わせ文字列が長い順に並べる。
# Sort-Object は安定ソートではなく、長さが同じもの同士の順序が GAMES の並びや件数で
# 変わってしまう(F2)。同じゲームで name と alias の正規化結果が同じ場合などに
# via(name/alias) が入れ替わり confidence が揺れるため、長さが同じときの順序を固定する:
#   name を alias より先(candidates を name, aliases の順に作っている意図どおり)
#   → 以降は判定に影響しない決定性のためだけの序数比較(matchText → gameName)
# キーは「長さ(降順・固定幅) / name=0・alias=1 / matchText / gameName」を連結し序数比較する
# (末尾の添字はキーを一意にして元の要素へ戻すためのもので、完全に同じ内容の要素同士でしか効かない)。
$sortKeys = New-Object System.Collections.Generic.List[string]
for ($ti = 0; $ti -lt $matchTargets.Count; $ti++) {
  $t = $matchTargets[$ti]
  $sortKeys.Add((99999 - $t.matchText.Length).ToString("D5") + $(if ($t.isAlias) { "1" } else { "0" }) + $t.matchText + [char]0 + $t.gameName + [char]0 + $ti.ToString("D6"))
}
$sortKeys.Sort([System.StringComparer]::Ordinal)
$matchTargets = @($sortKeys | ForEach-Object { $matchTargets[[int]$_.Substring($_.Length - 6)] })

# ---- 各ゲームが name / aliases のどこかに持っている版語クラス ----
#   「版語がタイトルにあるとき、その版を明示しているゲームはどれか」を判定するための表。
#   aliases に版固有語が登録されている場合(例: モンスターハンターライズ の「サンブレイク」)も
#   正当な根拠として扱えるように、name と aliases の両方から集める。
$gameEditionClasses = @{}
foreach ($o in $gameObjs) {
  $gn = Field $o "name"
  if (-not $gn) { continue }
  $set = New-Object 'System.Collections.Generic.HashSet[string]'
  foreach ($txt in (@($gn) + @(FieldArray $o "aliases"))) {
    if (-not $txt) { continue }
    # 版語の境界判定に空白が必要なため、空白を保持した正規化(collapsed)を使う
    foreach ($c in (Get-EditionClasses (Build-MatchText $txt).collapsed)) { [void]$set.Add($c) }
  }
  $gameEditionClasses[$gn] = $set
}

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
      if (-not (Test-BoundaryMatch $normTitle $t.matchText)) { continue }
      if ($matchedGames.ContainsKey($t.gameName)) {
        # 同じゲームに2つ目以降の根拠が当たった場合、判定の強さ(via/境界)は最初に
        # 記録した最長一致のものを保つが、「根拠」としては全部ためておく。
        # 後段で「どのゲームがより具体的に一致しているか」を根拠集合の包含関係から判定する。
        [void]$matchedGames[$t.gameName].evidences.Add($t.matchText)
        continue
      }
      if ($true) {
        $rec = [PSCustomObject]@{
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
          # このゲームに当たった突き合わせ文字列(name / alias)の集合
          evidences = (New-Object System.Collections.Generic.List[string])
        }
        [void]$rec.evidences.Add($t.matchText)
        $matchedGames[$t.gameName] = $rec
        $titleMatches.Add($rec)
      }
    }
    if ($titleMatches.Count -eq 0) { continue }

    # ---- A-2: 版語と根拠の具体性で候補を絞る ----
    #   原則A: タイトルの版語が候補ゲームの name / aliases に明示されている場合、
    #          その一致は正当な強い根拠として扱い、版語を理由に落とさない。
    #   原則B: タイトルに版語があるのに、どの候補もその版を明示していない場合は
    #          自動確定させない(HIGHへ上げない)。
    #   原則C: 複数の根拠が同じゲームへ収束している場合は ambiguous にしない。
    #          ただし根拠が増えただけで confidence を無条件に上げることはしない。
    #   原則D: 別ゲームが複数残る場合は従来どおり ambiguous のまま。
    # タイトル側も空白を保持した collapsed で判定する(理由は $gameEditionClasses と同じ)
    $titleEditionClasses = Get-EditionClasses $titleCtx.collapsed
    foreach ($tm in $titleMatches) {
      $backed = $false
      if ($titleEditionClasses.Count -gt 0 -and $gameEditionClasses.ContainsKey($tm.game)) {
        foreach ($c in $titleEditionClasses) { if ($gameEditionClasses[$tm.game].Contains($c)) { $backed = $true; break } }
      }
      $tm | Add-Member -NotePropertyName editionBacked -NotePropertyValue $backed -Force
    }
    $preferredGame = $null
    $preferredBy = ""
    if ($titleMatches.Count -gt 1) {
      # 原則A: 版語の裏付けを持つ候補を優先する。
      #   複数の候補が裏付けを持つ場合は「タイトルの版語クラスをより多く満たす」方が
      #   具体的なので、被覆数が唯一最大の候補だけを採用する。同数で並ぶ場合は
      #   どちらとも決められないため従来どおり ambiguous のままにする(原則D)。
      $backedGames = @($titleMatches | Where-Object { $_.editionBacked })
      if ($backedGames.Count -ge 1) {
        $bestCover = -1; $bestGame = $null; $bestTied = $false
        foreach ($bg in $backedGames) {
          $cover = 0
          foreach ($c in $titleEditionClasses) { if ($gameEditionClasses[$bg.game].Contains($c)) { $cover++ } }
          if ($cover -gt $bestCover) { $bestCover = $cover; $bestGame = $bg.game; $bestTied = $false }
          elseif ($cover -eq $bestCover) { $bestTied = $true }
        }
        if (-not $bestTied -and $bestGame) {
          $preferredGame = $bestGame
          $preferredBy = "edition-token"
        }
      }
      if (-not $preferredGame -and $backedGames.Count -eq 0) {
        # 原則C: 根拠集合が他候補すべてを包含し、かつ自身が追加の根拠を持つ候補を優先する
        foreach ($cand in $titleMatches) {
          $isDominant = $true
          foreach ($other in $titleMatches) {
            if ($other.game -eq $cand.game) { continue }
            if ($cand.evidences.Count -le $other.evidences.Count) { $isDominant = $false; break }
            foreach ($ev in $other.evidences) { if (-not $cand.evidences.Contains($ev)) { $isDominant = $false; break } }
            if (-not $isDominant) { break }
          }
          if ($isDominant) { $preferredGame = $cand.game; $preferredBy = "evidence-subsumption"; break }
        }
      }
    }
    # 原則B の適用条件: タイトルに版語があるのに裏付け候補が1件も無い
    # 原則B の判定では、上限対象外クラス(拡張/DLC)だけの場合はキャップしない
    $capClasses = @($titleEditionClasses | Where-Object { $script:EditionClassesExemptFromCap -notcontains $_ })
    $editionUnbacked = ($capClasses.Count -gt 0) -and ((@($titleMatches | Where-Object { $_.editionBacked })).Count -eq 0)

    $isNonGame = $false
    foreach ($kw in $nonGameKeywords) {
      if ($normTitle.Contains($kw) -or $normDesc.Contains($kw)) { $isNonGame = $true; break }
    }

    foreach ($m in $titleMatches) {
      # 優先候補が決まった場合、具体性で劣る候補は候補一覧から落とす
      # (落とした側は優先候補の otherMatches に残るので追跡できる)
      if ($preferredGame -and $m.game -ne $preferredGame) { continue }
      if ($GapOnly -and $m.currentPlaylistCount -ge 2) { continue }
      $seq++
      $ambiguous = ($titleMatches.Count -gt 1) -and (-not $preferredGame)
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
      # 原則B: タイトルが版を主張しているのにカタログ側がその版を区別していない場合、
      #        自動確定させず人間確認へ送る(HIGH には上げない)。
      if ($editionUnbacked -and $confidence -eq "HIGH") { $confidence = "MEDIUM" }
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
        editionTokens  = @($titleEditionClasses | Sort-Object)
        editionBacked  = $m.editionBacked
        preferredBy    = $preferredBy
        matchEvidence  = @($m.evidences)
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
