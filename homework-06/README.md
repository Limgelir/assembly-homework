# 作业六：输出月历、传参和跨代码段调用

从键盘输入年份（1900～2099）和月份（1～12），输出以星期日为第一列的公历月历。汇编程序使用 8086 指令、两个独立代码段，并实际使用寄存器、栈和数据段三种传参方式。

## 提交材料

| 内容 | 文件 |
| --- | --- |
| 汇编源码、DOS 程序、汇编清单 | [CALENDAR.ASM](asm/CALENDAR.ASM)、[CALENDAR.EXE](asm/CALENDAR.EXE)、[CALENDAR.LST](asm/CALENDAR.LST) |
| 调用跟踪命令 | [TRACE.TXT](asm/TRACE.TXT) |
| C 源码、Windows 程序 | [calendar.c](c/calendar.c)、[CAL_C.EXE](c/CAL_C.EXE) |
| 实际 C 反汇编及中文注释 | [完整反汇编](c/CAL_C.DISASM.txt)、[ANNOTATED.md](c/ANNOTATED.md) |
| 自动验收及运行记录 | [verify.ps1](verify.ps1)、[RESULTS.TXT](verification/RESULTS.TXT)、[DEBUG 跟踪](verification/trace-202611.txt) |

## 1. 运行和验收

### DOSBox 运行汇编版

本机已把 asm 目录同步到 `D:\ASM\HW06`，DOSBox 将 `D:\ASM` 挂载为 C 盘。打开 DOSBox，输入：

```dos
c:
cd \hw06
calendar
```

先输入 `2026`，按 Enter；再输入 `11`，按 Enter。应显示：

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

每次运行打印一个月，打印后回到 DOS 提示符。要换日期，重新执行 `calendar`。

| 年份 / 月份 | 要检查的结果 |
| --- | --- |
| 2026 / 11 | 1 日星期日，30 天，与题目示例一致 |
| 1900 / 2 | 1 日星期四，只有 28 天（整百年不一定是闰年） |
| 2000 / 2 | 1 日星期二，有 29 日（400 的倍数是闰年） |
| 2026 / 8 | 1 日星期六，31 天需要占 6 行 |
| 2099 / 12 | 1 日星期二，31 日星期四 |
| 1899 或 2100 | 年份错误提示，退出码 1 |
| 2026 / 0 或 2026 / 13 | 月份错误提示，退出码 1 |
| 直接 Enter、字母、正负号、小数点、空格 | 错误提示，不输出月历 |

年份是 4 位十进制数字，月份为 1～2 位数字；允许 `01`、`02` 这样的月份。输入不合法时退出，重新运行即可重输。

### Windows 运行 C 版

在 PowerShell 中：

```powershell
Set-Location 'D:\Limgelir\Files\汇编语言\assembly-homework'
.\homework-06\c\CAL_C.EXE
```

按同样顺序输入年份、月份。C EXE 是 Windows 32 位程序；汇编 EXE 是 DOS 16 位程序。

### 一键完整验收

