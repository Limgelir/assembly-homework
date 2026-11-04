# 作业四第二部分：九九乘法表纠错

按老师更新的题目扫描完整的 **9×9=81 个数据**，比较每个字节与行号×列号，输出错误位置。这里 x 表示行、y 表示列，均从 1 开始。按题目基本要求完成检测与定位，保留原表供检查，不直接修改它。

第一部分的倒三角乘法表仍在上一级目录。本部分检查完整方阵，包含上、下三角全部位置。

## 预期结果

```text
x y
1 1  error
2 3  error
4 5  error
6 6  error
8 8  error

accomplish!
```

| 行 x | 列 y | 原始值 | 正确值 | 相对表首地址的偏移 |
| --- | --- | --- | --- | --- |
| 1 | 1 | 7 | 1 | 0000h |
| 2 | 3 | 7 | 6 | 000Bh |
| 4 | 5 | 7 | 20 | 001Fh |
| 6 | 6 | 7 | 36 | 0032h |
| 8 | 8 | 7 | 64 | 0046h |

程序根据 MUL 和比较结果判断错误；没有把这五个坐标写死。表内 (1,7)、(7,1) 的 7 是正确值，会正常通过。

## 文件说明

| 文件 | 用途 |
| --- | --- |
| [asm/CHECK.ASM](asm/CHECK.ASM)、[CHECK.EXE](asm/CHECK.EXE)、[CHECK.LST](asm/CHECK.LST) | 16 位 DOS 汇编实现、可执行程序、汇编清单 |
| [asm/CHECKDBG.TXT](asm/CHECKDBG.TXT) | 反汇编、第一次错误、嵌套过程调用和数据段观察 |
| [asm/ALLDBG.TXT](asm/ALLDBG.TXT) | 观察全部 81 次 check_cell 调用前后的寄存器 |
| [c/global.c](c/global.c)、[GLOBAL.EXE](c/GLOBAL.EXE) | 全局数组版本 |
| [c/local.c](c/local.c)、[LOCAL.EXE](c/LOCAL.EXE) | 自动局部数组版本 |
| [c/DATA.H](c/DATA.H)、[c/scan.c](c/scan.c) | 相同数据初值和公共扫描/错误报告过程 |
| [c/ANNOTATED.md](c/ANNOTATED.md) | 全局/局部数组、寻址、循环与过程的 103 条指令中文注释 |
| [verify.ps1](verify.ps1) | 自动验收 |
| tests/driver.c、tests/TEST_C.EXE | 仅供验收，将任意 81 字节交给实际的 scan.c 检查 |

C 程序为 Windows 32 位 x86 可执行文件，汇编程序在 DOSBox 中运行。

## 手动验收

### 1. 在 DOSBox 中执行

本机已将本部分的 asm 文件同步到 `D:\ASM\HW04CHK`。打开 DOSBox 输入：

```dos
c:
cd \hw04chk
check
```

程序无需输入，应该显示上述五个错误坐标及 accomplish!，随后返回提示符。退出码 0 表示检查完成；发现表中错误本身不是运行失败。

### 2. 运行两个 C 版本

Windows PowerShell 中进入仓库根目录：

```powershell
.\homework-04\checker\c\GLOBAL.EXE
.\homework-04\checker\c\LOCAL.EXE
```

两份输出都应与 DOS 版一致。再打开 [C 反汇编对比](c/ANNOTATED.md)，重点看：GLOBAL 直接传递 .data 中数组地址；LOCAL 先把初值复制到 main 的栈帧，再传递栈地址；公共检查函数均使用 `base + row*9 + column` 访问数据。

### 3. 看 DEBUG 反汇编及内存

在 DOSBox 的 HW04CHK 目录执行：

```dos
path c:\
debug CHECK.EXE < CHECKDBG.TXT
```

脚本首先 U 反汇编，再 G 运行到指定 IP，T 单步进入或返回，D 查看数据。主要观察：

| 观察点 | 预期 |
| --- | --- |
| IP=0009h | DS 已初始化，SI=0000h |
| `d ds:0 l 51` | 显示 81 字节；首字节为 07，最后为 51（十六进制 81） |
| IP=001Ch | 调用前 BX=0101h、CX=9、SI=0、SP=00FEh |
| T 进入 check_cell | SP=00FCh，栈上返回地址为 1F 00 |
| IP=003Fh | MUL 后 AX=0001，与 DS:SI 中 07 比较 |
| IP=0076h | report_error 借用 CX 打印空格后，CX=0 |
| IP=0079h | report_error 恢复后，CX=9，随后 RET 返回 check_cell |
| IP=004Bh | check_cell 恢复寄存器后，RET 回到 001Fh |
| IP=0029h | 全表检查结束，SI=0051h、CX=0、SP=0100h |

段寄存器的具体地址随加载位置变化，不要求与日志一致。偏移对应本次 EXE；修改源码重新构建后，应同步调整 DEBUG 和验收脚本中的断点。

也可手动验证程序确实读取了表中数据：

