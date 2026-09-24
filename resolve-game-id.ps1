<#
.SYNOPSIS
  候補ゲーム名を data-core.js の GAMES 上の正式ゲーム名(= game ID)へ、
  安全に一意解決できる場合だけ解決するリゾルバ。

.DESCRIPTION
  「実在するゲームのplaylistだと判断できているのに、表記揺れのために
  game IDを確定できず HOLD_GAME_ID になる」問題を減らすための処理単位。

  GAMES / STREAMERS には id フィールドが無く、name が主キー(= game ID)である。
  したがって解決結果の gameId は正式ゲーム名そのものを指す。

  解決は次の優先順位で行い、ここまでを「自動解決可能範囲」とする。

    LEVEL 1 exact           … 正式ゲーム名と完全一致(生文字列)
    LEVEL 2 alias-exact     … 既存 aliases と完全一致(生文字列)
    LEVEL 3 normalized-exact… 正規化後に正式ゲーム名と完全一致
    LEVEL 4 canonical-alias … 正規化後に aliases と完全一致

  正規化は次のみを行う(意味を変えない範囲に限定する)。
    - Unicode正規化(NFKC。全角英数字・全角記号を半角へ)
    - カタカナ→ひらがな(サイト内検索 common.js / match-playlist-candidates.ps1 と同一基準)
    - 大文字小文字の統一
    - 前後空白の除去・連続空白の単一化・空白の完全除去
    - 一般的な区切り記号の除去(・/:/-/~/,/. などの装飾差)

  次は自動確定しない(仕様として禁止)。
    - 部分一致だけでの確定
    - 曖昧一致だけでの確定
    - シリーズ名だけでの確定
    - YouTubeタイトルからの推測による確定
    - Levenshtein距離等のあいまい距離だけでの確定

  同一レベルで複数のゲームが該当した場合は ambiguous として解決しない。
  これは正規化によって別ゲームが同一文字列に潰れる衝突を含む。

.PARAMETER Name
  解決したい候補ゲーム名。指定すると1件だけ解決して結果を表示する。

.PARAMETER Audit
  既存GAMES全体に対して、正規化衝突・alias衝突・canonical alias衝突を監査する。

.PARAMETER SelfTest
  リゾルバの回帰テストを実行する。

.PARAMETER Json
  結果をJSONで書き出す先(任意)。

.EXAMPLE
  .\resolve-game-id.ps1 -Name "ドラゴンクエストV 天空の花嫁"
.EXAMPLE
  .\resolve-game-id.ps1 -Audit
.EXAMPLE
  .\resolve-game-id.ps1 -SelfTest
#>
param(
  [string]$Name,
  [switch]$Audit,
  [switch]$SelfTest,
  [string]$Json,
  [string]$CorePath
)

$ErrorActionPreference = "Stop"
if (-not $CorePath) { $CorePath = Join-Path $PSScriptRoot "data-core.js" }

