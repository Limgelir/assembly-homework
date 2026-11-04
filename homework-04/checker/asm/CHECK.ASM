; Homework 4 part 2: check all 81 bytes; report 1-based row/column.
data segment para public 'DATA'
table db 7,2,3,4,5,6,7,8,9
      db 2,4,7,8,10,12,14,16,18
      db 3,6,9,12,15,18,21,24,27
      db 4,8,12,16,7,24,28,32,36
      db 5,10,15,20,25,30,35,40,45
      db 6,12,18,24,30,7,42,48,54
      db 7,14,21,28,35,42,49,56,63
      db 8,16,24,32,40,48,56,7,72
      db 9,18,27,36,45,54,63,72,81
heading db 'x y',13,10,'$'
error_text db 'error',13,10,'$'
finished db 13,10,'accomplish!',13,10,'$'
data ends

stack_seg segment para stack 'STACK'
    dw 128 dup (?)
stack_seg ends

code segment para public 'CODE'
assume cs:code,ds:data,ss:stack_seg
start:
    mov ax,data
    mov ds,ax
    lea si,table
ready:                        ; DS initialized; table starts at DS:0000.
    lea dx,heading
    mov ah,09h
    int 21h
    mov bh,1                  ; 1-based row.
    mov cx,9
row_loop:
    push cx                   ; Save outer counter.
    mov cx,9
    mov bl,1                  ; 1-based column.
column_loop:
    call check_cell
after_cell:
    inc si                    ; Next BYTE; 9 bytes per row, no row padding.
    inc bl
    loop column_loop
    pop cx
    inc bh
    loop row_loop
scan_done:
    lea dx,finished
    mov ah,09h
    int 21h
    mov ax,4c00h               ; Scan completed, even when bad cells exist.
    int 21h

; Input DS:SI=current byte, BH=row, BL=column.
; Preserve AX/BX/CX/DX/SI; flags may change. Does not modify the table.
check_cell proc near
    push ax
    push bx
    push cx
    push dx
    push si
    mov al,bh
    mul bl                    ; AX = row * column, maximum 81.
compare_cell:
    cmp al,[si]               ; Register-indirect access through DS:SI.
    je cell_done
    call report_error
cell_done:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
check_cell endp

; Report BH BL. Borrow CX to output two spaces, then restore it.
report_error proc near
    push ax
    push cx
    push dx
    mov dl,bh
    add dl,'0'
    call put_char
    mov dl,' '
    call put_char
    mov dl,bl
    add dl,'0'
    call put_char
    mov cx,2
    mov dl,' '
space_loop:
    call put_char
    loop space_loop
    lea dx,error_text
    mov ah,09h
    int 21h
    pop dx
    pop cx
    pop ax
    ret
report_error endp

put_char proc near
    push ax
    mov ah,02h
    int 21h
    pop ax
    ret
put_char endp
code ends
end start