```dos
debug CHECK.EXE
```

在 DEBUG 中逐条输入：

```text
g 9
e ds:0 01
g
q
```

这只把本次进程中 (1,1) 改为正确的 1，随后应只报告其余四处错误。没有使用 W 命令，不会修改磁盘上的 EXE；退出后直接运行 CHECK 仍会显示原来的五处错误。

## 自动验收

仅验收第二部分，在 Windows PowerShell 的仓库根目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\homework-04\checker\verify.ps1
```

完整验收作业四两部分：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\homework-04\verify.ps1
```

最后应出现：

```text
PASS checker: 3 default programs, 85 DOS + 85 C data fixtures, 81 procedure calls.
```

验证范围：

- 三个正式程序（DOS、C 全局、C 局部）都输出完全相同的五个错误坐标。
- 85 组数据：老师示例、全表正确、81 个不同位置各自单独出错、全 0、全 255。每组分别运行 DOS 程序和与正式 C 程序共用 scan.c 的测试驱动；期望值用重复加法独立计算。
- DOS 测试只通过 DEBUG 修改被加载进程的数据段，不写回 EXE。C 两个正式版本各验收示例数据，另外 85 组通过测试驱动检验实际公共扫描过程。
- 检查全部 81 次 CALL/RET 前后的寄存器，确认 SI 连续访问 0000h～0050h、CX 双循环计数正确、最终 SP 恢复。
- 检查嵌套调用、栈中返回地址、CX 保存恢复，以及扫描前后原始 81 字节完全不变。

默认工具路径是 DOSBox 0.74 和 `D:\ASM\DEBUG.COM`（FreeDOS DEBUG 2.50）。若路径不同，传入 `-DosBoxPath` 和 `-DebugPath`。DEBUG 输出解析针对上述版本。脚本不重新编译，修改源码后须先构建再验收。ExecutionPolicy Bypass 仅作用于此次进程。

运行记录写在被 Git 忽略的 .verify 目录，提交的实际结果位于 [verification](verification/RESULTS.TXT)。

## 汇编实现要点

数据段从 table 开始，连续存放 9 行 DB，每行 9 个字节。显示坐标从 1 开始，因此：

```text
地址 = DS 段内 table 偏移 + (x-1)*9 + (y-1)
```

初始化 DS 后，SI 指向 table。内层循环每次检查 [SI] 并 INC SI；跨行时不重置 SI，连续扫描全部 81 字节。读取 [SI] 默认使用 DS；它不是字变量，因此每项前进 1 而非 2。

BH 保存行号、BL 保存列号；MOV AL,BH / MUL BL 得到正确乘积 AX。最大乘积 81，AH=0，故以 CMP AL,[SI] 比较一个字节即可。相等跳过，错误时调用 report_error。

外层 CX 初始为 9，进入一行先 PUSH CX，内层 CX 设为 9，结束后 POP CX 再执行外层 LOOP。check_cell 保存 AX/BX/CX/DX/SI；嵌套的 report_error 也保存 AX/CX/DX，再借用 CX 打印两格空白。每层按相反顺序 POP，最后 RET。标志寄存器不作为过程的保存承诺。

C 数组的下标从 0 开始，比较的是 (row+1)*(column+1)，输出时再将下标加 1。

## 构建与反汇编

DOSBox 的 HW04CHK 目录中：

```dos
path c:\
build
```

等价命令：

```dos
masm CHECK.ASM,CHECK.OBJ,CHECK.LST;
link CHECK.OBJ;
```

MASM 5.00 / LINK 3.60，本次为 0 Warning Errors、0 Severe Errors。源码采用 ASCII/CRLF。

Windows 中进入 checker\c，运行 BUILD.BAT，会生成 GLOBAL.EXE、LOCAL.EXE、测试驱动、两个原始反汇编和两个符号表。使用 MinGW GCC 6.3.0 / GNU objdump 2.28，开启 -Wall -Wextra -Werror，并保留过程调用和栈帧方便观察。

全局数组具有静态存储期；自动局部数组具有当前调用的生存期。局部版本的初始化模板仍可能存在 EXE 数据节中，应通过实际传参地址区分模板与数组本体，详见 [103 条指令注释](c/ANNOTATED.md)。

## 实测材料

2026-11-04 完成构建和验证，Windows PowerShell 5.1 下的实际命令通过。

- [DOS 示例输出](verification/dos-output.txt)、[C 全局输出](verification/global-output.txt)、[C 局部输出](verification/local-output.txt)
- [85 组数据及调用验收结果](verification/RESULTS.TXT)
- [详细 DEBUG 记录](verification/trace-debug.txt)、[81 次调用记录](verification/all-calls-debug.txt)
- [全表正确的 DEBUG 运行](verification/all-correct-debug.txt)、[仅最后一项错误的运行](verification/last-cell-debug.txt)
- [构建记录](verification/build.txt)、[C 工具链](verification/c-toolchain.txt)
- [文件 SHA-256](verification/SHA256SUMS.txt)
