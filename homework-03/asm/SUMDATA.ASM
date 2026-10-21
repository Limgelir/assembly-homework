; Homework 3: accumulate directly in a 16-bit data-segment variable.
.model small
.stack 100h
.data
total dw 0                    ; A byte cannot hold 5050; use a word.
.code
start:
    mov ax,@data
    mov ds,ax
    mov total,0
    mov bx,1
    mov cx,100
sum_loop:
    add total,bx              ; Actual accumulator is DS:total.
    inc bx
    loop sum_loop
sum_done:                     ; DS:total contains BA 13 (little endian).
    mov ax,total
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
