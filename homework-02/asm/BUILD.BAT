@echo off
masm ASCIILP.ASM,ASCIILP.OBJ,ASCIILP.LST;
if errorlevel 1 goto failed
link ASCIILP.OBJ;
if errorlevel 1 goto failed
masm ASCIIJMP.ASM,ASCIIJMP.OBJ,ASCIIJMP.LST;
if errorlevel 1 goto failed
link ASCIIJMP.OBJ;
if errorlevel 1 goto failed
echo Build completed. Run ASCIILP and ASCIIJMP.
goto finished
:failed
echo Build failed. Check the messages above.
:finished
