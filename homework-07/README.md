# 作业七：多模块实现输出月历

把作业六改为 **5 个独立汇编模块 + 1 个宏包含文件**。每个 ASM 分别汇编为 OBJ，再链接为一个 DOS EXE。保留键盘输入年份（1900～2099）、月份（1～12）和月历输出功能，实际比较同文件近调用、跨文件近调用、跨文件远调用。

## 提交材料与模块划分

| 文件 | 职责 |
| --- | --- |
| [MAIN.ASM](asm/MAIN.ASM) | 入口、栈定义、输入流程、范围检查、调度计算和显示 |
| [INPUT.ASM](asm/INPUT.ASM) | DOS 0Ah 行输入，十进制解析与非法字符检查 |
| [DATE.ASM](asm/DATE.ASM) | 闰年、每月天数、月初星期计算 |
| [SCREEN.ASM](asm/SCREEN.ASM) | 月历布局、数字和字符串输出 |
| [DATA.ASM](asm/DATA.ASM) | 唯一一份共享数据、月份表、字符串及输入缓冲区 |
| [MACROS.INC](asm/MACROS.INC) | PRINT_TEXT、NEW_LINE、REQUIRE_RANGE 三个宏；LOCAL 标签 |
| [BUILD.BAT](asm/BUILD.BAT) | 五次 MASM 汇编，一次 LINK 链接 |
| [CALENDAR.EXE](asm/CALENDAR.EXE)、[CALENDAR.MAP](asm/CALENDAR.MAP) | 可直接运行的程序及链接后地址表 |
| [实验报告](EXPERIMENT.md) | PUBLIC/EXTRN、宏展开、真实机器码和 CS/IP/SP/栈比较 |
| [TRACE.TXT](asm/TRACE.TXT)、[跟踪记录](verification/trace-202611.txt) | 可重放的 DEBUG 命令及实际结果 |
| [verify.ps1](verify.ps1)、[RESULTS.TXT](verification/RESULTS.TXT) | 全范围自动验收及记录 |

asm 目录还包含五份 LST，可查看每个模块的机器码、宏展开和外部符号。OBJ 是构建中间文件，不纳入提交；可随时重新生成。

## 1. 直接运行验收

本机已同步到 `D:\ASM\HW07`。DOSBox 把 `D:\ASM` 挂载为 C 盘，打开后输入：

```dos
c:
cd \hw07
calendar
```

依次输入 `2026`、`11`，每次按 Enter，结果应为：

```text
Please input year (1900-2099): 2026
Please input month (1-12): 11

2026  November
Su Mo Tu We Th Fr Sa
 1  2  3  4  5  6  7
 8  9 10 11 12 13 14
15 16 17 18 19 20 21
22 23 24 25 26 27 28
29 30
```

程序一次输出一个月，再次输入请重新运行 `calendar`。

| 输入 | 验收重点 |
| --- | --- |
| 1900 / 2 | 1 日星期四，28 天；1900 不是闰年 |
| 2000 / 2 | 1 日星期二，29 天；2000 是闰年 |
| 2026 / 8 | 1 日星期六，31 天占六行 |
| 2026 / 11 | 1 日星期日，30 天，与作业六示例一致 |
| 2099 / 12 | 1 日星期二，31 日星期四 |
| 年份 1899、2100 或月份 0、13 | Error 提示并退出，退出码 1 |

年份输入 4 位数字，月份 1～2 位数字，允许月份前导零；空行、字母、正负号、小数和空格均报错。

## 2. 确认是分别汇编、共同链接

在 DOSBox 中执行：

```dos
c:
cd \hw07
path c:\
build
```

应依次看到 MAIN、INPUT、DATE、SCREEN、DATA 的汇编结果，每份都为 `0 Warning Errors`、`0 Severe Errors`，最后显示 `Build completed`。五份源码分别生成五个 OBJ，并通过下面命令形成唯一 EXE：

```dos
link /map MAIN.OBJ+INPUT.OBJ+DATE.OBJ+SCREEN.OBJ+DATA.OBJ,CALENDAR.EXE,CALENDAR.MAP;
```

这些不是把所有过程 INCLUDE 到一个主文件里汇编。只有宏定义采用 INCLUDE；五份逻辑模块都有各自的汇编过程，通过 PUBLIC/EXTRN 和链接器连接。

## 3. 一键完整验收

在 Windows PowerShell 中：

```powershell
Set-Location 'D:\Limgelir\Files\汇编语言\assembly-homework'
powershell -NoProfile -ExecutionPolicy Bypass -File .\homework-07\verify.ps1
```

最后应显示：

```text
PASS homework07: 2433 DOS input cases; all 2400 months checked against .NET; 4 call/return traces; 3 call categories verified.
```

2433 项包括全部 2400 个月、2 个前导零用例、26 个非法输入用例和 5 个 CRLF 文件用例。期望日期由 .NET DateTime 独立计算，逐字核对完整输出、空白布局和退出码。另对 1900/2、2000/2、2026/11、2099/12 验证三类 CALL/RET 的实际机器码、参数、返回地址、CS/IP/SP 和保存的寄存器。

脚本从 MAP 读取链接后的公共符号偏移，使用已生成的 EXE，不自动编译。默认工具是 DOSBox 0.74 与 FreeDOS DEBUG 2.50，可用 `-DosBoxPath`、`-DebugPath` 指定路径。`.verify` 是忽略的测试临时目录，正式记录在 `verification`。ExecutionPolicy Bypass 仅影响本次 PowerShell 进程。

修改源码后，应重新生成 EXE、MAP、LST，再验收。若在 `D:\ASM\HW07` 构建，先将更新的源文件与产物同步回仓库对应目录。手动调试偏移也需要按新 MAP 更新。

## 4. 观察调用与返回

在 DOSBox 的 HW07 目录：

```dos
path c:\
debug CALENDAR.EXE < TRACE.TXT
```

脚本将参数设为 2026/11，绕过键盘输入，演示三类调用。以下均为十六进制：

| 调用 | CALL 前 SP | 刚进入过程 SP | 返回后 SP | CS |
| --- | --- | --- | --- | --- |
| MAIN → DATE，跨文件 NEAR，两个参数已入栈 | 03FC | 03FA | 0400 | 不变；RET 4 还清理两个 word 参数 |
| MAIN → SCREEN，跨文件 FAR | 0400 | 03FC | 0400 | 切换，RETF 后恢复 |
| SCREEN 内 print_unsigned，NEAR | 03F0 | 03EE | 03F0 | 不变；普通 RET |

DEBUG 的寄存器输出会插入程序正在打印的标题中，例如 `2026AX=...`，这是单步观察时输出交错；正常运行月历的排版见第 1 节。

需要亲手逐条输入、理解栈内各字节，继续阅读 [实验报告](EXPERIMENT.md)。
