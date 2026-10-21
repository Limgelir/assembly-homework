@echo off
masm SUM.ASM,SUM.OBJ,SUM.LST;
if errorlevel 1 goto failed
link SUM.OBJ;
if errorlevel 1 goto failed
masm SUMDATA.ASM,SUMDATA.OBJ,SUMDATA.LST;
if errorlevel 1 goto failed
link SUMDATA.OBJ;
if errorlevel 1 goto failed
masm SUMSTACK.ASM,SUMSTACK.OBJ,SUMSTACK.LST;
if errorlevel 1 goto failed
link SUMSTACK.OBJ;
if errorlevel 1 goto failed
masm SUMINPUT.ASM,SUMINPUT.OBJ,SUMINPUT.LST;
if errorlevel 1 goto failed
link SUMINPUT.OBJ;
if errorlevel 1 goto failed
echo Build completed.
goto finished
:failed
echo Build failed. Check messages above.
:finished
