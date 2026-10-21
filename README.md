# Assembly Homework

x86 汇编语言课程作业，汇编部分使用 DOSBox 0.74、MASM 5.00、LINK 3.60 和 DOS DEBUG，C 语言对照实验使用 MinGW GCC。

| 作业 | 内容 | 提交材料 |
| --- | --- | --- |
| [作业一 Hello world](homework-01/README.md) | 传统汇编链接、DEBUG 反汇编与单步执行、直接写内存执行 | ASM 源代码、DOS EXE、实验文档和实际运行记录 |
| [作业二 ASCII 小写字母表](homework-02/README.md) | LOOP、条件跳转、C 实现；每行 13 个字母；C 反汇编注释 | 三份源码与 EXE、反汇编、实验说明和自动验收脚本 |

作业按 `homework-01`、`homework-02` 等目录组织。当前包含作业一和作业二。

汇编程序为 16 位 DOS 程序，在 DOSBox 等兼容环境中运行；作业二的 C 程序为 Windows 32 位 x86 程序，在 Windows 中运行。各作业目录包含对应的构建、运行和验收说明。
