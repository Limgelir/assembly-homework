# 作业一 Hello world

本作业分别通过传统的汇编链接流程和 DEBUG 直接写内存的方式输出 `Hello world!`，并通过反汇编、单步执行理解机器码、内存地址与寄存器的关系。

## 提交文件

| 要求 | 文件 |
| --- | --- |
| 传统方式的源代码 | [traditional/HELLO.ASM](traditional/HELLO.ASM) |
| 传统方式的可执行文件 | [traditional/HELLO.EXE](traditional/HELLO.EXE) |
| 汇编时的代码与机器码对应列表 | [traditional/HELLO.LST](traditional/HELLO.LST) |
| DEBUG 反汇编及单步执行记录 | [verification/traditional-debug.txt](verification/traditional-debug.txt) |
| 直接写内存实验文档 | [direct-memory/README.md](direct-memory/README.md) |
| 直接写内存的完整命令 | [direct-memory/MEMHELLO.TXT](direct-memory/MEMHELLO.TXT) |
| 直接写内存的实际执行记录 | [verification/direct-memory-debug.txt](verification/direct-memory-debug.txt) |

## 实验环境

- DOSBox 0.74。
- Microsoft Macro Assembler 5.00。
- Microsoft Overlay Linker 3.60。
- FreeDOS Debug 2.50 的 `DEBUG.COM`。

先在 DOSBox 中挂载实验目录，并确保可以运行 `MASM`、`LINK` 和 `DEBUG`。源代码在 Windows 文本编辑器中编辑，汇编、链接和运行在 DOSBox 中完成。

## 传统方式

进入包含 `HELLO.ASM` 的目录，执行：

```dos
masm hello.asm,hello.obj,hello.lst;
link hello.obj;
hello
```

运行结果：

```text
Hello world!
```

程序使用 `.model small`，通过 `.data` 定义字符串，通过 `.code` 定义指令，通过 `.stack 100h` 保留 256 字节栈空间。

`MOV AX,@DATA` 与 `MOV DS,AX` 初始化数据段寄存器；`MOV DX,OFFSET Hello` 取得字符串的偏移地址。设置 `AH=09h` 后执行 `INT 21h`，DOS 从 `DS:DX` 读取并输出以 `$` 结束的字符串。末尾的 `0Dh,0Ah` 使输出回车换行。

最后设置 `AX=4C00h`，再执行 `INT 21h`，以返回码 0 结束程序。`END START` 是汇编器伪指令，用于结束源文件并指定入口，不承担运行时退出功能。

## 反汇编与单步执行

在 DOSBox 中输入：

```dos
debug hello.exe
```

在 DEBUG 的 `-` 提示符下输入以下命令，不需要输入提示符本身：

```text
u cs:0000 0010
r
t
t
t
t
```

`u` 将入口处的 17 字节机器码反汇编；四次 `t` 依次执行数据段初始化、字符串地址设置和输出功能号设置。

本次实测的寄存器变化如下，具体段值可能随运行环境变化：

| 指令 | 实测机器码 | 执行后的关键状态 |
| --- | --- | --- |
| `MOV AX,@DATA` | `B8 3F 07` | `AX=073F` |
| `MOV DS,AX` | `8E D8` | `DS=073F` |
| `MOV DX,OFFSET Hello` | `BA 02 00` | `DX=0002` |
| `MOV AH,09h` | `B4 09` | `AX=093F`，即 `AH=09` |
| `INT 21h` | `CD 21` | 输出字符串 |
| `MOV AX,4C00h` | `B8 00 4C` | `AX=4C00` |
| `INT 21h` | `CD 21` | 正常结束，返回码为 0 |

四次 `t` 后读取实际 DX 值。本次 DX 为 `0002`，因此继续输入：

```text
d ds:0002 0010
p
t
p
q
```

`d` 显示字符串字节；`p` 将中断调用作为整体执行；最后的 `q` 退出 DEBUG。执行记录见 [traditional-debug.txt](verification/traditional-debug.txt)。如果重新修改或链接程序后 DX 改变，查看字符串时应使用新的偏移值。

列表文件中的 `Hello` 是 `_DATA` 段内的偏移 `0000`；本次链接完成后，使用 DGROUP 段基址访问该字符串的偏移为 `0002`。运行时应以实际 `DS:DX` 为准。

## 验证结果

2026 年 10 月 21 日，在 DOSBox 0.74 中验证：

| 检查 | 结果 | 记录 |
| --- | --- | --- |
| 运行原有 EXE | 输出 `Hello world!` | [traditional-run.txt](verification/traditional-run.txt) |
| 重新汇编源代码 | 0 Warning Errors，0 Severe Errors | [assembler.txt](verification/assembler.txt) |
| 链接目标文件 | 成功，无错误信息 | [linker.txt](verification/linker.txt) |
| 运行重新生成的 EXE | 输出 `Hello world!` | [rebuilt-run.txt](verification/rebuilt-run.txt) |
| DEBUG 反汇编、单步执行 | 正常输出，返回码 0 | [traditional-debug.txt](verification/traditional-debug.txt) |
| DEBUG 直接写内存执行 | 正常输出，返回码 0 | [direct-memory-debug.txt](verification/direct-memory-debug.txt) |

提交的 `HELLO.EXE` 保留了原有成品。重新汇编链接生成的文件与它逐字节一致，两个文件的 SHA-256 均为：

```text
115d32cecede3ec0a999f7bde972da2f37e92494bb50692b0603a2683684b94e
```
