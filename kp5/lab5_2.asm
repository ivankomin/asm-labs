.MODEL SMALL
.386                
.STACK 100h

; --- UI & SYSTEM MACROS ---
M_PRINT_MSG MACRO msg_address
    PUSH DX
    PUSH AX
    MOV DX, msg_address
    MOV AH, 09h
    INT 21h
    POP AX
    POP DX
ENDM

M_NEWLINE MACRO
    PUSH AX
    PUSH DX
    MOV AH, 02h
    MOV DL, 13
    INT 21h
    MOV DL, 10
    INT 21h
    POP DX
    POP AX
ENDM

; Handles the "Prompt -> Input -> Store" flow
M_GET_INPUT MACRO prompt_msg, target_var
    MOV DX, OFFSET prompt_msg
    MOV current_prompt, DX
    CALL input_number
    MOV target_var, EAX
ENDM

M_EXIT MACRO ret_code
    MOV AX, 4C00h OR ret_code
    INT 21h
ENDM

; --- MATH MACROS ---

M_CALC_Z1 MACRO val_x, val_y
    MOV EAX, val_x
    IMUL EAX, val_y         
    JZ lbl_div_zero         
    CALL check_res_bounds
    CMP BL, 1
    JE lbl_math_ovf         
    MOV ECX, EAX            

    MOV EAX, val_x
    IMUL EAX, EAX           
    ADD EAX, 4              

    CDQ                     
    IDIV ECX                

    MOV res_quot, EAX
    MOV res_rem, EDX
    CALL check_res_bounds
    CMP BL, 1
    JE lbl_math_ovf         
ENDM

M_CALC_Z2 MACRO val_y
    MOV EAX, val_y
    IMUL EAX, 25
    CALL check_res_bounds
    CMP BL, 1
    JE lbl_math_ovf
    MOV res_quot, EAX
ENDM

M_CALC_Z3 MACRO val_x
    MOV EAX, val_x
    IMUL EAX, 4
    CALL check_res_bounds
    CMP BL, 1
    JE lbl_math_ovf
    MOV res_quot, EAX
ENDM

M_CALC_Z4 MACRO val_x, val_y
    MOV EAX, val_x
    ADD EAX, val_y
    CALL check_res_bounds
    CMP BL, 1
    JE lbl_math_ovf
    MOV res_quot, EAX
ENDM

; --- DATA SECTION ---

.DATA
    buf             DB 12, ?, 12 DUP(?) 
    x_val           DD 0                
    y_val           DD 0
    res_quot        DD 0
    res_rem         DD 0
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
                              DB '$'

; --- CODE SECTION ---

.CODE
MAIN PROC
    MOV AX, @DATA
    MOV DS, AX

main_loop:
    M_PRINT_MSG <OFFSET Z_FUNC_TITLE>

    M_GET_INPUT msg_input_x, x_val
    M_GET_INPUT msg_input_y, y_val

    ; Condition 1
    CMP x_val, 5
    JGE try_cond_2          
    CMP y_val, 5
    JGE try_cond_3          
    CALL do_calc_1
    JMP end_iteration

try_cond_2:
    CMP x_val, 5
    JL try_cond_3          
    CMP y_val, 5
    JL try_else            
    CALL do_calc_2
    JMP end_iteration

try_cond_3:
    CMP x_val, 0
    JG try_else            
    CMP y_val, 10
    JLE try_else            
    CALL do_calc_3
    JMP end_iteration

try_else:
    CALL do_calc_else

end_iteration:
    M_PRINT_MSG <OFFSET run_message>
    MOV AH, 01H
    INT 21H
    CMP AL, 'y'
    JE main_loop
    CMP AL, 'Y'
    JE main_loop

    M_EXIT 0
MAIN ENDP

; --- CALCULATION PROCEDURES ---

