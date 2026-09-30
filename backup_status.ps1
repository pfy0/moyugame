Set-StrictMode -Version Latest
try { $Host.UI.RawTitle = 'Backup Status - Weekly Report' } catch {}

function Copy-Board($b) {
    $out = @()
    foreach ($row in $b) { $out += ,($row.Clone()) }
    return ,$out
}

function Get-PseudoMoves($b, [int]$r, [int]$c) {
    $targets = [System.Collections.Generic.List[string]]::new()
    $piece = $b[$r][$c]
    if ($piece -eq '..') { return $targets }
    $color = $piece.Substring(0, 1)
    $kind  = $piece.Substring(1, 1)
    $add = {
        param($tr, $tc)
        if ($tr -lt 0 -or $tr -gt 9 -or $tc -lt 0 -or $tc -gt 8) { return }
        $target = $b[$tr][$tc]
        if ($target -eq '..' -or $target.Substring(0, 1) -ne $color) {
            $targets.Add("$tr,$tc")
        }
    }
    if ($kind -eq 'K') {
        $rows = if ($color -eq 'R') { 7..9 } else { 0..2 }
        foreach ($d in @(-1, 0, 1)) {
            foreach ($e in @(-1, 0, 1)) {
                if ([math]::Abs($d) + [math]::Abs($e) -eq 1) {
                    $tr = $r + $d; $tc = $c + $e
                    if ($rows -contains $tr -and $tc -ge 3 -and $tc -le 5) { & $add $tr $tc }
                }
            }
        }
    }
    elseif ($kind -eq 'A') {
        $rows = if ($color -eq 'R') { 7..9 } else { 0..2 }
        foreach ($d in @(-1, 1)) {
            foreach ($e in @(-1, 1)) {
                $tr = $r + $d; $tc = $c + $e
                if ($rows -contains $tr -and $tc -ge 3 -and $tc -le 5) { & $add $tr $tc }
            }
        }
    }
    elseif ($kind -eq 'E') {
        foreach ($d in @(-2, 2)) {
            foreach ($e in @(-2, 2)) {
                $tr = $r + $d; $tc = $c + $e
                $crossed = if ($color -eq 'R') { $tr -le 4 } else { $tr -ge 5 }
                if ($tr -ge 0 -and $tr -le 9 -and $tc -ge 0 -and $tc -le 8 -and -not $crossed) {
                    if ($b[$r + $d / 2][$c + $e / 2] -eq '..') { & $add $tr $tc }
                }
            }
        }
    }
    elseif ($kind -eq 'H') {
        foreach ($m in @(@(-2, -1), @(-2, 1), @(2, -1), @(2, 1), @(-1, -2), @(-1, 2), @(1, -2), @(1, 2))) {
            $tr = $r + $m[0]; $tc = $c + $m[1]
            if ($m[0] -eq -2) { $blockR = $r - 1; $blockC = $c }
            elseif ($m[0] -eq 2) { $blockR = $r + 1; $blockC = $c }
            elseif ($m[1] -eq -2) { $blockR = $r; $blockC = $c - 1 }
            else { $blockR = $r; $blockC = $c + 1 }
            if ($tr -ge 0 -and $tr -le 9 -and $tc -ge 0 -and $tc -le 8 -and $b[$blockR][$blockC] -eq '..') { & $add $tr $tc }
        }
    }
    elseif ($kind -eq 'R') {
        foreach ($d in @(@(-1, 0), @(1, 0), @(0, -1), @(0, 1))) {
            $tr = $r + $d[0]; $tc = $c + $d[1]
            while ($tr -ge 0 -and $tr -le 9 -and $tc -ge 0 -and $tc -le 8) {
                if ($b[$tr][$tc] -eq '..') { & $add $tr $tc }
                else { & $add $tr $tc; break }
                $tr += $d[0]; $tc += $d[1]
            }
        }
    }
    elseif ($kind -eq 'C') {
        foreach ($d in @(@(-1, 0), @(1, 0), @(0, -1), @(0, 1))) {
            $tr = $r + $d[0]; $tc = $c + $d[1]
            $jumped = $false
            while ($tr -ge 0 -and $tr -le 9 -and $tc -ge 0 -and $tc -le 8) {
                if (-not $jumped) {
                    if ($b[$tr][$tc] -eq '..') { & $add $tr $tc } else { $jumped = $true }
                }
                elseif ($b[$tr][$tc] -ne '..') { & $add $tr $tc; break }
                $tr += $d[0]; $tc += $d[1]
            }
        }
    }
    elseif ($kind -eq 'P') {
        $dir = if ($color -eq 'R') { -1 } else { 1 }
        & $add ($r + $dir) $c
        $crossed = if ($color -eq 'R') { $r -le 4 } else { $r -ge 5 }
        if ($crossed) { & $add $r ($c - 1); & $add $r ($c + 1) }
    }
    return $targets
}

