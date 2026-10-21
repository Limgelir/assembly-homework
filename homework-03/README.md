# 作业三：求和

完成 1+2+…+100 并输出 5050，同时提供寄存器、数据段、栈三种存储实现、输入 n 的版本，以及 C 实现和真实 EXE 的反汇编注释。

## 提交内容

| 要求 | 源码 | 程序及材料 |
| --- | --- | --- |
| 结果存放在寄存器 | [SUM.ASM](asm/SUM.ASM) | [SUM.EXE](asm/SUM.EXE)，AX 累加 |
| 结果存放在数据段 | [SUMDATA.ASM](asm/SUMDATA.ASM) | [SUMDATA.EXE](asm/SUMDATA.EXE)，DS:total 累加 |
| 结果存放在栈中 | [SUMSTACK.ASM](asm/SUMSTACK.ASM) | [SUMSTACK.EXE](asm/SUMSTACK.EXE)，SS:BP 累加 |
| 输入 1～100，求 1+…+n | [SUMINPUT.ASM](asm/SUMINPUT.ASM) | [SUMINPUT.EXE](asm/SUMINPUT.EXE) |
| C 实现 | [sum.c](c/sum.c) | [SUM_C.EXE](c/SUM_C.EXE)，输入 n，n=100 时输出 5050 |
| C 反汇编及注释 | [完整原始反汇编](c/SUM_C.DISASM.txt) | [101 条指令的中文注释](c/ANNOTATED.md) |
| 自动验收 | [verify.ps1](verify.ps1) | [237 项运行结果](verification/RESULTS.TXT) |

四个汇编 EXE 在 DOSBox 中运行。C EXE 由 MinGW 编译为 Windows 32 位 x86 程序，在 Windows PowerShell 或命令提示符中运行。

## 第一步：检查四个 DOS 程序

本机已把 asm 目录同步到 `D:\ASM\HW03`。打开 DOSBox，逐行输入：

```dos
c:
cd \hw03
sum
sumdata
sumstack
```

每个程序均应独立显示一行：

```text
5050
```

随后输入：

```dos
suminput
```

提示出现后输入 `100` 并按 Enter，应该显示 `Sum:` 和下一行的 `5050`。继续重新运行 suminput，检查：

| 输入 n | 预期总和 |
| --- | --- |
| 1 | 1 |
| 2 | 3 |
| 10 | 55 |
| 50 | 1275 |
| 99 | 4950 |
| 100 | 5050 |
| 001 | 1 |
| 0、101、-1、abc，或直接 Enter | Error 提示，不计算 |

输入格式是 1～3 位十进制数字，数值必须为 1～100；不接受空格、正负号、小数点。正常返回 0，错误返回 1。每次只处理一行；重新输入请再次运行程序。

## 第二步：确认三种存储方式确实不同

在同一个 DOSBox 目录运行：

```dos
path c:\
debug SUM.EXE < REGDBG.TXT
debug SUMDATA.EXE < DATADBG.TXT
debug SUMSTACK.EXE < STACKDBG.TXT
```

脚本自动反汇编、运行到断点、显示寄存器或内存，最后继续执行并退出 DEBUG。应观察到：

| 版本 | 断点与观察点 | 预期 |
| --- | --- | --- |
| SUM | CS:000Dh，打印前 | AX=13BA，BX=0065，CX=0000 |
| SUMDATA | CS:0018h，读取 total 前 | `d ds:0 l 2` 显示 BA 13；再执行 T，AX=13BA |
| SUMSTACK | CS:0012h，读取局部变量前 | SP=BP=00FC；`d ss:fc l 2` 显示 BA 13 |
| SUMSTACK | 再执行三次 T 后，CS:0019h | AX=13BA，SP=0100，BP 恢复为原值 |

13BAh=5050。8086 按小端序存储，低地址字节 BA、高地址字节 13。段寄存器的具体数值随加载位置变化，不需要与日志完全相同；偏移与当前提交的 EXE 对应。

**关键区别：** SUM 每次执行 `ADD AX,BX`；SUMDATA 每次执行 `ADD total,BX`；SUMSTACK 每次执行 `ADD WORD PTR [BP],BX`。数据段版和栈版均在对应内存位置直接累加，最后才读入 AX 用于显示。

如修改源码并重新编译，请根据新 LST/DEBUG 反汇编调整脚本断点，不能照抄旧地址。本次实际记录：[寄存器](verification/register-debug.txt)、[数据段](verification/data-debug.txt)、[栈与 SP 恢复](verification/stack-debug.txt)。

## 第三步：运行 C 并检查反汇编

在 Windows PowerShell 进入仓库根目录：

```powershell
.\homework-03\c\SUM_C.EXE
```

输入 `100` 得 5050，输入 `10` 得 55；非法输入同样拒绝。然后阅读 [反汇编注释](c/ANNOTATED.md)：

