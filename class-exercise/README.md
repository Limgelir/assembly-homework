# 课堂练习：进制转换

已完成基本要求（1～2 位十六进制数转十进制）和追加要求（十进制转十六进制）。两个程序相互独立，每次运行读取一行，按 Enter 后输出结果或错误提示并退出。

| 方向 | 源码 | DOS 程序 | 输入范围 | 输出 |
| --- | --- | --- | --- | --- |
| 十六进制 → 十进制 | [HEX2DEC.ASM](asm/HEX2DEC.ASM) | [HEX2DEC.EXE](asm/HEX2DEC.EXE) | 1～2 位，0～FF，接受大小写 | 0～255，无多余前导零 |
| 十进制 → 十六进制 | [DEC2HEX.ASM](asm/DEC2HEX.ASM) | [DEC2HEX.EXE](asm/DEC2HEX.EXE) | 1～5 位，0～65535 | 0～FFFF，大写，无 0x 前缀 |

追加要求没有指定数值范围，因此采用 16 位无符号整数范围 0～65535。两个方向都接受符合长度限制的前导零；不接受正负号、空格、小数点、0x 前缀、空输入、超长或超范围数字。正常退出码为 0，错误退出码为 1。

## 运行与验收

本机已把 asm 目录的文件同步到 `D:\ASM\CONVERT`。老师提供的 DOSBox 启动配置会将 `D:\ASM` 挂载为 C 盘。

1. 打开 DOSBox，输入：

   ```dos
   c:
   cd \convert
   hex2dec
   ```

2. 输入 `ff`，按 Enter，应看到：

   ```text
   Please input a Hex number (1-2 digits):
   ff
   The Dec number:
   255
   ```

3. 输入 `dec2hex`，输入 `255` 后按 Enter，应输出 `FF`。
4. 重新运行对应程序，检查下表。每次只输入表中的“输入”内容，不包含引号。

| 程序 | 输入 | 预期 |
| --- | --- | --- |
| hex2dec | 0 | 0 |
| hex2dec | a | 10 |
| hex2dec | 10 | 16 |
| hex2dec | aB | 171 |
| hex2dec | FF | 255 |
| hex2dec | G、FFF，或直接 Enter | Error 提示 |
| dec2hex | 0 | 0 |
| dec2hex | 16 | 10 |
| dec2hex | 255 | FF |
| dec2hex | 4096 | 1000 |
| dec2hex | 65535 | FFFF |
| dec2hex | 65536、-1，或直接 Enter | Error 提示 |

若在其他电脑验收，将 asm 目录复制到 DOSBox 可访问的目录；也可以挂载整个克隆仓库为新盘，从 `class-exercise\asm` 运行。两份 EXE 是 16 位 DOS 程序，需在 DOSBox 中启动。

## 自动验收

在 Windows PowerShell 中进入仓库根目录，执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\class-exercise\verify.ps1
```

如 DOSBox 安装路径不同，在命令末尾添加 `-DosBoxPath '实际的DOSBox.exe路径'`。脚本依赖仓库内的 [公共验收脚本](../tools/verify-programs.ps1)，应保留整个仓库目录结构。

预期显示：

```text
PASS conversion: 333 DOS cases, 0 C cases; exact output and exit codes verified.
```

测试包含全部 256 个字节的十六进制输入、全部 16 个单数字输入、大小写混合、十进制转换的进位边界和 16 位边界，以及 30 个非法输入。每项检查完整输出和退出码，不只是查找某个数字。运行细节保存在被 Git 忽略的 `.verify` 目录，已提交本次 [333 项实际结果](verification/RESULTS.TXT)。

## 怎样编译

在 DOSBox 的程序目录运行：

```dos
path c:\
build
```

本机的 MASM.EXE 和 LINK.EXE 位于 C 盘根目录。若工具放在其他位置，请相应设置 PATH。也可以逐个执行：

```dos
masm HEX2DEC.ASM,HEX2DEC.OBJ,HEX2DEC.LST;
link HEX2DEC.OBJ;
masm DEC2HEX.ASM,DEC2HEX.OBJ,DEC2HEX.LST;
link DEC2HEX.OBJ;
```

使用 MASM 5.00 / LINK 3.60，两份 LST 均为 0 Warning Errors、0 Severe Errors。源码采用 ASCII 编码以兼容旧工具；中文说明在本文中。

## 程序原理

**十六进制输入。** 字符不是数值本身：例如字符 `'9'` 的 ASCII 编码是 39h，要减去 `'0'` 才得到数值 9。字母转换为大写并检查 A～F，再得到 10～15。每读一个数字更新 `value = value*16 + digit`，乘 16 用四次 `SHL BX,1`，兼容 8086。例如 ff：先得到 15，再得到 15×16+15=255。

**十进制输入。** 逐个字符检查 0～9，并更新 `value = value*10 + digit`。无符号 `MUL BX` 把乘积放在 DX:AX，检查 DX 是否非零；加上当前数字后检查 CF。这样 65536、70000、99999 会报错，不会把溢出后的低 16 位当作正确结果。

**输出。** 把数值不断除以目标进制：十进制除以 10，十六进制除以 16。每次把余数压栈，最后依次出栈输出。循环至少执行一次，因此输入 0 时也会输出字符 0。每次 `DIV BX` 前先清零 DX，保证被除数 DX:AX 正确。十六进制的余数 10～15 输出 A～F。

例如 255 转十六进制：255÷16=15 余 15，15÷16=0 余 15，逆序输出 FF。这里的除法、余数与字符转换都由程序完成。

## 使用的 DOS 服务

输入调用 `INT 21h`，AH=0Ah，DS:DX 指向缓冲区。缓冲区第一个字节是容量（包括回车），第二个字节由 DOS 返回实际字符数（不包括回车），后面存放输入字符；支持键盘行编辑。输出使用 AH=02h（DL 中的字符）、AH=09h（DS:DX 指向的 $ 结尾字符串），AH=4Ch 返回退出码。

依据：[Microsoft《MS-DOS 3.3 Programmer's Reference》系统调用表与 Buffered Keyboard Input](https://www.pcjs.org/documents/books/mspl13/msdos/dosref33/)（PCjs 保存的原版文档）。本程序容量为 64，允许 DOS 接收最多 63 个字符，然后由程序检查题目要求的位数。

## 实测材料

2026-10-21 使用 DOSBox 0.74 运行验证。

- [ff → 255 的原始输出](verification/hex-ff.txt)
- [65535 → FFFF 的原始输出](verification/dec-65535.txt)
- [65536 越界拒绝](verification/dec-overflow.txt)
- [完整验收结果](verification/RESULTS.TXT)
- [构建日志](verification/build.txt)
- [源文件和 EXE 的 SHA-256](verification/SHA256SUMS.txt)

原始输出包含 DOS 输入回显的 CR 和程序随后输出的 CRLF，某些文本查看器可能把连续回车显示为空行；DOSBox 屏幕显示不受影响。