# ---- パーサ(既存スクリプトと同じ手法) ----
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
    if ($ch -eq '[') { $depth++ }
    elseif ($ch -eq ']') { $depth--; if ($depth -eq 0) { return $text.Substring($i, $p - $i) } }
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
    if ($ch -eq '{') { if ($depth -eq 0) { $start = $i }; $depth++ }
    elseif ($ch -eq '}') { $depth--; if ($depth -eq 0 -and $start -ge 0) { $results += $inner.Substring($start, $i - $start + 1); $start = -1 } }
  }
  return $results
}
function Field([string]$obj, [string]$name) {
  $m = [regex]::Match($obj, [regex]::Escape($name) + '\s*:\s*"((?:\\.|[^"])*)"')
  if ($m.Success) { return ($m.Groups[1].Value -replace '\\"', '"' -replace '\\\\', '\') }
  return ""
}
function FieldArray([string]$obj, [string]$name) {
  $m = [regex]::Match($obj, [regex]::Escape($name) + '\s*:\s*\[([^\]]*)\]')
  if (-not $m.Success) { return @() }
  return @([regex]::Matches($m.Groups[1].Value, '"((?:\\.|[^"])*)"') | ForEach-Object { $_.Groups[1].Value })
}

# ---- 正規化 ----
function ConvertTo-HiraganaText([string]$s) {
  $sb = New-Object System.Text.StringBuilder
  foreach ($ch in $s.ToCharArray()) {
    if ($ch -ge [char]0x30A1 -and $ch -le [char]0x30F6) { [void]$sb.Append([char]([int]$ch - 0x60)) }
    else { [void]$sb.Append($ch) }
  }
  return $sb.ToString()
}

# 区切り・装飾のみの記号。意味を変えないものだけを対象にする
# (英数字・かな・漢字は一切落とさない)。
$script:GameIdSeparators = @(
  ' ', "`t", '　',
  '・', '·', '･',
  '-', '‐', '‑', '‒', '–', '—', '―', 'ー',
  '~', '〜', '～',
  ':', '：', ';', '；',
  ',', '、', '，',
  '.', '。', '．',
  '/', '／', '\', '＼',
  '_', '＿'
)

function Get-GameIdNormalizedText([string]$s) {
  if (-not $s) { return "" }
  $n = $s.Normalize([System.Text.NormalizationForm]::FormKC)   # 全角英数字・全角記号 -> 半角
  $n = ConvertTo-HiraganaText $n                                # カタカナ -> ひらがな
  $n = $n.ToLowerInvariant().Trim()
  $n = ($n -replace '\s+', ' ')                                 # 連続空白を1つに
  $sb = New-Object System.Text.StringBuilder
  foreach ($ch in $n.ToCharArray()) {
    if ($script:GameIdSeparators -contains ([string]$ch)) { continue }  # 区切り記号は除去
    [void]$sb.Append($ch)
  }
  return $sb.ToString()
}

# 語順入れ替え(アナグラム)正規形。
#   正規化後の文字を序数順に並べ替えた「文字の多重集合」を鍵にする。
#   構成文字が1文字でも違えば一致しないため、部分一致や編集距離のような
#   「近いから通す」判定ではなく、あくまで完全一致の一種である。
#   短い名前は偶然の一致が起きやすいので、下限長に満たないものは鍵を作らない。
$script:GameIdMinPermutationLength = 8
function Get-GameIdPermutationKey([string]$s) {
  $n = Get-GameIdNormalizedText $s
  if (-not $n) { return "" }
  if ($n.Length -lt $script:GameIdMinPermutationLength) { return "" }
  $chars = $n.ToCharArray()
  [array]::Sort($chars)
  return (-join $chars)
}

# 数字・ローマ数字に使われる文字。続編番号/ナンバリングの判別に使う。
$script:GameIdNumeralChars = "0123456789ivxlcdm"
# 2つの正規化文字列の、共通する先頭長 $p と末尾長 $t、および相違部分を返す。
function Get-GameIdDiffRegion([string]$a, [string]$b) {
  $p = 0
  while ($p -lt $a.Length -and $p -lt $b.Length -and $a[$p] -ceq $b[$p]) { $p++ }
  $t = 0
  while (($t -lt ($a.Length - $p)) -and ($t -lt ($b.Length - $p)) -and ($a[$a.Length - 1 - $t] -ceq $b[$b.Length - 1 - $t])) { $t++ }
  return [PSCustomObject]@{
    prefix = $p; suffix = $t
    da = $a.Substring($p, $a.Length - $p - $t)
    db = $b.Substring($p, $b.Length - $p - $t)
  }
}

function Test-GameIdNumeralOnlyDifference([string]$a, [string]$b) {
  # 相違部分が数字・ローマ数字だけで構成されているかを調べる。
  # 例: finalfantasyiv / finalfantasyvi -> 相違部分 "iv" / "vi" は数字のみ -> $true
  #     FF IV と FF VI は語順入れ替えでは区別できないため、一致させてはいけない。
  if ($a -ceq $b) { return $false }
  $d = Get-GameIdDiffRegion $a $b
  if (-not $d.da -and -not $d.db) { return $false }
  foreach ($ch in ($d.da + $d.db).ToCharArray()) {
    if ($script:GameIdNumeralChars.IndexOf([string]$ch, [System.StringComparison]::Ordinal) -lt 0) { return $false }
  }
  return $true
}

# 並べ替えが「局所的」かどうか。
#   語順入れ替えは本来「タイトルの一部が入れ替わった表記ゆれ」を拾うためのもので、
#   文字列全体が総入れ替えになっている一致は、意味の近さではなく偶然である可能性が高い。
#   実例: DELTARUNE と UNDERTALE は構成文字が完全に同じ別作品で、共通の先頭が0文字。
#   そこで「先頭が一定数一致していること」と「入れ替わらなかった部分が一定割合以上
#   残っていること」を要求し、全面スクランブルは採用しない。
$script:GameIdMinPermutationPrefix = 2
$script:GameIdMinPermutationKeepRatio = 0.40
function Test-GameIdLocalRearrangement([string]$a, [string]$b) {
  if ($a.Length -eq 0) { return $false }
  $d = Get-GameIdDiffRegion $a $b
  if ($d.prefix -lt $script:GameIdMinPermutationPrefix) { return $false }
  $keep = ($d.prefix + $d.suffix) / [double]$a.Length
  return ($keep -ge $script:GameIdMinPermutationKeepRatio)
}

# ---- インデックス構築 ----
function Get-GameIdIndex([string]$corePath) {
  $coreText = [System.IO.File]::ReadAllText($corePath, [System.Text.Encoding]::UTF8)
  $gameObjs = Get-Objects (Get-ArrayInner "GAMES" $coreText)

  $games = New-Object System.Collections.Generic.List[object]
  foreach ($o in $gameObjs) {
    $n = Field $o "name"
    if (-not $n) { continue }
    $games.Add([PSCustomObject]@{
      name    = $n
      series  = Field $o "series"
      aliases = @(FieldArray $o "aliases")
    })
  }

  # 各インデックスは「キー -> 該当ゲーム名の集合」。集合サイズが2以上なら衝突。
  # PowerShellの @{} は既定で大文字小文字を区別しないため、LEVEL1/2 の「完全一致」が
  # 意図せず case-insensitive になってしまう。序数比較のDictionaryを使って厳密にする
  # (大文字小文字だけが異なる名前は LEVEL3 の正規化一致で拾う)。
  function New-OrdinalMap {
    return New-Object 'System.Collections.Generic.Dictionary[string,System.Collections.Generic.HashSet[string]]'([StringComparer]::Ordinal)
  }
  $exact = New-OrdinalMap; $aliasExact = New-OrdinalMap; $norm = New-OrdinalMap; $normAlias = New-OrdinalMap
  $permuted = New-OrdinalMap; $permutedSrc = New-OrdinalMap
  function Add-Key($map, [string]$key, [string]$gameName) {
    if (-not $key) { return }
    if (-not $map.ContainsKey($key)) { $map[$key] = New-Object 'System.Collections.Generic.HashSet[string]' }
    [void]$map[$key].Add($gameName)
  }
  foreach ($g in $games) {
    Add-Key $exact      $g.name                              $g.name
    Add-Key $norm       (Get-GameIdNormalizedText $g.name)    $g.name
    # 語順入れ替え鍵は正式名・aliasの両方から作る。permutedSrc にはその鍵を
    # 生み出した正規化文字列を持たせ、後段の続編番号ガードで使う。
    Add-Key $permuted    (Get-GameIdPermutationKey $g.name)    $g.name
    Add-Key $permutedSrc (Get-GameIdPermutationKey $g.name)    (Get-GameIdNormalizedText $g.name)
    foreach ($a in $g.aliases) {
      if (-not $a) { continue }
      Add-Key $aliasExact $a                                 $g.name
      Add-Key $normAlias  (Get-GameIdNormalizedText $a)       $g.name
      Add-Key $permuted    (Get-GameIdPermutationKey $a)       $g.name
      Add-Key $permutedSrc (Get-GameIdPermutationKey $a)       (Get-GameIdNormalizedText $a)
    }
  }
  return [PSCustomObject]@{
    games      = $games.ToArray()
    exact      = $exact
    aliasExact = $aliasExact
    normalized = $norm
    normAlias  = $normAlias
    permuted    = $permuted
    permutedSrc = $permutedSrc
  }
}

# ---- alias所有インデックス (alias ownership index) ----
#   正規化alias -> そのaliasを持つgameの集合。$index.normAlias がそのまま該当する。
#   シリーズ略称のように複数の作品が正当に共有するaliasは存在するため、aliasを
#   消すのではなく「共有aliasだけを根拠に一意確定しない」ために使う。
function Get-GameIdAliasOwners($index, [string]$aliasText) {
  $empty = New-Object 'System.Collections.Generic.HashSet[string]'
  if (-not $index) { return $empty }
  if (-not (@($index.PSObject.Properties.Name) -contains "normAlias")) { return $empty }
  $nz = Get-GameIdNormalizedText $aliasText
  if (-not $nz) { return $empty }
  if (-not $index.normAlias.ContainsKey($nz)) { return $empty }
  return $index.normAlias[$nz]
}

# ---- 解決本体 ----
# 戻り値: gameId / matchedName / matchType / confidence / ambiguous / candidateIds
function Resolve-GameId($candidateGameName, $index) {
  $empty = [PSCustomObject]@{
    candidateGameName = $candidateGameName
    gameId = $null; matchedName = $null; matchType = "not-found"
    confidence = "none"; ambiguous = $false; candidateIds = @()
  }
  if (-not $candidateGameName) { return $empty }
  if (-not $index) { return $empty }

  $levels = @(
    @{ map = $index.exact;      key = $candidateGameName;                                    type = "exact";            conf = "high" },
    @{ map = $index.aliasExact; key = $candidateGameName;                                    type = "alias-exact";      conf = "high"; aliasOwnership = $true },
    @{ map = $index.normalized; key = (Get-GameIdNormalizedText $candidateGameName);         type = "normalized-exact"; conf = "high" },
    @{ map = $index.normAlias;  key = (Get-GameIdNormalizedText $candidateGameName);         type = "canonical-alias";  conf = "medium"; aliasOwnership = $true }
  )

  foreach ($lv in $levels) {
    $key = $lv.key
    if (-not $key) { continue }
    if (-not $lv.map.ContainsKey($key)) { continue }
    $hits = @($lv.map[$key])
    if ($hits.Count -eq 1) {
      # 共有alias(複数gameが所有する略称)だけを根拠に一意確定しない。
      #   生aliasキーの上では単独所有に見えても、表記ゆれを正規化すると同じaliasを
      #   複数のgameが持っている場合がある(例: 半角「FF」と全角「ＦＦ」)。その場合は
      #   alias所有インデックスに従って ambiguous として扱い、manual-reviewへ送る。
      #   正式タイトル一致(LEVEL1/LEVEL3)はこの判定を通らないため、作品固有情報を
      #   含むタイトルの既存判定は妨げない。
      if ($lv.aliasOwnership) {
        $owners = Get-GameIdAliasOwners $index $key
        if ($owners.Count -ge 2) {
          return [PSCustomObject]@{
            candidateGameName = $candidateGameName
            gameId = $null; matchedName = $null; matchType = "ambiguous"
            confidence = "none"; ambiguous = $true; candidateIds = @($owners | Sort-Object)
          }
        }
      }
      return [PSCustomObject]@{
        candidateGameName = $candidateGameName
        gameId = $hits[0]; matchedName = $hits[0]; matchType = $lv.type
        confidence = $lv.conf; ambiguous = $false; candidateIds = @($hits[0])
      }
    }
    # 同一レベルで複数該当 = 一意確定できない。下位レベルへ降りず ambiguous で打ち切る。
    return [PSCustomObject]@{
      candidateGameName = $candidateGameName
      gameId = $null; matchedName = $null; matchType = "ambiguous"
      confidence = "none"; ambiguous = $true; candidateIds = @($hits | Sort-Object)
    }
  }

  # LEVEL 5: 語順入れ替え一致 (permuted-exact)
  #   LEVEL 1-4 がどれも鍵を持たなかった場合だけ到達する最終手段。
  #   構成文字が完全に同じで並び順だけが違うものを拾う
  #   (例:「ゼルダの伝説スカイソードウォード」->「ゼルダの伝説 スカイウォードソード」)。
  #   次の3条件をすべて満たすときだけ確定させる。
  #     (a) 正規化後の長さが下限以上   … Get-GameIdPermutationKey が保証
  #     (b) カタログ全体で該当が1件だけ … 2件以上なら ambiguous で打ち切る
  #     (c) 相違部分が数字・ローマ数字だけではない … 続編番号の取り違え防止
  #     (d) 並べ替えが局所的である … 全面スクランブル(偶然のアナグラム)を排除
  if (@($index.PSObject.Properties.Name) -contains "permuted") {
    $pkey = Get-GameIdPermutationKey $candidateGameName
    if ($pkey -and $index.permuted.ContainsKey($pkey)) {
      $phits = @($index.permuted[$pkey])
      if ($phits.Count -gt 1) {
        return [PSCustomObject]@{
          candidateGameName = $candidateGameName
          gameId = $null; matchedName = $null; matchType = "ambiguous"
          confidence = "none"; ambiguous = $true; candidateIds = @($phits | Sort-Object)
        }
      }
      $qn = Get-GameIdNormalizedText $candidateGameName
      $blocked = $false
      foreach ($src in @($index.permutedSrc[$pkey])) {
        if (Test-GameIdNumeralOnlyDifference $qn $src) { $blocked = $true; break }
        if (-not (Test-GameIdLocalRearrangement $qn $src)) { $blocked = $true; break }
      }
      if (-not $blocked) {
        return [PSCustomObject]@{
          candidateGameName = $candidateGameName
          gameId = $phits[0]; matchedName = $phits[0]; matchType = "permuted-exact"
          confidence = "medium"; ambiguous = $false; candidateIds = @($phits[0])
        }
      }
    }
  }
  return $empty
}

# ============================================================
# 実行モード
# ============================================================
$index = Get-GameIdIndex $CorePath
$result = $null

if ($Audit) {
  Write-Output "=== 既存GAMES 衝突監査 (対象 $($index.games.Count) ゲーム) ==="
  # 注意: 値を返す関数の中で Write-Output すると戻り値に混入するため、
  # 収集(Get-Collisions)と表示(インライン)を分離する。
  function Get-Collisions($map) {
    $col = New-Object System.Collections.Generic.List[object]
    foreach ($k in $map.Keys) {
      if ($map[$k].Count -gt 1) { $col.Add([PSCustomObject]@{ key = $k; games = @($map[$k] | Sort-Object) }) }
    }
    return ,$col.ToArray()
  }
  $sets = @(
    @{ label = "exact collision (正式名の重複)";                map = $index.exact },
    @{ label = "normalized collision (正規化後の衝突)";         map = $index.normalized },
    @{ label = "alias collision (生aliasの重複)";               map = $index.aliasExact },
    @{ label = "canonical alias collision (正規化alias衝突)";   map = $index.normAlias }
  )
  $collected = @()
  foreach ($s in $sets) {
    $col = Get-Collisions $s.map
    $collected += ,$col
    Write-Output ("{0}: {1}件" -f $s.label, $col.Count)
    foreach ($c in (@($col) | Sort-Object { $_.games.Count } -Descending | Select-Object -First 8)) {
      Write-Output ("  `"{0}`" -> {1}件: {2}" -f $c.key, $c.games.Count, ((@($c.games) | Select-Object -First 4) -join ' / '))
    }
    if ($col.Count -gt 8) { Write-Output ("  …他 {0}件" -f ($col.Count - 8)) }
    Write-Output ""
  }
  $c1 = $collected[0]; $c2 = $collected[1]; $c3 = $collected[2]; $c4 = $collected[3]
  $result = [PSCustomObject]@{
    totalGames = $index.games.Count
    exactCollision = $c1.Count; normalizedCollision = $c2.Count
    aliasCollision = $c3.Count; canonicalAliasCollision = $c4.Count
    details = [ordered]@{ exact = $c1; normalized = $c2; alias = $c3; canonicalAlias = $c4 }
  }
}
elseif ($SelfTest) {
  $cases = @(
    @{ n = "1. 正式名完全一致";        input = "ドラゴンクエストV 天空の花嫁"; expectType = "exact";            expectId = "ドラゴンクエストV 天空の花嫁" },
    @{ n = "2. alias完全一致";         input = "マイクラ";                      expectType = "alias-exact";      expectId = "Minecraft" },
    @{ n = "3. 正規化完全一致(空白差)"; input = "ドラゴンクエストV天空の花嫁";   expectType = "normalized-exact"; expectId = "ドラゴンクエストV 天空の花嫁" },
    @{ n = "3b. 正規化(全角英数)";      input = "ドラゴンクエストＶ 天空の花嫁"; expectType = "normalized-exact"; expectId = "ドラゴンクエストV 天空の花嫁" },
    @{ n = "3c. 正規化(大文字小文字)";  input = "minecraft";                     expectType = "normalized-exact"; expectId = "Minecraft" },
    @{ n = "4. canonical alias(表記差)"; input = "サイレントヒル2";              expectType = "canonical-alias";  expectId = "SILENT HILL 2" },
    @{ n = "5. 存在しないゲーム";       input = "存在しないゲームZZZ";           expectType = "not-found";        expectId = $null },
    @{ n = "6. 複数候補衝突(alias)";    input = "ドラクエ";                      expectType = "ambiguous";        expectId = $null },
    @{ n = "6b. 正規化衝突(中黒除去)";  input = "ドラゴンクエストIII";           expectType = "exact";            expectId = "ドラゴンクエストIII" },
    @{ n = "6c. 正規化衝突(潰れた形)";  input = "ドラゴンクエストIII ";          expectType = "ambiguous";        expectId = $null },
    @{ n = "7. シリーズ名のみ";         input = "ドラゴンクエストシリーズ";      expectType = "exact";            expectId = "ドラゴンクエストシリーズ" },
    @{ n = "8. 部分一致(自動確定しない)"; input = "ドラクエV";                   expectType = "not-found";        expectId = $null },
    @{ n = "8b. 部分一致(先頭語のみ)";  input = "ゼルダの伝説 TOTK";             expectType = "not-found";        expectId = $null },
    @{ n = "9. 誤ったゲーム名";         input = "ドラゴンクエストV 天空の花婿";  expectType = "not-found";        expectId = $null },
    @{ n = "10a. 第3回HOLD候補1の指定"; input = "ドラゴンクエストX";             expectType = "exact";            expectId = "ドラゴンクエストX" },
    @{ n = "10b. 第3回HOLD候補1の証拠"; input = "ドラゴンクエストV 天空の花嫁";  expectType = "exact";            expectId = "ドラゴンクエストV 天空の花嫁" },
    @{ n = "10c. 第3回HOLD候補1の生タイトル"; input = "〖ドラクエV〗";           expectType = "not-found";        expectId = $null },
    @{ n = "10d. 第3回HOLD候補4の指定"; input = "ときめきメモリアル Girl's Side"; expectType = "exact";           expectId = "ときめきメモリアル Girl's Side" },
    @{ n = "10e. 第3回HOLD候補4(空白差)"; input = "ときめきメモリアルGirl's Side"; expectType = "normalized-exact"; expectId = "ときめきメモリアル Girl's Side" },
    @{ n = "10f. 第3回HOLD候補4の略称"; input = "ときめきメモリアルGS";          expectType = "not-found";        expectId = $null },
    # --- LEVEL5 語順入れ替え一致 ---
    @{ n = "11. 語順入れ替え(今回の候補8)"; input = "ゼルダの伝説スカイソードウォード"; expectType = "permuted-exact"; expectId = "ゼルダの伝説 スカイウォードソード" },
    @{ n = "11b. 語順入れ替え+空白差";   input = "ゼルダの伝説 スカイ ソード ウォード"; expectType = "permuted-exact"; expectId = "ゼルダの伝説 スカイウォードソード" },
    @{ n = "11c. 語順入れ替え+全角カナ差"; input = "ゼルダの伝説スカイソードウォード"; expectType = "permuted-exact"; expectId = "ゼルダの伝説 スカイウォードソード" },
    @{ n = "12. 続編番号ガード(XI vs IX)"; input = "ドラゴンクエストXI";           expectType = "not-found";        expectId = $null },
    @{ n = "12b. 続編番号ガード(FF語順)"; input = "FANTASY FINAL VI";              expectType = "ambiguous";        expectId = $null },
    @{ n = "13. 短い名前は語順入れ替え対象外"; input = "すりとて";                  expectType = "not-found";        expectId = $null },
    @{ n = "14. 語順入れ替えでも一致0件"; input = "存在しないゲーム名ZZZZZZZZ";   expectType = "not-found";        expectId = $null },
    @{ n = "15. 別ゲームの文字を混ぜた偽名"; input = "ゼルダの伝説スカイウォードソードX"; expectType = "not-found";  expectId = $null },
    @{ n = "16. 偶然の完全アナグラム(別作品)"; input = "DELTARUNE";                    expectType = "not-found";        expectId = $null },
    @{ n = "16b. 同上(小文字表記)";      input = "Deltarune";                        expectType = "not-found";        expectId = $null },
    @{ n = "17. 局所的な並べ替え(語順)";  input = "ドラゴンクエストXI 過ぎ去りし時を求めて S"; expectType = "permuted-exact"; expectId = "ドラゴンクエストXI S 過ぎ去りし時を求めて" },
    @{ n = "18. 局所的な並べ替え(かな入替)"; input = "おにぎり屋さんシュミレーター"; expectType = "permuted-exact"; expectId = "おにぎり屋さんシミュレーター" },
    # --- 共有alias(複数gameが所有する略称) ---
    @{ n = "19. 共有alias単独(モンハン)";  input = "モンハン";                        expectType = "ambiguous";        expectId = $null },
    @{ n = "19b. 共有alias単独(MGS)";     input = "MGS";                           expectType = "ambiguous";        expectId = $null },
    @{ n = "19c. 共有alias単独(キムタク)"; input = "キムタク";                       expectType = "ambiguous";        expectId = $null },
    @{ n = "19d. 共有alias(ひらがな表記)"; input = "きむたく";                       expectType = "ambiguous";        expectId = $null },
    @{ n = "20. 単独所有aliasは従来どおり"; input = "MGSΔ";                          expectType = "alias-exact";      expectId = "METAL GEAR SOLID Δ: SNAKE EATER" },
    @{ n = "20b. 単独所有alias(新規game)"; input = "キャラバンハート";               expectType = "alias-exact";      expectId = "ドラゴンクエストモンスターズ キャラバンハート" },
    # --- シリーズ+ナンバリング / 版 / 表記 ---
    @{ n = "21. シリーズ+ナンバリング";    input = "FINAL FANTASY VII";             expectType = "exact";            expectId = "FINAL FANTASY VII" },
    @{ n = "21b. 共有alias+ナンバリング";  input = "ドラクエXI";                     expectType = "not-found";        expectId = $null },
    @{ n = "22. Remake(正式名)";          input = "FINAL FANTASY VII REMAKE";      expectType = "exact";            expectId = "FINAL FANTASY VII REMAKE" },
    @{ n = "22b. Remake(共有alias+版)";   input = "FF7 REMAKE";                    expectType = "not-found";        expectId = $null },
    @{ n = "23. HD版(正式名)";            input = "ゼルダの伝説 スカイウォードソード HD"; expectType = "exact";        expectId = "ゼルダの伝説 スカイウォードソード HD" },
    @{ n = "24. 日本語表記(alias)";        input = "サイレントヒル2";                expectType = "canonical-alias";  expectId = "SILENT HILL 2" },
    @{ n = "25. 英語表記(alias)";          input = "Silent Hill 2";                 expectType = "alias-exact";      expectId = "SILENT HILL 2" },
    @{ n = "26. 新規game 正式名";          input = "METAL GEAR SOLID Δ: SNAKE EATER"; expectType = "exact";          expectId = "METAL GEAR SOLID Δ: SNAKE EATER" },
    @{ n = "27. 新規game 正式名(和名)";    input = "星のカービィ 夢の泉の物語";       expectType = "exact";            expectId = "星のカービィ 夢の泉の物語" },
    # --- 大型DLC/拡張は本編gameのaliasとして解決する(独立game IDは作らない) ---
    @{ n = "28. 拡張名 単独(サンブレイク)";   input = "サンブレイク";                    expectType = "alias-exact";      expectId = "モンスターハンターライズ" },
    @{ n = "28b. 拡張名 単独(ゼロの秘宝)";   input = "ゼロの秘宝";                     expectType = "alias-exact";      expectId = "ポケットモンスター スカーレット・バイオレット" },
    # 複合タイトルは resolver では確定しない(部分一致による自動確定を行わない仕様)。
    # playlist題名からの候補生成は match-playlist-candidates.ps1 側の責務。
    @{ n = "28c. 拡張名を含む複合タイトル";   input = "モンハンサンブレイク";             expectType = "not-found";        expectId = $null },
    @{ n = "28d. 拡張名を含む複合タイトル2";  input = "ポケモンSV 「ゼロの秘宝」";        expectType = "not-found";        expectId = $null },
    # --- 定着した短縮カナ表記(ブレワイ)。単独所有aliasなので一意確定してよい ---
    @{ n = "29. 短縮カナalias 単独(ブレワイ)"; input = "ブレワイ";                       expectType = "alias-exact";      expectId = "ゼルダの伝説 ブレス オブ ザ ワイルド" },
    @{ n = "29b. 同上(ひらがな表記)";        input = "ぶれわい";                       expectType = "canonical-alias";  expectId = "ゼルダの伝説 ブレス オブ ザ ワイルド" },
    @{ n = "29c. 同上(半角カナ表記)";        input = "ﾌﾞﾚﾜｲ";                        expectType = "canonical-alias";  expectId = "ゼルダの伝説 ブレス オブ ザ ワイルド" },
    @{ n = "29d. 短縮aliasを含む複合タイトル"; input = "ゼルダの伝説 ブレワイ";            expectType = "not-found";        expectId = $null },
    @{ n = "29e. 短縮alias+ナンバリング";     input = "ブレワイ2";                      expectType = "not-found";        expectId = $null },
    # --- 英字3文字の略称(BOW)はaliasに登録していないため一致しないこと。
    #     一般語・別作品名(Rainbow / BOWIE / BOWMAN)に埋もれた誤爆も起きないこと ---
    @{ n = "30. 未登録の3文字略称(BOW)";     input = "BOW";                           expectType = "not-found";        expectId = $null },
    @{ n = "30b. 同上(小文字)";              input = "bow";                           expectType = "not-found";        expectId = $null },
    @{ n = "30c. 一般語(Rainbow)";           input = "Rainbow";                       expectType = "not-found";        expectId = $null },
    @{ n = "30d. 人名(BOWIE)";               input = "BOWIE";                         expectType = "not-found";        expectId = $null },
    @{ n = "30e. 一般語(BOWMAN)";            input = "BOWMAN";                        expectType = "not-found";        expectId = $null },
    @{ n = "30f. bowを含む既存gameは自分自身へ"; input = "Rainbow Six Siege";            expectType = "exact";            expectId = "Rainbow Six Siege" },
    # --- 英字略称 APEX。大文字小文字・全角半角は正規化で吸収されるため alias は1件だけ登録する ---
    @{ n = "31. 英字略称alias 単独(APEX)";    input = "APEX";                          expectType = "alias-exact";      expectId = "Apex Legends" },
    @{ n = "31b. 同上(小文字)";               input = "apex";                          expectType = "canonical-alias";  expectId = "Apex Legends" },
    @{ n = "31c. 同上(先頭大文字)";           input = "Apex";                          expectType = "canonical-alias";  expectId = "Apex Legends" },
    @{ n = "31d. 同上(全角)";                 input = "ＡＰＥＸ";                       expectType = "canonical-alias";  expectId = "Apex Legends" },
    @{ n = "31e. 正式名は従来どおり";         input = "Apex Legends";                  expectType = "exact";            expectId = "Apex Legends" },
    @{ n = "31f. 数字が続く場合は一致しない"; input = "APEX2";                         expectType = "not-found";        expectId = $null },
    @{ n = "31g. 英字が続く場合は一致しない"; input = "apexpredator";                  expectType = "not-found";        expectId = $null },
    # --- 定着した略称 プロセカ。表記ゆれは正規化で吸収されるため alias は1件だけ登録する ---
    @{ n = "32. 定着した略称alias 単独(プロセカ)"; input = "プロセカ";                    expectType = "alias-exact";      expectId = "プロジェクトセカイ" },
    @{ n = "32b. 同上(ひらがな)";             input = "ぷろせか";                      expectType = "canonical-alias";  expectId = "プロジェクトセカイ" },
    @{ n = "32c. 同上(半角カナ)";             input = "ﾌﾟﾛｾｶ";                       expectType = "canonical-alias";  expectId = "プロジェクトセカイ" },
    @{ n = "32d. 正式名は従来どおり";         input = "プロジェクトセカイ";            expectType = "exact";            expectId = "プロジェクトセカイ" },
    @{ n = "32e. 数字が続く場合は一致しない"; input = "プロセカ2";                     expectType = "not-found";        expectId = $null },
    # 英語表記は alias 未登録のため既存どおり not-found。今回の追加で挙動が変わらないことを固定する
    @{ n = "32f. 英語表記は既存どおり";       input = "Project Sekai";                 expectType = "not-found";        expectId = $null },
    # --- 作品固有の略称 ポケモンZA。「ZA」「Z-A」単独や他のポケモン作品には効かないこと ---
    @{ n = "33. 作品略称alias 単独(ポケモンZA)"; input = "ポケモンZA";                   expectType = "alias-exact";      expectId = "Pokémon LEGENDS Z-A" },
    @{ n = "33b. 同上(空白入り)";             input = "ポケモン ZA";                   expectType = "canonical-alias";  expectId = "Pokémon LEGENDS Z-A" },
    @{ n = "33c. 複合タイトルは確定しない";   input = "ポケモンZA実況";                expectType = "not-found";        expectId = $null },
    @{ n = "33d. ZA単独は解決しない";         input = "ZA";                            expectType = "not-found";        expectId = $null },
    @{ n = "33e. Z-A単独は解決しない";        input = "Z-A";                           expectType = "not-found";        expectId = $null },
    @{ n = "33f. ポケモンZは解決しない";      input = "ポケモンZ";                     expectType = "not-found";        expectId = $null },
    @{ n = "33g. ポケモンSVはZAへ寄らない";   input = "ポケモンSV";                    expectType = "alias-exact";      expectId = "ポケットモンスター スカーレット・バイオレット" },
    @{ n = "33h. アルセウスは既存どおり";     input = "Pokémon LEGENDS アルセウス";    expectType = "exact";            expectId = "Pokémon LEGENDS アルセウス" },
    @{ n = "33i. Z-A正式名は既存どおり";      input = "Pokémon LEGENDS Z-A";           expectType = "exact";            expectId = "Pokémon LEGENDS Z-A" },
    # --- 作品固有の略称 ポケモンSV。「SV」単独や他のポケモン作品には効かないこと ---
    @{ n = "34. 作品略称alias 単独(ポケモンSV)"; input = "ポケモンSV";                  expectType = "alias-exact";      expectId = "ポケットモンスター スカーレット・バイオレット" },
    @{ n = "34a. 同上(全角)";                 input = "ポケモンＳＶ";                  expectType = "canonical-alias";  expectId = "ポケットモンスター スカーレット・バイオレット" },
    @{ n = "34b. 同上(小文字)";               input = "ポケモンsv";                    expectType = "canonical-alias";  expectId = "ポケットモンスター スカーレット・バイオレット" },
    @{ n = "34c. SV単独は解決しない";         input = "SV";                            expectType = "not-found";        expectId = $null },
    @{ n = "34d. ポケモンSは解決しない";      input = "ポケモンS";                     expectType = "not-found";        expectId = $null },
    @{ n = "34e. ポケモンVは解決しない";      input = "ポケモンV";                     expectType = "not-found";        expectId = $null },
    # 複合タイトルは resolver では確定しない(28c/28d と同じ理由。候補生成は matcher 側の責務)
    @{ n = "34f. 複合タイトルは確定しない";   input = "ポケモンSV実況";                expectType = "not-found";        expectId = $null },
    @{ n = "34g. 複合タイトルは確定しない2";  input = "ポケモンSVニュース";            expectType = "not-found";        expectId = $null },
    @{ n = "34h. SV正式名は既存どおり";       input = "ポケットモンスター スカーレット・バイオレット"; expectType = "exact"; expectId = "ポケットモンスター スカーレット・バイオレット" },
    @{ n = "34i. 剣盾は既存どおり";           input = "ポケットモンスター ソード・シールド"; expectType = "exact";        expectId = "ポケットモンスター ソード・シールド" },
    # --- 作品略称 アルセウス。ポケモン「アルセウス」自体を指す複合語には効かないこと ---
    @{ n = "35. 作品略称alias 単独(アルセウス)"; input = "アルセウス";                   expectType = "alias-exact";      expectId = "Pokémon LEGENDS アルセウス" },
    @{ n = "35a. 正式名は既存どおり";         input = "Pokémon LEGENDS アルセウス";    expectType = "exact";            expectId = "Pokémon LEGENDS アルセウス" },
    # 複合タイトルは resolver では確定しない(28c/28d/34f と同じ仕様)。
    # 「捕獲」「対戦」などポケモン個体を指す用法をここで拾わないことの回帰固定でもある。
    @{ n = "35b. 複合タイトルは確定しない";   input = "アルセウス実況";                expectType = "not-found";        expectId = $null },
    @{ n = "35c. 個体を指す用法は確定しない"; input = "アルセウス捕獲";                expectType = "not-found";        expectId = $null },
    @{ n = "35d. 同上(対戦)";                 input = "アルセウス対戦";                expectType = "not-found";        expectId = $null },
    @{ n = "35e. 数字が続く場合は一致しない"; input = "アルセウス2";                   expectType = "not-found";        expectId = $null },
    @{ n = "35f. 英字表記はalias未登録";      input = "ARCEUS";                        expectType = "not-found";        expectId = $null },
    @{ n = "35g. ZAは既存どおり";             input = "ポケモンZA";                    expectType = "alias-exact";      expectId = "Pokémon LEGENDS Z-A" },
    @{ n = "35h. SVは既存どおり";             input = "ポケモンSV";                    expectType = "alias-exact";      expectId = "ポケットモンスター スカーレット・バイオレット" },
    @{ n = "35i. SV単独は今回も解決しない";   input = "SV";                            expectType = "not-found";        expectId = $null },
    # --- 英語公式名 Genshin Impact。「Genshin」単独や複合語には効かないこと ---
    @{ n = "36. 英語公式名alias(Genshin Impact)"; input = "Genshin Impact";            expectType = "alias-exact";      expectId = "原神" },
    @{ n = "36a. 和名は既存どおり";           input = "原神";                          expectType = "exact";            expectId = "原神" },
    @{ n = "36b. Genshin単独は解決しない";    input = "Genshin";                       expectType = "not-found";        expectId = $null },
    # 実データ(リゼ・ヘルエスタ「【原神/Genshin】星と深淵を目指せ」)に由来する境界ケース
    @{ n = "36c. 原神/Genshin併記は確定しない"; input = "原神/Genshin";                 expectType = "not-found";        expectId = $null },
    @{ n = "36d. 数字が続く場合は一致しない"; input = "Genshin Impact2";               expectType = "not-found";        expectId = $null },
    @{ n = "36e. 複合タイトルは確定しない";   input = "Genshin Impact実況";            expectType = "not-found";        expectId = $null },
    # --- 作品略称 ポケモン剣盾。「剣」「盾」「剣盾」単独や他のポケモン作品には効かないこと ---
    @{ n = "37. 作品略称alias(ポケモン剣盾)"; input = "ポケモン剣盾";                  expectType = "alias-exact";      expectId = "ポケットモンスター ソード・シールド" },
    @{ n = "37a. 正式名は既存どおり";         input = "ポケットモンスター ソード・シールド"; expectType = "exact";        expectId = "ポケットモンスター ソード・シールド" },
    @{ n = "37b. ポケモン剣は解決しない";     input = "ポケモン剣";                    expectType = "not-found";        expectId = $null },
    @{ n = "37c. ポケモン盾は解決しない";     input = "ポケモン盾";                    expectType = "not-found";        expectId = $null },
    @{ n = "37d. 剣盾単独は解決しない";       input = "剣盾";                          expectType = "not-found";        expectId = $null },
    @{ n = "37e. 複合タイトルは確定しない";   input = "ポケモン剣盾実況";              expectType = "not-found";        expectId = $null },
    @{ n = "37f. 数字が続く場合は一致しない"; input = "ポケモン剣盾2";                 expectType = "not-found";        expectId = $null },
    @{ n = "37g. BDSPは既存どおり";           input = "ポケモンBDSP";                  expectType = "not-found";        expectId = $null },
    @{ n = "37h. SVは既存どおり";             input = "ポケモンSV";                    expectType = "alias-exact";      expectId = "ポケットモンスター スカーレット・バイオレット" },
    @{ n = "37i. ZAは既存どおり";             input = "ポケモンZA";                    expectType = "alias-exact";      expectId = "Pokémon LEGENDS Z-A" },
    @{ n = "37j. アルセウスは既存どおり";     input = "アルセウス";                    expectType = "alias-exact";      expectId = "Pokémon LEGENDS アルセウス" },
    # --- 定着した略称 ツイステ。短い前方部分や複合語には効かないこと ---
    @{ n = "38. 略称alias(ツイステ)";         input = "ツイステ";                      expectType = "alias-exact";      expectId = "ディズニー ツイステッドワンダーランド" },
    @{ n = "38a. 正式名は既存どおり";         input = "ディズニー ツイステッドワンダーランド"; expectType = "exact";      expectId = "ディズニー ツイステッドワンダーランド" },
    @{ n = "38b. ツイスは解決しない";         input = "ツイス";                        expectType = "not-found";        expectId = $null },
    @{ n = "38c. 複合タイトルは確定しない";   input = "ツイステ実況";                  expectType = "not-found";        expectId = $null },
    @{ n = "38d. 数字が続く場合は一致しない"; input = "ツイステ2";                     expectType = "not-found";        expectId = $null },
    # --- 英語公式名 LOST JUDGMENT。姉妹作 JUDGE EYES や単語単独には効かないこと ---
    @{ n = "39. 英語公式名alias(LOST JUDGMENT)"; input = "LOST JUDGMENT";             expectType = "alias-exact";      expectId = "LOST JUDGMENT:裁かれざる記憶" },
    @{ n = "39a. 正式名は既存どおり";         input = "LOST JUDGMENT:裁かれざる記憶";  expectType = "exact";            expectId = "LOST JUDGMENT:裁かれざる記憶" },
    @{ n = "39b. 和名aliasは既存どおり";      input = "ロストジャッジメント";          expectType = "alias-exact";      expectId = "LOST JUDGMENT:裁かれざる記憶" },
    @{ n = "39c. JUDGMENT単独は解決しない";   input = "JUDGMENT";                      expectType = "not-found";        expectId = $null },
    @{ n = "39d. LOST単独は解決しない";       input = "LOST";                          expectType = "not-found";        expectId = $null },
    @{ n = "39e. 姉妹作の正式名は既存どおり"; input = "JUDGE EYES:死神の遺言";         expectType = "exact";            expectId = "JUDGE EYES:死神の遺言" },
    # 39f は「LOST JUDGMENT の alias が姉妹作へ漏れないこと」を固定していたケース。
    # JUDGE EYES 自身に alias を持たせたため、期待値を「姉妹作ではなく自分のcanonicalへ解決する」へ更新する。
    @{ n = "39f. JUDGE EYESは姉妹作へ寄らない"; input = "JUDGE EYES";                  expectType = "alias-exact";      expectId = "JUDGE EYES:死神の遺言" },
    @{ n = "39g. 数字が続く場合は一致しない"; input = "LOST JUDGMENT2";                expectType = "not-found";        expectId = $null },
    # --- 英語公式名 JUDGE EYES。単語単独・重複表記・姉妹作には効かないこと ---
    @{ n = "40. 英語公式名alias(JUDGE EYES)"; input = "JUDGE EYES";                    expectType = "alias-exact";      expectId = "JUDGE EYES:死神の遺言" },
    @{ n = "40a. 正式名は既存どおり";         input = "JUDGE EYES:死神の遺言";         expectType = "exact";            expectId = "JUDGE EYES:死神の遺言" },
    @{ n = "40b. 和名aliasは既存どおり";      input = "ジャッジアイズ";                expectType = "alias-exact";      expectId = "JUDGE EYES:死神の遺言" },
    @{ n = "40c. JUDGE単独は解決しない";      input = "JUDGE";                         expectType = "not-found";        expectId = $null },
    @{ n = "40d. EYES単独は解決しない";       input = "EYES";                          expectType = "not-found";        expectId = $null },
    @{ n = "40e. 重複表記は確定しない";       input = "JUDGE EYES / JUDGE EYES";       expectType = "not-found";        expectId = $null },
    @{ n = "40f. 版語つきは確定しない";       input = "JUDGE EYES：死神の遺言 Remastered"; expectType = "not-found";    expectId = $null },
    @{ n = "40g. 数字が続く場合は一致しない"; input = "JUDGE EYES2";                   expectType = "not-found";        expectId = $null },
    @{ n = "40h. 姉妹作は既存どおり";         input = "LOST JUDGMENT";                 expectType = "alias-exact";      expectId = "LOST JUDGMENT:裁かれざる記憶" },
    # --- 版を含む略称 ドラクエ11S。無印版・他ナンバリング・シリーズ略称には効かないこと ---
    @{ n = "41. 版つき略称alias(ドラクエ11S)"; input = "ドラクエ11S";                   expectType = "alias-exact";      expectId = "ドラゴンクエストXI S 過ぎ去りし時を求めて" },
    @{ n = "41a. 正式名は既存どおり";         input = "ドラゴンクエストXI S 過ぎ去りし時を求めて"; expectType = "exact";  expectId = "ドラゴンクエストXI S 過ぎ去りし時を求めて" },
    @{ n = "41b. 無印版は解決しない";         input = "ドラクエ11";                    expectType = "not-found";        expectId = $null },
    @{ n = "41c. 他ナンバリングは解決しない"; input = "ドラクエ3";                     expectType = "not-found";        expectId = $null },
    @{ n = "41d. 数字が続く場合は一致しない"; input = "ドラクエ11S2";                  expectType = "not-found";        expectId = $null },
    @{ n = "41e. 複合タイトルは確定しない";   input = "ドラクエ11S 実況";              expectType = "not-found";        expectId = $null },
    @{ n = "41f. 正式名の一部は解決しない";   input = "ドラゴンクエストXI";            expectType = "not-found";        expectId = $null },
    @{ n = "41g. 同上(S付き)";                input = "ドラゴンクエストXI S";          expectType = "not-found";        expectId = $null },
    # --- 外伝作品の略称 龍が如く7外伝。ナンバリング本編やシリーズ一般には効かないこと ---
    @{ n = "42. 外伝略称alias(龍が如く7外伝)"; input = "龍が如く7外伝";                expectType = "alias-exact";      expectId = "龍が如く7外伝 名を消した男" },
    @{ n = "42a. 全角数字も同じ扱い";         input = "龍が如く７外伝";                expectType = "canonical-alias";  expectId = "龍が如く7外伝 名を消した男" },
    @{ n = "42b. 正式名は既存どおり";         input = "龍が如く7外伝 名を消した男";    expectType = "exact";            expectId = "龍が如く7外伝 名を消した男" },
    @{ n = "42c. 本編7は解決しない";          input = "龍が如く7";                     expectType = "not-found";        expectId = $null },
    @{ n = "42d. 本編7の正式名は既存どおり";  input = "龍が如く7 光と闇の行方";        expectType = "exact";            expectId = "龍が如く7 光と闇の行方" },
    @{ n = "42e. 8は既存どおり";              input = "龍が如く8";                     expectType = "exact";            expectId = "龍が如く8" },
    @{ n = "42f. 8外伝は解決しない";          input = "龍が如く8外伝";                 expectType = "not-found";        expectId = $null },
    @{ n = "42g. 1作目は既存どおり";          input = "龍が如く";                      expectType = "exact";            expectId = "龍が如く" },
    @{ n = "42h. 龍が如く外伝は解決しない";   input = "龍が如く外伝";                  expectType = "not-found";        expectId = $null },
    @{ n = "42i. 数字が続く場合は一致しない"; input = "龍が如く7外伝2";               expectType = "not-found";        expectId = $null },
    # --- ナンバリング略称 ARMORED CORE VI。V / VII / IV など隣接ナンバリングには効かないこと ---
    @{ n = "43. ナンバリング略称alias(ARMORED CORE VI)"; input = "ARMORED CORE VI"; expectType = "alias-exact"; expectId = "ARMORED CORE VI FIRES OF RUBICON" },
    @{ n = "43a. 正式名は既存どおり";         input = "ARMORED CORE VI FIRES OF RUBICON"; expectType = "exact"; expectId = "ARMORED CORE VI FIRES OF RUBICON" },
    @{ n = "43b. Vは解決しない";              input = "ARMORED CORE V";                expectType = "not-found";        expectId = $null },
    @{ n = "43c. VIIは解決しない";            input = "ARMORED CORE VII";              expectType = "not-found";        expectId = $null },
    @{ n = "43d. IVは解決しない";             input = "ARMORED CORE IV";               expectType = "not-found";        expectId = $null },
    @{ n = "43e. IIIは解決しない";            input = "ARMORED CORE III";              expectType = "not-found";        expectId = $null },
    @{ n = "43f. IIは解決しない";             input = "ARMORED CORE II";               expectType = "not-found";        expectId = $null },
    @{ n = "43g. VIIIは解決しない";           input = "ARMORED CORE VIII";             expectType = "not-found";        expectId = $null },
    @{ n = "43h. 4は既存どおり";              input = "ARMORED CORE 4";                expectType = "exact";            expectId = "ARMORED CORE 4" },
    @{ n = "43i. for Answerは既存どおり";     input = "ARMORED CORE for Answer";       expectType = "exact";            expectId = "ARMORED CORE for Answer" },
    @{ n = "43j. シリーズ名だけでは解決しない"; input = "ARMORED CORE";               expectType = "not-found";        expectId = $null },
    # --- 中黒なし表記 ホグワーツレガシー。続編の数字表記や英題・別作品には効かないこと ---
    @{ n = "44. 中黒なし表記alias(ホグワーツレガシー)"; input = "ホグワーツレガシー"; expectType = "alias-exact"; expectId = "ホグワーツ・レガシー" },
    @{ n = "44a. 正式名は既存どおり";         input = "ホグワーツ・レガシー";          expectType = "exact";            expectId = "ホグワーツ・レガシー" },
    @{ n = "44b. 空白区切りは既存どおり";     input = "ホグワーツ レガシー";           expectType = "normalized-exact"; expectId = "ホグワーツ・レガシー" },
    @{ n = "44c. 続編の数字表記は解決しない"; input = "ホグワーツレガシー2";           expectType = "not-found";        expectId = $null },
    @{ n = "44d. 英題は解決しない(既存どおり)"; input = "Hogwarts Legacy";            expectType = "not-found";        expectId = $null },
    @{ n = "44e. ホグワーツだけでは解決しない"; input = "ホグワーツ";                 expectType = "not-found";        expectId = $null },
    # --- ナンバリング略称 龍が如く0。数字違い・他ナンバリング・外伝には効かないこと ---
    @{ n = "45. ナンバリング略称alias(龍が如く0)"; input = "龍が如く0";           expectType = "alias-exact";      expectId = "龍が如く0 誓いの場所" },
    @{ n = "45a. 全角数字も同じ扱い";         input = "龍が如く０";                    expectType = "canonical-alias";  expectId = "龍が如く0 誓いの場所" },
    @{ n = "45b. 正式名は既存どおり";         input = "龍が如く0 誓いの場所";          expectType = "exact";            expectId = "龍が如く0 誓いの場所" },
    @{ n = "45c. 1作目は既存どおり";          input = "龍が如く";                      expectType = "exact";            expectId = "龍が如く" },
    @{ n = "45d. 8は既存どおり";              input = "龍が如く8";                     expectType = "exact";            expectId = "龍が如く8" },
    @{ n = "45e. 7外伝は既存どおり";          input = "龍が如く7外伝";                 expectType = "alias-exact";      expectId = "龍が如く7外伝 名を消した男" },
    @{ n = "45f. 数字が続く場合は一致しない"; input = "龍が如く02";                    expectType = "not-found";        expectId = $null },
    @{ n = "45g. 10は解決しない";             input = "龍が如く10";                    expectType = "not-found";        expectId = $null },
    # --- 「スーパー」省略の略称 マリオメーカー2。数字違い・無印には効かないこと ---
    @{ n = "46. 略称alias(マリオメーカー2)";  input = "マリオメーカー2";              expectType = "alias-exact";      expectId = "スーパーマリオメーカー2" },
    @{ n = "46a. 全角数字も同じ扱い";         input = "マリオメーカー２";              expectType = "canonical-alias";  expectId = "スーパーマリオメーカー2" },
    @{ n = "46b. 正式名は既存どおり";         input = "スーパーマリオメーカー2";       expectType = "exact";            expectId = "スーパーマリオメーカー2" },
    @{ n = "46c. 無印は解決しない";           input = "マリオメーカー";                expectType = "not-found";        expectId = $null },
    @{ n = "46d. 3は解決しない";              input = "マリオメーカー3";               expectType = "not-found";        expectId = $null },
    @{ n = "46e. 数字が続く場合は一致しない"; input = "マリオメーカー20";              expectType = "not-found";        expectId = $null },
    # --- 正式表記寄りの略称 ドラゴンクエスト11S。S なし・他ナンバリング・英字略称には効かないこと ---
    @{ n = "47. 略称alias(ドラゴンクエスト11S)"; input = "ドラゴンクエスト11S";     expectType = "alias-exact";      expectId = "ドラゴンクエストXI S 過ぎ去りし時を求めて" },
    @{ n = "47a. 全角・小文字も同じ扱い";     input = "ドラゴンクエスト１１ｓ";        expectType = "canonical-alias";  expectId = "ドラゴンクエストXI S 過ぎ去りし時を求めて" },
    @{ n = "47b. 既存alias ドラクエ11S は既存どおり"; input = "ドラクエ11S";         expectType = "alias-exact";      expectId = "ドラゴンクエストXI S 過ぎ去りし時を求めて" },
    @{ n = "47c. S なしは解決しない";         input = "ドラゴンクエスト11";            expectType = "not-found";        expectId = $null },
    @{ n = "47d. 12は解決しない";             input = "ドラゴンクエスト12";            expectType = "not-found";        expectId = $null },
    @{ n = "47e. 英字略称は解決しない";       input = "DQ11S";                         expectType = "not-found";        expectId = $null },
    # --- ハイフンなし表記 キャプテン翼 RISE OF NEW CHAMPIONS。2作目・シリーズ名には効かないこと ---
    @{ n = "48. ハイフンなし表記alias";       input = "キャプテン翼 RISE OF NEW CHAMPIONS"; expectType = "alias-exact"; expectId = "キャプテン翼 -RISE OF NEW CHAMPIONS-" },
    @{ n = "48a. 正式名は既存どおり";         input = "キャプテン翼 -RISE OF NEW CHAMPIONS-"; expectType = "exact";     expectId = "キャプテン翼 -RISE OF NEW CHAMPIONS-" },
    @{ n = "48b. 2作目は既存どおり";          input = "キャプテン翼2 WORLD FIGHTERS";  expectType = "exact";            expectId = "キャプテン翼2 WORLD FIGHTERS" },
    @{ n = "48c. キャプテン翼だけでは解決しない"; input = "キャプテン翼";              expectType = "not-found";        expectId = $null },
    # --- コロンなし表記 モンスターハンターワールド。シリーズ他作品・数字違いには効かないこと ---
    @{ n = "49. コロンなし表記alias";         input = "モンスターハンターワールド";    expectType = "alias-exact";      expectId = "モンスターハンター：ワールド" },
    @{ n = "49a. 正式名は既存どおり";         input = "モンスターハンター：ワールド";  expectType = "exact";            expectId = "モンスターハンター：ワールド" },
    @{ n = "49b. ワイルズは既存どおり";       input = "モンスターハンターワイルズ";    expectType = "exact";            expectId = "モンスターハンターワイルズ" },
    @{ n = "49c. シリーズ名だけでは解決しない"; input = "モンスターハンター";          expectType = "not-found";        expectId = $null },
    @{ n = "49d. 数字が続く場合は一致しない"; input = "モンスターハンターワールド2";   expectType = "not-found";        expectId = $null },
    # --- 英題表記 Pokémon Legends: Z-A。é なし表記・アルセウス・短い文字列には効かないこと ---
    @{ n = "50. 英題表記alias";               input = "Pokémon Legends: Z-A";          expectType = "alias-exact";      expectId = "Pokémon LEGENDS Z-A" },
    @{ n = "50a. 正式名は既存どおり";         input = "Pokémon LEGENDS Z-A";           expectType = "exact";            expectId = "Pokémon LEGENDS Z-A" },
    @{ n = "50b. 既存alias ポケモンZA は既存どおり"; input = "ポケモンZA";             expectType = "alias-exact";      expectId = "Pokémon LEGENDS Z-A" },
    @{ n = "50c. é なし表記は解決しない";     input = "Pokemon Legends: Z-A";          expectType = "not-found";        expectId = $null },
    @{ n = "50d. アルセウス英題は解決しない"; input = "Pokémon Legends: Arceus";       expectType = "not-found";        expectId = $null },
    @{ n = "50e. Z-Aだけでは解決しない";      input = "Z-A";                           expectType = "not-found";        expectId = $null },
    # --- 空白・コロンなし表記 バイオハザードRE2。RE3・RE4・無印2・英字表記には効かないこと ---
    @{ n = "51. 空白・コロンなし表記alias";   input = "バイオハザードRE2";             expectType = "alias-exact";      expectId = "バイオハザード RE:2" },
    @{ n = "51a. 正式名は既存どおり";         input = "バイオハザード RE:2";           expectType = "exact";            expectId = "バイオハザード RE:2" },
    @{ n = "51b. RE3はRE2ではなく自作品へ(監査65でalias追加)"; input = "バイオハザードRE3"; expectType = "alias-exact"; expectId = "バイオハザード RE:3" },
    @{ n = "51c. 無印2は解決しない";          input = "バイオハザード2";               expectType = "not-found";        expectId = $null },
    @{ n = "51d. RE2だけでは解決しない";      input = "RE2";                           expectType = "not-found";        expectId = $null },
    @{ n = "51e. 英字表記は解決しない";       input = "BIOHAZARD RE2";                 expectType = "not-found";        expectId = $null },
    # --- 全角コロンなし表記 崩壊スターレイル。崩壊3rd・短い語・英題には効かないこと ---
    @{ n = "52. 全角コロンなし表記alias";     input = "崩壊スターレイル";              expectType = "alias-exact";      expectId = "崩壊：スターレイル" },
    @{ n = "52a. 正式名は既存どおり";         input = "崩壊：スターレイル";            expectType = "exact";            expectId = "崩壊：スターレイル" },
    @{ n = "52b. 崩壊3rdは既存どおり";        input = "崩壊3rd";                       expectType = "exact";            expectId = "崩壊3rd" },
    @{ n = "52c. 崩壊だけでは解決しない";     input = "崩壊";                          expectType = "not-found";        expectId = $null },
    @{ n = "52d. スターレイルだけでは解決しない"; input = "スターレイル";              expectType = "not-found";        expectId = $null },
    @{ n = "52e. 英題は解決しない";           input = "Honkai: Star Rail";             expectType = "not-found";        expectId = $null },
    # --- 空白・コロンなし表記 バイオハザードRE3。RE2・RE4・無印3・短い語・英字表記には効かないこと ---
    @{ n = "53. 空白・コロンなし表記alias";   input = "バイオハザードRE3";             expectType = "alias-exact";      expectId = "バイオハザード RE:3" },
    @{ n = "53a. 正式名は既存どおり";         input = "バイオハザード RE:3";           expectType = "exact";            expectId = "バイオハザード RE:3" },
    @{ n = "53b. RE2は既存aliasどおり";       input = "バイオハザードRE2";             expectType = "alias-exact";      expectId = "バイオハザード RE:2" },
    @{ n = "53c. 無印3は解決しない";          input = "バイオハザード3";               expectType = "not-found";        expectId = $null },
    @{ n = "53d. RE3だけでは解決しない";      input = "RE3";                           expectType = "not-found";        expectId = $null },
    @{ n = "53e. 英字表記は解決しない";       input = "BIOHAZARD RE3";                 expectType = "not-found";        expectId = $null },
    # --- コロンなし表記 NieRAutomata。Replicant・部分語・数字/英字が続く形には効かないこと ---
    @{ n = "54. コロンなし表記alias";        input = "NieRAutomata";                  expectType = "alias-exact";      expectId = "NieR:Automata" },
    @{ n = "54a. 正式名は既存どおり";         input = "NieR:Automata";                 expectType = "exact";            expectId = "NieR:Automata" },
    @{ n = "54b. 空白表記は正規化で同一";     input = "NieR Automata";                 expectType = "normalized-exact"; expectId = "NieR:Automata" },
    @{ n = "54c. 別作品Replicantは自作品へ";  input = "NieR Replicant";                expectType = "exact";            expectId = "NieR Replicant" },
    @{ n = "54d. NieR単独では解決しない";     input = "NieR";                          expectType = "not-found";        expectId = $null },
    @{ n = "54e. Automata単独では解決しない"; input = "Automata";                      expectType = "not-found";        expectId = $null },
    @{ n = "54f. 数字が続く場合は解決しない"; input = "NieRAutomata2";                 expectType = "not-found";        expectId = $null },
    @{ n = "54g. アニメ表記は解決しない";     input = "NieRAutomataVer1.1a";           expectType = "not-found";        expectId = $null },
    @{ n = "54h. カナ表記は解決しない";       input = "ニーアオートマタ";              expectType = "not-found";        expectId = $null },
    # --- 「ら」抜き表記 ほの暮しの庭。部分語・数字が続く形・かな表記には効かないこと ---
    @{ n = "55. ら抜き表記alias";            input = "ほの暮しの庭";                  expectType = "alias-exact";      expectId = "ほの暮らしの庭" },
    @{ n = "55a. 正式名は既存どおり";         input = "ほの暮らしの庭";                expectType = "exact";            expectId = "ほの暮らしの庭" },
    @{ n = "55b. 部分語では解決しない";       input = "暮しの庭";                      expectType = "not-found";        expectId = $null },
    @{ n = "55c. 前半だけでは解決しない";     input = "ほの暮し";                      expectType = "not-found";        expectId = $null },
    @{ n = "55d. 数字が続く場合は解決しない"; input = "ほの暮しの庭2";                 expectType = "not-found";        expectId = $null },
    @{ n = "55e. かな表記は解決しない";       input = "ほのくらしのにわ";              expectType = "not-found";        expectId = $null },
    @{ n = "55f. 別語は解決しない";           input = "ほのぼの暮しの庭";              expectType = "not-found";        expectId = $null },
    # --- コロンなし表記 ARK survival evolved。Ascended・部分語・数字が続く形には効かないこと ---
    @{ n = "56. コロンなし表記alias";        input = "ARK survival evolved";          expectType = "alias-exact";      expectId = "ARK: Survival Evolved" },
    @{ n = "56a. 正式名は既存どおり";         input = "ARK: Survival Evolved";         expectType = "exact";            expectId = "ARK: Survival Evolved" },
    @{ n = "56b. 大小文字ゆれは正規化で同一"; input = "Ark Survival Evolved";          expectType = "normalized-exact"; expectId = "ARK: Survival Evolved" },
    @{ n = "56c. 別作品Ascendedは自作品へ";   input = "ARK: Survival Ascended";        expectType = "exact";            expectId = "ARK: Survival Ascended" },
    @{ n = "56d. シリーズ登録は自登録へ";     input = "ARKシリーズ";                   expectType = "exact";            expectId = "ARKシリーズ" },
    @{ n = "56e. ARK単独では解決しない";      input = "ARK";                           expectType = "not-found";        expectId = $null },
    @{ n = "56f. 部分語では解決しない";       input = "survival evolved";              expectType = "not-found";        expectId = $null },
    @{ n = "56g. 数字が続く場合は解決しない"; input = "ARK survival evolved2";         expectType = "not-found";        expectId = $null },
    # --- 中黒なし表記 クロノトリガー。合本・別作品・数字が続く形には効かないこと ---
    @{ n = "57. 中黒なし表記alias";          input = "クロノトリガー";                expectType = "alias-exact";      expectId = "クロノ・トリガー" },
    @{ n = "57a. 正式名は既存どおり";         input = "クロノ・トリガー";              expectType = "exact";            expectId = "クロノ・トリガー" },
    @{ n = "57b. 合本は合本の登録へ";         input = "クロノ・トリガー＆クロノ・クロス"; expectType = "exact";          expectId = "クロノ・トリガー＆クロノ・クロス" },
    @{ n = "57c. 数字が続く場合は解決しない"; input = "クロノトリガー2";               expectType = "not-found";        expectId = $null },
    @{ n = "57d. 別作品クロノアは解決しない"; input = "クロノア";                      expectType = "not-found";        expectId = $null },
    @{ n = "57e. 英題は解決しない";           input = "CHRONO TRIGGER";                expectType = "not-found";        expectId = $null },
    # --- 末尾ピリオドなし表記 R.E.P.O。短縮形・数字が続く形には効かないこと ---
    @{ n = "58. ピリオドなし表記alias";      input = "R.E.P.O";                       expectType = "alias-exact";      expectId = "R.E.P.O." },
    @{ n = "58a. 正式名は既存どおり";         input = "R.E.P.O.";                      expectType = "exact";            expectId = "R.E.P.O." },
    @{ n = "58b. 小文字表記も同じゲームへ";    input = "r.e.p.o";                       expectType = "normalized-exact"; expectId = "R.E.P.O." },
    # REPO は alias 追加前から、記号を落とす正規化で同じゲームへ解決している(実装どおり)
    @{ n = "58c. REPOは正規化で同じゲームへ";  input = "REPO";                          expectType = "normalized-exact"; expectId = "R.E.P.O." },
    @{ n = "58d. 途中までは解決しない";       input = "R.E.P";                         expectType = "not-found";        expectId = $null },
    @{ n = "58e. 数字が続く場合は解決しない"; input = "R.E.P.O2";                      expectType = "not-found";        expectId = $null },
    # --- 長音・空白なし表記 ウマ娘プリティダービー。部分語・数字が続く形には効かないこと ---
    @{ n = "59. 長音なし表記alias";          input = "ウマ娘プリティダービー";        expectType = "alias-exact";      expectId = "ウマ娘 プリティーダービー" },
    @{ n = "59a. 正式名は既存どおり";         input = "ウマ娘 プリティーダービー";     expectType = "exact";            expectId = "ウマ娘 プリティーダービー" },
    @{ n = "59b. 空白ゆれは正規化で同一";     input = "ウマ娘プリティーダービー";      expectType = "normalized-exact"; expectId = "ウマ娘 プリティーダービー" },
    @{ n = "59c. ウマ娘単独では解決しない";   input = "ウマ娘";                        expectType = "not-found";        expectId = $null },
    @{ n = "59d. 部分語では解決しない";       input = "プリティダービー";              expectType = "not-found";        expectId = $null },
    @{ n = "59e. 数字が続く場合は解決しない"; input = "ウマ娘プリティダービー2";       expectType = "not-found";        expectId = $null },
    @{ n = "59f. 英題は解決しない";           input = "Umamusume Pretty Derby";        expectType = "not-found";        expectId = $null },
    # --- カタカナ表記 タルコフ。部分語・数字が続く形・英語部分語には効かないこと ---
    @{ n = "60. カタカナ表記alias";          input = "タルコフ";                      expectType = "alias-exact";      expectId = "Escape from Tarkov" },
    @{ n = "60a. 正式名は既存どおり";         input = "Escape from Tarkov";            expectType = "exact";            expectId = "Escape from Tarkov" },
    @{ n = "60b. 小文字表記も同じゲームへ";    input = "escape from tarkov";            expectType = "normalized-exact"; expectId = "Escape from Tarkov" },
    @{ n = "60c. ひらがな表記は正規化で同一";  input = "たるこふ";                      expectType = "canonical-alias";  expectId = "Escape from Tarkov" },
    @{ n = "60d. 部分語では解決しない";       input = "タルコ";                        expectType = "not-found";        expectId = $null },
    @{ n = "60e. 数字が続く場合は解決しない"; input = "タルコフ2";                     expectType = "not-found";        expectId = $null },
    @{ n = "60f. 英語部分語では解決しない";   input = "Tarkov";                        expectType = "not-found";        expectId = $null },
    @{ n = "60g. 未登録の派生は解決しない";   input = "Escape from Tarkov Arena";      expectType = "not-found";        expectId = $null }
  )
  $pass = 0; $fail = 0
  $rows = New-Object System.Collections.Generic.List[object]
  Write-Output "=== Resolve-GameId 回帰テスト ==="
  foreach ($c in $cases) {
    $r = Resolve-GameId $c.input $index
    $okType = ($r.matchType -eq $c.expectType)
    $okId = ($r.gameId -eq $c.expectId)
    $ok = ($okType -and $okId)
    if ($ok) { $pass++ } else { $fail++ }
    Write-Output ("  [{0}] {1}" -f $(if ($ok) { "PASS" } else { "FAIL" }), $c.n)
    Write-Output ("        input=`"{0}`" -> matchType={1} gameId={2} ambiguous={3} candidates={4}" -f `
      $c.input, $r.matchType, $(if ($r.gameId) { "`"$($r.gameId)`"" } else { "(null)" }), $r.ambiguous, $r.candidateIds.Count)
    if (-not $ok) { Write-Output ("        期待: matchType={0} gameId={1}" -f $c.expectType, $(if ($c.expectId) { "`"$($c.expectId)`"" } else { "(null)" })) }
    $rows.Add([PSCustomObject]@{ name = $c.n; input = $c.input; expectType = $c.expectType; expectId = $c.expectId; actualType = $r.matchType; actualId = $r.gameId; pass = $ok })
  }
  # ---- テーブル駆動: 共有aliasはすべて ambiguous になること ----
  #   カタログから「正規化aliasを2game以上が所有している」ものを列挙し、その生alias
  #   表記すべてについて一意確定しないことを確認する。データが増えても自動で追従する。
  Write-Output ""
  Write-Output "=== 共有alias テーブル駆動テスト ==="
  $sharedRows = New-Object System.Collections.Generic.List[object]
  $aliasByNorm = New-Object 'System.Collections.Generic.Dictionary[string,System.Collections.Generic.List[string]]'([StringComparer]::Ordinal)
  foreach ($g in $index.games) {
    foreach ($a in @($g.aliases)) {
      if (-not $a) { continue }
      $nz = Get-GameIdNormalizedText $a
      if (-not $nz) { continue }
      if (-not $aliasByNorm.ContainsKey($nz)) { $aliasByNorm[$nz] = New-Object 'System.Collections.Generic.List[string]' }
      if (-not $aliasByNorm[$nz].Contains($a)) { $aliasByNorm[$nz].Add($a) }
    }
  }
  $sharedNorm = @($aliasByNorm.Keys | Where-Object { $index.normAlias.ContainsKey($_) -and $index.normAlias[$_].Count -ge 2 } | Sort-Object)
  $sharedRawCount = 0
  foreach ($nz in $sharedNorm) { $sharedRawCount += $aliasByNorm[$nz].Count }
  Write-Output ("  共有alias(正規化キー): {0} 件 / 生alias表記: {1} 件" -f $sharedNorm.Count, $sharedRawCount)
  foreach ($nz in $sharedNorm) {
    foreach ($a in @($aliasByNorm[$nz])) {
      $r = Resolve-GameId $a $index
      $ok = ($r.matchType -eq "ambiguous") -and ($null -eq $r.gameId)
      if ($ok) { $pass++ } else { $fail++ }
      Write-Output ("  [{0}] 共有alias「{1}」(所有 {2} game) -> {3}{4}" -f $(if ($ok) { "PASS" } else { "FAIL" }), $a, $index.normAlias[$nz].Count, $r.matchType, $(if ($r.gameId) { " / $($r.gameId)" } else { "" }))
      $sharedRows.Add([PSCustomObject]@{ alias = $a; normalized = $nz; owners = $index.normAlias[$nz].Count; actualType = $r.matchType; actualId = $r.gameId; pass = $ok })
      $rows.Add([PSCustomObject]@{ name = "共有alias: $a"; input = $a; expectType = "ambiguous"; expectId = $null; actualType = $r.matchType; actualId = $r.gameId; pass = $ok })
    }
  }

  # ---- alias所有インデックスの単体テスト(合成インデックス) ----
  #   「生aliasキーでは単独所有だが、正規化すると複数gameが共有している」ケースを
  #   合成データで再現し、一意確定しないことを確認する。本番データには依存しない。
  Write-Output ""
  Write-Output "=== alias所有インデックス 単体テスト(合成データ) ==="
  function Add-FakeKey($map, [string]$k, [string]$v) {
    if (-not $map.ContainsKey($k)) { $map[$k] = New-Object 'System.Collections.Generic.HashSet[string]' }
    [void]$map[$k].Add($v)
  }
  $fx = New-Object 'System.Collections.Generic.Dictionary[string,System.Collections.Generic.HashSet[string]]'([StringComparer]::Ordinal)
  $fae = New-Object 'System.Collections.Generic.Dictionary[string,System.Collections.Generic.HashSet[string]]'([StringComparer]::Ordinal)
  $fnm = New-Object 'System.Collections.Generic.Dictionary[string,System.Collections.Generic.HashSet[string]]'([StringComparer]::Ordinal)
  $fna = New-Object 'System.Collections.Generic.Dictionary[string,System.Collections.Generic.HashSet[string]]'([StringComparer]::Ordinal)
  $fpm = New-Object 'System.Collections.Generic.Dictionary[string,System.Collections.Generic.HashSet[string]]'([StringComparer]::Ordinal)
  $fps = New-Object 'System.Collections.Generic.Dictionary[string,System.Collections.Generic.HashSet[string]]'([StringComparer]::Ordinal)
  # GAME A と GAME B が半角「FF」を共有し、GAME C だけが全角「ＦＦ」を持つ
  foreach ($n in @("GAME A", "GAME B", "GAME C")) {
    Add-FakeKey $fx $n $n
    Add-FakeKey $fnm (Get-GameIdNormalizedText $n) $n
  }
  Add-FakeKey $fae "FF" "GAME A"
  Add-FakeKey $fae "FF" "GAME B"
  Add-FakeKey $fae "ＦＦ" "GAME C"
  Add-FakeKey $fna (Get-GameIdNormalizedText "FF") "GAME A"
  Add-FakeKey $fna (Get-GameIdNormalizedText "FF") "GAME B"
  Add-FakeKey $fna (Get-GameIdNormalizedText "ＦＦ") "GAME C"
  $fake = [PSCustomObject]@{ games = @(); exact = $fx; aliasExact = $fae; normalized = $fnm; normAlias = $fna; permuted = $fpm; permutedSrc = $fps }
  $fakeCases = @(
    @{ n = "F1. 共有alias(半角)";          input = "FF";      expectType = "ambiguous"; expectId = $null },
    @{ n = "F2. 共有aliasの全角表記ゆれ";   input = "ＦＦ";    expectType = "ambiguous"; expectId = $null },
    @{ n = "F3. 正式名は従来どおり優先";    input = "GAME C";  expectType = "exact";     expectId = "GAME C" }
  )
  foreach ($c in $fakeCases) {
    $r = Resolve-GameId $c.input $fake
    $ok = ($r.matchType -eq $c.expectType) -and ($r.gameId -eq $c.expectId)
    if ($ok) { $pass++ } else { $fail++ }
    Write-Output ("  [{0}] {1}: input=`"{2}`" -> {3}{4}" -f $(if ($ok) { "PASS" } else { "FAIL" }), $c.n, $c.input, $r.matchType, $(if ($r.gameId) { " / $($r.gameId)" } else { "" }))
    if (-not $ok) { Write-Output ("        期待: matchType={0} gameId={1}" -f $c.expectType, $(if ($c.expectId) { "`"$($c.expectId)`"" } else { "(null)" })) }
    $rows.Add([PSCustomObject]@{ name = $c.n; input = $c.input; expectType = $c.expectType; expectId = $c.expectId; actualType = $r.matchType; actualId = $r.gameId; pass = $ok })
  }

  Write-Output ""
  Write-Output ("PASS: {0}  FAIL: {1}" -f $pass, $fail)
  $result = [PSCustomObject]@{ pass = $pass; fail = $fail; cases = $rows.ToArray(); sharedAliases = $sharedRows.ToArray() }
}
elseif ($Name) {
  $r = Resolve-GameId $Name $index
  Write-Output ("candidateGameName : {0}" -f $r.candidateGameName)
  Write-Output ("gameId            : {0}" -f $(if ($r.gameId) { $r.gameId } else { "(解決できません)" }))
  Write-Output ("matchedName       : {0}" -f $(if ($r.matchedName) { $r.matchedName } else { "-" }))
  Write-Output ("matchType         : {0}" -f $r.matchType)
  Write-Output ("confidence        : {0}" -f $r.confidence)
  Write-Output ("ambiguous         : {0}" -f $r.ambiguous)
  Write-Output ("candidateIds      : {0}" -f $(if ($r.candidateIds.Count) { ($r.candidateIds -join ' / ') } else { "-" }))
  $result = $r
}
else {
  Write-Output "使い方: -Name <ゲーム名> / -Audit / -SelfTest  (詳細は Get-Help .\resolve-game-id.ps1 -Full)"
}

if ($Json -and $result) {
  ($result | ConvertTo-Json -Depth 8) | Set-Content -Path $Json -Encoding UTF8
  Write-Output ""
  Write-Output "JSONを書き出しました: $Json"
}
