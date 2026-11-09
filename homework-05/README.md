# 作业五：递归 Fibonacci、寄存器和栈

输入 n（1～100），输出 F(n)，其中 F(0)=0、F(1)=1、F(n)=F(n-1)+F(n-2)。使用真实递归调用与缓存，并用 80 位无符号整数保证 F(100) 的完整精度。

## 提交材料

| 内容 | 文件 |
| --- | --- |
| DOS 汇编源码、程序、汇编清单 | [FIB.ASM](asm/FIB.ASM)、[FIB.EXE](asm/FIB.EXE)、[FIB.LST](asm/FIB.LST) |
| C 源码及 Windows 程序 | [fib.c](c/fib.c)、[FIB_C.EXE](c/FIB_C.EXE) |
| C 实际反汇编、78 条递归指令中文注释 | [完整反汇编](c/FIB_C.DISASM.txt)、[注释](c/ANNOTATED.md) |
| n=3、n=100 的完整调用/返回跟踪 | [TRACE3.TXT](asm/TRACE3.TXT)、[TRACE100.TXT](asm/TRACE100.TXT) |
| 自动验收 | [verify.ps1](verify.ps1)、[结果记录](verification/RESULTS.TXT) |

## 先运行验收

### 1. DOSBox 运行汇编版

本机已将 asm 文件同步到 `D:\ASM\HW05`。打开 DOSBox：

```dos
c:
cd \hw05
fib
```

输入 `10`，按 Enter，应显示：

```text
Please input n (1-100):
10
F(n):
55
```

每次运行接收一个输入，再次输入请重新运行 fib。

| 输入 | 预期 F(n) |
| --- | --- |
| 1 | 1 |
| 2 | 1 |
| 3 | 2 |
| 10 | 55 |
| 25 | 75025 |
| 50 | 12586269025 |
| 100 | 354224848179261915075 |
| 0、101、-1、abc，或直接 Enter | Error 提示，退出码 1 |

输入为 1～3 位十进制数字，允许合法前导零，不接受空格、正负号、小数点。程序内部需要 F(0)，但键盘输入范围按题目限定为 1～100。

### 2. Windows 运行 C 版

在 PowerShell 的仓库根目录：

```powershell
.\homework-05\c\FIB_C.EXE
```

输入 100，应输出相同的 21 位完整结果。C EXE 在 Windows 中运行，汇编 EXE 在 DOSBox 中运行。

### 3. 自动验收

