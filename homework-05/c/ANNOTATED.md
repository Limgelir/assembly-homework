# C 递归 Fibonacci：真实反汇编与注释

这里逐条注释已提交 FIB_C.EXE 的 fib 函数，共 **78 条指令**。完整程序的实际输出见 [FIB_C.DISASM.txt](FIB_C.DISASM.txt)，源码见 [fib.c](fib.c)。使用 MinGW GCC 6.3.0 / GNU objdump 2.28，目标为 Windows 32 位 x86。

编译参数含 -O0、-fno-inline、-fno-omit-frame-pointer、-fno-optimize-sibling-calls，便于观察真实的递归调用、返回与栈帧。

## 递归不是被循环替代

fib 在 004014BCh、004014CDh 两次 CALL 自身入口 00401460h，分别求 F(n-1)、F(n-2)。第一次计算结果写入 memo，以后命中 ready 时直接返回缓存指针。记忆化消除重复求值，真实递归链仍保留，n=100 时深度为 100。

main 在 00401739h 调用 fib，随后在 00401741h 调用 print_big（入口 00401550h）。这两个地址也可以在完整原始反汇编中搜索核对。

## 逐条注释

```asm
00401460 <_fib>:
  401460:	55                   	push   ebp ; 保存调用者 EBP。
  401461:	89 e5                	mov    ebp,esp ; 建立当前递归层的栈帧。
  401463:	83 ec 38             	sub    esp,0x38 ; 为局部变量和调用参数区分配 38h=56 字节。
  401466:	c7 45 f0 00 00 00 00 	mov    DWORD PTR [ebp-0x10],0x0 ; carry=0，保存在 [EBP-10h]。
  40146d:	8b 45 08             	mov    eax,DWORD PTR [ebp+0x8] ; 读取参数 n：[EBP+8]。
  401470:	05 20 74 40 00       	add    eax,0x407420 ; 计算 ready+n。
  401475:	0f b6 00             	movzx  eax,BYTE PTR [eax] ; 读取缓存有效标志。
  401478:	84 c0                	test   al,al ; 检查是否已计算。
  40147a:	74 16                	je     401492 <_fib+0x32> ; 未缓存则进入递归/基例。
  40147c:	8b 55 08             	mov    edx,DWORD PTR [ebp+0x8] ; 读取 n。
  40147f:	89 d0                	mov    eax,edx ; 复制 n。
  401481:	c1 e0 02             	shl    eax,0x2 ; 得到 4*n。
  401484:	01 d0                	add    eax,edx ; 得到 5*n。
  401486:	01 c0                	add    eax,eax ; 得到 10*n，即 Big 的字节偏移。
  401488:	05 20 70 40 00       	add    eax,0x407020 ; 加 memo 首地址，EAX=&memo[n]。
  40148d:	e9 bc 00 00 00       	jmp    40154e <_fib+0xee> ; 缓存命中，直接走函数出口。
  401492:	83 7d 08 01          	cmp    DWORD PTR [ebp+0x8],0x1 ; 比较 n 和 1。
  401496:	77 1b                	ja     4014b3 <_fib+0x53> ; n>1 时递归，否则处理 F(0)/F(1)。
  401498:	8b 45 08             	mov    eax,DWORD PTR [ebp+0x8] ; 读取 n。
  40149b:	89 c1                	mov    ecx,eax ; 保存 n 的值，用于设置最低 word。
  40149d:	8b 55 08             	mov    edx,DWORD PTR [ebp+0x8] ; 读取 n 以计算位置。
  4014a0:	89 d0                	mov    eax,edx ; 复制 n。
  4014a2:	c1 e0 02             	shl    eax,0x2 ; 4*n。
  4014a5:	01 d0                	add    eax,edx ; 5*n。
  4014a7:	01 c0                	add    eax,eax ; 10*n。
  4014a9:	05 20 70 40 00       	add    eax,0x407020 ; 得到 memo[n] 地址。
  4014ae:	66 89 08             	mov    WORD PTR [eax],cx ; 最低 16 位设为 n；其余 word 静态初始化为 0。
  4014b1:	eb 7f                	jmp    401532 <_fib+0xd2> ; 跳到设置 ready[n]。
  4014b3:	8b 45 08             	mov    eax,DWORD PTR [ebp+0x8] ; 读取本层 n。
  4014b6:	83 e8 01             	sub    eax,0x1 ; n-1。
  4014b9:	89 04 24             	mov    DWORD PTR [esp],eax ; 把 n-1 放入调用参数区。
  4014bc:	e8 9f ff ff ff       	call   401460 <_fib> ; 真正调用自身 fib(n-1)，压入返回地址 004014C1h。
  4014c1:	89 45 ec             	mov    DWORD PTR [ebp-0x14],eax ; 保存返回的 Big 指针 a 到 [EBP-14h]。
  4014c4:	8b 45 08             	mov    eax,DWORD PTR [ebp+0x8] ; 再次读取本层 n；它没有被子调用覆盖。
  4014c7:	83 e8 02             	sub    eax,0x2 ; n-2。
  4014ca:	89 04 24             	mov    DWORD PTR [esp],eax ; 设置递归调用参数。
  4014cd:	e8 8e ff ff ff       	call   401460 <_fib> ; 再次调用自身 fib(n-2)，返回到 004014D2h。
  4014d2:	89 45 e8             	mov    DWORD PTR [ebp-0x18],eax ; 保存指针 b 到 [EBP-18h]。
  4014d5:	c7 45 f4 00 00 00 00 	mov    DWORD PTR [ebp-0xc],0x0 ; i=0。
  4014dc:	eb 4e                	jmp    40152c <_fib+0xcc> ; 先检查五个 word 的循环边界。
  4014de:	8b 45 ec             	mov    eax,DWORD PTR [ebp-0x14] ; 读取 a 指针。
  4014e1:	8b 55 f4             	mov    edx,DWORD PTR [ebp-0xc] ; 读取 i。
  4014e4:	0f b7 04 50          	movzx  eax,WORD PTR [eax+edx*2] ; 读取 a->word[i] 并零扩展到 32 位。
  4014e8:	0f b7 c8             	movzx  ecx,ax ; 将 a 的 16 位值放入 ECX。
  4014eb:	8b 45 e8             	mov    eax,DWORD PTR [ebp-0x18] ; 读取 b 指针。
  4014ee:	8b 55 f4             	mov    edx,DWORD PTR [ebp-0xc] ; 读取 i。
  4014f1:	0f b7 04 50          	movzx  eax,WORD PTR [eax+edx*2] ; 读取 b->word[i]。
  4014f5:	0f b7 c0             	movzx  eax,ax ; 零扩展无符号 word。
  4014f8:	8d 14 01             	lea    edx,[ecx+eax*1] ; 加上两个 word。
  4014fb:	8b 45 f0             	mov    eax,DWORD PTR [ebp-0x10] ; 读取上一 word 的 carry。
  4014fe:	01 d0                	add    eax,edx ; 加 carry，形成不超过 131071 的 32 位 sum。
  401500:	89 45 e4             	mov    DWORD PTR [ebp-0x1c],eax ; 保存 sum 到 [EBP-1Ch]。
  401503:	8b 45 e4             	mov    eax,DWORD PTR [ebp-0x1c] ; 读取 sum。
  401506:	89 c1                	mov    ecx,eax ; 把 sum 低 16 位暂存在 CX。
  401508:	8b 55 08             	mov    edx,DWORD PTR [ebp+0x8] ; 读取 n。
  40150b:	89 d0                	mov    eax,edx ; 复制 n。
  40150d:	c1 e0 02             	shl    eax,0x2 ; 4*n。
  401510:	01 d0                	add    eax,edx ; 5*n，以 word 为单位的数组索引基数。
  401512:	8b 55 f4             	mov    edx,DWORD PTR [ebp-0xc] ; 读取 i。
  401515:	01 d0                	add    eax,edx ; 得到 5*n+i。
  401517:	66 89 8c 00 20 70 40 	mov    WORD PTR [eax+eax*1+0x407020],cx ; 以字节地址 memo+2*(5*n+i) 保存 sum 的低 16 位。
  40151e:	00
  40151f:	8b 45 e4             	mov    eax,DWORD PTR [ebp-0x1c] ; 读取完整 32 位 sum。
  401522:	c1 e8 10             	shr    eax,0x10 ; 右移 16 位得到 carry（0 或 1）。
  401525:	89 45 f0             	mov    DWORD PTR [ebp-0x10],eax ; 保存 carry，传给下一个 word。
  401528:	83 45 f4 01          	add    DWORD PTR [ebp-0xc],0x1 ; ++i。
  40152c:	83 7d f4 04          	cmp    DWORD PTR [ebp-0xc],0x4 ; 检查 i 是否 <=4。
  401530:	76 ac                	jbe    4014de <_fib+0x7e> ; 继续处理剩余 word。
  401532:	8b 45 08             	mov    eax,DWORD PTR [ebp+0x8] ; 读取 n。
  401535:	05 20 74 40 00       	add    eax,0x407420 ; 定位 ready[n]。
  40153a:	c6 00 01             	mov    BYTE PTR [eax],0x1 ; 标记缓存已计算。
  40153d:	8b 55 08             	mov    edx,DWORD PTR [ebp+0x8] ; 读取 n 以计算返回地址。
  401540:	89 d0                	mov    eax,edx ; 复制 n。
  401542:	c1 e0 02             	shl    eax,0x2 ; 4*n。
  401545:	01 d0                	add    eax,edx ; 5*n。
  401547:	01 c0                	add    eax,eax ; 10*n。
  401549:	05 20 70 40 00       	add    eax,0x407020 ; EAX=&memo[n]，作为返回值。
  40154e:	c9                   	leave ; LEAVE 恢复 ESP 和调用者 EBP。
  40154f:	c3                   	ret ; RET 返回本层调用者。
```

