;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Advent of Code Christmas Challenge Day 14 - Part II
;
; @brief    Move all the `0`s that can move to the top and calculate the 
;           total of each number of `0` in each row multiplied by their row 
;           number (where the bottom row is row 1).
;
;           This time, cycle rolling between north, west, south, east 
;           1000000000 times, then calculate the load.
;
;           It takes a while (about 5-10 minutes). Not sure how to optimize it.
;           Takes way too long on actual dataset. I tried several different 
;           optimizations and approaches (most of which were worse). There 
;           may be some number pattern. 
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
        push r13
        push r14
        push r15
        push rbx

        ; Probably start at top and move all rolling rocks up. 
        ; Alternatively, we may just be able to count the rocks in each column
        ; but will run into rock being between cubes, so probably easier to 
        ; move everything.
        mov r12, rdi                    ; top_left.
        
        ; Get line_len.
        mov al, 0xa
        xor rcx, rcx
        not rcx
        cld
        repne scasb
        not rcx
        mov r13, rcx                     ; line_len.

        ; Get bottom right.
        mov rdi, r12

        .getBottom:
            cmp byte [rdi], 0
            je .endGetBottom

            inc rdi
            jmp .getBottom

        .endGetBottom:
            mov r14, rdi                 ; bottom_right.

        mov rdi, r12
        lea r15, [rdi + r13 - 1]         ; top_right.
        xor rbx, rbx

        mov r9, r14
        mov rsi, r13
        mov r13, r15
        
        .for:
            cmp rbx, 200
            je .endFor

            ; Numbers seem to be increasing by an amount with each increment 
            ; and then decreasing with some number of increments.
            ; Hit 100093 twice (once on 13) (smaller set repeated on 6 and 13).

            ; Small dataset has two number for the first two iterations, 
            ; then repeats the pattern 69,69,65,64,65,63,68 over and over.
            ; If you take 1000000000-2 mod len(7) positions ?= answer?
            ; 
            ; The real pattern is much longer. Or I should say there is a long 
            ; settling time. 
            ; Pattern is 95253,95264,95262,95265,95267,95273,95274,95270,
            ; 95267,95255,95254,95251,95269,95252 and then repeats (so one of 
            ; these is the correct answer).
            ;
            ; The settling period is around 98.
            ;
            ; How to do you programmatically figure this out?
            ; I can do it by hand; maybe you need to compare to each previous 
            ; until a solution is figured.

            push rdi
            push rsi
            push rdx
            push rcx
            push r8
            push r9
            push r10
            push r11
            push r12
            push r13
            push r14
            push r15
            mov rdi, r12
            call moveRocks

            mov rdi, r12
            call calcLoad

            mov rdi, rax
            mov rsi, 0
            call numToStr

            mov rdi, msg
            mov rsi, 0
            call print

            mov rdi, num_str
            call print

            pop r15
            pop r14
            pop r13
            pop r12
            pop r11
            pop r10
            pop r9
            pop r8
            pop rcx
            pop rdx
            pop rsi
            pop rdi

            inc rbx
            jmp .for

        .endFor:
        
        ; Then just calculate the load.
        mov rdi, r12
        call calcLoad

        .end:
            pop rbx
            pop r15
            pop r14
            pop r13
            pop r12
            leave
            ret

    ; End getSolution.


    ; size_t moveRocks(
    ;   char* buf, 
    ;   size_t line_len, 
    ;   char* bottom_right,
    ;   char* top_right
    ; );
    ;
    ; @brief    Moves the rocks to the north, west, south, and east.
    ;
    ; @return   size_t  Returns `0` if successful, else returns `-1`.
    ;
    moveRocks:
        ; push rbp
        ; mov rbp, rsp
        ; push r12
        ; push r13

        ; Probably start at bottom right and move each rock up one column 
        ; at a time.
        ; mov r12, rdi                    ; start.
        ; mov r9, rdx                     ; bottom_right.
        ; mov r13, rcx                    ; top_right. 
        mov rdi, r12

        ; Travel each col moving rocks up.
        .forEaCol:
            cmp rdi, r13
            je .endForEaCol

            mov r10, rdi

            .forCol:
                cmp r10, r9
                jg .endForCol

                cmp byte [r10], 'O'
                je .rock

                add r10, rsi
                jmp .forCol

                .rock:
                    mov r11, r10
                    sub r11, rsi

                    cmp r11, rdi
                    jl .endRock

                    cmp byte [r11], '.'
                    jne .endRock

                    sub r11, rsi

                    .rockLoop:
                        cmp byte [r11], '.'
                        jne .xchgRock

                        sub r11, rsi
                        jmp .rockLoop

                    .xchgRock:
                        mov byte [r11 + rsi], 'O'
                        mov byte [r10], '.'
                        
                .endRock:
                    add r10, rsi
                    jmp .forCol

            .endForCol:
                inc rdi
                jmp .forEaCol

        .endForEaCol:

        ; Roll rocks west.
        mov rdi, r12
        
        .forEaRowWest:
            cmp rdi, r9
            jg .endForEaRowWest

            mov r10, rdi

            .forRowWest:
                cmp byte [r10], 0
                je .endForRowWest

                cmp byte [r10], 0xa
                je .endForRowWest

                cmp byte [r10], 'O'
                je .rockWest

                inc r10
                jmp .forRowWest

                .rockWest:
                    mov r11, r10
                    dec r11

                    cmp r11, rdi
                    jl .endRockWest

                    cmp byte [r11], '.'
                    jne .endRockWest

                    .rockWestLoop:
                        dec r11
                        cmp byte [r11], '.'
                        jne .rockWestXchg
                        jmp .rockWestLoop

                        .rockWestXchg:
                            mov byte [r11 + 1], 'O'
                            mov byte [r10], '.'

                .endRockWest:
                    inc r10
                    jmp .forRowWest

            .endForRowWest:
                add rdi, rsi
                jmp .forEaRowWest

        .endForEaRowWest:

        ; Roll rocks South.
        mov rdi, r9
        sub rdi, rsi
        inc rdi

        .forEaColSouth:
            cmp rdi, r9
            je .endForEaColSouth

            mov r10, rdi

            .forColSouth:
                cmp r10, r12
                jl .endForColSouth

                cmp byte [r10], 'O'
                je .rockSouth

                sub r10, rsi
                jmp .forColSouth

                .rockSouth:
                    mov r11, r10
                    add r11, rsi

                    cmp r11, rdi
                    jg .endRockSouth

                    cmp byte [r11], '.'
                    jne .endRockSouth

                    .rockSouthLoop:
                        add r11, rsi
                        cmp r11, rdi
                        jg .rockSouthXchg

                        cmp byte [r11], '.'
                        jne .rockSouthXchg
                        jmp .rockSouthLoop

                        .rockSouthXchg:
                            sub r11, rsi
                            mov byte [r11], 'O'
                            mov byte [r10], '.'

                .endRockSouth:
                    sub r10, rsi
                    jmp .forColSouth

            .endForColSouth:
                inc rdi
                jmp .forEaColSouth

        .endForEaColSouth:

        ; Roll rocks east.
        lea rdi, [r13 - 1]
        
        .forEaRowEast:
            cmp rdi, r9
            jg .endForEaRowEast

            mov r10, rdi

            .forRowEast:
                cmp r10, r12
                jl .endForRowEast

                cmp byte [r10], 0xa
                je .endForRowEast

                cmp byte [r10], 'O'
                je .rockEast

                dec r10
                jmp .forRowEast

                .rockEast:
                    mov r11, r10
                    inc r11
                    cmp r11, rdi
                    jg .endRockEast

                    cmp byte [r11], '.'
                    jne .endRockEast

                    .rockEastLoop:
                        inc r11
                        cmp r11, rdi
                        jg .rockEastXchg

                        cmp byte [r11], '.'
                        jne .rockEastXchg
                        jmp .rockEastLoop

                        .rockEastXchg:
                            mov byte [r11 - 1], 'O'
                            mov byte [r10], '.'

                .endRockEast:
                    dec r10
                    jmp .forRowEast

            .endForRowEast:
                add rdi, rsi
                jmp .forEaRowEast

        .endForEaRowEast:
            xor rax, rax

        .end:
            ; pop r13
            ; pop r12
            ; leave
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