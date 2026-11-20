@echo off
masm MAIN.ASM,MAIN.OBJ,MAIN.LST;
if errorlevel 1 goto failed
masm INPUT.ASM,INPUT.OBJ,INPUT.LST;
if errorlevel 1 goto failed
masm DATE.ASM,DATE.OBJ,DATE.LST;
if errorlevel 1 goto failed
masm SCREEN.ASM,SCREEN.OBJ,SCREEN.LST;
if errorlevel 1 goto failed
masm DATA.ASM,DATA.OBJ,DATA.LST;
if errorlevel 1 goto failed
link /map MAIN.OBJ+INPUT.OBJ+DATE.OBJ+SCREEN.OBJ+DATA.OBJ,CALENDAR.EXE,CALENDAR.MAP;
if errorlevel 1 goto failed
echo Build completed. Run CALENDAR in DOSBox.
goto finished
:failed
echo Build failed.
:finished