在上述仓库目录执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\homework-06\verify.ps1
```

预期最后结论：

```text
PASS homework06: 2433 DOS + 2433 C input cases; all 2400 months checked against .NET; 4 DEBUG traces.
```

测试逐字比较日历完整布局、月份名称、日期、空格、换行和退出码。期望值通过 .NET 的 `DateTime.DayOfWeek` 和 `DateTime.DaysInMonth` 独立取得，覆盖全部 2400 个月，以及前导零、非法字符、空输入、越界和 CRLF 文件输入。4 组 DEBUG 跟踪另外检查参数、CS 切换、返回地址、寄存器和 SP 恢复。

脚本运行可能需要几分钟，期间不必操作隐藏的 DOSBox。详细输出位于被 Git 忽略的 `.verify` 目录；提交的验收结果在 `verification`。默认工具路径可用 `-DosBoxPath`、`-DebugPath` 覆盖。`-SkipC` 仅检查 DOS 部分，不能代替完整验收。脚本验证已有 EXE，修改源码后应先重新构建；调试偏移也需与新的 LST 核对。

## 2. 月历计算方法

闰年条件为：能被 4 整除，且不能被 100 整除；或者能被 400 整除。二月据此取 28 或 29 天，其他月份查数据段的 12 字节表。

设 `y = year - 1`，以星期日为 0，星期一为 1，计算当年 1 月 1 日的星期：

```text
(y + y/4 - y/100 + y/400 + 1) % 7
```

其中 `/` 是整数除法。此前完整年份有 `365*y` 个普通日和 `y/4-y/100+y/400` 个闰日；`365 % 7 = 1`，所以可把 `365*y` 换为 `y`，避免 16 位中间结果溢出。再累加本年前面各月的天数，最后取模 7，得到本月 1 日星期。当前范围内中间和小于 3000，16 位无符号整数足够。

打印时先输出 `first_day` 个空格槽（每槽 3 字符），然后输出 1～月末。每个日期右对齐占 2 字符，列间 1 个空格；到第 7 列或最后一天换行。

## 3. 三种传参方式与过程约定

| 方式 | 程序中的实际例子 | 优点 | 代价 / 注意事项 |
| --- | --- | --- | --- |
| 寄存器 | `days_in_month`：AX=年份、BX=月份，AX 返回天数；`leap_year`：AX 传入和返回 | 指令少，直接运算 | 寄存器数量有限；明确返回值和保存约定 |
| 栈 | 主程序先 PUSH 月份，再 PUSH 年份，CALL `first_weekday`，AX 返回星期 | 参数与调用层绑定，便于嵌套和递归 | 需正确定位 BP 偏移；本例由被调用方 `RET 4` 清理参数 |
| 数据段 | `render_calendar` 读取 `selected_year`、`selected_month`、`first_day`、`month_length` | 大量共享参数易访问，跨代码段也可共用 DS | 依赖 DS 和共享状态，不便重入；调用前必须准备好数据 |

`read_number` 用 CL 传最大位数，AX 返回数值、CF 返回成功/失败；使用 DOS `INT 21h / AH=0Ah` 读取一行，再逐位做 `value*10+digit`。它保存 BX/CX/DX/SI/DI。日期计算过程保留除返回值 AX 以外所使用的寄存器，显示过程保存 AX/BX/CX/DX/SI/DI。

`ASSUME` 只给汇编器提供段关系，不会在 CPU 中设置寄存器。因此入口明确执行 `mov ax,data / mov ds,ax`。SS:SP 由 DOS 根据 EXE 头初始化，独立栈段分配 1024 字节，初始 SP=0400h。

`first_weekday` 执行 `push bp / mov bp,sp` 后：

```text
SS:[BP+6]  月份
SS:[BP+4]  年份
SS:[BP+2]  返回 IP
SS:[BP]    调用者 BP
SS:[BP-2]  保存的 BX
...        保存的 CX、DX、SI、DI
```

BP 寻址默认使用 SS。退出前先反向 POP 恢复寄存器和 BP，再 `RET 4`：先弹出返回 IP，再令 SP 加 4 跳过两个 word 参数，调用者不能重复清理。

## 4. 两个代码段、远调用与短跳转限制

源码显式定义不同名称的 `CORE` 和 `SCREEN` 两个代码段。计算和输入位于 CORE；月历显示和输出辅助过程位于 SCREEN。跨段调用写 `call far ptr render_calendar`，显示过程以 `RETF` 返回。跨段字符串输出、换行也使用 FAR 调用和 FAR 返回；同段内数字打印过程使用 NEAR 调用和普通 RET。

FAR CALL 把原 CS、返回 IP 压栈，然后加载目标 CS:IP；此时栈顶是返回 IP，其上一个 word 是原 CS。RETF 按 IP、CS 顺序弹出。仅使用普通 RET 会少弹一个 word，且不能恢复原 CS。

本次 DEBUG 中 CORE=0796h、SCREEN=07B0h，实际加载段值随环境变化，应看自己屏幕上的 CS，不能照抄段值。下面偏移和字节来自提交的 EXE；`verification/trace-202611.txt` 保留原始记录。

| 位置 / 字节 | 意义 |
| --- | --- |
| CORE:0013 `73 03` | JNC / JAE 跳到 0018，位移 3，相对于下一条指令 0015 |
| CORE:0015 `E9 5F 01` | NEAR JMP 到 0177；下一 IP=0018，0018+015F=0177，超过短跳转范围 |
| CORE:00C8 `EB 01` | SHORT JMP 到 00CB；下一 IP=00CA，00CA+1=00CB |
| CORE:0066 `E8 B6 00` | NEAR CALL 到 011F；下一 IP=0069，0069+00B6=011F，只压入返回 IP |
| CORE:0174 `C2 04 00` | RET 4，弹出返回 IP 并清理 4 字节参数 |
| CORE:006C `9A 00 00 B0 07` | FAR CALL 到 07B0:0000，5 字节：操作码、offset16、segment16（小端） |
| SCREEN:0080 `CB` | RETF，恢复 IP 和 CS |

区别是：SHORT 是段内 rel8 相对跳转，位移 -128～127；NEAR 是段内转移，不改变 CS，在本 16 位程序中用 rel16 的 E9 / E8 编码；FAR 是段间转移，更改 CS 和 IP。这里 NEAR 指段内，不能用它调用另一个代码段。

8086 的条件跳转只有 rel8。要到达较远的同段目标，本程序使用“相反条件短跳转 + NEAR JMP”：

```asm
    call read_number
    jnc short year_parsed       ; CF=0 时跳过下面的 JMP
    jmp near ptr bad_year       ; CF=1 时走长距离的段内跳转
