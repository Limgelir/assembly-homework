# C 实现的真实反汇编与注释

本文件来自已提交的 `SUM_C.EXE`，用 `objdump -d -M intel SUM_C.EXE` 生成；完整原始输出见 [SUM_C.DISASM.txt](SUM_C.DISASM.txt)。下面保留原地址、机器码和指令，逐条解释 `sum_to` 和 `main`，不包含函数末尾仅用于对齐的 NOP。

编译环境是 MinGW GCC 6.3.0，目标为 `mingw32`，使用 `-O0 -g -fno-omit-frame-pointer -fno-inline`。该 EXE 是 **Windows 32 位 x86 程序**，汇编作业中的 EXE 是 **DOS 16 位程序**。两者使用相同的累加算法，但调用约定、寄存器宽度、输入输出方式不同。

## 先看求和函数

C 代码的核心是 `total=0; for(i=1; i<=n; ++i) total+=i;`。
实际反汇编用 `ADD` 累加、`CMP/JBE` 控制循环，不是直接输出字符串 5050，也没有使用等差数列公式。测试脚本使用公式计算期望值，从另一条路径核对结果。

| 内容 | 位置 |
| --- | --- |
| 参数 n | `[EBP+8]` |
| 局部变量 total | `[EBP-4]` |
| 局部变量 i | `[EBP-8]` |
| 函数返回值 | `EAX` |
| main 的 input 数组 | `[ESP+14h]` 起，64 字节 |
| main 的 length、n、i | `[ESP+54h]`、`[ESP+58h]`、`[ESP+5Ch]` |

## 逐条注释

``asm
00401489 <_sum_to>:
  401489:	55                   	push   ebp ; 保存调用者的 EBP。
  40148a:	89 e5                	mov    ebp,esp ; 建立当前栈帧，EBP 成为访问参数和局部变量的基准。
  40148c:	83 ec 10             	sub    esp,0x10 ; 为局部变量和对齐预留 16 字节。
  40148f:	c7 45 fc 00 00 00 00 	mov    DWORD PTR [ebp-0x4],0x0 ; total = 0；32 位局部变量放在 [EBP-4]。
  401496:	c7 45 f8 01 00 00 00 	mov    DWORD PTR [ebp-0x8],0x1 ; i = 1；32 位局部变量放在 [EBP-8]。
  40149d:	eb 0a                	jmp    4014a9 <_sum_to+0x20> ; 先检查循环条件，避免无条件执行第一次累加。
  40149f:	8b 45 f8             	mov    eax,DWORD PTR [ebp-0x8] ; 读取 i 到 EAX。
  4014a2:	01 45 fc             	add    DWORD PTR [ebp-0x4],eax ; total += i，真正执行累加的指令。
  4014a5:	83 45 f8 01          	add    DWORD PTR [ebp-0x8],0x1 ; ++i。
  4014a9:	8b 45 f8             	mov    eax,DWORD PTR [ebp-0x8] ; 读取 i，为比较作准备。
  4014ac:	3b 45 08             	cmp    eax,DWORD PTR [ebp+0x8] ; 比较 i 和参数 n；[EBP+8] 是栈上传入的 n。
  4014af:	76 ee                	jbe    40149f <_sum_to+0x16> ; 无符号 i <= n 时返回循环体；JBE 使用 CF/ZF。
  4014b1:	8b 45 fc             	mov    eax,DWORD PTR [ebp-0x4] ; 把 total 放入 EAX，作为函数返回值。
  4014b4:	c9                   	leave ; 恢复 ESP 和调用者的 EBP（LEAVE）。
  4014b5:	c3                   	ret ; 返回调用者。

