<#
.SYNOPSIS
  単発実況の候補判定ロジック(discover-standalone.ps1 から dot-source して使う)。
  動画1本のタイトル・説明欄を GAMES と照合し、ゲームと信頼度(HIGH / MEDIUM / LOW)を決める。

.DESCRIPTION
  ■ HIGH(本番登録候補としてかなり信用できるもの)の条件 — すべてを満たすこと
    1. タイトルの【】または [] の中身が、あるゲームの name / nameJa / alias と表記揺れを除いて完全に一致する
       (表記揺れ = 大文字小文字・全角半角・空白・記号・ローマ数字 II〜IX と算用数字の違い)
    2. その名前が1つのゲームだけのもの(複数ゲームで共有される別名。例:「ダクソ」「FF」「ドラクエ」では HIGH にしない)
    3. タイトル中に、別のゲームの名前が(そのゲーム名の一部としてではなく)独立して一致していない
    4. タイトルに雑談・歌・告知などの非ゲーム語が無い
    5. 連番(#2・Part2・第2回 など)が無い … 続き物は再生リスト方式で拾うべきため
    6. 同じVTuber×ゲームの再生リストがサイトに登録済みでない(validate-data で止まる)
    7. チャンネル側に、そのゲーム名を含む再生リストが無い(再生リスト方式へ回す)
    ※ サイト登録済み再生リストの動画、STANDALONE_PLAYS 登録済みの動画は、判定の前に候補から外す。

  ■ MEDIUM: ゲームは特定できているが HIGH の条件を1つ以上満たさないもの
    (【】と一部だけ一致 / 【】の外でだけ一致 / 短い英数字名(5文字以下)の【】外一致 / 共有別名 /
     複数ゲームに一致 / 連番 / 登録済み再生リストあり / 専用再生リストあり / 説明欄の「配信タイトル:」行で一致)

  ■ LOW: タイトルに非ゲーム語がある、または説明欄(配信タイトル行以外)でしか一致しない

  ■ 照合の境界(部分一致対策)
    一致箇所の隣が漢字・英数字なら「別の語の一部」とみなして一致させない
    (match-playlist-candidates.ps1 の Test-CleanBoundaryMatch と同じ考え方)。
    例: "uno" は "Siokazunoko" / "suzunoki" の中では一致しない。"Rust" は "trust" の中では一致しない。
    また、ある一致が別ゲームの名前の一致箇所の中に含まれる場合(「DARK SOULS」が「DARK SOULS III」の中にある等)は、
    長い方のゲームだけを残す。一致箇所が登録済みVTuberの名前の一部である場合(「大神」が「大神ミオ」の中にある等)も一致させない。
#>

$script:StandaloneShortAsciiMax = 5   # 英数字だけでこの文字数以下の名前は「短い名前」(【】の完全一致でだけ HIGH)
$script:StandaloneNonGameWords = @('雑談', '歌枠', '歌ってみた', 'cover', 'music video', 'original song', 'shorts', '切り抜き', '誕生日', '周年',
  '記念配信', 'お知らせ', '告知', '朝活', '晩酌', 'asmr', 'デビュー', '新衣装', '凸待ち', '3dライブ', 'mv')
$script:StandaloneRomanDigits = @{ 'ii' = '2'; 'iii' = '3'; 'iv' = '4'; 'v' = '5'; 'vi' = '6'; 'vii' = '7'; 'viii' = '8'; 'ix' = '9' }

function ConvertTo-StandaloneHiragana([string]$s) {
  $sb = New-Object System.Text.StringBuilder
  foreach ($ch in $s.ToCharArray()) {
    if ($ch -ge [char]0x30A1 -and $ch -le [char]0x30F6) { [void]$sb.Append([char]([int]$ch - 0x60)) } else { [void]$sb.Append($ch) }
  }
  return $sb.ToString()
}

# 基本の正規化: 商標記号の除去・曲がった引用符の統一・NFKC・カタカナ→ひらがな・小文字・空白を1つに
function Get-StandaloneNorm([string]$s) {
  if (-not $s) { return "" }
  $n = ($s -replace '[™℠®]', '') -replace '[‘’]', "'"
  $n = ConvertTo-StandaloneHiragana ($n.Normalize([Text.NormalizationForm]::FormKC))
  return (($n.ToLowerInvariant() -replace '\s+', ' ').Trim())
}

# 表記揺れを吸収した比較用キー(【】の中身との完全一致の判定にだけ使う)。
#   独立したローマ数字 II〜IX を算用数字へ(X は「Mega Man X」等の固有名があるため変換しない)、
#   空白・記号(・:：-–—~!?'"./&+#,) を除去する。英字・数字・かな・漢字は変えない。
function Get-StandaloneLooseKey([string]$s) {
  $n = Get-StandaloneNorm $s
  $tokens = $n -split ' '
  $tokens = foreach ($t in $tokens) { if ($script:StandaloneRomanDigits.ContainsKey($t)) { $script:StandaloneRomanDigits[$t] } else { $t } }
  $n = ($tokens -join ' ')
  return ($n -replace "[\s・·:\-‐-―~〜～!?'`"\.\/&\+#,]", '')
}

# 空白を除いた照合用テキストと、元の位置(空白を1つに潰した文字列上)への対応表
function New-StandaloneMatchText([string]$s) {
  $n = Get-StandaloneNorm $s
  $sb = New-Object System.Text.StringBuilder
  $map = New-Object System.Collections.Generic.List[int]
  for ($i = 0; $i -lt $n.Length; $i++) { if ($n[$i] -eq ' ') { continue }; [void]$sb.Append($n[$i]); $map.Add($i) }
  return [pscustomobject]@{ stripped = $sb.ToString(); collapsed = $n; map = $map.ToArray() }
}

function Test-StandaloneWeakChar([char]$ch) {
  if ($ch -ge [char]0x3400 -and $ch -le [char]0x9FFF) { return $true }
  if ($ch -eq [char]0x3005) { return $true }
  if ($ch -ge 'a' -and $ch -le 'z') { return $true }
  if ($ch -ge '0' -and $ch -le '9') { return $true }
  return $false
}

# 強い境界での一致位置(stripped 上の [start, end))を返す。無ければ空配列。
function Find-StandaloneCleanMatches($ctx, [string]$needle) {
  $out = @()
  if (-not $needle -or -not $ctx.stripped) { return $out }
  $idx = $ctx.stripped.IndexOf($needle)
  while ($idx -ge 0) {
    $ok = $true
    $prev = $ctx.map[$idx] - 1
    if ($prev -ge 0 -and (Test-StandaloneWeakChar $ctx.collapsed[$prev])) { $ok = $false }
    if ($ok) {
      $next = $ctx.map[$idx + $needle.Length - 1] + 1
      if ($next -lt $ctx.collapsed.Length -and (Test-StandaloneWeakChar $ctx.collapsed[$next])) { $ok = $false }
    }
    if ($ok) { $out += , @($idx, ($idx + $needle.Length)) }
    $idx = $ctx.stripped.IndexOf($needle, $idx + 1)
  }
  # 1件だけのとき [start, end] の組が展開されないよう、配列のまま返す
  return , $out
}

# GAMES の照合用インデックスを作る。1回だけ作って全動画で使い回す。
#   $games: name / aliases(name・nameJa・aliases を含む配列)を持つオブジェクトの配列
function New-StandaloneGameIndex($games, [string[]]$streamerNames = @()) {
  $entries = New-Object System.Collections.Generic.List[object]
  $looseOwners = @{}
  foreach ($g in $games) {
    foreach ($a in @($g.aliases | Select-Object -Unique)) {
      if (-not $a) { continue }
      $stripped = (Get-StandaloneNorm $a) -replace ' ', ''
      $loose = Get-StandaloneLooseKey $a
      if ($loose.Length -lt 2) { continue }   # 1文字の名前は照合しない
      $isShortAscii = ($loose -match '^[a-z0-9]+$') -and ($loose.Length -le $script:StandaloneShortAsciiMax)
      $entries.Add([pscustomobject]@{ game = $g.name; alias = $a; stripped = $stripped; loose = $loose; shortAscii = $isShortAscii })
      if (-not $looseOwners.ContainsKey($loose)) { $looseOwners[$loose] = New-Object System.Collections.Generic.HashSet[string] }
      [void]$looseOwners[$loose].Add($g.name)
    }
  }
  foreach ($e in $entries) { $e | Add-Member -NotePropertyName shared -NotePropertyValue ($looseOwners[$e.loose].Count -gt 1) }
  # VTuber名(ゲーム名を含みうる長さのもの)。一致箇所が VTuber名の中にあるときは無視する
  $names = @($streamerNames | Where-Object { $_ } | ForEach-Object { (Get-StandaloneNorm $_) -replace ' ', '' } | Where-Object { $_.Length -ge 2 } | Select-Object -Unique)
  return [pscustomobject]@{ entries = $entries; looseOwners = $looseOwners; streamerNames = $names }
}

function Get-StandaloneBrackets([string]$title) {
  $n = Get-StandaloneNorm $title
  return @([regex]::Matches($n, '【([^】]+)】|\[([^\]]+)\]') | ForEach-Object { if ($_.Groups[1].Success) { $_.Groups[1].Value } else { $_.Groups[2].Value } })
}

function Test-StandaloneNonGameTitle([string]$title) {
  $ctx = New-StandaloneMatchText $title
  foreach ($w in $script:StandaloneNonGameWords) {
    $nw = (Get-StandaloneNorm $w) -replace ' ', ''
    if ($nw -match '^[a-z0-9]+$') { if ((Find-StandaloneCleanMatches $ctx $nw).Count -gt 0) { return $w } }
    elseif ($ctx.stripped.Contains($nw)) { return $w }
  }
  return $null
}

function Test-StandaloneSequel([string]$title) {
  $n = Get-StandaloneNorm $title
  return ($n -match '#\s*\d+|part\s*\.?\s*\d+|第\s*\d+\s*(回|話|章|夜|日)|\bep\s*\.?\s*\d+|その\s*\d+')
}

# テキスト中で強い境界で一致するゲーム(名前・位置)を集め、別ゲームの一致箇所に含まれる一致を除く
function Get-StandaloneSpanMatches($index, $ctx) {
  # テキスト中の VTuber名の位置(この中に収まる一致はゲーム名として扱わない)
  $nameSpans = @()
  foreach ($n in $index.streamerNames) {
    $i = $ctx.stripped.IndexOf($n)
    while ($i -ge 0) { $nameSpans += , @($i, ($i + $n.Length)); $i = $ctx.stripped.IndexOf($n, $i + 1) }
  }
  $found = @()
  foreach ($e in $index.entries) {
    if (-not $ctx.stripped.Contains($e.stripped)) { continue }
    foreach ($sp in (Find-StandaloneCleanMatches $ctx $e.stripped)) {
      $inName = $false
      foreach ($ns in $nameSpans) { if ($ns[0] -le $sp[0] -and $ns[1] -ge $sp[1] -and ($ns[1] - $ns[0]) -gt ($sp[1] - $sp[0])) { $inName = $true; break } }
      if (-not $inName) { $found += [pscustomobject]@{ entry = $e; start = $sp[0]; end = $sp[1] } }
    }
  }
  $kept = @()
  foreach ($f in $found) {
    $inside = $false
    foreach ($o in $found) {
      if ($o.entry.game -eq $f.entry.game) { continue }
      if ($o.start -le $f.start -and $o.end -ge $f.end -and ($o.end - $o.start) -gt ($f.end - $f.start)) { $inside = $true; break }
    }
    if (-not $inside) { $kept += $f }
  }
  return $kept
}

# 動画1本を判定する。戻り値: game(無ければ $null)・confidence・matchType・matchedAlias・reasons・otherGames
#   $context: siteHasGamePlaylist / dedicatedPlaylists を返すための scriptblock を持つハッシュ(省略可)
function Get-StandaloneMatch($index, [string]$title, [string]$description, $context) {
  $reasons = New-Object System.Collections.Generic.List[string]
  $titleCtx = New-StandaloneMatchText $title
  $brackets = @(Get-StandaloneBrackets $title | ForEach-Object { Get-StandaloneLooseKey $_ })

  # 1) 【】[] の中身との完全一致
  $bracketHits = @($index.entries | Where-Object { $brackets -contains $_.loose })
  # 2) タイトル中の強い境界での一致(別ゲーム名の中に含まれるものは除く)
  $titleHits = @(Get-StandaloneSpanMatches $index $titleCtx)
  $titleGames = @($titleHits | ForEach-Object { $_.entry.game } | Select-Object -Unique)

  $game = $null; $matchType = $null; $alias = $null
  $bracketGames = @($bracketHits | ForEach-Object { $_.game } | Select-Object -Unique)
  if ($bracketGames.Count -ge 1) {
    $matchType = 'bracket-exact'
    if ($bracketGames.Count -gt 1) { $reasons.Add('【】の名前が複数ゲームに一致: ' + ($bracketGames -join ' / ')) }
    $pick = @($bracketHits | Sort-Object { $_.loose.Length } -Descending)[0]
    $game = $pick.game; $alias = $pick.alias
    if ($pick.shared) { $reasons.Add('複数ゲームで共有される名前: ' + $pick.alias) }
  } elseif ($titleGames.Count -ge 1) {
    $matchType = 'title'
    $pick = @($titleHits | Sort-Object { $_.end - $_.start } -Descending)[0]
    $game = $pick.entry.game; $alias = $pick.entry.alias
    if ($pick.entry.shortAscii) { $reasons.Add('短い英数字名が【】の外で一致: ' + $pick.entry.alias) }
    elseif (@($brackets | Where-Object { $_.Contains($pick.entry.loose) }).Count -gt 0) { $reasons.Add('【】の中身と一部だけ一致: ' + $pick.entry.alias) }
    else { $reasons.Add('【】の外で一致: ' + $pick.entry.alias) }
    if ($pick.entry.shared) { $reasons.Add('複数ゲームで共有される名前: ' + $pick.entry.alias) }
  } else {
    # 3) 説明欄: 「配信タイトル:」の行は MEDIUM まで、それ以外は LOW
    $descLines = @(($description -split "`n") | Where-Object { $_ })
    $streamLine = @($descLines | Where-Object { (Get-StandaloneNorm $_) -match '^配信たいとる\s*[:：]' })
    foreach ($src in @(@{ type = 'description-stream-title'; text = ($streamLine -join ' ') }, @{ type = 'description'; text = $description })) {
      if (-not $src.text) { continue }
      $hits = @(Get-StandaloneSpanMatches $index (New-StandaloneMatchText $src.text))
      $hits = @($hits | Where-Object { -not $_.entry.shortAscii })   # 短い英数字名は説明欄では使わない(UNO 等の誤一致防止)
      if ($hits.Count -eq 0) { continue }
      $pick = @($hits | Sort-Object { $_.end - $_.start } -Descending)[0]
      $game = $pick.entry.game; $alias = $pick.entry.alias; $matchType = $src.type
      $dg = @($hits | ForEach-Object { $_.entry.game } | Select-Object -Unique)
      if ($dg.Count -gt 1) { $reasons.Add('説明欄で複数ゲームに一致: ' + ($dg -join ' / ')) }
      $reasons.Add($(if ($src.type -eq 'description') { '説明欄でだけ一致' } else { '説明欄の「配信タイトル」行で一致' }))
      break
    }
  }
  if (-not $game) { return $null }

  $otherGames = @($titleGames | Where-Object { $_ -ne $game })
  if ($matchType -eq 'bracket-exact') { $otherGames = @($otherGames + @($bracketGames | Where-Object { $_ -ne $game }) | Select-Object -Unique) }
  if ($otherGames.Count -gt 0) { $reasons.Add('タイトルに別のゲーム名もある: ' + ($otherGames -join ' / ')) }

  $nonGame = Test-StandaloneNonGameTitle $title
  if ($nonGame) { $reasons.Add('非ゲーム語: ' + $nonGame) }
  if (Test-StandaloneSequel $title) { $reasons.Add('連番あり(続き物は再生リスト方式で拾う)') }
  if ($context -and $context.siteHasGamePlaylist -and (& $context.siteHasGamePlaylist $game)) { $reasons.Add('同じVTuber×ゲームの再生リストが登録済み') }
  $dedicated = @(); if ($context -and $context.dedicatedPlaylists) { $dedicated = @(& $context.dedicatedPlaylists $game) }
  if ($dedicated.Count -gt 0) { $reasons.Add('チャンネル側に専用再生リスト候補あり') }

  $confidence = 'MEDIUM'
  if ($nonGame -or $matchType -eq 'description') { $confidence = 'LOW' }
  elseif ($matchType -eq 'bracket-exact' -and $reasons.Count -eq 0) { $confidence = 'HIGH' }

  return [pscustomobject]@{ game = $game; confidence = $confidence; matchType = $matchType; matchedAlias = $alias; reasons = @($reasons); otherGames = $otherGames; dedicatedPlaylists = $dedicated }
}

# data-standalone.js の STANDALONE_PLAYS に登録済みの video ID(コメント行は無視)
# チャンネル側の再生リストのうち、ゲーム名(3文字以上)を境界つきで含むもの(専用再生リストの候補)
function Get-StandaloneDedicatedPlaylists($games, [string]$gameName, $playlists) {
  $g = $games | Where-Object name -eq $gameName | Select-Object -First 1
  $hits = @()
  if (-not $g) { return }
  foreach ($cp in $playlists) {
    $pt = New-StandaloneMatchText $cp.title
    foreach ($a in $g.aliases) {
      $na = (Get-StandaloneNorm $a) -replace ' ', ''
      if ((Get-StandaloneLooseKey $a).Length -ge 3 -and (Find-StandaloneCleanMatches $pt $na).Count -gt 0) { $hits += $cp; break }
    }
  }
  return $hits   # 呼び出し側は @() で受ける(0件なら何も返さない)
}

function Get-StandaloneRegisteredVideoIds([string]$standaloneJsText) {
  $ids = New-Object System.Collections.Generic.HashSet[string]
  if (-not $standaloneJsText) { return , $ids }
  $body = ($standaloneJsText -split "`n" | Where-Object { $_ -notmatch '^\s*//' }) -join "`n"
  $start = $body.IndexOf('const STANDALONE_PLAYS')
  if ($start -lt 0) { return , $ids }
  foreach ($m in [regex]::Matches($body.Substring($start), '(?:watch\?v=|youtu\.be/)([A-Za-z0-9_-]{11})')) { [void]$ids.Add($m.Groups[1].Value) }
  return , $ids
}
