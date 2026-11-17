param(
    [string]$DosBoxPath='C:\Program Files (x86)\DOSBox-0.74\DOSBox.exe',
    [string]$DebugPath='D:\ASM\DEBUG.COM',
    [switch]$SkipC
)
$ErrorActionPreference='Stop'
$work=Join-Path $PSScriptRoot '.verify'
$ascii=[Text.Encoding]::ASCII
New-Item -ItemType Directory -Path $work -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'asm\CALENDAR.EXE') -Destination $work -Force
Copy-Item -LiteralPath $DebugPath -Destination (Join-Path $work 'DEBUG.COM') -Force
foreach($name in @('DONE.TXT','FAIL.TXT')) {
    $path=Join-Path $work $name
    if(Test-Path -LiteralPath $path){Remove-Item -LiteralPath $path -Force}
}
$yearPrompt='Please input year (1900-2099): '
$monthPrompt='Please input month (1-12): '
$yearError="Error: year must be 1900..2099 (4 digits).`r`n"
$monthError="Error: month must be 1..12 (1-2 digits).`r`n"
# Independent oracle: use .NET's calendar, not the assembly/C formula.
function Get-Calendar([int]$year,[int]$month) {
    $date=New-Object DateTime($year,$month,1)
    $first=[int]$date.DayOfWeek
    $count=[DateTime]::DaysInMonth($year,$month)
    $name=$date.ToString('MMMM',[Globalization.CultureInfo]::InvariantCulture)
    $text="`r`n$year  $name`r`nSu Mo Tu We Th Fr Sa`r`n"+('   '*$first)
    $column=$first
    foreach($day in 1..$count) {
        $text+=([string]$day).PadLeft(2)
        $column++
        if($day -eq $count){$text+="`r`n"}
        elseif($column -eq 7){$text+="`r`n";$column=0}
        else{$text+=' '}
    }
    return $text
}
$cases=New-Object 'System.Collections.Generic.List[object]'
function Add-Case([string]$year,[string]$month,[string]$errorAt='',[bool]$crlf=$false) {
    $cases.Add([pscustomobject]@{Year=$year;Month=$month;ErrorAt=$errorAt;CRLF=$crlf;Id=('T{0:D4}' -f $cases.Count)})
}
foreach($year in 1900..2099){foreach($month in 1..12){Add-Case ([string]$year) ([string]$month)}}
Add-Case '2026' '01'
Add-Case '2000' '02'
foreach($year in @('','1899','2100','9999','190','01900','-1900','+2000','20a0',' 2000','2000 ','20.0',('9'*63))){Add-Case $year '1' 'year'}
foreach($month in @('','0','00','13','99','001','-1','+1','1a',' 1','1 ','1.5',('9'*63))){Add-Case '2026' $month 'month'}
# CR-only simulates keyboard Enter; also exercise ordinary CRLF input files.
Add-Case '2026' '11' '' $true
Add-Case '1900' '2' '' $true
Add-Case '2000' '02' '' $true
Add-Case '2026' '' 'month' $true
Add-Case '2026' '13' 'month' $true
$batch=New-Object 'System.Collections.Generic.List[string]'
$batch.Add('@echo off')
foreach($case in $cases) {
    $id=$case.Id
    $eol=if($case.CRLF){"`r`n"}else{"`r"}
    [IO.File]::WriteAllText((Join-Path $work ($id+'.IN')),$case.Year+$eol+$case.Month+$eol,$ascii)
    $batch.Add("calendar < $id.IN > $id.OUT")
    if($case.ErrorAt -eq ''){$batch.Add('if errorlevel 1 goto failed')}
    else{$batch.Add('if errorlevel 2 goto failed');$batch.Add('if not errorlevel 1 goto failed')}
}
$traceDates=@(@(1900,2),@(2000,2),@(2026,11),@(2099,12))
foreach($date in $traceDates) {
    $year=$date[0];$month=$date[1];$id='D{0}{1:D2}' -f $year,$month
    $bytes='{0:X2} {1:X2} {2:X2} 00' -f ($year -band 255),($year -shr 8),$month
    $commands=@('g 5',('e ds:0 '+$bytes),'u 0 51','g =51 66','d ss:3fc l 4','t','g 127','d ss:3f8 l 8','g 174','t','g 6c','d ds:0 l 8','t','u 0 10','d ss:3fc l 4','g 80','t','g','q')
    [IO.File]::WriteAllText((Join-Path $work ($id+'.TXT')),($commands -join "`r`n")+"`r`n",$ascii)
    $batch.Add("debug CALENDAR.EXE < $id.TXT > $id.LOG")
    $batch.Add('if errorlevel 1 goto failed')
}
foreach($line in @('echo OK>DONE.TXT','goto finished',':failed','echo FAIL>FAIL.TXT',':finished','exit')){$batch.Add($line)}
[IO.File]::WriteAllText((Join-Path $work 'RUN.BAT'),($batch -join "`r`n")+"`r`n",$ascii)
$config="[sdl]`r`nfullscreen=false`r`noutput=surface`r`n[mixer]`r`nnosound=true`r`n[cpu]`r`ncycles=max`r`n[autoexec]`r`nmount c .`r`nc:`r`ncall run.bat`r`nexit`r`n"
[IO.File]::WriteAllText((Join-Path $work 'dosbox.conf'),$config,$ascii)
$savedVideo=$env:SDL_VIDEODRIVER;$savedAudio=$env:SDL_AUDIODRIVER
$p=New-Object Diagnostics.Process
$p.StartInfo.FileName=$DosBoxPath;$p.StartInfo.WorkingDirectory=$work
$p.StartInfo.Arguments='-conf dosbox.conf -noconsole'
$p.StartInfo.UseShellExecute=$false;$p.StartInfo.CreateNoWindow=$true
Write-Output ('Running DOSBox: '+$cases.Count+' input cases and 4 DEBUG traces...')
try {
    $env:SDL_VIDEODRIVER='dummy';$env:SDL_AUDIODRIVER='dummy'
    if(-not $p.Start()){throw 'DOSBox failed to start'}
    if(-not $p.WaitForExit(60000)){$p.Kill();throw 'DOSBox timed out'}
    if($p.ExitCode -ne 0){throw 'DOSBox failed'}
} finally {$p.Dispose();$env:SDL_VIDEODRIVER=$savedVideo;$env:SDL_AUDIODRIVER=$savedAudio}
if((Test-Path (Join-Path $work 'FAIL.TXT')) -or -not (Test-Path (Join-Path $work 'DONE.TXT'))){throw 'DOS return-code check failed'}
$reports=New-Object 'System.Collections.Generic.List[string]'
foreach($case in $cases) {
    $tail=if($case.ErrorAt -eq 'year'){$yearError}elseif($case.ErrorAt -eq 'month'){$monthError}else{Get-Calendar ([int]$case.Year) ([int]$case.Month)}
    $dosExpected=$yearPrompt+$case.Year+"`r`r`n"
    $cExpected=$yearPrompt
    if($case.ErrorAt -ne 'year') {
        $dosExpected+=$monthPrompt
        if($case.CRLF){$dosExpected+="`n"}
        $dosExpected+=$case.Month+"`r`r`n"
        $cExpected+=$monthPrompt
    }
    $dosExpected+=$tail;$cExpected+=$tail
    $actual=[IO.File]::ReadAllText((Join-Path $work ($case.Id+'.OUT')))
    if($actual -cne $dosExpected){throw ('DOS output mismatch: '+$case.Id+' year='+$case.Year+' month='+$case.Month)}
    if(-not $SkipC) {
        $p=New-Object Diagnostics.Process
        $p.StartInfo.FileName=Join-Path $PSScriptRoot 'c\CAL_C.EXE'
        $p.StartInfo.WorkingDirectory=$work;$p.StartInfo.UseShellExecute=$false;$p.StartInfo.CreateNoWindow=$true
        $p.StartInfo.RedirectStandardOutput=$true;$p.StartInfo.RedirectStandardError=$true;$p.StartInfo.RedirectStandardInput=$true
        try {
            if(-not $p.Start()){throw 'C program failed to start'}
            $stdout=$p.StandardOutput.ReadToEndAsync();$stderr=$p.StandardError.ReadToEndAsync()
            $p.StandardInput.Write($case.Year+"`r`n"+$case.Month+"`r`n");$p.StandardInput.Close()
            if(-not $p.WaitForExit(10000)){$p.Kill();throw 'C program timed out'}
            $exitCode=if($case.ErrorAt -eq ''){0}else{1}
            if($p.ExitCode -ne $exitCode -or $stderr.Result.Length -ne 0){throw ('C return-code/stderr mismatch: '+$case.Id)}
            $actual=$stdout.Result
        } finally {$p.Dispose()}
        [IO.File]::WriteAllText((Join-Path $work ($case.Id+'.COUT')),$actual,$ascii)
        if($actual -cne $cExpected){throw ('C output mismatch: '+$case.Id)}
    }
    $reports.Add(('PASS {0}: year="{1}" month="{2}" error="{3}" DOS-CRLF={4}' -f $case.Id,$case.Year,$case.Month,$case.ErrorAt,$case.CRLF))
}
$pattern='AX=(?<AX>[0-9A-F]{4}) BX=(?<BX>[0-9A-F]{4}) CX=(?<CX>[0-9A-F]{4}) DX=(?<DX>[0-9A-F]{4}) SP=(?<SP>[0-9A-F]{4}) BP=(?<BP>[0-9A-F]{4}) SI=(?<SI>[0-9A-F]{4}) DI=(?<DI>[0-9A-F]{4})\s+DS=(?<DS>[0-9A-F]{4}) ES=(?<ES>[0-9A-F]{4}) SS=(?<SS>[0-9A-F]{4}) CS=(?<CS>[0-9A-F]{4}) IP=(?<IP>[0-9A-F]{4})'
foreach($date in $traceDates) {
    $year=$date[0];$month=$date[1];$id='D{0}{1:D2}' -f $year,$month
    $log=[IO.File]::ReadAllText((Join-Path $work ($id+'.LOG')))
    $states=@([regex]::Matches($log,$pattern) | ForEach-Object {,$_.Groups})
    $ips=@('0005','0066','011F','0127','0174','0069','006C','0000','0080','0071')
    $sps=@('0400','03FC','03FA','03EE','03FA','0400','0400','03FC','03FC','0400')
    if($states.Count -ne $ips.Count){throw ('Wrong trace length: '+$id)}
    for($i=0;$i -lt $states.Count;$i++) {
        if($states[$i]['IP'].Value -ne $ips[$i] -or $states[$i]['SP'].Value -ne $sps[$i]){throw ('IP/SP mismatch: '+$id+' state '+$i)}
        if($states[$i]['DS'].Value -ne $states[0]['DS'].Value -or $states[$i]['SS'].Value -ne $states[0]['SS'].Value){throw 'Segment register clobbered'}
        if($i -notin @(7,8) -and $states[$i]['CS'].Value -ne $states[0]['CS'].Value){throw 'CORE CS mismatch'}
    }
    if($states[7]['CS'].Value -eq $states[0]['CS'].Value -or $states[8]['CS'].Value -ne $states[7]['CS'].Value){throw 'FAR call did not enter distinct SCREEN segment'}
    if($states[3]['BP'].Value -ne '03F8'){throw 'Stack argument frame mismatch'}
    foreach($reg in @('BX','CX','DX','BP','SI','DI')) {
        if($states[1][$reg].Value -ne $states[5][$reg].Value){throw ('NEAR callee clobbered '+$reg)}
    }
    foreach($reg in @('AX','BX','CX','DX','BP','SI','DI','DS','ES','SS','CS')) {
        if($states[6][$reg].Value -ne $states[9][$reg].Value){throw ('FAR callee clobbered '+$reg)}
    }
    $first=[int](New-Object DateTime($year,$month,1)).DayOfWeek
    if([Convert]::ToInt32($states[5]['AX'].Value,16) -ne $first){throw 'Stack-argument calculation mismatch'}
    $expectedBytes='{0:X2} {1:X2} {2:X2} 00 {3:X2} 00 {4:X2} 00' -f ($year -band 255),($year -shr 8),$month,$first,([DateTime]::DaysInMonth($year,$month))
    if(-not $log.Contains($expectedBytes)){throw 'Data-segment argument mismatch'}
    $coreCS=[Convert]::ToInt32($states[0]['CS'].Value,16)
    $farReturn='71 00 {0:X2} {1:X2}' -f ($coreCS -band 255),($coreCS -shr 8)
    if(-not $log.Contains($farReturn)){throw 'FAR return address not on stack'}
    if(-not $log.Contains((Get-Calendar $year $month)) -or -not $log.Contains('Program terminated normally (0000)')){throw 'DEBUG calendar/exit mismatch'}
    $reports.Add(('PASS trace {0}-{1:D2}: stack arguments, RET 4, distinct CS, FAR return IP/CS, all saved registers and SP restored.' -f $year,$month))
}
$cCount=if($SkipC){0}else{$cases.Count}
$reports.Add(('PASS homework06: {0} DOS + {1} C input cases; all 2400 months checked against .NET; 4 DEBUG traces.' -f $cases.Count,$cCount))
$resultFile=if($SkipC){'RESULTS-DOS.TXT'}else{'RESULTS.TXT'}
[IO.File]::WriteAllText((Join-Path $work $resultFile),($reports -join "`r`n")+"`r`n",$ascii)
$reports | Select-Object -Last 5
Write-Output ('Captured output: '+$work)
