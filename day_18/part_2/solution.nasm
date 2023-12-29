;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Advent of Code Christmas Challenge Day 18 - Part II
;
; @brief    We have to calculate the area of the perimeter formed by the 
;           given commands to move in different direction.
;
;           There are also colors which I assume will become relevant in Part 
;           II. 
;
;           Since this is a simple area problem, I am gonna try Guass's 
;           formula (aka Shoelace formula). I will probably pick the first 
;           point as the origin.
;
;           This time we use the first five digits of the hex code for the 
;           distance and the last digit for the direction where 0 is R, 1 is 
;           D, 2 is L, and 3 is U.
;
; @file         solution.nasm
; @date         29 Dec 2023
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

%define MUL_256_SHIFTER 8


; Struc definitions.
; None.


; Global constants.
section .rodata

    filename                db  "input.txt", 0
    
    err_main                db  "Error Main", 10, 0
    err_main_len            equ $ - err_main
    
    msg                     db  "Solution: ", 0


; Global uninitialized variables.
section .bss

    ; None.


; Global initialized variables.
section .data

    ; None.


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

        ; Need to deal with negative numbers here, so keep that in mind.
        ; Gonna have to do a lot of multiplication, so rax and rdx may need to 
        ; be clear.
        ; Parse one line at a time, multiply x by next y and y by next x and 
        ; keep track of both sums.
        xor r8, r8                  ; sum_1.
        xor r9, r9                  ; sum_2.
        xor r10, r10                ; x1.
        xor r11, r11                ; y1.
        xor r14, r14                ; perimeter.

        .while:
            cmp rdi, NULL
            je .endWhile

            call getLine            ; Leaves rdi and returns nxt_ln or -1.

            mov rsi, rax            ; nxt_ln.

            ; Need to get last char.
            push rdi
            push rsi
            push r8
            push r9
            push r10
            push r11
            call strLen

            pop r11
            pop r10
            pop r9
            pop r8
            pop rsi
            pop rdi

            lea rcx, [rdi + rax - 2]
            mov dl, [rcx]
            mov byte [rcx], NULL
            add rdi, 4

            push rdi
            push rsi
            push rdx
            push rcx
            push r8
            push r9
            push r10
            push r11
            call scanHex

            pop r11
            pop r10
            pop r9
            pop r8
            pop rcx
            pop rdx
            pop rsi
            pop rdi            

            ; rax = num_to_move.
            mov r12, r10            ; x2 = x1.
            mov r13, r11            ; y2 = y1.
            add r14, rax
            
            cmp dl, '0'
            je .right

            cmp dl, '2'
            je .left

            cmp dl, '3'
            je .up

            cmp dl, '1'
            je .down

            int3

            .right:                
                add r12, rax        ; Move x2 right.
                jmp .next

            .left:
                sub r12, rax        ; Move x2 left.
                jmp .next

            .up:
                add r13, rax        ; Move y2 up.
                jmp .next

            .down:
                sub r13, rax        ; Move y2 down.
                jmp .next

            .next:
                ; I think I have to skip this step for the last one.
                ; Actually, the last step I have to add x1 to r8 and y1 to r9.
                ; Multiply x1 and y2.
                mov rax, r10
                cqo
                imul r13
                add r8, rax

                ; Multiply x2 and y1.
                mov rax, r11
                cqo
                imul r12
                add r9, rax

                mov r10, r12        ; x1 = x2.
                mov r11, r13        ; y1 = y2.
                mov rdi, rsi
                jmp .while                

        .endWhile: 

        ; Subtract sums and get absolute value then divide by two.
        mov rax, r8
        sub rax, r9

        cqo                         ; Find abs(a).
        xor rax, rdx
        sub rax, rdx

        shr rax, 1

        ; Add perimeter divided by 2 to account for border.
        shr r14, 1
        add rax, r14
        inc rax                     ; Account for corners.
        
        .end:
            leave
            ret

    ; End getSolution.


    ; size_t scanHex(char* str);
    ;
    ; @brief    Scans string for hex number and returns the number. 
    ;
    ; @return   size_t  Hex number if found; otherwise 0.
    ;
    scanHex:
        push rbp
        mov rbp, rsp

        xor rax, rax
        test rdi, rdi
        jz .end

        .scanForward:
            cmp byte [rdi], NULL
            je .endScanForward

            cmp byte [rdi], '0'
            jl .scanNext

            cmp byte [rdi], '9'
            jle .endScanForward

            cmp byte [rdi], 'A'
            jl .scanNext

            cmp byte [rdi], 'F'
            jle .endScanForward

            cmp byte [rdi], 'a'
            jl .scanNext

            cmp byte [rdi], 'f'
            jle .endScanForward

            .scanNext:
                inc rdi
                jmp .scanForward
        
        .endScanForward:

        cmp byte [rdi], NULL
        je .end

        xor rcx, rcx
        push rdi

        .countDigits:
            cmp byte [rdi], NULL
            je .endCountDigits

            cmp byte [rdi], '0'
            jl .endCountDigits

            cmp byte [rdi], '9'
            jle .hex

            cmp byte [rdi], 'A'
            jl .endCountDigits

            cmp byte [rdi], 'F'
            jle .hex

            cmp byte [rdi], 'a'
            jl .endCountDigits

            cmp byte [rdi], 'f'
            jg .endCountDigits

            .hex:
                inc rcx
                inc rdi
                jmp .countDigits
        
        .endCountDigits:

        pop rdi
        
        ; For now, only scan up to 16 digits.
        cmp rcx, 16
        jle .setup

        mov rcx, 16

        .setup:
            xor rdx, rdx

        .translate:
            test rcx, rcx
            jz .end

            mov dl, [rdi]
            cmp dl, '9'
            jle .num

            cmp dl, 'F'
            jle .cap

            cmp dl, 'f'
            jle .lower

            int3

            .num:
                sub dl, '0'
                add rax, rdx
                cmp rcx, 1
                je .end

                shl rax, 4
                jmp .translateNext

            .cap:
                sub dl, 'A'
                add dl, 10
                add rax, rdx
                cmp rcx, 1
                je .end

                shl rax, 4
                jmp .translateNext

            .lower:
                sub dl, 'a'
                add dl, 10
                add rax, rdx
                cmp rcx, 1
                je .end

                shl rax, 4

            .translateNext:
                dec rcx
                inc rdi
                jmp .translate

        .end:
            leave
            ret

    ; End scanHex.


; End of file.