; Homework 3: accumulate in a word on the stack, addressed by SS:BP.
.model small
.stack 100h
.code
start:
    push bp                   ; Save caller's BP.
    xor ax,ax
    push ax                   ; Allocate and initialize a 16-bit local sum.
    mov bp,sp                 ; [BP] uses SS by default on 8086.
    mov bx,1
    mov cx,100
sum_loop:
    add word ptr [bp],bx      ; Update the stack variable on every iteration.
    inc bx
    loop sum_loop
sum_done:                     ; SS:BP contains BA 13; SP=00FCh.
    mov ax,[bp]
    add sp,2                  ; Release exactly the local word.
    pop bp                    ; Restore BP; SP is now 0100h again.
stack_restored:
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
