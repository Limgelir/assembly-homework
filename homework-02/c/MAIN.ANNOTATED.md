# C 程序 main 函数反汇编注释

下面的指令从本目录实际生成的 [ASCII_C.EXE](ASCII_C.EXE) 中提取，并逐条添加中文注释。完整原始输出保存在 [ASCII_C.DISASM.txt](ASCII_C.DISASM.txt)，原始 C 代码为 [ascii.c](ascii.c)。

编译器为 MinGW GCC 6.3.0，目标为 `mingw32`；反汇编工具为 GNU objdump 2.28，使用 Intel 语法。该 EXE 是 Windows 32 位 x86 程序，反汇编中的地址对应本次提交的 EXE。

## 生成方式

在 Windows 中进入本目录，运行 `BUILD.BAT`。其中使用 `-O0` 关闭优化，保留 C 局部变量与循环之间的直观对应关系；使用 `-g` 保留调试信息。

实际反汇编命令：

```bat
objdump -d -M intel ASCII_C.EXE > ASCII_C.DISASM.txt
```

## 栈中变量

函数对齐 ESP 并分配栈空间后，局部变量和输出参数对应如下。下列偏移均为十六进制，DWORD 为 4 字节。

| 地址 | C 中的含义 |
| --- | --- |
| `[esp+14h]` | `character`，初值为 `'a'`，即 `61h` |
| `[esp+18h]` | `column`，每行从 0 到 12 |
| `[esp+1Ch]` | `row`，从 0 到 1 |
| `[esp]` | 调用 `putchar` 时传递的第一个参数 |

## 带注释的反汇编

```asm
00401460 <_main>:
401460: push ebp                           ; 保存调用者的栈帧基址。
401461: mov  ebp,esp                       ; 建立当前函数的栈帧。
401463: and  esp,0xfffffff0                ; 将栈顶向下对齐到 16 字节。
401466: sub  esp,0x20                      ; 分配 32 字节，容纳局部变量与调用参数。
401469: call 401a10 <___main>              ; MinGW 运行库初始化辅助函数。

40146e: mov  DWORD PTR [esp+0x14],0x61     ; character = 'a'，ASCII 码 61h。
401476: mov  DWORD PTR [esp+0x1c],0x0      ; row = 0。
40147e: jmp  4014cb <_main+0x6b>           ; 首次进入外层循环前先检查 row < 2。

401480: mov  DWORD PTR [esp+0x18],0x0      ; 每行开始时 column = 0。
401488: jmp  4014b3 <_main+0x53>           ; 首次进入内层循环前先检查 column < 13。

40148a: cmp  DWORD PTR [esp+0x18],0x0      ; 判断 column 是否为 0。
40148f: je   40149d <_main+0x3d>           ; 第一列直接打印字母，不先打印空格。
401491: mov  DWORD PTR [esp],0x20          ; 准备 putchar 的参数：空格，ASCII 20h。
401498: call 403ab0 <_putchar>             ; putchar(' ')。

40149d: mov  eax,DWORD PTR [esp+0x14]      ; 将当前 character 读入 EAX。
4014a1: mov  DWORD PTR [esp],eax           ; 将 character 放到函数参数位置。
4014a4: call 403ab0 <_putchar>             ; putchar(character)，打印当前字母。
4014a9: add  DWORD PTR [esp+0x14],0x1      ; ++character，转到下一个 ASCII 字母。
4014ae: add  DWORD PTR [esp+0x18],0x1      ; ++column。

4014b3: cmp  DWORD PTR [esp+0x18],0xc      ; 比较 column 与 12（0Ch）。
4014b8: jle  40148a <_main+0x2a>           ; column <= 12 时继续，即 column < 13。

4014ba: mov  DWORD PTR [esp],0xa           ; 准备换行字符 '\n'，ASCII 0Ah。
4014c1: call 403ab0 <_putchar>             ; 一行 13 个字母完成后输出换行。
4014c6: add  DWORD PTR [esp+0x1c],0x1      ; ++row。

4014cb: cmp  DWORD PTR [esp+0x1c],0x1      ; 比较 row 与 1。
4014d0: jle  401480 <_main+0x20>           ; row <= 1 时继续，即 row < 2。

4014d2: mov  eax,0x0                      ; return 0，返回值通过 EAX 传递。
4014d7: leave                             ; ESP 恢复到 EBP，并恢复调用者 EBP。
4014d8: ret                               ; 返回到调用 main 的运行库代码。
```

完整反汇编中 `4014D9` 至 `4014DE` 的 `NOP`、`XCHG AX,AX` 是下一函数之前的对齐填充，位于 `RET` 之后。

## 与 C 源代码的对应关系

1. 两个 `for` 循环均被编译为初始化、条件比较、条件跳转、循环体和递增操作；本次生成的代码没有使用 `LOOP` 指令。
2. `column`、`row` 的类型为有符号 `int`，因此这里使用有符号条件跳转 `JLE`。从 0 开始递增时，`column <= 12` 与 `column < 13` 等价，`row <= 1` 与 `row < 2` 等价。
3. `CMP` 根据减法比较更新标志位，不修改被比较的变量；`JE` 使用 ZF，`JLE` 判断 `ZF=1` 或 `SF!=OF`。
4. `putchar` 接受一个 `int` 参数。本例使用 x86 C 调用约定，把参数写入已经预留的栈空间 `[esp]` 后执行 `CALL`，每次调用复用这块参数空间。
5. `CALL` 会将返回地址压栈，`RET` 取回返回地址继续执行。EAX 也是函数返回值寄存器，程序不使用 `putchar` 的返回值。
6. C 源代码输出 `\n`。Windows C 运行库的标准输出默认采用文本模式，将其转换为 CRLF；实际重定向输出已验证与 DOS 程序完全一致。

源码中没有定义全局字符串缓冲区；字母由整数变量 `character` 递增生成。每行仅在非第一列之前输出空格，因此没有行首和行尾空格。
