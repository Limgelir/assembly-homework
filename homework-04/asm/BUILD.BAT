@echo off
masm NINE.ASM,NINE.OBJ,NINE.LST;
if errorlevel 1 goto failed
link NINE.OBJ;
if errorlevel 1 goto failed
echo Build completed. Run NINE in DOSBox.
goto finished
:failed
echo Build failed. Check the messages above.
:finished
