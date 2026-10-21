.model small
.stack 100h

.code
start:
    mov bl,'a'
    mov cx,2

row_jump:
    push cx                    ; Preserve the outer counter.
    mov cx,13

column_jump:
    mov dl,bl
    call put_char
    inc bl
    dec cx                     ; DEC sets ZF when the result is zero.
    jnz column_gap             ; Conditional jump replaces the inner LOOP.
    jmp row_end

column_gap:
    mov dl,' '
    call put_char
    jmp column_jump

row_end:
    mov dl,0dh
    call put_char
    mov dl,0ah
    call put_char
    pop cx
    dec cx
    jnz row_jump               ; Conditional jump replaces the outer LOOP.

    mov ax,4c00h
    int 21h

put_char proc near
    mov ah,02h
    int 21h
    ret
put_char endp

end start
