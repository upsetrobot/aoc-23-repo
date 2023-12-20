;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Advent of Code Christmas Challenge Day 13 - Part I
;
; @brief    Find the rows above a reflection row or to the left of a 
;           reflection column and return the sum of the values found for each 
;           image.
;
; @file         solution.nasm
; @date         18 Dec 2023
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
        xor rcx, rcx
        not rcx
        push rdi
        cld
        mov al, 0xa
        repne scasb
        not rcx
        pop rdi
        mov r8, rcx                 ; line_len.
        
        .whileImg:
            cmp byte [rdi], 0
            je .endWhileImg

            cmp byte [rdi], 0xa
            jne .setupImg

            add rdi, 2

            .setupImg:
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

            mov rdi, r9            
            lea r11, [rdi + r8 - 2]         ; end_cols.
            mov r15, rdi                    ; cols.
            xor rdx, rdx                    ; cols.

            ; Better to start in middle, then go left or right. ugh.

            .getCols:
                cmp rdi, r11
                je .endGetCols

                mov rsi, rdi
                inc rsi
                inc rdx
                mov r13, rdi                ; top.
                mov r14, rsi                ; top2.

                .checkCol:
                    mov al, [rdi]
                    cmp al, [rsi]
                    jne .endCheckCol

                    add rdi, r8
                    add rsi, r8
                    cmp rdi, r10
                    jle .checkCol

                    .matchCol:
                        mov rdi, r13
                        mov rsi, r14
                        inc rsi
                        dec rdi
                        cmp rdi, r9
                        je .foundColRef

                        cmp rsi, r11
                        je .foundColRef
                        jmp .endCheckCol

                    .foundColRef:int3
                        mov r15, r14

                        ; Check middle.
                        lea rax, [r11 + 1]
                        sub rax, r15
                        cmp rdx, rax
                        jge .endGetCols

                .endCheckCol:
                    mov rdi, r13
                    inc rdi
                    jmp .getCols

            .endGetCols:
                cmp r15, r9
                je .getRows

                sub r15, r9
                add r12, r15
int3

            .getRows:
            .endGetRows:

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
