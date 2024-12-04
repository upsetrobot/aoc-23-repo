;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Advent of Code Christmas Challenge Day 12 - Part I
;
; @brief    Find the sum of different possible arrangements of broken springs.
;
;           I hate this problem!! I tried permutation theory, which doesn't 
;           work with all the constraints, then I successfully made formulas 
;           that worked using complicated math which was great, but it only 
;           worked for ?s and not ?s with #s mixed in. And I could not find 
;           a way to account for all situations to mathematically find a 
;           solution. I then looked into combinatorics. Either finishing my 
;           work on my counting theory or perfecting combinatorics with 
;           constraints would work, but I have wasted too much time.
;
;           I did not want to brute force this, but then studying 
;           combinatorics led me to a recursive approach which is probably the 
;           correct solution (eventhough it is basically brute force with 
;           optimization through checking which was my first idea before I 
;           decided that the problem could be mathematically calculated in 
;           constant time for any problem). Basically, I am abandoning the 
;           mathematical solution in favor of a recursive one to make 
;           constraints easier to deal with. I accept defeat in trying to 
;           master the mathematical solution (but I am sure one exists; you 
;           should be able to put the number of each known group, number of 
;           each set of consecutive ?s and #s and how they are connected and 
;           you should be able to spit an answer out).
;
;           https://doubleroot.in/lessons/permutations-combinations/permutations-identical-objects-examples/.
;           https://brilliant.org/wiki/rectangular-grid-walk-no-restriction/
;
; @file         solution.nasm
; @date         13 Dec 2023
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
        push rbx

        xor rbx, rbx                        ; sum.
        
        .whileLines:
            test rdi, rdi
            je .endWhileLines

            call getLine

            mov r12, rax                    ; nxt_line.
            mov r13, rdi                    ; line.
            xor rcx, rcx
            mov rdx, 0x7fffffffffffffff

            .parseNumbers:
                push rcx
                push rdx
                call scanNumber

                pop rdx
                pop rcx
                cmp rax, rdx
                je .endParseNumbers

                push rax
                inc rcx
                inc rdi
                jmp .parseNumbers

            .endParseNumbers:

            ; Allocate array.
            ; Considering just using stack instead.
            mov r15, rcx                    ; arr_len.
            lea rdi, [rcx*8]
            call memAlloc

            mov r14, rax                    ; arr.
            mov rcx, r15

            .fillArr:
                test rcx, rcx
                jz .endFillArr

                pop rdx
                mov [rax + rcx*8 - 8], rdx
                dec rcx
                jmp .fillArr

            .endFillArr:

            mov rdi, r14
            mov rsi, r15
            mov rdx, r13
            xor rcx, rcx
            xor r8, r8
            mov r9b, '.'
            push '.'
            call dynamicSolution

            pop r10
            add rbx, rax

            ; Deallocate array.
            lea rdi, [r15*8]
            call memDealloc

            test rax, rax
            js .err

            mov rdi, r12
            jmp .whileLines

        .endWhileLines:

        mov rax, rbx
        jmp .end

        .err:
            mov rdi, STDERR
            mov rsi, err_getSolution
            mov rdx, err_getSolution_len
            mov rax, SYS_WRITE
            syscall

            or rax, FUNC_FAILURE
        
        .end:
            pop rbx
            pop r15
            pop r14
            pop r13
            pop r12
            leave
            ret

    ; End getSolution.


    ; size_t dynamicSolution(
    ;       size_t* group_arr, 
    ;       size_t group_arr_len, 
    ;       char* string, 
    ;       size_t curr_num_pounds, 
    ;       size_t curr_group,
    ;       char first_sym,
    ;       char prev_sym
    ; );
    ;
    ; @brief    Recusive solve problem.
    ;
    ; @return   size_t      The number of ways to meet constraints.
    ;
    dynamicSolution:
        push rbp
        mov rbp, rsp
        push r12
        push r13
        push r14
        push r15

        mov r12, rdi                    ; group_arr.
        mov r13, rsi                    ; group_arr_len.
        mov r14, rdx                    ; string.
        xor r15, r15                    ; ret_val.
        mov r10, [rsp + 8*6]             ; prev_sym.

        mov rdi, r14
        dec rsi                         ; Last group number.
        dec rdi

        .checkFirstSym:
            cmp r9b, '.'
            je .dot

            cmp r9b, '#'
            je .pound

            cmp r9b, '?'
            je .question
            jmp .return0

        .checkLetter:
            cmp byte [rdi], '.'
            je .dot

            cmp byte [rdi], '#'
            je .pound

            cmp byte [rdi], '?'
            je .question

            cmp r8, r13
            je .return1

            cmp r8, rsi
            jne .return0

            cmp rcx, [r12 + r8*8]
            jne .return0
            jmp .return1

        .question:
            ; Here ways are equal to ways as a dot + ways as a pound.
            ; Need to pass string, current number of pounds, current group, 
            ; and rest of groups.
            inc rdi
            
            push rdi
            push rcx
            push r8

            push r10
            mov rdx, rdi
            mov rdi, r12
            mov rsi, r13
            mov r9, '#'
            call dynamicSolution

            pop r10
            pop r8
            pop rcx
            pop rdi
            add r15, rax

            push r10
            mov rdx, rdi
            mov rdi, r12
            mov rsi, r13
            mov r9, '.'
            call dynamicSolution

            pop r10
            add rax, r15
            jmp .end

        .pound:
            cmp r8, rsi
            jg .return0

            ; Check if curr_pounds exceeds group target.
            inc rcx
            cmp rcx, [r12 + r8*8]
            jg .return0
            
            inc rdi
            mov r10b, '#'
            jmp .checkLetter

        .dot:
            cmp r10b, '#'
            jne .contCheck

            .closeGroup:
                cmp r8, rsi
                jg .return0

                cmp rcx, [r12 + r8*8]
                jl .return0

                xor rcx, rcx
                inc r8
                
            .contCheck:
                inc rdi
                mov r10b, '.'
                jmp .checkLetter

        .return1:
            xor rax, rax
            inc rax
            jmp .end

        .return0:
            xor rax, rax

        .end:
            pop r15
            pop r14
            pop r13
            pop r12
            leave
            ret

    ; End dynamicSolution.


; End of file.