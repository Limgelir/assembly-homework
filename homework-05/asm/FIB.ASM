; F(n), 1..100: real recursive calls + memoization + 80-bit integers.
data segment para public 'DATA'
memo dw 5 dup (0),1,4 dup (0),495 dup (0) ; 101 numbers, 5 words each.
ready db 1,1,99 dup (0)                  ; F(0)=0 and F(1)=1 cached.
calls dw 0
min_sp dw 1000h
scratch dw 5 dup (0)
prompt db 'Please input n (1-100):',13,10,'$'
answer db 'F(n):',13,10,'$'
error_msg db 'Error: enter 1-3 decimal digits in 1..100.',13,10,'$'
input_buf db 64,0,64 dup (0)
data ends
stack_seg segment para stack 'STACK'
    dw 2048 dup (0a55ah)                ; 4096 bytes; DOS loader sets SS:SP.
stack_seg ends
code segment para public 'CODE'
assume cs:code,ds:data,ss:stack_seg
start:
    mov ax,data
    mov ds,ax
initialized:
    lea dx,prompt
    call puts
    lea dx,input_buf
    mov ah,0ah
    int 21h
    call newline
    xor cx,cx
    mov cl,input_buf[1]
    jcxz bad_input
    cmp cl,3
    ja bad_input
    jmp parse_start
bad_input:
    lea dx,error_msg
    call puts
    mov ax,4c01h
    int 21h
parse_start:
    lea si,input_buf[2]
    xor ax,ax
    mov bx,10
parse_digit:
    mov dl,[si]
    cmp dl,'0'
    jb bad_input
    cmp dl,'9'
    ja bad_input
    sub dl,'0'
    xor dh,dh
    mov di,dx
    mul bx
    add ax,di                           ; At most 3 digits: no 16-bit overflow.
    inc si
    loop parse_digit
    cmp ax,1
    jb bad_input
    cmp ax,100
    ja bad_input
compute:
    call fib
computed:
    lea dx,answer
    call puts
    call print_big
    call newline
    mov ax,4c00h
    int 21h

; Input AX=n (0..100). Return DS:SI -> memo[n], 5 little-endian words.
; Preserve AX/BX/CX/DX/DI/BP. SI is the return value; flags may change.
fib proc near
    push bp
    mov bp,sp
    push ax                            ; Saved n at SS:[BP-2].
    push bx
    push cx
    push dx
    push di
frame_ready:                           ; 14 bytes including near return IP.
    inc calls
    cmp sp,min_sp
    jae depth_recorded
    mov min_sp,sp
depth_recorded:
    mov bx,ax
    cmp ready[bx],0
    jne cached
    dec ax
    call fib                           ; F(n-1), recursively.
    push si                            ; Keep its pointer across next call.
    mov ax,[bp-2]
    sub ax,2
    call fib                           ; F(n-2); already cached on unwind.
    pop di
    mov ax,[bp-2]
    mov bx,10
    mul bx
    lea bx,memo
    add bx,ax                          ; Destination = memo + n*10.
    mov cx,5
    clc
add_words:
    mov ax,[di]
    adc ax,[si]                        ; Propagate carry across all 80 bits.
    mov [bx],ax
    inc si                             ; INC and LOOP preserve carry.
    inc si
    inc di
    inc di
    inc bx
    inc bx
    loop add_words
    mov bx,[bp-2]
    mov ready[bx],1
cached:
    mov ax,[bp-2]
    mov bx,10
    mul bx
    lea si,memo
    add si,ax
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
return_point:
    ret
fib endp

; Print DS:SI 80-bit value; copy it before division, preserving the cache.
print_big proc near
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    lea di,scratch
    mov cx,5
copy_words:
    mov ax,[si]
    mov [di],ax
    add si,2
    add di,2
    loop copy_words
    xor cx,cx                          ; Decimal digits saved on stack.
decimal_pass:
    lea si,scratch+8                   ; Divide from highest word to lowest.
    mov di,5
    mov bx,10
    xor dx,dx                          ; Carry remainder between words.
divide_words:
    mov ax,[si]
    div bx
    mov [si],ax
    sub si,2
    dec di
    jnz divide_words
    push dx                            ; This pass's decimal remainder.
    inc cx
    mov ax,scratch
    or ax,scratch[2]
    or ax,scratch[4]
    or ax,scratch[6]
    or ax,scratch[8]
    jnz decimal_pass
write_digits:
    pop dx
    add dl,'0'
    mov ah,02h
    int 21h
    loop write_digits
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
print_big endp

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
    mov dl,13
    mov ah,02h
    int 21h
    mov dl,10
    mov ah,02h
    int 21h
    pop dx
    pop ax
    ret
newline endp
code ends
end start