1. 在原始反汇编中搜索 `<_sum_to>:`，确认累加用 ADD，循环比较用 CMP/JBE。
2. 看 `[EBP-4]` 的 total、`[EBP-8]` 的 i、`[EBP+8]` 的参数 n。
3. 找 main 中 `CALL ... <_sum_to>`，确认返回值 EAX 交给 printf 显示。
4. 注意 C 的 EAX/EBP 为 32 位，DOS 汇编的 AX/BP 为 16 位。

注释保留实际机器码和地址，没有把手写汇编冒充 C 编译结果。

## 第四步：一键完整验收

在 Windows PowerShell 的仓库根目录执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\homework-03\verify.ps1
```

预期：

```text
PASS homework03: 120 DOS cases, 117 C cases; exact output and exit codes verified.
```

包括 3 个固定求和版本，以及输入版 ASM/C 各 117 项：1～100 全部有效输入、3 项前导零输入、14 项非法输入。测试按 n(n+1)/2 计算期望值，逐项比较完整输出和退出码。汇编和 C 中均使用循环求和，验收脚本采用公式作为独立参照。

脚本实际运行提交的 EXE，不会重新编译；修改源码后应先构建，再验收。详细记录在 `.verify`，脚本依赖仓库的 [tools/verify-programs.ps1](../tools/verify-programs.ps1)。指定其他 DOSBox 路径时，加参数 `-DosBoxPath '实际路径'`。进程内的 ExecutionPolicy Bypass 不会修改系统策略。

## 构建方法

汇编源文件采用 ASCII 编码、CRLF 换行，使用 8086 指令。在 DOSBox 的 HW03 目录：

```dos
path c:\
build
```

BUILD.BAT 依次汇编、链接四个程序并生成 EXE 和 LST。例如手工构建寄存器版：

```dos
masm SUM.ASM,SUM.OBJ,SUM.LST;
link SUM.OBJ;
```

四份 LST 均记录 0 Warning Errors、0 Severe Errors。不要将 MASM、LINK、DEBUG 的工具文件作为作业源码提交。

C 使用已安装的 MinGW GCC 6.3.0 / GNU objdump 2.28。在 Windows 的 c 目录运行 `BUILD.BAT`，生成 SUM_C.EXE 与 SUM_C.DISASM.txt；选项含 `-Wall -Wextra -Werror -O0 -g -fno-omit-frame-pointer -fno-inline`。改变编译结果后同步更新反汇编注释。

## 需要理解的知识点

**数值范围。** 最大总和为 100×101÷2=5050=13BAh，超过 8 位无符号数的上限 255，必须使用至少 16 位。此作业用 AX、DW、栈中的一个 word，16 位无符号范围 0～65535 足够。

**累加循环。** AX 或内存中的总和初始为 0，BX 从 1 开始，CX 保存次数。每轮累加 BX，再 INC BX，最后 LOOP。输入版先拒绝 n=0，再把 n 放到 CX；否则 LOOP 在 CX=0 时减成 FFFFh，会造成错误的循环次数。

**栈上局部变量。** 先 PUSH BP 保存旧 BP，再 PUSH AX（AX=0）分配并清零一个 word，MOV BP,SP 后通过 [BP] 访问它。8086 的 BP 寻址默认使用 SS。输出前读出总和，ADD SP,2 释放局部 word，再 POP BP 恢复旧值，保证 SP 回到 0100h。十进制打印子程序的 PUSH/POP 也成对执行。

**数值和显示字符。** AX 中的 13BAh 是一个数，不是字符 '5'、'0'、'5'、'0'。print_dec 重复除以 10，将余数压栈，逆序出栈并加 '0'，通过 INT 21h/AH=02h 打印。DIV 的被除数是 DX:AX，因此每次除法前 XOR DX,DX。传给字符串输出的 AH=09h 会改变 AX，puts 子程序用 PUSH AX / POP AX 保护总和。

**输入服务。** 使用 INT 21h/AH=0Ah，DS:DX 指向 `db 64,0,64 dup(0)`：容量字节包含回车空间，返回长度不包含回车，字符从第三字节开始。先校验长度与字符，再计算 value×10+digit，最后检查 1～100。支持退格编辑和 Enter 提交。

DOS 输入接口依据：[Microsoft《MS-DOS 3.3 Programmer's Reference》Buffered Keyboard Input](https://www.pcjs.org/documents/books/mspl13/msdos/dosref33/)（PCjs 保存的原版文档）。

## 实测记录

2026-10-21 在 DOSBox 0.74 和 Windows 中完成测试，完整命令使用 Windows PowerShell 5.1 复验成功。

- [237 项测试结果](verification/RESULTS.TXT)
- [固定求和输出](verification/sum.txt)
- [输入 100 的 DOS 输出](verification/input-100.txt)
- [输入 100 的 C 输出](verification/c-100.txt)
- [输入 0 被拒绝](verification/input-invalid.txt)
- [汇编构建日志](verification/build.txt)
- [C 工具链](verification/c-toolchain.txt)
- [源文件和 EXE 的 SHA-256](verification/SHA256SUMS.txt)
