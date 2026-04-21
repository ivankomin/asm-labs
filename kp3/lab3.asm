.MODEL SMALL
.STACK 100h

.DATA
    buf             DB 7, ?, 7 DUP(?)
    x_val           DW 0
    x_neg           DB 0 ;actual flag for the sign of x
    y_val           DW 0
    y_neg           DB 0 ;actual flag for the sign of y
    res_quot        DW 0
    res_rem         DW 0
    res_neg         DB 0 ;flag for the sign of the result, used in the output procedure
    is_negative     DB 0 ;simply for the input procedure
    current_prompt  DW 0

    msg_input_x     DB 13, 10, "Enter X: $"
    msg_input_y     DB 13, 10, "Enter Y: $"
    msg_res_z       DB 13, 10, "Z = $"
    msg_remain      DB " remainder: $"
    run_message     DB 13, 10, 13, 10, "Press 'y' to continue or any other key to exit: $"

    empty_input_msg   DB 13, 10, "Empty input. Try again.$"
    invalid_input_msg DB 13, 10, "Invalid input. Digits only.$"
    in_ovf_msg        DB 13, 10, "Input Overflow! (Range: -32768 to 65535)$"
    math_ovf_msg      DB 13, 10, "Math Overflow! Result is out of range.$"
    div_zero_msg      DB 13, 10, "Error: Division by zero!$"

    Z_FUNC_TITLE              DB 9, 9, '                ', 13, 10
                              DB 9, 9, '  _____       ,-', 13, 10
                              DB 9, 9, ' / _  /       | (4 + x^2) / (yx)    if x < 5, y < 5', 13, 10
                              DB 9, 9, ' \// /   --  /  25y             if x >= 5, y >= 5', 13, 10
                              DB 9, 9, '  / //\  --  \  4x              if x <= 0, y > 10', 13, 10
                              DB 9, 9, ' /____/       | x + y               otherwise', 13, 10
                              DB 9, 9, '              `-', 13, 10
                              DB 9, 9, 'The absolute input range is -32768 to 65535', 13, 10
                              DB 9, 9, ', but it heavily depends on the specific function', 13, 10
                              DB '$'

.CODE
MAIN PROC
    MOV AX, @DATA
    MOV DS, AX

main_loop:
    MOV AH, 09h
    LEA DX, Z_FUNC_TITLE
    INT 21h

    ; input X
    LEA DX, msg_input_x
    MOV current_prompt, DX
    CALL input_number
    MOV x_val, BX           ; store the absolute value
    ; is_negative is used in the input number procedure, which is used twice, which is why we need to store the
        ; sign in a separate variable for each number, so that we may use is_negative again
    MOV AL, is_negative
    MOV x_neg, AL

    ; input Y
    LEA DX, msg_input_y
    MOV current_prompt, DX
    CALL input_number
    MOV y_val, BX
    MOV AL, is_negative
    MOV y_neg, AL

    ; Check conditions and execute corresponding functions

    ; Condition 1: x < 5 && y < 5
    CALL check_x_less_5
    JNE try_cond_2          ; If X >= 5, check condition 2
    CALL check_y_less_5
    JNE try_cond_3          ; If X < 5, but Y >= 5, check condition 3
    CALL do_calc_1
    JMP end_iteration

try_cond_2:
    ; Condition 2: x >= 5 && y >= 5
    CALL check_x_ge_5
    JNE try_cond_3          ; If X < 5, check condition 3
    CALL check_y_ge_5
    JNE try_else            ; If X >= 5, but Y < 5, go to "otherwise"
    CALL do_calc_2
    JMP end_iteration

try_cond_3:
    ; Condition 3: x <= 0 && y > 10
    CALL check_x_le_0
    JNE try_else            ; If X > 0, go to "otherwise"
    CALL check_y_gt_10
    JNE try_else            ; If Y <= 10, go to "otherwise"
    CALL do_calc_3
    JMP end_iteration

try_else:
    ; Condition 4: Z = x + y
    CALL do_calc_else

end_iteration:
    LEA DX, run_message
    CALL print_str
    MOV AH, 01H
    INT 21H
    CMP AL, 'y'
    JE main_loop
    CMP AL, 'Y'
    JE main_loop

    MOV AH, 4CH
    INT 21H
MAIN ENDP

