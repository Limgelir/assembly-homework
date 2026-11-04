# 纠错 C 程序：全局数组、局部数组及实际反汇编

本文件逐条注释 **103 条实际指令**，分别取自本次 MinGW GCC 6.3.0 的 GLOBAL.EXE、LOCAL.EXE。编译使用 -O0、-g、-fno-inline、-fno-omit-frame-pointer。完整原始反汇编与符号表均保存在本目录。

两个 main 使用完全相同的 81 字节初值，并调用同一个 [scan.c](scan.c) 中的 check_table。这样对比的区别集中在数组的存储位置和初始化过程。

## 全局数组：GLOBAL.EXE

[global.c](global.c) 在函数外定义 table，具有静态存储期。符号表 [GLOBAL.SYMBOLS.txt](GLOBAL.SYMBOLS.txt) 显示 _table 位于第 2 节 .data，节内偏移 20h；.data 基址 0040A000h，因此数组地址为 0040A020h。main 直接传递该地址，无需在每次进入 main 时构造栈上副本。

```asm
00401460 <_main>:
  401460:	55                   	push   ebp ; 保存 EBP。
  401461:	89 e5                	mov    ebp,esp ; 建立栈帧。
  401463:	83 e4 f0             	and    esp,0xfffffff0 ; 按 16 字节对齐 ESP。
  401466:	83 ec 10             	sub    esp,0x10 ; 分配 16 字节调用参数区；数组本体不在此栈帧。
  401469:	e8 22 06 00 00       	call   401a90 <___main> ; 运行库初始化。
  40146e:	c7 04 24 20 a0 40 00 	mov    DWORD PTR [esp],0x40a020 ; 直接把全局 table 的地址 0040A020h 作为参数。
  401475:	e8 56 00 00 00       	call   4014d0 <_check_table> ; 调用公共检查过程。
  40147a:	b8 00 00 00 00       	mov    eax,0x0 ; 成功返回 0。
  40147f:	c9                   	leave ; 恢复栈帧。
  401480:	c3                   	ret ; 返回。
```

## 局部数组：LOCAL.EXE

[local.c](local.c) 在 main 内定义自动局部数组。本次构建将其放在 ESP+1Fh 开始的 81 字节空间，并生成初始化复制代码。初始化模板也出现在可执行文件的数据节中，但真正交给 check_table 的是栈地址，不能把模板误认为局部数组本体。

```asm
00401460 <_main>:
  401460:	55                   	push   ebp ; 保存 EBP。
  401461:	89 e5                	mov    ebp,esp ; 建立栈帧。
  401463:	57                   	push   edi ; 保存 EDI。
  401464:	56                   	push   esi ; 保存 ESI。
  401465:	53                   	push   ebx ; 保存 EBX。
  401466:	83 e4 f0             	and    esp,0xfffffff0 ; 对齐 ESP。
  401469:	83 ec 70             	sub    esp,0x70 ; 分配 112 字节，包含局部数组和调用参数区。
  40146c:	e8 5f 06 00 00       	call   401ad0 <___main> ; 运行库初始化。
  401471:	8d 44 24 1f          	lea    eax,[esp+0x1f] ; EAX = 栈上局部 table 的起始地址 ESP+1Fh。
  401475:	bb 20 a0 40 00       	mov    ebx,0x40a020 ; EBX = 编译器生成的初始化模板地址；它不是局部数组本体。
  40147a:	ba 51 00 00 00       	mov    edx,0x51 ; 要初始化的长度 51h = 81 字节。
  40147f:	8b 0b                	mov    ecx,DWORD PTR [ebx] ; 读模板开头四字节。
  401481:	89 08                	mov    DWORD PTR [eax],ecx ; 写局部数组开头四字节。
  401483:	8b 4c 13 fc          	mov    ecx,DWORD PTR [ebx+edx*1-0x4] ; 读模板最后四字节。
  401487:	89 4c 10 fc          	mov    DWORD PTR [eax+edx*1-0x4],ecx ; 写局部数组最后四字节。
  40148b:	8d 78 04             	lea    edi,[eax+0x4] ; 准备中间部分的目标地址。
  40148e:	83 e7 fc             	and    edi,0xfffffffc ; 向下按四字节对齐目标地址。
  401491:	29 f8                	sub    eax,edi ; 计算原目标与对齐后目标的差。
  401493:	29 c3                	sub    ebx,eax ; 相应调整源地址。
  401495:	01 c2                	add    edx,eax ; 调整剩余复制长度。
  401497:	83 e2 fc             	and    edx,0xfffffffc ; 把复制长度取四字节的整数倍。
  40149a:	89 d0                	mov    eax,edx ; 复制长度送入 EAX。
  40149c:	c1 e8 02             	shr    eax,0x2 ; 字节数除以四，得到 DWORD 数量。
  40149f:	89 de                	mov    esi,ebx ; ESI 设置为源地址。
  4014a1:	89 c1                	mov    ecx,eax ; ECX 设置为重复次数。
  4014a3:	f3 a5                	rep movs DWORD PTR es:[edi],DWORD PTR ds:[esi] ; REP MOVS 将初始化数据复制到栈上的数组。
  4014a5:	8d 44 24 1f          	lea    eax,[esp+0x1f] ; 重新取得局部数组地址 ESP+1Fh。
  4014a9:	89 04 24             	mov    DWORD PTR [esp],eax ; 传入局部数组地址。
  4014ac:	e8 5b 00 00 00       	call   40150c <_check_table> ; 调用同一个公共检查过程。
  4014b1:	b8 00 00 00 00       	mov    eax,0x0 ; 成功返回 0。
  4014b6:	8d 65 f4             	lea    esp,[ebp-0xc] ; 定位保存的寄存器。
  4014b9:	5b                   	pop    ebx ; 恢复 EBX。
  4014ba:	5e                   	pop    esi ; 恢复 ESI。
  4014bb:	5f                   	pop    edi ; 恢复 EDI。
  4014bc:	5d                   	pop    ebp ; 恢复 EBP。
  4014bd:	c3                   	ret ; 返回；局部数组的生存期随 main 结束。
```

