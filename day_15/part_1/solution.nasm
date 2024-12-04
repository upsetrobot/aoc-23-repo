;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Advent of Code Christmas Challenge Day 15 - Part I
;
; @brief    Implement a given hash algorithm and hash each string and return 
;           the sum of the hashes.
;
; @file         solution.nasm
; @date         22 Dec 2023
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

        xor r12, r12

        .while:
            cmp byte [rdi], 0
            je .endWhile
            
            cmp byte [rdi], ','
            jne .cont

            inc rdi

            .cont:
                call hash               ; Updates rdi; goes to comma.

            add r12, rax
            jmp .while

        .endWhile:

        mov rax, r12

        .end:
            pop r12
            leave
            ret

    ; End getSolution.


    ; size_t hash(char* buf);
    ;
    ; @brief    Hashes the current comma-delimited string using the given 
    ;           hash algorithm.
    ;
    ; @return   size_t  Hash value.
    ;
    hash:
        push rbp
        mov rbp, rsp

        xor rax, rax

        .while:
            cmp byte [rdi], ','
            je .endWhile

            cmp byte [rdi], 0
            je .endWhile
            
            cmp byte [rdi], 0xa
            je .next

            xor rcx, rcx
            mov cl, [rdi]
            add rax, rcx

            mov rcx, 17
            cqo
            mul rcx

            mov rcx, 256
            cqo
            div rcx
            mov rax, rdx

            .next:
                inc rdi
                jmp .while

        .endWhile:

        .end:
            leave
            ret

    ; End calcLoad.


; End of file.