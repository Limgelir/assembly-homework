param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('conversion','homework03')][string]$Suite,
    [string]$DosBoxPath = 'C:\Program Files (x86)\DOSBox-0.74\DOSBox.exe'
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$folder = if ($Suite -eq 'conversion') { 'class-exercise' } else { 'homework-03' }
$taskRoot = Join-Path $repo $folder
$work = Join-Path $taskRoot '.verify'
$ascii = [Text.Encoding]::ASCII
$cases = New-Object 'System.Collections.Generic.List[object]'
$reports = New-Object 'System.Collections.Generic.List[string]'

function Add-Case($program, $inputText, $result, [bool]$valid = $true) {
    $cases.Add([pscustomobject]@{ Program=$program; Input=$inputText; Result=$result; Valid=$valid })
}

if ($Suite -eq 'conversion') {
    # Exhaust every byte, then check one digit, uppercase, and mixed case.
    foreach ($n in 0..255) { Add-Case 'HEX2DEC' ($n.ToString('x2')) ([string]$n) }
    foreach ($n in 0..15) { Add-Case 'HEX2DEC' ($n.ToString('X')) ([string]$n) }
    foreach ($value in @('FF','fF','aB','Ab','7F','80')) {
        Add-Case 'HEX2DEC' $value ([string][Convert]::ToInt32($value,16))
    }
    foreach ($value in @('','G','1G','-1','+F','0xFF','FFF',' f','f ','1.','@','[','`','{',('f'*63))) {
        Add-Case 'HEX2DEC' $value '' $false
    }
    foreach ($n in @(0,1,9,10,15,16,17,99,100,127,128,254,255,256,257,999,1000,4095,4096,32767,32768,65534,65535)) {
        Add-Case 'DEC2HEX' ([string]$n) ($n.ToString('X'))
    }
    Add-Case 'DEC2HEX' '00000' '0'
    Add-Case 'DEC2HEX' '00255' 'FF'
    foreach ($value in @('','65536','65540','70000','99999','100000','-1','+1','1.5','1a','0x10',' 1','1 ','000000',('9'*63))) {
        Add-Case 'DEC2HEX' $value '' $false
    }
} else {
    foreach ($program in @('SUM','SUMDATA','SUMSTACK')) { Add-Case $program $null '5050' }
    # The test oracle uses the arithmetic formula, independent of the loops.
    foreach ($n in 1..100) { Add-Case 'SUMINPUT' ([string]$n) ([string]($n*($n+1)/2)) }
    foreach ($value in @('001','010','099')) {
        $n=[int]$value
        Add-Case 'SUMINPUT' $value ([string]($n*($n+1)/2))
    }
    foreach ($value in @('','0','000','101','999','1000','-1','+1','1.5','1a',' 1','1 ','0001',('9'*63))) {
        Add-Case 'SUMINPUT' $value '' $false
    }
}

if (-not (Test-Path -LiteralPath $DosBoxPath -PathType Leaf)) { throw 'DOSBox was not found. Use -DosBoxPath.' }
New-Item -ItemType Directory -Path $work -Force | Out-Null
foreach ($program in ($cases.Program | Select-Object -Unique)) {
    Copy-Item -LiteralPath (Join-Path $taskRoot "asm\$program.EXE") -Destination $work -Force
}
foreach ($marker in @('DONE.TXT','FAIL.TXT')) {
    $path=Join-Path $work $marker
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
}
$batch = New-Object 'System.Collections.Generic.List[string]'
$batch.Add('@echo off')
$index=0
foreach ($case in $cases) {
    $index++
    $id='T{0:D4}' -f $index
    $case | Add-Member -NotePropertyName Id -NotePropertyValue $id
    $outputPath=Join-Path $work "$id.OUT"
    if (Test-Path -LiteralPath $outputPath) { Remove-Item -LiteralPath $outputPath -Force }
    $batch.Add("echo $id>CURRENT.TXT")
    if ($null -eq $case.Input) {
        $batch.Add($case.Program + " > $id.OUT")
    } else {
        [IO.File]::WriteAllText((Join-Path $work "$id.IN"),$case.Input+"`r`n",$ascii)
        $batch.Add($case.Program + " < $id.IN > $id.OUT")
    }
    if ($case.Valid) {
        $batch.Add('if errorlevel 1 goto failed')
    } else {
        $batch.Add('if errorlevel 2 goto failed')
        $batch.Add('if not errorlevel 1 goto failed')
    }
}
$batch.Add('echo OK>DONE.TXT')
$batch.Add('goto finished')
$batch.Add(':failed')
$batch.Add('echo FAIL>FAIL.TXT')
$batch.Add(':finished')
$batch.Add('exit')
[IO.File]::WriteAllText((Join-Path $work 'RUN.BAT'),($batch -join "`r`n")+"`r`n",$ascii)
$config="[sdl]`r`nfullscreen=false`r`noutput=surface`r`n[mixer]`r`nnosound=true`r`n[autoexec]`r`nmount c .`r`nc:`r`ncall run.bat`r`nexit`r`n"
[IO.File]::WriteAllText((Join-Path $work 'dosbox.conf'),$config,$ascii)
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
    -not (Test-Path -LiteralPath (Join-Path $work 'DONE.TXT'))) {
    throw ('DOS return-code check failed. Inspect CURRENT.TXT and outputs in ' + $work)
}

