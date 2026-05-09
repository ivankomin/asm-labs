; output string macro
m_print_str MACRO msg
    PUSH AX
    PUSH DX
    LEA DX, msg
    MOV AH, 09H
    INT 21H
    POP DX
    POP AX
ENDM

; output char macro
m_print_char MACRO char
    PUSH AX
    PUSH DX
    MOV DL, char
    MOV AH, 02H
    INT 21H
    POP DX
    POP AX
ENDM

STSEG SEGMENT PARA STACK "STACK"
    DB 128 DUP (?)
STSEG ENDS

DSEG SEGMENT PARA PUBLIC "DATA"
    buf             DB 7, ?, 7 DUP(?)
    number          DW 0
    is_negative     DB 0

    input_message   DB 13, 10, "Enter an integer number (-32768 to 65512): $"
    calculation_msg DB 13, 10, "Result (+23): $"
    run_message     DB 13, 10, "Press 'y' to continue or any other key to exit: $"

    empty_input_msg   DB 13, 10, "Empty input. Try again.$"
    invalid_input_msg DB 13, 10, "Invalid input. Digits only.$"
    overflow_msg      DB 13, 10, "Overflow! Out of range.$"
DSEG ENDS

CSEG SEGMENT PARA PUBLIC "CODE"
    MAIN PROC FAR 
        ASSUME CS: CSEG, DS: DSEG, SS: STSEG
        
        MOV AX, DSEG
        MOV DS, AX
        
    main_loop:
        CALL input_number
        
        m_print_str run_message      
        
        MOV AH, 01H
        INT 21H
        
        CMP AL, 'y'
        JE main_loop
        CMP AL, 'Y'
        JE main_loop
        
        MOV AH, 4CH
        INT 21H
    MAIN ENDP

    input_number PROC NEAR
    start_input:
        m_print_str input_message   
        
        MOV AH, 0Ah
        LEA DX, buf
        INT 21H
        
        CALL line
        XOR CX, CX
        MOV CL, [buf + 1]
        JCXZ empty_input 
        
        XOR BX, BX
        MOV is_negative, 0
        LEA SI, buf + 2

        MOV AL, [SI]
        CMP AL, '-'
        JNE check_plus
        MOV is_negative, 1
        INC SI
        DEC CX
        JZ invalid_input
        JMP convert_loop

    check_plus:
        CMP AL, '+'
        JNE convert_loop
        INC SI
        DEC CX
        JZ invalid_input

    convert_loop:
        MOV AL, [SI]
        CMP AL, '0'
        JB invalid_input
        CMP AL, '9'
        JA invalid_input
        SUB AL, '0'
        XOR AH, AH
        PUSH AX

        MOV AX, BX
        MOV DI, 10
        MUL DI

        JC overflow_pop
        
        POP DX
        ADD AX, DX
        
        JC overflow_input
        MOV BX, AX
        INC SI
        LOOP convert_loop

        OR BX, BX
        JNS check_zero  
        CMP is_negative, 1  
        JNE apply_math 
        CMP BX, 8000H
        JA overflow_input 

    check_zero:
        OR BX, BX 
        JNZ apply_math
        MOV is_negative, 0
        jmp apply_math

    ; error blocks now use macros for output
    empty_input:
        m_print_str empty_input_msg
        JMP start_input

    invalid_input:
        m_print_str invalid_input_msg
        JMP start_input

    overflow_pop:
        POP AX
    overflow_input:
        m_print_str overflow_msg
        JMP start_input

    apply_math:
        MOV number, BX
        MOV AX, number
        CMP is_negative, 0
        JE positive_add

        CMP AX, 23
        JA stay_negative
        MOV BX, 23
        SUB BX, AX
        MOV AX, BX
        MOV is_negative, 0
        JMP save_final

    stay_negative:
        SUB AX, 23
        JMP save_final
    
    positive_add:
        ADD AX, 23
        JC overflow_input

    save_final:
        MOV number, AX
        m_print_str calculation_msg
        CALL print_number
        RET
    input_number ENDP

    line PROC NEAR
        m_print_char 13              ; CR
        m_print_char 10              ; LF
        RET
    line ENDP

    print_number PROC NEAR
        PUSH AX
        PUSH BX
        PUSH CX
        PUSH DX
        
        MOV AX, number
        CMP is_negative, 1
        JNE prepare_div
        
        m_print_char '-'             
        MOV AX, number               ; restore ax after macro use

    prepare_div:
        XOR CX, CX
        MOV BX, 10
    divide_loop:
        XOR DX, DX
        DIV BX
        PUSH DX
        INC CX
        OR AX, AX
        JNZ divide_loop
        
    print_loop:
        POP DX
        ADD DL, '0'
        m_print_char DL
        LOOP print_loop
        
        POP DX
        POP CX
        POP BX
        POP AX
        RET
    print_number ENDP
CSEG ENDS
END MAIN