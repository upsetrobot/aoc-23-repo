;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Advent of Code Christmas Challenge Day 15 - Part II
;
; @brief    Implement a given hash algorithm and hash each string and return 
;           the sum of the hashes.
;
;           Now, make a hashmap of all labels and store values when the `=` 
;           operator is encountered and remove them when the `-` operator is 
;           found, then sum the products of each hashmap location (+1), 
;           slot location, and value.
;
; @file         solution.nasm
; @date         23 Dec 2023
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

struc node

    .nxt:   resq    1
    .val:   resq    1
    .lbl:   resb    1

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

        xor r12, r12                    ; sum.

        ; Allocate hash array.
        push rdi
        mov rdi, 256
        shl rdi, 3
        call memAlloc

        pop rdi
        mov r13, rax                    ; arr.

        ; Zero memory.
        push rdi
        push rcx
        mov rdi, r13
        lea rcx, [256*8]
        
        .loop:
            mov byte [rdi], 0
            inc rdi
            loop .loop

        pop rcx
        pop rdi

        .while:
            cmp byte [rdi], 0
            je .endWhile

            mov r14, rdi                ; label.
            call hash                   ; Updates rdi; goes to operator.

            mov r15, rax                ; hash.

            ; Have hash of label. Now execute operation.
            cmp byte [rdi], '='
            je .equals

            .minus:
                mov byte [rdi], 0
                inc rdi
                push rdi
                mov rdi, r14
                mov rsi, r13
                mov rdx, r15
                call removeHashmap
                pop rdi
                jmp .continue

            .equals:
                mov byte [rdi], 0
                inc rdi
                push rdi
                call scanNumber

                pop rdi
                
                inc rdi
                push rdi
                mov rdi, r14
                mov rsi, r13
                mov rdx, r15
                mov rcx, rax
                call addHashmap
                pop rdi

            .continue:
                inc rdi
                jmp .while

        .endWhile:

        .focusPower:
            xor r8, r8

            .for:
                cmp r8, 256
                je .endFor

                lea rdi, [r13 + r8*8]
                mov rdi, [rdi]
                xor r9, r9                  ; slot_num.
                inc r9

                .whileNodes:
                    test rdi, rdi
                    jz .endWhileNodes

                    lea rax, [r8 + 1]       ; box_num.
                    mov rcx, r9
                    cqo
                    mul rcx
                    mov rcx, [rdi + node.val]
                    cqo
                    mul rcx
                    add r12, rax

                    inc r9
                    mov rdi, [rdi + node.nxt]
                    jmp .whileNodes

                .endWhileNodes:

                inc r8
                jmp .for

            .endFor:

        mov rax, r12

        .end:
            pop r12
            leave
            ret

    ; End getSolution.


    ; size_t hash(char* buf);
    ;
    ; @brief    Hashes the current equals-minus-delimited string using the 
    ;           given hash algorithm.
    ;
    ; @return   size_t  Hash value.
    ;
    hash:
        push rbp
        mov rbp, rsp

        xor rax, rax

        .while:
            cmp byte [rdi], '='
            je .endWhile

            cmp byte [rdi], '-'
            je .endWhile

            cmp byte [rdi], 0
            je .endWhile
            
            cmp byte [rdi], 0xa
            je .next

            xor rcx, rcx
            mov cl, [rdi]
            add rax, rcx

            mov rcx, 17
            cqo
            mul rcx

            mov rcx, 256
            cqo
            div rcx
            mov rax, rdx

            .next:
                inc rdi
                jmp .while

        .endWhile:

        .end:
            leave
            ret

    ; End hash.


    ; int addHashMap(char* label, void* arr, size_t hash, size_t val);
    ;
    ; @brief    Creates a new node and adds it to the hashmap.
    ;
    ; @return   int     FUNC_SUCCESS if node added, else FUNC_FAILURE.
    ;
    addHashmap:
        push rbp
        mov rbp, rsp
        push r12

        test rsi, rsi
        jz .err

        push rdi
        push rsi
        push rdx
        push rcx
        call strLen

        pop rcx
        pop rdx
        pop rsi
        pop rdi

        mov r8, rax                             ; str_len.

        .checkForNode:
            lea r10, [rsi + rdx*8]
            cmp qword [r10], 0
            je .createNewNode

            mov r10, [r10]

            .checkNodes:
                test r10, r10
                jz .createNewNode

                ; Need to get greater of two str_lens.
                push rdi
                push rsi
                push rdx
                push rcx
                lea rdi, [r10 + node.lbl]
                call strLen

                pop rcx
                pop rdx
                pop rsi
                pop rdi

                cmp rax, r8
                jg .cont

                mov rax, r8

                .cont:

                push rdi
                push rsi
                push rcx
                lea rsi, [r10 + node.lbl]
                mov rcx, rax
                cld
                repe cmpsb
                mov r11, rcx
                pop rcx
                pop rsi
                pop rdi
                test r11, r11
                jz .foundNode               ; Already in there.

                mov r10, [r10 + node.nxt]
                jmp .checkNodes

                .foundNode:
                    mov [r10 + node.val], rcx
                    jmp .err

        .createNewNode:
            push rdi
            push rsi
            push rdx
            push rcx
            push r8
            mov rdi, node_size
            add rdi, r8
            inc rdi
            call memAlloc

            pop r8
            pop rcx
            pop rdx
            pop rsi
            pop rdi

            mov r9, rax                         ; new_node.

            mov qword [r9 + node.nxt], 0
            mov [r9 + node.val], rcx
            
            push rdi
            push rsi
            push rcx
            mov rsi, rdi
            lea rdi, [r9 + node.lbl]
            mov rcx, r8
            cld
            rep movsb
            mov byte [rdi], 0
            pop rcx
            pop rsi
            pop rdi
                        
        .placeNode:
            lea r10, [rsi + rdx*8]

            cmp qword [r10], 0
            je .addToArr

            mov r10, [r10]

            .getFinalNode:
                cmp qword [r10], 0
                je .addToArr

                mov r10, [r10]
                jmp .getFinalNode

            .addToArr:
                mov [r10], r9

        .added:
            xor rax, rax
            jmp .end

        .err:
            or rax, FUNC_FAILURE

        .end:
            leave
            ret
    
    ; End addHashmap.


    ; int removeHashmap(char* label, void* arr, size_t hash);
    ;
    ; @brief    Searches the hashmap for the label and removes node if found.
    ;
    ; @return   int     FUNC_SUCCESS if node found and removed; else 
    ;                   FUNC_FAILURE.
    removeHashmap:
        push rbp
        mov rbp, rsp

        test rsi, rsi
        jz .err

        lea r8, [rsi + rdx*8]                 ; last_node.
        mov rsi, [rsi + rdx*8]                ; curr_node.
        
        .loop:
            test rsi, rsi
            jz .err

            push rdi
            call strLen

            pop rdi
            mov rcx, rax                    ; str_len.

            ; Need to get greater of two str_lens.
            push rdi
            push rsi
            push rdx
            push rcx
            lea rdi, [rsi + node.lbl]
            call strLen

            pop rcx
            pop rdx
            pop rsi
            pop rdi

            cmp rax, rcx
            jle .cont

            mov rcx, rax

            .cont:

            push rdi
            push rsi
            lea rsi, [rsi + node.lbl]
            cld
            repe cmpsb
            pop rsi
            pop rdi

            test rcx, rcx
            jnz .notFound

            .found:
                mov r9, [rsi + node.nxt]
                mov [r8 + node.nxt], r9

                ; Not gonna worry about dealloc.
                jmp .removed

            .notFound:
                mov r8, rsi
                mov rsi, [rsi + node.nxt]
                jmp .loop

        .removed:
            xor rax, rax
            jmp .end

        .err:
            or rax, FUNC_FAILURE

        .end:
            leave
            ret
    
    ; End removeHashmap.


; End of file.