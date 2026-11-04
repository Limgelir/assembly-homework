@echo off
gcc -std=c99 -Wall -Wextra -Werror -O0 -g -fno-omit-frame-pointer -fno-inline "-fdebug-prefix-map=%CD%=." global.c scan.c -o GLOBAL.EXE
if errorlevel 1 goto failed
gcc -std=c99 -Wall -Wextra -Werror -O0 -g -fno-omit-frame-pointer -fno-inline "-fdebug-prefix-map=%CD%=." local.c scan.c -o LOCAL.EXE
if errorlevel 1 goto failed
gcc -std=c99 -Wall -Wextra -Werror -O0 -g -fno-omit-frame-pointer -fno-inline "-fdebug-prefix-map=%CD%=." ../tests/driver.c scan.c -o ../tests/TEST_C.EXE
if errorlevel 1 goto failed
objdump -d -M intel GLOBAL.EXE > GLOBAL.DISASM.txt
if errorlevel 1 goto failed
objdump -d -M intel LOCAL.EXE > LOCAL.DISASM.txt
if errorlevel 1 goto failed
objdump -h -t GLOBAL.EXE > GLOBAL.SYMBOLS.txt
if errorlevel 1 goto failed
objdump -h -t LOCAL.EXE > LOCAL.SYMBOLS.txt
if errorlevel 1 goto failed
echo Build completed.
exit /b 0
:failed
exit /b 1