在 Windows PowerShell 的仓库根目录执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\homework-05\verify.ps1
```

预期最后一条结论：

```text
PASS homework05: 117 DOS + 117 C input cases; 6 recursive traces including F(0) and F(100); exact 80-bit results; balanced stack.
```

检查包含：1～100 全部数值、3 个前导零输入、14 个非法输入，分别验证两版完整输出和退出码。期望值用 PowerShell BigInteger 的迭代算法独立计算；正式程序使用递归。

另外对 n=0、1、2、3、10、100 跟踪每次递归进入和返回，核对寄存器、返回指针、BP 帧链、SP 恢复、最大深度、最小 SP 和栈底 32 字节保护区。n=0 是通过 DEBUG 调用内部过程以验证基例，不改变键盘输入限制。

默认 DOSBox 0.74、FreeDOS DEBUG 2.50；路径可用 `-DosBoxPath`、`-DebugPath` 参数覆盖。脚本验收已有 EXE，不自动编译；修改源码后先构建。详细记录在被 Git 忽略的 .verify 中。ExecutionPolicy Bypass 仅对本次 PowerShell 进程生效。

## 按题目要求观察每次调用与返回

### 自动播放 n=3 的完整跟踪

在 DOSBox 的 HW05 目录：

```dos
path c:\
debug FIB.EXE < TRACE3.TXT
```

脚本先运行到 DS 初始化完成处，再把 AX 设置为 3，从计算入口开始；用于观察递归，不需要键盘输入。下表中的“进入”指该层保存寄存器后；“返回前”指寄存器已恢复、尚未执行 RET。

| 顺序 | 事件 | AX 中的 n | SP | BP |
| --- | --- | --- | --- | --- |
| 1 | 进入 F(3) | 3 | 0FF2h | 0FFCh |
| 2 | 进入 F(2) | 2 | 0FE4h | 0FEEh |
| 3 | 进入 F(1) | 1 | 0FD6h | 0FE0h |
| 4 | F(1) 返回前 | 1 | 0FE2h | 0FEEh |
| 5 | 进入 F(0) | 0 | 0FD4h | 0FDEh |
| 6 | F(0) 返回前 | 0 | 0FE0h | 0FEEh |
| 7 | F(2) 返回前 | 2 | 0FF0h | 0FFCh |
| 8 | 进入缓存的 F(1) | 1 | 0FE2h | 0FECh |
| 9 | F(1) 返回前 | 1 | 0FEEh | 0FFCh |
| 10 | F(3) 返回前 | 3 | 0FFEh | 初始 BP |
| 11 | 返回主程序 | 3 | 1000h | 初始 BP |

最低 SP=0FD4h，递归占用 1000h-0FD4h=44 字节。F(0) 比第一次 F(1) 多占 2 字节，是因为父层暂存了 F(n-1) 的结果指针。

跟踪 n=100：

```dos
debug FIB.EXE < TRACE100.TXT
```

此脚本输出较多，完整日志已保存到 [trace-100.txt](verification/trace-100.txt)。实际深度为 100、调用 199 次，最低 SP=0A86h，主程序恢复 SP=1000h。

### 手动单步

输入 `debug FIB.EXE` 后逐条执行：

```text
u 75 df
g 5
r ax
0003
g =60 7d
d ss:sp l 0e
t
g 7d df
```

- U 反汇编递归过程；G 5 先完成 DS 初始化。
- R AX 把本次演示参数设为 3；G =60 7D 从主调用处开始，在本层保存完寄存器后停下。
- D SS:SP L 0E 查看这一层的 14 字节帧（保存的寄存器、BP、返回 IP）。
- 之后交替执行 T 和 G 7D DF：T 先离开当前断点，G 在下一次“进入层”或“返回前”暂停。不要反复在当前 IP 原样设置同一个断点，否则 DEBUG 可能立即再次停在原处。
- IP=007Dh 表示进入一层；IP=00DFh 表示该层即将 RET。T 执行 RET 后，观察 IP 回到父调用的下一条指令、SP 增加 2。

最后用 G 63 回到主程序计算完成处，再 G 执行输出，Q 退出 DEBUG。这些偏移对应当前提交的 EXE；改动代码后应结合新 LST 更新脚本断点。

## 为什么需要缓存和 80 位数据

直接递归求 fib(n-1) 和 fib(n-2) 会产生大量重复计算，n=100 无法作为实用的课程验收程序。这里仍保留两次真实 CALL fib，只是将已计算值存入 memo[n]，由 ready[n] 判断能否直接返回。

每个新 n 只求值一次，第二条分支通常命中缓存；一次全新运行中 n>=1 的总调用数为 2n-1，最大深度为 n。这不是把递归替换为迭代，ASM 与 C 的反汇编中都能看到调用自身的指令。

F(25) 已超过 16 位无符号范围，F(48) 超过 32 位，F(94) 超过 64 位。F(100)=354224848179261915075，必须提供更大精度。每个缓存项用 5 个 16 位 word，共 80 位，按低位在前保存；整个 memo 有 101 个元素，覆盖 F(0) 到 F(100)。

汇编通过 ADC 逐个 word 加上进位。移动指针使用 INC，因其不会破坏 CF；不能随意将其换为影响进位标志的 ADD。C 使用 uint32_t 中间和，保存低 16 位并把高位作为 carry。两版都不依赖普通 64 位整数容纳最终结果。

输出前复制数据，通过从高 word 到低 word 的长除法转换十进制。缓存中的结果不会被显示过程破坏。每一步 DIV 前的余数均小于 10，保证 word 除法的商不溢出。

## 栈初始化和空间估算

stack_seg 声明为 PARA STACK 段，包含 2048 个 word，共 **4096 字节**，初值为 A55Ah。LINK 写入 EXE 的 SS:SP 信息，由 DOS 加载器初始化；本次 DEBUG 确认入口 SP=1000h。无需在已有 DOS EXE 栈上冒险重置 SS/SP。

每层近调用：

| 项目 | 字节数 |
| --- | --- |
| CALL 压入返回 IP | 2 |
| 保存 BP、AX、BX、CX、DX、DI | 12 |
| 每层固定总计 | 14 |
| 第一分支返回后，临时保存 SI 指针 | 另 2 |

BP+2 是返回 IP，BP 是旧 BP，BP-2 是本层参数 n，BP-4/-6/-8/-10 保存 BX/CX/DX/DI。SI 是返回值，指向数据段中的 memo[n]，不作为需要保持的输入寄存器；其他约定保持的寄存器均在返回前逆序恢复。

即使用“100 层固定帧 + 99 层都额外保存指针”的保守估计，也只有 100×14+99×2=1598 字节。实际求值顺序中第二分支命中缓存，本次 n=100 实测为 **1402 字节**。

分配 4 KiB 留出中断、调试以及其他操作的余量。这里的最小 SP 统计针对 fib 过程，不能理解为已统计每一次硬件/调试中断的临时压栈；但栈底 32 字节保护区保持不变，且每个递归帧都已验证正确返回。打印和 DOS 输入输出发生在递归链外。

| n | 调用次数 | 最大层数 | 递归最小 SP | 递归峰值字节数 |
| --- | --- | --- | --- | --- |
| 0（内部测试） | 1 | 1 | 0FF2h | 14 |
| 1 | 1 | 1 | 0FF2h | 14 |
| 2 | 3 | 2 | 0FE2h | 30 |
| 3 | 5 | 3 | 0FD4h | 44 |
| 10 | 19 | 10 | 0F72h | 142 |
| 100 | 199 | 100 | 0A86h | 1402 |

这些数值只针对本次程序和数据表示，不能推广到任意递归程序。增大 n 上限时，需要同时重新评估数值精度、缓存和栈。

## 构建

在 DOSBox 的 HW05 目录：

```dos
path c:\
build
```

等价于：

```dos
masm FIB.ASM,FIB.OBJ,FIB.LST;
link FIB.OBJ;
```

MASM 5.00 / LINK 3.60，本次 LST 为 0 Warning Errors、0 Severe Errors。源文件采用 ASCII/CRLF。

Windows 中进入 homework-05\c，执行 BUILD.BAT，生成 FIB_C.EXE 和完整反汇编。采用 MinGW GCC 6.3.0，开启 -Wall -Wextra -Werror；禁止内联和尾调用优化，方便观察递归。C 的栈由 Windows 可执行文件配置管理，与 DOS 的栈分开，详见 [C 注释](c/ANNOTATED.md)。

## 实测材料

2026-11-09 完成构建与验收，Windows PowerShell 5.1 下的上述验收命令通过。

- [完整验收结果](verification/RESULTS.TXT)
- [DOS F(100)](verification/dos-100.txt)、[C F(100)](verification/c-100.txt)、[输入 0 被拒绝](verification/invalid-0.txt)
- [n=3 完整逐层跟踪](verification/trace-3.txt)、[n=100 跟踪](verification/trace-100.txt)
- [构建日志](verification/build.txt)、[C 工具链](verification/c-toolchain.txt)、[文件 SHA-256](verification/SHA256SUMS.txt)

原始 DOS 输出文件保留输入回显中的回车字符，部分文本查看器可能显示额外空行；自动验收已核对实际字节。
