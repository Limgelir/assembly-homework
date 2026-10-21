@echo off
masm HEX2DEC.ASM,HEX2DEC.OBJ,HEX2DEC.LST;
if errorlevel 1 goto failed
link HEX2DEC.OBJ;
if errorlevel 1 goto failed
masm DEC2HEX.ASM,DEC2HEX.OBJ,DEC2HEX.LST;
if errorlevel 1 goto failed
link DEC2HEX.OBJ;
if errorlevel 1 goto failed
echo Build completed.
goto finished
:failed
echo Build failed. Check messages above.
:finished
