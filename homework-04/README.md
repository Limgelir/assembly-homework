# 作业四：乘法指令和过程调用

按照题图输出倒三角九九乘法表：行号从 9 递减到 1，第 r 行输出 r×1 到 r×r，共 45 个算式。每个算式调用一次过程，使用实际乘法指令计算，过程内部借用主程序的寄存器并在返回前恢复。

## 提交材料

| 内容 | 文件 |
| --- | --- |
| 8086 汇编源码 | [NINE.ASM](asm/NINE.ASM) |
| DOS 可执行程序、汇编清单 | [NINE.EXE](asm/NINE.EXE)、[NINE.LST](asm/NINE.LST) |
| C 源码、Windows 可执行程序 | [nine.c](c/nine.c)、[NINE_C.EXE](c/NINE_C.EXE) |
| C 真实反汇编和 60 条指令中文注释 | [NINE_C.DISASM.txt](c/NINE_C.DISASM.txt)、[ANNOTATED.md](c/ANNOTATED.md) |
| CALL/RET 单步演示、全部 45 次调用断点 | [CALLDBG.TXT](asm/CALLDBG.TXT)、[ALLDBG.TXT](asm/ALLDBG.TXT) |
| 自动验收 | [verify.ps1](verify.ps1)、[运行结果](verification/RESULTS.TXT) |

## 预期输出

```text
The 9mul9 table:
9*1=9    9*2=18   9*3=27   9*4=36   9*5=45   9*6=54   9*7=63   9*8=72   9*9=81
8*1=8    8*2=16   8*3=24   8*4=32   8*5=40   8*6=48   8*7=56   8*8=64
7*1=7    7*2=14   7*3=21   7*4=28   7*5=35   7*6=42   7*7=49
6*1=6    6*2=12   6*3=18   6*4=24   6*5=30   6*6=36
5*1=5    5*2=10   5*3=15   5*4=20   5*5=25
4*1=4    4*2=8    4*3=12   4*4=16
3*1=3    3*2=6    3*3=9
2*1=2    2*2=4
1*1=1
```

除每行最后一项外，每个单元格占 9 列。乘积为一位数时补 4 个空格，两位数时补 3 个空格；行尾不添加多余空格。最长数据行 78 个字符，适合 DOS 的 80 列显示。整个输出含表头、CRLF 换行，共 411 字节。

## 先运行验收

### 1. DOSBox：验收汇编程序

本机已将 asm 目录同步到 `D:\ASM\HW04`，DOSBox 启动配置将 `D:\ASM` 挂载为 C 盘。打开 DOSBox，输入：

```dos
c:
cd \hw04
nine
```

不用输入数字。程序应立即输出上面的表，然后返回 DOS 提示符。检查：

- 第一行是 9×1 到 9×9，最后一项 9*9=81。
- 下一行少一项，一直缩短到最后的 1*1=1。
- 每行的乘数从 1 开始；例如 8 行最后为 8*8=64，5 行最后为 5*5=25。
- 一位数和两位数乘积后面的列保持对齐。

若在其他电脑运行，将 asm 目录复制到 DOSBox 已挂载的目录中。汇编 EXE 是 16 位 DOS 程序，应在 DOSBox 中启动。

### 2. Windows：验收 C 程序

在 PowerShell 中进入仓库根目录，运行：

```powershell
.\homework-04\c\NINE_C.EXE
```

应输出完全相同的表。该 EXE 为 Windows 32 位 x86 程序，在 Windows 运行。

### 3. 自动验收输出和所有过程调用

在 Windows PowerShell 的仓库根目录执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\homework-04\verify.ps1
```

成功时显示六行 PASS，最后一行为：

```text
PASS homework04: output, multiplication, nested loops, CALL/RET, and register/stack preservation verified.
```

脚本实际执行 DOS 与 C 的 EXE，并进行以下检查：

1. 用重复加法独立计算 45 个乘积，核对两版完整输出、行序、列对齐、CRLF、无行尾空格和成功退出码。
2. 核对两版输出逐字节一致（411 字节）。
3. 单步观察近 CALL 压入的返回地址、RET 返回、CX 的借用与恢复、SP 的变化。
4. 在全部 45 次 print_cell 调用前后暂停，逐次比较 AX/BX/CX/DX/SP/BP/SI/DI/DS/ES/SS/CS，并核对主程序的行号、列号和内层剩余次数。
5. 确认最后外层 CX=0、SP 回到初始的 0100h。

使用本机 DOSBox 0.74 和老师工具目录中的 FreeDOS DEBUG 2.50。若路径不同，可传参：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\homework-04\verify.ps1 -DosBoxPath '实际DOSBox.exe路径' -DebugPath '实际DEBUG.COM路径'
```

脚本只验收当前 EXE，不自动编译；修改源码后先构建。结果保存在被 Git 忽略的 `.verify` 目录。进程内的 ExecutionPolicy Bypass 不会修改系统执行策略。

## 用 DEBUG 看懂 CALL 和 RET

在 DOSBox 的 HW04 目录输入：

```dos
path c:\
debug NINE.EXE < CALLDBG.TXT
```

PATH 让 DOS 找到 C 盘根目录中的 DEBUG.COM。脚本自动显示主循环和过程的反汇编，并运行以下观察步骤：

