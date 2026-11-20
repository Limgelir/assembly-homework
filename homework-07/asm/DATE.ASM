; Calendar arithmetic; PUBLIC CORE combines with MAIN and INPUT at link time.
data segment para public 'DATA'
extrn month_days:byte
data ends
core segment para public 'CODE'
assume cs:core,ds:data
public leap_year, days_in_month, first_weekday, weekday_frame, weekday_return
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

core ends
end