function Find-King($b, $color) {
    for ($r = 0; $r -lt 10; $r++) {
        for ($c = 0; $c -lt 9; $c++) {
            if ($b[$r][$c] -eq ($color + 'K')) { return @($r, $c) }
        }
    }
    return $null
}

function Test-Attacked($b, $color) {
    $king = Find-King $b $color
    if ($null -eq $king) { return $true }
    $enemy = if ($color -eq 'R') { 'B' } else { 'R' }
    for ($r = 0; $r -lt 10; $r++) {
        for ($c = 0; $c -lt 9; $c++) {
            $piece = $b[$r][$c]
            if ($piece -ne '..' -and $piece.Substring(0, 1) -eq $enemy) {
                if ((Get-PseudoMoves $b $r $c) -contains ("$($king[0]),$($king[1])")) { return $true }
            }
        }
    }
    $enemyKing = Find-King $b $enemy
    if ($null -ne $enemyKing -and $king[1] -eq $enemyKing[1]) {
        $clear = $true
        for ($r = [math]::Min($king[0], $enemyKing[0]) + 1; $r -lt [math]::Max($king[0], $enemyKing[0]); $r++) {
            if ($b[$r][$king[1]] -ne '..') { $clear = $false; break }
        }
        if ($clear) { return $true }
    }
    return $false
}

function Get-LegalMoves($b, [int]$r, [int]$c) {
    $piece = $b[$r][$c]
    if ($piece -eq '..') { return @() }
    $color = $piece.Substring(0, 1)
    $legal = @()
    foreach ($move in (Get-PseudoMoves $b $r $c)) {
        $parts = $move.Split(',')
        $tr = [int]$parts[0]; $tc = [int]$parts[1]
        $test = Copy-Board $b
        $test[$tr][$tc] = $test[$r][$c]
        $test[$r][$c] = '..'
        if (-not (Test-Attacked $test $color)) { $legal += $move }
    }
    return $legal
}

function Show-Board($b) {
    Clear-Host
    Write-Host '=== BACKUP STATUS REPORT ===' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '     0   1   2   3   4   5   6   7   8' -ForegroundColor DarkGray
    Write-Host '   ┌────┬────┬────┬────┬────┬────┬────┬────┬────┐' -ForegroundColor DarkGray
    Write-Host ''
    for ($r = 0; $r -lt 10; $r++) {
        Write-Host (" $r ") -NoNewline -ForegroundColor DarkGray
        Write-Host '│' -NoNewline -ForegroundColor DarkGray
        for ($c = 0; $c -lt 9; $c++) {
            $piece = $b[$r][$c]
            $text = if ($piece -eq '..') { '    ' } else { ' ' + $script:display[$piece] + ' ' }
            $fg = if ($piece -eq '..') { 'DarkGray' } elseif ($piece.Substring(0, 1) -eq 'R') { 'Red' } else { 'White' }
            Write-Host $text -NoNewline -ForegroundColor $fg
            Write-Host '│' -NoNewline -ForegroundColor DarkGray
        }
        Write-Host ''
        if ($r -lt 9) {
            Write-Host '   ├────┼────┼────┼────┼────┼────┼────┼────┼────┤' -ForegroundColor DarkGray
        }
    }
    Write-Host '   └────┴────┴────┴────┴────┴────┴────┴────┴────┘' -ForegroundColor DarkGray
    Write-Host ''
}

