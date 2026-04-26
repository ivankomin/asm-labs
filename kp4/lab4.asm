; Ivan Komin IP-44
.model small
.386                
.stack 100h

.data
    mas             dd 100 dup(0)     
    n_elements      dw 0            
    
    res_sum         dd 0
    res_max         dd 0
    res_min         dd 0
    
    buf             db 7, ?, 7 dup(?)
    
    msg_menu        db 13, 10, 10, "Choose an option:"
                    db 13, 10, "1 - Show Stats (Sum, Max, Min)"
                    db 13, 10, "2 - Re-enter Array"
                    db 13, 10, "Any other key - Exit"
                    db 13, 10, "Your choice: $"

    msg_size_p      db 13, 10, "Enter array size (2-100): $"
    msg_input       db 13, 10, "Enter element (-32768..65535): $"

    msg_err_size    db 13, 10, "Error: Invalid array size!$"
    msg_err_val     db 13, 10, "Error: Invalid element!$"
    msg_err_sum_ovf db 13, 10, "Error: Sum overflowed [-32768..65535]!$"
    
    msg_res_sum     db 13, 10, 10, "Sum of elements: $"
    msg_res_max     db 13, 10, "Maximum element: $"
    msg_res_min     db 13, 10, "Minimum element: $"

.code
start:
    mov ax, @data
    mov ds, ax

; --- INPUT ARRAY ELEMENTS ---
input_phase:
    lea dx, msg_size_p
    mov ah, 09h
    int 21h
    
    call read_input           
    cmp bl, 1    ; use bl as error flag for more modularity           
    je  size_error
    
    cmp eax, 2
    jl  size_error
    cmp eax, 100
    jg  size_error
    
    mov n_elements, ax
    jmp start_fill

size_error:
    lea dx, msg_err_size
    mov ah, 09h
    int 21h
    jmp input_phase

; Actually fill the array with elements
start_fill:
    mov cx, n_elements
    xor si, si              
fill_loop:
    push cx
    lea dx, msg_input
    mov ah, 09h
    int 21h
    
    call read_input           
    cmp bl, 0               
    je  store_element

    lea dx, msg_err_val
    mov ah, 09h
    int 21h
    pop cx
    jmp fill_loop

store_element:
    mov mas[si], eax        
    add si, 4               
    pop cx
    loop fill_loop

; --- MAIN MENU ---
main_menu:
    lea dx, msg_menu
    mov ah, 09h
    int 21h
    
    mov ah, 01h             
    int 21h
    mov bh, al              

    cmp bh, '1'
    je  action_stats
    cmp bh, '2'
    je  input_phase
    
    jmp exit_program        

; --- ACTION 1: Calculate sum, min and max ---
action_stats:
    xor si, si
    mov cx, n_elements
    mov eax, mas[si]        ; take 1st element for comparison
    mov edx, eax            ; Max
    mov ebx, eax            ; Min
    mov edi, 0              ; Sum (32-bit register)

stats_loop:
    mov eax, mas[si]        ; read current element 
    add edi, eax            ; add it to the sum
    
    cmp eax, edx            ; compare current element with max
    jle not_max             ; skip if less or equal
    mov edx, eax            ; update max if greater     
not_max:
    cmp eax, ebx            ; compare current element with min
    jge not_min             ; skip if greater or equal
    mov ebx, eax            ; update min if less    
not_min:
    add si, 4               ; move to next element
    loop stats_loop
    ; save all results
    mov res_sum, edi
    mov res_max, edx
    mov res_min, ebx

    ; and print them out
    lea dx, msg_res_max
    mov ah, 09h
    int 21h
    mov eax, res_max
    call print_number

    lea dx, msg_res_min
    mov ah, 09h
    int 21h
    mov eax, res_min
    call print_number

    ; check if the sum overflowed
    mov eax, edi            
    call check_bounds
    cmp bl, 1
    je  sum_overflow

    lea dx, msg_res_sum
    mov ah, 09h
    int 21h
    mov eax, res_sum
    call print_number
    
    jmp main_menu

sum_overflow:
    lea dx, msg_err_sum_ovf
    mov ah, 09h
    int 21h
    jmp main_menu

exit_program:
    mov ax, 4c00h
    int 21h

; PROCEDURE: Input ASCII and convert to Binary
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
    xor edi, edi            ; edi acts as is_negative flag
    cmp byte ptr [si], '-'  ; byte ptr means we need to read only one byte
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
    cmp bl, '9'
    jg  r_err
    imul eax, 10
    add eax, ebx
    inc si
    loop r_conv
    cmp edi, 1
    jne r_lim
    neg eax                 
r_lim:
    call check_bounds       
    jmp r_fin
r_err:
    mov bl, 1               ; Error status
r_fin:
    pop edi esi edx ecx
    ret
read_input endp

; PROCEDURE: Check if EAX is within [-32768..65535]
check_bounds proc near
    cmp eax, 65535
    jg  out_of_bounds
    cmp eax, -32768
    jl  out_of_bounds
    mov bl, 0               ; Success
    ret
out_of_bounds:
    mov bl, 1               ; Error
    ret
check_bounds endp

; PROCEDURE: Convert Binary to ASCII and Print
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