<# :
:: This code is owned and belongs to Robert, Co-Owner Of Gemini
:: https://discord.gg/dZTkKRxcbr - Gemini Discord Link
:: If you are reading this.. why are you even in here? what on earth is the point of you being in here? what do you *GAIN* by being in here? oh look a bunch of GM FUNCTION WOW GENIUS. GREAT WORK. you SOLVED THE MYSTERY.
@echo off
title RobertsPatcher
set "GM_RobertsPatcherPath=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Expression ([System.IO.File]::ReadAllText($env:GM_RobertsPatcherPath))"
pause
exit /b
#>

$ErrorActionPreference = 'Stop'
$GM_ZomboidDir = Join-Path $env:USERPROFILE 'Zomboid'
$GM_RestoreFile = Join-Path $GM_ZomboidDir 'GM_RobertsPatcherRestore.txt'

function GM_ApplyGameSettings([string]$GM_DoubleSize, [string]$GM_Compression, [string]$GM_Heap) {
    $GM_SteamDir = (Get-ItemProperty -Path 'HKCU:\Software\Valve\Steam').SteamPath
    $GM_LibraryList = [IO.File]::ReadAllText((Join-Path $GM_SteamDir 'steamapps\libraryfolders.vdf'))
    $GM_LaunchFile = [regex]::Matches($GM_LibraryList, '"path"\s+"([^"]+)"') |
        ForEach-Object { Join-Path ($_.Groups[1].Value -replace '\\\\', '\') 'steamapps\common\ProjectZomboid\ProjectZomboid64.json' } |
        Where-Object { [IO.File]::Exists($_) } |
        Select-Object -First 1
    if (-not $GM_LaunchFile) { throw 'Project Zomboid was not found in your Steam libraries.' }
    $GM_IniFile = Join-Path $GM_ZomboidDir 'options.ini'
    $GM_IniBody = [IO.File]::ReadAllText($GM_IniFile)
    $GM_LaunchBody = [IO.File]::ReadAllText($GM_LaunchFile)
    $GM_OldDoubleSize = [regex]::Match($GM_IniBody, '(?m)^texture2x=(\w+)').Groups[1].Value
    $GM_OldCompression = [regex]::Match($GM_IniBody, '(?m)^textureCompression=(\w+)').Groups[1].Value
    $GM_OldHeap = [regex]::Match($GM_LaunchBody, '"\s*-Xmx([^"\s]*)\s*"').Groups[1].Value
    [IO.File]::WriteAllText($GM_IniFile, ($GM_IniBody -replace '(?m)^texture2x=\w+', "texture2x=$GM_DoubleSize" -replace '(?m)^textureCompression=\w+', "textureCompression=$GM_Compression"))
    [IO.File]::WriteAllText($GM_LaunchFile, ($GM_LaunchBody -replace '"\s*-Xmx[^"]*"', "`"-Xmx$GM_Heap`""))
    return "$GM_OldDoubleSize $GM_OldCompression $GM_OldHeap"
}

function GM_RobertPatcher {
    $GM_RamGB = (Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1GB
    $GM_Heap = if ($GM_RamGB -ge 24) { '8192m' } elseif ($GM_RamGB -ge 15) { '6144m' } else { '4096m' }
    $GM_Before = GM_ApplyGameSettings 'false' 'true' $GM_Heap
    if (-not (Test-Path -LiteralPath $GM_RestoreFile)) { [IO.File]::WriteAllText($GM_RestoreFile, $GM_Before) }
    Write-Host ''
    Write-Host 'Double-size textures turned off, texture compression turned on.' -ForegroundColor Green
    Write-Host ('Game memory limit set to ' + $GM_Heap + ' for this PC''s ' + [math]::Round($GM_RamGB) + ' GB of RAM.') -ForegroundColor Green
    if ($GM_RamGB -lt 15) { Write-Host 'Your PC somehow has LESS then 16 gig? dude... im so sorry for you, so this server may still be too heavy for your machine..' -ForegroundColor Yellow }
    Write-Host ''
    if ((Read-Host 'Do you want to delete your server cache? this may help with joining the server. [Yes/No]') -match '^\s*y') {
        Get-ChildItem -LiteralPath (Join-Path $GM_ZomboidDir 'Saves\Multiplayer') -Directory -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
        Write-Host 'Server cache deleted.' -ForegroundColor Green
    }
    Write-Host ''
    Write-Host 'All done! just start your game again for this all to take effect.... or will it? this is a joke.' -ForegroundColor Green
    Write-Host 'If you are seeing this Taylor.... be warned.'
}

function GM_UndoRobertPatcher {
    $GM_Saved = 'true false 3072m'
    if (Test-Path -LiteralPath $GM_RestoreFile) { $GM_Saved = [IO.File]::ReadAllText($GM_RestoreFile) }
    $GM_DoubleSize, $GM_Compression, $GM_Heap = -split $GM_Saved
    [void](GM_ApplyGameSettings $GM_DoubleSize $GM_Compression $GM_Heap)
    Remove-Item -LiteralPath $GM_RestoreFile -ErrorAction SilentlyContinue
    Write-Host ''
    Write-Host 'Textures and game memory limit restored.' -ForegroundColor Green
}

function GM_ReadLastJoin {
    $GM_NewestLog = @(Get-Item -LiteralPath (Join-Path $GM_ZomboidDir 'console.txt') -ErrorAction SilentlyContinue) + @(Get-ChildItem -LiteralPath (Join-Path $GM_ZomboidDir 'Logs') -Recurse -Filter '*DebugLog*.txt' -ErrorAction SilentlyContinue) | Sort-Object LastWriteTime | Select-Object -Last 1
    if (-not $GM_NewestLog) {
        Write-Host 'No game log found. Start the game and try joining the server first.' -ForegroundColor Yellow
        return
    }
    $GM_LogBody = [IO.File]::ReadAllText($GM_NewestLog.FullName)
    $GM_JoinStart = $GM_LogBody.LastIndexOf('ConnectToServerState: Start')
    $GM_JoinLog = if ($GM_JoinStart -ge 0) { $GM_LogBody.Substring($GM_JoinStart) } else { '' }
    $GM_Crash = [regex]::Match($GM_JoinLog, 'GameLoadingState\$1\.run> Exception thrown\s+([^\r\n]+)').Groups[1].Value
    $GM_Stuck = $GM_JoinLog.Contains('isBusy() loop start') -and -not $GM_JoinLog.Contains('isBusy() loop end')
    $GM_Loaded = $GM_JoinLog.Contains('game loading took')
    $GM_Verdict = if ($GM_JoinStart -lt 0) {
        'The log shows no attempt to join any server.'
    } elseif ($GM_Crash -match 'square is null') {
        'Loading crashed because the ground under your character never loaded.'
    } elseif ($GM_Crash -match 'Timed out waiting for the server to send player data') {
        'The server did not send your character within 30 seconds. Try again in a few minutes.'
    } elseif ($GM_Crash) {
        'Loading crashed with an error.'
    } elseif ($GM_Stuck) {
        'Stuck downloading the map around your character. The server never finished sending some map chunks.'
    } elseif ($GM_Loaded) {
        'Your last join got past "Loading the world". This log does not show that problem.'
    } else {
        'the log stops partway through joining the server, could be you ran out of ram, crashing your game.'
    }
    Write-Host ''
    Write-Host ('Checking ' + $GM_NewestLog.Name + ' from ' + $GM_NewestLog.LastWriteTime.ToString('yyyy-MM-dd HH:mm'))
    Write-Host ('Result: ' + $GM_Verdict) -ForegroundColor $(if ($GM_Loaded -and -not $GM_Crash -and -not $GM_Stuck) { 'Green' } else { 'Yellow' })
    if ($GM_Crash) { Write-Host ('Error: ' + $GM_Crash) }
    $GM_StuckChunks = [regex]::Matches($GM_JoinLog, 'did not generate the chunk (-?\d+,-?\d+)') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique | Select-Object -First 5
    if ($GM_Stuck -and -not $GM_Crash -and $GM_StuckChunks) { Write-Host ('Chunks the server kept failing on: ' + ($GM_StuckChunks -join '  ') + '  (send these to the admin)') }
    $GM_LogCopy = Join-Path ([Environment]::GetFolderPath('Desktop')) ('GM_PZLog_' + (Get-Date -Format 'yyyy-MM-dd_HH-mm') + '.txt')
    Copy-Item -LiteralPath $GM_NewestLog.FullName -Destination $GM_LogCopy
    Write-Host ('Saved a copy for the server admin: ' + $GM_LogCopy)
}

function GM_RobertsPatcherMenu {
    if (Get-Process -Name 'ProjectZomboid64' -ErrorAction SilentlyContinue) {
        Write-Host 'Close Project Zomboid first, then open RobertsPatcher again.' -ForegroundColor Yellow
        return
    }
    while ($true) {
        Write-Host ''
        Write-Host 'RobertsPatcher' -ForegroundColor Magenta
        Write-Host '  [1] ROBERT PATCHER'
        Write-Host '      A simple little fix that should resolve ram or loading in issues for some - 60% of the time, it works every time."' -ForegroundColor DarkGray
        Write-Host ''
        Write-Host '  Extras' -ForegroundColor Magenta
        Write-Host '    [2] Check My Last Join Attempt'
        Write-Host '    [3] Reset'
        Write-Host ''
        Write-Host '  [Q] Quit'
        switch (Read-Host 'Choose') {
            '1' { GM_RobertPatcher }
            '2' { GM_ReadLastJoin }
            '3' { GM_UndoRobertPatcher }
            'q' { return }
        }
    }
}

try { GM_RobertsPatcherMenu }
catch { Write-Host ('Something went wrong: ' + $_.Exception.Message) -ForegroundColor Red }
