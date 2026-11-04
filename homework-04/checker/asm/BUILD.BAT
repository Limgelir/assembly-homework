@echo off
masm CHECK.ASM,CHECK.OBJ,CHECK.LST;
if errorlevel 1 goto failed
link CHECK.OBJ;
if errorlevel 1 goto failed
echo Build completed. Run CHECK in DOSBox.
goto finished
:failed
echo Build failed.
:finished
