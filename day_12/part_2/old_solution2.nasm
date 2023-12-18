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

struc memo

	.nxt:       resq    1
	.str_len:   resq    1
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

    head:   resq    1
    tail:   resq    1


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

        ; Need memo head/tail.
        mov qword [head], 0
        mov qword [tail], 0

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

            mov rdi, r13
            mov rsi, r14
            mov rdx, r13
            call optimize

            mov rdi, r13
            mov rsi, r14
            mov rdx, r15
            xor rcx, rcx
            mov ch, '.'
            mov cl, '.'
            xor r8, r8
            xor r9, r9
            call dynamicSolution

            add rbx, rax

            ; Deallocate array.
            ; lea rdi, [r15*8]
            ; call memDealloc

            ; test rax, rax
            ; js .err

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

    ; Optimizations were worthless.
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
        push r12
        ; rdi = string.
        ; rsi = grp_arr.
        ; rdx = grp_arr_len.
        ; cl = curr_sym.
        ; ch = prev_sym.
        ; r8 = curr_grp_idx.
        ; r9 = curr_num_pds

        mov r10, [rsi + r8*8]       ; tgt_pds.
        xor rax, rax                ; ret.
        dec rdi
        lea r11, [rdx - 1]
        
        .checkSym:
            cmp byte cl, '.'
            je .dot

            cmp byte cl, '#'
            je .pound
            jmp .return0
        
        .checkLetter:
            ; If total ?s + #s left < total needed pounds, ret 0.
            ; This helped a little.
            ; If equal, ret 1, I think.
            xor r12, r12  ; count_remaining.
            push rdi

            .countRemaining:
                cmp byte [rdi], ' '
                je .endCountRemaining

                cmp byte [rdi], '.'
                je .dont

                inc r12

                .dont:
                    inc rdi
                    jmp .countRemaining

            .endCountRemaining:

            pop rdi

            push 0  ; count_needed.
            push r8
            push rax
            
            .countNeeded:
                cmp r8, rdx
                je .endCountNeeded

                mov rax, [rsi + r8*8]
                add [rsp + 16], rax
                inc r8
                jmp .countNeeded

            .endCountNeeded:

            pop rax
            pop r8
            sub [rsp], r9

            cmp r12, [rsp]
            jge .okay

            pop r12
            jmp .return0

            .okay:
            pop r12

            cmp byte [rdi], '.'
            je .dot

            cmp byte [rdi], '#'
            je .pound

            cmp byte [rdi], '?'
            je .question

            cmp r8, r11
            jne .return0

            cmp r9, r10
            jne .return0
            jmp .return1

        .question:
            
            ; Check memo.
            cmp ch, '.'
            jne .calc

            push rcx
            push rdi
            xor rcx, rcx
            .len:
                cmp byte [rdi], ' '
                je .endLen

                inc rcx
                inc rdi
                jmp .len

            .endLen:

            pop rdi
            cmp rcx, 25
            jle .chk

            pop rcx
            jmp .calc

            .chk:
            pop rcx

            push rdi
            push rsi
            push rdx
            push rcx
            push r8
            push r9
            push r10
            push r11

            mov rcx, rdx
            sub rcx, r8
            lea rdx, [rsi + r8*8]
            mov rsi, rdi
            mov rdi, head
            call checkMemo

            pop r11
            pop r10
            pop r9
            pop r8
            pop rcx
            pop rdx
            pop rsi
            pop rdi

            cmp rax, FUNC_FAILURE
            jne .end

            .calc:

            push rdi    ; Special.

            inc rdi
            push 0

            push rdi
            push rsi
            push rcx
            push rdx
            push r8
            push r9
            push r10
            push r11
            mov cl, '#'
            call dynamicSolution

            pop r11
            pop r10
            pop r9
            pop r8
            pop rdx
            pop rcx
            pop rsi
            pop rdi
            add [rsp], rax

            push rdi
            push rsi
            push rcx
            push rdx
            push r8
            push r9
            push r10
            push r11
            mov cl, '.'
            call dynamicSolution

            pop r11
            pop r10
            pop r9
            pop r8
            pop rdx
            pop rcx
            pop rsi
            pop rdi

            add [rsp], rax
            pop rax

            pop rdi     ; Special.

            ; Save memo if last character `.`.
            ; `-(^-^)-'  ~["="]~.
            cmp ch, '.'
            jne .end

            push rcx
            push rdi
            xor rcx, rcx
            .len1:
                cmp byte [rdi], ' '
                je .endLen1

                inc rcx
                inc rdi
                jmp .len1

            .endLen1:

            pop rdi

            cmp rcx, 25
            jle .chk1

            pop rcx
            jmp .end

            .chk1:
            pop rcx

            push rax
            inc r8
            
            push rdi
            push rsi
            push rdx
            push rcx
            push r8
            push r9
            push r10
            push r11

            mov rcx, rdx
            sub rcx, r8
            lea rdx, [rsi + r8*8]
            mov rsi, rdi
            mov rdi, head
            call checkMemo

            pop r11
            pop r10
            pop r9
            pop r8
            pop rcx
            pop rdx
            pop rsi
            pop rdi

            cmp rax, FUNC_FAILURE
            jne .headPresent

            lea rcx, [rsi + r8*8]
            mov rsi, rdi
            mov rdi, tail
            sub rdx, r8
            mov r8, rdx
            mov rdx, rax
            call createMemo

            cmp qword [head], 0
            jne .headPresent

            mov r10, [tail]
            mov [head], r10

            .headPresent:
                pop rax
                jmp .end

        .pound:
            inc r9
            cmp r9, r10
            jg .return0
            
            inc rdi
            mov ch, '#'
            jmp .checkLetter

        .dot:
            ; Regular algo.
            inc rdi
            cmp ch, '#'
            jne .checkLetter

            cmp r9, r10
            jne .return0

            cmp r8, r11
            je .last

            inc r8
            mov r10, [rsi + r8*8]
            xor r9, r9

            .last:
                mov ch, '.'

                ; If remaining groups are all equal to tgt_grp numbers, ret 1.
                push rdi
                push r8
                push r10

                .forGrps:
                    xor r12, r12

                    cmp r8, rdx
                    je .endForGrps

                    ; Move to group.
                    .move:
                        cmp byte [rdi], '.'
                        jne .endMove

                        inc rdi
                        jmp .move

                    .endMove:

                    ; Get number in group.
                    .grp:
                        cmp byte [rdi], '.'
                        je .endGrp

                        cmp byte [rdi], ' '
                        je .endGrp

                        inc r12
                        inc rdi
                        jmp .grp

                    .endGrp:

                    cmp r12, r10
                    jne .notEqGrp

                    inc r8
                    cmp r8, rdx
                    je .endForGrps
                    
                    mov r10, [rsi + r8*8]
                    jmp .forGrps

                .endForGrps:

                ; Move to end.
                .moveToEnd:
                    cmp byte [rdi], ' '
                    je .endMoveToEnd

                    cmp byte [rdi], '.'
                    jne .notEqGrp

                    inc rdi
                    jmp .moveToEnd

                .endMoveToEnd:
                    pop r12
                    pop r12
                    pop r12
                    jmp .return1

                .notEqGrp:
                    pop r10
                    pop r8
                    pop rdi

                ; If previous is a dot, you are in a new group.
                ; Check for magic math.
                push rax
                push rcx
                push rdx
                push rdi
                push rsi
                push r8
                push r9
                push r10
                push r11
                call getNumGroups

                pop r11
                pop r10
                pop r9
                pop r8
                pop rsi
                pop rdi
                pop rdx
                pop rcx
                pop rax

                cmp rax, 1
                jne .dp

                ; Last group. Check if all questions.
                push rdi
                push rcx

                xor rcx, rcx

                ; Move to end.
                .moveToEnd1:
                    cmp byte [rdi], ' '
                    je .endMoveToEnd1

                    cmp byte [rdi], '#'
                    je .notMagic

                    cmp byte [rdi], '?'
                    je .count?
                    jmp .dontCount?

                    .count?:
                        inc rcx

                    .dontCount?:
                        inc rdi
                        jmp .moveToEnd1

                .endMoveToEnd1:

                pop r12
                pop r12           

                mov rdi, rcx
                mov rcx, rdx
                mov rdx, rsi
                mov rsi, r8
                call secretMath
                jmp .end

                .notMagic:
                    pop rcx
                    pop rdi

                .dp:
                    jmp .checkLetter

        .return1:
            xor rax, rax
            inc rax

        .return0:            

        .end:
            pop r12
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


    ; size_t secretMath(
    ;       size_t num_questions, 
    ;       size_t curr_grp, 
    ;       size_t* grp_arr, 
    ;       size_t grp_arr_len
    ; );
    ;
    ; @brief    For last group with all `?`s, the total ways can be calculated 
    ;           with a really weird formula.
    ;
    ; @return   size_t  Number of ways. 
    secretMath:
        push rbp
        mov rbp, rsp

        mov r10, rsi        ; curr_grp.

        ; Count remaining targets; add 1 to all but last one.
        xor r8, r8          ; sum_tgts.
        lea r9, [rcx - 1]   ; last_grp.

        .loop:
            cmp rsi, rcx
            je .doneLoop

            add r8, [rdx + rsi*8]
            cmp rsi, r9
            je .skip

            inc r8

            .skip:
                inc rsi
                jmp .loop

        .doneLoop:

        ; Take num_question and subtract new number.
        sub rdi, r8

        ; Add 1.
        inc rdi

        ; If number is 0, ret 0.
        xor rax, rax
        test rdi, rdi
        jz .end

        ; If number is 1, ret 1 (1?n = 1).
        inc rax
        cmp rdi, 1
        je .end

        ; Need number of target groups left.
        sub rcx, r10
        test rcx, rcx        ; return 1 (shouldn't happen).
        je .end

        ; Decrement number.
        dec rcx

        ; Call magic.
        ; rdi already loaded.
        mov rsi, rcx
        call secretMathFunc        

        .end:
            leave
            ret

    ; End secretMath.


    ; size_t secretMathFunc(size_t a, size_t level);
    ;
    ; @brief    Calculates `a(?*level)` where ? is sum of `a sub i from 0 to 
    ;           a`. For example, `4?` = `4 + 3 + 2 + 1 + 0`.
    ;
    ;           `a?? = a? + (a-1)?...`.
    ;           `4(?3) = 4??? = 4?? + 3?? + 2?? + 1?? = (4? + 3? + 2? + 1?) + 
    ;           (3? + 2? + 1?) + (2? + 1?) + (1?) = 
    ;           (4+3+2+1)+(3+2+1)+(2+1)+(1) + (3+2+1)+(2+1)+(1) + (2+1)+(1) + (1) =
    ;           4*1 + 3*3 + 2*6 + 1*10 = 4*1 + 3*(1+2) + 2*(1+2+3) + 1*(1+2+3+4)
    ;
    ; @return   size_t  Sum.
    ;
    secretMathFunc:
        push rbp
        mov rbp, rsp

        test rsi, rsi
        jz .returnRDI

        xor rdx, rdx

        .loop:
            test rdi, rdi
            jz .done

            push rdx
            push rdi
            push rsi
            dec rsi            

            call secretMathFunc

            pop rsi
            pop rdi
            pop rdx
            add rdx, rax
            dec rdi
            jmp .loop

        .done:
            mov rax, rdx
            jmp .end

        .returnRDI:
            mov rax, rdi

        .end:
            leave
            ret

    ; End secretMathFunc.


    ; void optimize(char* string, size_t* group_arr, size_t group_arr_len);
    ;
    ; @brief    Fills in beginning questions with `.`s or `#`s if they 
    ;           cannot be otherwise. Improves performance slightly.
    ;
    optimize:
        push rbp
        mov rbp, rsp
        push r12
        push r13
        push r14
        push r15

        mov r12, rdi                ; string.
        mov r13, rsi                ; group_arr.
        mov r14, rdx                ; group_arr_len.

        call getNumGroups

        mov r15, rax                ; num_grps.
        mov rdi, r12

        ; Detect case where (in order) a grp is less than target. This grp is 
        ; all dots until a grp_len >= first tgt_grp.
        .fillDots:
            call getNextGroup

            test rax, rax
            jz .endFillDots

            mov rdi, rax

            ; Count grp_len.
            xor rdx, rdx
            xor r10, r10            ; hash_count.

            ; Move to next group.
            .scan:
                cmp byte [rdi], '.'
                je .endScan

                cmp byte [rdi], ' '
                je .endScan

                cmp byte [rdi], '#'
                jne .contScan

                inc r10

                .contScan:
                    inc rdi
                    inc rdx
                    jmp .scan

            .endScan:

            cmp rdx, [r13]
            jg .endFillDots

            cmp rdx, [r13]
            jl .dots

            ; Check for hashes.
            test r10, r10
            jz .endFillDots

            .hashes:
                test rdx, rdx
                jz .endDots

                mov rsi, rdi
                sub rsi, rdx
                mov byte [rsi], '#'
                dec rdx
                jmp .hashes


            .dots:
                test rdx, rdx
                jz .endDots

                mov rsi, rdi
                sub rsi, rdx
                mov byte [rsi], '.'
                dec rdx
                jmp .dots

            .endDots:

            jmp .fillDots

        .endFillDots:

        .end:
            pop r15
            pop r14
            pop r13
            pop r12
            leave
            ret

        ; End optimize.

        ; ; Analyze groups.
        ; xor rcx, rcx                ; curr_group_idx.
        ; xor r8, r8                  ; curr_num_pounds.
        ; xor r9, r9                  ; curr_num_questions.

        ; .analyzeGrps:
        ;     push rcx
        ;     call getNextGroup

        ;     pop rcx
        ;     test rax, rax
        ;     jz .endAnalyzeGrps

        ;     mov rdi, rax

        ;     .analyzeGrp:
        ;         push rcx

        ;         .count:
        ;             push rdi
        ;             call countPoundsInGroup

        ;             pop rdi
        ;             mov r8, rax
                
        ;             push rdi
        ;             push r8
        ;             call countQuestionsInGroup

        ;             pop r8
        ;             pop rdi
        ;             mov r9, rax
        ;             pop rcx

        ;     .endAnalyzeGrp:

        ;     push r9
        ;     push r8
        ;     push rcx
            
        ;     ; Move out of group.
        ;     inc rcx

        ;     .scan:
        ;         cmp byte [rdi], '.'
        ;         je .endScan

        ;         cmp byte [rdi], ' '
        ;         je .endScan

        ;         inc rdi
        ;         jmp .scan

        ;     .endScan:
        ;         jmp .analyzeGrps

        ; .endAnalyzeGrps:

        ; ; rcx = num_grps.
        ; ; each grp no on stack followed by no#, no?.

        ; ; Detect case where there is one group and all ?s.
        ; ; This case is math solvable.
        ; cmp rcx, 1
        ; je .oneGrp

        ; .oneGrp:
        ;     pop rcx
        ;     pop 


        ; ; Detect case where num_grps = num_targ and each grp is only questions 
        ; ; and each grp_len <= target*2 + 1.
        ; ; If true, case is math solvable, with cases_1 * cases_2 ...


        ; ; Detect case where num_grps = num_targ and each grp_len <= 
        ; ; target*2 + 1. Then any grp that is equal to target is all #s.


        


        ; ; Detect case where (in order) a grp is equal to target, This grp is 
        ; ; all #s if no other grp is that large.

            

        ; ; Check if groups = grp_arr_len.
        ;         cmp r15, r14
        ;         je .groupsEqual

        ;         .groupsEqual:
        ;             test r8, r8
        ;             jz .all?

        ;             test r9, r9
        ;             jz .all#

        ;             .all?:
        ;                 cmp r9, [rsi + rcx*8]
        ;                 jg .greater?

        ;                 xor rdx, rdx
        ;                 push rdi

        ;                 .replace?:
        ;                     cmp rdx, r9
        ;                     je .endReplace?

        ;                     mov [rdi + rdx*8], '#'
        ;                     inc rdi
        ;                     jmp .replace?

        ;                 .endReplace?:
        ;                     pop rdi
        ;                     jmp .all#

        ;                 .greater?:
        ;                     ; Solve ways which should be muliplied by rest of ways.
        ;                     ; I can solve ways, but how to I track what to multiply with.
        ;                     ; For now, do nothing.
        ;                     jmp .all#

        ;             .all#:
        ;                 ; Increment group_arr_idx.
        ;                 inc rcx

        ;         .endGroupsEqual:

        ;         .groupsNotEqual:
        ;             .



        ; Detect case where all symbols are consecutive '?'s.


        ; Detect case where there is equal number of groups and breaks.

    ; End optimize.


    ; char* getNextGroup(char* string)
    ;
    ; @brief    Returns pointer to next group if there is one.
    ;
    ; @return   char*   Next group if one is found, else `NULL`.
    ;
    getNextGroup:
        push rbp
        mov rbp, rsp

        .loopOfDeath:
            cmp byte [rdi], '.'
            je .onward

            cmp byte [rdi], '#'
            je .foundTheDonkey

            cmp byte [rdi], '?'
            je .foundTheDonkey
            jmp .death

            .onward:
                inc rdi
                jmp .loopOfDeath

        .foundTheDonkey:
            mov rax, rdi
            jmp .end

        .death:
            xor rax, rax

        .end:
            leave
            ret

    ; End getNextGroup.


    ; size_t countPoundsInGroup(char* string);
    ;
    ; @brief    Count '#'s in current group.
    ;
    ; @return   size_t  Number of pounds found.
    ;
    countPoundsInGroup:
        push rbp
        mov rbp, rsp

        xor rax, rax

        .loopOfLight:
            cmp byte [rdi], '#'
            je .foundLight

            cmp byte [rdi], '?'
            je .foundDarkness
            jmp .end

            .foundLight:
                inc rax
                
            .foundDarkness:
                inc rdi
                jmp .loopOfLight

        .end:
            leave
            ret

    ; End countPoundsInGroup.


    ; size_t countQuestionsInGroup(char* string);
    ;
    ; @brief    Count '?'s in current group.
    ;
    ; @return   size_t  Number of questions found.
    ;
    countQuestionsInGroup:
        push rbp
        mov rbp, rsp

        xor rax, rax

        .loopOfLight:
            cmp byte [rdi], '?'
            je .foundLight

            cmp byte [rdi], '#'
            je .foundDarkness
            jmp .end

            .foundLight:
                inc rax
                
            .foundDarkness:
                inc rdi
                jmp .loopOfLight

        .end:
            leave
            ret

    ; End countQuestionsInGroup.


    ; size_t getNumGroups(char* string);
    ;
    ; @brief    Returns the number of groups in string.
    ;
    ; @returns  size_t  Number of remaining groups in string.
    getNumGroups:
        push rbp
        mov rbp, rsp

        xor rdx, rdx

        .loop:
            push rdx
            call getNextGroup

            pop rdx
            test rax, rax
            jz .end

            mov rdi, rax
            inc rdx

            .scan:
                cmp byte [rdi], '.'
                je .endScan

                cmp byte [rdi], ' '
                je .endScan

                inc rdi
                jmp .scan

            .endScan:
                jmp .loop

        .end:
            mov rax, rdx
            leave
            ret

    ; End getNumGroups.


    ; void createMemo(
    ;   memo* tail, 
    ;   char* string, 
    ;   size_t val, 
    ;   size_t* grps, 
    ;   size_t grps_len
    ; );
    ;
    ; @brief    Create memo entry with known value.
    ;
    createMemo:
        push rbp
        mov rbp, rsp

        cmp byte [rsi], ' '
        je .end

        ; Allocate memory.
        push rdi
        push rsi
        push rdx
        push rcx

        xor rcx, rcx
        .len:
            cmp byte [rsi], ' '
            je .endLen

            inc rcx
            inc rsi
            jmp .len

        .endLen:

        push rcx
        mov rdi, rcx
        add rdi, memo_size
        call memAlloc

        pop r10              ; str_len.
        pop rcx
        pop rdx
        pop rsi
        pop rdi

        cmp qword [rdi], 0
        jz .over

        mov r11, [rdi]
        mov [r11 + memo.nxt], rax
        
        .over:

        mov [rdi], rax
        mov qword [rax + memo.nxt], 0
        mov [rax + memo.str_len], r10
        mov [rax + memo.val], rdx
        mov [rax + memo.grps], rcx
        mov [rax + memo.grps_len], r8
        ; Strcpy.
        mov rcx, r10
        lea rdi, [rax + memo.str]
        cld
        rep movsb
        mov byte [rdi], 0

        .end:
            leave
            ret

    ; End createMemo.


    ; size_t checkMemo(
    ;   memo* head, 
    ;   char* string, 
    ;   size_t* grps, 
    ;   size_t grps_len
    ; );
    ;
    ; @brief    Check list for copy of string, then return value if found.
    ;           Otherwise return -1.
    ;
    ; @return   Return value if found; otherwise, return -1.
    checkMemo:
        push rbp
        mov rbp, rsp

        cmp qword [rdi], 0
        je .notFound

        cmp byte [rsi], ' '
        je .notFound

        mov r9, rcx

        push rdi
        push rsi
        push r8
        push r9

        xor rcx, rcx
        .len:
            cmp byte [rsi], ' '
            je .endLen

            inc rcx
            inc rsi
            jmp .len

        .endLen:

        pop r9
        pop r8
        pop rsi
        pop rdi

        mov rdi, [rdi]

        .loop:
            test rdi, rdi
            je .notFound

            cmp rcx, [rdi + memo.str_len]
            jne .cont

            mov r11, rcx
            
            ; Compare groups.
            cmp r9, [rdi + memo.grps_len]
            jne .notFound

            xor rcx, rcx

            .groups:
                cmp rcx, r9
                je .endGroups

                mov r10, [rdi + memo.grps]
                mov r10, [r10 + rcx*8]
                cmp r10, [rdx + rcx*8]
                jne .notFound

                inc rcx
                jmp .groups

            .endGroups:

            ; Strcmp.
            push rdi
            mov rcx, r11
            lea rdi, [rdi + memo.str] 
            cld
            repe cmpsb

            pop rdi
            test rcx, rcx
            je .retVal

            .cont:
                mov rdi, [rdi + memo.nxt]
                jmp .loop

        .retVal:
            mov rax, [rdi + memo.val]
            jmp .end

        .notFound:
            or rax, FUNC_FAILURE

        .end:
            leave
            ret

    ; End checkMemo.


; End of file.