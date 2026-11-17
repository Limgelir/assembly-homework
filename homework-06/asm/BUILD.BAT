@echo off
masm CALENDAR.ASM,CALENDAR.OBJ,CALENDAR.LST;
if errorlevel 1 goto failed
link CALENDAR.OBJ;
if errorlevel 1 goto failed
echo Build completed. Run CALENDAR in DOSBox.
goto finished
:failed
echo Build failed.
:finished
