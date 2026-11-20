# 作业七实验报告：模块、宏与调用现场

## 一、实验结构

目标环境：8086 实模式，DOSBox 0.74、MASM 5.00、LINK 3.60、FreeDOS DEBUG 2.50。月历算法沿用作业六：完整公历闰年规则，先计算月初星期，再按七列输出。

```text
MAIN.ASM   -> MAIN.OBJ   --+
INPUT.ASM  -> INPUT.OBJ  --+
DATE.ASM   -> DATE.OBJ   --+--> LINK --> CALENDAR.EXE + CALENDAR.MAP
SCREEN.ASM -> SCREEN.OBJ --+
DATA.ASM   -> DATA.OBJ   --+

MAIN / INPUT / SCREEN 在各自汇编时 INCLUDE MACROS.INC
```

五个 ASM 都是独立汇编单元，只有 MAIN 用 `END start` 指定入口，其他模块用 `END` 结束。DATA 独立定义变量，其他模块只用 EXTRN 声明类型，不重复分配存储空间。

MAIN、INPUT、DATE 使用同名 `core segment para public 'CODE'`。这里的 **public 组合属性**告诉链接器合并这些同名段；SCREEN 使用不同段名。与此不同，`PUBLIC first_weekday` 是把符号导出供其他 OBJ 引用，两种 PUBLIC 的作用不要混淆。

本次 MAP 给出以下相对装载基址的布局：

| 段 | 起始相对地址 | 长度 |
| --- | --- | --- |
| DATA | 00000h | 0172h |
| STACK_SEG | 00180h | 0400h，1024 字节 |
| CORE | 00580h | 01A6h |
| SCREEN | 00730h | 00CDh |

CORE 内 MAIN 从 0000 开始，INPUT 的 `read_number` 在 00A0，DATE 的 `leap_year` 在 0100。模块段片段使用 PARA 对齐，链接后的偏移可能不同于各自 LST 中从 0000 开始的偏移。用 MAP 查最终位置，用 DEBUG 查看装载后的机器码。

## 二、PUBLIC / EXTRN 与链接

DATE 中导出 `first_weekday`，MAIN 在 CORE 段内声明 `extrn first_weekday:near`，然后 `call first_weekday`。它们来自两个文件，但最终处于同一 CORE 段，因此可以使用近调用。

SCREEN 导出 FAR 类型的 `render_calendar`，MAIN 声明 `extrn render_calendar:far`，使用 `call far ptr render_calendar`。过程最后执行 RETF。

MAIN.LST 中跨文件调用仍显示待修正的外部地址，例如：

```text
0066  E8 0000 E       call first_weekday
006C  9A 0000 ---- E  call far ptr render_calendar
```

这不是最终执行目标为零。OBJ 含有外部符号和修正信息，LINK 解析 PUBLIC/EXTRN 后填入偏移；DOS 装载 EXE 时再处理段地址重定位。DEBUG 中看到的才是运行地址。

DS 在 MAIN 中用 `mov ax,data / mov ds,ax` 明确初始化。其他模块沿用同一个 DS。ASSUME 只服务于汇编器，不会自动修改 CPU 寄存器。SS:SP 由 DOS 根据 EXE 头设置，本程序开始时 SP=0400h。

## 三、宏汇编的实际使用

MACROS.INC 定义三个宏：

| 宏 | 使用位置 | 展开内容 |
| --- | --- | --- |
| PRINT_TEXT message | MAIN、SCREEN | LEA DX,message；CALL FAR PTR write_string |
| NEW_LINE | INPUT、SCREEN | CALL FAR PTR crlf |
| REQUIRE_RANGE value,lower,upper,failure | MAIN 两次 | 两次 CMP、条件跳转和越界分支；LOCAL 生成独立标签 |

MAIN 中的 `REQUIRE_RANGE ax,1900,2099,bad_year` 和 `REQUIRE_RANGE ax,1,12,bad_month` 分别展开成两个检查块。MAIN.LST 显示第一处 LOCAL 标签为 `??0000`、`??0001`，第二处为 `??0002`、`??0003`，不会重复定义。

