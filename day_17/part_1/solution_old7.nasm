;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Advent of Code Christmas Challenge Day 17 - Part I
;
; @brief    Find the minimum sum of the digits along the path from the top 
;           right to bottom left while only being able to move 3 consecutive 
;           step in one direction at most at one time.
;
;           This idea should work, but now I feel like it would be easier to 
;           apply this idea to my regular pathfinder algorithm instead of 
;           using a Dysktra's nightmare. Either way, this way will be faster.
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

%define RIGHT   0b00000001
%define DOWN    0b00000010
%define LEFT    0b00000100
%define UP      0b00001000

%define VISITED '/'                     ; Less than or equal to.
%define VISIT   10

%define MAX_STEPS   3


; Struc defs.
; Idea here is that every node is actually 12 nodes.
struc memo

    .right0_path:       resd    1
    .right1_path:       resd    1
    .right2_path:       resd    1
    .right0_visited:    resb    1
    .right1_visited:    resb    1
    .right2_visited:    resb    1
    .right_pad:         resb    1

    .left0_path:        resd    1
    .left1_path:        resd    1
    .left2_path:        resd    1
    .left0_visited:     resb    1
    .left1_visited:     resb    1
    .left2_visited:     resb    1
    .left_pad:          resb    1

    .up0_path:          resd    1
    .up1_path:          resd    1
    .up2_path:          resd    1
    .up0_visited:       resb    1
    .up1_visited:       resb    1
    .up2_visited:       resb    1
    .up_pad:            resb    1

    .down0_path:        resd    1
    .down1_path:        resd    1
    .down2_path:        resd    1
    .down0_visited:     resb    1
    .down1_visited:     resb    1
    .down2_visited:     resb    1
    .down_pad:          resb    1

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

        ; I just came up with the idea, that every node is actually 12 nodes 
        ; because its neighbors change up to 12 times. So, we should be able 
        ; to run an algorithm with that in mind that would be much better. 
        ; So, this will be that attempt.
        ; Basically, conceptually, its like a 3d graph.

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
        shl rdi, 6                      ; Multiply by 64.
        call memAlloc

        mov r11, rax                    ; memo.
        mov rcx, r9
        shl rcx, 6
        mov rdi, r11

        .fill:
            mov byte [rdi], 0xff
            inc rdi
            loop .fill

        pop rdi

        ; So we are actually starting at two different nodes.
        ; Let's pretend its one for now.
        ; Init state.
        mov rsi, rdi                    ; curr_pos.
        xor rdx, rdx                    ; curr_path.
        mov rcx, RIGHT                  ; curr_dir.
        xor r12, r12                    ; curr_steps.

        mov dword [r11 + memo.right0_path], 0
        mov dword [r11 + memo.right1_path], 0
        mov dword [r11 + memo.right2_path], 0
        ; mov dword [r11 + memo.left0_path], 0
        ; mov dword [r11 + memo.left1_path], 0
        ; mov dword [r11 + memo.left2_path], 0
        ; mov dword [r11 + memo.up0_path], 0
        ; mov dword [r11 + memo.up1_path], 0
        ; mov dword [r11 + memo.up2_path], 0
        mov dword [r11 + memo.down0_path], 0
        mov dword [r11 + memo.down1_path], 0
        mov dword [r11 + memo.down2_path], 0
        mov byte [r11 + memo.right0_visited], 0
        mov byte [r11 + memo.right1_visited], 0
        mov byte [r11 + memo.right2_visited], 0
        ; mov byte [r11 + memo.left0_visited], 0
        ; mov byte [r11 + memo.left1_visited], 0
        ; mov byte [r11 + memo.left2_visited], 0
        ; mov byte [r11 + memo.up0_visited], 0
        ; mov byte [r11 + memo.up1_visited], 0
        ; mov byte [r11 + memo.up2_visited], 0
        mov byte [r11 + memo.down0_visited], 0
        mov byte [r11 + memo.down1_visited], 0
        mov byte [r11 + memo.down2_visited], 0

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
        .while:int3

            ; Exit criteria? Uh, when bottom right has been visited from top 
            ; and left?
            mov rax, r10
            sub rax, rdi
            shl rax, 6
            add rax, r11

            mov ebx, -1

            .right0:
                cmp byte [rax + memo.right0_visited], 0
                jne .exploreNeighbors

                cmp [rax + memo.right0_path], ebx
                jae .right1

                mov ebx, [rax + memo.right0_path]

            .right1:
                cmp byte [rax + memo.right1_visited], 0
                jne .exploreNeighbors

                cmp [rax + memo.right1_path], ebx
                jae .right2

                mov ebx, [rax + memo.right1_path]

            .right2:
                cmp byte [rax + memo.right2_visited], 0
                jne .exploreNeighbors

                cmp [rax + memo.right2_path], ebx
                jae .down0

                mov ebx, [rax + memo.right2_path]

            .down0:
                cmp byte [rax + memo.down0_visited], 0
                jne .exploreNeighbors

                cmp [rax + memo.down0_path], ebx
                jae .down1

                mov ebx, [rax + memo.down0_path]

            .down1:
                cmp byte [rax + memo.down1_visited], 0
                jne .exploreNeighbors

                cmp [rax + memo.down1_path], ebx
                jae .down2

                mov ebx, [rax + memo.down1_path]

            .down2:
                cmp byte [rax + memo.down2_visited], 0
                jne .exploreNeighbors

                cmp [rax + memo.down2_path], ebx
                jae .found

                mov ebx, [rax + memo.down2_path]

            .found:
                jmp .endWhile

            .exploreNeighbors:
                mov rax, rsi
                sub rax, rdi
                shl rax, 6          ; curr_node_memo_loc.

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
                    je .skip

                    inc r12
                    .skip:
                    call exploreRightNeighbors
                    xor r12, r12
                    call exploreUpNeighbors
                    call exploreDownNeighbors
                    pop r12
                    jmp .visitRight

                .left:
                    push r12
                    inc r12
                    call exploreLeftNeighbors
                    xor r12, r12
                    call exploreUpNeighbors
                    call exploreDownNeighbors
                    pop r12
                    jmp .visitLeft

                .up:
                    push r12
                    inc r12
                    call exploreUpNeighbors
                    xor r12, r12
                    call exploreLeftNeighbors
                    call exploreRightNeighbors
                    pop r12
                    jmp .visitUp

                .down:
                    push r12
                    inc r12
                    call exploreDownNeighbors
                    xor r12, r12
                    call exploreLeftNeighbors
                    call exploreRightNeighbors
                    pop r12
                    jmp .visitDown

            ; Visit curr_node.
            .visitRight:
                cmp r12, 1
                je .visitRight.0

                cmp r12, 2
                je .visitRight.1

                cmp r12, 3
                je .visitRight.2

                jmp .doneVisit

                .visitRight.0:
                    mov byte [r11 + rax + memo.right0_visited], 0
                    jmp .doneVisit

                .visitRight.1:
                    mov byte [r11 + rax + memo.right1_visited], 0
                    jmp .doneVisit

                .visitRight.2:
                    mov byte [r11 + rax + memo.right2_visited], 0
                    jmp .doneVisit

            .visitLeft:
                cmp r12, 1
                je .visitLeft.0

                cmp r12, 2
                je .visitLeft.1

                cmp r12, 3
                je .visitLeft.2

                jmp .doneVisit

                .visitLeft.0:
                    mov byte [r11 + rax + memo.left0_visited], 0
                    jmp .doneVisit

                .visitLeft.1:
                    mov byte [r11 + rax + memo.left1_visited], 0
                    jmp .doneVisit

                .visitLeft.2:
                    mov byte [r11 + rax + memo.left2_visited], 0
                    jmp .doneVisit

            .visitUp:
                cmp r12, 1
                je .visitUp.0

                cmp r12, 2
                je .visitUp.1

                cmp r12, 3
                je .visitUp.2

                jmp .doneVisit

                .visitUp.0:
                    mov byte [r11 + rax + memo.up0_visited], 0
                    jmp .doneVisit

                .visitUp.1:
                    mov byte [r11 + rax + memo.up1_visited], 0
                    jmp .doneVisit

                .visitUp.2:
                    mov byte [r11 + rax + memo.up2_visited], 0
                    jmp .doneVisit

            .visitDown:
                cmp r12, 1
                je .visitDown.0

                cmp r12, 2
                je .visitDown.1

                cmp r12, 3
                je .visitDown.2

                jmp .doneVisit

                .visitDown.0:
                    mov byte [r11 + rax + memo.down0_visited], 0
                    jmp .doneVisit

                .visitDown.1:
                    mov byte [r11 + rax + memo.down1_visited], 0
                    jmp .doneVisit

                .visitDown.2:
                    mov byte [r11 + rax + memo.down2_visited], 0
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
                shl r13, 6

                .find.right0:
                    cmp byte [r11 + r13 + memo.right0_visited], 0
                    je .find.right1

                    cmp edx, [r11 + r13 + memo.right0_path]
                    jbe .find.right1

                    mov edx, [r11 + r13 + memo.right0_path]
                    mov rcx, RIGHT
                    mov r12, 1
                    lea rsi, [rdi + rax]

                .find.right1:
                    cmp byte [r11 + r13 + memo.right1_visited], 0
                    je .find.right2

                    cmp edx, [r11 + r13 + memo.right1_path]
                    jbe .find.right2

                    mov edx, [r11 + r13 + memo.right1_path]
                    mov rcx, RIGHT
                    mov r12, 2
                    lea rsi, [rdi + rax]

                .find.right2:
                    cmp byte [r11 + r13 + memo.right2_visited], 0
                    je .find.left0

                    cmp edx, [r11 + r13 + memo.right2_path]
                    jbe .find.left0

                    mov edx, [r11 + r13 + memo.right2_path]
                    mov rcx, RIGHT
                    mov r12, 3
                    lea rsi, [rdi + rax]

                .find.left0:
                    cmp byte [r11 + r13 + memo.left0_visited], 0
                    je .find.left1

                    cmp edx, [r11 + r13 + memo.left0_path]
                    jbe .find.left1

                    mov edx, [r11 + r13 + memo.left0_path]
                    mov rcx, LEFT
                    mov r12, 1
                    lea rsi, [rdi + rax]

                .find.left1:
                    cmp byte [r11 + r13 + memo.left1_visited], 0
                    je .find.left2

                    cmp edx, [r11 + r13 + memo.left1_path]
                    jbe .find.left2

                    mov edx, [r11 + r13 + memo.left1_path]
                    mov rcx, LEFT
                    mov r12, 2
                    lea rsi, [rdi + rax]

                .find.left2:
                    cmp byte [r11 + r13 + memo.left2_visited], 0
                    je .find.up0

                    cmp edx, [r11 + r13 + memo.left2_path]
                    jbe .find.up0

                    mov edx, [r11 + r13 + memo.left2_path]
                    mov rcx, LEFT
                    mov r12, 3
                    lea rsi, [rdi + rax]

                .find.up0:
                    cmp byte [r11 + r13 + memo.up0_visited], 0
                    je .find.up1

                    cmp edx, [r11 + r13 + memo.up0_path]
                    jbe .find.up1

                    mov edx, [r11 + r13 + memo.up0_path]
                    mov rcx, UP
                    mov r12, 1
                    lea rsi, [rdi + rax]

                .find.up1:
                    cmp byte [r11 + r13 + memo.up1_visited], 0
                    je .find.up2

                    cmp edx, [r11 + r13 + memo.up1_path]
                    jbe .find.up2

                    mov edx, [r11 + r13 + memo.up1_path]
                    mov rcx, UP
                    mov r12, 2
                    lea rsi, [rdi + rax]

                .find.up2:
                    cmp byte [r11 + r13 + memo.up2_visited], 0
                    je .find.down0

                    cmp edx, [r11 + r13 + memo.up2_path]
                    jbe .find.down0

                    mov edx, [r11 + r13 + memo.up2_path]
                    mov rcx, UP
                    mov r12, 3
                    lea rsi, [rdi + rax]

                .find.down0:
                    cmp byte [r11 + r13 + memo.down0_visited], 0
                    je .find.down1

                    cmp edx, [r11 + r13 + memo.down0_path]
                    jbe .find.down1

                    mov edx, [r11 + r13 + memo.down0_path]
                    mov rcx, DOWN
                    mov r12, 1
                    lea rsi, [rdi + rax]

                .find.down1:
                    cmp byte [r11 + r13 + memo.down1_visited], 0
                    je .find.down2

                    cmp edx, [r11 + r13 + memo.down1_path]
                    jbe .find.down2

                    mov edx, [r11 + r13 + memo.down1_path]
                    mov rcx, DOWN
                    mov r12, 2
                    lea rsi, [rdi + rax]

                .find.down2:
                    cmp byte [r11 + r13 + memo.down2_visited], 0
                    je .next

                    cmp edx, [r11 + r13 + memo.down2_path]
                    jbe .next

                    mov edx, [r11 + r13 + memo.down2_path]
                    mov rcx, DOWN
                    mov r12, 3
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


    ; void exploreRightNeighbors(...)
    ;
    ; @brief    Given a position, explores right neighbors based on current 
    ;           step count.  Does not modified registers except for r13, r14, 
    ;           r15, and rbx.
    ;
    exploreRightNeighbors:
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

        .firstNeighbor:
            cmp r12, MAX_STEPS
            je .end

            mov r13, rsi        ; tmp_pos.
            add r13, 1

            ; Check existence.
            cmp r13, rdi
            jb .end

            cmp r13, r10
            ja .end

            cmp byte [r13], NEWLINE
            je .end

            cmp byte [r13], NULL
            je .end

            mov r14b, [r13]     ; tmp_addend.
            sub r14b, '0'

            add ebx, r14d

            mov r15, r13
            sub r15, rdi
            shl r15, 6          ; tmp_memo_offset.

            cmp byte [r11 + r15 + memo.right0_visited], 0
            je .secondNeighbor

            cmp ebx, [r11 + r15 + memo.right0_path]
            jae .secondNeighbor

            mov [r11 + r15 + memo.right0_path], ebx

        .secondNeighbor:
            cmp r12, 2
            je .end

            mov r13, rsi        ; tmp_pos.
            add r13, 2

            ; Check existence.
            cmp r13, rdi
            jb .end

            cmp r13, r10
            ja .end

            cmp byte [r13], NEWLINE
            je .end

            cmp byte [r13], NULL
            je .end

            mov r14b, [r13]     ; tmp_addend.
            sub r14b, '0'

            add ebx, r14d

            mov r15, r13
            sub r15, rdi
            shl r15, 6          ; tmp_memo_offset.

            cmp byte [r11 + r15 + memo.right1_visited], 0
            je .thirdNeighbor

            cmp ebx, [r11 + r15 + memo.right1_path]
            jae .thirdNeighbor

            mov [r11 + r15 + memo.right1_path], ebx

        .thirdNeighbor:
            cmp r12, 1
            je .end

            mov r13, rsi        ; tmp_pos.
            add r13, 3

            ; Check existence.
            cmp r13, rdi
            jb .end

            cmp r13, r10
            ja .end

            cmp byte [r13], NEWLINE
            je .end

            cmp byte [r13], NULL
            je .end

            mov r14b, [r13]     ; tmp_addend.
            sub r14b, '0'

            add ebx, r14d

            mov r15, r13
            sub r15, rdi
            shl r15, 6          ; tmp_memo_offset.

            cmp byte [r11 + r15 + memo.right2_visited], 0
            je .end

            cmp ebx, [r11 + r15 + memo.right2_path]
            jae .end

            mov [r11 + r15 + memo.right2_path], ebx

        .end:
            leave
            ret

    ; End exploreRightNeighbors.



    ; void exploreLeftNeighbors(...)
    ;
    ; @brief    Given a position, explores left neighbors based on current 
    ;           step count.  Does not modified registers except for r13, r14, 
    ;           r15, and rbx.
    ;
    exploreLeftNeighbors:
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

        .firstNeighbor:
            cmp r12, MAX_STEPS
            je .end

            mov r13, rsi        ; tmp_pos.
            sub r13, 1

            ; Check existence.
            cmp r13, rdi
            jb .end

            cmp r13, r10
            ja .end

            cmp byte [r13], NEWLINE
            je .end

            cmp byte [r13], NULL
            je .end

            mov r14b, [r13]     ; tmp_addend.
            sub r14b, '0'

            add ebx, r14d

            mov r15, r13
            sub r15, rdi
            shl r15, 6          ; tmp_memo_offset.

            cmp byte [r11 + r15 + memo.left0_visited], 0
            je .secondNeighbor

            cmp ebx, [r11 + r15 + memo.left0_path]
            jae .secondNeighbor

            mov [r11 + r15 + memo.left0_path], ebx

        .secondNeighbor:
            cmp r12, 2
            je .end

            mov r13, rsi        ; tmp_pos.
            sub r13, 2

            ; Check existence.
            cmp r13, rdi
            jb .end

            cmp r13, r10
            ja .end

            cmp byte [r13], NEWLINE
            je .end

            cmp byte [r13], NULL
            je .end

            mov r14b, [r13]     ; tmp_addend.
            sub r14b, '0'

            add ebx, r14d

            mov r15, r13
            sub r15, rdi
            shl r15, 6          ; tmp_memo_offset.

            cmp byte [r11 + r15 + memo.left1_visited], 0
            je .thirdNeighbor

            cmp ebx, [r11 + r15 + memo.left1_path]
            jae .thirdNeighbor

            mov [r11 + r15 + memo.left1_path], ebx

        .thirdNeighbor:
            cmp r12, 1
            je .end

            mov r13, rsi        ; tmp_pos.
            sub r13, 3

            ; Check existence.
            cmp r13, rdi
            jb .end

            cmp r13, r10
            ja .end

            cmp byte [r13], NEWLINE
            je .end

            cmp byte [r13], NULL
            je .end

            mov r14b, [r13]     ; tmp_addend.
            sub r14b, '0'

            add ebx, r14d

            mov r15, r13
            sub r15, rdi
            shl r15, 6          ; tmp_memo_offset.

            cmp byte [r11 + r15 + memo.left2_visited], 0
            je .end

            cmp ebx, [r11 + r15 + memo.left2_path]
            jae .end

            mov [r11 + r15 + memo.left2_path], ebx

        .end:
            leave
            ret

    ; End exploreLeftNeighbors.


    ; void exploreUpNeighbors(...)
    ;
    ; @brief    Given a position, explores up neighbors based on current 
    ;           step count.  Does not modified registers except for r13, r14, 
    ;           r15, and rbx.
    ;
    exploreUpNeighbors:
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

        .firstNeighbor:
            cmp r12, MAX_STEPS
            je .end

            mov r13, rsi        ; tmp_pos.
            sub r13, r8

            ; Check existence.
            cmp r13, rdi
            jb .end

            cmp r13, r10
            ja .end

            cmp byte [r13], NEWLINE
            je .end

            cmp byte [r13], NULL
            je .end

            mov r14b, [r13]     ; tmp_addend.
            sub r14b, '0'

            add ebx, r14d

            mov r15, r13
            sub r15, rdi
            shl r15, 6          ; tmp_memo_offset.

            cmp byte [r11 + r15 + memo.up0_visited], 0
            je .secondNeighbor

            cmp ebx, [r11 + r15 + memo.up0_path]
            jae .secondNeighbor

            mov [r11 + r15 + memo.up0_path], ebx

        .secondNeighbor:
            cmp r12, 2
            je .end

            mov r13, rsi        ; tmp_pos.
            sub r13, r8
            sub r13, r8

            ; Check existence.
            cmp r13, rdi
            jb .end

            cmp r13, r10
            ja .end

            cmp byte [r13], NEWLINE
            je .end

            cmp byte [r13], NULL
            je .end

            mov r14b, [r13]     ; tmp_addend.
            sub r14b, '0'

            add ebx, r14d

            mov r15, r13
            sub r15, rdi
            shl r15, 6          ; tmp_memo_offset.

            cmp byte [r11 + r15 + memo.up1_visited], 0
            je .thirdNeighbor

            cmp ebx, [r11 + r15 + memo.up1_path]
            jae .thirdNeighbor

            mov [r11 + r15 + memo.up1_path], ebx

        .thirdNeighbor:
            cmp r12, 1
            je .end

            mov r13, rsi        ; tmp_pos.
            sub r13, r8
            sub r13, r8
            sub r13, r8

            ; Check existence.
            cmp r13, rdi
            jb .end

            cmp r13, r10
            ja .end

            cmp byte [r13], NEWLINE
            je .end

            cmp byte [r13], NULL
            je .end

            mov r14b, [r13]     ; tmp_addend.
            sub r14b, '0'

            add ebx, r14d

            mov r15, r13
            sub r15, rdi
            shl r15, 6          ; tmp_memo_offset.

            cmp byte [r11 + r15 + memo.up2_visited], 0
            je .end

            cmp ebx, [r11 + r15 + memo.up2_path]
            jae .end

            mov [r11 + r15 + memo.up2_path], ebx

        .end:
            leave
            ret

    ; End exploreUpNeighbors.


    ; void exploreDownNeighbors(...)
    ;
    ; @brief    Given a position, explores down neighbors based on current 
    ;           step count.  Does not modified registers except for r13, r14, 
    ;           r15, and rbx.
    ;
    exploreDownNeighbors:
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

        .firstNeighbor:
            cmp r12, MAX_STEPS
            je .end

            mov r13, rsi        ; tmp_pos.
            add r13, r8

            ; Check existence.
            cmp r13, rdi
            jb .end

            cmp r13, r10
            ja .end

            cmp byte [r13], NEWLINE
            je .end

            cmp byte [r13], NULL
            je .end

            mov r14b, [r13]     ; tmp_addend.
            sub r14b, '0'

            add ebx, r14d

            mov r15, r13
            sub r15, rdi
            shl r15, 6          ; tmp_memo_offset.

            cmp byte [r11 + r15 + memo.down0_visited], 0
            je .secondNeighbor

            cmp ebx, [r11 + r15 + memo.down0_path]
            jae .secondNeighbor

            mov [r11 + r15 + memo.down0_path], ebx

        .secondNeighbor:
            cmp r12, 2
            je .end

            mov r13, rsi        ; tmp_pos.
            add r13, r8
            add r13, r8

            ; Check existence.
            cmp r13, rdi
            jb .end

            cmp r13, r10
            ja .end

            cmp byte [r13], NEWLINE
            je .end

            cmp byte [r13], NULL
            je .end

            mov r14b, [r13]     ; tmp_addend.
            sub r14b, '0'

            add ebx, r14d

            mov r15, r13
            sub r15, rdi
            shl r15, 6          ; tmp_memo_offset.

            cmp byte [r11 + r15 + memo.down1_visited], 0
            je .thirdNeighbor

            cmp ebx, [r11 + r15 + memo.down1_path]
            jae .thirdNeighbor

            mov [r11 + r15 + memo.down1_path], ebx

        .thirdNeighbor:
            cmp r12, 1
            je .end

            mov r13, rsi        ; tmp_pos.
            add r13, r8
            add r13, r8
            add r13, r8

            ; Check existence.
            cmp r13, rdi
            jb .end

            cmp r13, r10
            ja .end

            cmp byte [r13], NEWLINE
            je .end

            cmp byte [r13], NULL
            je .end

            mov r14b, [r13]     ; tmp_addend.
            sub r14b, '0'

            add ebx, r14d

            mov r15, r13
            sub r15, rdi
            shl r15, 6          ; tmp_memo_offset.

            cmp byte [r11 + r15 + memo.down2_visited], 0
            je .end

            cmp ebx, [r11 + r15 + memo.down2_path]
            jae .end

            mov [r11 + r15 + memo.down2_path], ebx

        .end:
            leave
            ret

    ; End exploreDownNeighbors.


; End of file.