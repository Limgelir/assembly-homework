@echo off
gcc -std=c99 -Wall -Wextra -Werror -O0 -g -fno-omit-frame-pointer -fno-inline -fno-optimize-sibling-calls "-fdebug-prefix-map=%CD%=." fib.c -o FIB_C.EXE
if errorlevel 1 goto failed
objdump -d -M intel FIB_C.EXE > FIB_C.DISASM.txt
if errorlevel 1 goto failed
echo Build completed. Run FIB_C.EXE in Windows.
exit /b 0
:failed
exit /b 1
