;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Advent of Code Christmas Challenge Day 13 - Part I
;
; @brief    Find the rows above a reflection row or to the left of a 
;           reflection column and return the sum of the values found for each 
;           image.
;
; @file         solution.nasm
; @date         18 Dec 2023
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

        xor r12, r12                ; sum.

        ; Find last image.
        push rdi
        call strLen
        
        pop rdi
        mov byte [rdi + rax], 0xa

        xor r13, r13                ; last_img.

        .whileImage:

            ; Get line_len.
            xor rcx, rcx
            not rcx
            cld
            push rdi
            mov al, 0xa
            repne scasb
            pop rdi
            not rcx
            mov r8, rcx             ; line_len (with newline).

            ; Get first and last position.
            mov r9, rdi             ; first_pos.
            mov r10, rdi
            xor rdx, rdx

            .lookDoubleNewLine:
                xor rcx, rcx
                not rcx
                cld
                repne scasb
                not rcx
                cmp byte [rdi], 0xa
                je .endLookDoubleNewLine

                cmp byte [rdi], 0
                jne .lookDoubleNewLine

                ; Found last image, flag.
                mov r13, 1

            .endLookDoubleNewLine:

            dec rdi
            mov r10, rdi            ; last_pos.

            ; Check for reflection rows.
            mov rdi, r9
            xor r11, r11

            .checkRefRows:
                lea rdi, [rdi + r8]
                cmp rdi, r10
                jge .endCheckRefRows

                ; Check for reflection.
                mov rsi, rdi
                xor rdx, rdx
                push rdi

                .whileRefRow:
                    sub rdi, r8
                    cmp rdi, r9
                    jl .endWhileRefRow

                    push rdi
                    push rsi
                    mov rcx, r8
                    cld
                    repe cmpsb
                    pop rsi
                    pop rdi
                    test rcx, rcx
                    jz .matchRow

                    .noMatchRow:
                        jmp .endWhileRefRow

                    .matchRow:
                        inc rdx
                        add rsi, r8
                        jmp .whileRefRow

                .endWhileRefRow:

                pop rdi
                cmp r11, rdx
                jl .swapMaxRow
                jmp .checkRefRows

                .swapMaxRow:
                    mov r11, rdx
                    jmp .checkRefRows

            .endCheckRefRows:

            inc r1
int3
            ; I think there is only horizontal or vertical reflection, not 
            ; both.
            test r11, r11
            jnz .endCheckRefCols

            ; Check for reflection columns.
            mov rdi, r9
            xor r11, r11

            .checkRefCols:
                lea rax, [rdi + r8]
                lea rdi, [rdi + 1]                
                cmp rdi, rax
                jge .endCheckRefCols

                ; Check for reflection.
                mov rsi, rdi
                xor rdx, rdx
                push rdi

                .whileRefCols:
                    dec rsi
                    cmp rsi, r9
                    jl .endWhileRefCols

                    push rdi
                    push rsi

                    .checkCols:
                        cmp rsi, r10
                        jg .endCheckCols

                        mov al, [rsi]
                        cmp [rdi], al
                        jne .noMatchCols

                        add rdi, r8
                        add rsi, r8
                        jmp .checkCols

                    .endCheckCols:

                    .matchCols:
                        inc rdx
                        dec rsi
                        jmp .whileRefCols

                    .noMatchCols:
                        jmp .endWhileRefCols                    

                .endWhileRefCols:

                pop rdi
                cmp r11, rdx
                jl .swapMaxCols
                jmp .checkRefCols

                .swapMaxCols:
                    mov r11, rdx
                    jmp .checkRefCols

            .endCheckRefCols:

            ; Check for last image.
            test r13, r13
            jnz .endWhileImage

            mov rdi, r10
            add rdi, 3
            jmp .whileImage

        .endWhileImage:
            mov rax, r11

        .end:
            pop r12
            leave
            ret

    ; End getSolution.


; End of file.