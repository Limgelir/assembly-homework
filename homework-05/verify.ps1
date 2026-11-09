param(
    [string]$DosBoxPath='C:\Program Files (x86)\DOSBox-0.74\DOSBox.exe',
    [string]$DebugPath='D:\ASM\DEBUG.COM'
)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Numerics
$work=Join-Path $PSScriptRoot '.verify'
$ascii=[Text.Encoding]::ASCII
New-Item -ItemType Directory -Path $work -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'asm\FIB.EXE') -Destination $work -Force
Copy-Item -LiteralPath $DebugPath -Destination (Join-Path $work 'DEBUG.COM') -Force
foreach($name in @('DONE.TXT','FAIL.TXT')) {$p=Join-Path $work $name;if(Test-Path -LiteralPath $p){Remove-Item -LiteralPath $p -Force}}
# Independent oracle: iterative arbitrary-precision arithmetic.
$values=New-Object 'System.Collections.Generic.List[System.Numerics.BigInteger]'
$values.Add([System.Numerics.BigInteger]::Zero);$values.Add([System.Numerics.BigInteger]::One)
foreach($n in 2..100){$values.Add($values[$n-1]+$values[$n-2])}
if($values[100].ToString() -cne '354224848179261915075'){throw 'Oracle mismatch'}
$cases=New-Object 'System.Collections.Generic.List[object]'
foreach($n in 1..100){$cases.Add([pscustomobject]@{Input=[string]$n;N=$n;Valid=$true})}
foreach($text in @('001','010','099')){$cases.Add([pscustomobject]@{Input=$text;N=[int]$text;Valid=$true})}
foreach($text in @('','0','000','101','999','1000','-1','+1','1.5','1a',' 1','1 ','0001',('9'*63))){$cases.Add([pscustomobject]@{Input=$text;N=0;Valid=$false})}
$batch=New-Object 'System.Collections.Generic.List[string]'
$batch.Add('@echo off')
for($i=0;$i -lt $cases.Count;$i++) {
    $id='T{0:D3}' -f $i
    $cases[$i] | Add-Member -NotePropertyName Id -NotePropertyValue $id
    [IO.File]::WriteAllText((Join-Path $work ($id+'.IN')),$cases[$i].Input+"`r`n",$ascii)
    $p=Join-Path $work ($id+'.OUT');if(Test-Path -LiteralPath $p){Remove-Item -LiteralPath $p -Force}
    $batch.Add("fib < $id.IN > $id.OUT")
    if($cases[$i].Valid){$batch.Add('if errorlevel 1 goto failed')}
    else {$batch.Add('if errorlevel 2 goto failed');$batch.Add('if not errorlevel 1 goto failed')}
}
$traceNs=@(0,1,2,3,10,100)
foreach($n in $traceNs) {
    $id='D{0:D3}' -f $n
    $commands=@('g 5','r ax',('{0:X4}' -f $n),'g =60 7d df')
    $calls=[Math]::Max(1,2*$n-1)
    # Step off the current breakpoint before installing it again.
    for($i=1;$i -lt 2*$calls;$i++) {$commands+=@('t','g 7d df')}
    $commands+=@('g 63','d ds:457 l 4','d ss:0 l 20','g','q')
    [IO.File]::WriteAllText((Join-Path $work ($id+'.TXT')),($commands -join "`r`n")+"`r`n",$ascii)
    $p=Join-Path $work ($id+'.LOG');if(Test-Path -LiteralPath $p){Remove-Item -LiteralPath $p -Force}
    $batch.Add("debug FIB.EXE < $id.TXT > $id.LOG")
    $batch.Add('if errorlevel 1 goto failed')
}
foreach($line in @('echo OK>DONE.TXT','goto finished',':failed','echo FAIL>FAIL.TXT',':finished','exit')){$batch.Add($line)}
[IO.File]::WriteAllText((Join-Path $work 'RUN.BAT'),($batch -join "`r`n")+"`r`n",$ascii)
$config="[sdl]`r`nfullscreen=false`r`noutput=surface`r`n[mixer]`r`nnosound=true`r`n[autoexec]`r`nmount c .`r`nc:`r`ncall run.bat`r`nexit`r`n"
[IO.File]::WriteAllText((Join-Path $work 'dosbox.conf'),$config,$ascii)
$savedVideo=$env:SDL_VIDEODRIVER;$savedAudio=$env:SDL_AUDIODRIVER
$p=New-Object Diagnostics.Process
$p.StartInfo.FileName=$DosBoxPath;$p.StartInfo.WorkingDirectory=$work
$p.StartInfo.Arguments='-conf dosbox.conf -noconsole'
$p.StartInfo.UseShellExecute=$false;$p.StartInfo.CreateNoWindow=$true
try {
    $env:SDL_VIDEODRIVER='dummy';$env:SDL_AUDIODRIVER='dummy'
    if(-not $p.Start()){throw 'DOSBox failed to start'}
    if(-not $p.WaitForExit(60000)){$p.Kill();throw 'DOSBox timed out'}
    if($p.ExitCode -ne 0){throw 'DOSBox failed'}
} finally {$p.Dispose();$env:SDL_VIDEODRIVER=$savedVideo;$env:SDL_AUDIODRIVER=$savedAudio}
if((Test-Path (Join-Path $work 'FAIL.TXT')) -or -not (Test-Path (Join-Path $work 'DONE.TXT'))){throw 'DOS return-code check failed'}
$reports=New-Object 'System.Collections.Generic.List[string]'
foreach($case in $cases) {
    $prompt="Please input n (1-100):`r`n"
    $tail=if($case.Valid){"F(n):`r`n"+$values[$case.N].ToString()+"`r`n"}else{"Error: enter 1-3 decimal digits in 1..100.`r`n"}
    $expected=$prompt+$case.Input+"`r`r`n"+$tail
    $actual=[IO.File]::ReadAllText((Join-Path $work ($case.Id+'.OUT')))
    if($actual -cne $expected){throw ('DOS output mismatch: '+$case.Input)}
    $p=New-Object Diagnostics.Process
    $p.StartInfo.FileName=Join-Path $PSScriptRoot 'c\FIB_C.EXE'
    $p.StartInfo.WorkingDirectory=$work;$p.StartInfo.UseShellExecute=$false;$p.StartInfo.CreateNoWindow=$true
    $p.StartInfo.RedirectStandardOutput=$true;$p.StartInfo.RedirectStandardError=$true;$p.StartInfo.RedirectStandardInput=$true
    try {
        if(-not $p.Start()){throw 'C program failed to start'}
        $stdout=$p.StandardOutput.ReadToEndAsync();$stderr=$p.StandardError.ReadToEndAsync()
        $p.StandardInput.WriteLine($case.Input);$p.StandardInput.Close()
        if(-not $p.WaitForExit(10000)){$p.Kill();throw 'C program timed out'}
        $exitCode=if($case.Valid){0}else{1}
        if($p.ExitCode -ne $exitCode -or $stderr.Result.Length -ne 0){throw 'C return-code/stderr mismatch'}
        $actual=$stdout.Result
    } finally {$p.Dispose()}
    [IO.File]::WriteAllText((Join-Path $work ($case.Id+'.COUT')),$actual,$ascii)
    if($actual -cne ($prompt+$tail)){throw ('C output mismatch: '+$case.Input)}
    $reports.Add(('PASS DOS and C input="{0}" valid={1}' -f $case.Input,$case.Valid))
}
$pattern='AX=(?<AX>[0-9A-F]{4}) BX=(?<BX>[0-9A-F]{4}) CX=(?<CX>[0-9A-F]{4}) DX=(?<DX>[0-9A-F]{4}) SP=(?<SP>[0-9A-F]{4}) BP=(?<BP>[0-9A-F]{4}) SI=(?<SI>[0-9A-F]{4}) DI=(?<DI>[0-9A-F]{4})\s+DS=(?<DS>[0-9A-F]{4}) ES=(?<ES>[0-9A-F]{4}) SS=(?<SS>[0-9A-F]{4}) CS=(?<CS>[0-9A-F]{4}) IP=(?<IP>[0-9A-F]{4})'
foreach($n in $traceNs) {
    $log=[IO.File]::ReadAllText((Join-Path $work ('D{0:D3}.LOG' -f $n)))
    $matches=@([regex]::Matches($log,$pattern) | Where-Object {$_.Groups['IP'].Value -in @('0005','007D','00DF','0063')})
    $calls=[Math]::Max(1,2*$n-1)
    if($matches.Count -ne (2*$calls+2)){throw ('Unexpected trace length n='+$n)}
    $stack=New-Object 'System.Collections.Generic.Stack[object]'
    $minimum=4096;$maximumDepth=0;$entries=0
    $initial=$matches[0].Groups
    if($initial['SP'].Value -ne '1000' -or $initial['IP'].Value -ne '0005'){throw 'Stack initialization mismatch'}
    foreach($match in @($matches | Select-Object -Skip 1 | Select-Object -First (2*$calls))) {
        $state=$match.Groups;$ip=$state['IP'].Value
        $sp=[Convert]::ToInt32($state['SP'].Value,16)
        if($ip -eq '007D') {
            $parentBP=if($stack.Count -eq 0){$initial['BP'].Value}else{$stack.Peek().State['BP'].Value}
            $stack.Push([pscustomobject]@{State=$state;SP=$sp;ParentBP=$parentBP})
            $minimum=[Math]::Min($minimum,$sp);$maximumDepth=[Math]::Max($maximumDepth,$stack.Count);$entries++
            if([Convert]::ToInt32($state['BP'].Value,16) -ne ($sp+10)){throw 'Frame BP layout mismatch'}
        } elseif($ip -eq '00DF') {
            if($stack.Count -eq 0){throw 'Unmatched RET'}
            $entry=$stack.Pop()
            foreach($reg in @('AX','BX','CX','DX','DI','DS','ES','SS','CS')){if($state[$reg].Value -cne $entry.State[$reg].Value){throw ('Recursive register clobbered: '+$reg)}}
            if($sp -ne ($entry.SP+12) -or $state['BP'].Value -ne $entry.ParentBP){throw 'Unbalanced recursive frame'}
            if([Convert]::ToInt32($state['SI'].Value,16) -ne (10*[Convert]::ToInt32($state['AX'].Value,16))){throw 'Wrong returned memo pointer'}
        } else {throw ('Unexpected trace IP: '+$ip)}
    }
    $last=$matches[$matches.Count-1].Groups
    if($entries -ne $calls -or $stack.Count -ne 0 -or $last['IP'].Value -ne '0063' -or $last['SP'].Value -ne '1000'){throw 'Unbalanced final stack'}
    if($maximumDepth -ne [Math]::Max(1,$n)){throw 'Recursion depth mismatch'}
    $counterBytes='{0:X2} {1:X2} {2:X2} {3:X2}' -f ($calls-band 255),($calls-shr 8),($minimum-band 255),($minimum-shr 8)
    $counterPattern=($counterBytes -split ' ' | ForEach-Object {[regex]::Escape($_)}) -join '[- ]+'
    if($log -notmatch $counterPattern){throw 'Recorded call count/low water mismatch'}
    $guard=[regex]::Match($log,'(?ms)^-d ss:0 l 20\r\n(.*?)(?=^-g)').Groups[1].Value
    $guardBytes=@()
    foreach($line in ($guard -split '\r?\n')){if($line -match '^[0-9A-F]{4}:[0-9A-F]{4}  (.{47})'){$guardBytes+=@([regex]::Matches($Matches[1],'[0-9A-F]{2}') | ForEach-Object {$_.Value})}}
    if(($guardBytes -join ' ') -cne ((@('5A','A5')*16) -join ' ')){throw 'Stack guard changed'}
    if(-not $log.Contains("F(n):`r`n"+$values[$n].ToString()+"`r`n") -or -not $log.Contains('Program terminated normally (0000)')){throw 'DEBUG result mismatch'}
    $reports.Add(('PASS trace n={0}: {1} calls; depth={2}; minimum SP={3:X4}; peak recursive stack={4} bytes; all frames/registers restored; guard intact.' -f $n,$calls,$maximumDepth,$minimum,(4096-$minimum)))
}
$reports.Add('PASS homework05: 117 DOS + 117 C input cases; 6 recursive traces including F(0) and F(100); exact 80-bit results; balanced stack.')
[IO.File]::WriteAllText((Join-Path $work 'RESULTS.TXT'),($reports -join "`r`n")+"`r`n",$ascii)
$reports | Select-Object -Last 7
Write-Output ('Captured output: '+$work)
