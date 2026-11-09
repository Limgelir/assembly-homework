@echo off
masm FIB.ASM,FIB.OBJ,FIB.LST;
if errorlevel 1 goto failed
link FIB.OBJ;
if errorlevel 1 goto failed
echo Build completed. Run FIB in DOSBox.
goto finished
:failed
echo Build failed.
:finished
