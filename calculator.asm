; High-quality GTK-based calculator written in x86-64 assembly
; Assembled with: nasm -felf64 calculator.asm && gcc -no-pie calculator.o -o calculator $(pkg-config --cflags --libs gtk+-3.0) -lm

%define GTK_WINDOW_TOPLEVEL 0
%define GTK_ALIGN_START 1
%define TRUE 1
%define BUFFER_SIZE 256

section .bss align=8
app_widgets:        resq 4                ; entry1, entry2, combo, result label

section .rodata align=8
window_title:               db "Assembly Calculator",0
label_operand1:             db "Operand 1:",0
label_operand2:             db "Operand 2:",0
label_operation:            db "Operation:",0
placeholder_operand1:       db "Enter the first number",0
placeholder_operand2:       db "Enter the second number",0
button_text:                db "Calculate",0
result_initial:             db "Result: (none)",0
result_format:              db "Result: %.15g",0
signal_destroy:             db "destroy",0
signal_clicked:             db "clicked",0

op_id_add:                  db "+",0
op_label_add:               db "Addition (+)",0
op_id_sub:                  db "-",0
op_label_sub:               db "Subtraction (-)",0
op_id_mul:                  db "*",0
op_label_mul:               db "Multiplication (*)",0
op_id_div:                  db "/",0
op_label_div:               db "Division (/)",0
op_id_pow:                  db "^",0
op_label_pow:               db "Power (^)",0

error_operand1_invalid:     db "Error: Enter a valid number in Operand 1.",0
error_operand2_invalid:     db "Error: Enter a valid number in Operand 2.",0
error_operand1_range:       db "Error: Operand 1 is out of range.",0
error_operand2_range:       db "Error: Operand 2 is out of range.",0
error_operation_missing:    db "Error: Select an operation.",0
error_div_zero:             db "Error: Division by zero is undefined.",0
error_operation_unknown:    db "Error: Unsupported operation.",0
error_result_not_finite:    db "Error: Result is not a finite number.",0

align 8
exp_mask:                   dq 0x7ff0000000000000
zero_double:                dq 0.0

section .text
extern gtk_init
extern gtk_main
extern gtk_main_quit
extern gtk_window_new
extern gtk_window_set_title
extern gtk_window_set_default_size
extern gtk_container_set_border_width
extern gtk_grid_new
extern gtk_grid_set_row_spacing
extern gtk_grid_set_column_spacing
extern gtk_container_add
extern gtk_label_new
extern gtk_grid_attach
extern gtk_entry_new
extern gtk_entry_set_placeholder_text
extern gtk_widget_show_all
extern gtk_widget_set_hexpand
extern gtk_widget_set_halign
extern gtk_combo_box_text_new
extern gtk_combo_box_text_append
extern gtk_combo_box_set_active
extern gtk_combo_box_get_active_id
extern gtk_button_new_with_label
extern g_signal_connect_data
extern gtk_entry_get_text
extern g_ascii_strtod
extern __errno_location
extern gtk_label_set_text
extern g_free
extern pow
extern snprintf
extern gtk_widget_set_margin_top
extern gtk_widget_set_margin_bottom
extern gtk_widget_set_margin_start
extern gtk_widget_set_margin_end

global main

; Helper: skip leading whitespace characters (<= space). Returns pointer in RAX.
skip_trailing_spaces:
    push rbp
    mov rbp, rsp
    mov rax, rdi
.skip_loop:
    mov dl, byte [rax]
    cmp dl, 0
    je .done
    cmp dl, 32
    ja .done
    inc rax
    jmp .skip_loop
.done:
    pop rbp
    ret

; Callback for window destroy -> quit main loop
on_window_destroy:
    push rbp
    mov rbp, rsp
    sub rsp, 8
    call gtk_main_quit
    add rsp, 8
    pop rbp
    ret

; Callback for calculate button
on_calculate_clicked:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 0x160                     ; ensure 16-byte alignment and local storage

