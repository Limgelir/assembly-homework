; Homework 3: accumulate 1+2+...+100 in register AX.
.model small
.stack 100h
.code
start:
    xor ax,ax
    mov bx,1
    mov cx,100
sum_loop:
    add ax,bx
    inc bx
    loop sum_loop
sum_done:                     ; AX=13BAh=5050, BX=101, CX=0.
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
