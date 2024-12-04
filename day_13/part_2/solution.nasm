;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Advent of Code Christmas Challenge Day 13 - Part II
;
; @brief    Find the rows above a reflection row or to the left of a 
;           reflection column and return the sum of the values found for each 
;           image. But this time, change one symbol first.
;
; @file         solution.nasm
; @date         21 Dec 2023
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

struc rec

    .nxt:   resq    1
    .val:   resd    1
    .freq:  resd    1

endstruc


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

        xor r12, r12                ; sum.

        .whileImg:
            cmp byte [rdi], 0
            je .endWhileImg

            cmp byte [rdi], 0xa
            jne .testImg

            inc rdi

            .testImg:
                ; Gonna make list of all results and number of those and 
                ; search list for result with only one result after changing 
                ; a symbol.
                xor r13, r13                ; sym_pos.
                xor r15, r15                ; rotation_count.

                push rdi
                push rsi
                xor rsi, rsi
                call evaluate
                
                pop rsi
                pop rdi
                mov r8, rax                 ; base_val.

                .changeSym:
                    cmp byte [rdi + r13], 0
                    je .done

                    cmp byte [rdi + r13], 0xa
                    je .moveForward

                    cmp byte [rdi + r13], '.'
                    je .dot

                    cmp byte [rdi + r13], '#'
                    je .hash

                    inc r13
                    jmp .changeSym

                    .moveForward:
                        inc r13
                        cmp byte [rdi + r13], 0xa
                        je .done
                        jmp .changeSym

                    .dot:
                        mov byte [rdi + r13], '#'
                        jmp .eval

                    .hash:
                        mov byte [rdi + r13], '.'

                    .eval:
                        push rdi
                        push r8
                        push r9
                        mov rsi, r8
                        call evaluate

                        mov rsi, rdi
                        pop r9
                        pop r8
                        pop rdi
                        cmp byte [rdi + r13], '.'
                        je .moveHash

                        mov byte [rdi + r13], '.'
                        jmp .updateList

                        .moveHash:
                            mov byte [rdi + r13], '#'

                    .updateList:
                        test rax, rax
                        jz .nextChar

                        cmp rax, r8
                        jne .getNextImg

                    .nextChar:
                        inc r13
                        jmp .changeSym

                .done:
                    test rax, rax
                    jz .changeSomething

                    cmp rax, r8
                    je .changeSomething
                    jmp .getNextImg
                    
                .changeSomething:
                    cmp r15, 0
                    je .topLeft

                    cmp r15, 1
                    je .topRight

                    cmp r15, 2
                    je .bottomRight

                    cmp r15, 3
                    je .bottomLeft

                    int3

                    .topLeft:
                        mov r14b, [rdi]
                        mov byte [rdi], 'x'
                        mov r15, 1
                        xor r13, r13
                        jmp .changeSym

                    .topRight:
                        mov [rdi], r14b
                        mov r9, rdi

                        .loopTopRight:
                            cmp byte [r9], 0xa
                            je .endLoopTopRight

                            inc r9
                            jmp .loopTopRight

                        .endLoopTopRight:
                            dec r9

                        mov r14b, [r9]
                        mov byte [r9], 'x'
                        mov r15, 2
                        xor r13, r13
                        jmp .changeSym

                    .bottomRight:
                        mov [r9], r14b
                        mov r14b, [r10 - 1]
                        mov byte [r10 - 1], 'x'
                        mov r15, 3
                        xor r13, r13
                        jmp .changeSym

                    .bottomLeft:
                        mov [r10 - 1], r14b
                        push r10
                        dec r10

                        .loopBottomLeft:
                            cmp byte [r10], 0xa
                            je .endLoopBottomLeft

                            dec r10
                            jmp .loopBottomLeft

                        .endLoopBottomLeft:

                        mov r9, r10
                        pop r10
                        inc r9

                        mov r14b, [r9]
                        mov byte [r9], 'x'
                        mov r15, 4
                        xor r13, r13
                        jmp .changeSym

            .getNextImg:
                add r12, rax
                mov rdi, rsi
                inc rdi
                jmp .whileImg
            
        .endWhileImg:
            mov rax, r12
            jmp .end

        .err:
            mov rdi, err_getSolution
            call print
            or rax, FUNC_FAILURE

        .end:
            pop r15
            pop r14
            pop r13
            pop r12
            leave
            ret

    ; End getSolution.


    ; size_t evaluate(char* img, unsigned int checkval);
    ;
    ; @brief    Checks for relection lines in image and returns columnns to 
    ;           the left of vertical reflection lines or number of rows above 
    ;           horizontal reflective lines.
    ;
    ; @return   size_t  Value. Move `rdi` to end of image.
    ;
    evaluate:
        push rbp
        mov rbp, rsp
        push r12
        push r13
        push r14
        push r15

        ; push rsi

        .setupImg:
            xor rcx, rcx
            not rcx
            push rdi
            cld
            mov al, 0xa
            repne scasb
            not rcx
            pop rdi
            mov r8, rcx                 ; line_len.

            mov r9, rdi                 ; top_left.
            add rdi, r8

            .findBottomRight:
                cmp byte [rdi], 0xa
                je .endFindBottomRight

                dec rdi
                cmp byte [rdi], 0
                je .endFindBottomRight

                inc rdi
                add rdi, r8
                jmp .findBottomRight

            .endFindBottomRight:
                dec rdi
                mov r10, rdi            ; bottom_right.

        ; Check columns.
        mov rdi, r9            
        lea r11, [rdi + r8 - 2]         ; last_col.
        xor rdx, rdx                    ; cols_left.
        xor r13, r13
        xor r14, r14
        xor r15, r15                    ; col_score.            

        .findColRef:
            cmp rdi, r11
            je .colRefNotFound

            mov rsi, rdi
            inc rsi
            mov r13, rdi                ; curr_left.
            mov r14, rsi                ; curr_right.
            xor rcx, rcx                ; curr_score.
            push rdi

            .checkCols:
                cmp rdi, r9
                jl .colRefFound

                cmp rsi, r11
                jg .colRefFound

                .checkCol:
                    cmp rdi, r10
                    jg .endCheckCol

                    mov al, [rsi]
                    cmp al, [rdi]
                    jne .endCheckCols

                    add rdi, r8
                    add rsi, r8
                    jmp .checkCol

                .endCheckCol:
                    inc rcx
                    dec r13
                    inc r14
                    mov rdi, r13
                    mov rsi, r14
                    jmp .checkCols

                .colRefFound:
                    cmp rcx, r15
                    jle .endCheckCols

                    .updateScore:
                    mov r15, rcx
                    mov rdx, [rsp]
                    sub rdx, r9
                    inc rdx

            .endCheckCols:
                pop rdi
                inc rdi
                jmp .findColRef

        .colRefNotFound:
            mov rax, rdx
            ; pop rcx
            ; cmp rax, rcx
            ; je .check

            cmp rdx, 0
            jg .end

        ; Check rows.
        .check:
            mov rdi, r9
            mov rsi, rdi
            add rsi, r8
            xor rdx, rdx                    ; rows_above.
            xor r11, r11                    ; highest_row_score.
            xor r13, r13                    ; curr_high_row.
            xor r14, r14                    ; curr_low_row.
            xor r15, r15                    ; row_score.            

        .findRowRef:
            cmp rsi, r10
            jg .rowRefNotFound

            mov r13, rdi
            mov r14, rsi
            xor rax, rax                ; curr_score.
            push rdi
            inc rdx

            .checkRows:
                cmp rdi, r9
                jl .rowRefFound

                cmp rsi, r10
                jg .rowRefFound

                .checkRow:
                    mov rcx, r8
                    cld
                    repe cmpsb
                    test rcx, rcx
                    jnz .endCheckRows

                .endCheckRow:
                    inc rax
                    sub r13, r8
                    add r14, r8
                    mov rdi, r13
                    mov rsi, r14
                    jmp .checkRows

                .rowRefFound:
                    cmp rax, r15
                    jle .endCheckRows

                    .updateRowScore:
                    mov r15, rax
                    mov r11, rdx

            .endCheckRows:
                pop rdi
                add rdi, r8
                mov rsi, rdi
                add rsi, r8
                jmp .findRowRef

        .rowRefNotFound:
            mov rax, r11
            mov rcx, 100
            cqo
            mul rcx

        .end:
            mov rdi, r10
            pop r15
            pop r14
            pop r13
            pop r12
            leave
            ret

    ; End evaluate.


    ; rec* updateList(unsigned int val, rec* list);
    ;
    ; @brief    Update the frequency for the given value in the list.
    ;
    ; @return   rec*    Returns NULL if list updated, otherwise returns 
    ;                   address of new list.
    ;
    updateList:
        push rbp
        mov rbp, rsp

        test rsi, rsi
        jz .new

        .findRec:
            cmp [rsi + rec.val], rdi
            je .found

            cmp qword [rsi], 0
            jz .notFound            

            mov rsi, [rsi]
            jmp .findRec

        .notFound:
            push rdi
            mov rdi, rec_size
            call memAlloc

            pop rdi
            mov qword [rax + rec.nxt], 0
            mov [rax + rec.val], edi
            mov [rsi], rax

        .found:
            inc dword [rsi + rec.freq]
            xor rax, rax
            jmp .end

        .new:
            push rdi
            mov rdi, rec_size
            call memAlloc

            pop rdi
            mov qword [rax + rec.nxt], 0
            mov [rax + rec.val], edi
            inc dword [rax + rec.freq]

        .end:
            leave
            ret

    ; End updateList.


    ; unsigned int checkList(rec* list);
    ;
    ; @brief    Check if the value exists with a frequency of one.
    ;
    ; @return   unsigned int    Value if found, else -1.
    ;
    checkList:
        push rbp
        mov rbp, rsp

        .loop:
            test rdi, rdi
            jz .notFound

            cmp dword [rdi + rec.freq], 1
            je .endLoop

            mov rdi, [rdi]
            jmp .loop

        .endLoop:
            mov eax, [rdi + rec.val]
            jmp .end

        .notFound:
            or rax, FUNC_FAILURE

        .end:
            leave
            ret

    ; End checkList.


; End of file.