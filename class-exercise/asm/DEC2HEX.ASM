; Extra classroom exercise: unsigned decimal 0..65535 -> hexadecimal.
.model small
.stack 100h
.data
prompt db 'Please input a Dec number (0-65535):',13,10,'$'
answer db 'The Hex number:',13,10,'$'
error_msg db 'Error: enter 1-5 decimal digits in 0..65535.',13,10,'$'
input_buf db 64,0,64 dup (0)
.code
start:
    mov ax,@data
    mov ds,ax
    lea dx,prompt
    call puts
    lea dx,input_buf
    mov ah,0ah
    int 21h
    call newline
    xor cx,cx
    mov cl,input_buf[1]
    jcxz bad_input
    cmp cl,5
    ja bad_input
    jmp parse_start
bad_input:
    lea dx,error_msg
    call puts
    mov ax,4c01h
    int 21h
parse_start:
    lea si,input_buf[2]
    xor ax,ax
    mov bx,10
parse_digit:
    mov dl,[si]
    cmp dl,'0'
    jb bad_input
    cmp dl,'9'
    ja bad_input
    sub dl,'0'
    xor dh,dh
    mov di,dx                 ; Preserve digit across MUL (overwrites DX).
    mul bx                    ; Unsigned DX:AX = previous value * 10.
    or dx,dx
    jnz bad_input             ; Reject overflow, e.g. 99999.
    add ax,di
    jc bad_input              ; Reject overflow, e.g. 65536.
    inc si
    loop parse_digit
    lea dx,answer
    call puts
    call print_hex
    call newline
    mov ax,4c00h
    int 21h

; Print unsigned AX in uppercase hex, no prefix or unnecessary leading zero.
print_hex proc near
    push ax
    push bx
    push cx
    push dx
    mov bx,16
    xor cx,cx
hex_split:
    xor dx,dx
    div bx
    push dx
    inc cx
    or ax,ax
    jnz hex_split
hex_write:
    pop dx
    cmp dl,9
    jbe hex_numeric
    add dl,'A'-10
    jmp hex_output
hex_numeric:
    add dl,'0'
hex_output:
    mov ah,02h
    int 21h
    loop hex_write
    pop dx
    pop cx
    pop bx
    pop ax
    ret
print_hex endp

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
