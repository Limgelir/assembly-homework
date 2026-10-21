; Classroom exercise: 1-2 hexadecimal digits -> unsigned decimal.
.model small
.stack 100h
.data
prompt db 'Please input a Hex number (1-2 digits):',13,10,'$'
answer db 'The Dec number:',13,10,'$'
error_msg db 'Error: enter 1-2 hex digits (0-9, A-F or a-f).',13,10,'$'
input_buf db 64,0,64 dup (0)  ; Max includes CR; count excludes CR.
.code
start:
    mov ax,@data
    mov ds,ax
    lea dx,prompt
    call puts
    lea dx,input_buf
    mov ah,0ah                ; Buffered input; supports Backspace and Enter.
    int 21h
    call newline
    xor cx,cx
    mov cl,input_buf[1]
    jcxz bad_input
    cmp cl,2
    ja bad_input
    jmp parse_start
bad_input:
    lea dx,error_msg
    call puts
    mov ax,4c01h
    int 21h
parse_start:
    lea si,input_buf[2]
    xor bx,bx
parse_digit:
    mov al,[si]
    cmp al,'0'
    jb bad_input
    cmp al,'9'
    jbe numeric_digit
    and al,0dfh               ; Lowercase a-f -> uppercase A-F.
    cmp al,'A'
    jb bad_input
    cmp al,'F'
    ja bad_input
    sub al,'A'-10
    jmp accumulate
numeric_digit:
    sub al,'0'
accumulate:
    xor ah,ah
    shl bx,1                  ; Four one-bit shifts are valid on 8086.
    shl bx,1
    shl bx,1
    shl bx,1
    add bx,ax                 ; value = value * 16 + digit.
    inc si
    loop parse_digit
    mov ax,bx
    lea dx,answer
    call puts
    call print_dec
    call newline
    mov ax,4c00h
    int 21h

; Print unsigned AX (0..65535) in decimal; preserve AX/BX/CX/DX.
print_dec proc near
    push ax
    push bx
    push cx
    push dx
    mov bx,10
    xor cx,cx
decimal_split:
    xor dx,dx                 ; DIV uses DX:AX, not AX alone.
    div bx
    push dx                   ; Save remainder, least significant first.
    inc cx
    or ax,ax
    jnz decimal_split
decimal_write:
    pop dx                    ; Reverse order gives most significant first.
    add dl,'0'
    mov ah,02h
    int 21h
    loop decimal_write
    pop dx
    pop cx
    pop bx
    pop ax
    ret
print_dec endp

; Print the '$'-terminated string at DS:DX; preserve AX.
puts proc near
    push ax
    mov ah,09h
    int 21h
    pop ax
    ret
puts endp

newline proc near
    push ax
    push dx
    mov dl,0dh
    mov ah,02h
    int 21h
    mov dl,0ah
    mov ah,02h
    int 21h
    pop dx
    pop ax
    ret
newline endp

end start
