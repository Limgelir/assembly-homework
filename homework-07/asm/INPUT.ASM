; Buffered decimal input, linked into the same CORE segment as MAIN.
include MACROS.INC
extrn crlf:far
data segment para public 'DATA'
extrn input_buf:byte
data ends
core segment para public 'CODE'
assume cs:core,ds:data
public read_number
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
    NEW_LINE
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

core ends
end