$script:display = @{
    'bK' = '將'; 'bA' = '士'; 'bE' = '象'; 'bH' = '馬'; 'bR' = '車'; 'bC' = '砲'; 'bP' = '卒'
    'RK' = '帥'; 'RA' = '仕'; 'RE' = '相'; 'RH' = '馬'; 'RR' = '車'; 'RC' = '炮'; 'RP' = '兵'
}

function Show-BossScreen {
    Clear-Host
    Write-Host '[INFO] Running scheduled backup verification...'
    Start-Sleep -Milliseconds 400
    Write-Host '[INFO] Checking disk usage on C:\ ... 42% used'
    Start-Sleep -Milliseconds 300
    Write-Host '[WARN] Temp folder cleanup recommended'
    Start-Sleep -Milliseconds 300
    Write-Host '[INFO] Incremental backup completed successfully.'
    Write-Host '[INFO] No critical issues found.'
    Write-Host ''
    Read-Host 'Press ENTER to close this report'
}

function Show-Help {
    Write-Host 'Legend: K=King A=Advisor E=Elephant H=Horse R=Chariot C=Cannon P=Pawn'
    Write-Host 'Uppercase=Red (bottom), Lowercase=Black (top)'
    Write-Host 'Move format: fromRow fromCol toRow toCol   Example: 0 1 2 2'
    Write-Host 'Commands: h=help  u=undo  b=hide game  q=quit'
}

function Get-AIMove {
    $allMoves = @()
    for ($r = 0; $r -lt 10; $r++) {
        for ($c = 0; $c -lt 9; $c++) {
            $piece = $script:board[$r][$c]
            if ($piece -ne '..' -and $piece.Substring(0, 1) -eq 'B') {
                foreach ($move in (Get-LegalMoves $script:board $r $c)) {
                    $parts = $move.Split(',')
                    $target = $script:board[[int]$parts[0]][[int]$parts[1]]
                    $score = 0
                    if ($target -ne '..') {
                        $score = switch ($target.Substring(1, 1)) {
                            'K' { 1000 }
                            'R' { 90 }
                            'C' { 45 }
                            'H' { 40 }
                            'E' { 20 }
                            'A' { 20 }
                            'P' { 10 }
                        }
                    }
                    $allMoves += ,@([int]$r, [int]$c, [int]$parts[0], [int]$parts[1], $score)
                }
            }
        }
    }
    if ($allMoves.Count -eq 0) { return $null }
    $best = $allMoves | Sort-Object { -$_[4] } | Select-Object -First 1
    $topMoves = @($allMoves | Where-Object { $_[4] -ge $best[4] })
    return $topMoves[(Get-Random -Maximum $topMoves.Count)]
}

$script:board = @(
    ,@('bR','bH','bE','bA','bK','bA','bE','bH','bR')
    ,@( ' .',' .',' .',' .',' .',' .',' .',' .',' .')
    ,@( ' .','bC',' .',' .',' .',' .',' .','bC',' .')
    ,@('bp',' .','bp',' .','bp',' .','bp',' .','bp')
    ,@( ' .',' .',' .',' .',' .',' .',' .',' .',' .')
    ,@( ' .',' .',' .',' .',' .',' .',' .',' .',' .')
    ,@('RP',' .','RP',' .','RP',' .','RP',' .','RP')
    ,@( ' .','RC',' .',' .',' .',' .',' .','RC',' .')
    ,@( ' .',' .',' .',' .',' .',' .',' .',' .',' .')
    ,@('RR','RH','RE','RA','RK','RA','RE','RH','RR')
)
$script:turn = 'R'
$script:history = @()
$script:aiEnabled = $true
$script:running = $true

