;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Advent of Code Christmas Challenge Day 17 - Part I
;
; @brief    Find the minimum sum of the digits along the path from the top 
;           right to bottom left while only being able to move 3 consecutive 
;           step in one direction at most at one time.
;
;           Dykstra's works great but I don't know how to get it over this:
;           1112999
;           9911111
;           9999991
;           9999991
;           9999991
;
; @file         solution.nasm
; @date         24 Dec 2023
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

            .loc:       resq    1
            .path:      resd    1
            .visited:   resb    1
            .dir:       resb    1
            .steps:     resb    1
            .pad:       resb    1

        endstruc

        push rdi
        mov rdi, r9
        shl rdi, 4
        call memAlloc

        pop rdi
        mov r11, rax                    ; memo.

        ; Fill with high value for path.
        push rdi
        mov rsi, r11
        xor rcx, rcx
        xor rdx, rdx

        .fill:
            cmp rcx, r9
            je .endFill

            mov rdx, rcx
            shl rdx, 4
            mov [rsi + rdx + memo.loc], rdi
            mov dword [rsi + rdx + memo.path], -1
            mov byte [rsi + rdx + memo.visited], FALSE
            mov byte [rsi + rdx + memo.dir], NULL
            mov byte [rsi + rdx + memo.steps], 0

            inc rdi
            inc rcx
            jmp .fill
        
        .endFill:
            pop rdi

        ; Gonna try a modified dykstra's. 
        ; Start at src node.
        ; Mark path to src as 0.
        ; Mark src as visited.
        xor rdx, rdx                    ; path_len.
        mov rsi, rdi                    ; curr_node.
        mov rcx, rsi                    ; tmp_offset.
        sub rcx, rdi
        shl rcx, 4                      ; Mulitply by 16.
        xor rax, rax                    ; curr_dir.
        xor rbx, rbx                    ; curr_steps.
        mov [r11 + rcx + memo.path], edx
        mov byte [r11 + rcx + memo.dir], al
        mov byte [r11 + rcx + memo.steps], bl
        mov byte [r11 + rcx + memo.visited], TRUE

        lea r12, [r10 - 1]              ; tgt_node.

        ; r8 = line_len.
        ; r9 = arr_len.
        ; r10 = bottom_right.
        ; r11 = arr.
        ; rdi = top_left.
        ; rsi = curr_node.
        ; rdx = curr_node_path.
        ; rcx = curr_offset.
        ; rax = curr_dir.
        ; rbx = curr_steps.
        ; r12 = tgt.
        ; r13 = tmp.
        ; r14 = tmp.

        .while:
            ; Get path of curr_node.
            mov rcx, rsi                    ; tmp_offset.
            sub rcx, rdi
            shl rcx, 4
            mov edx, [r11 + rcx + memo.path]

            ; Is node dest; if yes return path.
            cmp rsi, r12
            je .endWhile

            ; Update adjacent nodes.
            mov al, byte [r11 + rcx + memo.dir]
            mov bl, byte [r11 + rcx + memo.steps]

            .right:
                push rsi
                push rbx
                push rcx
                
                ; mov r15b, al
                ; and r15b, LEFT
                ; cmp r15b, LEFT
                ; je .right.lv

                ; mov r15b, al
                ; and r15b, RIGHT
                cmp al, RIGHT
                jne .right.turn

                cmp bl, MAX_STEPS
                je .right.lv

                inc bl
                jmp .right.move

                .right.turn:
                    xor bl, bl

                .right.move:
                    inc rsi
                    cmp rsi, rdi
                    jb .right.lv

                    cmp rsi, r10
                    jae .right.lv

                    cmp byte [rsi], NEWLINE
                    je .right.lv

                    cmp byte [rsi], NULL
                    je .right.lv

                    xor r13, r13
                    mov r13b, byte [rsi]
                    sub r13, '0'
                    add r13, rdx

                    mov rcx, rsi
                    sub rcx, rdi
                    shl rcx, 4

                    cmp r13d, [r11 + rcx + memo.path]
                    ja .right.lv

                    mov [r11 + rcx + memo.path], r13d
                    or byte [r11 + rcx + memo.dir], RIGHT
                    mov byte [r11 + rcx + memo.steps], bl
                    
                .right.lv:
                    pop rcx
                    pop rbx
                    pop rsi

            .left:
                push rsi
                push rbx
                push rcx

                ; mov r15b, al
                ; and r15b, RIGHT
                ; cmp r15b, RIGHT
                ; je .left.lv

                ; mov r15b, al
                ; and r15b, LEFT
                cmp al, LEFT
                jne .left.turn

                cmp bl, MAX_STEPS
                je .left.lv

                inc bl
                jmp .left.move

                .left.turn:
                    xor bl, bl

                .left.move:
                    dec rsi
                    cmp rsi, rdi
                    jb .left.lv

                    cmp rsi, r10
                    jae .left.lv

                    cmp byte [rsi], NEWLINE
                    je .left.lv

                    cmp byte [rsi], NULL
                    je .left.lv

                    xor r13, r13
                    mov r13b, byte [rsi]
                    sub r13, '0'
                    add r13, rdx

                    mov rcx, rsi
                    sub rcx, rdi
                    shl rcx, 4

                    cmp r13d, [r11 + rcx + memo.path]
                    ja .left.lv

                    mov [r11 + rcx + memo.path], r13d
                    or byte [r11 + rcx + memo.dir], LEFT
                    mov byte [r11 + rcx + memo.steps], bl
                    
                .left.lv:
                    pop rcx
                    pop rbx
                    pop rsi

            .down:
                push rsi
                push rbx
                push rcx

                ; mov r15b, al
                ; and r15b, UP
                ; cmp r15b, UP
                ; je .down.lv

                ; mov r15b, al
                ; and r15b, DOWN
                cmp al, DOWN
                jne .down.turn

                cmp bl, MAX_STEPS
                je .down.lv

                inc bl
                jmp .down.move

                .down.turn:
                    xor bl, bl

                .down.move:
                    add rsi, r8
                    cmp rsi, rdi
                    jb .down.lv

                    cmp rsi, r10
                    jae .down.lv

                    cmp byte [rsi], NEWLINE
                    je .down.lv

                    cmp byte [rsi], NULL
                    je .down.lv

                    xor r13, r13
                    mov r13b, byte [rsi]
                    sub r13, '0'
                    add r13, rdx

                    mov rcx, rsi
                    sub rcx, rdi
                    shl rcx, 4

                    cmp r13d, [r11 + rcx + memo.path]
                    ja .down.lv

                    mov [r11 + rcx + memo.path], r13d
                    or byte [r11 + rcx + memo.dir], DOWN
                    mov byte [r11 + rcx + memo.steps], bl
                    
                .down.lv:
                    pop rcx
                    pop rbx
                    pop rsi
            
            .up:
                push rsi
                push rbx
                push rcx

                ; mov r15b, al
                ; and r15b, DOWN
                ; cmp r15b, DOWN
                ; je .up.lv

                ; mov r15b, al
                ; and r15b, UP
                cmp al, UP
                jne .up.turn

                cmp bl, MAX_STEPS
                je .up.lv

                inc bl
                jmp .up.move

                .up.turn:
                    xor bl, bl

                .up.move:
                    sub rsi, r8
                    cmp rsi, rdi
                    jb .up.lv

                    cmp rsi, r10
                    jae .up.lv

                    cmp byte [rsi], NEWLINE
                    je .up.lv

                    cmp byte [rsi], NULL
                    je .up.lv

                    xor r13, r13
                    mov r13b, byte [rsi]
                    sub r13, '0'
                    add r13, rdx

                    mov rcx, rsi
                    sub rcx, rdi
                    shl rcx, 4

                    cmp r13d, [r11 + rcx + memo.path]
                    ja .up.lv

                    mov [r11 + rcx + memo.path], r13d
                    or byte [r11 + rcx + memo.dir], UP
                    mov byte [r11 + rcx + memo.steps], bl
                    
                .up.lv:
                    pop rcx
                    pop rbx
                    pop rsi

            ; Mark node as visited.
            mov byte [r11 + rcx + memo.visited], TRUE

            ; Now select node that is not visited with lowest path.
            xor rcx, rcx
            xor rsi, rsi        ; Lowest loc.
            xor r14, r14
            or r14d, -1          ; Lowest path.

            .find:
                cmp rcx, r9
                je .endFind

                mov r13, rcx
                shl r13, 4
                cmp byte [r11 + r13 + memo.visited], TRUE
                je .next

                cmp r14d, [r11 + r13 + memo.path]
                jbe .next

                mov r14d, [r11 + r13 + memo.path]
                mov rsi, [r11 + r13 + memo.loc]

                .next:
                    inc rcx
                    jmp .find

            .endFind:
                jmp .while

        .endWhile:
        
            mov eax, edx
            jmp .end

        .end:
            pop rbx
            pop r15
            pop r14
            pop r13
            pop r12
            leave
            ret

    ; End getSolution.


; End of file.