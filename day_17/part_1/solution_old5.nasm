;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Advent of Code Christmas Challenge Day 17 - Part I
;
; @brief    Find the minimum sum of the digits along the path from the top 
;           right to bottom left while only being able to move 3 consecutive 
;           step in one direction at most at one time.
;
;           Old4 works but it was taking hours. So, I added an optimization 
;           which seems to greatly speed up the process. Unfortunately, the 
;           algorithm is still pretty slow. Old4 was running for about 8 hours 
;           and still not done. This one ran in about 2 hours. 
;
;           Answer is WRONG??!!
;
;           Both crash if not run in gdb for some reason. I think it may be 
;           related to a stack size thing or something.
;
;           I don't know what else to do. I implemented so many approaches 
;           including a modified dykstra's but none of them are super fast or 
;           if they are, they have errors due to the step thing. 
;
;           Maybe if you check the memo before calling the function would 
;           help, but to me it seems logically the same. My first few attempts 
;           were much faster but were not giving the correct answers on the 
;           large dataset and has potential logic errors. I'm sticking with 
;           this for now and will look into more some other time.
;
; @file         solution.nasm
; @date         26 Dec 2023
; @author       upsetrobot
; @copyright    Copyright (c) 2023
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%include "lib.nasm"

%define FUNC_SUCCESS    0
%define FUNC_FAILURE    -1

%define EXIT_SUCCESS    0
%define EXIT_FAILURE    -1

%define NULL            0

%define NEWLINE         10

%define TRUE    1
%define FALSE   0

%define RIGHT   0b00000001
%define DOWN    0b00000010
%define LEFT    0b00000100
%define UP      0b00001000

%define VISITED '/'                     ; Less than or equal to.
%define VISIT   10

%define MAX_STEPS   3