year_parsed:
```

如果目标在另一个代码段，同样可先反向短跳过一个 FAR JMP，或按业务组织为 FAR CALL/RETF。不能把 80386 之后的近条件跳转当成 8086 指令。位移从**下一条指令的 IP**计算，而不是从当前指令首地址计算。FAR 立即数直接含 offset 和 segment，其中 segment 由 DOS 加载器按 EXE 重定位项修正，不是相对距离。

## 5. 亲自单步验收

在 DOSBox 的 HW06 目录，先让 DEBUG 能从 C 盘根目录找到：

```dos
path c:\
debug CALENDAR.EXE < TRACE.TXT
```

自动脚本设置 2026/11，绕过输入部分进入计算；完整验证输入由常规运行和自动测试完成。也可以手动执行：

```text
debug CALENDAR.EXE
g 5
u 0 51
g =51 66
d ss:3fc l 4
t
g 127
d ss:3f8 l 8
g 174
t
g 6c
d ds:0 l 8
t
d ss:3fc l 4
g 80
t
g
q
```

关键观察点（所有偏移、SP 和数据均为十六进制）：

| 断点 / 操作后 | 预期现象 |
| --- | --- |
| `g 5` | DS 已初始化；SP=0400 |
| `g =51 66` | 两个参数已压栈，SP=03FC；内存 `EA 07 0B 00` 表示年份 07EAh=2026、月份 000Bh=11 |
| 第一次 `t` | 执行 NEAR CALL，IP=011F、SP=03FA、CS 不变 |
| `g 127` | BP=03F8、SP=03EE；栈内含旧 BP、返回 IP=0069、年份、月份 |
| `g 174` | 即将 RET 4；AX=0（星期日），SP=03FA |
| 第二次 `t` | IP=0069、SP=0400，参数也被清理 |
| `g 6c` | 数据段前 8 字节为 `EA 07 0B 00 00 00 1E 00`，即年份、月份、星期、天数 |
| 第三次 `t` | 执行 FAR CALL，CS 改变、IP=0000、SP=03FC |
| `d ss:3fc l 4` | 前两个字节 `71 00` 是返回 IP=0071，后两个字节是原 CORE 的 CS |
| `g 80` | 月历已打印；停在 SCREEN:0080 的 RETF，SP=03FC |
| 第四次 `t` | CS 恢复为 CORE、IP=0071、SP=0400；显示过程使用的寄存器全部恢复 |
| `g`、`q` | 正常退出程序，退出 DEBUG |

修改源码后偏移可能改变；先用新 LST 和 DEBUG `u` 找到对应标签，不应盲用旧偏移。

## 6. 重新构建

DOSBox 中（MASM.EXE、LINK.EXE 在 C 盘根目录）：

```dos
c:
cd \hw06
path c:\
build
calendar
```

MASM 5.00 汇编、LINK 3.60 链接；本次为 0 Warning Errors、0 Severe Errors。若在仓库外重新构建，需把更新后的 ASM、EXE、LST 同步回仓库，再验收。

Windows 已安装 MinGW GCC 6.3.0 / GNU objdump 2.28，在仓库根目录的 PowerShell 中：

```powershell
Push-Location .\homework-06\c
cmd /c BUILD.BAT
Pop-Location
```

使用 `-std=c99 -Wall -Wextra -Werror -O0 -g -fno-omit-frame-pointer -fno-inline`，保留可读函数边界。完整反汇编由实际 CAL_C.EXE 生成，中文注释分析其中的真实指令；Windows 平坦内存模型下 C 的普通函数调用不展示 DOS 的跨代码段 CS 切换，该部分由汇编版和 DEBUG 实测完成。

`verification/SHA256SUMS.txt` 保存本次提交材料的 SHA-256。原始 DOS 重定向日志含键盘回显以及 CR/CRLF，文本查看器可能显示多余空行；交互运行时不会把用户输入重复输出，验收脚本按实际字节核对。
