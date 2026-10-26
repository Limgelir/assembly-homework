param(
    [string]$DosBoxPath = 'C:\Program Files (x86)\DOSBox-0.74\DOSBox.exe',
    [string]$DebugPath = 'D:\ASM\DEBUG.COM'
)

$ErrorActionPreference = 'Stop'
$work = Join-Path $PSScriptRoot '.verify'
$ascii = [Text.Encoding]::ASCII
$reports = New-Object 'System.Collections.Generic.List[string]'
foreach ($path in @($DosBoxPath,$DebugPath,(Join-Path $PSScriptRoot 'c\NINE_C.EXE'))) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw ('Required program not found: '+$path) }
}
New-Item -ItemType Directory -Path $work -Force | Out-Null
foreach ($name in @('NINE.EXE','CALLDBG.TXT','ALLDBG.TXT')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('asm\'+$name)) -Destination $work -Force
}
Copy-Item -LiteralPath $DebugPath -Destination (Join-Path $work 'DEBUG.COM') -Force
foreach ($name in @('DONE.TXT','FAIL.TXT','NINE.OUT','CALL.LOG','ALL.LOG')) {
    $path=Join-Path $work $name
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
}
$batch=@'
@echo off
nine > NINE.OUT
if errorlevel 1 goto failed
debug NINE.EXE < CALLDBG.TXT > CALL.LOG
if errorlevel 1 goto failed
debug NINE.EXE < ALLDBG.TXT > ALL.LOG
if errorlevel 1 goto failed
echo OK>DONE.TXT
goto finished
:failed
echo FAIL>FAIL.TXT
:finished
exit
'@
$config=@'
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
[IO.File]::WriteAllText((Join-Path $work 'RUN.BAT'),($batch -replace '\r?\n',"`r`n")+"`r`n",$ascii)
[IO.File]::WriteAllText((Join-Path $work 'dosbox.conf'),($config -replace '\r?\n',"`r`n")+"`r`n",$ascii)
$savedVideo=$env:SDL_VIDEODRIVER
$savedAudio=$env:SDL_AUDIODRIVER
$p=New-Object System.Diagnostics.Process
$p.StartInfo.FileName=$DosBoxPath
$p.StartInfo.Arguments='-conf dosbox.conf -noconsole'
$p.StartInfo.WorkingDirectory=$work
$p.StartInfo.UseShellExecute=$false
$p.StartInfo.CreateNoWindow=$true
try {
    $env:SDL_VIDEODRIVER='dummy'
    $env:SDL_AUDIODRIVER='dummy'
    if (-not $p.Start()) { throw 'Could not start DOSBox.' }
    if (-not $p.WaitForExit(60000)) { $p.Kill(); throw 'DOSBox timed out.' }
    if ($p.ExitCode -ne 0) { throw 'DOSBox failed.' }
} finally {
    $p.Dispose()
    $env:SDL_VIDEODRIVER=$savedVideo
    $env:SDL_AUDIODRIVER=$savedAudio
}
if ((Test-Path -LiteralPath (Join-Path $work 'FAIL.TXT')) -or
    -not (Test-Path -LiteralPath (Join-Path $work 'DONE.TXT'))) { throw 'DOS program/debug run failed.' }

$p=New-Object System.Diagnostics.Process
$p.StartInfo.FileName=Join-Path $PSScriptRoot 'c\NINE_C.EXE'
$p.StartInfo.WorkingDirectory=$work
$p.StartInfo.UseShellExecute=$false
$p.StartInfo.CreateNoWindow=$true
$p.StartInfo.RedirectStandardOutput=$true
$p.StartInfo.RedirectStandardError=$true
try {
    if (-not $p.Start()) { throw 'Could not start NINE_C.EXE.' }
    $stdoutTask=$p.StandardOutput.ReadToEndAsync()
    $stderrTask=$p.StandardError.ReadToEndAsync()
    if (-not $p.WaitForExit(10000)) { $p.Kill(); throw 'C program timed out.' }
    $exitCode=$p.ExitCode
    $cOutput=$stdoutTask.Result
    $cError=$stderrTask.Result
} finally { $p.Dispose() }
[IO.File]::WriteAllText((Join-Path $work 'C.OUT'),$cOutput,$ascii)
if ($exitCode -ne 0 -or $cError.Length -ne 0) { throw 'C program failed.' }

# Independent product oracle: repeated addition instead of multiplication.
$expected="The 9mul9 table:`r`n"
$positions=New-Object 'System.Collections.Generic.List[object]'
for ($row=9; $row -ge 1; $row--) {
    for ($column=1; $column -le $row; $column++) {
        $product=0
        for ($i=0; $i -lt $column; $i++) { $product+=$row }
        $cell='{0}*{1}={2}' -f $row,$column,$product
        if ($column -lt $row) { $cell=$cell.PadRight(9) }
        $expected+=$cell
        $positions.Add([pscustomobject]@{ Row=$row; Column=$column })
    }
    $expected+="`r`n"
}
$dosOutput=[IO.File]::ReadAllText((Join-Path $work 'NINE.OUT'),$ascii)
foreach ($item in @(@('DOS',$dosOutput),@('C',$cOutput))) {
    if ($item[1] -cne $expected) { throw ('Incorrect '+$item[0]+' table; inspect '+$work) }
    $reports.Add('PASS '+$item[0]+': 45 correct products; rows 9..1; 9-column alignment; CRLF; no trailing spaces; exit=0.')
}
$reports.Add(('PASS DOS and C outputs identical ({0} bytes).' -f $ascii.GetByteCount($expected)))

function Read-States([string]$log) {
    $pattern='AX=(?<AX>[0-9A-F]{4}) BX=(?<BX>[0-9A-F]{4}) CX=(?<CX>[0-9A-F]{4}) DX=(?<DX>[0-9A-F]{4}) SP=(?<SP>[0-9A-F]{4}) BP=(?<BP>[0-9A-F]{4}) SI=(?<SI>[0-9A-F]{4}) DI=(?<DI>[0-9A-F]{4})\s+DS=(?<DS>[0-9A-F]{4}) ES=(?<ES>[0-9A-F]{4}) SS=(?<SS>[0-9A-F]{4}) CS=(?<CS>[0-9A-F]{4}) IP=(?<IP>[0-9A-F]{4})'
    foreach ($match in [regex]::Matches($log,$pattern)) {
        $state=[ordered]@{}
        foreach ($key in @('AX','BX','CX','DX','SP','BP','SI','DI','DS','ES','SS','CS','IP')) { $state[$key]=$match.Groups[$key].Value }
        [pscustomobject]$state
    }
}
function Require($condition,[string]$message) { if (-not $condition) { throw $message } }
$traceText=[IO.File]::ReadAllText((Join-Path $work 'CALL.LOG'),$ascii)
$allText=[IO.File]::ReadAllText((Join-Path $work 'ALL.LOG'),$ascii)
foreach ($log in @($traceText,$allText)) {
    Require ($log.Contains('Program terminated normally (0000)')) 'DEBUG run did not terminate normally.'
}
$trace=@(Read-States $traceText)
Require ($trace.Count -eq 8) 'Expected 8 snapshots in CALL.LOG.'
$ips=@('0000','0019','002D','0049','0060','0064','001C','0028')
$sps=@('0100','00FE','00FC','00F4','00F4','00FC','00FE','0100')
for ($i=0; $i -lt 8; $i++) {
    Require ($trace[$i].IP -ceq $ips[$i] -and $trace[$i].SP -ceq $sps[$i]) ('Unexpected CALL/RET state at snapshot '+$i)
}
Require ($traceText -match '(?m)^[0-9A-F]{4}:00F0[^\r\n]*1C 00') 'Missing stacked return IP 001C.'
Require ($trace[3].AX -ceq '0009') 'MUL 9*1 did not produce AX=0009.'
Require ($trace[4].CX -ceq '0000' -and $trace[6].CX -ceq '0009') 'Padding CX was not restored.'
$reports.Add('PASS CALL/RET trace: return IP=001C; SP 0100->00FE->00FC->00F4->00FC->00FE->0100; MUL result=9; CX 9->0->9.')

$states=@(Read-States $allText)
Require ($states.Count -eq 91) 'Expected 90 before/after snapshots and one final snapshot.'
for ($i=0; $i -lt 45; $i++) {
    $before=$states[2*$i]
    $after=$states[2*$i+1]
    Require ($before.IP -ceq '0019' -and $after.IP -ceq '001C') 'Unexpected CALL/RET addresses.'
    foreach ($reg in @('AX','BX','CX','DX','SP','BP','SI','DI','DS','ES','SS','CS')) {
        Require ($before.$reg -ceq $after.$reg) ('Register '+$reg+' was not preserved on call '+($i+1))
    }
    $row=$positions[$i].Row
    $column=$positions[$i].Column
    $expectedBX=('{0:X2}{1:X2}' -f $row,$column)
    Require ($before.BX -ceq $expectedBX) 'Incorrect row/column registers.'
    Require ([Convert]::ToInt32($before.CX,16) -eq ($row-$column+1)) 'Incorrect inner CX.'
    Require ($before.SP -ceq '00FE') 'Stack was not balanced between cells.'
}
Require ($states[90].IP -ceq '0028' -and $states[90].SP -ceq '0100' -and $states[90].CX -ceq '0000') 'Final stack/outer loop state is wrong.'
$reports.Add('PASS all 45 print_cell calls preserve AX/BX/CX/DX/SP/BP/SI/DI/DS/ES/SS/CS; loop counters correct; final SP=0100.')
$reports.Add('PASS homework04: output, multiplication, nested loops, CALL/RET, and register/stack preservation verified.')
[IO.File]::WriteAllText((Join-Path $work 'RESULTS.TXT'),($reports -join "`r`n")+"`r`n",$ascii)
$reports
Write-Output ('Captured output and DEBUG logs: '+$work)
