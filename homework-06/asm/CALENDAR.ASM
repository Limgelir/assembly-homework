; 8086 monthly calendar. CORE and SCREEN are separate code segments.
data segment para public 'DATA'
selected_year dw 2026
selected_month dw 11
first_day dw 0
month_length dw 0
month_days db 31,28,31,30,31,30,31,31,30,31,30,31
month_names dw offset m1,offset m2,offset m3,offset m4,offset m5,offset m6,offset m7,offset m8,offset m9,offset m10,offset m11,offset m12
m1 db 'January$'
m2 db 'February$'
m3 db 'March$'
m4 db 'April$'
m5 db 'May$'
m6 db 'June$'
m7 db 'July$'
m8 db 'August$'
m9 db 'September$'
m10 db 'October$'
m11 db 'November$'
m12 db 'December$'
year_prompt db 'Please input year (1900-2099): $'
month_prompt db 'Please input month (1-12): $'
year_error db 'Error: year must be 1900..2099 (4 digits).',13,10,'$'
month_error db 'Error: month must be 1..12 (1-2 digits).',13,10,'$'
weekdays db 'Su Mo Tu We Th Fr Sa',13,10,'$'
two_spaces db '  $'
input_buf db 64,0,64 dup (0)
data ends
stack_seg segment para stack 'STACK'
    dw 512 dup (0a55ah)
stack_seg ends

core segment para public 'CODE'
assume cs:core,ds:data,ss:stack_seg
start:
    mov ax,data
    mov ds,ax
    lea dx,year_prompt
    call far ptr write_string
    mov cl,4
    call read_number
    jnc short year_parsed
    jmp near ptr bad_year              ; Conditional target may exceed 127.
year_parsed:
    cmp ax,1900
    jae short year_min_ok
    jmp near ptr bad_year
year_min_ok:
    cmp ax,2099
    jbe short year_ok
    jmp near ptr bad_year
year_ok:
    mov selected_year,ax
    lea dx,month_prompt
    call far ptr write_string
    mov cl,2
    call read_number
    jnc short month_parsed
    jmp near ptr bad_month
month_parsed:
    cmp ax,1
    jae short month_min_ok
    jmp near ptr bad_month
month_min_ok:
    cmp ax,12
    jbe short month_ok
    jmp near ptr bad_month
month_ok:
    mov selected_month,ax
calculate:
    mov ax,selected_year
    mov bx,selected_month
    call days_in_month                 ; Register arguments AX/BX -> AX.
    mov month_length,ax
    push selected_month
    push selected_year
before_weekday:
    call first_weekday                 ; Stack arguments, callee RET 4.
after_weekday:
    mov first_day,ax
before_render:
    call far ptr render_calendar       ; Data-segment arguments; changes CS.
after_render:
    mov ax,4c00h
    int 21h

; CL=max digits. Return AX=value, CF=0; CF=1 for invalid input.
read_number proc near
    push bx
    push cx
    push dx
    push si
    push di
    mov bl,cl
    mov input_buf[1],0
    lea dx,input_buf
    mov ah,0ah
    int 21h
    call far ptr crlf
    xor cx,cx
    mov cl,input_buf[1]
    lea si,input_buf[2]
    jcxz read_bad
    cmp byte ptr [si],10                ; CRLF files leave LF after prior CR.
    jne length_ready
    inc si
    dec cx
    jcxz read_bad
length_ready:
    cmp cl,bl
    ja read_bad
    xor ax,ax
    mov bx,10
read_digit:
    mov dl,[si]
    cmp dl,'0'
    jb read_bad
    cmp dl,'9'
    ja read_bad
    sub dl,'0'
    xor dh,dh
    mov di,dx
    mul bx
    add ax,di                          ; At most 4 digits, no overflow.
    inc si
    loop read_digit
    clc
    jmp short read_end
read_bad:
    stc
read_end:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    ret
read_number endp

; Register argument AX=year -> AX=0/1; preserve BX/CX/DX.
leap_year proc near
    push bx
    push cx
    push dx
    mov cx,ax
    mov bx,4
    xor dx,dx
    div bx
    or dx,dx
    jnz not_leap
    mov ax,cx
    mov bx,100
    xor dx,dx
    div bx
    or dx,dx
    jnz is_leap
    mov ax,cx
    mov bx,400
    xor dx,dx
    div bx
    or dx,dx
    jnz not_leap
is_leap:
    mov ax,1
    jmp short leap_end
not_leap:
    xor ax,ax
leap_end:
    pop dx
    pop cx
    pop bx
    ret
leap_year endp

; AX=year, BX=month (1..12) -> AX=28..31. Other registers preserved.
days_in_month proc near
    push si
    cmp bx,2
    jne ordinary_month
    call leap_year
    add ax,28
    jmp short days_end
ordinary_month:
    mov si,bx
    dec si
    xor ax,ax
    mov al,month_days[si]
days_end:
    pop si
    ret
days_in_month endp

; Caller pushes month, then year. AX=weekday, Sunday=0.
; [BP+4]=year, [BP+6]=month; RET 4 removes the two arguments.
first_weekday proc near
    push bp
    mov bp,sp
    push bx
    push cx
    push dx
    push si
    push di
weekday_frame:
    mov si,[bp+4]
    dec si
    mov di,si
    inc di                             ; (year-1)+1, Jan 1 of year 1 is Monday.
    mov ax,si
    mov bx,4
    xor dx,dx
    div bx
    add di,ax
    mov ax,si
    mov bx,100
    xor dx,dx
    div bx
    sub di,ax
    mov ax,si
    mov bx,400
    xor dx,dx
    div bx
    add di,ax
    mov cx,[bp+6]
    dec cx
    jcxz weekday_reduce
    mov bx,1
add_month:
    mov ax,[bp+4]
    call days_in_month
    add di,ax
    inc bx
    loop add_month
weekday_reduce:
    mov ax,di
    mov bx,7
    xor dx,dx
    div bx
    mov ax,dx
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop bp
weekday_return:
    ret 4
first_weekday endp

; These targets are intentionally far away within CORE.
bad_year:
    lea dx,year_error
    call far ptr write_string
    mov ax,4c01h
    int 21h
bad_month:
    lea dx,month_error
    call far ptr write_string
    mov ax,4c01h
    int 21h
core ends

screen segment para public 'CODE'
assume cs:screen,ds:data,ss:stack_seg
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
    call far ptr crlf
    mov ax,selected_year
    call print_unsigned
    lea dx,two_spaces
    call far ptr write_string
    mov bx,selected_month
    dec bx
    shl bx,1
    mov dx,month_names[bx]
    call far ptr write_string
    call far ptr crlf
    lea dx,weekdays
    call far ptr write_string
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
    call far ptr crlf
    xor bl,bl
next_day:
    inc si
    jmp short day_loop
calendar_end:
    call far ptr crlf
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
end start