## 数组寻址、比较及双循环：GLOBAL.EXE 的公共过程

C 下标 row、column 从 0 开始。数组是 unsigned char[9][9]，每个元素 1 字节，因此地址公式为 `base + row*9 + column`。传入的参数是指向一行（9 个字节）的指针，并不是把 81 字节数组复制进参数区。

```asm
004014d0 <_check_table>:
  4014d0:	55                   	push   ebp ; 保存 EBP。
  4014d1:	89 e5                	mov    ebp,esp ; 建立检查函数栈帧。
  4014d3:	83 ec 28             	sub    esp,0x28 ; 分配局部变量和参数区。
  4014d6:	c7 04 24 72 b0 40 00 	mov    DWORD PTR [esp],0x40b072 ; 准备表头字符串。
  4014dd:	e8 8e 7e 00 00       	call   409370 <_puts> ; 输出 x y。
  4014e2:	c7 45 f4 00 00 00 00 	mov    DWORD PTR [ebp-0xc],0x0 ; row = 0，位于 [EBP-0Ch]。
  4014e9:	eb 60                	jmp    40154b <_check_table+0x7b> ; 先检查外层循环条件。
  4014eb:	c7 45 f0 00 00 00 00 	mov    DWORD PTR [ebp-0x10],0x0 ; column = 0，位于 [EBP-10h]。
  4014f2:	eb 4d                	jmp    401541 <_check_table+0x71> ; 先检查内层循环条件。
  4014f4:	8b 45 f4             	mov    eax,DWORD PTR [ebp-0xc] ; 读取 row。
  4014f7:	8d 50 01             	lea    edx,[eax+0x1] ; EDX = row+1。
  4014fa:	8b 45 f0             	mov    eax,DWORD PTR [ebp-0x10] ; 读取 column。
  4014fd:	83 c0 01             	add    eax,0x1 ; EAX = column+1。
  401500:	0f af c2             	imul   eax,edx ; 计算期望乘积 (row+1)*(column+1)。
  401503:	89 45 ec             	mov    DWORD PTR [ebp-0x14],eax ; 保存 expected 到 [EBP-14h]。
  401506:	8b 55 f4             	mov    edx,DWORD PTR [ebp-0xc] ; 读取 row。
  401509:	89 d0                	mov    eax,edx ; 复制 row。
  40150b:	c1 e0 03             	shl    eax,0x3 ; EAX = row*8。
  40150e:	01 c2                	add    edx,eax ; EDX = row*9，即行起始字节偏移。
  401510:	8b 45 08             	mov    eax,DWORD PTR [ebp+0x8] ; 读取传入的数组首地址。
  401513:	01 c2                	add    edx,eax ; 加上行偏移。
  401515:	8b 45 f0             	mov    eax,DWORD PTR [ebp-0x10] ; 读取 column。
  401518:	01 d0                	add    eax,edx ; 加上列偏移，得到 table[row][column] 地址。
  40151a:	0f b6 00             	movzx  eax,BYTE PTR [eax] ; 从内存读取一个无符号字节并零扩展。
  40151d:	0f b6 c0             	movzx  eax,al ; 再次零扩展 AL；本次未优化构建保留了这一步。
  401520:	3b 45 ec             	cmp    eax,DWORD PTR [ebp-0x14] ; 比较实际字节值与 expected。
  401523:	74 18                	je     40153d <_check_table+0x6d> ; 相等则跳过报告。
  401525:	8b 45 f0             	mov    eax,DWORD PTR [ebp-0x10] ; 读取 column。
  401528:	8d 50 01             	lea    edx,[eax+0x1] ; 转换为从 1 开始的输出列号。
  40152b:	8b 45 f4             	mov    eax,DWORD PTR [ebp-0xc] ; 读取 row。
  40152e:	83 c0 01             	add    eax,0x1 ; 转换为从 1 开始的输出行号。
  401531:	89 54 24 04          	mov    DWORD PTR [esp+0x4],edx ; 设置 report_error 第二个参数 column+1。
  401535:	89 04 24             	mov    DWORD PTR [esp],eax ; 设置第一个参数 row+1。
  401538:	e8 70 ff ff ff       	call   4014ad <_report_error> ; 调用 report_error 输出错误坐标。
  40153d:	83 45 f0 01          	add    DWORD PTR [ebp-0x10],0x1 ; column++。
  401541:	83 7d f0 08          	cmp    DWORD PTR [ebp-0x10],0x8 ; 比较 column 和 8。
  401545:	76 ad                	jbe    4014f4 <_check_table+0x24> ; column <= 8 则继续内层循环。
  401547:	83 45 f4 01          	add    DWORD PTR [ebp-0xc],0x1 ; row++。
  40154b:	83 7d f4 08          	cmp    DWORD PTR [ebp-0xc],0x8 ; 比较 row 和 8。
  40154f:	76 9a                	jbe    4014eb <_check_table+0x1b> ; row <= 8 则继续外层循环。
  401551:	c7 04 24 76 b0 40 00 	mov    DWORD PTR [esp],0x40b076 ; 准备结束提示。
  401558:	e8 13 7e 00 00       	call   409370 <_puts> ; 输出空行及 accomplish!。
  40155d:	90                   	nop ; 空操作。
  40155e:	c9                   	leave ; 恢复栈帧。
  40155f:	c3                   	ret ; 返回调用者。
```