```asm
REQUIRE_RANGE macro value,lower,upper,failure
    local lower_ok,range_ok
    cmp value,lower
    jae short lower_ok
    jmp near ptr failure
lower_ok:
    cmp value,upper
    jbe short range_ok
    jmp near ptr failure
range_ok:
endm
```

宏在汇编时展开，没有名为 REQUIRE_RANGE 的运行时过程，也不会因“调用宏”而压入返回地址。此宏只做比较和跳转，不改 SP。PRINT_TEXT 和 NEW_LINE 展开内容本身包含真正的 CALL，所以它们会因为那条 CALL 产生返回地址；不能说“宏永远不使用栈”。

优点是减少重复源码、可参数化；代价是每次使用都会复制指令，频繁展开较长宏会增加代码大小。过程调用只保留一份过程体，但运行时需跳转、保存返回地址并遵守寄存器约定。

本次 MASM 把部分源代码中的 `JMP NEAR PTR` 缩成短 JMP 加 NOP，例如 CORE:001D 的 `EB 57 90`。因此不能只看源码关键字猜最终字节，应以 LST/DEBUG 为准。反向短条件跳过无条件跳转的结构仍可处理较远目标；作业六的同类位置实际生成了 E9 近跳转。

## 四、三类调用的真实机器码

记录来自 [trace-202611.txt](verification/trace-202611.txt)，本次装载 CORE=0796h、SCREEN=07B1h。段值随装载环境变化，偏移由本次构建决定。

| 类别 | CALL 位置及字节 | 目标 | 返回指令 |
| --- | --- | --- | --- |
| 同文件、同段 NEAR | SCREEN:000E `E8 80 00` | SCREEN:0091，print_unsigned | SCREEN:00B1 `C3`，RET |
| 跨文件、同段 NEAR | CORE:0066 `E8 E5 00` | CORE:014E，first_weekday | CORE:01A3 `C2 04 00`，RET 4 |
| 跨文件、跨段 FAR | CORE:006C `9A 00 00 B1 07` | SCREEN:0000，render_calendar | SCREEN:0080 `CB`，RETF |

近调用 E8 后面是相对**下一条指令 IP**的 16 位位移，小端存储：

```text
同文件：000Eh + 3 + 0080h = 0091h
跨文件：0066h + 3 + 00E5h = 014Eh
```

远调用 9A 后面依次是 offset16、segment16：`00 00` 是偏移 0000，`B1 07` 是装载后的段 07B1。这种立即数 FAR CALL 共 5 字节。

对照作业六的 [原始跟踪](../homework-06/verification/trace-202611.txt)：

| 实验 | 文件关系 | 实际字节 | 结论 |
| --- | --- | --- | --- |
| 作业六 CORE 内 first_weekday | 同一 ASM、同一段 | `E8 B6 00` | NEAR，只保存 IP |
| 作业七 MAIN → DATE | 不同 ASM、同一合并段 | `E8 E5 00` | 仍是 NEAR，只是目标布局改变使位移改变 |
| 作业六 CORE → SCREEN | 同一 ASM、两个段 | `9A 00 00 B0 07` | FAR，保存 CS/IP |
| 作业七 MAIN → SCREEN | 不同 ASM、两个段 | `9A 00 00 B1 07` | 仍是 FAR，装载后的目标段改变 |

**文件边界是汇编和链接层面的组织方式，不是 CPU 的调用种类。** CPU 执行 CALL 时不会知道源代码来自哪个文件。决定保存 IP 还是 CS:IP 的是 CALL 指令本身的近/远形式。

本例 SCREEN 中还对同段的 `crlf` 使用 FAR CALL/RETF：它是供其他段调用的 FAR 接口，保持接口一致。因此“同段一定只能用近调用”也不正确；同段可以使用 FAR 形式，届时同样压入 CS/IP，只是加载的 CS 数值与原值相同。

## 五、栈及寄存器实测

表中数值均为十六进制，SP 变化只描述指定观察点，不包括过程内部更深的辅助调用。

### 1. MAIN → DATE：跨文件 NEAR 和栈参数

调用前先 PUSH 月份，再 PUSH 年份，SP 从 0400 变为 03FC：

