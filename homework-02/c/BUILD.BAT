@echo off
gcc -std=c99 -Wall -Wextra -Werror -O0 -g -fno-omit-frame-pointer -fno-inline -fno-builtin-putchar "-fdebug-prefix-map=%CD%=." ascii.c -o ASCII_C.EXE
if errorlevel 1 goto failed
objdump -d -M intel ASCII_C.EXE > ASCII_C.DISASM.txt
if errorlevel 1 goto failed
echo Build completed. Run ASCII_C.EXE in Windows.
goto finished
:failed
echo Build failed. Check the messages above.
:finished