%define ENDPTR1_OFFSET     -0x140
%define ENDPTR2_OFFSET     -0x138
%define TEXT1_OFFSET       -0x130
%define TEXT2_OFFSET       -0x128
%define OPID_OFFSET        -0x120
%define OPERAND1_OFFSET    -0x118
%define OPERAND2_OFFSET    -0x110
%define RESULT_OFFSET      -0x108
%define BUFFER_OFFSET      -0x100

    mov rbx, rsi                          ; user data -> &app_widgets
    mov qword [rbp + OPID_OFFSET], 0

    ; Retrieve entry texts
    mov rdi, qword [rbx]                  ; entry 1
    call gtk_entry_get_text
    mov qword [rbp + TEXT1_OFFSET], rax

    mov rdi, qword [rbx + 8]              ; entry 2
    call gtk_entry_get_text
    mov qword [rbp + TEXT2_OFFSET], rax

    ; Parse operand 1
    call __errno_location
    mov dword [rax], 0
    lea rsi, [rbp + ENDPTR1_OFFSET]
    mov rdi, qword [rbp + TEXT1_OFFSET]
    call g_ascii_strtod
    movsd qword [rbp + OPERAND1_OFFSET], xmm0

    mov rax, qword [rbp + ENDPTR1_OFFSET]
    cmp rax, qword [rbp + TEXT1_OFFSET]
    je .invalid_operand1
    mov rdi, rax
    call skip_trailing_spaces
    mov dl, byte [rax]
    cmp dl, 0
    jne .invalid_operand1
    call __errno_location
    mov eax, dword [rax]
    test eax, eax
    jne .range_operand1

    ; Parse operand 2
    call __errno_location
    mov dword [rax], 0
    lea rsi, [rbp + ENDPTR2_OFFSET]
    mov rdi, qword [rbp + TEXT2_OFFSET]
    call g_ascii_strtod
    movsd qword [rbp + OPERAND2_OFFSET], xmm0

    mov rax, qword [rbp + ENDPTR2_OFFSET]
    cmp rax, qword [rbp + TEXT2_OFFSET]
    je .invalid_operand2
    mov rdi, rax
    call skip_trailing_spaces
    mov dl, byte [rax]
    cmp dl, 0
    jne .invalid_operand2
    call __errno_location
    mov eax, dword [rax]
    test eax, eax
    jne .range_operand2

    ; Determine selected operation ID
    mov rdi, qword [rbx + 16]
    call gtk_combo_box_get_active_id
    mov qword [rbp + OPID_OFFSET], rax
    test rax, rax
    je .missing_operation
    movzx eax, byte [rax]

    cmp al, '+'
    je .do_add
    cmp al, '-'
    je .do_sub
    cmp al, '*'
    je .do_mul
    cmp al, '/'
    je .do_div
    cmp al, '^'
    je .do_pow
    jmp .unsupported_operation

.do_add:
    movsd xmm0, qword [rbp + OPERAND1_OFFSET]
    addsd xmm0, qword [rbp + OPERAND2_OFFSET]
    movsd qword [rbp + RESULT_OFFSET], xmm0
    jmp .check_result

.do_sub:
    movsd xmm0, qword [rbp + OPERAND1_OFFSET]
    subsd xmm0, qword [rbp + OPERAND2_OFFSET]
    movsd qword [rbp + RESULT_OFFSET], xmm0
    jmp .check_result

.do_mul:
    movsd xmm0, qword [rbp + OPERAND1_OFFSET]
    mulsd xmm0, qword [rbp + OPERAND2_OFFSET]
    movsd qword [rbp + RESULT_OFFSET], xmm0
    jmp .check_result

