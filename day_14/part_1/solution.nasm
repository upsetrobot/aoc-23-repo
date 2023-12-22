;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Advent of Code Christmas Challenge Day 14 - Part I
;
; @brief    Move all the `0`s that can move to the top and calculate the 
;           total of each number of `0` in each row multiplied by their row 
;           number (where the bottom row is row 1).
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

        ; Probably start at top and move all rolling rocks up. 
        ; Alternatively, we may just be able to count the rocks in each column
        ; but will run into rock being between cubes, so probably easier to 
        ; move everything.
        push rdi
        call moveRocks

        pop rdi
        
        ; Then just calculate the load.
        call calcLoad

        .end:
            leave
            ret

    ; End getSolution.


    ; size_t moveRocks(char* buf);
    ;
    ; @brief    Moves the rocks to the north.
    ;
    ; @return   size_t  Returns `0` if successful, else returns `-1`.
    ;
    moveRocks:
        push rbp
        mov rbp, rsp
        push r12
        push r13

        ; Probably start at bottom right and move each rock up one column 
        ; at a time.
        mov r12, rdi                    ; start.

        ; Get line_len.
        mov al, 0xa
        xor rcx, rcx
        not rcx
        cld
        repne scasb
        not rcx
        mov r8, rcx                     ; line_len.
        mov rdi, r12

        ; Get bottom right.
        .getBottom:
            cmp byte [rdi], 0
            je .endGetBottom

            inc rdi
            jmp .getBottom

        .endGetBottom:
            mov r9, rdi                 ; bottom_right.

        ; Travel each col moving rocks up.
        mov rdi, r12
        mov r13, rdi
        add r13, r8                     ; top_right.
        dec r13

        .forEaCol:
            cmp rdi, r13
            je .endForEaCol

            mov r10, rdi

            .forCol:
                cmp r10, r9
                jg .endForCol

                cmp byte [r10], 'O'
                je .rock

                add r10, r8
                jmp .forCol

                .rock:
                    mov r11, r10
                    sub r11, r8

                    cmp r11, r12
                    jl .endRock

                    cmp byte [r11], '.'
                    jne .endRock

                    mov byte [r11], 'O'
                    mov byte [r10], '.'
                    sub r10, r8
                    jmp .rock

                .endRock:
                    add r10, r8
                    jmp .forCol

            .endForCol:
                inc rdi
                jmp .forEaCol

        .endForEaCol:
            xor rax, rax

        .end:
            pop r13
            pop r12
            leave
            ret

    ; End moveRocks.


    ; size_t calcLoad(char* buf);
    ;
    ; @brief    Calculates the load of the north beam.
    ;
    ; @return   size_t  The load value.
    ;
    calcLoad:
        push rbp
        mov rbp, rsp
        push r12
        push r13

        mov r12, rdi
        xor r13, r13                        ; sum.

        ; Get number of rows.
        xor r8, r8

        .forGetRows:
            cmp byte [rdi], 0
            je .lastRow

            cmp byte [rdi], 0xa
            je .checkRow

            inc rdi
            jmp .forGetRows

            .checkRow:
                inc rdi
                cmp byte [rdi], 0xa
                je .lastRow

                inc r8
                jmp .forGetRows

            .lastRow:
                inc r8

        .endForGetRows:

        mov rdi, r12

        .for:
            test r8, r8
            jz .endFor

            xor rax, rax

            .countOs:
                cmp byte [rdi], 0
                je .endCountOs

                cmp byte [rdi], 0xa
                je .endCountOs

                cmp byte [rdi], 'O'
                jne .dontCount

                inc rax

                .dontCount:
                    inc rdi
                    jmp .countOs

            .endCountOs:

            cqo
            mul r8
            add r13, rax
            dec r8
            inc rdi
            jmp .for

        .endFor:
            mov rax, r13

        .end:
            pop r13
            pop r12
            leave
            ret

    ; End calcLoad.


; End of file.