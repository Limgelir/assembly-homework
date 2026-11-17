# C 实际反汇编与中文注释

本文件摘录自同目录 `CAL_C.DISASM.txt`，对应实际提交的 Windows 32 位 `CAL_C.EXE`。工具为 MinGW GCC 6.3.0、GNU objdump 2.28；构建参数见 `BUILD.BAT`，完整运行记录见 `../verification/c-toolchain.txt`。以下地址、字节、指令保留 objdump 原文，分号行是中文解释。

这是 x86 32 位平坦内存模型，用 EAX/ESP/EBP；汇编作业主程序是 8086 的 AX/SP/BP。C 的普通函数调用没有显式切换 CS，不能用它代替本作业的 DOS 远调用实验。

## 闰年判定

C 表达式为 `year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)`。1900 为平年，2000 为闰年。即使使用 -O0，GCC 仍会把常数除法变成等价的乘法、移位和符号修正；下面确实没有直接用 DIV 100 或 DIV 400。

```asm
00401489 <_leap_year>:
; 保存调用者 EBP，建立栈帧；[EBP+8] 是 year。
  401489:	55                   	push   ebp
  40148a:	89 e5                	mov    ebp,esp
  40148c:	8b 45 08             	mov    eax,DWORD PTR [ebp+0x8]
; 检查低两位，相当于判断 year % 4 是否为 0；非零直接返回 0。
  40148f:	83 e0 03             	and    eax,0x3
  401492:	85 c0                	test   eax,eax
  401494:	75 50                	jne    4014e6 <_leap_year+0x5d>
; 下面用乘法的高 32 位和右移计算 year/100；0x51EB851F 是编译器选择的常数。
  401496:	8b 4d 08             	mov    ecx,DWORD PTR [ebp+0x8]
  401499:	ba 1f 85 eb 51       	mov    edx,0x51eb851f
  40149e:	89 c8                	mov    eax,ecx
  4014a0:	f7 ea                	imul   edx
  4014a2:	c1 fa 05             	sar    edx,0x5
; 提取符号并修正有符号整除的舍入；本作业年份全为正数。
  4014a5:	89 c8                	mov    eax,ecx
  4014a7:	c1 f8 1f             	sar    eax,0x1f
  4014aa:	29 c2                	sub    edx,eax
  4014ac:	89 d0                	mov    eax,edx
; 商乘 100，再用 year 减去它，得到 year % 100；非零即可返回闰年。
  4014ae:	6b c0 64             	imul   eax,eax,0x64
  4014b1:	29 c1                	sub    ecx,eax
  4014b3:	89 c8                	mov    eax,ecx
  4014b5:	85 c0                	test   eax,eax
  4014b7:	75 26                	jne    4014df <_leap_year+0x56>
; 若整百，继续计算 year/400；同一个常数，但这里右移 7 位。
  4014b9:	8b 4d 08             	mov    ecx,DWORD PTR [ebp+0x8]
  4014bc:	ba 1f 85 eb 51       	mov    edx,0x51eb851f
  4014c1:	89 c8                	mov    eax,ecx
  4014c3:	f7 ea                	imul   edx
  4014c5:	c1 fa 07             	sar    edx,0x7
  4014c8:	89 c8                	mov    eax,ecx
  4014ca:	c1 f8 1f             	sar    eax,0x1f
  4014cd:	29 c2                	sub    edx,eax
  4014cf:	89 d0                	mov    eax,edx
; 商乘 0x190（400），再相减得余数；余数非零则不是闰年。
  4014d1:	69 c0 90 01 00 00    	imul   eax,eax,0x190
  4014d7:	29 c1                	sub    ecx,eax
  4014d9:	89 c8                	mov    eax,ecx
  4014db:	85 c0                	test   eax,eax
  4014dd:	75 07                	jne    4014e6 <_leap_year+0x5d>
; 返回值放 EAX：1 表示闰年，0 表示平年。
  4014df:	b8 01 00 00 00       	mov    eax,0x1
  4014e4:	eb 05                	jmp    4014eb <_leap_year+0x62>
  4014e6:	b8 00 00 00 00       	mov    eax,0x0
; 恢复栈帧，普通近返回；32 位返回地址从栈弹入 EIP。
  4014eb:	5d                   	pop    ebp
  4014ec:	c3                   	ret
```

## 第一天星期、栈参数与循环

`first_weekday(year,month)` 的 year/month 分别位于 [EBP+8]/[EBP+0xC]；返回地址和旧 EBP 各占 4 字节。y、total、m 都是栈上的局部变量。

