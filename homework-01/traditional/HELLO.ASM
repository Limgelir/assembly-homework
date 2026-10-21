.model small
.stack 100h

.data
Hello db 'Hello world!',0dh,0ah,'$'

.code
start:
    mov ax,@data
    mov ds,ax
    mov dx,offset Hello
    mov ah,09h
    int 21h

    mov ax,4c00h
    int 21h
end start
