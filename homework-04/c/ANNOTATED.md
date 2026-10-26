# C 乘法表：真实反汇编及中文注释

本文件对已提交的 [NINE_C.EXE](NINE_C.EXE) 中 `print_cell` 和 `main` 的 **60 条指令**逐条注释，保留实际地址和机器码。完整原始输出见 [NINE_C.DISASM.txt](NINE_C.DISASM.txt)，源码见 [nine.c](nine.c)。

构建使用 MinGW GCC 6.3.0、GNU objdump 2.28，目标为 Windows 32 位 x86（mingw32）。选项包含 `-O0 -g -fno-omit-frame-pointer -fno-inline -fno-builtin-putchar`，保留过程调用和易读的栈变量访问。

## 先看与题目对应的位置

| 要求 | 本次反汇编 |
| --- | --- |
| 乘法运算 | 401492：`IMUL EAX,[EBP+0Ch]` |
| main 调用过程 | 40152F：`CALL 401489 <_print_cell>` |
| 过程返回 | 4014F1：`RET`，返回到 401534 |
| 外层 row=9 到 1 | 40154F 的 SUB、401554 的 CMP、401559 的 JNE |
| 内层 column=1 到 row | 401534 的 ADD、40153D 的 CMP、401541 的 JBE |
| 过程内复用栈和寄存器 | EBP 栈帧、EAX 运算、局部变量 product/spaces |

C 源码的参数是无符号整数，但编译器在这里选择了双操作数 IMUL，保留乘积低 32 位。对于本题 1～9 的正整数，这与无符号乘法的结果相同。DOS 汇编源码使用的是 8086 的 `MUL BL`，AL×BL 的结果放在 AX；不要把两种指令形式的操作数宽度混淆。

## 逐条注释