LOCAL.EXE 中相同源函数的地址为 0040150Ch，GLOBAL.EXE 中为 004014D0h；调用的参数和算法相同，地址布局不同。对 LOCAL 的完整函数可以在 [LOCAL.DISASM.txt](LOCAL.DISASM.txt) 搜索 `<_check_table>:` 核对。

## 错误报告过程：GLOBAL.EXE

```asm
004014ad <_report_error>:
  4014ad:	55                   	push   ebp ; 保存 EBP。
  4014ae:	89 e5                	mov    ebp,esp ; 建立栈帧。
  4014b0:	83 ec 18             	sub    esp,0x18 ; 分配调用参数区。
  4014b3:	8b 45 0c             	mov    eax,DWORD PTR [ebp+0xc] ; 读取列号。
  4014b6:	89 44 24 08          	mov    DWORD PTR [esp+0x8],eax ; 放入 printf 的第三个参数位置。
  4014ba:	8b 45 08             	mov    eax,DWORD PTR [ebp+0x8] ; 读取行号。
  4014bd:	89 44 24 04          	mov    DWORD PTR [esp+0x4],eax ; 放入 printf 的第二个参数位置。
  4014c1:	c7 04 24 64 b0 40 00 	mov    DWORD PTR [esp],0x40b064 ; 第一个参数为格式字符串 %u %u  error\n。
  4014c8:	e8 b7 ff ff ff       	call   401484 <_printf> ; 打印一条错误报告。
  4014cd:	90                   	nop ; 空操作。
  4014ce:	c9                   	leave ; 恢复栈帧。
  4014cf:	c3                   	ret ; RET 返回检查循环。
```

## 对比结论

| 项目 | 全局 table | 自动局部 table |
| --- | --- | --- |
| 定义位置 | 函数外 | main 内 |
| 生存期 | 整个程序执行期间 | 当前 main 调用期间 |
| 本次实际位置 | .data，0040A020h | main 栈帧，ESP+1Fh |
| 初始化方式 | EXE 保存初始数据，装载时得到初值 | 进入 main 后把模板复制到栈 |
| 传参 | 固定数据地址 | LEA 得到的栈地址 |
| 公共扫描过程 | 读取传入指针，再按行列偏移寻址 | 相同 |
| 检查结果 | 相同的五个坐标 | 相同的五个坐标 |

局部变量若声明为 static，会具有静态存储期，与这里的自动局部数组不同。优化等级或编译器变化也可能改变实现方式，以上地址与复制指令只针对已提交的实际 EXE。

C 版本是 Windows 32 位 x86 程序，MUL/IMUL 形式、寄存器宽度和调用约定与 16 位 DOS 版本不同。这里 IMUL 的两个操作数均在 1～9 内，所得低 32 位乘积就是所需的无符号正整数结果。C 函数不保证保存 EAX/ECX/EDX；DOS 手写过程则通过 PUSH/POP 明确保持调用者需要的寄存器。

重新运行 BUILD.BAT 后可搜索 main、check_table、report_error 对比上述代码。若生成的指令改变，应同步更新本注释和验收材料。
