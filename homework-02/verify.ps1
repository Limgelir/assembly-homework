param(
    [string]$DosBoxPath = 'C:\Program Files (x86)\DOSBox-0.74\DOSBox.exe'
)

$ErrorActionPreference = 'Stop'
$taskRoot = $PSScriptRoot
$work = Join-Path $taskRoot '.verify'
$ascii = [System.Text.Encoding]::ASCII
$expected = "a b c d e f g h i j k l m`r`nn o p q r s t u v w x y z`r`n"

foreach ($required in @($DosBoxPath,
    (Join-Path $taskRoot 'asm\ASCIILP.EXE'),
    (Join-Path $taskRoot 'asm\ASCIIJMP.EXE'),
    (Join-Path $taskRoot 'c\ASCII_C.EXE'))) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw ('Required program not found: ' + $required)
    }
}

New-Item -ItemType Directory -Path $work -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $taskRoot 'asm\ASCIILP.EXE'),
    (Join-Path $taskRoot 'asm\ASCIIJMP.EXE') -Destination $work -Force

# Remove only the previous completion markers owned by this verifier.
foreach ($marker in @('DONE.TXT','FAILED.TXT')) {
    $markerPath = Join-Path $work $marker
    if (Test-Path -LiteralPath $markerPath) {
        Remove-Item -LiteralPath $markerPath -Force
    }
}

$dosBatch = @'
@echo off
asciilp > loop.txt
if errorlevel 1 goto failed
asciijmp > jump.txt
if errorlevel 1 goto failed
echo OK> DONE.TXT
exit
:failed
echo FAIL> FAILED.TXT
exit
'@
$dosConfig = @'
[sdl]
fullscreen=false
output=surface
[mixer]
nosound=true
[autoexec]
mount c .
c:
call run.bat
exit
'@
[System.IO.File]::WriteAllText((Join-Path $work 'RUN.BAT'),
    ($dosBatch -replace "\r?\n", "`r`n") + "`r`n", $ascii)
[System.IO.File]::WriteAllText((Join-Path $work 'dosbox.conf'),
    ($dosConfig -replace "\r?\n", "`r`n") + "`r`n", $ascii)

$savedVideo = $env:SDL_VIDEODRIVER
$savedAudio = $env:SDL_AUDIODRIVER
try {
    $env:SDL_VIDEODRIVER = 'dummy'
    $env:SDL_AUDIODRIVER = 'dummy'
    $dosProcess = Start-Process -FilePath $DosBoxPath -WorkingDirectory $work `
        -ArgumentList '-conf dosbox.conf -noconsole' -WindowStyle Hidden -PassThru
    if (-not $dosProcess.WaitForExit(30000)) {
        Stop-Process -Id $dosProcess.Id
        throw 'DOSBox timed out.'
    }
    if ($dosProcess.ExitCode -ne 0) { throw 'DOSBox exited with an error.' }
} finally {
    $env:SDL_VIDEODRIVER = $savedVideo
    $env:SDL_AUDIODRIVER = $savedAudio
}

$done = Join-Path $work 'DONE.TXT'
if (-not (Test-Path -LiteralPath $done)) { throw 'DOS programs did not finish.' }
if ([System.IO.File]::ReadAllText($done).Trim() -ne 'OK') {
    throw 'Unexpected DOS completion marker.'
}
if (Test-Path -LiteralPath (Join-Path $work 'FAILED.TXT')) {
    throw 'A DOS program returned a failure code.'
}

$cOutput = Join-Path $work 'c.txt'
$cError = Join-Path $work 'c-error.txt'
$cProcess = Start-Process -FilePath (Join-Path $taskRoot 'c\ASCII_C.EXE') `
    -WorkingDirectory $work -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput $cOutput -RedirectStandardError $cError
if (-not $cProcess.WaitForExit(15000)) {
    Stop-Process -Id $cProcess.Id
    throw 'The C program timed out.'
}
if ($cProcess.ExitCode -ne 0) { throw 'The C program returned a failure code.' }
if ((Get-Item -LiteralPath $cError).Length -ne 0) {
    throw 'The C program wrote an error message.'
}

$results = @()
foreach ($case in @(
    @{Name='ASCIILP (LOOP)'; File='loop.txt'},
    @{Name='ASCIIJMP (conditional jumps)'; File='jump.txt'},
    @{Name='ASCII_C (C language)'; File='c.txt'})) {
    $actual = [System.IO.File]::ReadAllText((Join-Path $work $case.File), $ascii)
    if ($actual -cne $expected) {
        throw ('Incorrect output from ' + $case.Name + '. See ' + $work)
    }
    $results += 'PASS ' + $case.Name + ': a-z exactly once; 2 rows; 13 letters per row; spaces and CRLF correct.'
}
$results += 'PASS all three outputs are byte-for-byte identical ASCII text (54 bytes).'
[System.IO.File]::WriteAllText((Join-Path $work 'RESULTS.TXT'),
    ($results -join "`r`n") + "`r`n", $ascii)
$results
Write-Output ('Output files: ' + $work)