```asm
0040152a <_first_weekday>:
; 保存 EBP、EBX，为局部变量和调用参数预留栈空间。
  40152a:	55                   	push   ebp
  40152b:	89 e5                	mov    ebp,esp
  40152d:	53                   	push   ebx
  40152e:	83 ec 18             	sub    esp,0x18
; [EBP+8]=year；year-1 存入局部变量 y，即 [EBP-0x10]。
  401531:	8b 45 08             	mov    eax,DWORD PTR [ebp+0x8]
  401534:	83 e8 01             	sub    eax,0x1
  401537:	89 45 f0             	mov    DWORD PTR [ebp-0x10],eax
; 计算 y/4；CDQ 和掩码负责有符号除法舍入，然后 SAR 2。
  40153a:	8b 45 f0             	mov    eax,DWORD PTR [ebp-0x10]
  40153d:	99                   	cdq
  40153e:	83 e2 03             	and    edx,0x3
  401541:	01 d0                	add    eax,edx
  401543:	c1 f8 02             	sar    eax,0x2
  401546:	89 c2                	mov    edx,eax
; LEA 在这里做整数加法，EBX=y+y/4，不是读内存。
  401548:	8b 45 f0             	mov    eax,DWORD PTR [ebp-0x10]
  40154b:	8d 1c 02             	lea    ebx,[edx+eax*1]
; 乘常数并右移，得到 y/100；符号修正后取负，再加到 EBX。
  40154e:	8b 4d f0             	mov    ecx,DWORD PTR [ebp-0x10]
  401551:	ba 1f 85 eb 51       	mov    edx,0x51eb851f
  401556:	89 c8                	mov    eax,ecx
  401558:	f7 ea                	imul   edx
  40155a:	89 d0                	mov    eax,edx
  40155c:	c1 f8 05             	sar    eax,0x5
  40155f:	c1 f9 1f             	sar    ecx,0x1f
  401562:	89 ca                	mov    edx,ecx
  401564:	29 c2                	sub    edx,eax
  401566:	89 d0                	mov    eax,edx
  401568:	01 c3                	add    ebx,eax
; 同理算 y/400；接着加上 EBX，再加 1。
  40156a:	8b 4d f0             	mov    ecx,DWORD PTR [ebp-0x10]
  40156d:	ba 1f 85 eb 51       	mov    edx,0x51eb851f
  401572:	89 c8                	mov    eax,ecx
  401574:	f7 ea                	imul   edx
  401576:	c1 fa 07             	sar    edx,0x7
  401579:	89 c8                	mov    eax,ecx
  40157b:	c1 f8 1f             	sar    eax,0x1f
  40157e:	29 c2                	sub    edx,eax
  401580:	89 d0                	mov    eax,edx
  401582:	01 d8                	add    eax,ebx
  401584:	83 c0 01             	add    eax,0x1
; total 存在 [EBP-8]；循环变量 m=[EBP-0xC] 初始化为 1。
  401587:	89 45 f8             	mov    DWORD PTR [ebp-0x8],eax
  40158a:	c7 45 f4 01 00 00 00 	mov    DWORD PTR [ebp-0xc],0x1
; 先跳到循环条件，确保 month=1 时不执行循环体。
  401591:	eb 19                	jmp    4015ac <_first_weekday+0x82>
; 准备 days_in_month(year,m) 的两个栈参数：m 放 [ESP+4]，year 放 [ESP]。
  401593:	8b 45 f4             	mov    eax,DWORD PTR [ebp-0xc]
  401596:	89 44 24 04          	mov    DWORD PTR [esp+0x4],eax
  40159a:	8b 45 08             	mov    eax,DWORD PTR [ebp+0x8]
  40159d:	89 04 24             	mov    DWORD PTR [esp],eax
; 真实 CALL；被调用方返回该月天数到 EAX。
  4015a0:	e8 48 ff ff ff       	call   4014ed <_days_in_month>
; total += 返回天数；m++。
  4015a5:	01 45 f8             	add    DWORD PTR [ebp-0x8],eax
  4015a8:	83 45 f4 01          	add    DWORD PTR [ebp-0xc],0x1
; 把 m 与第二参数 month=[EBP+0xC] 比较，JL 表示有符号小于，满足则继续。
  4015ac:	8b 45 f4             	mov    eax,DWORD PTR [ebp-0xc]
  4015af:	3b 45 0c             	cmp    eax,DWORD PTR [ebp+0xc]
  4015b2:	7c df                	jl     401593 <_first_weekday+0x69>
; 开始计算 total % 7；0x92492493、乘法和移位先生成除以 7 的商。
  4015b4:	8b 4d f8             	mov    ecx,DWORD PTR [ebp-0x8]
  4015b7:	ba 93 24 49 92       	mov    edx,0x92492493
  4015bc:	89 c8                	mov    eax,ecx
  4015be:	f7 ea                	imul   edx
  4015c0:	8d 04 0a             	lea    eax,[edx+ecx*1]
  4015c3:	c1 f8 02             	sar    eax,0x2
  4015c6:	89 c2                	mov    edx,eax
; 修正商的符号舍入，将商置于 EAX/EDX。
  4015c8:	89 c8                	mov    eax,ecx
  4015ca:	c1 f8 1f             	sar    eax,0x1f
  4015cd:	29 c2                	sub    edx,eax
  4015cf:	89 d0                	mov    eax,edx
  4015d1:	89 c2                	mov    edx,eax
; 商左移 3 位再减去商得到 7*商，最后 total-7*商就是余数 0..6。
  4015d3:	c1 e2 03             	shl    edx,0x3
  4015d6:	29 c2                	sub    edx,eax
  4015d8:	89 c8                	mov    eax,ecx
  4015da:	29 d0                	sub    eax,edx
; 撤销局部空间，恢复 EBX、EBP，RET；EAX 是星期，星期日=0。
  4015dc:	83 c4 18             	add    esp,0x18
  4015df:	5b                   	pop    ebx
  4015e0:	5d                   	pop    ebp
  4015e1:	c3                   	ret
```

