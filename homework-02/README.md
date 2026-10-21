# 作业二 打印 ASCII 小写字母表

按题目要求提供三种实现：使用 `LOOP` 指令、使用条件跳转指令、使用 C 语言并对实际 EXE 的反汇编添加注释。三份程序均输出以下两行，每行 13 个字母，字母之间用一个空格分隔：

```text
a b c d e f g h i j k l m
n o p q r s t u v w x y z
```

每行没有首尾空格，行尾使用 CRLF。两行共 26 个字母、24 个分隔空格和 4 个换行字节，输出总长为 54 字节。

## 提交内容

| 要求 | 源代码 | 可执行程序或说明 |
| --- | --- | --- |
| 使用 LOOP | [ASCIILP.ASM](asm/ASCIILP.ASM) | [ASCIILP.EXE](asm/ASCIILP.EXE) |
| 使用条件跳转 | [ASCIIJMP.ASM](asm/ASCIIJMP.ASM) | [ASCIIJMP.EXE](asm/ASCIIJMP.EXE) |
| 使用 C 语言 | [ascii.c](c/ascii.c) | [ASCII_C.EXE](c/ASCII_C.EXE) |
| C 程序反汇编及注释 | [原始完整反汇编](c/ASCII_C.DISASM.txt) | [main 函数逐条中文注释](c/MAIN.ANNOTATED.md) |
| 自动验收 | [verify.ps1](verify.ps1) | [验收结果](verification/RESULTS.TXT) |

两份汇编 EXE 为 16 位 DOS 程序，使用 DOSBox 运行；C EXE 为 MinGW 编译的 Windows 32 位 x86 程序，在 Windows 终端中运行。

## LOOP 方式

BL 从 `'a'` 开始，每打印一个字母后递增。外层 CX 为 2，表示两行；内层 CX 为 13，表示当前行的 13 个字母。

每行开始先执行 `PUSH CX`，保存外层剩余行数，然后将 CX 改为 13。内层用 `LOOP column_gap` 减少 CX 并判断是否还需要打印下一列；仍有下一列时输出一个空格，再跳回打印字母的位置。最后一列之后直接换行，因此不留下行尾空格。

内层结束时 CX 已为 0。换行后执行 `POP CX` 恢复外层计数，再通过 `LOOP row_loop` 减少剩余行数并决定是否输出下一行。

| 时刻 | CX |
| --- | --- |
| 第一行开始，保存前 | 2 |
| 设置内层计数后 | 13，即 `000Dh` |
| 第一行内层结束 | 0 |
| 执行 POP CX 后 | 2 |
| 执行外层 LOOP 后 | 1 |
| 第二行内层结束并恢复外层计数 | 1 |
| 最后一次外层 LOOP 后 | 0，退出 |

`LOOP` 在当前 16 位程序中使用 CX，先减 1 再判断是否为 0，不修改标志寄存器。如果没有保存、恢复外层 CX，内层结束后的 0 会被外层 `LOOP` 减成 `FFFFh`，导致错误的循环次数。

打印字符的 `put_char` 子程序设置 `AH=02h` 并调用 `INT 21h`，字符通过 DL 传入。程序的字母保存在 BL 中，输出空格或 CRLF 时只修改 DL，因此不会丢失下一个字母。

## 条件跳转方式

整体输出逻辑与 LOOP 版一致，内层和外层循环均改用：

```asm
dec cx
jnz target
```

`DEC CX` 更新 ZF 等状态，`JNZ` 在 `ZF=0` 时继续循环。因此 `DEC` 与对应的 `JNZ` 之间不插入会覆盖这些标志的指令。

这与本例中 `LOOP` 的循环次数相同，但对标志寄存器的影响不同：`LOOP` 不修改标志，`DEC` 会修改 ZF、SF、OF、AF、PF，保留 CF。条件跳转版没有使用 `LOOP` 指令。

## 构建

### 两份汇编程序

工具版本为 DOSBox 0.74、MASM 5.00、LINK 3.60。源文件使用 ASCII 编码、CRLF 换行。

