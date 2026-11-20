; Main module: input workflow and calls to independently assembled modules.
include MACROS.INC
extrn write_string:far, render_calendar:far
data segment para public 'DATA'
extrn selected_year:word, selected_month:word, first_day:word, month_length:word
extrn year_prompt:byte, month_prompt:byte, year_error:byte, month_error:byte
data ends
stack_seg segment para stack 'STACK'
    dw 512 dup (0a55ah)
stack_seg ends
core segment para public 'CODE'
assume cs:core,ds:data,ss:stack_seg
extrn read_number:near, days_in_month:near, first_weekday:near
public start, calculate, before_weekday, after_weekday, before_render, after_render
start:
    mov ax,data
    mov ds,ax
    PRINT_TEXT year_prompt
    mov cl,4
    call read_number
    jnc short year_parsed
    jmp near ptr bad_year              ; Conditional target may exceed 127.
year_parsed:
    REQUIRE_RANGE ax,1900,2099,bad_year
    mov selected_year,ax
    PRINT_TEXT month_prompt
    mov cl,2
    call read_number
    jnc short month_parsed
    jmp near ptr bad_month
month_parsed:
    REQUIRE_RANGE ax,1,12,bad_month
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

bad_year:
    PRINT_TEXT year_error
    mov ax,4c01h
    int 21h
bad_month:
    PRINT_TEXT month_error
    mov ax,4c01h
    int 21h
core ends
end start