| 时刻 | IP | SP | 观察 |
| --- | --- | --- | --- |
| 程序入口 | 0000h | 0100h | 初始栈顶 |
| 第一次 CALL 前 | 0019h | 00FEh | 外层 CX 已压栈；BX=0901h，CX=9 |
| 单步进入 print_cell | 002Dh | 00FCh | CALL 压入返回地址 001Ch，栈内两字节为 1C 00 |
| 执行 MUL 后 | 0049h | 00F4h | 过程保存了四个寄存器；AX=9×1=0009h |
| 填充空格后、恢复前 | 0060h | 00F4h | 过程内的 LOOP 已将 CX 减为 0 |
| POP 完成、RET 前 | 0064h | 00FCh | CX 恢复为 9，AX/BX/DX 也恢复 |
| 单步执行 RET 后 | 001Ch | 00FEh | 返回 CALL 后的 INC BL，继续主循环 |
| 所有行完成 | 0028h | 0100h | 外层 CX=0，栈平衡 |

这些地址对应本次提交的 EXE。具体段地址随加载位置变化；修改源码、重新构建后，按新 LST/反汇编同步修改断点脚本与验收脚本中的偏移。

也可以手动体验最关键的一段：

```dos
debug NINE.EXE
```

进入 DEBUG 后依次输入：

```text
g 19
t
d ss:fc l 2
g 64
t
g
q
```

先看 CALL 将 SP 从 00FE 减为 00FC，再看栈中的 1C 00，最后看 RET 回到 IP=001C、SP=00FE。程序输出与调试文字会交错，这是断点暂停时的正常表现。

## 程序设计

### 乘法和双循环

BH 保存行号（9 到 1），BL 保存列号（1 到 BH）。主循环通过 `CALL print_cell` 输出一个单元格，再增加 BL。

外层 CX 初始为 9；每行先 PUSH CX，内层 CX 改为当前行号。内层 LOOP 结束后换行、POP CX 恢复外层次数、DEC BH，再执行外层 LOOP。这样两层循环不会互相覆盖计数。

在 print_cell 中：

```asm
mov al,bh
mul bl
```

这里是 8 位无符号乘法，隐含的另一个操作数是 AL，完整结果在 AX；最大值 9×9=81=0051h。程序自己做十进制转换后输出，没有预存 45 个答案。

### 过程调用与保护寄存器

print_cell 输入为 BH/BL，输出为屏幕上的算式；约定保持 AX、BX、CX、DX，标志寄存器不保证保持。入口：

```asm
push ax
push bx
push cx
push dx
```

过程内 CX 用作空格数量，print_dec 也会借用 BX=10、CX=十进制位数、DX=余数。返回前按逆序恢复：

```asm
pop dx
pop cx
pop bx
pop ax
ret
```

如果漏掉 CX 的恢复，主循环的剩余次数就会被过程覆盖；如果 PUSH/POP 数量或顺序不匹配，还可能让 RET 把保存的寄存器误当成返回地址。CALL/RET 本身并不替程序保存通用寄存器。

本程序使用同代码段内的近调用，CALL 压入 16 位返回 IP，RET 弹出它。print_cell 内还会调用 print_digit、print_dec、put_char，构成实际的嵌套过程调用；所有路径保持栈平衡。

### 十进制输出与字符输出

print_dec 将 AX 反复除以 10，把余数压栈，逆序出栈并加 '0' 得到 ASCII 数字。每次 DIV 前清零 DX，避免错误地使用 DX:AX 的高位。

put_char 使用 INT 21h/AH=02h 输出 DL，在设置 AH 前保存 AX，完成后恢复，防止字符输出破坏乘积。换行输出 CR、LF 两个字符。

### C 语言对照

C 中的 print_cell(row,column) 同样负责一个单元格，main 保留两层循环。编译时禁用内联，已确认真实 EXE 中保留 CALL 和 RET。乘法在该构建中生成 32 位双操作数 IMUL；详细区别和逐条解释见 [反汇编中文注释](c/ANNOTATED.md)。

C 的调用约定不要求保留所有临时寄存器；不能将 C 的 EAX 使用规则直接套用为本汇编过程的保存约定。

## 重新构建

在 DOSBox 的 HW04 目录：

```dos
path c:\
build
```

或逐条执行：

```dos
masm NINE.ASM,NINE.OBJ,NINE.LST;
link NINE.OBJ;
```

源码是 ASCII/CRLF，使用 MASM 5.00、LINK 3.60；LST 和构建日志均为 0 Warning Errors、0 Severe Errors。

在 Windows 的 homework-04\c 目录运行 `BUILD.BAT`，生成 C EXE 和 objdump 原始反汇编。使用 MinGW GCC 6.3.0 / GNU objdump 2.28，编译开启 `-Wall -Wextra -Werror`，并保留便于观察的过程调用。更改生成的机器码后，同步更新注释与验证记录。

## 实际验收记录

2026-10-26 完成构建和运行验证，Windows PowerShell 5.1 下执行验收命令通过。

- [DOS 输出](verification/dos-output.txt)、[C 输出](verification/c-output.txt)
- [六项验收结论](verification/RESULTS.TXT)
- [CALL/RET 详细单步记录](verification/call-debug.txt)
- [全部 45 次调用前后的 DEBUG 原始记录](verification/all-calls-debug.txt)
- [MASM/LINK 构建日志](verification/build.txt)
- [C 工具链版本](verification/c-toolchain.txt)
- [提交文件 SHA-256](verification/SHA256SUMS.txt)

仓库保存源码、可执行文件和验收材料，工具 MASM、LINK、DEBUG 仍使用本机课程环境中的版本。
