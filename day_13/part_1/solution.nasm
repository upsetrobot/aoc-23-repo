;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Advent of Code Christmas Challenge Day 13 - Part I
;
; @brief    Find the number of columns (to the left) or rows (above) the one 
;           reflection line in each ASCII image (separated by blank lines) and 
;           add the number of columns found to the product of 100 and the 
;           number of rows found.
;
; @file         solution.nasm
; @date         14 Dec 2023
; @author       upsetrobot
; @copyright    Copyright (c) 2023
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%include "lib.nasm"

%define STDIN   0
%define STDOUT  1
%define STDERR  2

%define SYS_READ    0
%define SYS_WRITE   1
%define SYS_OPEN    2
%define SYS_CLOSE   3
%define SYS_STAT    4
%define SYS_BRK     12

%define EXIT_SUCCESS    0
%define EXIT_FAILURE    -1

%define FUNC_SUCCESS    0
%define FUNC_FAILURE    -1

%define NULL            0

%define TRUE    1
%define FALSE   0

%define MAX_INT_STR_LEN 21

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

        xor r14, r14                    ; sum.

        .whileImage:
            test rdi, rdi
            jz .endWhileImage

            call getImage               ; rdi points to img; rax nxt_img.

            mov r12, rax                ; nxt_img.
            mov r13, rdi                ; curr_img.
            call getCols

            add r14, rax
            mov rdi, r13
            call getRows

            xor rdx, rdx
            mov rcx, 100
            mul rcx
            add r14, rax
            mov rdi, r12
            jmp .whileImage

        .endWhileImage:

        mov rax, r14
        
        .end:
            pop r15
            pop r14
            pop r13
            pop r12
            leave
            ret

    ; End getSolution.


    ; char* getImage(char* buf);
    ;
    ; @brief    Null terminates image and returns the pointer to the next 
    ;           image or NULL if there are none.
    ;
    ; @return   char*   Pointer to next image or NULL if no more images.
    ;
    getImage:
        push rbp
        mov rbp, rsp

        mov rax, rdi

        .loop:
            cmp [rax], 0
            je .last

            cmp [rax], 10
            jne .cont

            inc rax
            cmp [rax], 10
            je .endLoop

            .cont:
                inc rax
                jmp .loop

        .last:
            xor rax, rax
            jmp .end

        .endLoop:
            inc rax
            
        .end:
            leave
            ret

    ; End getImage.


    ; size_t getCols(char* img);
    ;
    ; @brief    Finds a vertical line of reflection and returns the number of 
    ;           columns to the left of it.
    ;
    ; @returns  size_t  Number of columns to left of a vertical line of 
    ;                   reflection or `0` if no line is found.
    ;
    getCols:
        push rbp
        mov rbp, rsp

        

        .end:
            leave
            ret

    ; End getCols.


    ; size_t getRows(char* img);
    ;
    ; @brief    Finds a horizontal line of reflection and returns the number 
    ;           of rows above it.
    ;
    ; @returns  size_t  Number of row above a horizontal line of reflection 
    ;                   or `0` if no line is found.
    ;
    getRows:
        push rbp
        mov rbp, rsp

        

        .end:
            leave
            ret

    ; End getRows.


; End of file.