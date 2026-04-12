.MODEL SMALL
.STACK 100h

.DATA
    buf             DB 7, ?, 7 DUP(?) 
    x_val           DW 0             
    x_neg           DB 0              
    y_val           DW 0              
    y_neg           DB 0              
    res_quot        DW 0              
    res_rem         DW 0             
    res_neg         DB 0             
    is_negative     DB 0             
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

.CODE
MAIN PROC
    MOV AX, @DATA
    MOV DS, AX
    
main_loop:
    MOV AH, 09h
    LEA DX, Z_FUNC_TITLE
    INT 21h

    ; Ввід X
    LEA DX, msg_input_x
    MOV current_prompt, DX  
    CALL input_number
    MOV x_val, BX           ; BX повертає модуль числа
    MOV AL, is_negative
    MOV x_neg, AL           ; Зберігаємо знак X
    
    ; Ввід Y
    LEA DX, msg_input_y
    MOV current_prompt, DX  
    CALL input_number
    MOV y_val, BX
    MOV AL, is_negative
    MOV y_neg, AL           ; Зберігаємо знак Y
    
    ; --- ДИСПЕТЧЕР УМОВ ---
    ; Перевірка умови 1: x < 5 і y < 5
    CALL check_x_less_5
    JNE try_cond_2          ; Якщо X >= 5, перевіряємо наступну гілку
    CALL check_y_less_5
    JNE try_cond_3          ; Якщо X < 5, але Y >= 5, йдемо до умови 3
    CALL do_calc_1          ; Виконуємо розрахунок гілки 1
    JMP end_iteration

try_cond_2:
    ; Перевірка умови 2: x >= 5 і y >= 5
    CALL check_x_ge_5
    JNE try_cond_3          ; Якщо X < 5, перевіряємо умову 3
    CALL check_y_ge_5
    JNE try_else            ; Якщо X >= 5, але Y < 5, йдемо в "otherwise"
    CALL do_calc_2          ; Розрахунок гілки 2
    JMP end_iteration

try_cond_3:
    ; Перевірка умови 3: x <= 0 і y > 10
    CALL check_x_le_0
    JNE try_else            ; Якщо X > 0, йдемо в "otherwise"
    CALL check_y_gt_10
    JNE try_else            ; Якщо Y <= 10, йдемо в "otherwise"
    CALL do_calc_3          ; Розрахунок гілки 3
    JMP end_iteration

try_else:
    ; Умова 4: Z = x + y (в інших випадках)
    CALL do_calc_else

end_iteration:
    ; Питаємо, чи хоче користувач повторити цикл
    LEA DX, run_message
    CALL print_str
    MOV AH, 01H
    INT 21H
    CMP AL, 'y'
    JE main_loop
    CMP AL, 'Y'
    JE main_loop
    
    ; Повернення управління DOS
    MOV AH, 4CH
    INT 21H
MAIN ENDP

; --- ОБЧИСЛЕННЯ УМОВИ 1: $Z = (4 + x^2) / (yx)$ ---
do_calc_1 PROC NEAR
    MOV AX, x_val
    MUL y_val               ; DX:AX = модуль знаменника
    OR DX, DX               ; Якщо DX не 0, значить знаменник > 65535
    JNZ math_overflow_c1
    MOV CX, AX              ; Зберігаємо знаменник у CX
    OR CX, CX               ; Перевірка на ділення на нуль
    JZ divide_zero_error
    
    ; Логіка знаку результату: плюс на плюс = плюс, мінус на мінус = плюс, різні = мінус
    MOV AL, x_neg
    XOR AL, y_neg           ; Визначаємо знак через XOR
    PUSH AX                 ; Зберігаємо знак у стек
    
    ; Розрахунок чисельника (x^2 + 4)
    MOV AX, x_val
    MUL x_val               ; DX:AX = x^2
    ADD AX, 4
    ADC DX, 0               ; Додаємо 4 до 32-бітного результату в DX:AX
    
    ; Ділення 32-бітного чисельника (DX:AX) на 16-бітний знаменник (CX)
    DIV CX                  ; AX = ціла частина, DX = остача
    
    MOV res_quot, AX
    MOV res_rem, DX
    POP AX
    MOV res_neg, AL         ; Повертаємо знак зі стеку
    
    ; Перевірка: якщо результат від'ємний, він не має бути більшим за 32768
    CMP res_neg, 1
    JNE print_c1_result
    CMP res_quot, 8000H
    JA math_overflow_c1
    
