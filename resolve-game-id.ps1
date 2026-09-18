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
    @{ map = $index.aliasExact; key = $candidateGameName;                                    type = "alias-exact";      conf = "high" },
    @{ map = $index.normalized; key = (Get-GameIdNormalizedText $candidateGameName);         type = "normalized-exact"; conf = "high" },
    @{ map = $index.normAlias;  key = (Get-GameIdNormalizedText $candidateGameName);         type = "canonical-alias";  conf = "medium" }
  )

  foreach ($lv in $levels) {
    $key = $lv.key
    if (-not $key) { continue }
    if (-not $lv.map.ContainsKey($key)) { continue }
    $hits = @($lv.map[$key])
    if ($hits.Count -eq 1) {
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
    @{ n = "18. 局所的な並べ替え(かな入替)"; input = "おにぎり屋さんシュミレーター"; expectType = "permuted-exact"; expectId = "おにぎり屋さんシミュレーター" }
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
  Write-Output ""
  Write-Output ("PASS: {0}  FAIL: {1}" -f $pass, $fail)
  $result = [PSCustomObject]@{ pass = $pass; fail = $fail; cases = $rows.ToArray() }
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
