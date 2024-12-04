;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Advent of Code Christmas Challenge Day 17 - Part II
;
; @brief    Find the minimum sum of the digits along the path from the top 
;           right to bottom left while only being able to move 3 consecutive 
;           step in one direction at most at one time.
;
;           This time you have to move a minimum of 4 steps before turning and 
;           you can move a maximum of 10 steps.
;
; @file         solution.nasm
; @date         28 Dec 2023
; @author       upsetrobot
; @copyright    Copyright (c) 2023
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Includes.
%include "lib.nasm"


; Macros.
%define FUNC_SUCCESS    0
%define FUNC_FAILURE    -1

%define EXIT_SUCCESS    0
%define EXIT_FAILURE    -1

%define NULL            0

%define NEWLINE         10

%define TRUE    1
%define FALSE   0

%define RIGHT   0b0001
%define DOWN    0b0010
%define LEFT    0b0100
%define UP      0b1000

%define MIN_STEPS   4
%define MAX_STEPS   10

%define MUL_256_SHIFTER 8

%define VISITED     0
%define UNVISITED   0xff


; Struc definitions.
struc memo

    .right4_path:       resd    1
    .right5_path:       resd    1

    .right6_path:       resd    1
    .right7_path:       resd    1

    .right8_path:       resd    1
    .right9_path:       resd    1

    .right10_path:      resd    1
    .left4_path:        resd    1


    .left5_path:        resd    1
    .left6_path:        resd    1

    .left7_path:        resd    1
    .left8_path:        resd    1

    .left9_path:        resd    1
    .left10_path:       resd    1

    .up4_path:          resd    1
    .up5_path:          resd    1


    .up6_path:          resd    1
    .up7_path:          resd    1

    .up8_path:          resd    1
    .up9_path:          resd    1

    .up10_path:         resd    1
    .down4_path:        resd    1
    
    .down5_path:        resd    1
    .down6_path:        resd    1


    .down7_path:        resd    1
    .down8_path:        resd    1

    .down9_path:        resd    1
    .down10_path:       resd    1

    .right4_visited:    resb    1
    .right5_visited:    resb    1
    .right6_visited:    resb    1
    .right7_visited:    resb    1
    .right8_visited:    resb    1
    .right9_visited:    resb    1
    .right10_visited:   resb    1
    .left4_visited:     resb    1

    .left5_visited:     resb    1
    .left6_visited:     resb    1
    .left7_visited:     resb    1
    .left8_visited:     resb    1
    .left9_visited:     resb    1
    .left10_visited:    resb    1
    .up4_visited:       resb    1
    .up5_visited:       resb    1

    .up6_visited:       resb    1
    .up7_visited:       resb    1
    .up8_visited:       resb    1
    .up9_visited:       resb    1
    .up10_visited:      resb    1
    .down4_visited:     resb    1
    .down5_visited:     resb    1
    .down6_visited:     resb    1

    .down7_visited:     resb    1
    .down8_visited:     resb    1
    .down9_visited:     resb    1
    .down10_visited:    resb    1
    .pad:               resb    4

    .pad_add:           resq    14