do_calc_1 PROC NEAR
    M_CALC_Z1 x_val, y_val
    M_PRINT_MSG <OFFSET msg_res_z>
    MOV EAX, res_quot
    CALL print_number_32

    CMP res_rem, 0          
    JZ exit_do_calc_1
    M_PRINT_MSG <OFFSET msg_remain>
    MOV EAX, res_rem
    CALL print_number_32
exit_do_calc_1:
    RET
do_calc_1 ENDP

do_calc_2 PROC NEAR
    M_CALC_Z2 y_val
    M_PRINT_MSG <OFFSET msg_res_z>
    MOV EAX, res_quot
    CALL print_number_32
    RET
do_calc_2 ENDP

do_calc_3 PROC NEAR
    M_CALC_Z3 x_val
    M_PRINT_MSG <OFFSET msg_res_z>
    MOV EAX, res_quot
    CALL print_number_32
    RET
do_calc_3 ENDP

do_calc_else PROC NEAR
    M_CALC_Z4 x_val, y_val
    M_PRINT_MSG <OFFSET msg_res_z>
    MOV EAX, res_quot
    CALL print_number_32
    RET
do_calc_else ENDP

; --- SHARED ERROR LABELS ---
lbl_math_ovf:
    M_PRINT_MSG <OFFSET math_ovf_msg>
    RET
lbl_div_zero:
    M_PRINT_MSG <OFFSET div_zero_msg>
    RET

; --- I/O PROCEDURES ---

input_number PROC NEAR
start_input:
    ; Fixed: Now passing the variable itself, which holds the address
    M_PRINT_MSG current_prompt
    MOV AH, 0Ah
    LEA DX, buf
    INT 21H
    M_NEWLINE

    LEA SI, buf + 2
    MOV CL, [buf + 1]
    XOR CH, CH
    JCXZ empty_input

    XOR EAX, EAX
    XOR EDI, EDI            
    
    CMP BYTE PTR [SI], '-'
    JNE check_plus
    MOV EDI, 1
    INC SI
    DEC CX
    JZ invalid_input
    JMP convert_loop

check_plus:
    CMP BYTE PTR [SI], '+'
    JNE convert_loop
    INC SI
    DEC CX
    JZ invalid_input

convert_loop:
    MOVZX EBX, BYTE PTR [SI]
    SUB BL, '0'
    CMP BL, 9
    JA invalid_input
    
    IMUL EAX, 10
    JO  overflow_input      
    ADD EAX, EBX
    JO  overflow_input      
    
    INC SI
    LOOP convert_loop

    CMP EDI, 1
    JNE check_range
    NEG EAX

check_range:
    CMP EAX, 65535
    JG overflow_input
    CMP EAX, -32768
    JL overflow_input
    RET

empty_input:
    M_PRINT_MSG <OFFSET empty_input_msg>
    JMP start_input
invalid_input:
    M_PRINT_MSG <OFFSET invalid_input_msg>
    JMP start_input
overflow_input:
    M_PRINT_MSG <OFFSET in_ovf_msg>
    JMP start_input
input_number ENDP

check_res_bounds PROC NEAR
    CMP EAX, 65535
    JG  out_of_bounds
    CMP EAX, -32768
    JL  out_of_bounds
    MOV BL, 0
    RET
out_of_bounds:
    MOV BL, 1
    RET
check_res_bounds ENDP

print_number_32 PROC NEAR
    PUSHAD
    OR EAX, EAX
    JNS p_pos
    PUSH EAX
    MOV AH, 02h
    MOV DL, '-'
    INT 21h
    POP EAX
    NEG EAX                 
p_pos:
    MOV EBX, 10
    XOR CX, CX
p_div:
    XOR EDX, EDX
    DIV EBX
    PUSH DX
    INC CX
    OR EAX, EAX
    JNZ p_div
p_out:
    POP DX
    ADD DL, '0'
    MOV AH, 02h
    INT 21h
    LOOP p_out
    POPAD
    RET
print_number_32 ENDP

END MAIN