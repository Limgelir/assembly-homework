; Homework 3: read n (1..100), then compute 1+2+...+n.
.model small
.stack 100h
.data
prompt db 'Please input n (1-100):',13,10,'$'
answer db 'Sum:',13,10,'$'
error_msg db 'Error: enter 1-3 decimal digits in 1..100.',13,10,'$'
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
    cmp cl,3
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
    cmp ax,1
    jb bad_input
    cmp ax,100
    ja bad_input
    mov cx,ax                 ; Check range before LOOP; n=0 is rejected.
    xor ax,ax
    mov bx,1
sum_loop:
    add ax,bx
    inc bx
    loop sum_loop
sum_done:
    lea dx,answer
    call puts                 ; Preserve AX: AH=09h alone would corrupt sum.
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