```text
SS:03FC  EA 07   年份 07EA = 2026
SS:03FE  0B 00   月份 000B = 11
```

CALL 后 IP=014E、SP=03FA，CS 保持 CORE：

```text
SS:03FA  69 00   返回 IP=0069
SS:03FC  EA 07   年份
SS:03FE  0B 00   月份
```

过程执行 PUSH BP / MOV BP,SP，并保存 BX/CX/DX/SI/DI 后，BP=03F8、SP=03EE。因此 `[BP+4]` 是年份、`[BP+6]` 是月份。BP 默认使用 SS 寻址。

恢复寄存器后，停在 RET 4 时 SP=03FA、AX=0（星期日）。RET 4 先弹出返回 IP，再额外加 SP,4 清理参数。返回后 IP=0069、SP=0400、CS 不变，调用者不能重复清理参数。

### 2. MAIN → SCREEN：跨文件 FAR

CALL 前 CORE:006C、SP=0400。刚进入 SCREEN:0000，SP=03FC：

```text
SS:03FC  71 00   返回 IP=0071
SS:03FE  96 07   原 CS=0796（本次装载值）
```

FAR CALL 先压入原 CS，再压入返回 IP，因此栈顶是 IP。RETF 依次弹入 IP 和 CS。显示过程退出前已经反向恢复 AX/BX/CX/DX/SI/DI；RETF 后回到 CORE:0071，SP=0400。

### 3. SCREEN 内部 NEAR

显示过程先保存六个通用寄存器，SP=03F0。在 SCREEN:000E 调用 print_unsigned，刚进入 SCREEN:0091 时 SP=03EE，CS 不变：

```text
SS:03EE  11 00   返回 IP=0011
```

内部数字转换过程保存寄存器并借栈暂存十进制余数，退出前全部恢复。停在 SCREEN:00B1 的 RET 时 SP 又是 03EE。执行 RET 后 IP=0011、SP=03F0、CS 不变。

自动验收分别比较这些调用前后的寄存器、CS/IP/SP、栈上返回地址、传入参数和实际机器码。标志寄存器不属于这些过程的保存约定。

## 六、手动单步操作

DOSBox 中进入 HW07，执行 `path c:\`，再执行 `debug CALENDAR.EXE`。逐行输入下列命令（DEBUG 数字默认为十六进制）：

```text
g 5
e ds:0 ea 07 0b 00
u 0 51
g =51 66
d ss:3fc l 4
t
g 156
d ss:3f8 l 8
g 1a3
t
g 6c
d ds:0 l 8
t
u 0 11
d ss:3fc l 4
g e
t
d ss:3ee l 2
g b1
t
g 80
t
g
q
```

- 第一个 `t` 执行 MAIN → DATE 的 NEAR CALL；下一个 `t` 执行 RET 4。
- `g 6c` 后的 `t` 执行 FAR CALL，观察 CS 切换与栈中两个返回 word。
- `g e` 后的 `t` 执行 SCREEN 内 NEAR CALL；`g b1` 后的 `t` 执行普通 RET。
- `g 80` 后的 `t` 执行 RETF，回到原 CORE 段，SP=0400。

`g =51 66` 的等号设置开始执行位置，其后 66 是断点；普通 `g 156` 是从当前位置继续运行到断点，不是设置 IP。本脚本跳过输入，直接设定共享数据，输入功能由正常运行和自动用例验证。

如源码改变，先按新 MAP 和 DEBUG `u` 核对偏移。绝对 CS 段值随加载位置变化，本脚本依赖当前 CS 和段寄存器别名，不硬编码 0796/07B1。

## 七、验收结论

五个模块分别汇编，均为 0 警告、0 错误；链接产生两个实际代码段。2433 项 DOS 输入测试全部通过，覆盖 1900～2099 的 2400 个月及输入边界；4 组 DEBUG 跟踪各检查三类调用，全部通过。完整记录见 [RESULTS.TXT](verification/RESULTS.TXT)，构建输出见 [build.txt](verification/build.txt)。

本题重点是汇编的多模块和宏机制。月历算法与作业六相同，其 C 对照及反汇编可参阅 [作业六 C 分析](../homework-06/c/ANNOTATED.md)。