.do_div:
    movsd xmm1, qword [rbp + OPERAND2_OFFSET]
    movsd xmm0, xmm1
    ucomisd xmm0, qword [rel zero_double]
    jp .division_by_zero
    je .division_by_zero
    movsd xmm0, qword [rbp + OPERAND1_OFFSET]
    divsd xmm0, xmm1
    movsd qword [rbp + RESULT_OFFSET], xmm0
    jmp .check_result

.do_pow:
    movsd xmm0, qword [rbp + OPERAND1_OFFSET]
    movsd xmm1, qword [rbp + OPERAND2_OFFSET]
    call pow
    movsd qword [rbp + RESULT_OFFSET], xmm0
    jmp .check_result

.check_result:
    movsd xmm0, qword [rbp + RESULT_OFFSET]
    movq rax, xmm0
    mov rdx, qword [rel exp_mask]
    and rax, rdx
    cmp rax, rdx
    je .result_not_finite

    ; Format success text
    lea rdi, [rbp + BUFFER_OFFSET]
    mov esi, BUFFER_SIZE
    mov rdx, result_format
    movsd xmm0, qword [rbp + RESULT_OFFSET]
    xor eax, eax
    mov al, 1
    call snprintf

    mov rdi, qword [rbx + 24]
    lea rsi, [rbp + BUFFER_OFFSET]
    call gtk_label_set_text
    jmp .cleanup

.invalid_operand1:
    mov rdi, qword [rbx + 24]
    mov rsi, error_operand1_invalid
    call gtk_label_set_text
    jmp .cleanup

.invalid_operand2:
    mov rdi, qword [rbx + 24]
    mov rsi, error_operand2_invalid
    call gtk_label_set_text
    jmp .cleanup

.range_operand1:
    mov rdi, qword [rbx + 24]
    mov rsi, error_operand1_range
    call gtk_label_set_text
    jmp .cleanup

.range_operand2:
    mov rdi, qword [rbx + 24]
    mov rsi, error_operand2_range
    call gtk_label_set_text
    jmp .cleanup

.missing_operation:
    mov rdi, qword [rbx + 24]
    mov rsi, error_operation_missing
    call gtk_label_set_text
    jmp .cleanup

.division_by_zero:
    mov rdi, qword [rbx + 24]
    mov rsi, error_div_zero
    call gtk_label_set_text
    jmp .cleanup

.unsupported_operation:
    mov rdi, qword [rbx + 24]
    mov rsi, error_operation_unknown
    call gtk_label_set_text
    jmp .cleanup

.result_not_finite:
    mov rdi, qword [rbx + 24]
    mov rsi, error_result_not_finite
    call gtk_label_set_text

.cleanup:
    mov rax, qword [rbp + OPID_OFFSET]
    test rax, rax
    je .skip_free
    mov rdi, rax
    call g_free
.skip_free:
    add rsp, 0x160
    pop rbx
    pop rbp
    ret