把 `asm` 目录中的文件放入 DOSBox 可访问的目录，确保 `MASM.EXE`、`LINK.EXE` 在当前目录或 PATH 中，然后运行：

```dos
build
```

也可以逐条执行：

```dos
masm ASCIILP.ASM,ASCIILP.OBJ,ASCIILP.LST;
link ASCIILP.OBJ;
masm ASCIIJMP.ASM,ASCIIJMP.OBJ,ASCIIJMP.LST;
link ASCIIJMP.OBJ;
```

[ASCIILP.LST](asm/ASCIILP.LST) 和 [ASCIIJMP.LST](asm/ASCIIJMP.LST) 均记录了 0 Warning Errors、0 Severe Errors，并展示源码与机器码的对应关系。

### C 程序

使用 MinGW GCC 6.3.0 与 GNU objdump 2.28。确认它们位于 Windows 的 PATH 后，在 `c` 目录运行 `BUILD.BAT`，会生成 `ASCII_C.EXE` 和 `ASCII_C.DISASM.txt`。源码按 C99 编译，启用 `-Wall -Wextra -Werror`，使用 `-O0` 便于观察循环与局部变量。

编译器环境记录见 [c-toolchain.txt](verification/c-toolchain.txt)。更换编译器、编译参数或源码后，地址和指令布局可能改变，应重新生成反汇编并同步注释。

## 验收

### 检查运行结果

在 DOSBox 中进入保存两份 DOS EXE 的目录，分别输入：

```dos
asciilp
asciijmp
```

在 Windows PowerShell 中进入本作业目录，输入：

```powershell
.\c\ASCII_C.EXE
```

三份结果应与文档开头完全相同：第一行 a 到 m，第二行 n 到 z，每行 13 个字母，无重复、遗漏或额外字母。

### 检查指令与 CX 保存恢复

在 DOSBox 中输入：

```dos
debug ASCIILP.EXE < LOOPDBG.TXT
debug ASCIIJMP.EXE < JUMPDBG.TXT
```

[LOOPDBG.TXT](asm/LOOPDBG.TXT) 会在外层 CX 保存后以及恢复前设置断点，观察 CX 从 2 变为 13、内层结束时变为 0、POP 恢复为 2、外层 LOOP 减为 1 的过程，并执行完程序。

FreeDOS DEBUG 在本次记录中将 `LOOP` 显示为 `LOOPW`，表示使用 16 位 CX 的循环形式。

[JUMPDBG.TXT](asm/JUMPDBG.TXT) 会反汇编条件跳转版并执行，可以确认循环控制由 `DEC CX`、`JNZ` 完成。DEBUG 可能将 `JNZ` 显示为同义助记符 `JNE`。

两个脚本中的地址与本次提交的 MASM 5.00 构建对应，修改代码后应根据新的反汇编调整断点。

### 自动验收

在 Windows PowerShell 中进入本作业目录，执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verify.ps1
```

`-ExecutionPolicy Bypass` 仅作用于这次 PowerShell 进程，用于运行仓库中的验收脚本，不会修改系统的执行策略。也可以在已允许运行本地脚本的终端中直接执行 `.\verify.ps1`。

如果 DOSBox 安装位置不同，传入实际路径：

```powershell
.\verify.ps1 -DosBoxPath 'D:\DOSBox\DOSBox.exe'
```

脚本在 `.verify` 中运行两份 DOS EXE 和 C EXE，比较完整输出、返回状态和字节长度。成功时显示四行 `PASS`，失败时抛出错误并保留输出供检查。

## 实测记录

2026 年 10 月 21 日完成构建和运行验证。三份程序均正常结束，输出全部符合要求，54 字节的结果完全一致。

- [LOOP 版输出](verification/loop.txt)
- [条件跳转版输出](verification/jump.txt)
- [C 版输出](verification/c.txt)
- [自动验收结果](verification/RESULTS.TXT)
- [LOOP 版反汇编和 CX 观察](verification/loop-debug.txt)
- [条件跳转版反汇编及运行](verification/jump-debug.txt)
