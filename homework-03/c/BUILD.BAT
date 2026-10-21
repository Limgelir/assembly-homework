@echo off
gcc -std=c99 -Wall -Wextra -Werror -O0 -g -fno-omit-frame-pointer -fno-inline "-fdebug-prefix-map=%CD%=." sum.c -o SUM_C.EXE
if errorlevel 1 goto failed
objdump -d -M intel SUM_C.EXE > SUM_C.DISASM.txt
if errorlevel 1 goto failed
echo Build completed. Run SUM_C.EXE in Windows.
exit /b 0
:failed
echo Build failed. Check messages above.
exit /b 1
