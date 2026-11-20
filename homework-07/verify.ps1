param(
    [string]$DosBoxPath='C:\Program Files (x86)\DOSBox-0.74\DOSBox.exe',
    [string]$DebugPath='D:\ASM\DEBUG.COM'
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
# Read link-time PUBLIC addresses, not unlinked module offsets from LST.
$symbols=@{}
foreach($match in [regex]::Matches([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'asm\CALENDAR.MAP')),'(?m)^\s*([0-9A-F]{4}):([0-9A-F]{4})\s+(\w+)\s*$')) {
    $symbols[$match.Groups[3].Value]=@($match.Groups[1].Value,$match.Groups[2].Value)
}
function Offset([string]$name){if(-not $symbols.ContainsKey($name)){throw ('Missing symbol: '+$name)};return $symbols[$name][1]}
foreach($name in @('FIRST_WEEKDAY','READ_NUMBER','DAYS_IN_MONTH')){if($symbols[$name][0] -ne $symbols['START'][0]){throw 'CORE modules not combined'}}
if($symbols['RENDER_CALENDAR'][0] -eq $symbols['START'][0]){throw 'SCREEN must be a distinct segment'}
$traceDates=@(@(1900,2),@(2000,2),@(2026,11),@(2099,12))
foreach($date in $traceDates) {
    $year=$date[0];$month=$date[1];$id='D{0}{1:D2}' -f $year,$month
    $bytes='{0:X2} {1:X2} {2:X2} 00' -f ($year -band 255),($year -shr 8),$month
    $commands=@('g 5',('e ds:0 '+$bytes),'u 0 51',('g ='+(Offset 'CALCULATE')+' '+(Offset 'BEFORE_WEEKDAY')),'d ss:3fc l 4','t',('g '+(Offset 'WEEKDAY_FRAME')),'d ss:3f8 l 8',('g '+(Offset 'WEEKDAY_RETURN')),'t',('g '+(Offset 'BEFORE_RENDER')),'d ds:0 l 8','t','u 0 11','d ss:3fc l 4',('g '+(Offset 'BEFORE_DIGITS')),'t','d ss:3ee l 2',('g '+(Offset 'UNSIGNED_RETURN')),'t',('g '+(Offset 'RENDER_RETURN')),'t','g','q')
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
    $expected=$yearPrompt+$case.Year+"`r`r`n"
    if($case.ErrorAt -ne 'year') {
        $expected+=$monthPrompt
        if($case.CRLF){$expected+="`n"}
        $expected+=$case.Month+"`r`r`n"
    }
    $expected+=$tail
    $actual=[IO.File]::ReadAllText((Join-Path $work ($case.Id+'.OUT')))
    if($actual -cne $expected){throw ('DOS output mismatch: '+$case.Id+' year='+$case.Year+' month='+$case.Month)}
    $reports.Add(('PASS {0}: year="{1}" month="{2}" error="{3}" DOS-CRLF={4}' -f $case.Id,$case.Year,$case.Month,$case.ErrorAt,$case.CRLF))
}
$pattern='AX=(?<AX>[0-9A-F]{4}) BX=(?<BX>[0-9A-F]{4}) CX=(?<CX>[0-9A-F]{4}) DX=(?<DX>[0-9A-F]{4}) SP=(?<SP>[0-9A-F]{4}) BP=(?<BP>[0-9A-F]{4}) SI=(?<SI>[0-9A-F]{4}) DI=(?<DI>[0-9A-F]{4})\s+DS=(?<DS>[0-9A-F]{4}) ES=(?<ES>[0-9A-F]{4}) SS=(?<SS>[0-9A-F]{4}) CS=(?<CS>[0-9A-F]{4}) IP=(?<IP>[0-9A-F]{4})'
function Equal-Registers($left,$right,$registers){foreach($reg in $registers){if($left[$reg].Value -ne $right[$reg].Value){throw ('Register mismatch: '+$reg)}}}
function Word-Bytes([int]$value){return ('{0:X2} {1:X2}' -f ($value -band 255),($value -shr 8))}
foreach($date in $traceDates) {
    $year=$date[0];$month=$date[1];$id='D{0}{1:D2}' -f $year,$month
    $log=[IO.File]::ReadAllText((Join-Path $work ($id+'.LOG')))
    $states=@([regex]::Matches($log,$pattern) | ForEach-Object {,$_.Groups})
    $ips=@('0005',(Offset 'BEFORE_WEEKDAY'),(Offset 'FIRST_WEEKDAY'),(Offset 'WEEKDAY_FRAME'),(Offset 'WEEKDAY_RETURN'),(Offset 'AFTER_WEEKDAY'),(Offset 'BEFORE_RENDER'),(Offset 'RENDER_ENTER'),(Offset 'BEFORE_DIGITS'),(Offset 'PRINT_UNSIGNED'),(Offset 'UNSIGNED_RETURN'),(Offset 'AFTER_DIGITS'),(Offset 'RENDER_RETURN'),(Offset 'AFTER_RENDER'))
    $sps=@('0400','03FC','03FA','03EE','03FA','0400','0400','03FC','03F0','03EE','03EE','03F0','03FC','0400')
    if($states.Count -ne $ips.Count){throw ('Wrong trace length: '+$id)}
    for($i=0;$i -lt $states.Count;$i++) {
        if($states[$i]['IP'].Value -ne $ips[$i] -or $states[$i]['SP'].Value -ne $sps[$i]){throw ('IP/SP mismatch: '+$id+' state '+$i)}
        Equal-Registers $states[0] $states[$i] @('DS','SS')
        $expectedCS=if($i -ge 7 -and $i -le 12){$states[7]['CS'].Value}else{$states[0]['CS'].Value}
        if($states[$i]['CS'].Value -ne $expectedCS){throw 'CS mismatch'}
    }
    if($states[7]['CS'].Value -eq $states[0]['CS'].Value){throw 'FAR call did not change CS'}
    if($states[3]['BP'].Value -ne '03F8'){throw 'Stack argument frame mismatch'}
    Equal-Registers $states[1] $states[5] @('BX','CX','DX','BP','SI','DI')
    Equal-Registers $states[6] $states[13] @('AX','BX','CX','DX','BP','SI','DI','DS','ES','SS','CS')
    Equal-Registers $states[8] $states[11] @('AX','BX','CX','DX','BP','SI','DI','DS','ES','SS','CS')
    $first=[int](New-Object DateTime($year,$month,1)).DayOfWeek
    if([Convert]::ToInt32($states[5]['AX'].Value,16) -ne $first){throw 'Stack-argument calculation mismatch'}
    $expectedBytes=(Word-Bytes $year)+' '+(Word-Bytes $month)+' '+(Word-Bytes $first)+' '+(Word-Bytes ([DateTime]::DaysInMonth($year,$month)))
    if(-not $log.Contains($expectedBytes)){throw 'Data-segment arguments mismatch'}
    $coreCS=[Convert]::ToInt32($states[0]['CS'].Value,16)
    $nearReturn=Word-Bytes ([Convert]::ToInt32((Offset 'AFTER_WEEKDAY'),16))
    $farReturn=(Word-Bytes ([Convert]::ToInt32((Offset 'AFTER_RENDER'),16)))+' '+(Word-Bytes $coreCS)
    if(-not $log.Contains($nearReturn+' '+(Word-Bytes $year)+' '+(Word-Bytes $month))){throw 'Cross-file NEAR return/arguments not on stack'}
    if(-not $log.Contains($farReturn)){throw 'FAR return IP/CS not on stack'}
    $nearDump=[regex]::Match($log,'(?ms)^-d ss:3ee l 2\r\n(.*?)(?=^-g)').Groups[1].Value
    if(-not $nearDump.Contains((Word-Bytes ([Convert]::ToInt32((Offset 'AFTER_DIGITS'),16))))){throw 'Same-file NEAR return not on stack'}
    # Compare actual loaded machine bytes, including linker-fixed displacement and segment relocation.
    $rel=([Convert]::ToInt32((Offset 'FIRST_WEEKDAY'),16)-[Convert]::ToInt32((Offset 'AFTER_WEEKDAY'),16)) -band 65535
    $nearCode='E8'+(Word-Bytes $rel).Replace(' ','')
    $farCode='9A'+(Word-Bytes ([Convert]::ToInt32((Offset 'RENDER_ENTER'),16))).Replace(' ','')+(Word-Bytes ([Convert]::ToInt32($states[7]['CS'].Value,16))).Replace(' ','')
    $sameRel=([Convert]::ToInt32((Offset 'PRINT_UNSIGNED'),16)-[Convert]::ToInt32((Offset 'AFTER_DIGITS'),16)) -band 65535
    $sameCode='E8'+(Word-Bytes $sameRel).Replace(' ','')
    foreach($code in @($nearCode,$farCode,$sameCode,'C20400','CB')){if(-not $log.Contains($code)){throw ('Missing instruction bytes: '+$code)}}
    $retPattern='[0-9A-F]{4}:'+(Offset 'UNSIGNED_RETURN')+' C3\s+RET'
    if($log -notmatch $retPattern -or -not $log.Contains('Program terminated normally (0000)')){throw 'NEAR RET or exit mismatch'}
    $reports.Add(('PASS trace {0}-{1:D2}: same-file NEAR, cross-file NEAR, cross-file FAR; machine bytes, return addresses, CS/IP/SP, arguments and saved registers verified.' -f $year,$month))
}
$reports.Add(('PASS homework07: {0} DOS input cases; all 2400 months checked against .NET; 4 call/return traces; 3 call categories verified.' -f $cases.Count))
[IO.File]::WriteAllText((Join-Path $work 'RESULTS.TXT'),($reports -join "`r`n")+"`r`n",$ascii)
$reports | Select-Object -Last 5
Write-Output ('Captured output: '+$work)