print_c1_result:
    CALL print_complex_res  ; Друк із остачею
    RET
math_overflow_c1: JMP math_overflow_err
divide_zero_error: JMP div_by_zero_err
do_calc_1 ENDP

; --- ОБЧИСЛЕННЯ УМОВИ 2: $Z = 25y$ ---
do_calc_2 PROC NEAR
    MOV AX, y_val
    MOV CX, 25
    MUL CX                  ; AX = 25 * y_val
    JC math_overflow_c2     ; Перевірка фізичного оверфлоу (>65535)
    
    ; Перевірка ліміту для від'ємного числа
    CMP y_neg, 1
    JNE save_result_c2
    CMP AX, 8000H
    JA math_overflow_c2
save_result_c2:
    MOV res_quot, AX
    MOV AL, y_neg
    MOV res_neg, AL
    CALL print_simple_res   ; Друк простого результату
    RET
math_overflow_c2: JMP math_overflow_err
do_calc_2 ENDP

; --- ОБЧИСЛЕННЯ УМОВИ 3: $Z = 4x$ ---
do_calc_3 PROC NEAR
    MOV AX, x_val
    MOV CX, 4
    MUL CX
    JC math_overflow_c3
    CMP x_neg, 1
    JNE save_result_c3
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

; --- ОБЧИСЛЕННЯ УМОВИ 4: $Z = x + y$ ---
do_calc_else PROC NEAR
    MOV AL, x_neg
    CMP AL, y_neg
    JNE different_signs     ; Якщо знаки різні, йдемо до віднімання
    
    ; ОДНАКОВІ ЗНАКИ: додаємо модулі
    MOV AX, x_val
    ADD AX, y_val
    JC math_overflow_else   ; Оверфлоу суми
    CMP x_neg, 1
    JNE save_result_c4
    CMP AX, 8000H           ; Ліміт негативного числа
    JA math_overflow_else
save_result_c4:
    MOV res_quot, AX
    MOV AL, x_neg
    MOV res_neg, AL
    JMP print_else_result

different_signs:
    ; РІЗНІ ЗНАКИ: віднімаємо менший модуль від більшого
    MOV AX, x_val
    CMP AX, y_val
    JAE x_is_bigger         
    ; Модуль Y більший: Z = Y - X, знак від Y
    MOV AX, y_val
    SUB AX, x_val
    MOV res_quot, AX
    MOV AL, y_neg       
    JMP print_else_result
x_is_bigger:
    ; Модуль X більший або рівний: Z = X - Y, знак від X
    SUB AX, y_val
    MOV res_quot, AX
    MOV AL, x_neg       
print_else_result:
    CALL print_simple_res
    RET
math_overflow_else: JMP math_overflow_err
do_calc_else ENDP

; --- ПРОЦЕДУРИ ВИВОДУ ---
print_simple_res PROC NEAR
    LEA DX, msg_res_z
    CALL print_str
    MOV AX, res_quot
    MOV BL, res_neg
    CALL print_number_with_sign
    RET
print_simple_res ENDP

print_complex_res PROC NEAR
    LEA DX, msg_res_z
    CALL print_str
    MOV AX, res_quot
    MOV BL, res_neg
    CALL print_number_with_sign
    ; Виводимо остачу, тільки якщо вона не нуль
    MOV AX, res_rem
    OR AX, AX
    JZ print_exit
    LEA DX, msg_remain
    CALL print_str
    MOV AX, res_rem
    MOV BL, 0               ; Остача завжди позитивна
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

; --- ПРОЦЕДУРИ ЛОГІЧНИХ ПЕРЕВІРОК ---
; Кожна процедура встановлює ZF=1 (успіх) або ZF=0 (невдача)