; Calculate condition 1: Z = (4 + x^2) / (yx)
do_calc_1 PROC NEAR
    MOV AX, x_val
    MUL y_val               ; DX:AX = x * y (denominator)
    ; If DX != 0, then the result overflowed (> 65535)
    JC math_overflow_c1

    OR AX, AX
    JZ divide_zero_error       
    MOV CX, AX              ; Save the denominator in CX

    ; Result sign calculation
    MOV AL, x_neg
    XOR AL, y_neg           ; XOR sets 1, if the signs of the operands are different, and 0, if they are the same
    PUSH AX                 ; Save the result sign in the stack

    ; Calculating the numerator (x^2 + 4)
    MOV AX, x_val
    MUL x_val               ; DX:AX = x^2
    ADD AX, 4               ; Додаємо 4 до молодшої частини (може виникнути перенос CF=1)
    ADC DX, 0               ; Враховуємо цей перенос для DX (DX = DX + 0 + Carry)

    DIV CX                  ; AX = quotient, DX = remainder

    MOV res_quot, AX
    MOV res_rem, DX
    POP AX
    MOV res_neg, AL         ; Get back the result sign

    ; Check for overflow if the number is negative
    CMP res_neg, 1
    JNE print_c1_result
    CMP res_quot, 8000H
    JA math_overflow_c1

print_c1_result:
    CMP res_rem, 0          
    JZ call_simple          ; Print simple res if the remainder is 0

    CALL print_complex_res 
    JMP exit_do_calc_1     

    call_simple:
        CALL print_simple_res 

    exit_do_calc_1:
        RET
math_overflow_c1: JMP math_overflow_err
divide_zero_error: JMP div_by_zero_err
do_calc_1 ENDP

; Calculate condition 2: Z = 25y
do_calc_2 PROC NEAR
    MOV AX, y_val
    MOV CX, 25
    MUL CX
    JC math_overflow_c2

    MOV res_quot, AX
    MOV res_neg, 0
    CALL print_simple_res
    RET
math_overflow_c2: JMP math_overflow_err
do_calc_2 ENDP

; Calculate condition 3: Z = 4x
do_calc_3 PROC NEAR
    MOV AX, x_val
    MOV CX, 4
    MUL CX
    CMP AX, 8000H
    JA math_overflow_c3
save_result_c3:
    MOV res_quot, AX
    MOV AL, x_neg
    MOV res_neg, AL
    CALL print_simple_res
    RET
math_overflow_c3: JMP math_overflow_err
do_calc_3 ENDP

; Calculate condition 4: Z = x + y
do_calc_else PROC NEAR
    MOV AL, x_neg
    CMP AL, y_neg
    JNE different_signs

    MOV AX, x_val
    ADD AX, y_val
    JC math_overflow_else

    MOV res_quot, AX
    MOV res_neg, 0
    JMP print_else_result

different_signs:
    MOV AX, x_val
    CMP AX, y_val
    JAE x_is_bigger

    MOV AX, y_val
    SUB AX, x_val
    MOV res_quot, AX
    MOV AL, y_neg
    JMP print_else_result

x_is_bigger:
    SUB AX, y_val
    MOV res_quot, AX
    MOV AL, x_neg

print_else_result:
    CALL print_simple_res
    RET
math_overflow_else: JMP math_overflow_err
do_calc_else ENDP

; Output procedures
print_simple_res PROC NEAR
    LEA DX, msg_res_z
    CALL print_str
    MOV AX, res_quot
    CALL print_number_with_sign
    RET
print_simple_res ENDP

print_complex_res PROC NEAR
    LEA DX, msg_res_z
    CALL print_str
    ; Print the quotient
    MOV AX, res_quot
    CALL print_number_with_sign

    ; Print the remainder
    LEA DX, msg_remain
    CALL print_str
    MOV AX, res_rem
    MOV res_neg, 0               ; Remainder is always positive
    CALL print_number_with_sign
print_exit: RET
print_complex_res ENDP

math_overflow_err:
    LEA DX, math_ovf_msg
    CALL print_str
    RET

div_by_zero_err:
    LEA DX, div_zero_msg
    CALL print_str
    RET

; Logic for checking conditions, each sets ZF to 1 if the condition is true and 0 otherwise
check_x_less_5:
    CMP x_neg, 1
    JE set_true
    CMP x_val, 5
    JB set_true
    JMP set_false

check_y_less_5:
    CMP y_neg, 1
    JE set_true
    CMP y_val, 5
    JB set_true
    JMP set_false

check_x_ge_5:
    CMP x_neg, 1
    JE set_false
    CMP x_val, 5
    JAE set_true
    JMP set_false

