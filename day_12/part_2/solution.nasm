;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Advent of Code Christmas Challenge Day 12 - Part II
;
; @brief    Find the sum of different possible arrangements of broken springs.
;
;           This time, each group has to be expanded five times. Ugh.
;
;           This problem was way too hard for me. But I went on a crazy binge 
;           of trying to solve this problem in so may ways. I was able to 
;           create several innovative optimizations, which did improve 
;           performance, but not enough to be acceptable. I tried so hard to 
;           find a general complete mathematical solution, but I was only able 
;           find special cases. I tried permutations and combinations. I 
;           tried group analysis. Finally, after much experimentation, I 
;           decided to redo it all with just recursion and memoization 
;           cause that will do it.
;
;           FINALLY!!! What a nightmare. I had to switch the order of 
;           checking for symbols (I was turning ?s into # first when I needed 
;           to do dots). I got memo working. It is way faster. Ran into 
;           final problem of memory. Fixed that an WA-BAM. 
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

struc memo

	.nxt:       resq    1
    .grps:      resq    1
    .grps_len:  resq    1
	.val:       resq    1
    .str:       resb    1

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

    len_tbl:   resq    1


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

        xor rbx, rbx                        ; sum.

        ; Allocate length table. Probably like lengths up to 200.
        push rdi
        xor rdi, rdi
        inc rdi
        shl rdi, 8                          ; 0x100
        shl rdi, 3                          ; 8 bytes each.
        call memAlloc

        mov [len_tbl], rax
        
        mov r15, rax
        add r15, 0x800
        
        ; Zero table.
        mov rcx, 0x800
        mov rdi, rax
        mov al, 0
        cld
        rep stosb

        pop rdi
        
        .whileLines:
            test rdi, rdi
            je .endWhileLines

            push r15
            call getLine

            mov r12, rax                    ; nxt_line.
            mov r13, rdi                    ; line.
            
            call getExpandedStr

            mov rdi, rax
            mov r13, rax
            xor rcx, rcx
            mov rdx, 0x7fffffffffffffff

            .parseNumbers:
                push rcx
                push rdx
                call scanNumber

                pop rdx
                pop rcx
                cmp rax, rdx
                je .endParseNumbers

                push rax
                inc rcx
                inc rdi
                jmp .parseNumbers

            .endParseNumbers:

            ; Allocate array.
            ; Considering just using stack instead.
            mov r15, rcx                    ; arr_len.
            lea rdi, [rcx*8]
            call memAlloc

            mov r14, rax                    ; arr.
            mov rcx, r15

            .fillArr:
                test rcx, rcx
                jz .endFillArr

                pop rdx
                mov [rax + rcx*8 - 8], rdx
                dec rcx
                jmp .fillArr

            .endFillArr:

            mov rdi, r13
            mov rsi, r14
            mov rdx, r15
            xor rcx, rcx
            mov cl, '.'
            xor r8, r8
            xor r9, r9
            call dynamicSolution

            add rbx, rax

            ; Dealloc.
            mov rdi, 0
            call memAlloc

            pop r15

            sub rax, r15
            mov rdi, rax
            call memDealloc         ; not working?

            ; Zero table.
            mov rax, [len_tbl]
            mov rcx, 0x800
            mov rdi, rax
            mov al, 0
            cld
            rep stosb

            mov rdi, r12
            jmp .whileLines

        .endWhileLines:

        mov rax, rbx
        jmp .end

        .err:
            mov rdi, STDERR
            mov rsi, err_getSolution
            mov rdx, err_getSolution_len
            mov rax, SYS_WRITE
            syscall

            or rax, FUNC_FAILURE
        
        .end:
            pop rbx
            pop r15
            pop r14
            pop r13
            pop r12
            leave
            ret

    ; End getSolution.


    ; size_t dynamicSolution(
    ;       char* string, 
    ;       size_t* group_arr, 
    ;       size_t group_arr_len, 
    ;       short prev_and_curr_sym, 
    ;       size_t curr_group,
    ;       size_t curr_num_hashes,
    ; );
    ;
    ; @brief    Recusively solve problem.
    ;
    ; @return   size_t      The number of ways to meet constraints.
    ;
    dynamicSolution:
        push rbp
        mov rbp, rsp
        push r12

        push rdi
        push rsi
        push rdx
        push rcx
        push r8
        push r9

        mov rdi, rbx
        call numToStr
        mov rdi, num_str
        call print

        pop r9
        pop r8
        pop rcx
        pop rdx
        pop rsi
        pop rdi

        mov r10, rdx
        dec r10                         ; last_grp_idx.
        xor r12, r12                    ; result.

        .check:
            cmp cl, '#'
            je .checkPrevHash

            .checkPrevDot:
                cmp byte [rdi], '.'
                je .dotdot

                cmp byte [rdi], '#'
                je .dothash

                cmp byte [rdi], '?'
                je .dot?

                ; Assume space.
                ; Check if curr num_hashes is equal to curr_grp.
                ; And check if curr_grp is last grp.
                cmp r9, [rsi + r8*8]
                jne .return0

                cmp r8, r10
                jne .return0
                jmp .return1

                .dotdot:
                    mov cl, '.'
                    jmp .getNext

                .dothash:
                    mov cl, '#'
                    inc r9
                    jmp .getNext

                .dot?:
                    ; .optimize:
                    ;     push rdi
                    ;     push rcx
                    ;     push r8
                    ;     push r10
                    ;     xor r10, r10
                    ;     xor rcx, rcx

                    ;     .num?:
                    ;         cmp byte [rdi], ' '
                    ;         je .endNum?

                    ;         cmp byte [rdi], '?'
                    ;         je .count

                    ;         cmp byte [rdi], '#'
                    ;         je .count
                    ;         jmp .dontCount

                    ;         .count:
                    ;             inc rcx

                    ;         .dontCount:
                    ;             inc rdi
                    ;             jmp .num?

                    ;     .endNum?:

                    ;     .countTgt:
                    ;         cmp r8, rdx
                    ;         je .endCountTgt

                    ;         add r10, [rsi + r8*8]
                    ;         inc r8
                    ;         jmp .countTgt

                    ;     .endCountTgt: 

                    ;     cmp rcx, r10
                    ;     jl .gonnaRet0

                    ;     pop r10
                    ;     pop r8
                    ;     pop rcx
                    ;     pop rdi
                    ;     jmp .checkMemos
                        
                    ;     .gonnaRet0:
                    ;         pop r10
                    ;         pop r8
                    ;         pop rcx
                    ;         pop rdi
                    ;         jmp .return0

                    .checkMemos:
                        cmp r9, 0
                        jne .dpDot

                        push rdi
                        push rsi
                        push rdx
                        push rcx
                        push r8
                        push r9

                        lea rsi, [rsi + r8*8]
                        sub rdx, r8
                        call checkMemo

                        pop r9
                        pop r8
                        pop rcx
                        pop rdx
                        pop rsi
                        pop rdi

                        cmp rax, -1
                        jne .end

                    .dpDot:
                        push rdi
                        push rsi
                        push rdx
                        push rcx
                        push r8
                        push r9

                        mov cl, '.'
                        inc rdi
                        call dynamicSolution

                        add r12, rax
                        pop r9
                        pop r8
                        pop rcx
                        pop rdx
                        pop rsi
                        pop rdi

                        push rdi
                        push rsi
                        push rdx
                        push rcx
                        push r8
                        push r9

                        mov cl, '#'
                        inc r9
                        inc rdi
                        call dynamicSolution

                        add r12, rax
                        pop r9
                        pop r8
                        pop rcx
                        pop rdx
                        pop rsi
                        pop rdi

                    .addMemo:
                        mov rax, r12
                        cmp r9, 0
                        jne .end

                        ; cmp r12, 0
                        ; jne .end

                        push rdi
                        push rsi
                        push rdx
                        push rcx
                        push r8
                        push r9
                        push r10

                        inc rdi
                        mov rcx, rdx
                        sub rcx, r8
                        lea rdx, [rsi + r8*8]
                        mov rsi, r12
                        mov r8b, '?'
                        call createMemo

                        pop r10
                        pop r9
                        pop r8
                        pop rcx
                        pop rdx
                        pop rsi
                        pop rdi
                        
                        mov rax, r12
                        jmp .end

            .checkPrevHash:
                cmp byte [rdi], '.'
                je .hashdot

                cmp byte [rdi], '#'
                je .hashhash

                cmp byte [rdi], '?'
                je .hash?

                ; Assume space.
                ; Check if curr num_hashes is equal to curr_grp.
                ; And check if curr_grp is last grp.
                cmp r9, [rsi + r8*8]
                jne .return0

                cmp r8, r10
                jne .return0
                jmp .return1

                .hashdot:
                    mov cl, '.'

                    ; Close group.
                    cmp r9, [rsi + r8*8]
                    jne .return0

                    cmp r8, r10
                    je .getNext

                    inc r8
                    xor r9, r9
                    jmp .getNext

                .hashhash:
                    mov cl, '#'
                    inc r9
                    cmp r9, [rsi + r8*8]
                    jg .return0
                    jmp .getNext

                .hash?:
                    .dpHashDot:
                        push rdi
                        push rsi
                        push rdx
                        push rcx
                        push r8
                        push r9

                        ; Close group.
                        cmp r9, [rsi + r8*8]
                        jne .skipDot?

                        cmp r8, r10
                        je .skip

                        inc r8
                        xor r9, r9
                        
                        .skip:

                        mov cl, '.'
                        inc rdi
                        call dynamicSolution

                        add r12, rax
                        pop r9
                        pop r8
                        pop rcx
                        pop rdx
                        pop rsi
                        pop rdi
                        jmp .dpHashHash

                    .skipDot?:
                        pop r9
                        pop r8
                        pop rcx
                        pop rdx
                        pop rsi
                        pop rdi

                    .dpHashHash:
                        push rdi
                        push rsi
                        push rdx
                        push rcx
                        push r8
                        push r9

                        inc r9
                        cmp r9, [rsi + r8*8]
                        jg .skipHash?

                        mov cl, '#'
                        inc rdi
                        call dynamicSolution

                        add r12, rax
                        pop r9
                        pop r8
                        pop rcx
                        pop rdx
                        pop rsi
                        pop rdi
                        jmp .addHash

                    .skipHash?:
                        pop r9
                        pop r8
                        pop rcx
                        pop rdx
                        pop rsi
                        pop rdi                        

                    .addHash:
                        mov rax, r12
                        jmp .end

            .getNext:
                inc rdi
                jmp .check

        .return1:
            xor rax, rax
            inc rax
            jmp .end

        .return0:
            xor rax, rax

        .end:
            pop r12
            leave
            ret

    ; End dynamicSolution.


    ; char* getExpandedStr(char* string);
    ;
    ; @brief    Expands string so that each the springs code is replaced with 
    ;           five copies separated by a `?` and replace the group numbers 
    ;           by five copies of the list separated by a `,`.
    ;
    ; @returns  char*   Pointer to allocated memory with expanded string.
    ;
    getExpandedStr:
        push rbp
        mov rbp, rsp

        ; Calculate size of new string.
        mov r8, rdi
        call strLen

        xor rdx, rdx
        mov rcx, 5
        mul rcx
        add rax, 8

        mov rdi, rax
        call memAlloc

        mov rsi, rax
        mov r10, rax
        mov rcx, 5
        
        .fillBufCode:
            test rcx, rcx
            jz .endFillBufCode

            mov rdi, r8
            xor al, al

            .loop:
                cmp al, ' '
                je .endLoop

                mov al, [rdi]
                mov [rsi], al
                inc rdi
                inc rsi
                jmp .loop

            .endLoop:

            dec rsi
            mov byte [rsi], '?'
            inc rsi
            dec rcx
            jmp .fillBufCode

        .endFillBufCode:

        dec rsi
        mov byte [rsi], ' '
        inc rsi
        mov rcx, 5
        mov r9, rdi
        
        .fillNumbers:
            test rcx, rcx
            jz .endfillNumbers

            mov al, 1
            mov rdi, r9

            .loop1:
                test al, al
                jz .endLoop1

                cmp al, 10
                je .endLoop1

                mov al, [rdi]
                mov [rsi], al
                inc rdi
                inc rsi
                jmp .loop1

            .endLoop1:

            dec rsi
            mov byte [rsi], ','
            inc rsi
            dec rcx
            jmp .fillNumbers

        .endfillNumbers:

        dec rsi
        mov byte [rsi], 0
        mov rax, r10

        .end:
            leave
            ret

    ; End getExpandedStr.


    ; void createMemo(
    ;   char* string,
    ;   size_t val,
    ;   size_t* grps,
    ;   size_t grps_len,
    ;   char curr_sym
    ; );
    ;
    ; @brief    Create memo entry with known value.
    ;
    createMemo:
        push rbp
        mov rbp, rsp
        push r12
        push r13

        cmp byte [rdi], ' '
        je .end

        mov r10, rdi
        xor r12, r12                ; str_len.

        .count:
            cmp byte [r10], ' '
            je .endCount

            inc r10
            inc r12
            jmp .count

        .endCount:

        inc r12

        ; Check memory.
        ; push rdi
        ; push rsi
        ; push rdx
        ; push rcx
        ; push r8
        ; push rbx
        ; xor rbx, rbx
        ; mov rax, SYS_BRK
        ; syscall

        ; pop rbx
        ; pop r8
        ; pop rcx
        ; pop rdx
        ; pop rsi
        ; pop rdi

        ; cmp rax, 0x1325c20000000010
        ; ja .end

        ; Allocate memory.
        push rdi
        push rsi
        push rdx
        push rcx
        push r8

        mov rdi, r12
        inc rdi
        add rdi, memo_size
        call memAlloc

        pop r8
        pop rcx
        pop rdx
        pop rsi
        pop rdi

        ; Get table slot.
        mov r13, [len_tbl]
        lea r13, [r13 + r12*8]
        dec r12

        .findEnd:
            cmp qword [r13 + memo.nxt], 0
            jz .found

            mov r13, [r13 + memo.nxt]
            jmp .findEnd

        .found:

        mov [r13 + memo.nxt], rax
        mov qword [rax + memo.nxt], 0
        mov [rax + memo.grps], rdx
        mov [rax + memo.grps_len], rcx
        mov [rax + memo.val], rsi

        ; Strcpy.
        mov byte [rax + memo.str], r8b
        mov rsi, rdi
        lea rdi, [rax + memo.str + 1]
        mov rcx, r12
        cld
        rep movsb
        mov byte [rdi], 0

        .end:
            pop r13
            pop r12
            leave
            ret

    ; End createMemo.


    ; size_t checkMemo(
    ;   char* string, 
    ;   size_t* grps, 
    ;   size_t grps_len,
    ; );
    ;
    ; @brief    Check list for copy of string, then return value if found.
    ;           Otherwise return -1.
    ;
    ; @return   Return value if found; otherwise, return -1.
    checkMemo:
        push rbp
        mov rbp, rsp
        push r12
        push r13

        mov r13, rsi

        cmp byte [rdi], ' '
        je .notFound

        ; Check table for strlen.
        xor r11, r11                    ; strlen.
        mov r8, rdi                     ; string.
        mov r12b, cl                    ; first.

        .len:
            cmp byte [rdi], ' '
            je .endLen

            inc r11
            inc rdi
            jmp .len

        .endLen:

        mov r9, [len_tbl]
        test r9, r9
        jz .notFound

        mov r9, [r9 + r11*8]
        
        ; Check memo list.
        .loop:
            test r9, r9
            jz .notFound

            ; Compare groups.
            cmp rdx, [r9 + memo.grps_len]
            jne .cont

            xor rcx, rcx

            .groups:
                cmp rcx, rdx
                je .endGroups

                mov r10, [r9 + memo.grps]
                mov r10, [r10 + rcx*8]
                cmp r10, [r13 + rcx*8]
                jne .cont

                inc rcx
                jmp .groups

            .endGroups:

            ; Strcmp.
            mov rcx, r11
            mov rdi, r8
            lea rsi, [r9 + memo.str] 
            cld
            repe cmpsb

            test rcx, rcx
            je .retVal

            .cont:
                mov r9, [r9 + memo.nxt]
                jmp .loop

        .retVal:
            mov rax, [r9 + memo.val]
            jmp .end

        .notFound:
            or rax, FUNC_FAILURE

        .end:
            pop r13
            pop r12
            leave
            ret

    ; End checkMemo.


; End of file.