param(
    [string]$DosBoxPath='C:\Program Files (x86)\DOSBox-0.74\DOSBox.exe',
    [string]$DebugPath='D:\ASM\DEBUG.COM'
)
$ErrorActionPreference='Stop'
$work=Join-Path $PSScriptRoot '.verify'
$ascii=[Text.Encoding]::ASCII
New-Item -ItemType Directory -Path $work -Force | Out-Null
foreach($name in @('CHECK.EXE','CHECKDBG.TXT','ALLDBG.TXT')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('asm\'+$name)) -Destination $work -Force
}
Copy-Item -LiteralPath $DebugPath -Destination (Join-Path $work 'DEBUG.COM') -Force
foreach($name in @('DONE.TXT','FAIL.TXT','DEFAULT.OUT','TRACE.LOG','CALLS.LOG')) {
    $path=Join-Path $work $name
    if(Test-Path -LiteralPath $path){Remove-Item -LiteralPath $path -Force}
}
$teacher=[byte[]]@(7,2,3,4,5,6,7,8,9,2,4,7,8,10,12,14,16,18,3,6,9,12,15,18,21,24,27,4,8,12,16,7,24,28,32,36,5,10,15,20,25,30,35,40,45,6,12,18,24,30,7,42,48,54,7,14,21,28,35,42,49,56,63,8,16,24,32,40,48,56,7,72,9,18,27,36,45,54,63,72,81)
$correct=New-Object byte[] 81
for($row=1;$row -le 9;$row++) {
    $sum=0
    for($col=1;$col -le 9;$col++) { $sum+=$row; $correct[($row-1)*9+$col-1]=$sum }
}
function Expected([byte[]]$data) {
    $text="x y`r`n"
    for($i=0;$i -lt 81;$i++) {
        if($data[$i] -ne $correct[$i]) {$text+=('{0} {1}  error' -f ([int][Math]::Floor($i/9)+1),($i%9+1))+"`r`n"}
    }
    return $text+"`r`naccomplish!`r`n"
}
$fixtures=New-Object 'System.Collections.Generic.List[object]'
$fixtures.Add([pscustomobject]@{Name='teacher';Data=$teacher})
$fixtures.Add([pscustomobject]@{Name='all-correct';Data=$correct})
for($i=0;$i -lt 81;$i++) {
    $copy=[byte[]]$correct.Clone();$copy[$i]=255
    $fixtures.Add([pscustomobject]@{Name=('single-error-'+$i);Data=$copy})
}
$fixtures.Add([pscustomobject]@{Name='all-zero';Data=(New-Object byte[] 81)})
$fixtures.Add([pscustomobject]@{Name='all-255';Data=([byte[]](@(255)*81))})
$batch=New-Object 'System.Collections.Generic.List[string]'
foreach($line in @('@echo off','check > DEFAULT.OUT','if errorlevel 1 goto failed','debug CHECK.EXE < CHECKDBG.TXT > TRACE.LOG','if errorlevel 1 goto failed','debug CHECK.EXE < ALLDBG.TXT > CALLS.LOG','if errorlevel 1 goto failed')) {$batch.Add($line)}
for($i=0;$i -lt $fixtures.Count;$i++) {
    $id='T{0:D3}' -f $i
    $fixtures[$i] | Add-Member -NotePropertyName Id -NotePropertyValue $id
    # Modify only the loaded process memory; never overwrite the EXE or source.
    $commands=@('g 9')
    for($row=0;$row -lt 9;$row++) {
        $hex=@($fixtures[$i].Data[($row*9)..($row*9+8)] | ForEach-Object {$_.ToString('X2')}) -join ' '
        $commands+=('e ds:{0:X} {1}' -f ($row*9),$hex)
    }
    $commands+=@('g','q')
    [IO.File]::WriteAllText((Join-Path $work ($id+'.TXT')),($commands -join "`r`n")+"`r`n",$ascii)
    $output=Join-Path $work ($id+'.LOG')
    if(Test-Path -LiteralPath $output){Remove-Item -LiteralPath $output -Force}
    $batch.Add("debug CHECK.EXE < $id.TXT > $id.LOG")
    $batch.Add('if errorlevel 1 goto failed')
}
foreach($line in @('echo OK>DONE.TXT','goto finished',':failed','echo FAIL>FAIL.TXT',':finished','exit')){$batch.Add($line)}
[IO.File]::WriteAllText((Join-Path $work 'RUN.BAT'),($batch -join "`r`n")+"`r`n",$ascii)
$config="[sdl]`r`nfullscreen=false`r`noutput=surface`r`n[mixer]`r`nnosound=true`r`n[autoexec]`r`nmount c .`r`nc:`r`ncall run.bat`r`nexit`r`n"
[IO.File]::WriteAllText((Join-Path $work 'dosbox.conf'),$config,$ascii)
$oldVideo=$env:SDL_VIDEODRIVER;$oldAudio=$env:SDL_AUDIODRIVER
$p=New-Object Diagnostics.Process
$p.StartInfo.FileName=$DosBoxPath;$p.StartInfo.WorkingDirectory=$work
$p.StartInfo.Arguments='-conf dosbox.conf -noconsole'
$p.StartInfo.UseShellExecute=$false;$p.StartInfo.CreateNoWindow=$true
try {
    $env:SDL_VIDEODRIVER='dummy';$env:SDL_AUDIODRIVER='dummy'
    if(-not $p.Start()){throw 'Could not start DOSBox'}
    if(-not $p.WaitForExit(60000)){$p.Kill();throw 'DOSBox timeout'}
    if($p.ExitCode -ne 0){throw 'DOSBox failed'}
} finally {$p.Dispose();$env:SDL_VIDEODRIVER=$oldVideo;$env:SDL_AUDIODRIVER=$oldAudio}
if((Test-Path (Join-Path $work 'FAIL.TXT')) -or -not (Test-Path (Join-Path $work 'DONE.TXT'))){throw 'DOS run failed'}

function Run-C([string]$exe,[byte[]]$data) {
    $p=New-Object Diagnostics.Process
    $p.StartInfo.FileName=$exe;$p.StartInfo.WorkingDirectory=$work
    $p.StartInfo.UseShellExecute=$false;$p.StartInfo.CreateNoWindow=$true
    $p.StartInfo.RedirectStandardOutput=$true;$p.StartInfo.RedirectStandardError=$true
    $p.StartInfo.RedirectStandardInput=$true
    try {
        if(-not $p.Start()){throw 'Could not start C executable'}
        $stdout=$p.StandardOutput.ReadToEndAsync();$stderr=$p.StandardError.ReadToEndAsync()
        if($null -ne $data){$p.StandardInput.BaseStream.Write($data,0,$data.Length)}
        $p.StandardInput.Close()
        if(-not $p.WaitForExit(10000)){$p.Kill();throw 'C timeout'}
        if($p.ExitCode -ne 0 -or $stderr.Result.Length -ne 0){throw 'C execution failed'}
        return $stdout.Result
    } finally {$p.Dispose()}
}
$reports=New-Object 'System.Collections.Generic.List[string]'
$expected=Expected $teacher
$literal="x y`r`n1 1  error`r`n2 3  error`r`n4 5  error`r`n6 6  error`r`n8 8  error`r`n`r`naccomplish!`r`n"
if($expected -cne $literal){throw 'Teacher fixture mismatch'}
if([IO.File]::ReadAllText((Join-Path $work 'DEFAULT.OUT')) -cne $expected){throw 'Default DOS output mismatch'}
foreach($exe in @('GLOBAL','LOCAL')) {
    $actual=Run-C (Join-Path $PSScriptRoot ('c\'+$exe+'.EXE')) $null
    [IO.File]::WriteAllText((Join-Path $work ($exe+'.OUT')),$actual,$ascii)
    if($actual -cne $expected){throw ($exe+' output mismatch')}
}
$reports.Add('PASS default DOS, C global and C local outputs match exactly: (1,1),(2,3),(4,5),(6,6),(8,8).')
foreach($fixture in $fixtures) {
    $log=[IO.File]::ReadAllText((Join-Path $work ($fixture.Id+'.LOG')))
    if(-not $log.Contains('Program terminated normally (0000)')){throw ('DEBUG failed: '+$fixture.Name)}
    $actual=[regex]::Match($log,'(?s)x y\r\n.*?accomplish!\r\n').Value
    $expected=Expected $fixture.Data
    if($actual -cne $expected){throw ('DOS fixture mismatch: '+$fixture.Name)}
    $c=Run-C (Join-Path $PSScriptRoot 'tests\TEST_C.EXE') $fixture.Data
    [IO.File]::WriteAllText((Join-Path $work ($fixture.Id+'.COUT')),$c,$ascii)
    if($c -cne $expected){throw ('C fixture mismatch: '+$fixture.Name)}
    $reports.Add('PASS fixture '+$fixture.Name+': DOS and production C scanner.')
}
$log=[IO.File]::ReadAllText((Join-Path $work 'CALLS.LOG'))
$pattern='AX=(?<AX>[0-9A-F]{4}) BX=(?<BX>[0-9A-F]{4}) CX=(?<CX>[0-9A-F]{4}) DX=(?<DX>[0-9A-F]{4}) SP=(?<SP>[0-9A-F]{4}) BP=(?<BP>[0-9A-F]{4}) SI=(?<SI>[0-9A-F]{4}) DI=(?<DI>[0-9A-F]{4})\s+DS=(?<DS>[0-9A-F]{4}) ES=(?<ES>[0-9A-F]{4}) SS=(?<SS>[0-9A-F]{4}) CS=(?<CS>[0-9A-F]{4}) IP=(?<IP>[0-9A-F]{4})'
$states=[regex]::Matches($log,$pattern)
if($states.Count -ne 163 -or -not $log.Contains('Program terminated normally (0000)')){throw 'Expected 163 DEBUG snapshots'}
for($i=0;$i -lt 81;$i++) {
    $a=$states[2*$i].Groups;$b=$states[2*$i+1].Groups
    if($a['IP'].Value -ne '001C' -or $b['IP'].Value -ne '001F'){throw 'Wrong CALL/RET addresses'}
    foreach($reg in @('AX','BX','CX','DX','SP','BP','SI','DI','DS','ES','SS','CS')){if($a[$reg].Value -cne $b[$reg].Value){throw ('Clobbered '+$reg+' at cell '+$i)}}
    $row=[int][Math]::Floor($i/9)+1;$col=$i%9+1
    if($a['BX'].Value -ne ('{0:X2}{1:X2}' -f $row,$col) -or [Convert]::ToInt32($a['SI'].Value,16) -ne $i -or [Convert]::ToInt32($a['CX'].Value,16) -ne (10-$col) -or $a['SP'].Value -ne '00FE'){throw ('Incorrect addressing/counters at cell '+$i)}
}
$last=$states[162].Groups
if($last['IP'].Value -ne '0029' -or $last['SI'].Value -ne '0051' -or $last['SP'].Value -ne '0100' -or $last['CX'].Value -ne '0000'){throw 'Incorrect final scan state'}
$reports.Add('PASS 81 CALL/RET pairs preserve registers; DS:SI visits offsets 0000..0050 once; final SI=0051, CX=0, SP=0100.')
$trace=[IO.File]::ReadAllText((Join-Path $work 'TRACE.LOG'))
$snapshots=[regex]::Matches($trace,$pattern)
$ips=@('0009','001C','0036','003F','0041','0076','0079','0046','004B','001F','0029','0029')
$sps=@('0100','00FE','00FC','00F2','00F2','00EA','00F0','00F2','00FC','00FE','0100','0100')
if($snapshots.Count -ne $ips.Count){throw 'Unexpected detailed trace length'}
for($i=0;$i -lt $ips.Count;$i++){if($snapshots[$i].Groups['IP'].Value -ne $ips[$i] -or $snapshots[$i].Groups['SP'].Value -ne $sps[$i]){throw 'Incorrect nested CALL/RET stack trace'}}
if($snapshots[3].Groups['AX'].Value -ne '0001' -or $snapshots[5].Groups['CX'].Value -ne '0000' -or $snapshots[6].Groups['CX'].Value -ne '0009'){throw 'Incorrect product or CX restoration'}
$dumps=[regex]::Matches($trace,'(?ms)^-d ds:0 l 51\r\n(.*?)(?=^-g)')
if($dumps.Count -ne 2 -or $dumps[0].Groups[1].Value -cne $dumps[1].Groups[1].Value){throw 'Data table changed during scan'}
if($trace -notmatch '(?m)^[0-9A-F]{4}:00F0[^\r\n]*1F 00'){throw 'Missing return address 001F on stack'}
$reports.Add('PASS detailed nested CALL/RET trace: stacked IP=001F, CX restored, original 81-byte table unchanged.')
$reports.Add('PASS checker: 3 default programs, 85 DOS + 85 C data fixtures, 81 procedure calls.')
[IO.File]::WriteAllText((Join-Path $work 'RESULTS.TXT'),($reports -join "`r`n")+"`r`n",$ascii)
$reports[0]
$reports[$reports.Count-3]
$reports[$reports.Count-2]
$reports[$reports.Count-1]
Write-Output ('Details: '+$work)
