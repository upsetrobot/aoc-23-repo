;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Advent of Code Christmas Challenge Day 12 - Part II
;
; @brief    Find the sum of different possible arrangements of broken springs.
;
;           This time, each group has to be expanded five times. Ugh.
;
; @file         solution.nasm
; @date         13 Dec 2023
; @author       upsetrobot
; @copyright    Copyright (c) 2023
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%include "lib.nasm"

%define STDIN   0
%define STDOUT  1
%define STDERR  2

%define SYS_READ    0
%define SYS_WRITE   1
%define SYS_OPEN    2
%define SYS_CLOSE   3
%define SYS_STAT    4
%define SYS_BRK     12

%define EXIT_SUCCESS    0
%define EXIT_FAILURE    -1

%define FUNC_SUCCESS    0
%define FUNC_FAILURE    -1

%define NULL            0

%define TRUE    1
%define FALSE   0

%define MAX_INT_STR_LEN 21

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
        push rbx

        xor rbx, rbx                        ; sum.
        
        .whileLines:
            test rdi, rdi
            je .endWhileLines

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

            mov rdi, r14
            mov rsi, r15
            mov rdx, r13
            xor rcx, rcx
            xor r8, r8
            mov r9b, '.'
            push '.'
            call dynamicSolution

            pop r10
            add rbx, rax

            ; Deallocate array.
            lea rdi, [r15*8]
            call memDealloc

            test rax, rax
            js .err

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
    ;       size_t* group_arr, 
    ;       size_t group_arr_len, 
    ;       char* string, 
    ;       size_t curr_num_pounds, 
    ;       size_t curr_group,
    ;       char first_sym,
    ;       char prev_sym
    ; );
    ;
    ; @brief    Recusive solve problem.
    ;
    ; @return   size_t      The number of ways to meet constraints.
    ;
    dynamicSolution:
        push rbp
        mov rbp, rsp
        push r12
        push r13
        push r14
        push r15

        mov r12, rdi                    ; group_arr.
        mov r13, rsi                    ; group_arr_len.
        mov r14, rdx                    ; string.
        xor r15, r15                    ; ret_val.
        mov r10, [rsp + 8*6]             ; prev_sym.

        mov rdi, r14
        dec rsi                         ; Last group number.
        dec rdi

        .checkFirstSym:
            cmp r9b, '.'
            je .dot

            cmp r9b, '#'
            je .pound

            cmp r9b, '?'
            je .question
            jmp .return0

        .checkLetter:
            cmp byte [rdi], '.'
            je .dot

            cmp byte [rdi], '#'
            je .pound

            cmp byte [rdi], '?'
            je .question

            cmp r8, r13
            je .return1

            cmp r8, rsi
            jne .return0

            cmp rcx, [r12 + r8*8]
            jne .return0
            jmp .return1

        .question:
            ; Here ways are equal to ways as a dot + ways as a pound.
            ; Need to pass string, current number of pounds, current group, 
            ; and rest of groups.
            inc rdi
            
            push rdi
            push rcx
            push r8

            push r10
            mov rdx, rdi
            mov rdi, r12
            mov rsi, r13
            mov r9, '#'
            call dynamicSolution

            pop r10
            pop r8
            pop rcx
            pop rdi
            add r15, rax

            push r10
            mov rdx, rdi
            mov rdi, r12
            mov rsi, r13
            mov r9, '.'
            call dynamicSolution

            pop r10
            add rax, r15
            jmp .end

        .pound:
            cmp r8, rsi
            jg .return0

            ; Check if curr_pounds exceeds group target.
            inc rcx
            cmp rcx, [r12 + r8*8]
            jg .return0
            
            inc rdi
            mov r10b, '#'
            jmp .checkLetter

        .dot:
            cmp r10b, '#'
            jne .contCheck

            .closeGroup:
                cmp r8, rsi
                jg .return0

                cmp rcx, [r12 + r8*8]
                jl .return0

                xor rcx, rcx
                inc r8
                
            .contCheck:
                inc rdi
                mov r10b, '.'
                jmp .checkLetter

        .return1:
            xor rax, rax
            inc rax
            jmp .end

        .return0:
            xor rax, rax

        .end:
            pop r15
            pop r14
            pop r13
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
        mov rcx, 3
        mul rcx
        add rax, 8

        mov rdi, rax
        call memAlloc

        mov rsi, rax
        mov r10, rax
        mov rcx, 3
        
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
        mov rcx, 3
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


    ;
    ; checkForShortCutSolution:
    ;     push rbp
    ;     mov rbp, rsp

    ;     call getNumGroups

    ;     cmp rax, rsi
    ;     jne .blah

    ;     .forEachGrp:

    ;         getNumQuestions
    ;         getNumPounds
    ;         groupSize
    ;         target_grp_size*2 + 1
    ;         cmp x, y
    ;         jne .waht

    ;     .endForEachGrp:

    ;     ; Okay, score it.

    ;     .forEaGrp:
    ;         mul score

    ;     .endForEaGrp:

    ;     ret

    ;     .Notf




    ;     .blah:

    ;     .end:
    ;         leave
    ;         ret

    ; ; End checkForShortSolution.



    ; ; void optimize(char* string, size_t* group_arr, size_t group_arr_len);
    ; ;
    ; ;
    ; ;
    ; optimize:
    ;     push rbp
    ;     mov rbp, rsp
    ;     push r12
    ;     push r13
    ;     push r14
    ;     push r15

    ;     mov r12, rdi                ; string.
    ;     mov r13, rsi                ; group_arr.
    ;     mov r14, rdx                ; group_arr_len.

    ;     call getNumGroups

    ;     mov r15, rax                ; num_grps.
    ;     mov rdi, r12

    ;     ; Detect case where (in order) a grp is less than target. This grp is 
    ;     ; all dots until a grp_len >= first tgt_grp.
    ;     .fillDots:
    ;         call getNextGroup

    ;         test rax, rax
    ;         jz .endFillDots

    ;         mov rdi, rax

    ;         ; Count grp_len.
    ;         xor rdx, rdx

    ;         ; Move to next group.
    ;         .scan:
    ;             cmp byte [rdi], '.'
    ;             je .endScan

    ;             cmp byte [rdi], ' '
    ;             je .endScan

    ;             inc rdi
    ;             inc rdx
    ;             jmp .scan

    ;         .endScan:

    ;         cmp rdx, [r13]
    ;         jl .dots
    ;         jmp .endFillDots

    ;         .dots:
    ;             test rdx, rdx
    ;             jz .endDots

    ;             mov rsi, rdi
    ;             sub rsi, rdx
    ;             mov byte [rsi], '.'
    ;             dec rdx
    ;             jmp .dots

    ;         .endDots:

    ;         jmp .fillDots

    ;     .endFillDots:

    ;     mov rdi, r12

    ;     ; Analyze groups.
    ;     xor rcx, rcx                ; curr_group_idx.
    ;     xor r8, r8                  ; curr_num_pounds.
    ;     xor r9, r9                  ; curr_num_questions.

    ;     .analyzeGrps:
    ;         push rcx
    ;         call getNextGroup

    ;         pop rcx
    ;         test rax, rax
    ;         jz .endAnalyzeGrps

    ;         mov rdi, rax

    ;         .analyzeGrp:
    ;             push rcx

    ;             .count:
    ;                 push rdi
    ;                 call countPoundsInGroup

    ;                 pop rdi
    ;                 mov r8, rax
                
    ;                 push rdi
    ;                 push r8
    ;                 call countQuestionsInGroup

    ;                 pop r8
    ;                 pop rdi
    ;                 mov r9, rax
    ;                 pop rcx

    ;         .endAnalyzeGrp:

    ;         push r9
    ;         push r8
    ;         push rcx
            
    ;         ; Move out of group.
    ;         inc rcx

    ;         .scan:
    ;             cmp byte [rdi], '.'
    ;             je .endScan

    ;             cmp byte [rdi], ' '
    ;             je .endScan

    ;             inc rdi
    ;             jmp .scan

    ;         .endScan:
    ;             jmp .analyzeGrps

    ;     .endAnalyzeGrps:

    ;     ; rcx = num_grps.
    ;     ; each grp no on stack followed by no#, no?.

    ;     ; Detect case where there is one group and all ?s.
    ;     ; This case is math solvable.
    ;     cmp rcx, 1
    ;     je .oneGrp

    ;     .oneGrp:
    ;         pop rcx
    ;         pop 


    ;     ; Detect case where num_grps = num_targ and each grp is only questions 
    ;     ; and each grp_len <= target*2 + 1.
    ;     ; If true, case is math solvable, with cases_1 * cases_2 ...


    ;     ; Detect case where num_grps = num_targ and each grp_len <= 
    ;     ; target*2 + 1. Then any grp that is equal to target is all #s.


        


    ;     ; Detect case where (in order) a grp is equal to target, This grp is 
    ;     ; all #s if no other grp is that large.

            

    ;     ; Check if groups = grp_arr_len.
    ;             cmp r15, r14
    ;             je .groupsEqual

    ;             .groupsEqual:
    ;                 test r8, r8
    ;                 jz .all?

    ;                 test r9, r9
    ;                 jz .all#

    ;                 .all?:
    ;                     cmp r9, [rsi + rcx*8]
    ;                     jg .greater?

    ;                     xor rdx, rdx
    ;                     push rdi

    ;                     .replace?:
    ;                         cmp rdx, r9
    ;                         je .endReplace?

    ;                         mov [rdi + rdx*8], '#'
    ;                         inc rdi
    ;                         jmp .replace?

    ;                     .endReplace?:
    ;                         pop rdi
    ;                         jmp .all#

    ;                     .greater?:
    ;                         ; Solve ways which should be muliplied by rest of ways.
    ;                         ; I can solve ways, but how to I track what to multiply with.
    ;                         ; For now, do nothing.
    ;                         jmp .all#

    ;                 .all#:
    ;                     ; Increment group_arr_idx.
    ;                     inc rcx

    ;             .endGroupsEqual:

    ;             .groupsNotEqual:
    ;                 .



    ;     ; Detect case where all symbols are consecutive '?'s.


    ;     ; Detect case where there is equal number of groups and breaks.

    ; ; End optimize.


    ; ; char* getNextGroup(char* string)
    ; ;
    ; ; @brief    Returns pointer to next group if there is one.
    ; ;
    ; ; @return   char*   Next group if one is found, else `NULL`.
    ; ;
    ; getNextGroup:
    ;     push rbp
    ;     mov rbp, rsp

    ;     .loopOfDeath:
    ;         cmp byte [rdi], '.'
    ;         je .onward

    ;         cmp byte [rdi], '#'
    ;         je .foundTheDonkey

    ;         cmp byte [rdi], '?'
    ;         je .foundTheDonkey
    ;         jmp .death

    ;         .onward:
    ;             inc rdi
    ;             jmp .loopOfDeath

    ;     .foundTheDonkey:
    ;         mov rax, rdi
    ;         jmp .end

    ;     .death:
    ;         xor rax, rax

    ;     .end:
    ;         leave
    ;         ret

    ; ; End getNextGroup.


    ; ; size_t countPoundsInGroup(char* string);
    ; ;
    ; ; @brief    Count '#'s in current group.
    ; ;
    ; ; @return   size_t  Number of pounds found.
    ; ;
    ; countPoundsInGroup:
    ;     push rbp
    ;     mov rbp, rsp

    ;     xor rax, rax

    ;     .loopOfLight:
    ;         cmp byte [rdi], '#'
    ;         je .foundLight

    ;         cmp byte [rdi], '?'
    ;         je .foundDarkness
    ;         jmp .end

    ;         .foundLight:
    ;             inc rax
                
    ;         .foundDarkness:
    ;             inc rdi
    ;             jmp .loopOfLight

    ;     .end:
    ;         leave
    ;         ret

    ; ; End countPoundsInGroup.


    ; ; size_t countQuestionsInGroup(char* string);
    ; ;
    ; ; @brief    Count '?'s in current group.
    ; ;
    ; ; @return   size_t  Number of questions found.
    ; ;
    ; countQuestionsInGroup:
    ;     push rbp
    ;     mov rbp, rsp

    ;     xor rax, rax

    ;     .loopOfLight:
    ;         cmp byte [rdi], '?'
    ;         je .foundLight

    ;         cmp byte [rdi], '#'
    ;         je .foundDarkness
    ;         jmp .end

    ;         .foundLight:
    ;             inc rax
                
    ;         .foundDarkness:
    ;             inc rdi
    ;             jmp .loopOfLight

    ;     .end:
    ;         leave
    ;         ret

    ; ; End countQuestionsInGroup.


    ; ; size_t getNumGroups(char* string);
    ; ;
    ; ; @brief    Returns the number of groups in string.
    ; ;
    ; ; @returns  size_t  Number of remaining groups in string.
    ; getNumGroups:
    ;     push rbp
    ;     mov rbp, rsp

    ;     xor rdx, rdx

    ;     .loop:
    ;         push rdx
    ;         call getNextGroup

    ;         pop rdx
    ;         test rax, rax
    ;         jz .end

    ;         mov rdi, rax
    ;         inc rdx

    ;         .scan:
    ;             cmp byte [rdi], '.'
    ;             je .endScan

    ;             cmp byte [rdi], ' '
    ;             je .endScan

    ;             inc rdi
    ;             jmp .scan

    ;         .endScan:
    ;             jmp .loop

    ;     .end:
    ;         leave
    ;         ret

    ; ; End getNumGroups.


; End of file.