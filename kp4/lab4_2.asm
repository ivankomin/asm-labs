.model small
.386                
.stack 100h

.data
    matrix          dd 100 dup(0)     
    rows            dw 0            
    cols            dw 0
    is_error        db 0            
    
    target          dd 0
    found_count     dw 0
    
    buf             db 7, ?, 7 dup(?)
    
    msg_menu        db 13, 10, 10, "Choose an option:"
                    db 13, 10, "1 - Find element indices"
                    db 13, 10, "2 - Re-enter Matrix"
                    db 13, 10, "Any other key - Exit"
                    db 13, 10, "Your choice: $"

    msg_rows_p      db 13, 10, "Enter number of rows (2-10): $"
    msg_cols_p      db 13, 10, "Enter number of columns (2-10): $"
    msg_input       db 13, 10, "Enter element (-32768..65535) [$"
    msg_comma       db ", $"
    msg_bracket     db "]: $"
    
    msg_target_p    db 13, 10, "Enter target element: $"
    msg_res_found   db 13, 10, "Found at: $"
    msg_not_found   db 13, 10, "Not found in matrix.$"
    msg_idx_start   db "[", "$"
    msg_idx_end     db "] ", "$"

    msg_err_size    db 13, 10, "Error: Invalid size!$"
    msg_err_val     db 13, 10, "Error: Invalid element!$"

.code
start:
    mov ax, @data
    mov ds, ax

;input matrix dimensions
input_rows:                 
    lea dx, msg_rows_p
    mov ah, 09h
    int 21h
    call read_input
    cmp is_error, 1

    je  err_rows
    cmp eax, 2
    jl  err_rows
    cmp eax, 10
    jg  err_rows

    mov rows, ax
    jmp input_cols          

err_rows:
    lea dx, msg_err_size
    mov ah, 09h
    int 21h
    jmp input_rows          

input_cols:                
    lea dx, msg_cols_p
    mov ah, 09h
    int 21h
    call read_input
    cmp is_error, 1

    je  err_cols
    cmp eax, 2
    jl  err_cols
    cmp eax, 10
    jg  err_cols

    mov cols, ax
    jmp start_fill_matrix

err_cols:
    lea dx, msg_err_size
    mov ah, 09h
    int 21h
    jmp input_cols          

; fill the matrix
start_fill_matrix:
    xor si, si              ; flat index in bytes
    xor bx, bx              ; current row
row_loop:
    xor di, di              ; current col
col_loop:
element_retry:              ; separate mark for each element
    lea dx, msg_input
    mov ah, 09h
    int 21h
    
    movzx eax, bx           ; get row number and fill higher bits with 0
    call print_number
    lea dx, msg_comma
    mov ah, 09h
    int 21h
    movzx eax, di           ; get col number and fill higher bits with 0
    call print_number
    lea dx, msg_bracket
    mov ah, 09h
    int 21h
    
    call read_input
    cmp is_error, 1
    je val_error
    
    mov matrix[si], eax
    add si, 4
    inc di
    cmp di, cols
    jl col_loop
    
    inc bx
    cmp bx, rows
    jl row_loop
    jmp main_menu

val_error:
    lea dx, msg_err_val
    mov ah, 09h
    int 21h
    jmp element_retry       ; Перепитуємо тільки цей елемент

; --- ГОЛОВНЕ МЕНЮ ---
main_menu:
    lea dx, msg_menu
    mov ah, 09h
    int 21h
    mov ah, 01h
    int 21h
    
    cmp al, '1'
    je action_find
    cmp al, '2'
    je input_rows           ; Повний перезапуск матриці за бажанням
    jmp exit_program

; --- ПОШУК ЕЛЕМЕНТА ---
action_find:
    lea dx, msg_target_p
    mov ah, 09h
    int 21h
    call read_input
    cmp is_error, 1
    je main_menu
    mov target, eax
    
    mov found_count, 0
    lea dx, msg_res_found
    mov ah, 09h
    int 21h

    xor si, si              
    xor bx, bx              
find_row:
    xor di, di              
find_col:
    mov eax, matrix[si]
    cmp eax, target
    jne next_step
    
    inc found_count
    lea dx, msg_idx_start
    mov ah, 09h
    int 21h
    movzx eax, bx
    call print_number
    lea dx, msg_comma
    mov ah, 09h
    int 21h
    movzx eax, di
    call print_number
    lea dx, msg_idx_end
    mov ah, 09h
    int 21h

next_step:
    add si, 4
    inc di
    cmp di, cols
    jl find_col
    
    inc bx
    cmp bx, rows
    jl find_row
    
    cmp found_count, 0
    jne main_menu
    lea dx, msg_not_found
    mov ah, 09h
    int 21h
    jmp main_menu

exit_program:
    mov ax, 4c00h
    int 21h

; --- PROCEDURES ---

read_input proc near
    push ebx ecx edx esi edi
    
    mov is_error, 0         
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
    cmp eax, 65535
    jg r_err
    cmp eax, -32768
    jl r_err
    jmp r_fin

r_err:
    mov is_error, 1         
r_fin:
    pop edi esi edx ecx ebx
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