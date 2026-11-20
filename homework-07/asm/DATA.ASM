; Shared data definitions: storage allocated exactly once.
data segment para public 'DATA'
public selected_year, selected_month, first_day, month_length
public month_days, month_names, year_prompt, month_prompt
public year_error, month_error, weekdays, two_spaces, input_buf
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
end
