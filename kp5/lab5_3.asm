.model small
.386                
.stack 100h

; --- SECTION: MACROS ---

; Макрос для виводу рядка (статичні мітки)
M_PRINT_STR MACRO msg
    push ax
    push dx
    lea dx, msg
    mov ah, 09h
    int 21h
    pop dx
    pop ax
ENDM

; Макрос для перевірки меж 
; Директива LOCAL гарантує унікальність міток при кожному розгортанні
M_CHECK_RANGE MACRO
    LOCAL @@in_bounds, @@out_of_bounds, @@done
    cmp eax, 65535
    jg  @@out_of_bounds
    cmp eax, -32768
    jge @@in_bounds
@@out_of_bounds:
    mov bl, 1               ; Прапор помилки
    jmp @@done
@@in_bounds:
    mov bl, 0               ; Успіх
@@done:
ENDM

; Макрос для обчислення статистики масиву
M_CALC_STATS MACRO array, count, sum_v, max_v, min_v
    LOCAL @@stats_loop, @@not_max, @@not_min
    xor si, si
    mov cx, count
    mov eax, array[si]
    mov edx, eax            ; Max
    mov ebx, eax            ; Min
    mov edi, 0              ; Sum

@@stats_loop:
    mov eax, array[si]
    add edi, eax            
    
    cmp eax, edx
    jle @@not_max
    mov edx, eax            
@@not_max:
    cmp eax, ebx
    jge @@not_min
    mov ebx, eax            
@@not_min:
    add si, 4
    loop @@stats_loop
    
    mov sum_v, edi
    mov max_v, edx
    mov min_v, ebx
ENDM

; --- SECTION: DATA ---

.data
    min_size equ 2
    max_size equ 100
    mas             dd 100 dup(0)     
    n_elements      dw 0            
    
    res_sum         dd 0
    res_max         dd 0
    res_min         dd 0
    
    buf             db 12, ?, 12 dup(?)
    
    msg_menu        db 13, 10, 10, "Choose an option:"
                    db 13, 10, "1 - Show Stats (Sum, Max, Min)"
                    db 13, 10, "2 - Sort Array (Ascending)"
                    db 13, 10, "3 - Re-enter Array"
                    db 13, 10, "Any other key - Exit"
                    db 13, 10, "Your choice: $"

    msg_size_p      db 13, 10, "Enter array size (2-100): $"
    msg_input       db 13, 10, "Enter element (-32768..65535): $"

    msg_err_size    db 13, 10, "Error: Invalid array size!$"
    msg_err_val     db 13, 10, "Error: Invalid element!$"
    msg_err_sum_ovf db 13, 10, 10, "Error: Sum overflowed [-32768..65535]!$"
    
    msg_res_sum     db 13, 10, 10, "Sum of elements: $"
    msg_res_max     db 13, 10, 10, "Maximum element: $"
    msg_res_min     db 13, 10, 10, "Minimum element: $"
    msg_res_sort    db 13, 10, 10, "Array sorted! Resulting array: ", "$"
    msg_space       db "  ", "$"

; --- SECTION: CODE ---

.code
start:
    mov ax, @data
    mov ds, ax

input_phase:
    M_PRINT_STR msg_size_p
    call read_input           
    cmp bl, 1                   
    je  size_error
    
    cmp eax, min_size
    jl  size_error
    cmp eax, max_size
    jg  size_error
    
    mov n_elements, ax
    jmp start_fill

size_error:
    M_PRINT_STR msg_err_size
    jmp input_phase

start_fill:
    mov cx, n_elements
    xor si, si              
fill_loop:
    push cx     
    M_PRINT_STR msg_input
    call read_input           
    cmp bl, 0               
    je  store_element
    M_PRINT_STR msg_err_val
    pop cx
    jmp fill_loop
store_element:
    mov mas[si], eax        
    add si, 4               
    pop cx
    loop fill_loop

main_menu:
    M_PRINT_STR msg_menu
    mov ah, 01h             
    int 21h
    mov bh, al              

    cmp bh, '1'
    je  action_stats
    cmp bh, '2'
    je  action_sort
    cmp bh, '3'            
    je  input_phase
    jmp exit_program        

action_stats:
    ; Виклик макросу обчислення статистики
    M_CALC_STATS mas, n_elements, res_sum, res_max, res_min

    M_PRINT_STR msg_res_max
    mov eax, res_max
    call print_number

    M_PRINT_STR msg_res_min
    mov eax, res_min
    call print_number

    ; Перевірка суми на переповнення через макрос
    mov eax, res_sum            
    M_CHECK_RANGE               
    cmp bl, 1
    je  sum_overflow

    M_PRINT_STR msg_res_sum
    mov eax, res_sum
    call print_number
    jmp main_menu

sum_overflow:
    M_PRINT_STR msg_err_sum_ovf
    jmp main_menu

action_sort:
    call sort_array         
    M_PRINT_STR msg_res_sort
    mov cx, n_elements
    xor si, si
display_loop:              
    mov eax, mas[si]
    call print_number
    M_PRINT_STR msg_space
    add si, 4
    loop display_loop
    jmp main_menu

exit_program:
    mov ax, 4c00h
    int 21h

; --- SECTION: PROCEDURES ---

sort_array proc near
    mov cx, n_elements
    dec cx
    jz sort_done
outer_loop:
    push cx
    mov dl, 0
    xor si, si
inner_loop:
    mov eax, mas[si]
    mov ebx, mas[si+4]
    cmp eax, ebx
    jle no_swap
    mov mas[si], ebx
    mov mas[si+4], eax
    mov dl, 1
no_swap:
    add si, 4
    loop inner_loop
    pop cx
    cmp dl, 0
    je sort_done
    loop outer_loop
sort_done:
    ret
sort_array endp

read_input proc near
    push ecx edx esi edi
    mov ah, 0ah
    lea dx, buf
    int 21h
    lea si, buf + 2
    mov cl, [buf + 1]
    xor ch, ch
    jcxz r_err   
    xor eax, eax
    xor edi, edi            
    cmp byte ptr [si], '-'
    jne r_plus
    mov edi, 1
    inc si
    dec cx
    jz r_err
    jmp r_conv
r_plus:
    cmp byte ptr [si], '+'
    jne r_conv
    inc si
    dec cx
    jz r_err
r_conv:
    movzx ebx, byte ptr [si]
    sub bl, '0'
    jl  r_err
    cmp bl, 9
    jg  r_err
    imul eax, 10
    add eax, ebx
    inc si
    loop r_conv
    cmp edi, 1
    jne r_lim
    neg eax                 
r_lim:
    ; Виклик макросу перевірки всередині процедури
    M_CHECK_RANGE           
    jmp r_fin
r_err:
    mov bl, 1
r_fin:
    pop edi esi edx ecx
    ret
read_input endp

print_number proc near
    pushad
    or eax, eax
    jns p_pos
    push eax
    mov dl, '-'
    mov ah, 02h
    int 21h
    pop eax
    neg eax                 
p_pos:
    mov ebx, 10
    xor cx, cx
p_div:
    xor edx, edx
    div ebx
    push dx
    inc cx
    or eax, eax
    jnz p_div
p_out:
    pop dx
    add dl, '0'
    mov ah, 02h
    int 21h
    loop p_out
    popad
    ret
print_number endp

end start