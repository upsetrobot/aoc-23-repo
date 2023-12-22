;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Advent of Code Christmas Challenge Day 13 - Part I
;
; @brief    Find the rows above a reflection row or to the left of a 
;           reflection column and return the sum of the values found for each 
;           image.
;
; @file         solution.nasm
; @date         20 Dec 2023
; @author       upsetrobot
; @copyright    Copyright (c) 2023
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%include "lib.nasm"

%define FUNC_SUCCESS    0
%define FUNC_FAILURE    -1

%define EXIT_SUCCESS    0
%define EXIT_FAILURE    -1

%define NULL            0

%define TRUE    1
%define FALSE   0


; Global constants.
section .rodata

    filename                db  "input.txt", 0
    
    err_main                db  "Error Main", 10, 0
    err_main_len            equ $ - err_main

    err_getSolution         db  "Error getSolution", 10, 0
    err_getSolution_len     equ $ - err_getSolution
    
    msg             db  "Solution: ", 0
    msg_len         equ $ - msg


; Global uninitialized variables.
section .bss

    ;


; Global initialized variables.
section .data

    ;


; Code.
section .text

    global main

    ; int main();
    ;
    ; @brief    Main function.
    ;
    ; @return   int Returns EXIT_SUCCESS if no errors; otherwise returns 
    ;               EXIT_FAILURE.
    ;
    main:
        push rbp
        mov rbp, rsp

        mov rdi, filename
        call getFile

        test eax, eax
        jz .err

        mov rdi, [rax]
        call getSolution

        mov rdi, rax
        mov rsi, 1
        call numToStr

        push rax

        mov rdi, msg
        xor rsi, rsi
        call print

        pop rdi
        xor rsi, rsi
        inc sil
        call print

        xor rax, rax                ; EXIT_SUCCESS.
        jmp .end

        .err:
            mov rdi, STDERR
            mov rsi, err_main
            mov rdx, err_main_len
            mov rax, SYS_WRITE
            syscall

            or rax, EXIT_FAILURE
        
        .end:
            leave
            ret

    ; End main.


    ; size_t getSolution(char* fileBuffer);
    ;
    ; @brief    Solves problem and returns solution value.
    ;
    ; @return   size_t  Returns solution value.
    getSolution:
        push rbp
        mov rbp, rsp
        push r12
        push r13
        push r14
        push r15

        xor r12, r12                ; sum.
        
        .whileImg:
            cmp byte [rdi], 0
            je .endWhileImg

            cmp byte [rdi], 0xa
            jne .setupImg

            inc rdi

            .setupImg:
                xor rcx, rcx
                not rcx
                push rdi
                cld
                mov al, 0xa
                repne scasb
                not rcx
                pop rdi
                mov r8, rcx                 ; line_len.

                mov r9, rdi                 ; top_left.
                add rdi, r8

                .findBottomRight:
                    cmp byte [rdi], 0xa
                    je .endFindBottomRight

                    dec rdi
                    cmp byte [rdi], 0
                    je .endFindBottomRight

                    inc rdi
                    add rdi, r8
                    jmp .findBottomRight

                .endFindBottomRight:
                    dec rdi
                    mov r10, rdi            ; bottom_right.

            ; Check columns.
            mov rdi, r9            
            lea r11, [rdi + r8 - 2]         ; last_col.
            xor rdx, rdx                    ; cols_left.
            xor r13, r13
            xor r14, r14
            xor r15, r15                    ; col_score.            

            .findColRef:
                cmp rdi, r11
                je .colRefNotFound

                mov rsi, rdi
                inc rsi
                mov r13, rdi                ; curr_left.
                mov r14, rsi                ; curr_right.
                xor rcx, rcx                ; curr_score.
                push rdi

                .checkCols:
                    cmp rdi, r9
                    jl .colRefFound

                    cmp rsi, r11
                    jg .colRefFound

                    .checkCol:
                        cmp rdi, r10
                        jg .endCheckCol

                        mov al, [rsi]
                        cmp al, [rdi]
                        jne .endCheckCols

                        add rdi, r8
                        add rsi, r8
                        jmp .checkCol

                    .endCheckCol:
                        inc rcx
                        dec r13
                        inc r14
                        mov rdi, r13
                        mov rsi, r14
                        jmp .checkCols

                    .colRefFound:
                        cmp rcx, r15
                        jle .endCheckCols

                        .updateScore:
                        mov r15, rcx
                        mov rdx, [rsp]
                        sub rdx, r9
                        inc rdx

                .endCheckCols:
                    pop rdi
                    inc rdi
                    jmp .findColRef

            .colRefNotFound:
                add r12, rdx
                cmp rdx, 0
                jg .getNextImg

            ; Check rows.
            mov rdi, r9
            mov rsi, rdi
            add rsi, r8
            xor rdx, rdx                    ; rows_above.
            xor r11, r11                    ; highest_row_score.
            xor r13, r13                    ; curr_high_row.
            xor r14, r14                    ; curr_low_row.
            xor r15, r15                    ; row_score.            

            .findRowRef:
                cmp rsi, r10
                jg .rowRefNotFound

                mov r13, rdi
                mov r14, rsi
                xor rax, rax                ; curr_score.
                push rdi
                inc rdx

                .checkRows:
                    cmp rdi, r9
                    jl .rowRefFound

                    cmp rsi, r10
                    jg .rowRefFound

                    .checkRow:
                        mov rcx, r8
                        cld
                        repe cmpsb
                        test rcx, rcx
                        jnz .endCheckRows

                    .endCheckRow:
                        inc rax
                        sub r13, r8
                        add r14, r8
                        mov rdi, r13
                        mov rsi, r14
                        jmp .checkRows

                    .rowRefFound:
                        cmp rax, r15
                        jle .endCheckRows

                        .updateRowScore:
                        mov r15, rax
                        mov r11, rdx

                .endCheckRows:
                    pop rdi
                    add rdi, r8
                    mov rsi, rdi
                    add rsi, r8
                    jmp .findRowRef

            .rowRefNotFound:
                mov rax, r11
                mov rcx, 100
                cqo
                mul rcx
                add r12, rax
                add rbx, rax

            .getNextImg:
                mov rdi, r10
                inc rdi
                jmp .whileImg
            
        .endWhileImg:
            mov rax, r12

        .end:
            pop r15
            pop r14
            pop r13
            pop r12
            leave
            ret

    ; End getSolution.


; End of file.
