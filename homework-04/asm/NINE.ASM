; Homework 4: reverse triangular multiplication table, 8086 / DOS.
; BH = row (9..1), BL = column (1..row), CX = current loop count.
.model small
.stack 100h
.data
heading db 'The 9mul9 table:',13,10,'$'
.code
start:
    mov ax,@data
    mov ds,ax
    lea dx,heading
    mov ah,09h
    int 21h
    mov bh,9
    mov cx,9
row_loop:
    push cx                   ; Save OUTER loop counter.
    xor cx,cx
    mov cl,bh                 ; INNER loop: row cells.
    mov bl,1
column_loop:
    call print_cell           ; Callee preserves main's AX/BX/CX/DX.
after_cell:
    inc bl
    loop column_loop
    call newline
    pop cx                    ; Restore OUTER loop counter.
    dec bh
    loop row_loop
table_done:
    mov ax,4c00h
    int 21h

; Input BH=row, BL=column. Print r*c=product, padded to 9 columns
; except at the end of a row. Preserve AX/BX/CX/DX; flags may change.
print_cell proc near
    push ax
    push bx
    push cx
    push dx
    mov dl,bh
    call print_digit
    mov dl,'*'
    call put_char
    mov dl,bl
    call print_digit
    mov dl,'='
    call put_char
    mov al,bh
    mul bl                    ; 8-bit unsigned multiply: AX = AL * BL.
product_ready:                ; 9*1: AX=0009; 9*9: AX=0051.
    call print_dec
    cmp bl,bh
    je cell_done              ; No trailing spaces at end of row.
    mov cx,4                  ; Single-digit product: 5 chars + 4 spaces.
    cmp ax,10
    jb pad_cell
    dec cx                    ; Two-digit product: 6 chars + 3 spaces.
pad_cell:
    mov dl,' '
pad_loop:
    call put_char
    loop pad_loop             ; Reuses main's CX, saved on entry.
cell_done:
    pop dx
    pop cx
    pop bx
    pop ax
cell_return:
    ret                       ; Pop return IP pushed by near CALL.
print_cell endp

; Input DL=0..9; output a digit. Changes DL; preserves AX.
print_digit proc near
    add dl,'0'
    call put_char
    ret
print_digit endp

; Print unsigned AX in decimal (also handles 0). Preserve AX/BX/CX/DX.
print_dec proc near
    push ax
    push bx
    push cx
    push dx
    mov bx,10
    xor cx,cx
decimal_split:
    xor dx,dx                 ; DIV uses DX:AX as its dividend.
    div bx
    push dx
    inc cx
    or ax,ax
    jnz decimal_split
decimal_write:
    pop dx
    add dl,'0'
    call put_char
    loop decimal_write
    pop dx
    pop cx
    pop bx
    pop ax
    ret
print_dec endp

; Input DL=character. Preserve AX, so DOS AH=02h cannot destroy product.
put_char proc near
    push ax
    mov ah,02h
    int 21h
    pop ax
    ret
put_char endp

newline proc near
    push dx
    mov dl,13
    call put_char
    mov dl,10
    call put_char
    pop dx
    ret
newline endp

end start
