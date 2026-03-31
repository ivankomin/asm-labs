STSEG SEGMENT PARA STACK "STACK"
    DB 128 DUP (?)
STSEG ENDS

DSEG SEGMENT PARA PUBLIC "DATA"
    buf             DB 7, ?, 7 DUP(?)
    number          DW 0
    is_negative     DB 0

    ;13 - carriage return, 10 - newline
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
        ;display message
        MOV AH, 9
        LEA DX, run_message
        INT 21H
        ;accept user input
        MOV AH, 01H
        INT 21H
        
        CMP AL, 'y'
        JE main_loop
        CMP AL, 'Y'
        JE main_loop
        
        ;exit dos
        MOV AH, 4CH
        INT 21H
    MAIN ENDP

;INPUT PROC
    input_number PROC NEAR
    start_input:
        ;display message
        MOV AH, 9
        LEA DX, input_message
        INT 21H
        ;read user input
        MOV AH, 0Ah
        LEA DX, buf
        INT 21H
        CALL line
        ;clean cx register to get rid of garbage
        XOR CX, CX
        ;get the length of the input
        MOV CL, [buf + 1]
        ;if cx is 0 we jump to the error
        JCXZ empty_input 
        ;bx reg will serve as the accumulator for the number
        XOR BX, BX
        ;assume that the number is positive
        MOV is_negative, 0
        ;si becomes the cursor, allows us to loop over the input
            ;buf + 2 is the address where the input text itself starts
        LEA SI, buf + 2

        ;square brackets act like pointers: we get the actual value
            ;rather than the address of that value
        MOV AL, [SI]
        ;check for a minus, if its not there we check for the plus
        CMP AL, '-'
        JNE check_plus
        ;if a number IS negative, set the is_negative var to 1
        MOV is_negative, 1
        ;skip the '-' symbol so that we wont have to convert it
        INC SI
        DEC CX
        ;if cx is empty after a '-' or '+' jump to invalid input
        JZ invalid_input
        JMP convert_loop

    check_plus:
        ;if we have a '+' we skip it, else go to the convert loop
        CMP AL, '+'
        JNE convert_loop
        INC SI
        DEC CX
        JZ invalid_input

    convert_loop:
        MOV AL, [SI]
        ;check if the number only contains digits
        CMP AL, '0'
        ;jump if below
        JB invalid_input
        CMP AL, '9'
        ;jump if above
        JA invalid_input
        ;convert ascii to digit by subtracting a '0'
        SUB AL, '0'
        ;clear possible garbage in ah
        XOR AH, AH
        ;store the digit temporarily in the stack
        PUSH AX

        ;accumulate the digits in bx
        MOV AX, BX
        ;unsigned multiplication
        MOV DI, 10
        MUL DI

        ;overflows are getting caught here:

        ;case 1: 9999 * 10 = 99990 => overflow
        ;update the flags
        ;if dx isnt 0 then the result overflowed, pop the digit off the stack and go to the error
        JC overflow_pop
        
        ;get the digit from the stack and add it to the multiplication result
        POP DX
        ADD AX, DX
        
        ;case 2: 65530 + 6 = 65536 => overflow
        
        JC overflow_input
        ;save new result in bx and move forward in the loop
        MOV BX, AX
        INC SI
        LOOP convert_loop

        ;update the flags
        or bx, bx
        ;jump if not sign (15th bit is 0 and the number is within 0 and 32768)
        jns check_zero  
        ;if it's 1 then it's within 32768 and 65535
            ;check if the number is negative     
        CMP is_negative, 1  
        ;if it's not we can apply math to the number <65535  
        JNE apply_math 
        ;if it is negative, check if it overflows (< -32768) 
        CMP BX, 8000H
        JA overflow_input 

    check_zero:
        OR BX, BX 
        ;jump if input is not 0             
        JNZ apply_math
        ;prevent something like '-0'
        MOV is_negative, 0
        jmp apply_math

    ;ERROR BLOCKS
    empty_input:
        MOV AH, 9
        LEA DX, empty_input_msg
        INT 21H
        JMP start_input

    invalid_input:
        MOV AH, 9
        LEA DX, invalid_input_msg
        INT 21H
        JMP start_input

    overflow_pop:
        POP AX
    overflow_input:
        MOV AH, 9
        LEA DX, overflow_msg
        INT 21H
        JMP start_input

    ;Add 23 to the number
    apply_math:
    ;save the current abs value in bx
        MOV number, BX
        MOV AX, number
        ;if positive, go to positive add
        CMP is_negative, 0
        JE positive_add

        ;if the abs value is > 23, sub 23 from the value and the number remains negative
        CMP AX, 23
        JA stay_negative
        ;if the abs value is <= 23, sub the number from 23
        MOV BX, 23
        SUB BX, AX
        MOV AX, BX
        ;then the number becomes positive
        MOV is_negative, 0
        JMP save_final

    stay_negative:
        SUB AX, 23
        JMP save_final
    
    ;simply add 23 to the number
    positive_add:
        ADD AX, 23
        JC overflow_input

    ;save the final value in memory and call print_number
    save_final:
        MOV number, AX
        MOV AH, 9
        LEA DX, calculation_msg
        INT 21H
        CALL print_number
        RET
    input_number ENDP

    line PROC NEAR
        PUSH AX
        PUSH DX
        ;move to the start of the line
        MOV AH, 02H
        MOV DL, 13
        INT 21H
        ;print new line char
        MOV DL, 10
        INT 21H
        
        POP DX
        POP AX
        RET
    line ENDP

    print_number PROC NEAR
    ;save current register values
        PUSH AX
        PUSH BX
        PUSH CX
        PUSH DX
        
        ;if the number is positive go to prepare_div
        MOV AX, number
        CMP is_negative, 1
        JNE prepare_div
        ;else, temporarily store the number in the stack, print the '-' and 
            ;get back the number from the stack
        PUSH AX
        MOV AH, 02H
        MOV DL, '-'
        INT 21H
        POP AX

    ;clear cx register and use 10 as the denominator
    prepare_div:
        XOR CX, CX
        MOV BX, 10
    divide_loop:
        ;clear the dx register
        XOR DX, DX
        ;ax/10. quotient in ax, remainder in dx (digit)
        DIV BX
        ;put the number in the stack
        PUSH DX
        ;get amount of digits received
        INC CX
        ;if we have something left to divide, iterate again
        OR AX, AX
        JNZ divide_loop
        
    print_loop:
        ;get the last number, turn it back to ascii and print it out
        POP DX
        ADD DL, '0'
        MOV AH, 02H
        INT 21H
        LOOP print_loop
        
        ;restore the register values and return
        POP DX
        POP CX
        POP BX
        POP AX
        RET
    print_number ENDP
CSEG ENDS
END MAIN