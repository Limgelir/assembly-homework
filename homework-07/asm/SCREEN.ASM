; SCREEN is a distinct code segment; imported FAR procedures end in RETF.
include MACROS.INC
data segment para public 'DATA'
extrn selected_year:word, selected_month:word, first_day:word, month_length:word
extrn month_names:word, weekdays:byte, two_spaces:byte
data ends
public render_calendar, write_string, crlf, render_enter, render_return
public before_digits, after_digits, print_unsigned, unsigned_return
screen segment para public 'CODE'
assume cs:screen,ds:data
; Data-segment parameters: selected_year/month, first_day, month_length.
; FAR return restores both IP and CS. Preserve all used registers.
render_calendar proc far
render_enter:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    NEW_LINE
    mov ax,selected_year
before_digits:
    call print_unsigned
after_digits:
    PRINT_TEXT two_spaces
    mov bx,selected_month
    dec bx
    shl bx,1
    mov dx,month_names[bx]
    call far ptr write_string
    NEW_LINE
    PRINT_TEXT weekdays
    mov cx,first_day
    jcxz begin_days
leading_blanks:
    mov dl,' '
    call put_char
    call put_char
    call put_char
    loop leading_blanks
begin_days:
    mov bx,first_day
    mov si,1
day_loop:
    mov ax,si
    call print_day
    inc bl
    cmp si,month_length
    jae calendar_end
    cmp bl,7
    je wrap_line
    mov dl,' '
    call put_char
    jmp short next_day
wrap_line:
    NEW_LINE
    xor bl,bl
next_day:
    inc si
    jmp short day_loop
calendar_end:
    NEW_LINE
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
render_return:
    retf
render_calendar endp

; Same-segment NEAR helper; right-align a date in two characters.
print_day proc near
    push ax
    cmp ax,10
    jae day_two
    mov dl,' '
    call put_char
day_two:
    call print_unsigned
    pop ax
    ret
print_day endp

print_unsigned proc near
    push ax
    push bx
    push cx
    push dx
    mov bx,10
    xor cx,cx
split_decimal:
    xor dx,dx
    div bx
    push dx
    inc cx
    or ax,ax
    jnz split_decimal
write_decimal:
    pop dx
    add dl,'0'
    call put_char
    loop write_decimal
    pop dx
    pop cx
    pop bx
    pop ax
unsigned_return:
    ret
print_unsigned endp

put_char proc near
    push ax
    mov ah,02h
    int 21h
    pop ax
    ret
put_char endp

write_string proc far
    push ax
    mov ah,09h
    int 21h
    pop ax
    retf
write_string endp

crlf proc far
    push dx
    mov dl,13
    call put_char
    mov dl,10
    call put_char
    pop dx
    retf
crlf endp
screen ends
end