endstruc


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

        ; Get line_len and str_len, top_left, and bottom_right.
        push rdi                        ; top_left/src.
        or rcx, -1
        mov al, NEWLINE
        cld
        repne scasb
        not rcx
        mov r8, rcx                     ; line_len.
        pop rdi

        push rdi
        call strLen

        mov r9, rax                     ; str_len/memo_len.
        pop rdi
        
        lea r10, [rdi + r9 - 1]         ; bottom_right/tgt.

        ; Make arr.
        push rdi
        mov rdi, r9
        shl rdi, MUL_256_SHIFTER
        call memAlloc

        mov r11, rax                    ; memo.
        mov rcx, r9
        shl rcx, MUL_256_SHIFTER
        mov rdi, r11

        .fill:
            mov byte [rdi], 0xff
            inc rdi
            loop .fill

        pop rdi

        ; Init state.
        mov rsi, rdi                    ; curr_pos.
        xor rdx, rdx                    ; curr_path.
        mov rcx, RIGHT                  ; curr_dir.
        mov r12, 1                      ; curr_steps.

        mov dword [r11 + memo.right4_path], 0
        mov byte [r11 + memo.right4_visited], 0

        mov dword [r11 + memo.down4_path], 0
        mov byte [r11 + memo.down4_visited], 0

        ; rdi = top_left/src.
        ; rsi = curr_pos.
        ; rdx = curr_path.
        ; rcx = curr_dir.
        ; r8 = line_len.
        ; r9 = memo_len/str_len.
        ; r10 = bottom_right/tgt.
        ; r11 = memo.
        ; r12 = curr_steps.
        ; r13 = ?
        ; r14 = ?
        ; r15 = ?
        ; rax = ?
        ; rbx = shortest_path.
                
        ; Do visited loop.
        .while:

            ; Exit when bottom right has been visited from top and left.
            .checkForSolution:
                mov rax, r10
                sub rax, rdi
                shl rax, MUL_256_SHIFTER
                add rax, r11                ; memo_loc.
                mov ebx, -1
            
                .right4:
                    cmp byte [rax + memo.right4_visited], VISITED
                    jne .exploreNeighbors

                    cmp [rax + memo.right4_path], ebx
                    jae .right5

                    mov ebx, [rax + memo.right4_path]

                .right5:
                    cmp byte [rax + memo.right5_visited], VISITED
                    jne .exploreNeighbors

                    cmp [rax + memo.right5_path], ebx
                    jae .right6

                    mov ebx, [rax + memo.right5_path]

                .right6:
                    cmp byte [rax + memo.right6_visited], VISITED
                    jne .exploreNeighbors

                    cmp [rax + memo.right6_path], ebx
                    jae .right7

                    mov ebx, [rax + memo.right6_path]

                .right7:
                    cmp byte [rax + memo.right7_visited], VISITED
                    jne .exploreNeighbors

                    cmp [rax + memo.right7_path], ebx
                    jae .right8

                    mov ebx, [rax + memo.right7_path]

                .right8:
                    cmp byte [rax + memo.right8_visited], VISITED
                    jne .exploreNeighbors

                    cmp [rax + memo.right8_path], ebx
                    jae .right9

                    mov ebx, [rax + memo.right8_path]

                .right9:
                    cmp byte [rax + memo.right9_visited], VISITED
                    jne .exploreNeighbors

                    cmp [rax + memo.right9_path], ebx
                    jae .right10

                    mov ebx, [rax + memo.right9_path]

                .right10:
                    cmp byte [rax + memo.right10_visited], VISITED
                    jne .exploreNeighbors

                    cmp [rax + memo.right10_path], ebx
                    jae .down4

                    mov ebx, [rax + memo.right10_path]

                .down4:
                    cmp byte [rax + memo.down4_visited], VISITED
                    jne .exploreNeighbors

                    cmp [rax + memo.down4_path], ebx
                    jae .down5

                    mov ebx, [rax + memo.down4_path]

                .down5:
                    cmp byte [rax + memo.down5_visited], VISITED
                    jne .exploreNeighbors

                    cmp [rax + memo.down5_path], ebx
                    jae .down6

                    mov ebx, [rax + memo.down5_path]

                .down6:
                    cmp byte [rax + memo.down6_visited], VISITED
                    jne .exploreNeighbors

                    cmp [rax + memo.down6_path], ebx
                    jae .down7

                    mov ebx, [rax + memo.down6_path]

                .down7:
                    cmp byte [rax + memo.down7_visited], VISITED
                    jne .exploreNeighbors

                    cmp [rax + memo.down7_path], ebx
                    jae .down8

                    mov ebx, [rax + memo.down7_path]

                .down8:
                    cmp byte [rax + memo.down8_visited], VISITED
                    jne .exploreNeighbors

                    cmp [rax + memo.down8_path], ebx
                    jae .down9

                    mov ebx, [rax + memo.down8_path]

                .down9:
                    cmp byte [rax + memo.down9_visited], VISITED
                    jne .exploreNeighbors

                    cmp [rax + memo.down9_path], ebx
                    jae .down10

                    mov ebx, [rax + memo.down9_path]

                .down10:
                    cmp byte [rax + memo.down10_visited], VISITED
                    jne .exploreNeighbors

                    cmp [rax + memo.down10_path], ebx
                    jae .found

                    mov ebx, [rax + memo.down10_path]

                .found:
                    jmp .endWhile


            .exploreNeighbors:
                mov rax, rsi
                sub rax, rdi
                shl rax, MUL_256_SHIFTER    ; curr_node_memo_loc.

                cmp rcx, RIGHT
                je .right

                cmp rcx, LEFT
                je .left

                cmp rcx, UP
                je .up

                cmp rcx, DOWN
                je .down

                int3

                .right:
                    push r12
                    cmp rsi, rdi
                    je .skipIncRight

                    inc r12

                    .skipIncRight:
                        call exploreRightNeighbor
                        mov r12, 1
                        call exploreUpNeighbor
                        mov r12, 1
                        call exploreDownNeighbor
                        pop r12
                        jmp .visitRight

                .left:
                    push r12
                    inc r12
                    call exploreLeftNeighbor
                    mov r12, 1
                    call exploreUpNeighbor
                    mov r12, 1
                    call exploreDownNeighbor
                    pop r12
                    jmp .visitLeft

                .up:
                    push r12
                    inc r12
                    call exploreUpNeighbor
                    mov r12, 1
                    call exploreLeftNeighbor
                    mov r12, 1
                    call exploreRightNeighbor
                    pop r12
                    jmp .visitUp

                .down:
                    push r12
                    inc r12
                    call exploreDownNeighbor
                    mov r12, 1
                    call exploreLeftNeighbor
                    mov r12, 1
                    call exploreRightNeighbor
                    pop r12
                    jmp .visitDown

            ; Visit curr_node.
            .visitRight:
                cmp r12, MIN_STEPS
                je .visitRight.4

                cmp r12, 5
                je .visitRight.5

                cmp r12, 6
                je .visitRight.6

                cmp r12, 7
                je .visitRight.7

                cmp r12, 8
                je .visitRight.8

                cmp r12, 9
                je .visitRight.9

                cmp r12, MAX_STEPS
                je .visitRight.10
                jmp .doneVisit

                .visitRight.4:
                    mov byte [r11 + rax + memo.right4_visited], VISITED
                    jmp .doneVisit

                .visitRight.5:
                    mov byte [r11 + rax + memo.right5_visited], VISITED
                    jmp .doneVisit

                .visitRight.6:
                    mov byte [r11 + rax + memo.right6_visited], VISITED
                    jmp .doneVisit

                .visitRight.7:
                    mov byte [r11 + rax + memo.right7_visited], VISITED
                    jmp .doneVisit

                .visitRight.8:
                    mov byte [r11 + rax + memo.right8_visited], VISITED
                    jmp .doneVisit

                .visitRight.9:
                    mov byte [r11 + rax + memo.right9_visited], VISITED
                    jmp .doneVisit

                .visitRight.10:
                    mov byte [r11 + rax + memo.right10_visited], VISITED
                    jmp .doneVisit

            .visitLeft:
                cmp r12, MIN_STEPS
                je .visitLeft.4

                cmp r12, 5
                je .visitLeft.5

                cmp r12, 6
                je .visitLeft.6

                cmp r12, 7
                je .visitLeft.7

                cmp r12, 8
                je .visitLeft.8

                cmp r12, 9
                je .visitLeft.9

                cmp r12, MAX_STEPS
                je .visitLeft.10
                jmp .doneVisit

                .visitLeft.4:
                    mov byte [r11 + rax + memo.left4_visited], VISITED
                    jmp .doneVisit

                .visitLeft.5:
                    mov byte [r11 + rax + memo.left5_visited], VISITED
                    jmp .doneVisit

                .visitLeft.6:
                    mov byte [r11 + rax + memo.left6_visited], VISITED
                    jmp .doneVisit

                .visitLeft.7:
                    mov byte [r11 + rax + memo.left7_visited], VISITED
                    jmp .doneVisit

                .visitLeft.8:
                    mov byte [r11 + rax + memo.left8_visited], VISITED
                    jmp .doneVisit

                .visitLeft.9:
                    mov byte [r11 + rax + memo.left9_visited], VISITED
                    jmp .doneVisit

                .visitLeft.10:
                    mov byte [r11 + rax + memo.left10_visited], VISITED
                    jmp .doneVisit

            .visitUp:
                cmp r12, MIN_STEPS
                je .visitUp.4

                cmp r12, 5
                je .visitUp.5

                cmp r12, 6
                je .visitUp.6

                cmp r12, 7
                je .visitUp.7

                cmp r12, 8
                je .visitUp.8

                cmp r12, 9
                je .visitUp.9

                cmp r12, MAX_STEPS
                je .visitUp.10
                jmp .doneVisit

                .visitUp.4:
                    mov byte [r11 + rax + memo.up4_visited], VISITED
                    jmp .doneVisit

                .visitUp.5:
                    mov byte [r11 + rax + memo.up5_visited], VISITED
                    jmp .doneVisit

                .visitUp.6:
                    mov byte [r11 + rax + memo.up6_visited], VISITED
                    jmp .doneVisit

                .visitUp.7:
                    mov byte [r11 + rax + memo.up7_visited], VISITED
                    jmp .doneVisit

                .visitUp.8:
                    mov byte [r11 + rax + memo.up8_visited], VISITED
                    jmp .doneVisit

                .visitUp.9:
                    mov byte [r11 + rax + memo.up9_visited], VISITED
                    jmp .doneVisit

                .visitUp.10:
                    mov byte [r11 + rax + memo.up10_visited], VISITED
                    jmp .doneVisit

            .visitDown:
                cmp r12, MIN_STEPS
                je .visitDown.4

                cmp r12, 5
                je .visitDown.5

                cmp r12, 6
                je .visitDown.6

                cmp r12, 7
                je .visitDown.7

                cmp r12, 8
                je .visitDown.8

                cmp r12, 9
                je .visitDown.9

                cmp r12, MAX_STEPS
                je .visitDown.10
                jmp .doneVisit

                .visitDown.4:
                    mov byte [r11 + rax + memo.down4_visited], VISITED
                    jmp .doneVisit

                .visitDown.5:
                    mov byte [r11 + rax + memo.down5_visited], VISITED
                    jmp .doneVisit

                .visitDown.6:
                    mov byte [r11 + rax + memo.down6_visited], VISITED
                    jmp .doneVisit

                .visitDown.7:
                    mov byte [r11 + rax + memo.down7_visited], VISITED
                    jmp .doneVisit

                .visitDown.8:
                    mov byte [r11 + rax + memo.down8_visited], VISITED
                    jmp .doneVisit

                .visitDown.9:
                    mov byte [r11 + rax + memo.down9_visited], VISITED
                    jmp .doneVisit

                .visitDown.10:
                    mov byte [r11 + rax + memo.down10_visited], VISITED
                    jmp .doneVisit

            .doneVisit:

            ; Find lowest_unvisited.
            or rdx, -1                      ; curr_lowest_path
            xor rcx, rcx                    ; curr_dir.
            xor r12, r12                    ; curr_steps.
            xor rax, rax                    ; curr_idx.
            xor r13, r13                    ; curr_memo.
            xor rsi, rsi                    ; curr_pos.

            .find:
                cmp rax, r9
                je .endFind

                mov r13, rax
                shl r13, MUL_256_SHIFTER

                .find.right4:
                    cmp byte [r11 + r13 + memo.right4_visited], VISITED
                    je .find.right5

                    cmp edx, [r11 + r13 + memo.right4_path]
                    jbe .find.right5

                    mov edx, [r11 + r13 + memo.right4_path]
                    mov rcx, RIGHT
                    mov r12, 4
                    lea rsi, [rdi + rax]

                .find.right5:
                    cmp byte [r11 + r13 + memo.right5_visited], VISITED
                    je .find.right6

                    cmp edx, [r11 + r13 + memo.right5_path]
                    jbe .find.right6

                    mov edx, [r11 + r13 + memo.right5_path]
                    mov rcx, RIGHT
                    mov r12, 5
                    lea rsi, [rdi + rax]

                .find.right6:
                    cmp byte [r11 + r13 + memo.right6_visited], VISITED
                    je .find.right7

                    cmp edx, [r11 + r13 + memo.right6_path]
                    jbe .find.right7

                    mov edx, [r11 + r13 + memo.right6_path]
                    mov rcx, RIGHT
                    mov r12, 6
                    lea rsi, [rdi + rax]

                .find.right7:
                    cmp byte [r11 + r13 + memo.right7_visited], VISITED
                    je .find.right8

                    cmp edx, [r11 + r13 + memo.right7_path]
                    jbe .find.right8

                    mov edx, [r11 + r13 + memo.right7_path]
                    mov rcx, RIGHT
                    mov r12, 7
                    lea rsi, [rdi + rax]

                .find.right8:
                    cmp byte [r11 + r13 + memo.right8_visited], VISITED
                    je .find.right9

                    cmp edx, [r11 + r13 + memo.right8_path]
                    jbe .find.right9

                    mov edx, [r11 + r13 + memo.right8_path]
                    mov rcx, RIGHT
                    mov r12, 8
                    lea rsi, [rdi + rax]

                .find.right9:
                    cmp byte [r11 + r13 + memo.right9_visited], VISITED
                    je .find.right10

                    cmp edx, [r11 + r13 + memo.right9_path]
                    jbe .find.right10

                    mov edx, [r11 + r13 + memo.right9_path]
                    mov rcx, RIGHT
                    mov r12, 9
                    lea rsi, [rdi + rax]

                .find.right10:
                    cmp byte [r11 + r13 + memo.right10_visited], VISITED
                    je .find.left4

                    cmp edx, [r11 + r13 + memo.right10_path]
                    jbe .find.left4

                    mov edx, [r11 + r13 + memo.right10_path]
                    mov rcx, RIGHT
                    mov r12, 10
                    lea rsi, [rdi + rax]

                .find.left4:
                    cmp byte [r11 + r13 + memo.left4_visited], VISITED
                    je .find.left5

                    cmp edx, [r11 + r13 + memo.left4_path]
                    jbe .find.left5

                    mov edx, [r11 + r13 + memo.left4_path]
                    mov rcx, LEFT
                    mov r12, 4
                    lea rsi, [rdi + rax]

                .find.left5:
                    cmp byte [r11 + r13 + memo.left5_visited], VISITED
                    je .find.left6

                    cmp edx, [r11 + r13 + memo.left5_path]
                    jbe .find.left6

                    mov edx, [r11 + r13 + memo.left5_path]
                    mov rcx, LEFT
                    mov r12, 5
                    lea rsi, [rdi + rax]

                .find.left6:
                    cmp byte [r11 + r13 + memo.left6_visited], VISITED
                    je .find.left7

                    cmp edx, [r11 + r13 + memo.left6_path]
                    jbe .find.left7

                    mov edx, [r11 + r13 + memo.left6_path]
                    mov rcx, LEFT
                    mov r12, 6
                    lea rsi, [rdi + rax]

                .find.left7:
                    cmp byte [r11 + r13 + memo.left7_visited], VISITED
                    je .find.left8

                    cmp edx, [r11 + r13 + memo.left7_path]
                    jbe .find.left8

                    mov edx, [r11 + r13 + memo.left7_path]
                    mov rcx, LEFT
                    mov r12, 7
                    lea rsi, [rdi + rax]

                .find.left8:
                    cmp byte [r11 + r13 + memo.left8_visited], VISITED
                    je .find.left9

                    cmp edx, [r11 + r13 + memo.left8_path]
                    jbe .find.left9

                    mov edx, [r11 + r13 + memo.left8_path]
                    mov rcx, LEFT
                    mov r12, 8
                    lea rsi, [rdi + rax]

                .find.left9:
                    cmp byte [r11 + r13 + memo.left9_visited], VISITED
                    je .find.left10

                    cmp edx, [r11 + r13 + memo.left9_path]
                    jbe .find.left10

                    mov edx, [r11 + r13 + memo.left9_path]
                    mov rcx, LEFT
                    mov r12, 9
                    lea rsi, [rdi + rax]

                .find.left10:
                    cmp byte [r11 + r13 + memo.left10_visited], VISITED
                    je .find.up4

                    cmp edx, [r11 + r13 + memo.left10_path]
                    jbe .find.up4

                    mov edx, [r11 + r13 + memo.left10_path]
                    mov rcx, LEFT
                    mov r12, 10
                    lea rsi, [rdi + rax]

                .find.up4:
                    cmp byte [r11 + r13 + memo.up4_visited], VISITED
                    je .find.up5

                    cmp edx, [r11 + r13 + memo.up4_path]
                    jbe .find.up5

                    mov edx, [r11 + r13 + memo.up4_path]
                    mov rcx, UP
                    mov r12, 4
                    lea rsi, [rdi + rax]

                .find.up5:
                    cmp byte [r11 + r13 + memo.up5_visited], VISITED
                    je .find.up6

                    cmp edx, [r11 + r13 + memo.up5_path]
                    jbe .find.up6

                    mov edx, [r11 + r13 + memo.up5_path]
                    mov rcx, UP
                    mov r12, 5
                    lea rsi, [rdi + rax]

                .find.up6:
                    cmp byte [r11 + r13 + memo.up6_visited], VISITED
                    je .find.up7

                    cmp edx, [r11 + r13 + memo.up6_path]
                    jbe .find.up7

                    mov edx, [r11 + r13 + memo.up6_path]
                    mov rcx, UP
                    mov r12, 6
                    lea rsi, [rdi + rax]

                .find.up7:
                    cmp byte [r11 + r13 + memo.up7_visited], VISITED
                    je .find.up8

                    cmp edx, [r11 + r13 + memo.up7_path]
                    jbe .find.up8

                    mov edx, [r11 + r13 + memo.up7_path]
                    mov rcx, UP
                    mov r12, 7
                    lea rsi, [rdi + rax]

                .find.up8:
                    cmp byte [r11 + r13 + memo.up8_visited], VISITED
                    je .find.up9

                    cmp edx, [r11 + r13 + memo.up8_path]
                    jbe .find.up9

                    mov edx, [r11 + r13 + memo.up8_path]
                    mov rcx, UP
                    mov r12, 8
                    lea rsi, [rdi + rax]

                .find.up9:
                    cmp byte [r11 + r13 + memo.up9_visited], VISITED
                    je .find.up10

                    cmp edx, [r11 + r13 + memo.up9_path]
                    jbe .find.up10

                    mov edx, [r11 + r13 + memo.up9_path]
                    mov rcx, UP
                    mov r12, 9
                    lea rsi, [rdi + rax]

                .find.up10:
                    cmp byte [r11 + r13 + memo.up10_visited], VISITED
                    je .find.down4

                    cmp edx, [r11 + r13 + memo.up10_path]
                    jbe .find.down4

                    mov edx, [r11 + r13 + memo.up10_path]
                    mov rcx, UP
                    mov r12, 10
                    lea rsi, [rdi + rax]

                .find.down4:
                    cmp byte [r11 + r13 + memo.down4_visited], VISITED
                    je .find.down5

                    cmp edx, [r11 + r13 + memo.down4_path]
                    jbe .find.down5

                    mov edx, [r11 + r13 + memo.down4_path]
                    mov rcx, DOWN
                    mov r12, 4
                    lea rsi, [rdi + rax]

                .find.down5:
                    cmp byte [r11 + r13 + memo.down5_visited], VISITED
                    je .find.down6

                    cmp edx, [r11 + r13 + memo.down5_path]
                    jbe .find.down6

                    mov edx, [r11 + r13 + memo.down5_path]
                    mov rcx, DOWN
                    mov r12, 5
                    lea rsi, [rdi + rax]

                .find.down6:
                    cmp byte [r11 + r13 + memo.down6_visited], VISITED
                    je .find.down7

                    cmp edx, [r11 + r13 + memo.down6_path]
                    jbe .find.down7

                    mov edx, [r11 + r13 + memo.down6_path]
                    mov rcx, DOWN
                    mov r12, 6
                    lea rsi, [rdi + rax]

                .find.down7:
                    cmp byte [r11 + r13 + memo.down7_visited], VISITED
                    je .find.down8

                    cmp edx, [r11 + r13 + memo.down7_path]
                    jbe .find.down8

                    mov edx, [r11 + r13 + memo.down7_path]
                    mov rcx, DOWN
                    mov r12, 7
                    lea rsi, [rdi + rax]

                .find.down8:
                    cmp byte [r11 + r13 + memo.down8_visited], VISITED
                    je .find.down9

                    cmp edx, [r11 + r13 + memo.down8_path]
                    jbe .find.down9

                    mov edx, [r11 + r13 + memo.down8_path]
                    mov rcx, DOWN
                    mov r12, 8
                    lea rsi, [rdi + rax]

                .find.down9:
                    cmp byte [r11 + r13 + memo.down9_visited], VISITED
                    je .find.down10

                    cmp edx, [r11 + r13 + memo.down9_path]
                    jbe .find.down10

                    mov edx, [r11 + r13 + memo.down9_path]
                    mov rcx, DOWN
                    mov r12, 9
                    lea rsi, [rdi + rax]

                .find.down10:
                    cmp byte [r11 + r13 + memo.down10_visited], VISITED
                    je .next

                    cmp edx, [r11 + r13 + memo.down10_path]
                    jbe .next

                    mov edx, [r11 + r13 + memo.down10_path]
                    mov rcx, DOWN
                    mov r12, 10
                    lea rsi, [rdi + rax]

                .next:
                    inc rax
                    jmp .find

            .endFind:
                jmp .while

        .endWhile:
            mov eax, ebx
       
        .end:
            pop rbx
            pop r15
            pop r14
            pop r13
            pop r12
            leave
            ret

    ; End getSolution.


    ; void exploreRightNeighbor(...)
    ;
    ; @brief    Given a position, explores right neighbors based on current 
    ;           step count.  Does not modified registers except for r13, r14, 
    ;           r15, and rbx.
    ;
    exploreRightNeighbor:
        push rbp
        mov rbp, rsp

        ; rdi = top_left.
        ; rsi = curr_pos.
        ; edx = current_path.
        ; rcx = current_dir.
        ; r8 = line_len.
        ; r9 = memo_len.
        ; r10 = tgt.
        ; r11 = memo.
        ; r12 = curr_steps.

        xor r14, r14
        mov ebx, edx            ; tmp_path.

        cmp r12, 11             ; MAX_STEPS + 1
        je .end

        mov r13, rsi            ; tmp_pos.
        inc r13

        .loop:
            cmp r12, 4
            jge .endLoop

            ; Check existence.
            cmp r13, rdi
            jb .end

            cmp r13, r10
            ja .end

            cmp byte [r13], NEWLINE
            je .end

            cmp byte [r13], NULL
            je .end

            mov r14b, [r13]         ; tmp_addend.
            sub r14b, '0'

            add ebx, r14d

            inc r12
            inc r13
            jmp .loop

        .endLoop:

        ; Check existence.
        cmp r13, rdi
        jb .end

        cmp r13, r10
        ja .end

        cmp byte [r13], NEWLINE
        je .end

        cmp byte [r13], NULL
        je .end

        mov r14b, [r13]             ; tmp_addend.
        sub r14b, '0'

        add ebx, r14d

        mov r15, r13
        sub r15, rdi
        shl r15, MUL_256_SHIFTER    ; tmp_memo_offset.

        cmp r12, 4
        je .steps4

        cmp r12, 5
        je .steps5

        cmp r12, 6
        je .steps6

        cmp r12, 7
        je .steps7

        cmp r12, 8
        je .steps8

        cmp r12, 9
        je .steps9

        cmp r12, 10
        je .steps10

        .steps4:
            cmp byte [r11 + r15 + memo.right4_visited], VISITED
            je .end

            cmp ebx, [r11 + r15 + memo.right4_path]
            jae .end

            mov [r11 + r15 + memo.right4_path], ebx
            jmp .end

        .steps5:
            cmp byte [r11 + r15 + memo.right5_visited], VISITED
            je .end

            cmp ebx, [r11 + r15 + memo.right5_path]
            jae .end

            mov [r11 + r15 + memo.right5_path], ebx
            jmp .end

        .steps6:
            cmp byte [r11 + r15 + memo.right6_visited], VISITED
            je .end

            cmp ebx, [r11 + r15 + memo.right6_path]
            jae .end

            mov [r11 + r15 + memo.right6_path], ebx
            jmp .end

        .steps7:
            cmp byte [r11 + r15 + memo.right7_visited], VISITED
            je .end

            cmp ebx, [r11 + r15 + memo.right7_path]
            jae .end

            mov [r11 + r15 + memo.right7_path], ebx
            jmp .end

        .steps8:
            cmp byte [r11 + r15 + memo.right8_visited], VISITED
            je .end

            cmp ebx, [r11 + r15 + memo.right8_path]
            jae .end

            mov [r11 + r15 + memo.right8_path], ebx
            jmp .end

        .steps9:
            cmp byte [r11 + r15 + memo.right9_visited], VISITED
            je .end

            cmp ebx, [r11 + r15 + memo.right9_path]
            jae .end

            mov [r11 + r15 + memo.right9_path], ebx
            jmp .end

        .steps10:
            cmp byte [r11 + r15 + memo.right10_visited], VISITED
            je .end

            cmp ebx, [r11 + r15 + memo.right10_path]
            jae .end

            mov [r11 + r15 + memo.right10_path], ebx

        .end:
            leave
            ret

    ; End exploreRightNeighbor.


    exploreLeftNeighbor:
        push rbp
        mov rbp, rsp

        ; rdi = top_left.
        ; rsi = curr_pos.
        ; edx = current_path.
        ; rcx = current_dir.
        ; r8 = line_len.
        ; r9 = memo_len.
        ; r10 = tgt.
        ; r11 = memo.
        ; r12 = curr_steps.

        xor r14, r14
        mov ebx, edx            ; tmp_path.

        cmp r12, 11             ; MAX_STEPS + 1
        je .end

        mov r13, rsi            ; tmp_pos.
        dec r13

        .loop:
            cmp r12, 4
            jge .endLoop

            ; Check existence.
            cmp r13, rdi
            jb .end

            cmp r13, r10
            ja .end

            cmp byte [r13], NEWLINE
            je .end

            cmp byte [r13], NULL
            je .end

            mov r14b, [r13]         ; tmp_addend.
            sub r14b, '0'

            add ebx, r14d

            inc r12
            dec r13
            jmp .loop

        .endLoop:

        ; Check existence.
        cmp r13, rdi
        jb .end

        cmp r13, r10
        ja .end

        cmp byte [r13], NEWLINE
        je .end

        cmp byte [r13], NULL
        je .end

        mov r14b, [r13]             ; tmp_addend.
        sub r14b, '0'

        add ebx, r14d

        mov r15, r13
        sub r15, rdi
        shl r15, MUL_256_SHIFTER    ; tmp_memo_offset.

        cmp r12, 4
        je .steps4

        cmp r12, 5
        je .steps5

        cmp r12, 6
        je .steps6

        cmp r12, 7
        je .steps7

        cmp r12, 8
        je .steps8

        cmp r12, 9
        je .steps9

        cmp r12, 10
        je .steps10

        .steps4:
            cmp byte [r11 + r15 + memo.left4_visited], VISITED
            je .end

            cmp ebx, [r11 + r15 + memo.left4_path]
            jae .end

            mov [r11 + r15 + memo.left4_path], ebx
            jmp .end

        .steps5:
            cmp byte [r11 + r15 + memo.left5_visited], VISITED
            je .end

            cmp ebx, [r11 + r15 + memo.left5_path]
            jae .end

            mov [r11 + r15 + memo.left5_path], ebx
            jmp .end

        .steps6:
            cmp byte [r11 + r15 + memo.left6_visited], VISITED
            je .end

            cmp ebx, [r11 + r15 + memo.left6_path]
            jae .end

            mov [r11 + r15 + memo.left6_path], ebx
            jmp .end

        .steps7:
            cmp byte [r11 + r15 + memo.left7_visited], VISITED
            je .end

            cmp ebx, [r11 + r15 + memo.left7_path]
            jae .end

            mov [r11 + r15 + memo.left7_path], ebx
            jmp .end

        .steps8:
            cmp byte [r11 + r15 + memo.left8_visited], VISITED
            je .end

            cmp ebx, [r11 + r15 + memo.left8_path]
            jae .end

            mov [r11 + r15 + memo.left8_path], ebx
            jmp .end

        .steps9:
            cmp byte [r11 + r15 + memo.left9_visited], VISITED
            je .end

            cmp ebx, [r11 + r15 + memo.left9_path]
            jae .end

            mov [r11 + r15 + memo.left9_path], ebx
            jmp .end

        .steps10:
            cmp byte [r11 + r15 + memo.left10_visited], VISITED
            je .end

            cmp ebx, [r11 + r15 + memo.left10_path]
            jae .end

            mov [r11 + r15 + memo.left10_path], ebx

        .end:
            leave
            ret

    ; End exploreLeftNeighbor.


    exploreUpNeighbor:
        push rbp
        mov rbp, rsp

        ; rdi = top_left.
        ; rsi = curr_pos.
        ; edx = current_path.
        ; rcx = current_dir.
        ; r8 = line_len.
        ; r9 = memo_len.
        ; r10 = tgt.
        ; r11 = memo.
        ; r12 = curr_steps.

        xor r14, r14
        mov ebx, edx            ; tmp_path.

        cmp r12, 11             ; MAX_STEPS + 1
        je .end

        mov r13, rsi            ; tmp_pos.
        sub r13, r8

        .loop:
            cmp r12, 4
            jge .endLoop

            ; Check existence.
            cmp r13, rdi
            jb .end

            cmp r13, r10
            ja .end

            cmp byte [r13], NEWLINE
            je .end

            cmp byte [r13], NULL
            je .end

            mov r14b, [r13]         ; tmp_addend.
            sub r14b, '0'

            add ebx, r14d

            inc r12
            sub r13, r8
            jmp .loop

        .endLoop:

        ; Check existence.
        cmp r13, rdi
        jb .end

        cmp r13, r10
        ja .end

        cmp byte [r13], NEWLINE
        je .end

        cmp byte [r13], NULL
        je .end

        mov r14b, [r13]             ; tmp_addend.
        sub r14b, '0'

        add ebx, r14d

        mov r15, r13
        sub r15, rdi
        shl r15, MUL_256_SHIFTER    ; tmp_memo_offset.

        cmp r12, 4
        je .steps4

        cmp r12, 5
        je .steps5

        cmp r12, 6
        je .steps6

        cmp r12, 7
        je .steps7

        cmp r12, 8
        je .steps8

        cmp r12, 9
        je .steps9

        cmp r12, 10
        je .steps10

        .steps4:
            cmp byte [r11 + r15 + memo.up4_visited], VISITED
            je .end

            cmp ebx, [r11 + r15 + memo.up4_path]
            jae .end

            mov [r11 + r15 + memo.up4_path], ebx
            jmp .end

        .steps5:
            cmp byte [r11 + r15 + memo.up5_visited], VISITED
            je .end

            cmp ebx, [r11 + r15 + memo.up5_path]
            jae .end

            mov [r11 + r15 + memo.up5_path], ebx
            jmp .end

        .steps6:
            cmp byte [r11 + r15 + memo.up6_visited], VISITED
            je .end

            cmp ebx, [r11 + r15 + memo.up6_path]
            jae .end

            mov [r11 + r15 + memo.up6_path], ebx
            jmp .end

        .steps7:
            cmp byte [r11 + r15 + memo.up7_visited], VISITED
            je .end

            cmp ebx, [r11 + r15 + memo.up7_path]
            jae .end

            mov [r11 + r15 + memo.up7_path], ebx
            jmp .end

        .steps8:
            cmp byte [r11 + r15 + memo.up8_visited], VISITED
            je .end

            cmp ebx, [r11 + r15 + memo.up8_path]
            jae .end

            mov [r11 + r15 + memo.up8_path], ebx
            jmp .end

        .steps9:
            cmp byte [r11 + r15 + memo.up9_visited], VISITED
            je .end

            cmp ebx, [r11 + r15 + memo.up9_path]
            jae .end

            mov [r11 + r15 + memo.up9_path], ebx
            jmp .end

        .steps10:
            cmp byte [r11 + r15 + memo.up10_visited], VISITED
            je .end

            cmp ebx, [r11 + r15 + memo.up10_path]
            jae .end

            mov [r11 + r15 + memo.up10_path], ebx

        .end:
            leave
            ret

    ; End exploreUpNeighbor.


    exploreDownNeighbor:
        push rbp
        mov rbp, rsp

        ; rdi = top_left.
        ; rsi = curr_pos.
        ; edx = current_path.
        ; rcx = current_dir.
        ; r8 = line_len.
        ; r9 = memo_len.
        ; r10 = tgt.
        ; r11 = memo.
        ; r12 = curr_steps.

        xor r14, r14
        mov ebx, edx            ; tmp_path.

        cmp r12, 11             ; MAX_STEPS + 1
        je .end

        mov r13, rsi            ; tmp_pos.
        add r13, r8

        .loop:
            cmp r12, 4
            jge .endLoop

            ; Check existence.
            cmp r13, rdi
            jb .end

            cmp r13, r10
            ja .end

            cmp byte [r13], NEWLINE
            je .end

            cmp byte [r13], NULL
            je .end

            mov r14b, [r13]         ; tmp_addend.
            sub r14b, '0'

            add ebx, r14d

            inc r12
            add r13, r8
            jmp .loop

        .endLoop:

        ; Check existence.
        cmp r13, rdi
        jb .end

        cmp r13, r10
        ja .end

        cmp byte [r13], NEWLINE
        je .end

        cmp byte [r13], NULL
        je .end

        mov r14b, [r13]             ; tmp_addend.
        sub r14b, '0'

        add ebx, r14d

        mov r15, r13
        sub r15, rdi
        shl r15, MUL_256_SHIFTER    ; tmp_memo_offset.

        cmp r12, 4
        je .steps4

        cmp r12, 5
        je .steps5

        cmp r12, 6
        je .steps6

        cmp r12, 7
        je .steps7

        cmp r12, 8
        je .steps8

        cmp r12, 9
        je .steps9

        cmp r12, 10
        je .steps10

        .steps4:
            cmp byte [r11 + r15 + memo.down4_visited], VISITED
            je .end

            cmp ebx, [r11 + r15 + memo.down4_path]
            jae .end

            mov [r11 + r15 + memo.down4_path], ebx
            jmp .end

        .steps5:
            cmp byte [r11 + r15 + memo.down5_visited], VISITED
            je .end

            cmp ebx, [r11 + r15 + memo.down5_path]
            jae .end

            mov [r11 + r15 + memo.down5_path], ebx
            jmp .end

        .steps6:
            cmp byte [r11 + r15 + memo.down6_visited], VISITED
            je .end

            cmp ebx, [r11 + r15 + memo.down6_path]
            jae .end

            mov [r11 + r15 + memo.down6_path], ebx
            jmp .end

        .steps7:
            cmp byte [r11 + r15 + memo.down7_visited], VISITED
            je .end

            cmp ebx, [r11 + r15 + memo.down7_path]
            jae .end

            mov [r11 + r15 + memo.down7_path], ebx
            jmp .end

        .steps8:
            cmp byte [r11 + r15 + memo.down8_visited], VISITED
            je .end

            cmp ebx, [r11 + r15 + memo.down8_path]
            jae .end

            mov [r11 + r15 + memo.down8_path], ebx
            jmp .end

        .steps9:
            cmp byte [r11 + r15 + memo.down9_visited], VISITED
            je .end

            cmp ebx, [r11 + r15 + memo.down9_path]
            jae .end

            mov [r11 + r15 + memo.down9_path], ebx
            jmp .end

        .steps10:
            cmp byte [r11 + r15 + memo.down10_visited], VISITED
            je .end

            cmp ebx, [r11 + r15 + memo.down10_path]
            jae .end

            mov [r11 + r15 + memo.down10_path], ebx

        .end:
            leave
            ret

    ; End exploreDownNeighbor.


; End of file.