## 显示月历

下面是完整显示函数。前半段调用星期/天数函数，输出标题和前导空位；后半段逐日输出，处理第 7 列及最后一天换行。每个 CALL 都使用预留的栈参数区域；局部循环状态跨调用保存在栈帧中。

```asm
004015e2 <_render_calendar>:
; render_calendar(year,month) 的栈帧开始。
  4015e2:	55                   	push   ebp
  4015e3:	89 e5                	mov    ebp,esp
  4015e5:	83 ec 38             	sub    esp,0x38
; 准备调用参数，计算本月第一天星期及本月天数。
  4015e8:	8b 45 0c             	mov    eax,DWORD PTR [ebp+0xc]
  4015eb:	89 44 24 04          	mov    DWORD PTR [esp+0x4],eax
  4015ef:	8b 45 08             	mov    eax,DWORD PTR [ebp+0x8]
  4015f2:	89 04 24             	mov    DWORD PTR [esp],eax
  4015f5:	e8 30 ff ff ff       	call   40152a <_first_weekday>
; 返回的 first 保存在 [EBP-0x18]，随后重新设置栈参数并调用 days_in_month。
  4015fa:	89 45 e8             	mov    DWORD PTR [ebp-0x18],eax
  4015fd:	8b 45 0c             	mov    eax,DWORD PTR [ebp+0xc]
  401600:	89 44 24 04          	mov    DWORD PTR [esp+0x4],eax
  401604:	8b 45 08             	mov    eax,DWORD PTR [ebp+0x8]
  401607:	89 04 24             	mov    DWORD PTR [esp],eax
  40160a:	e8 de fe ff ff       	call   4014ed <_days_in_month>
; count=[EBP-0x1C]，column=[EBP-0xC] 初始化为 first。
  40160f:	89 45 e4             	mov    DWORD PTR [ebp-0x1c],eax
  401612:	8b 45 e8             	mov    eax,DWORD PTR [ebp-0x18]
  401615:	89 45 f4             	mov    DWORD PTR [ebp-0xc],eax
; month-1 作为 names 指针表下标；32 位指针每项 4 字节，因此索引乘 4。
  401618:	8b 45 0c             	mov    eax,DWORD PTR [ebp+0xc]
  40161b:	83 e8 01             	sub    eax,0x1
  40161e:	8b 04 85 20 a0 40 00 	mov    eax,DWORD PTR [eax*4+0x40a020]
; printf 三个参数：格式串、year、月份名称指针；分别放 [ESP]、[ESP+4]、[ESP+8]。
  401625:	89 44 24 08          	mov    DWORD PTR [esp+0x8],eax
  401629:	8b 45 08             	mov    eax,DWORD PTR [ebp+0x8]
  40162c:	89 44 24 04          	mov    DWORD PTR [esp+0x4],eax
  401630:	c7 04 24 80 b0 40 00 	mov    DWORD PTR [esp],0x40b080
  401637:	e8 24 fe ff ff       	call   401460 <_printf>
; i=[EBP-0x14] 从 0 开始；先检查 i<first，再输出一槽三个空格。
  40163c:	c7 45 ec 00 00 00 00 	mov    DWORD PTR [ebp-0x14],0x0
  401643:	eb 10                	jmp    401655 <_render_calendar+0x73>
  401645:	c7 04 24 9e b0 40 00 	mov    DWORD PTR [esp],0x40b09e
  40164c:	e8 0f fe ff ff       	call   401460 <_printf>
  401651:	83 45 ec 01          	add    DWORD PTR [ebp-0x14],0x1
  401655:	8b 45 ec             	mov    eax,DWORD PTR [ebp-0x14]
  401658:	3b 45 e8             	cmp    eax,DWORD PTR [ebp-0x18]
  40165b:	7c e8                	jl     401645 <_render_calendar+0x63>
; day=[EBP-0x10] 初始化为 1；先跳到 day<=count 的循环判断。
  40165d:	c7 45 f0 01 00 00 00 	mov    DWORD PTR [ebp-0x10],0x1
  401664:	eb 58                	jmp    4016be <_render_calendar+0xdc>
; printf("%2d",day)，用宽度 2 右对齐输出日期。
  401666:	8b 45 f0             	mov    eax,DWORD PTR [ebp-0x10]
  401669:	89 44 24 04          	mov    DWORD PTR [esp+0x4],eax
  40166d:	c7 04 24 a2 b0 40 00 	mov    DWORD PTR [esp],0x40b0a2
  401674:	e8 e7 fd ff ff       	call   401460 <_printf>
; column++，随后检查 day==count；月末优先换行。
  401679:	83 45 f4 01          	add    DWORD PTR [ebp-0xc],0x1
  40167d:	8b 45 f0             	mov    eax,DWORD PTR [ebp-0x10]
  401680:	3b 45 e4             	cmp    eax,DWORD PTR [ebp-0x1c]
  401683:	75 0e                	jne    401693 <_render_calendar+0xb1>
  401685:	c7 04 24 0a 00 00 00 	mov    DWORD PTR [esp],0xa
  40168c:	e8 0f 80 00 00       	call   4096a0 <_putchar>
  401691:	eb 27                	jmp    4016ba <_render_calendar+0xd8>
; 若不是月末，检查 column==7；满 7 列换行并把 column 清零。
  401693:	83 7d f4 07          	cmp    DWORD PTR [ebp-0xc],0x7
  401697:	75 15                	jne    4016ae <_render_calendar+0xcc>
  401699:	c7 04 24 0a 00 00 00 	mov    DWORD PTR [esp],0xa
  4016a0:	e8 fb 7f 00 00       	call   4096a0 <_putchar>
  4016a5:	c7 45 f4 00 00 00 00 	mov    DWORD PTR [ebp-0xc],0x0
  4016ac:	eb 0c                	jmp    4016ba <_render_calendar+0xd8>
; 既非月末又未满 7 列，输出一个空格。
  4016ae:	c7 04 24 20 00 00 00 	mov    DWORD PTR [esp],0x20
  4016b5:	e8 e6 7f 00 00       	call   4096a0 <_putchar>
; day++；若 day<=count，跳回 401666 继续打印。
  4016ba:	83 45 f0 01          	add    DWORD PTR [ebp-0x10],0x1
  4016be:	8b 45 f0             	mov    eax,DWORD PTR [ebp-0x10]
  4016c1:	3b 45 e4             	cmp    eax,DWORD PTR [ebp-0x1c]
  4016c4:	7e a0                	jle    401666 <_render_calendar+0x84>
  4016c6:	90                   	nop
; LEAVE 相当于 MOV ESP,EBP / POP EBP，RET 返回调用者。
  4016c7:	c9                   	leave
  4016c8:	c3                   	ret
```
## 与手写 16 位程序的调用约定比较

