# Assembly Homework

x86 汇编语言课程作业，汇编部分使用 DOSBox 0.74、MASM 5.00、LINK 3.60 和 DOS DEBUG，C 语言对照实验使用 MinGW GCC。

| 作业 | 内容 | 提交材料 |
| --- | --- | --- |
| [作业一 Hello world](homework-01/README.md) | 传统汇编链接、DEBUG 反汇编与单步执行、直接写内存执行 | ASM 源代码、DOS EXE、实验文档和实际运行记录 |
| [作业二 ASCII 小写字母表](homework-02/README.md) | LOOP、条件跳转、C 实现；每行 13 个字母；C 反汇编注释 | 三份源码与 EXE、反汇编、实验说明和自动验收脚本 |
| [课堂练习 进制转换](class-exercise/README.md) | 1～2 位十六进制转十进制；十进制转十六进制 | 两份 ASM / DOS EXE、LST、333 项验收记录 |
| [作业三 求和](homework-03/README.md) | 1+…+100；寄存器 / 数据段 / 栈；输入 1～100；C 反汇编注释 | 四份 ASM / DOS EXE、C 源码 / EXE、DEBUG 观察、237 项验收记录 |
| [作业四 九九乘法表](homework-04/README.md) | MUL、CALL/RET、寄存器保存恢复、双循环、C 反汇编注释 | ASM / DOS EXE、C 源码 / EXE、60 条指令注释、45 次过程调用验收 |

作业按 `homework-01` 至 `homework-04` 目录组织，课堂进制转换练习在 `class-exercise` 目录。

汇编程序为 16 位 DOS 程序，在 DOSBox 等兼容环境中运行；C 程序为 Windows 32 位 x86 程序，在 Windows 中运行。各作业目录包含对应的构建、运行和验收说明。进制转换和作业三的验收脚本依赖 `tools/verify-programs.ps1`，请保留完整仓库目录结构。
