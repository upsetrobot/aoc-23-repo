;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Advent of Code Christmas Challenge Day 17 - Part I
;
; @brief    Find the minimum sum of the digits along the path from the top 
;           right to bottom left while only being able to move 3 consecutive 
;           step in one direction at most at one time.
;
;           One of my algos finally gave the right answer, but it had to run 
;           all night to figure it out, so I am trying again.
;
;           I am gonna start again from scratch.
;
; @file         solution.nasm
; @date         27 Dec 2023
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

%define MAX_STEPS   2


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
        push rbx

        ; Okay trying every path doesn't work with optimizations for some 
        ; reason. Standard traversal doesn't seem to work. Dykstra's is a no 
        ; go. This seems to be because the path is dynamic. The roads change 
        ; depending on where you come from and how far. We need to simplify 
        ; and rephrase the problem somehow. Each tile is connected to 12 tiles 
        ; at most. From perspective of traveler, you can reach 9 nodes. So, 
        ; every node can reach 9 other nodes for one direction. 6 of those 
        ; nodes are reachable with the opposite direction. 
        ;
        ; I think the cruz of the problem is that the shortest path to a 
        ; place may be through a large node by going around. If you can test 
        ; if you can go around with each step, does that help?
        ;
        ;   g 1 c d s           Shortest path to adj nodes is one hop.
        ;   f 3 a b r           Shortest path to 2 depends on diagnonals.
        ;   e 3 y z q           And basically all other nodes.
        ;   > x 8 2 1           If their path is less than 10.
        ;   e 4 y z q
        ;   f 3 a b r
        ;   g 1 c d s
        ;
        ; What if we did a Dykstra's but we check 9 nodes with each iteration?
        ; That kinda makes sense, but ... well, maybe. 
        ;
        ; x 8 2
        ; 3 3 3 
        ; 
        ; 0 > 1 = 8
        ; 0 > 3 = 3
        ; 0 > 2 = 10
        ;
        ; visit 0.
        ;
        ; goto node 3.
        ; 3 > 4 = 3 + 3 = 6
        ; 3 > 5 = 3 + 3 + 3 = 9
        ;
        ; visit 3.
        ; 
        ; goto 4.
        ; 4 > 1 = 6 + 8 = 14, don't update 1.
        ; 4 > 5 = 6 + 3 = 9
        ;
        ; visit 4.
        ;
        ; goto 1.
        ; 1 > 2 = 8 + 2 = 10.
        ;
        ; visit 1.
        ;
        ; goto 5.
        ; 5 > 2 = 9 + 2 = 11
        ;
        ; visit 5.
        ;
        ; goto 2.
        ; None. 
        ; visit 2.
        ; 
        ; All visited and shortest path to 2 is 10.
        ;
        ; I feel like this won't work, but I will try it.
        ; ...
        ; Okay, I am where I was last time I tried this. 
        ; The problem is that each of the four ways you can arrive at a node 
        ; change the neighbors you can document. I think there is a way to 
        ; deal with this, but I don't know. If you could visit each node 
        ; four times (once from each direction), would that help?

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
        struc memo
            
            .path:      resd    1
            .visited:   resb    1
            .pad:       resb    3

        endstruc

        push rdi
        lea rdi, [r9*8]
        call memAlloc

        mov r11, rax                    ; memo.
        mov rcx, r9
        mov rdi, r11

        .fill:
            lea rdi, [r11 + rcx*8 - 8]
            mov dword [rdi + memo.path], -1
            mov dword [rdi + memo.visited], NULL
            loop .fill

        pop rdi

        ; I'm going to ignore directions and steps for now at my peril.
        ; Init state.
        mov rsi, rdi                    ; curr_node.
        xor rdx, rdx                    ; curr_path.
        mov dword [r11 + memo.path], 0

        ; Do visited loop.
        .while:
            ; Look up path.
            mov rax, rsi
            sub rax, rdi                ; curr_idx.
            mov edx, [r11 + rax*8]

            ; Visiting curr_node. So logically, if this is tgt, it already 
            ; has shortest path. We will see.
            cmp rsi, r10
            je .endWhile
            
            ; Now update neighbor paths if they are unvisited.
            ; Need another idx.
            xor r12, r12                    ; tmp_path.
            xor rbx, rbx                    ; tmp_path_addend.
            xor rcx, rcx                    ; tmp_idx.
            xor r13, r13                    ; tmp_loc.

            .right:
                .rightSkip0:
                    lea r13, [rsi + 1]
                    mov rcx, r13
                    sub rcx, rdi

                    cmp r13, rdi
                    jb .rightSkip1

                    cmp r13, r10
                    ja .rightSkip1

                    cmp byte [r13], NEWLINE
                    je .rightSkip1

                    cmp byte [r13], NULL
                    je .rightSkip1

                    cmp byte [r11 + rcx*8 + memo.visited], TRUE
                    je .rightSkip1

                    mov r12d, edx
                    
                    mov bl, [rsi + 1]
                    sub bl, '0'
                    add r12d, ebx
                    
                    cmp r12d, [r11 + rcx*8 + memo.path]
                    jae .rightSkip1

                    mov [r11 + rcx*8 + memo.path], r12d

                .rightSkip1:
                    lea r13, [rsi + 2]
                    mov rcx, r13
                    sub rcx, rdi

                    cmp r13, rdi
                    jb .rightSkip2

                    cmp r13, r10
                    ja .rightSkip2

                    cmp byte [r13], NEWLINE
                    je .rightSkip2

                    cmp byte [r13], NULL
                    je .rightSkip2
                    
                    cmp byte [r11 + rcx*8 + memo.visited], TRUE
                    je .rightSkip2

                    mov r12d, edx
                    
                    mov bl, [rsi + 1]
                    sub bl, '0'
                    add r12d, ebx

                    mov bl, [rsi + 2]
                    sub bl, '0'
                    add r12d, ebx

                    cmp r12d, [r11 + rcx*8 + memo.path]
                    jae .rightSkip2

                    mov [r11 + rcx*8 + memo.path], r12d

                .rightSkip2:
                    lea r13, [rsi + 3]
                    mov rcx, r13
                    sub rcx, rdi

                    cmp r13, rdi
                    jb .left

                    cmp r13, r10
                    ja .left

                    cmp byte [r13], NEWLINE
                    je .left

                    cmp byte [r13], NULL
                    je .left
                    
                    cmp byte [r11 + rcx*8 + memo.visited], TRUE
                    je .left

                    mov r12d, edx
                    
                    mov bl, [rsi + 1]
                    sub bl, '0'
                    add r12d, ebx

                    mov bl, [rsi + 2]
                    sub bl, '0'
                    add r12d, ebx

                    mov bl, [rsi + 3]
                    sub bl, '0'
                    add r12d, ebx

                    cmp r12d, [r11 + rcx*8 + memo.path]
                    jae .left

                    mov [r11 + rcx*8 + memo.path], r12d

            .left:
                .leftSkip0:
                    lea r13, [rsi - 1]
                    mov rcx, r13
                    sub rcx, rdi

                    cmp r13, rdi
                    jb .leftSkip1

                    cmp r13, r10
                    ja .leftSkip1

                    cmp byte [r13], NEWLINE
                    je .leftSkip1

                    cmp byte [r13], NULL
                    je .leftSkip1

                    cmp byte [r11 + rcx*8 + memo.visited], TRUE
                    je .leftSkip1

                    mov r12d, edx
                    
                    mov bl, [rsi - 1]
                    sub bl, '0'
                    add r12d, ebx
                    
                    cmp r12d, [r11 + rcx*8 + memo.path]
                    jae .leftSkip1

                    mov [r11 + rcx*8 + memo.path], r12d

                .leftSkip1:
                    lea r13, [rsi - 2]
                    mov rcx, r13
                    sub rcx, rdi

                    cmp r13, rdi
                    jb .leftSkip2

                    cmp r13, r10
                    ja .leftSkip2

                    cmp byte [r13], NEWLINE
                    je .leftSkip2

                    cmp byte [r13], NULL
                    je .leftSkip2
                    
                    cmp byte [r11 + rcx*8 + memo.visited], TRUE
                    je .leftSkip2

                    mov r12d, edx
                    
                    mov bl, [rsi - 1]
                    sub bl, '0'
                    add r12d, ebx

                    mov bl, [rsi - 2]
                    sub bl, '0'
                    add r12d, ebx

                    cmp r12d, [r11 + rcx*8 + memo.path]
                    jae .leftSkip2

                    mov [r11 + rcx*8 + memo.path], r12d

                .leftSkip2:
                    lea r13, [rsi - 3]
                    mov rcx, r13
                    sub rcx, rdi

                    cmp r13, rdi
                    jb .up

                    cmp r13, r10
                    ja .up

                    cmp byte [r13], NEWLINE
                    je .up

                    cmp byte [r13], NULL
                    je .up
                    
                    cmp byte [r11 + rcx*8 + memo.visited], TRUE
                    je .up

                    mov r12d, edx
                    
                    mov bl, [rsi - 1]
                    sub bl, '0'
                    add r12d, ebx

                    mov bl, [rsi - 2]
                    sub bl, '0'
                    add r12d, ebx

                    mov bl, [rsi - 3]
                    sub bl, '0'
                    add r12d, ebx

                    cmp r12d, [r11 + rcx*8 + memo.path]
                    jae .up

                    mov [r11 + rcx*8 + memo.path], r12d

            .up:
                .upSkip0:
                    mov r13, rsi
                    sub r13, r8
                    mov rcx, r13
                    sub rcx, rdi

                    cmp r13, rdi
                    jb .upSkip1

                    cmp r13, r10
                    ja .upSkip1

                    cmp byte [r13], NEWLINE
                    je .upSkip1

                    cmp byte [r13], NULL
                    je .upSkip1

                    cmp byte [r11 + rcx*8 + memo.visited], TRUE
                    je .upSkip1

                    mov r12d, edx
                    
                    mov bl, [r13]
                    sub bl, '0'
                    add r12d, ebx
                    
                    cmp r12d, [r11 + rcx*8 + memo.path]
                    jae .upSkip1

                    mov [r11 + rcx*8 + memo.path], r12d

                .upSkip1:
                    mov r13, rsi
                    sub r13, r8
                    sub r13, r8
                    mov rcx, r13
                    sub rcx, rdi

                    cmp r13, rdi
                    jb .upSkip2

                    cmp r13, r10
                    ja .upSkip2

                    cmp byte [r13], NEWLINE
                    je .upSkip2

                    cmp byte [r13], NULL
                    je .upSkip2
                    
                    cmp byte [r11 + rcx*8 + memo.visited], TRUE
                    je .upSkip2

                    mov r12d, edx
                    
                    mov r13, rsi
                    sub r13, r8
                    mov bl, [r13]
                    sub bl, '0'
                    add r12d, ebx

                    sub r13, r8
                    mov bl, [r13]
                    sub bl, '0'
                    add r12d, ebx

                    cmp r12d, [r11 + rcx*8 + memo.path]
                    jae .upSkip2

                    mov [r11 + rcx*8 + memo.path], r12d

                .upSkip2:
                    mov r13, rsi
                    sub r13, r8
                    sub r13, r8
                    sub r13, r8
                    mov rcx, r13
                    sub rcx, rdi

                    cmp r13, rdi
                    jb .down

                    cmp r13, r10
                    ja .down

                    cmp byte [r13], NEWLINE
                    je .down

                    cmp byte [r13], NULL
                    je .down
                    
                    cmp byte [r11 + rcx*8 + memo.visited], TRUE
                    je .down

                    mov r12d, edx
                    
                    mov r13, rsi
                    sub r13, r8
                    mov bl, [r13]
                    sub bl, '0'
                    add r12d, ebx

                    sub r13, r8
                    mov bl, [r13]
                    sub bl, '0'
                    add r12d, ebx

                    sub r13, r8
                    mov bl, [r13]
                    sub bl, '0'
                    add r12d, ebx

                    cmp r12d, [r11 + rcx*8 + memo.path]
                    jae .down

                    mov [r11 + rcx*8 + memo.path], r12d
        
            .down:
                .downSkip0:
                    mov r13, rsi
                    add r13, r8
                    mov rcx, r13
                    sub rcx, rdi

                    cmp r13, rdi
                    jb .downSkip1

                    cmp r13, r10
                    ja .downSkip1

                    cmp byte [r13], NEWLINE
                    je .downSkip1

                    cmp byte [r13], NULL
                    je .downSkip1

                    cmp byte [r11 + rcx*8 + memo.visited], TRUE
                    je .downSkip1

                    mov r12d, edx
                    
                    mov bl, [r13]
                    sub bl, '0'
                    add r12d, ebx
                    
                    cmp r12d, [r11 + rcx*8 + memo.path]
                    jae .downSkip1

                    mov [r11 + rcx*8 + memo.path], r12d

                .downSkip1:
                    mov r13, rsi
                    add r13, r8
                    add r13, r8
                    mov rcx, r13
                    sub rcx, rdi

                    cmp r13, rdi
                    jb .downSkip2

                    cmp r13, r10
                    ja .downSkip2

                    cmp byte [r13], NEWLINE
                    je .downSkip2

                    cmp byte [r13], NULL
                    je .downSkip2
                    
                    cmp byte [r11 + rcx*8 + memo.visited], TRUE
                    je .downSkip2

                    mov r12d, edx
                    
                    mov r13, rsi
                    add r13, r8
                    mov bl, [r13]
                    sub bl, '0'
                    add r12d, ebx

                    add r13, r8
                    mov bl, [r13]
                    sub bl, '0'
                    add r12d, ebx

                    cmp r12d, [r11 + rcx*8 + memo.path]
                    jae .downSkip2

                    mov [r11 + rcx*8 + memo.path], r12d

                .downSkip2:
                    mov r13, rsi
                    add r13, r8
                    add r13, r8
                    add r13, r8
                    mov rcx, r13
                    sub rcx, rdi

                    cmp r13, rdi
                    jb .visit

                    cmp r13, r10
                    ja .visit

                    cmp byte [r13], NEWLINE
                    je .visit

                    cmp byte [r13], NULL
                    je .visit
                    
                    cmp byte [r11 + rcx*8 + memo.visited], TRUE
                    je .visit

                    mov r12d, edx
                    
                    mov r13, rsi
                    add r13, r8
                    mov bl, [r13]
                    sub bl, '0'
                    add r12d, ebx

                    add r13, r8
                    mov bl, [r13]
                    sub bl, '0'
                    add r12d, ebx

                    add r13, r8
                    mov bl, [r13]
                    sub bl, '0'
                    add r12d, ebx

                    cmp r12d, [r11 + rcx*8 + memo.path]
                    jae .visit

                    mov [r11 + rcx*8 + memo.path], r12d

            ; Visit curr_node.
            .visit:
                mov byte [r11 + rax*8 + memo.visited], TRUE


            ; Find lowest_unvisited.
            xor rcx, rcx                    ; curr_idx.
            or r12, -1                      ; curr_lowest_path
            xor r13, r13                    ; curr_lowest_path_idx.

            .find:
                cmp rcx, r9
                je .endFind

                cmp byte [r11 + rcx*8 + memo.visited], TRUE
                je .next

                cmp [r11 + rcx*8 + memo.path], r12d
                jae .next

                mov r12d, [r11 + rcx*8 + memo.path]
                mov r13, rcx

                .next:
                    inc rcx
                    jmp .find

            .endFind:
                lea rsi, [rdi + r13]
                jmp .while

        .endWhile:
            mov eax, edx
       
        .end:
            pop rbx
            pop r13
            pop r12
            leave
            ret

    ; End getSolution.


; End of file.