本 C 构建中，调用者先在栈上预留空间，再把参数写到 `[ESP]`、`[ESP+4]` 等位置，未必逐个 PUSH。CALL 压入 4 字节返回 EIP，被调用函数 PUSH EBP 后，第一个参数便位于 `[EBP+8]`。函数只执行 RET；参数区属于调用者的栈空间，由调用者管理。

手写 8086 的 `first_weekday` 明确用 PUSH 传两个 word，近 CALL 只压入 2 字节返回 IP，建立 BP 帧后参数偏移是 `[BP+4]` 和 `[BP+6]`，并约定由被调用者 `RET 4` 清理。两种约定不能混用。

C 的 month_names 对应静态指针表 `names`，位于程序静态存储区；`first`、`count`、`column`、`day`、`i` 则在当前函数栈帧中。反汇编中 `[eax*4+0x40a020]` 展示静态数组寻址，`[EBP-...]` 展示局部变量寻址。手写 16 位版的月份名称偏移表每项是 2 字节，因此使用 SHL BX,1。

## 从源码到反汇编的核对方法

1. 重新运行 `BUILD.BAT`，从实际 EXE 生成完整的 `CAL_C.DISASM.txt`。
2. 搜索 `_leap_year`、`_first_weekday`、`_render_calendar`，逐段对照本文件；若换编译器，地址和指令选择可能改变。
3. 用 1900/2 和 2000/2 验证闰年分支，用 2026/8 验证前导空位、满列换行和第六行。
4. 反汇编中的地址与字节是这次构建的记录；算法正确性另外由 2400 个月的独立参考结果检验。
