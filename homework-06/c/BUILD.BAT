@echo off
gcc -std=c99 -Wall -Wextra -Werror -O0 -g -fno-omit-frame-pointer -fno-inline "-fdebug-prefix-map=%CD%=." calendar.c -o CAL_C.EXE
if errorlevel 1 goto failed
objdump -d -M intel CAL_C.EXE > CAL_C.DISASM.txt
if errorlevel 1 goto failed
echo Build completed. Run CAL_C.EXE in Windows.
exit /b 0
:failed
exit /b 1