foreach ($case in $cases) {
    $prompt=''
    $answer=''
    $errorText=''
    switch ($case.Program) {
        'HEX2DEC' {
            $prompt='Please input a Hex number (1-2 digits):'
            $answer='The Dec number:'
            $errorText='Error: enter 1-2 hex digits (0-9, A-F or a-f).'
        }
        'DEC2HEX' {
            $prompt='Please input a Dec number (0-65535):'
            $answer='The Hex number:'
            $errorText='Error: enter 1-5 decimal digits in 0..65535.'
        }
        'SUMINPUT' {
            $prompt='Please input n (1-100):'
            $answer='Sum:'
            $errorText='Error: enter 1-3 decimal digits in 1..100.'
        }
    }
    $case | Add-Member -NotePropertyName Prompt -NotePropertyValue $prompt
    $case | Add-Member -NotePropertyName Answer -NotePropertyValue $answer
    $case | Add-Member -NotePropertyName ErrorText -NotePropertyValue $errorText
    if ($null -eq $case.Input) {
        $expected=$case.Result+"`r`n"
    } else {
        # AH=0Ah echoes the input including CR, followed by our CRLF.
        $expected=$prompt+"`r`n"+$case.Input+"`r`r`n"
        if ($case.Valid) { $expected+=$answer+"`r`n"+$case.Result+"`r`n" }
        else { $expected+=$errorText+"`r`n" }
    }
    $actual=[IO.File]::ReadAllText((Join-Path $work ($case.Id+'.OUT')),$ascii)
    if ($actual -cne $expected) { throw ('Output mismatch: '+$case.Id+' '+$case.Program+'; see '+$work) }
    $expectCode=if ($case.Valid) {0} else {1}
    $reports.Add(('PASS DOS {0} {1} input="{2}" result="{3}" exit={4}' -f $case.Id,$case.Program,$case.Input,$case.Result,$expectCode))
}

$cCount=0
if ($Suite -eq 'homework03') {
    foreach ($case in ($cases | Where-Object { $_.Program -eq 'SUMINPUT' })) {
        $process=New-Object System.Diagnostics.Process
        $process.StartInfo.FileName=Join-Path $taskRoot 'c\SUM_C.EXE'
        $process.StartInfo.WorkingDirectory=$work
        $process.StartInfo.UseShellExecute=$false
        $process.StartInfo.CreateNoWindow=$true
        $process.StartInfo.RedirectStandardInput=$true
        $process.StartInfo.RedirectStandardOutput=$true
        $process.StartInfo.RedirectStandardError=$true
        try {
            if (-not $process.Start()) { throw 'Could not start SUM_C.EXE.' }
            $stdoutTask=$process.StandardOutput.ReadToEndAsync()
            $stderrTask=$process.StandardError.ReadToEndAsync()
            $process.StandardInput.WriteLine($case.Input)
            $process.StandardInput.Close()
            if (-not $process.WaitForExit(10000)) { $process.Kill(); throw 'C program timed out.' }
            $exitCode=$process.ExitCode
            $stdout=$stdoutTask.Result
            $stderr=$stderrTask.Result
        } finally { $process.Dispose() }
        $expected=$case.Prompt+"`r`n"
        $expectedCode=if ($case.Valid) {0} else {1}
        if ($case.Valid) { $expected+=$case.Answer+"`r`n"+$case.Result+"`r`n" }
        else { $expected+=$case.ErrorText+"`r`n" }
        [IO.File]::WriteAllText((Join-Path $work ($case.Id+'.COUT')),$stdout,$ascii)
        if ($exitCode -ne $expectedCode -or $stdout -cne $expected -or $stderr.Length -ne 0) {
            throw ('C output/exit mismatch: '+$case.Id+'; see '+$work)
        }
        $cCount++
        $reports.Add(('PASS C {0} input="{1}" result="{2}" exit={3}' -f $case.Id,$case.Input,$case.Result,$exitCode))
    }
}
$summary='PASS {0}: {1} DOS cases, {2} C cases; exact output and exit codes verified.' -f $Suite,$cases.Count,$cCount
$reports.Add($summary)
[IO.File]::WriteAllText((Join-Path $work 'RESULTS.TXT'),($reports -join "`r`n")+"`r`n",$ascii)
Write-Output $summary
Write-Output ('Full results and captured output: '+$work)