check_y_ge_5:
    CMP y_neg, 1
    JE set_false
    CMP y_val, 5
    JAE set_true
    JMP set_false

check_x_le_0:
    CMP x_neg, 1
    JE set_true
    CMP x_val, 0
    JE set_true
    JMP set_false

check_y_gt_10:
    CMP y_neg, 1
    JE set_false
    CMP y_val, 10
    JA set_true
    JMP set_false

set_true:
    PUSH AX
    CMP AX, AX      ; ZF = 1
    POP AX
    RET
set_false:
    PUSH AX
    XOR AX, AX
    INC AX
    CMP AX, 0       ; ZF = 0
    POP AX
    RET

;INPUT PROCEDURE
input_number PROC NEAR
start_input:
    ; Print current prompt
    MOV DX, current_prompt
    CALL print_str

    ; Read user input
    MOV AH, 0Ah
    LEA DX, buf
    INT 21H
    CALL line

    XOR CX, CX
    MOV CL, [buf + 1]       ; Get the input length
    JCXZ empty_input

    XOR BX, BX              ; Accumulate the result in BX
    MOV is_negative, 0      ; Treat number as positive by default
    LEA SI, buf + 2         ; Use SI as the input pointer, starting from the first digit

    ; Check for negative sign
    MOV AL, [SI]
    CMP AL, '-'
    JNE check_plus
    MOV is_negative, 1
    INC SI
    DEC CX
    JZ invalid_input        ; Check if only '-' was entered
    JMP convert_loop

check_plus:
    ; Skip the plus sign
    CMP AL, '+'
    JNE convert_loop
    INC SI
    DEC CX
    JZ invalid_input        ; Check if only '+' was entered

convert_loop:
    ; Convert ASCII to digit
    MOV AL, [SI]    CMP x_neg, 1
    JNE save_result_c3
    CMP AL, '0'
    JB invalid_input
    CMP AL, '9'
    JA invalid_input

    SUB AL, '0'             ; ASCII -> Digit
    XOR AH, AH
    PUSH AX                 ; Save current digit

    MOV AX, BX
    MOV DI, 10
    MUL DI

    ;overflows are getting caught here:

    ;case 1: 9999 * 10 = 99990 => overflow
    ;update the flags
    ;if dx isnt 0 then the result overflowed, pop the digit off the stack and go to the error
    JC overflow_pop

    POP DX                  ; Get the digit off the stack and add it to the multiplication result
    ADD AX, DX
    ;case 2: 65530 + 6 = 65536 => overflow
    JC overflow_input

    MOV BX, AX              ; Accumulate the result in BX
    INC SI
    LOOP convert_loop

    ; Check the limit for negative numbers
    CMP is_negative, 1
    JNE input_done
    CMP BX, 8000H
    JA overflow_input

input_done: RET

empty_input:
    LEA DX, empty_input_msg
    CALL print_str
    JMP start_input
invalid_input:
    LEA DX, invalid_input_msg
    CALL print_str
    JMP start_input
overflow_pop: POP AX
overflow_input:
    LEA DX, in_ovf_msg
    CALL print_str
    JMP start_input
input_number ENDP

; Helper functions
print_str PROC NEAR
    MOV AH, 9
    INT 21H
    RET
print_str ENDP

line PROC NEAR
    MOV AH, 02H
    MOV DL, 13
    INT 21H
    MOV DL, 10
    INT 21H
    RET
line ENDP

;Convert number to string and output it
print_number_with_sign PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    ; Output the negative sign
    CMP res_neg, 1
    JNE prepare_print
    ; Prevent the output of '-0'
    OR AX, AX
    JZ prepare_print
    PUSH AX             ; Save the result in the stack temporarily
    MOV AH, 02H
    MOV DL, '-'
    INT 21H
    POP AX

prepare_print:
    XOR CX, CX
    MOV BX, 10              ; BX will serve as the divider

divide_to_stack:
    ; Divide the number by 10 and push the remainder
    XOR DX, DX
    DIV BX
    PUSH DX
    ;get amount of digits received
    INC CX
    ;if we have something left to divide, iterate again
    OR AX, AX
    JNZ divide_to_stack

pop_and_print:
    ;get the last number, turn it back to ascii and print it out
    POP DX
    ADD DL, '0'
    MOV AH, 02H
    INT 21H
    LOOP pop_and_print

    POP DX
    POP CX
    POP BX
    POP AX
    RET
print_number_with_sign ENDP

END MAIN