check_x_less_5:
    CMP x_neg, 1
    JE set_true            ; Від'ємне X завжди < 5
    CMP x_val, 5
    JB set_true            ; Додатне X перевіряємо модуль
    JMP set_false       

check_y_less_5:
    CMP y_neg, 1
    JE set_true
    CMP y_val, 5
    JB set_true
    JMP set_false

check_x_ge_5:
    CMP x_neg, 1
    JE set_false           ; Від'ємне X ніколи не >= 5
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
    JE set_true            ; Від'ємне X завжди <= 0
    CMP x_val, 0
    JE set_true            ; Нуль теж
    JMP set_false

check_y_gt_10:
    CMP y_neg, 1
    JE set_false           ; Від'ємне Y ніколи не > 10
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

; --- ПРОЦЕДУРА ВВОДУ ЧИСЛА З КЛАВІАТУРИ ---
input_number PROC NEAR
start_input:
    ; Друкуємо запит ("Enter X/Y:")
    MOV DX, current_prompt
    CALL print_str      
    
    ; Читаємо рядок у буфер
    MOV AH, 0Ah
    LEA DX, buf
    INT 21H
    CALL line               ; Перехід на новий рядок
    
    XOR CX, CX
    MOV CL, [buf + 1]       ; Реальна кількість введених символів
    JCXZ empty_input        ; Помилка, якщо просто натиснули Enter
    
    XOR BX, BX              ; Очищаємо акумулятор результату
    MOV is_negative, 0
    LEA SI, buf + 2         ; Вказуємо на перший символ тексту

    ; Перевірка наявності мінуса
    MOV AL, [SI]
    CMP AL, '-'
    JNE check_plus
    MOV is_negative, 1      ; Встановлюємо прапорець
    INC SI
    DEC CX
    JZ invalid_input        ; Помилка, якщо ввели тільки мінус
    JMP convert_loop

check_plus:
    ; Перевірка наявності плюса (просто ігноруємо його)
    CMP AL, '+'
    JNE convert_loop
    INC SI
    DEC CX
    JZ invalid_input
    
convert_loop:
    ; Основний цикл перетворення тексту в число
    MOV AL, [SI]
    CMP AL, '0'
    JB invalid_input        ; Не цифра
    CMP AL, '9'
    JA invalid_input        ; Не цифра
    
    SUB AL, '0'             ; ASCII -> Digit
    XOR AH, AH
    PUSH AX                 ; Зберігаємо цифру
    
    MOV AX, BX
    MOV DI, 10
    MUL DI                  ; Множимо поточну суму на 10
    JC overflow_pop         ; Помилка, якщо число вийшло за 16 біт
    
    POP DX                  ; Отримуємо цифру
    ADD AX, DX              ; Додаємо до суми
    JC overflow_input
    
    MOV BX, AX              ; Зберігаємо результат у BX
    INC SI
    LOOP convert_loop
    
    ; Перевірка ліміту для від'ємного числа (-32768)
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

; --- ДОПОМІЖНІ ФУНКЦІЇ ---
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

; --- ПЕРЕТВОРЕННЯ ЧИСЛА В ТЕКСТ ТА ВИВІД НА ЕКРАН ---
print_number_with_sign PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    
    ; Виводимо мінус, якщо число від'ємне та не нуль
    CMP BL, 1           
    JNE prepare_print
    OR AX, AX           
    JZ prepare_print
    PUSH AX
    MOV AH, 02H
    MOV DL, '-'
    INT 21H
    POP AX
    
prepare_print:
    XOR CX, CX
    MOV BX, 10              ; Дільник
    
divide_to_stack:
    ; Ділимо число на 10, остачу (цифру) кладемо в стек
    XOR DX, DX
    DIV BX              
    PUSH DX             
    INC CX
    OR AX, AX               ; Поки є що ділити
    JNZ divide_to_stack
    
pop_and_print:
    ; Дістаємо цифри зі стеку (вони там у зворотному порядку)
    POP DX              
    ADD DL, '0'             ; Digit -> ASCII
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