; Global constants.
section .rodata

    filename                db  "input.txt", 0
    
    err_main                db  "Error Main", 10, 0
    err_main_len            equ $ - err_main

    err_getSolution         db  "Error getSolution", 10, 0
    err_getSolution_len     equ $ - err_getSolution
    
    msg                     db  "Solution: ", 0


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

        push rdi
        xor rcx, rcx
        not rcx
        mov al, NEWLINE
        cld
        repne scasb
        not rcx
        pop rdi
        mov r8, rcx                     ; line_len.

        push rdi
        call strLen

        pop rdi

        mov r9, rax                     ; str_len.
        lea r10, [rdi + rax]            ; bottom_right.

        ; Make list.
        struc memo

            .from_left0:        resq    1
            .from_left1:        resq    1
            .from_left2:        resq    1
            .from_left_path:    resd    1
            .from_left_steps:   resd    1

            .from_right0:       resq    1
            .from_right1:       resq    1
            .from_right2:       resq    1
            .from_right3:       resq    1
            .from_right_path:   resd    1
            .from_right_steps:  resd    1

            .from_above0:       resq    1
            .from_above1:       resq    1
            .from_above2:       resq    1
            .from_above3:       resq    1
            .from_above_path:   resd    1
            .from_above_steps:  resd    1

            .from_below0:       resq    1
            .from_below1:       resq    1
            .from_below2:       resq    1
            .from_below3:       resq    1
            .from_below_path:   resd    1
            .from_below_steps:  resd    1

        endstruc

        push rdi
        mov rdi, r9
        shl rdi, 7                      ; Multiply by 128.
        call memAlloc

        pop rdi
        mov r11, rax                    ; memo.

        ; Fill all with high value.
        push rdi
        mov rdi, r11
        mov rcx, r9
        shl rcx, 7

        .loop:
            mov byte [rdi], -1
            inc rdi
            loop .loop

        pop rdi

        lea r12, [r10 -1]               ; tgt.
        or rbx, -1                      ; curr_shortest.

        ; Keep register the way they are to pass to function.
        mov rsi, rdi                    ; curr_position.
        xor rdx, rdx                    ; steps.
        xor rax, rax
        mov al, byte [rdi]
        sub al, '0'
        sub rdx, rax
        mov rcx, NULL                   ; dir.
        mov r13, r12
        mov r12, r11
        mov r11, r10
        mov r10, r9
        mov r9, r8
        xor r8, r8
        call findPath

        mov rax, rbx

        .end:
            pop rbx
            pop r15
            pop r14
            pop r13
            pop r12
            leave
            ret

    ; End getSolution.


    ; size_t findPath(
    ;   char* top_left,                 ; rdi.
    ;   char* curr_pos,                 ; rsi.
    ;   size_t curr_path_len,           ; rdx.
    ;   char dir,                       ; rcx.
    ;   size_t steps,                   ; r8.
    ;   size_t line_len,                ; r9.
    ;   size_t str_len,                 ; r10.
    ;   char* bottom_right,             ; r11.
    ;   memo* memo,                     ; r12.
    ;   char* tgt,                      ; r13.
    ; );
    ;
    ; @brief    Find the shortest path to lower-right corner.
    ;
    ; @return   size_t  Length of place or FUNC_FAILURE if err.
    ;
    findPath: 
        push rbp
        mov rbp, rsp
        push 15

        .check:
            ; Check if on board.
            cmp byte [rsi], NULL
            je .wrong

            cmp byte [rsi], NEWLINE
            je .wrong

            cmp rsi, rdi
            jb .wrong

            cmp rsi, r11
            ja .wrong

            ; Visited?
            cmp byte [rsi], VISITED
            jbe .wrong

            ; Check path_len.
            xor r14, r14
            mov r14b, byte [rsi]
            sub r14b, '0'
            add rdx, r14

            cmp rdx, rbx
            ja .wrong

            ; Check memo.
            mov r14, rsi
            sub r14, rdi
            
            mov rax, r14
            shl rax, 7
            lea rax, [r12 + rax]

            cmp rcx, RIGHT
            je .fromLeft

            cmp rcx, LEFT
            je .fromRight

            cmp rcx, UP
            je .fromBelow

            cmp rcx, DOWN
            je .fromAbove

            jmp .memoUpdated

            .fromLeft:

                cmp r8, 0
                je .left0

                cmp r8, 1
                je .left1

                cmp r8, 2
                je .left2

                int3

                .left0:
                    cmp rdx, [rax + memo.from_left0]
                    ja .wrong

                    mov [rax + memo.from_left0], rdx
                    jmp .leftOpt

                .left1:

                    cmp rdx, [rax + memo.from_left1]
                    ja .wrong

                    mov [rax + memo.from_left1], rdx
                    jmp .leftOpt

                .left2:
                    cmp rdx, [rax + memo.from_left2]
                    ja .wrong

                    mov [rax + memo.from_left2], rdx
                    jmp .leftOpt

                .leftOpt:
                    cmp r8d, [rax + memo.from_left_steps]
                    jb .leftUpdate

                    cmp edx, [rax + memo.from_left_path]
                    ja .wrong
                    jmp .memoUpdated

                    .leftUpdate:
                        cmp edx, [rax + memo.from_left_path]
                        jae .memoUpdated

                        mov [rax + memo.from_left_path], edx
                        mov [rax + memo.from_left_steps], r8d
                        jmp .memoUpdated
                
            .fromRight:
                cmp r8, 0
                je .right0

                cmp r8, 1
                je .right1

                cmp r8, 2
                je .right2

                int3

                .right0:
                    cmp rdx, [rax + memo.from_right0]
                    ja .wrong

                    mov [rax + memo.from_right0], rdx
                    jmp .rightOpt

                .right1:
                    cmp rdx, [rax + memo.from_right1]
                    ja .wrong

                    mov [rax + memo.from_right1], rdx
                    jmp .rightOpt

                .right2:
                    cmp rdx, [rax + memo.from_right2]
                    ja .wrong

                    mov [rax + memo.from_right2], rdx
                    jmp .rightOpt

                .rightOpt:
                    cmp r8d, [rax + memo.from_right_steps]
                    jb .rightUpdate

                    cmp edx, [rax + memo.from_right_path]
                    ja .wrong
                    jmp .memoUpdated

                    .rightUpdate:
                        cmp edx, [rax + memo.from_right_path]
                        jae .memoUpdated

                        mov [rax + memo.from_right_path], edx
                        mov [rax + memo.from_right_steps], r8d
                        jmp .memoUpdated

            .fromBelow:
                cmp r8, 0
                je .below0

                cmp r8, 1
                je .below1

                cmp r8, 2
                je .below2

                int3

                .below0:
                    cmp rdx, [rax + memo.from_below0]
                    ja .wrong

                    mov [rax + memo.from_below0], rdx
                    jmp .belowOpt

                .below1:
                    cmp rdx, [rax + memo.from_below1]
                    ja .wrong

                    mov [rax + memo.from_below1], rdx
                    jmp .belowOpt

                .below2:
                    cmp rdx, [rax + memo.from_below2]
                    ja .wrong

                    mov [rax + memo.from_below2], rdx
                    jmp .belowOpt

                .belowOpt:
                    cmp r8d, [rax + memo.from_below_steps]
                    jb .belowUpdate

                    cmp edx, [rax + memo.from_below_path]
                    ja .wrong
                    jmp .memoUpdated

                    .belowUpdate:
                        cmp edx, [rax + memo.from_below_path]
                        jae .memoUpdated

                        mov [rax + memo.from_below_path], edx
                        mov [rax + memo.from_below_steps], r8d
                        jmp .memoUpdated

            .fromAbove:
                cmp r8, 0
                je .above0

                cmp r8, 1
                je .above1

                cmp r8, 2
                je .above2

                int3

                .above0:
                    cmp rdx, [rax + memo.from_above0]
                    ja .wrong

                    mov [rax + memo.from_above0], rdx
                    jmp .aboveOpt

                .above1:
                    cmp rdx, [rax + memo.from_above1]
                    ja .wrong

                    mov [rax + memo.from_above1], rdx
                    jmp .aboveOpt

                .above2:
                    cmp rdx, [rax + memo.from_above2]
                    ja .wrong

                    mov [rax + memo.from_above2], rdx
                    jmp .aboveOpt

                .aboveOpt:
                    cmp r8d, [rax + memo.from_above_steps]
                    jb .aboveUpdate

                    cmp edx, [rax + memo.from_above_path]
                    ja .wrong
                    jmp .memoUpdated

                    .aboveUpdate:
                        cmp edx, [rax + memo.from_above_path]
                        jae .memoUpdated

                        mov [rax + memo.from_above_path], edx
                        mov [rax + memo.from_above_steps], r8d
                        jmp .memoUpdated

            .memoUpdated:

            ; Visit.
            sub byte [rsi], VISIT

            ; Check target.
            cmp rsi, r13
            je .found
            
            or r15, -1                  ; ret.

        .down:
            push rsi
            push rdx
            push rcx
            push r8

            cmp rcx, UP
            je .leaveDown

            cmp rcx, DOWN
            jne .turnDown

            inc r8
            cmp r8, MAX_STEPS
            jne .moveDown
            jmp .leaveDown

            .turnDown:
                xor r8, r8

            .moveDown:
                add rsi, r9
                mov rcx, DOWN
                call findPath

                cmp rax, r15
                jae .leaveDown

                mov r15, rax

            .leaveDown:
                pop r8
                pop rcx
                pop rdx
                pop rsi

        .right:
            push rsi
            push rdx
            push rcx
            push r8

            cmp rcx, LEFT
            je .leaveRight

            cmp rcx, RIGHT
            jne .turnRight

            inc r8
            cmp r8, MAX_STEPS
            jne .moveRight
            jmp .leaveRight

            .turnRight:
                xor r8, r8

            .moveRight:
                inc rsi
                mov rcx, RIGHT
                call findPath

                cmp rax, r15
                jae .leaveRight

                mov r15, rax

            .leaveRight:
                pop r8
                pop rcx
                pop rdx
                pop rsi

        .left:
            push rsi
            push rdx
            push rcx
            push r8

            cmp rcx, RIGHT
            je .leaveLeft

            cmp rcx, LEFT
            jne .turnLeft

            inc r8
            cmp r8, MAX_STEPS
            jne .moveLeft
            jmp .leaveLeft

            .turnLeft:
                xor r8, r8

            .moveLeft:
                dec rsi
                mov rcx, LEFT
                call findPath

                cmp rax, r15
                jae .leaveLeft

                mov r15, rax

            .leaveLeft:
                pop r8
                pop rcx
                pop rdx
                pop rsi

        .up:
            push rsi
            push rdx
            push rcx
            push r8

            cmp rcx, DOWN
            je .leaveUp

            cmp rcx, UP
            jne .turnUp

            inc r8
            cmp r8, MAX_STEPS
            jne .moveUp
            jmp .leaveUp

            .turnUp:
                xor r8, r8

            .moveUp:
                sub rsi, r9
                mov rcx, UP
                call findPath

                cmp rax, r15
                jae .leaveUp

                mov r15, rax

            .leaveUp:
                pop r8
                pop rcx
                pop rdx
                pop rsi

        .unvisit:
            add byte [rsi], VISIT
            mov rax, r15
            jmp .end        

        .found:
            ; Print.
            ; push rdi
            ; push rsi
            ; push rdx
            ; push rcx
            ; push r8
            ; push r9
            ; push r10
            ; push r11
            ; call print
            ; mov rdi, nl
            ; call print
            ; pop r11
            ; pop r10
            ; pop r9
            ; pop r8
            ; pop rcx
            ; pop rdx
            ; pop rsi
            ; pop rdi

            add byte [rsi], VISIT

            mov rax, rdx
            cmp rax, rbx
            jae .end

            mov rbx, rax
            jmp .end

        .wrong:
            or rax, FUNC_FAILURE

        .end:
            pop r15
            leave
            ret
    
    ; End findPath.


; End of file.