```asm
00401489 <_print_cell>:
  401489:	55                   	push   ebp ; 保存调用者 EBP。
  40148a:	89 e5                	mov    ebp,esp ; 建立 print_cell 的栈帧。
  40148c:	83 ec 28             	sub    esp,0x28 ; 分配局部变量和调用参数区，共 0x28 字节。
  40148f:	8b 45 08             	mov    eax,DWORD PTR [ebp+0x8] ; 读入参数 row，[EBP+8] 为第一个参数。
  401492:	0f af 45 0c          	imul   eax,DWORD PTR [ebp+0xc] ; EAX = row * column，第二个参数在 [EBP+0Ch]；保留乘积低 32 位。
  401496:	89 45 f0             	mov    DWORD PTR [ebp-0x10],eax ; 保存 product 到局部变量 [EBP-10h]。
  401499:	8b 45 f0             	mov    eax,DWORD PTR [ebp-0x10] ; 读出 product。
  40149c:	89 44 24 0c          	mov    DWORD PTR [esp+0xc],eax ; 为 printf 设置第四个参数 product。
  4014a0:	8b 45 0c             	mov    eax,DWORD PTR [ebp+0xc] ; 读取 column。
  4014a3:	89 44 24 08          	mov    DWORD PTR [esp+0x8],eax ; 设置 printf 第三个参数 column。
  4014a7:	8b 45 08             	mov    eax,DWORD PTR [ebp+0x8] ; 读取 row。
  4014aa:	89 44 24 04          	mov    DWORD PTR [esp+0x4],eax ; 设置 printf 第二个参数 row。
  4014ae:	c7 04 24 64 b0 40 00 	mov    DWORD PTR [esp],0x40b064 ; 设置 printf 第一个参数：格式字符串 %u*%u=%u。
  4014b5:	e8 a6 ff ff ff       	call   401460 <_printf> ; 调用 printf 输出一个算式。
  4014ba:	8b 45 0c             	mov    eax,DWORD PTR [ebp+0xc] ; 读取 column。
  4014bd:	3b 45 08             	cmp    eax,DWORD PTR [ebp+0x8] ; 比较 column 和 row。
  4014c0:	73 2d                	jae    4014ef <_print_cell+0x66> ; column >= row 时不填充空格，直接退出过程。
  4014c2:	83 7d f0 09          	cmp    DWORD PTR [ebp-0x10],0x9 ; 比较 product 和 9。
  4014c6:	77 07                	ja     4014cf <_print_cell+0x46> ; product > 9 时选择 3 个空格。
  4014c8:	b8 04 00 00 00       	mov    eax,0x4 ; 一位数乘积：spaces = 4。
  4014cd:	eb 05                	jmp    4014d4 <_print_cell+0x4b> ; 跳到保存 spaces 的共同位置。
  4014cf:	b8 03 00 00 00       	mov    eax,0x3 ; 两位数乘积：spaces = 3。
  4014d4:	89 45 f4             	mov    DWORD PTR [ebp-0xc],eax ; 保存 spaces 到 [EBP-0Ch]。
  4014d7:	eb 10                	jmp    4014e9 <_print_cell+0x60> ; 先检查 spaces 是否非零。
  4014d9:	c7 04 24 20 00 00 00 	mov    DWORD PTR [esp],0x20 ; 把字符空格 20h 放到参数区。
  4014e0:	e8 a3 7e 00 00       	call   409388 <_putchar> ; 调用 putchar 输出一个空格。
  4014e5:	83 6d f4 01          	sub    DWORD PTR [ebp-0xc],0x1 ; --spaces。
  4014e9:	83 7d f4 00          	cmp    DWORD PTR [ebp-0xc],0x0 ; 检查剩余 spaces。
  4014ed:	75 ea                	jne    4014d9 <_print_cell+0x50> ; 非零则继续打印空格。
  4014ef:	90                   	nop ; 空操作，对程序数据无影响。
  4014f0:	c9                   	leave ; LEAVE 恢复 ESP 和 EBP。
  4014f1:	c3                   	ret ; RET 取出返回地址，回到 main 中 CALL 的下一条指令。


004014f2 <_main>:
  4014f2:	55                   	push   ebp ; 保存调用者 EBP。
  4014f3:	89 e5                	mov    ebp,esp ; 建立 main 栈帧。
  4014f5:	83 e4 f0             	and    esp,0xfffffff0 ; 将 ESP 向下对齐到 16 字节。
  4014f8:	83 ec 20             	sub    esp,0x20 ; 为局部变量和参数区预留 0x20 字节。
  4014fb:	e8 a0 05 00 00       	call   401aa0 <___main> ; GCC 运行库初始化，不属于乘法表算法。
  401500:	c7 04 24 6d b0 40 00 	mov    DWORD PTR [esp],0x40b06d ; 为 puts 设置表头字符串地址。
  401507:	e8 74 7e 00 00       	call   409380 <_puts> ; 打印表头并换行。
  40150c:	c7 44 24 1c 09 00 00 	mov    DWORD PTR [esp+0x1c],0x9 ; row = 9，局部变量在 [ESP+1Ch]。
  401513:	00
  401514:	eb 3e                	jmp    401554 <_main+0x62> ; 跳到外层循环条件检查。
  401516:	c7 44 24 18 01 00 00 	mov    DWORD PTR [esp+0x18],0x1 ; 每行 column = 1，在 [ESP+18h]。
  40151d:	00
  40151e:	eb 19                	jmp    401539 <_main+0x47> ; 跳到内层循环条件检查。
  401520:	8b 44 24 18          	mov    eax,DWORD PTR [esp+0x18] ; 读取 column。
  401524:	89 44 24 04          	mov    DWORD PTR [esp+0x4],eax ; 设置 print_cell 的第二个参数 column。
  401528:	8b 44 24 1c          	mov    eax,DWORD PTR [esp+0x1c] ; 读取 row。
  40152c:	89 04 24             	mov    DWORD PTR [esp],eax ; 设置 print_cell 的第一个参数 row。
  40152f:	e8 55 ff ff ff       	call   401489 <_print_cell> ; 调用 print_cell(row,column)，压入返回地址 00401534h。
  401534:	83 44 24 18 01       	add    DWORD PTR [esp+0x18],0x1 ; 返回后 ++column。
  401539:	8b 44 24 18          	mov    eax,DWORD PTR [esp+0x18] ; 读取 column。
  40153d:	3b 44 24 1c          	cmp    eax,DWORD PTR [esp+0x1c] ; 比较 column 和 row。
  401541:	76 dd                	jbe    401520 <_main+0x2e> ; 无符号 column <= row 时继续内层循环。
  401543:	c7 04 24 0a 00 00 00 	mov    DWORD PTR [esp],0xa ; 设置换行字符 0Ah。
  40154a:	e8 39 7e 00 00       	call   409388 <_putchar> ; 调用 putchar 换行，Windows 文本输出转换为 CRLF。
  40154f:	83 6c 24 1c 01       	sub    DWORD PTR [esp+0x1c],0x1 ; --row。
  401554:	83 7c 24 1c 00       	cmp    DWORD PTR [esp+0x1c],0x0 ; 检查 row 是否为 0。
  401559:	75 bb                	jne    401516 <_main+0x24> ; row != 0 时进入下一行。
  40155b:	b8 00 00 00 00       	mov    eax,0x0 ; 设置 main 返回值 0。
  401560:	c9                   	leave ; 恢复栈帧。
  401561:	c3                   	ret ; 返回 C 运行库。
```

只有机器码、没有助记符的续行属于上一条较长指令。main 返回后的对齐填充未列入注释。

## 参数、局部变量和寄存器保存

`print_cell` 的栈布局：

| 位置 | 含义 |
| --- | --- |
| [EBP] | 保存的调用者 EBP |
| [EBP+4] | 返回地址 00401534h |
| [EBP+8] | 参数 row |
| [EBP+0Ch] | 参数 column |
| [EBP-10h] | product |
| [EBP-0Ch] | spaces |

主函数的 row、column 分别在 [ESP+1Ch]、[ESP+18h]，调用前将参数写入调用参数区。CALL 压入返回地址；被调用函数保存 EBP 并建立栈帧，退出时 LEAVE 恢复栈帧，RET 返回调用后的指令。

这个 C 程序遵循编译器的调用约定，EAX 等临时寄存器可以被被调用函数改变。汇编版则明确约定 `print_cell` 保持主程序的 AX、BX、CX、DX，入口 PUSH、出口逆序 POP；主程序因此能继续使用 BH/BL 和 CX 控制循环。不要认为 CALL/RET 会自动保存这些通用寄存器。

## 怎样复核

在 Windows 的本目录运行 `BUILD.BAT`，用文本编辑器打开生成的 NINE_C.DISASM.txt，搜索 `<_print_cell>:` 和 `<_main>:`，核对上面的乘法、CALL、RET、两层循环。

更改源码、编译器或选项后，地址和指令可能变化，应重新生成并同步注释。这个 C EXE 在 Windows 中运行，不能作为 16 位 DOS 程序放入 DOSBox 执行。
