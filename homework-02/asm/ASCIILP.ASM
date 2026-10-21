.model small
.stack 100h

.code
start:
    mov bl,'a'                 ; Next lowercase ASCII character.
    mov cx,2                   ; Two rows.

row_loop:
    push cx                    ; Save the OUTER loop counter.
    mov cx,13                  ; Thirteen letters in this row.

column_loop:
    mov dl,bl
    call put_char
    inc bl
    loop column_gap            ; Decrement INNER CX, continue if nonzero.
    jmp row_end                ; No trailing space after letter 13.

column_gap:
    mov dl,' '
    call put_char
    jmp column_loop

row_end:
    mov dl,0dh                 ; DOS newline: carriage return + line feed.
    call put_char
    mov dl,0ah
    call put_char
    pop cx                     ; Restore the OUTER loop counter.
    loop row_loop

    mov ax,4c00h
    int 21h

put_char proc near
    mov ah,02h                 ; DOS: write the character in DL.
    int 21h
    ret
put_char endp

end start