只有机器码、没有助记符的续行属于上一条指令。

## 栈帧与多字精度

| 本层位置 | 含义 |
| --- | --- |
| [EBP] | 保存的调用者 EBP |
| [EBP+4] | 本层返回地址 |
| [EBP+8] | 本层参数 n |
| [EBP-0Ch] | word 循环下标 i |
| [EBP-10h] | 进位 carry |
| [EBP-14h]、[EBP-18h] | 子结果 a、b 的指针 |
| [EBP-1Ch] | 32 位中间和 sum |

C 的 Big 包含五个 uint16_t，共 10 字节。两个 16 位 word 相加再加进位，最大为 131071，使用 uint32_t 能完整容纳；低 16 位写回，右移 16 位得到进位。这个实现不依赖编译器提供 128 位整数。

一层 fib 分配 56 字节，另有保存的 EBP 和 CALL 的返回地址，各 4 字节，因此此构建每层 fib 的固定占用为 64 字节。调用参数区已包括在 56 字节内。PE 头记录栈预留 00200000h（2 MiB）、初始提交 00001000h（4 KiB）；这是 Windows 程序的配置，与 DOS 程序单独分配的 4 KiB 栈不同。

C 通过 EAX 返回指针，临时寄存器遵循 C 调用约定；不能假设 CALL/RET 自动保存所有寄存器。DOS 汇编版则在每层显式保存 AX/BX/CX/DX/DI/BP，用 SI 返回数据段中的缓存地址。

print_big 复制结果后进行从最高 word 到最低 word 的长除法，将每次除以 10 的余数保存为字符并逆序输出。因此显示十进制字符串时不会破坏递归缓存。

改变编译器、源码或编译选项后，地址可能变化；应重新运行 BUILD.BAT，并同步更新注释。
