@echo off
gcc -std=c99 -Wall -Wextra -Werror -O0 -g -fno-omit-frame-pointer -fno-inline -fno-builtin-putchar "-fdebug-prefix-map=%CD%=." nine.c -o NINE_C.EXE
if errorlevel 1 goto failed
objdump -d -M intel NINE_C.EXE > NINE_C.DISASM.txt
if errorlevel 1 goto failed
echo Build completed. Run NINE_C.EXE in Windows.
exit /b 0
:failed
echo Build failed. Check the messages above.
exit /b 1
