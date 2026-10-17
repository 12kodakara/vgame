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

# 一致箇所(stripped 上の [start, end))の前後が & / + で、その先が英数字なら「つながった語」(空白で区切られていれば対象外)
function Test-StandaloneJoinedAscii($ctx, $span) {
  $isAlnum = { param($c) ($c -ge 'a' -and $c -le 'z') -or ($c -ge '0' -and $c -le '9') }
  $prev = $ctx.map[$span[0]] - 1
  if ($prev -ge 1 -and '&+'.Contains([string]$ctx.collapsed[$prev]) -and (& $isAlnum $ctx.collapsed[$prev - 1])) { return $true }
  $next = $ctx.map[$span[1] - 1] + 1
  if ($next + 1 -lt $ctx.collapsed.Length -and '&+'.Contains([string]$ctx.collapsed[$next]) -and (& $isAlnum $ctx.collapsed[$next + 1])) { return $true }
  return $false
}

# 【】の中身がそれだけで楽曲・公式映像を表すもの(単語の一律除外ではなく、【】全体がこの表記のときだけ非ゲーム扱い)
$script:StandaloneNonGameBracketLabels = @('original', 'official', 'music video', 'lyric video')

function Test-StandaloneNonGameTitle([string]$title) {
  foreach ($b in @(Get-StandaloneBrackets $title)) {
    $key = (Get-StandaloneNorm $b) -replace '\s+', ' '
    if ($script:StandaloneNonGameBracketLabels -contains $key.Trim()) { return $key.Trim() }
  }
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
      # 短い英数字名が & / + で英数字とつながっている場合は別の語の一部とみなす(例:「Stray&Stay」の「Stray」)
      if ($e.shortAscii -and (Test-StandaloneJoinedAscii $ctx $sp)) { continue }
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

# ============================================================
# 未登録作品の候補(GAMES のどれとも一致しなかった動画から、作品名らしい語を取り出す。watch-standalone-rss.ps1 から使う)
#   取り出し元: (1)【】[] の中身(VTuber名・事務所名を含む表記、# で始まるハッシュタグは除く)
#             (2) タイトル本文の英字の語のまとまり(2語以上で、大文字で始まる語が2つ以上。例: Japanese Ramen Simulator)
#   動画ごと除外: 非ゲーム語(Test-StandaloneNonGameTitle)、または下の $StandaloneUnknownExtraNonGameWords を含むタイトル
#   必須条件: タイトルか説明欄にゲームを表す語(下の $StandaloneGameSignalWords)があること
#   信頼度: タイトルにゲームを表す語があれば MEDIUM、説明欄だけなら LOW(HIGH にはしない。作品マスタには登録しない)
#   既存の照合(Get-StandaloneMatch)の判定には影響しない
# ============================================================
$script:StandaloneUnknownExtraNonGameWords = @('セール', 'sale', '案件', '提供', 'dance', '踊ってみた', '生誕', '3d live')
$script:StandaloneGameSignalWords = @('ゲーム', '実況', 'プレイ', '攻略', 'クリア', '初見', 'あそびます', '遊びます', 'fps', 'tps', 'rpg', 'pve', 'pvp', 'simulator', 'シミュレーター', 'dlc', 'ガチャ')
$script:StandaloneAgencyWords = @('ホロライブ', 'hololive', 'にじさんじ', 'nijisanji', 'ぶいすぽ', 'vspo')

# $words のうち $text に含まれる最初の語。無ければ $null
#   英数字だけの語は、前後が英数字でないこと(英単語の一部ではないこと)を確かめる。日本語の文中の略語(「100人対戦FPS」)は一致させる。
#   ゲーム名の照合(Find-StandaloneCleanMatches)は漢字の隣も「つながった語」とみなすが、ここはゲームを表す語の有無を見るだけなので英数字の隣だけを見る
function Find-StandaloneWord([string]$text, [string[]]$words) {
  $ctx = New-StandaloneMatchText $text
  foreach ($w in $words) {
    $nw = (Get-StandaloneNorm $w) -replace ' ', ''
    if ($nw -match '^[a-z0-9]+$') {
      if ([regex]::IsMatch($ctx.collapsed, '(?<![a-z0-9])' + [regex]::Escape($nw) + '(?![a-z0-9])')) { return $w }
    }
    elseif ($ctx.stripped.Contains($nw)) { return $w }
  }
  return $null
}

function Get-StandaloneUnknownGameCandidates($index, [string]$title, [string]$description) {
  $out = @()
  if (-not $title) { return , $out }
  if (Test-StandaloneNonGameTitle $title) { return , $out }
  if (Find-StandaloneWord $title $script:StandaloneUnknownExtraNonGameWords) { return , $out }
  $titleSignal = Find-StandaloneWord $title $script:StandaloneGameSignalWords
  $descSignal = if ($titleSignal) { $null } else { Find-StandaloneWord $description $script:StandaloneGameSignalWords }
  if (-not $titleSignal -and -not $descSignal) { return , $out }

  $names = New-Object System.Collections.Generic.List[object]
  # (1) 【】[] の中身
  foreach ($m in [regex]::Matches($title, '【([^】]+)】|\[([^\]]+)\]')) {
    $raw = $(if ($m.Groups[1].Success) { $m.Groups[1].Value } else { $m.Groups[2].Value }).Trim()
    if (-not $raw -or $raw.StartsWith('#') -or $raw.StartsWith('＃')) { continue }
    $nz = (Get-StandaloneNorm $raw) -replace ' ', ''
    if (@($index.streamerNames | Where-Object { $nz.Contains($_) }).Count -gt 0) { continue }   # VTuber名の表記
    if (@($script:StandaloneAgencyWords | Where-Object { $nz.Contains(((Get-StandaloneNorm $_) -replace ' ', '')) }).Count -gt 0) { continue }
    $names.Add([pscustomobject]@{ name = $raw; source = 'bracket' })
  }
  # (2) タイトル本文の英字の語のまとまり(【】[] とハッシュタグを除いた部分から探す)
  $body = [regex]::Replace($title, '【[^】]*】|\[[^\]]*\]|[#＃]\S+', ' ')
  foreach ($m in [regex]::Matches($body, "[A-Za-z0-9][A-Za-z0-9:'’\-]*(?: [A-Za-z0-9:'’\-]+)+")) {
    $phrase = $m.Value.Trim().TrimEnd(':', '-')
    $words = @($phrase -split ' ' | Where-Object { $_ })
    if ($words.Count -lt 2 -or @($words | Where-Object { $_ -cmatch '^[A-Z0-9]' }).Count -lt 2) { continue }
    $names.Add([pscustomobject]@{ name = $phrase; source = 'title-phrase' })
  }

  foreach ($n in $names) {
    $key = Get-StandaloneLooseKey $n.name
    if ($key.Length -lt 3) { continue }
    if (@($out | Where-Object { $_.key -eq $key }).Count -gt 0) { continue }
    $reasons = @()
    if ($n.source -eq 'bracket') { $reasons += '【】の中の語' } else { $reasons += 'タイトル本文の英字の語' }
    $reasons += $(if ($titleSignal) { 'タイトルにゲームを表す語: ' + $titleSignal } else { '説明欄にだけゲームを表す語: ' + $descSignal })
    # 表記揺れの可能性: 既存作品の名前と正規化キーが一致・一部一致するもの(4文字以上)
    $possible = @()
    foreach ($e in $index.entries) {
      if ($e.loose -eq $key -or ($key.Length -ge 4 -and $e.loose.Length -ge 4 -and ($e.loose.Contains($key) -or $key.Contains($e.loose)))) { $possible += $e.game }
    }
    $out += [pscustomobject]@{
      name = $n.name; key = $key; source = $n.source
      confidence = $(if ($titleSignal) { 'MEDIUM' } else { 'LOW' })
      reasons = $reasons; possibleExisting = @($possible | Select-Object -Unique)
    }
  }
  return , $out
}

# ============================================================
# 単発実況 → 再生リスト移行の判定(audit-standalone-migration.ps1 から使う。データは変更しない)
# ============================================================
# STANDALONE_PLAYS の1件について、後日できたゲーム専用再生リストへ移行すべきかを判定する。
#   STRONG : サイト登録済み再生リストに 同じVTuber × 同じgame があり、単発実況の動画がその再生リスト内にもある
#   MEDIUM : 同じVTuber × 同じgame の登録済み再生リストはあるが、動画が再生リスト内に無い / 確認していない
#   WEAK   : VTuber × game を確定できないが関連の可能性がある
#            (同じVTuberの別gameの再生リストのタイトルにゲーム名がある、同じVTuberの別gameの再生リストに動画がある、
#             チャンネル側にサイト未登録のゲーム名入り再生リストがある)
#   NONE   : 該当なし(正常)
# VTuber・game は名前の完全一致で比べる(PLAYLISTS / STANDALONE_PLAYS はどちらも GAMES の正式名で game を持つ)。
# 別VTuberの同じgame、同じVTuberの別gameは、タイトルにゲーム名が無い限り候補にしない。
# どの判定でも自動削除・自動移行はしない(人が確認して、再生リスト追加と単発実況削除を同じ commit で行う)。
function Get-StandaloneVideoIdsOf($play) {
  $ids = @()
  foreach ($v in @($play.videos)) {
    if ($v -and $v.url) { $m = [regex]::Match([string]$v.url, '(?:watch\?v=|youtu\.be/)([A-Za-z0-9_-]{11})'); if ($m.Success) { $ids += $m.Groups[1].Value } }
  }
  return , @($ids | Select-Object -Unique)
}

#   $play            : STANDALONE_PLAYS の1件(id / streamer / game / videos[].url)
#   $sitePlaylists   : PLAYLISTS(id / title / streamer / game / playlistId)
#   $games           : GAMES(name / aliases。aliases は name 等を含む照合用の名前一覧)
#   $playlistVideos  : playlistId → 動画IDの配列 のハッシュ。未取得の再生リストはキーが無い(=確認できない)
#   $channelPlaylists: チャンネル側の再生リスト(id / title / count)。省略可(省略時はチャンネル側を見ない)
function Get-StandaloneMigrationStatus($play, $sitePlaylists, $games, $playlistVideos = @{}, $channelPlaylists = $null) {
  $videoIds = Get-StandaloneVideoIdsOf $play
  $contains = {
    param($plId)
    if (-not $playlistVideos -or -not $playlistVideos.ContainsKey($plId)) { return $null }
    return (@($videoIds | Where-Object { @($playlistVideos[$plId]) -contains $_ }).Count -gt 0)
  }
  $mine = @($sitePlaylists | Where-Object { $_.streamer -eq $play.streamer })
  $exact = @($mine | Where-Object { $_.game -eq $play.game })
  $found = @()
  $reasons = @()
  if ($exact.Count) {
    foreach ($pl in $exact) { $found += [pscustomobject]@{ source = 'site'; id = $pl.id; title = $pl.title; game = $pl.game; playlistId = $pl.playlistId; videoInPlaylist = (& $contains $pl.playlistId) } }
    if (@($found | Where-Object { $_.videoInPlaylist -eq $true }).Count) {
      $level = 'STRONG'; $reasons += '同じVTuber × 同じgame の登録済み再生リストに、単発実況の動画も入っている'
    } else {
      $level = 'MEDIUM'
      $reasons += '同じVTuber × 同じgame の登録済み再生リストがある'
      if (@($found | Where-Object { $_.videoInPlaylist -eq $false }).Count) { $reasons += '単発実況の動画は再生リスト内に無い(移行すると動画がサイトから見えなくなる可能性)' }
      if (@($found | Where-Object { $null -eq $_.videoInPlaylist }).Count) { $reasons += '再生リスト内の動画は確認していない' }
    }
  } else {
    # 同じVTuberの別gameの再生リスト: タイトルにゲーム名がある / 単発実況の動画が入っている
    $titled = @(Get-StandaloneDedicatedPlaylists $games $play.game @($mine | ForEach-Object { [pscustomobject]@{ id = $_.id; title = $_.title; game = $_.game; playlistId = $_.playlistId } }))
    foreach ($pl in $mine) {
      $byTitle = @($titled | Where-Object { $_.id -eq $pl.id }).Count -gt 0
      $inPl = & $contains $pl.playlistId
      if ($byTitle -or $inPl -eq $true) {
        $found += [pscustomobject]@{ source = 'site'; id = $pl.id; title = $pl.title; game = $pl.game; playlistId = $pl.playlistId; videoInPlaylist = $inPl }
        if ($byTitle) { $reasons += "登録済み再生リスト「$($pl.title)」のタイトルにゲーム名があるが、登録上の game は「$($pl.game)」" }
        if ($inPl -eq $true) { $reasons += "単発実況の動画が、別 game(「$($pl.game)」)で登録された再生リスト「$($pl.title)」に入っている" }
      }
    }
    # チャンネル側でサイト未登録の、ゲーム名入り再生リスト
    if ($null -ne $channelPlaylists) {
      $registeredIds = @($sitePlaylists | ForEach-Object { $_.playlistId })
      $unregistered = @($channelPlaylists | Where-Object { $registeredIds -notcontains $_.id })
      foreach ($cp in @(Get-StandaloneDedicatedPlaylists $games $play.game $unregistered)) {
        $inPl = & $contains $cp.id
        $found += [pscustomobject]@{ source = 'channel'; id = $null; title = $cp.title; game = $null; playlistId = $cp.id; videoInPlaylist = $inPl }
        $reasons += "チャンネル側に、サイト未登録のゲーム名入り再生リスト「$($cp.title)」がある(先に再生リストとして登録するか確認)"
      }
    }
    $level = $(if ($found.Count) { 'WEAK' } else { 'NONE' })
    if (-not $found.Count) { $reasons += '対応するゲーム専用再生リストなし' }
  }
  return [pscustomobject]@{ id = $play.id; streamer = $play.streamer; game = $play.game; videoIds = @($videoIds); level = $level; playlists = @($found); reasons = @($reasons) }
}
