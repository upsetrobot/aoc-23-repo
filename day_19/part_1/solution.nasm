;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Advent of Code Christmas Challenge Day 19 - Part I
;
; @brief    Sum the attributes of all the accepted parts as determined by 
;           sending them through a acceptance workflow determined by the 
;           given instructions.
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
struc op

    .op:        resd    1
    .operand1:  resd    1
    .operand2:  resd    1
    .result:    resd    1

endstruc

struc rule

    .lbl:           resd    1
    .op1:           resb    op_size
    .op2:           resb    op_size
    .op3:           resb    op_size
    .op4:           resb    op_size
    .null_op:       resb    op_size

endstruc


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
        push r15

        xor r12, r12                    ; parse_switch;
        xor r13, r13                    ; sum.
        xor r8, r8                      ; rules_arr.
        xor r9, r9                      ; rules_arr_len.
        xor r10, r10                    ; curr_rule.

        .while:
            test rdi, rdi
            jz .endWhile

            push rdi
            call getLine

            pop rdi
            mov rsi, rax                ; next_line;

            cmp byte [rdi], NULL
            jne .parseSwitch

            inc r12                     ; Switch parsing.
            jmp .cont

            .parseSwitch:
                test r12, r12
                jnz .parsePart

            .parseRule:
                push rdi
                push rsi
                push r8
                push r9
                push r10
                mov rdi, rule_size
                call memAlloc

                pop r10
                pop r9
                pop r8
                pop rsi
                pop rdi
                mov r10, rax            ; curr_rule.

                mov rcx, rule_size

                .fillRule:
                    mov byte [rax], NULL
                    inc rax
                    loop .fillRule

                xor rcx, rcx
                test r9, r9
                jnz .additionalRules

                .firstRule:
                    mov r8, r10

                .additionalRules:
                    inc r9

                    .label:
                        cmp byte [rdi], '{'
                        je .endLabel

                        mov dl, [rdi]
                        mov [r10 + rcx + rule.lbl], dl
                        inc rcx
                        inc rdi
                        jmp .label

                    .endLabel:

                    inc rdi
                    xor rax, rax
                    
                    .operation:
                        cmp byte [rdi], '}'
                        je .endOperation

                        cmp byte [rdi], ','
                        jne .addOp

                        inc rdi

                        .addOp:
                            cmp byte [rdi], 'R'
                            je .addResult

                            cmp byte [rdi], 'A'
                            je .addResult

                            cmp byte [rdi + 1], 'a'
                            jge .addResult                            

                            mov dl, byte [rdi]
                            mov [r10 + rax + rule.op1 + op.operand1], dl
                            inc rdi
                            mov dl, byte [rdi]
                            mov [r10 + rax + rule.op1 + op.op], dl

                            push rax
                            push rsi
                            push r8
                            push r9
                            push r10
                            call scanNumber

                            mov rdx, rax
                            pop r10
                            pop r9
                            pop r8
                            pop rsi
                            pop rax
                            
                            mov [r10 + rax + rule.op1 + op.operand2], edx
                            add rdi, 2

                            .addResult:
                                lea r11, [r10 + rax + rule.op1 + op.result]
                                xor rcx, rcx
                            
                            .resultLabel:
                                cmp byte [rdi], '}'
                                je .endResultLabel

                                cmp byte [rdi], ','
                                je .endResultLabel

                                mov dl, [rdi]
                                mov [r11 + rcx], dl
                                inc rcx
                                inc rdi
                                jmp .resultLabel

                            .endResultLabel:

                            add rax, op_size
                            jmp .operation

                    .endOperation:                    
                        jmp .cont

            .parsePart:
                ; parse values.
                xor rdx, rdx                ; x.
                xor rcx, rcx                ; m.
                xor r10, r10                ; a.
                xor r11, r11                ; s.

                push rsi
                push rdx
                push rcx
                push r8
                push r9
                push r10
                push r11
                call scanNumber

                pop r11
                pop r10
                pop r9
                pop r8
                pop rcx
                pop rdx
                pop rsi

                mov rdx, rax
                inc rdi

                push rsi
                push rdx
                push rcx
                push r8
                push r9
                push r10
                push r11
                call scanNumber

                pop r11
                pop r10
                pop r9
                pop r8
                pop rcx
                pop rdx
                pop rsi
                
                mov rcx, rax
                inc rdi

                push rsi
                push rdx
                push rcx
                push r8
                push r9
                push r10
                push r11
                call scanNumber

                pop r11
                pop r10
                pop r9
                pop r8
                pop rcx
                pop rdx
                pop rsi
                
                mov r10, rax
                inc rdi

                push rsi
                push rdx
                push rcx
                push r8
                push r9
                push r10
                push r11
                call scanNumber

                pop r11
                pop r10
                pop r9
                pop r8
                pop rcx
                pop rdx
                pop rsi
                
                mov r11, rax

                ; Execute instructions.
                xor rax, rax                ; rule_idx.
                mov rdi, r8                 ; curr_rule.
                mov r15, "in"               ; curr_lbl.

                .execute:
                    .findRule:
                        cmp rax, r9
                        je .foundRule

                        cmp dword [rdi + rule.lbl], r15d
                        je .foundRule

                        inc rax
                        add rdi, rule_size
                        jmp .findRule

                    .foundRule:

                    lea rdi, [rdi + rule.op1]

                    .forOp:
                        cmp dword [rdi + op.result], NULL
                        je .endForOp

                        cmp dword [rdi + op.op], NULL
                        je .result

                        cmp dword [rdi + op.op], '<'
                        je .lessThan

                        cmp dword [rdi + op.op], '>'
                        je .greaterThan

                        int3

                        .greaterThan:
                            mov r14d, [rdi + op.operand1]
                            cmp r14b, 'x'
                            je .gx

                            cmp r14b, 'm'
                            je .gm

                            cmp r14b, 'a'
                            je .ga

                            cmp r14b, 's'
                            je .gs

                            int3

                            .gx:
                                mov r14, rdx
                                jmp .g

                            .gm:
                                mov r14, rcx
                                jmp .g

                            .ga:
                                mov r14, r10
                                jmp .g

                            .gs:
                                mov r14, r11
                                jmp .g

                            .g:
                                cmp r14d, [rdi + op.operand2]
                                ja .result
                                jmp .nextOp

                        .lessThan:
                            mov r14d, [rdi + op.operand1]
                            cmp r14b, 'x'
                            je .lx

                            cmp r14b, 'm'
                            je .lm

                            cmp r14b, 'a'
                            je .la

                            cmp r14b, 's'
                            je .ls

                            int3

                            .lx:
                                mov r14, rdx
                                jmp .l

                            .lm:
                                mov r14, rcx
                                jmp .l

                            .la:
                                mov r14, r10
                                jmp .l

                            .ls:
                                mov r14, r11
                                jmp .l

                            .l:
                                cmp r14d, [rdi + op.operand2]
                                jb .result
                                jmp .nextOp

                        .result:
                            cmp dword [rdi + op.result], 'R'
                            je .reject

                            cmp dword [rdi + op.result], 'A'
                            je .accept

                            mov r15d, [rdi + op.result]
                            mov rdi, r8
                            xor rax, rax
                            jmp .execute

                            .reject:
                                jmp .cont

                            .accept:
                                add r13, rdx
                                add r13, rcx
                                add r13, r10
                                add r13, r11
                                jmp .cont

                        .nextOp:
                            add rdi, op_size
                            jmp .forOp

                    .endForOp:
                        int3

            .cont:
                mov rdi, rsi
                jmp .while

        .endWhile:
            mov rax, r13
        
        .end:
            pop r15
            pop r14
            pop r13
            pop r12
            leave
            ret

    ; End getSolution.


; End of file.