main:
    push rbp
    mov rbp, rsp
    sub rsp, 0x88                        ; align stack and reserve locals

    xor edi, edi
    xor esi, esi
    call gtk_init

    mov edi, GTK_WINDOW_TOPLEVEL
    call gtk_window_new
    mov qword [rbp - 8], rax             ; store window

    mov rdi, rax
    mov rsi, window_title
    call gtk_window_set_title

    mov rdi, qword [rbp - 8]
    mov esi, 420
    mov edx, 280
    call gtk_window_set_default_size

    mov rdi, qword [rbp - 8]
    mov esi, 16
    call gtk_container_set_border_width

    call gtk_grid_new
    mov qword [rbp - 16], rax            ; grid pointer

    mov rdi, rax
    mov esi, 12
    call gtk_grid_set_row_spacing

    mov rdi, qword [rbp - 16]
    mov esi, 12
    call gtk_grid_set_column_spacing

    mov rdi, qword [rbp - 8]
    mov rsi, qword [rbp - 16]
    call gtk_container_add

    ; Row 0: label + entry for operand 1
    mov rdi, label_operand1
    call gtk_label_new
    mov qword [rbp - 24], rax

    mov rdi, rax
    mov esi, GTK_ALIGN_START
    call gtk_widget_set_halign

    mov rdi, qword [rbp - 16]
    mov rsi, qword [rbp - 24]
    xor edx, edx                         ; column 0
    xor ecx, ecx                         ; row 0
    mov r8d, 1
    mov r9d, 1
    call gtk_grid_attach

    call gtk_entry_new
    mov qword [rel app_widgets + 0], rax

    mov rdi, rax
    mov rsi, placeholder_operand1
    call gtk_entry_set_placeholder_text

    mov rdi, qword [rel app_widgets + 0]
    mov esi, TRUE
    call gtk_widget_set_hexpand

    mov rdi, qword [rel app_widgets + 0]
    mov esi, 6
    call gtk_widget_set_margin_top

    mov rdi, qword [rel app_widgets + 0]
    mov esi, 6
    call gtk_widget_set_margin_bottom

    mov rdi, qword [rel app_widgets + 0]
    mov esi, 6
    call gtk_widget_set_margin_start

    mov rdi, qword [rel app_widgets + 0]
    mov esi, 6
    call gtk_widget_set_margin_end

    mov rdi, qword [rbp - 16]
    mov rsi, qword [rel app_widgets + 0]
    mov edx, 1                           ; column 1
    xor ecx, ecx                         ; row 0
    mov r8d, 1
    mov r9d, 1
    call gtk_grid_attach

    ; Row 1: label + entry for operand 2
    mov rdi, label_operand2
    call gtk_label_new
    mov qword [rbp - 32], rax

    mov rdi, rax
    mov esi, GTK_ALIGN_START
    call gtk_widget_set_halign

    mov rdi, qword [rbp - 16]
    mov rsi, qword [rbp - 32]
    xor edx, edx
    mov ecx, 1
    mov r8d, 1
    mov r9d, 1
    call gtk_grid_attach

    call gtk_entry_new
    mov qword [rel app_widgets + 8], rax

    mov rdi, rax
    mov rsi, placeholder_operand2
    call gtk_entry_set_placeholder_text

    mov rdi, qword [rel app_widgets + 8]
    mov esi, TRUE
    call gtk_widget_set_hexpand

    mov rdi, qword [rel app_widgets + 8]
    mov esi, 6
    call gtk_widget_set_margin_top

    mov rdi, qword [rel app_widgets + 8]
    mov esi, 6
    call gtk_widget_set_margin_bottom

    mov rdi, qword [rel app_widgets + 8]
    mov esi, 6
    call gtk_widget_set_margin_start

    mov rdi, qword [rel app_widgets + 8]
    mov esi, 6
    call gtk_widget_set_margin_end

    mov rdi, qword [rbp - 16]
    mov rsi, qword [rel app_widgets + 8]
    mov edx, 1
    mov ecx, 1
    mov r8d, 1
    mov r9d, 1
    call gtk_grid_attach

    ; Row 2: label + combo box
    mov rdi, label_operation
    call gtk_label_new
    mov qword [rbp - 40], rax

    mov rdi, rax
    mov esi, GTK_ALIGN_START
    call gtk_widget_set_halign

    mov rdi, qword [rbp - 16]
    mov rsi, qword [rbp - 40]
    xor edx, edx
    mov ecx, 2
    mov r8d, 1
    mov r9d, 1
    call gtk_grid_attach

    call gtk_combo_box_text_new
    mov qword [rel app_widgets + 16], rax

    mov rdi, rax
    mov rsi, op_id_add
    mov rdx, op_label_add
    call gtk_combo_box_text_append

    mov rdi, qword [rel app_widgets + 16]
    mov rsi, op_id_sub
    mov rdx, op_label_sub
    call gtk_combo_box_text_append

    mov rdi, qword [rel app_widgets + 16]
    mov rsi, op_id_mul
    mov rdx, op_label_mul
    call gtk_combo_box_text_append

    mov rdi, qword [rel app_widgets + 16]
    mov rsi, op_id_div
    mov rdx, op_label_div
    call gtk_combo_box_text_append

    mov rdi, qword [rel app_widgets + 16]
    mov rsi, op_id_pow
    mov rdx, op_label_pow
    call gtk_combo_box_text_append

    mov rdi, qword [rel app_widgets + 16]
    mov esi, TRUE
    call gtk_widget_set_hexpand

    mov rdi, qword [rel app_widgets + 16]
    mov esi, 6
    call gtk_widget_set_margin_top

    mov rdi, qword [rel app_widgets + 16]
    mov esi, 6
    call gtk_widget_set_margin_bottom

    mov rdi, qword [rel app_widgets + 16]
    mov esi, 6
    call gtk_widget_set_margin_start

    mov rdi, qword [rel app_widgets + 16]
    mov esi, 6
    call gtk_widget_set_margin_end

    mov rdi, qword [rbp - 16]
    mov rsi, qword [rel app_widgets + 16]
    mov edx, 1
    mov ecx, 2
    mov r8d, 1
    mov r9d, 1
    call gtk_grid_attach

    mov rdi, qword [rel app_widgets + 16]
    xor esi, esi
    call gtk_combo_box_set_active

    ; Row 3: button and result label
    mov rdi, button_text
    call gtk_button_new_with_label
    mov qword [rbp - 48], rax

    mov rdi, qword [rbp - 16]
    mov rsi, qword [rbp - 48]
    xor edx, edx
    mov ecx, 3
    mov r8d, 1
    mov r9d, 1
    call gtk_grid_attach

    mov rdi, qword [rbp - 48]
    mov esi, 10
    call gtk_widget_set_margin_top

    mov rdi, qword [rbp - 48]
    mov esi, 10
    call gtk_widget_set_margin_bottom

    mov rdi, qword [rbp - 48]
    mov esi, 6
    call gtk_widget_set_margin_start

    mov rdi, qword [rbp - 48]
    mov esi, 6
    call gtk_widget_set_margin_end

    mov rdi, result_initial
    call gtk_label_new
    mov qword [rel app_widgets + 24], rax

    mov rdi, qword [rel app_widgets + 24]
    mov esi, TRUE
    call gtk_widget_set_hexpand

    mov rdi, qword [rel app_widgets + 24]
    mov esi, GTK_ALIGN_START
    call gtk_widget_set_halign

    mov rdi, qword [rel app_widgets + 24]
    mov esi, 10
    call gtk_widget_set_margin_top

    mov rdi, qword [rel app_widgets + 24]
    mov esi, 10
    call gtk_widget_set_margin_bottom

    mov rdi, qword [rel app_widgets + 24]
    mov esi, 6
    call gtk_widget_set_margin_start

    mov rdi, qword [rel app_widgets + 24]
    mov esi, 6
    call gtk_widget_set_margin_end

    mov rdi, qword [rbp - 16]
    mov rsi, qword [rel app_widgets + 24]
    mov edx, 1
    mov ecx, 3
    mov r8d, 1
    mov r9d, 1
    call gtk_grid_attach

    ; Connect signals
    mov rdi, qword [rbp - 8]
    mov rsi, signal_destroy
    mov rdx, on_window_destroy
    xor rcx, rcx
    xor r8d, r8d
    xor r9d, r9d
    call g_signal_connect_data

    mov rdi, qword [rbp - 48]
    mov rsi, signal_clicked
    mov rdx, on_calculate_clicked
    lea rcx, [rel app_widgets]
    xor r8d, r8d
    xor r9d, r9d
    call g_signal_connect_data

    ; Show window and enter main loop
    mov rdi, qword [rbp - 8]
    call gtk_widget_show_all

    call gtk_main

    mov eax, 0
    add rsp, 0x88
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite align=1