while ($script:running) {
    Show-Board $script:board
    Show-Help
    $side = if ($script:turn -eq 'R') { 'Red' } else { 'Black' }
    $inputText = Read-Host "$side to move"
    $inputText = $inputText.Trim().ToLower()

    if ($inputText -eq 'q') {
        $confirm = Read-Host 'Quit? (y/n)'
        if ($confirm -eq 'y') { $script:running = $false }
        continue
    }
    if ($inputText -eq 'b') { Show-BossScreen; continue }
    if ($inputText -eq 'u') {
        if ($script:history.Count -gt 0) {
            $last = $script:history[-1]
            $script:board = $last.Board
            $script:turn = $last.Turn
            $script:history = $script:history[0..($script:history.Count - 2)]
        }
        continue
    }
    if ($inputText -eq 'h') { continue }

    if ($inputText -match '^([0-9])\D+([0-9])\D+([0-9])\D+([0-9])$') {
        $fr = [int]$Matches[1]; $fc = [int]$Matches[2]
        $tr = [int]$Matches[3]; $tc = [int]$Matches[4]
        $piece = $script:board[$fr][$fc]
        if ($piece -eq '..') { Write-Host 'No piece there. Press ENTER.' -ForegroundColor Yellow; Read-Host; continue }
        if ($piece.Substring(0, 1) -ne $script:turn) { Write-Host 'Not your piece. Press ENTER.' -ForegroundColor Yellow; Read-Host; continue }
        $legal = Get-LegalMoves $script:board $fr $fc
        if ($legal -notcontains "$tr,$tc") { Write-Host 'Illegal move. Press ENTER.' -ForegroundColor Yellow; Read-Host; continue }

        $script:history += ,@{ Board = (Copy-Board $script:board); Turn = $script:turn }
        $captured = $script:board[$tr][$tc]
        $script:board[$tr][$tc] = $piece
        $script:board[$fr][$fc] = ' .'

        $enemy = if ($script:turn -eq 'R') { 'B' } else { 'R' }
        if ($null -eq (Find-King $script:board $enemy)) {
            Show-Board $script:board
            Write-Host "$side wins! King captured." -ForegroundColor Green
            Read-Host 'Press ENTER to exit'
            break
        }
        $enemyMoves = 0
        for ($r = 0; $r -lt 10; $r++) {
            for ($c = 0; $c -lt 9; $c++) {
                $p = $script:board[$r][$c]
                if ($p -ne '..' -and $p.Substring(0, 1) -eq $enemy) {
                    if (@(Get-LegalMoves $script:board $r $c).Count -gt 0) { $enemyMoves++; break }
                }
            }
            if ($enemyMoves -gt 0) { break }
        }
        if ($enemyMoves -eq 0) {
            Show-Board $script:board
            Write-Host "$side wins! Opponent has no legal moves." -ForegroundColor Green
            Read-Host 'Press ENTER to exit'
            break
        }
        $script:turn = $enemy

        if ($script:aiEnabled) {
            $aiMove = Get-AIMove
            if ($null -eq $aiMove) {
                Show-Board $script:board
                Write-Host 'Red wins! Black has no legal moves.' -ForegroundColor Green
                Read-Host 'Press ENTER to exit'
                break
            }
            Show-Board $script:board
            Write-Host "Black is thinking... moving $($aiMove[0]),$($aiMove[1]) to $($aiMove[2]),$($aiMove[3])"
            Start-Sleep -Milliseconds 600
            $script:history += ,@{ Board = (Copy-Board $script:board); Turn = $script:turn }
            $script:board[$aiMove[2]][$aiMove[3]] = $script:board[$aiMove[0]][$aiMove[1]]
            $script:board[$aiMove[0]][$aiMove[1]] = ' .'
            if ($null -eq (Find-King $script:board 'R')) {
                Show-Board $script:board
                Write-Host 'Black wins! King captured.' -ForegroundColor Green
                Read-Host 'Press ENTER to exit'
                break
            }
            $script:turn = 'R'
        }
        continue
    }

    Write-Host 'Invalid input. Press ENTER.' -ForegroundColor Yellow
    Read-Host
}