004014b6 <_main>:
  4014b6:	55                   	push   ebp ; 保存调用者 EBP。
  4014b7:	89 e5                	mov    ebp,esp ; 建立 main 栈帧。
  4014b9:	83 e4 f0             	and    esp,0xfffffff0 ; 把 ESP 向下对齐到 16 字节。
  4014bc:	83 ec 60             	sub    esp,0x60 ; 预留局部缓冲区和调用参数区，共 0x60 字节。
  4014bf:	e8 7c 06 00 00       	call   401b40 <___main> ; GCC 运行库初始化；并非求和逻辑。
  4014c4:	c7 44 24 58 00 00 00 	mov    DWORD PTR [esp+0x58],0x0 ; n = 0，保存到 [ESP+0x58]。
  4014cb:	00
  4014cc:	c7 04 24 64 b0 40 00 	mov    DWORD PTR [esp],0x40b064 ; puts 的参数：输入提示字符串地址。
  4014d3:	e8 50 7f 00 00       	call   409428 <_puts> ; 打印输入提示。
  4014d8:	a1 ec f1 40 00       	mov    eax,ds:0x40f1ec ; 读取 C 运行库的 stdin 指针。
  4014dd:	89 44 24 08          	mov    DWORD PTR [esp+0x8],eax ; fgets 第三个参数为 stdin。
  4014e1:	c7 44 24 04 40 00 00 	mov    DWORD PTR [esp+0x4],0x40 ; fgets 第二个参数为缓冲区容量 64。
  4014e8:	00
  4014e9:	8d 44 24 14          	lea    eax,[esp+0x14] ; 取得 input 缓冲区地址 [ESP+0x14]。
  4014ed:	89 04 24             	mov    DWORD PTR [esp],eax ; fgets 第一个参数为 input。
  4014f0:	e8 7b 7f 00 00       	call   409470 <_fgets> ; 调用 fgets 读取一行。
  4014f5:	85 c0                	test   eax,eax ; 检查返回指针是否为 NULL。
  4014f7:	75 16                	jne    40150f <_main+0x59> ; 读取成功则继续，否则进入错误处理。
  4014f9:	c7 04 24 7c b0 40 00 	mov    DWORD PTR [esp],0x40b07c ; 错误提示字符串地址。
  401500:	e8 23 7f 00 00       	call   409428 <_puts> ; 打印错误提示。
  401505:	b8 01 00 00 00       	mov    eax,0x1 ; 设置返回码 1。
  40150a:	e9 f4 00 00 00       	jmp    401603 <_main+0x14d> ; 跳到函数退出位置。
  40150f:	c7 44 24 04 a7 b0 40 	mov    DWORD PTR [esp+0x4],0x40b0a7 ; strcspn 第二个参数是包含 CR/LF 的字符串。
  401516:	00
  401517:	8d 44 24 14          	lea    eax,[esp+0x14] ; 取得 input 地址。
  40151b:	89 04 24             	mov    DWORD PTR [esp],eax ; strcspn 第一个参数为 input。
  40151e:	e8 d5 7e 00 00       	call   4093f8 <_strcspn> ; 找到首个 CR/LF 的位置，得到有效长度。
  401523:	89 44 24 54          	mov    DWORD PTR [esp+0x54],eax ; 保存 length 到 [ESP+0x54]。
  401527:	83 7c 24 54 00       	cmp    DWORD PTR [esp+0x54],0x0 ; 检查 length 是否为 0。
  40152c:	74 07                	je     401535 <_main+0x7f> ; 空输入进入错误处理。
  40152e:	83 7c 24 54 03       	cmp    DWORD PTR [esp+0x54],0x3 ; 比较 length 和 3。
  401533:	76 16                	jbe    40154b <_main+0x95> ; length <= 3 时开始解析。
  401535:	c7 04 24 7c b0 40 00 	mov    DWORD PTR [esp],0x40b07c ; 错误提示字符串地址。
  40153c:	e8 e7 7e 00 00       	call   409428 <_puts> ; 打印长度错误。
  401541:	b8 01 00 00 00       	mov    eax,0x1 ; 设置返回码 1。
  401546:	e9 b8 00 00 00       	jmp    401603 <_main+0x14d> ; 跳到退出位置。
  40154b:	c7 44 24 5c 00 00 00 	mov    DWORD PTR [esp+0x5c],0x0 ; i = 0，保存到 [ESP+0x5c]。
  401552:	00
  401553:	eb 62                	jmp    4015b7 <_main+0x101> ; 先检查解析循环的 i < length。
  401555:	8d 54 24 14          	lea    edx,[esp+0x14] ; 取得 input 首地址。
  401559:	8b 44 24 5c          	mov    eax,DWORD PTR [esp+0x5c] ; 读取 i。
  40155d:	01 d0                	add    eax,edx ; 计算 input+i。
  40155f:	0f b6 00             	movzx  eax,BYTE PTR [eax] ; 读取 input[i] 的一个字节。
  401562:	3c 2f                	cmp    al,0x2f ; 比较字符与 0x2f（'0'-1）。
  401564:	7e 11                	jle    401577 <_main+0xc1> ; 字符 <= '/'，即小于 '0'，进入错误处理。
  401566:	8d 54 24 14          	lea    edx,[esp+0x14] ; 再次取得 input 首地址。
  40156a:	8b 44 24 5c          	mov    eax,DWORD PTR [esp+0x5c] ; 读取 i。
  40156e:	01 d0                	add    eax,edx ; 计算 input+i。
  401570:	0f b6 00             	movzx  eax,BYTE PTR [eax] ; 读取 input[i]。
  401573:	3c 39                	cmp    al,0x39 ; 与 0x39（'9'）比较。
  401575:	7e 13                	jle    40158a <_main+0xd4> ; 字符 <= '9' 则接受；下界已检查。
  401577:	c7 04 24 7c b0 40 00 	mov    DWORD PTR [esp],0x40b07c ; 错误提示字符串地址。
  40157e:	e8 a5 7e 00 00       	call   409428 <_puts> ; 打印字符错误。
  401583:	b8 01 00 00 00       	mov    eax,0x1 ; 设置返回码 1。
  401588:	eb 79                	jmp    401603 <_main+0x14d> ; 跳到退出位置。
  40158a:	8b 54 24 58          	mov    edx,DWORD PTR [esp+0x58] ; 把旧 n 读入 EDX。
  40158e:	89 d0                	mov    eax,edx ; 复制旧 n 到 EAX。
  401590:	c1 e0 02             	shl    eax,0x2 ; EAX = 4*n。
  401593:	01 d0                	add    eax,edx ; EAX = 5*n。
  401595:	01 c0                	add    eax,eax ; EAX = 10*n。
  401597:	89 c1                	mov    ecx,eax ; 暂存 10*n 到 ECX。
  401599:	8d 54 24 14          	lea    edx,[esp+0x14] ; 取得 input 首地址。
  40159d:	8b 44 24 5c          	mov    eax,DWORD PTR [esp+0x5c] ; 读取 i。
  4015a1:	01 d0                	add    eax,edx ; 计算 input+i。
  4015a3:	0f b6 00             	movzx  eax,BYTE PTR [eax] ; 读取 input[i]。
  4015a6:	0f be c0             	movsx  eax,al ; 将 char 扩展到 int；前面已限定为 ASCII 数字。
  4015a9:	01 c8                	add    eax,ecx ; 加上 10*n。
  4015ab:	83 e8 30             	sub    eax,0x30 ; 减去 0x30（'0'），得到 10*n+digit。
  4015ae:	89 44 24 58          	mov    DWORD PTR [esp+0x58],eax ; 更新 n。
  4015b2:	83 44 24 5c 01       	add    DWORD PTR [esp+0x5c],0x1 ; ++i。
  4015b7:	8b 44 24 5c          	mov    eax,DWORD PTR [esp+0x5c] ; 读取 i。
  4015bb:	3b 44 24 54          	cmp    eax,DWORD PTR [esp+0x54] ; 比较 i 和 length。
  4015bf:	72 94                	jb     401555 <_main+0x9f> ; 无符号 i < length 时解析下一个字符。
  4015c1:	83 7c 24 58 00       	cmp    DWORD PTR [esp+0x58],0x0 ; 检查 n 是否为 0。
  4015c6:	74 07                	je     4015cf <_main+0x119> ; 0 不在 1..100 范围，进入错误处理。
  4015c8:	83 7c 24 58 64       	cmp    DWORD PTR [esp+0x58],0x64 ; 与 0x64（100）比较。
  4015cd:	76 13                	jbe    4015e2 <_main+0x12c> ; n <= 100 则接受。
  4015cf:	c7 04 24 7c b0 40 00 	mov    DWORD PTR [esp],0x40b07c ; 错误提示字符串地址。
  4015d6:	e8 4d 7e 00 00       	call   409428 <_puts> ; 打印范围错误。
  4015db:	b8 01 00 00 00       	mov    eax,0x1 ; 设置返回码 1。
  4015e0:	eb 21                	jmp    401603 <_main+0x14d> ; 跳到退出位置。
  4015e2:	8b 44 24 58          	mov    eax,DWORD PTR [esp+0x58] ; 读取有效 n。
  4015e6:	89 04 24             	mov    DWORD PTR [esp],eax ; 把 n 放到调用参数区。
  4015e9:	e8 9b fe ff ff       	call   401489 <_sum_to> ; 调用 sum_to(n)。
  4015ee:	89 44 24 04          	mov    DWORD PTR [esp+0x4],eax ; 返回的 EAX 即总和，作为 printf 第二个参数。
  4015f2:	c7 04 24 aa b0 40 00 	mov    DWORD PTR [esp],0x40b0aa ; printf 第一个参数是格式字符串 Sum:\n%u\n。
  4015f9:	e8 62 fe ff ff       	call   401460 <_printf> ; 打印十进制总和，转换由 C 库的 printf 完成。
  4015fe:	b8 00 00 00 00       	mov    eax,0x0 ; 成功返回 0。
  401603:	c9                   	leave ; 恢复栈帧。
  401604:	c3                   	ret ; 返回 Windows C 运行库。
