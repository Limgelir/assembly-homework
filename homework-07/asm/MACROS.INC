; Compile-time expansion; a macro itself has no runtime CALL or return address.
; This macro expands to LEA + a real FAR CALL to the output procedure.
PRINT_TEXT macro message
    lea dx,message
    call far ptr write_string
endm

NEW_LINE macro
    call far ptr crlf
endm

; LOCAL generates unique labels for the two expansions in MAIN.
; Inverted short conditions skip a NEAR JMP, avoiding the 8086 Jcc range limit.
REQUIRE_RANGE macro value,lower,upper,failure
    local lower_ok,range_ok
    cmp value,lower
    jae short lower_ok
    jmp near ptr failure
lower_ok:
    cmp value,upper
    jbe short range_ok
    jmp near ptr failure
range_ok:
endm