```

这里共注释 **101 条指令**。仅显示机器码、没有助记符的续行属于上一条较长的指令。

## 与 16 位汇编对照

- C 的 `unsigned int` 在此编译器目标上为 32 位，汇编中的 AX 和 `DW` 为 16 位；最大总和 5050 在两种表示范围内。
- C 循环的 `i <= n` 生成无符号条件跳转 `JBE`；汇编的 `LOOP` 通过 CX 倒计数控制次数。
- C 的 `n*10` 在本次构建中生成移位和加法，即使使用 `-O0`，也不保证乘法表达式一定生成 `MUL`。
- C 通过 `fgets` 读入、`printf` 把整数转成十进制文本；DOS 版本通过 `INT 21h/AH=0Ah` 输入，自己用 `DIV 10` 和余数栈完成输出。
- main 的栈布局由编译器生成；`SUMSTACK.ASM` 则显式地通过 `SS:BP` 更新栈上的 16 位总和。

## 怎样自己核对

在 Windows 的本目录执行 `BUILD.BAT`，再在 `SUM_C.DISASM.txt` 中搜索 `<_sum_to>:` 和 `<_main>:`。核对 ADD、CMP/JBE、CALL、返回值 EAX 与以上注释。

更改源码、编译器或编译选项会改变地址与指令，应重新生成反汇编和对应注释。十六进制地址是本次 EXE 的布局，不需要记忆。
