;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Advent of Code Christmas Challenge Day 19 - Part II
;
; @brief    Sum the attributes of all the accepted parts as determined by 
;           sending them through a acceptance workflow determined by the 
;           given instructions.
;
;           Now, they want to find the total number of combinations that will 
;           be accepted for values for `x`, `m`, `a`, and `s` from ranges of 
;           1 to 4000. 
;
; @file         solution.nasm
; @date         29 Dec 2023
; @author       upsetrobot
; @copyright    Copyright (c) 2023
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Thoughts:
;
; This sounds easy, but trying 256 trillion combinations will probably take a 
; long time (guess it may be worth a shot, but even counting that high takes 
; forever; I ran just a counting test in C and it took about 2 seconds to get 
; to each billion (with one increment and one if per cycle and one print per 
; billion) so 256 trillion would take longer (probably much longer due to 
; memory reads and writes and logic) than 256000*2 seconds which is like 141 
; hours per case). 
;
; So, what is a better way. Well, since the checks are based on ranges, that 
; makes things simpler somehow I'm sure.
;
; I was thinking you could just try 4000 combos for each variable at one time 
; while swapping the other variables between combinations of 1 and 4000, but 
; I think that will miss cases where a second variable should be inbetween 
; two ranges (more than one value but less than other value).
;
; Side note, I feel like I should have used the stack to hold the operations 
; rather than parsing them into a structure. 
;
; The splits seem to form a weird kinda tree (not binary), so recursion may be 
; possible to explore all outcomes.
;
; Maybe I can work backwards from the `A`s since those are the target?
;
; Actually, it can be modeled as a binary tree if you think of the operations 
; rather than the rules (the labels are just links to additional trees and 
; each rule has multiple leaves, but each split is binary, although now that 
; I think about it, I guess all data models can be binary (complex cases are 
; just more branches of binary splits; I probably should know that already)).
;
; Maybe I could start with the 256 trillion or whatever and every branch 
; subtract that amount, and subtract the other amount (so to sets: one for 
; less than and one for greater than (and accounting for the equals), then 
; do it again at the next branch, then when I arrive at an `A`, I will have 
; the number of ways it took to get there. I think I would just take the max 
; of the other ways to get to an `A` which is actually wrong I think because 
; some of the cases may arrive at more than one `A`...Ugh. ... Actually, you 
; would have to only subtract once from the total to get a new total at each 
; branch; I just did a sample on paper and this method would work, you would 
; just add all the cases that result in `A` as you traverse the tree. 
;
; To implement the above solution would need a recursive function that returns 
; 0 if ending on rejected and return number of ways for that subset if arrived 
; a A. It actually feels like a pain to me without building a tree in advance 
; but I feel like I don't need to. If I did it iteratively, I would have to 
; track which direction I went and then run it again changing one direction 
; at a time. Sounds like I am going to try to figure out the recurse solution 
; with a location (rule and group number) and access to the rule array and 
; current number of ways and then sum ways going down each branch. 
; 
; Okay, I ran into problems with multipliers, but I can simplify this if I can 
; just know how many of each var end up at the bottom on a `A` because, they 
; can just be multiplied together. The only tricky part is when a var comes up 
; more than once, you have to account for that. In that case, it sounds like 
; it is easier just to track a min and max for each var and then get the 
; difference at the bottom of the tree, then just multiply the diffs 
; together and you have the number for that branch. This method could have 
; been iterative just fine, but I already converted everything to recursive 
; so, yeah. I will just use globals, I think.
;

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

%define MIN_OPERAND 1
%define MAX_OPERAND 4000


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
        mov rsi, FALSE
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
            jne .parseRule
            jmp .endWhile

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

            .endParse:    
                mov rdi, rsi
                jmp .while

        .endWhile:
            ; Execute instructions.
            xor rax, rax                ; rule_idx.
            mov rdi, r8                 ; curr_rule.
            mov r15, "in"               ; curr_lbl.

            .findRule:
                cmp rax, r9
                je .foundRule

                cmp dword [rdi + rule.lbl], r15d
                je .foundRule

                inc rax
                add rdi, rule_size
                jmp .findRule

            .foundRule:

            mov rsi, r9
            lea rdx, [rdi + rule.op1]
            mov rdi, r8
            push qword MIN_OPERAND
            push qword MAX_OPERAND
            push qword MIN_OPERAND
            push qword MAX_OPERAND
            push qword MIN_OPERAND
            push qword MAX_OPERAND
            push qword MIN_OPERAND
            push qword MAX_OPERAND
            call recurseFindTotal

            add rsp, 0x40           
        
        .end:
            pop r15
            pop r14
            pop r13
            pop r12
            leave
            ret

    ; End getSolution.


    ; size_t recurseFindTotal(
    ;   rule* rule_arr, 
    ;   size_t rule_arr_len,
    ;   op* operation,
    ;   stack x_min,    rbp + 0x48
    ;   stack x_max,    rbp + 0x40
    ;   stack m_min,    rbp + 0x38
    ;   stack m_max,    rbp + 0x30
    ;   stack a_min,    rbp + 0x28
    ;   stack a_max,    rbp + 0x20
    ;   stack s_min,    rbp + 0x18
    ;   stack s_max,    rbp + 0x10
    ;)
    ;
    ; @brief    Execute branching with each cmp and return total number of 
    ;           cases based on comparasion numbers.
    ;
    ; @return   size_t  Total number of cases that arrive as accepted.
    ;
    recurseFindTotal:
        push rbp
        mov rbp, rsp
        push r12

        xor r12, r12                        ; sum.

        .top:

        cmp dword [rdx + op.op], NULL
        je .checkLabel

        cmp dword [rdx + op.op], '<'
        je .less

        cmp dword [rdx + op.op], '>'
        je .greater

        int3

        .checkLabel:
            cmp dword [rdx + op.result], 'A'
            je .accepted

            cmp dword [rdx + op.result], 'R'
            je .rejected

            mov r8d, [rdx + op.result]
            xor r9, r9
            xor rcx, rcx

            .findNextOp:
                cmp rcx, rsi
                je .endFindNextOp

                cmp [rdi + r9 + rule.lbl], r8d
                je .endFindNextOp

                inc rcx
                add r9, rule_size
                jmp .findNextOp

            .endFindNextOp:
                lea rdx, [rdi + r9 + rule.op1]
                jmp .top

            .accepted:
                mov rax, [rbp + 0x40]
                sub rax, [rbp + 0x48]
                inc rax

                mov rcx, [rbp + 0x30]
                sub rcx, [rbp + 0x38]
                inc rcx

                mul rcx

                mov rcx, [rbp + 0x20]
                sub rcx, [rbp + 0x28]
                inc rcx

                mul rcx

                mov rcx, [rbp + 0x10]
                sub rcx, [rbp + 0x18]
                inc rcx

                mul rcx
                jmp .end

            .rejected:
                xor rax, rax
                jmp .end

        .less:
            .less.true:
                mov r8d, [rdx + op.operand1]
                mov r9d, [rdx + op.operand2]
                dec r9
                push rdx

                cmp r8, 'x'
                je .less.true.x

                cmp r8, 'm'
                je .less.true.m

                cmp r8, 'a'
                je .less.true.a

                cmp r8, 's'
                je .less.true.s

                int3

                .less.true.x:
                    push qword [rbp + 0x48]
                    push qword r9
                    push qword [rbp + 0x38]
                    push qword [rbp + 0x30]
                    push qword [rbp + 0x28]
                    push qword [rbp + 0x20]
                    push qword [rbp + 0x18]
                    push qword [rbp + 0x10]
                    jmp .less.true.recurse

                .less.true.m:
                    push qword [rbp + 0x48]
                    push qword [rbp + 0x40]
                    push qword [rbp + 0x38]
                    push qword r9
                    push qword [rbp + 0x28]
                    push qword [rbp + 0x20]
                    push qword [rbp + 0x18]
                    push qword [rbp + 0x10]
                    jmp .less.true.recurse

                .less.true.a:
                    push qword [rbp + 0x48]
                    push qword [rbp + 0x40]
                    push qword [rbp + 0x38]
                    push qword [rbp + 0x30]
                    push qword [rbp + 0x28]
                    push qword r9
                    push qword [rbp + 0x18]
                    push qword [rbp + 0x10]
                    jmp .less.true.recurse

                .less.true.s:
                    push qword [rbp + 0x48]
                    push qword [rbp + 0x40]
                    push qword [rbp + 0x38]
                    push qword [rbp + 0x30]
                    push qword [rbp + 0x28]
                    push qword [rbp + 0x20]
                    push qword [rbp + 0x18]
                    push qword r9

                .less.true.recurse:
                    mov r8d, [rdx + op.result]
                    cmp r8, 'A'
                    jne .less.true.rejected

                    mov rax, [rsp + 0x30]
                    sub rax, [rsp + 0x38]
                    inc rax

                    mov rcx, [rsp + 0x20]
                    sub rcx, [rsp + 0x28]
                    inc rcx

                    mul rcx

                    mov rcx, [rsp + 0x10]
                    sub rcx, [rsp + 0x18]
                    inc rcx

                    mul rcx

                    mov rcx, [rsp]
                    sub rcx, [rsp + 0x8]
                    inc rcx

                    mul rcx

                    add rsp, 0x40
                    pop rdx
                    add r12, rax
                    jmp .less.false

                    .less.true.rejected:
                        cmp r8, 'R'
                        jne .less.true.label

                        add rsp, 0x40
                        pop rdx
                        jmp .less.false
                    
                    .less.true.label:
                        xor r9, r9
                        xor rcx, rcx

                    .less.true.findResult:
                        cmp rcx, rsi
                        je .less.true.endfindResult

                        cmp [rdi + r9 + rule.lbl], r8d
                        je .less.true.endfindResult

                        inc rcx
                        add r9, rule_size
                        jmp .less.true.findResult

                    .less.true.endfindResult:
                        lea rdx, [rdi + r9 + rule.op1]

                    call recurseFindTotal

                    add rsp, 0x40
                    pop rdx
                    add r12, rax

            .less.false:
                .less.false:
                mov r8d, [rdx + op.operand1]
                mov r9d, [rdx + op.operand2]

                cmp r8, 'x'
                je .less.false.x

                cmp r8, 'm'
                je .less.false.m

                cmp r8, 'a'
                je .less.false.a

                cmp r8, 's'
                je .less.false.s

                int3

                .less.false.x:
                    push qword r9
                    push qword [rbp + 0x40]
                    push qword [rbp + 0x38]
                    push qword [rbp + 0x30]
                    push qword [rbp + 0x28]
                    push qword [rbp + 0x20]
                    push qword [rbp + 0x18]
                    push qword [rbp + 0x10]
                    jmp .less.false.recurse

                .less.false.m:
                    push qword [rbp + 0x48]
                    push qword [rbp + 0x40]
                    push qword r9
                    push qword [rbp + 0x30]
                    push qword [rbp + 0x28]
                    push qword [rbp + 0x20]
                    push qword [rbp + 0x18]
                    push qword [rbp + 0x10]
                    jmp .less.false.recurse

                .less.false.a:
                    push qword [rbp + 0x48]
                    push qword [rbp + 0x40]
                    push qword [rbp + 0x38]
                    push qword [rbp + 0x30]
                    push qword r9
                    push qword [rbp + 0x20]
                    push qword [rbp + 0x18]
                    push qword [rbp + 0x10]
                    jmp .less.false.recurse

                .less.false.s:
                    push qword [rbp + 0x48]
                    push qword [rbp + 0x40]
                    push qword [rbp + 0x38]
                    push qword [rbp + 0x30]
                    push qword [rbp + 0x28]
                    push qword [rbp + 0x20]
                    push qword r9
                    push qword [rbp + 0x10]

                .less.false.recurse:
                    add rdx, op_size
                    call recurseFindTotal

                    add rsp, 0x40
                    add r12, rax
                    mov rax, r12
                    jmp .end

        .greater:
            .greater.true:
                mov r8d, [rdx + op.operand1]
                mov r9d, [rdx + op.operand2]
                inc r9
                push rdx

                cmp r8, 'x'
                je .greater.true.x

                cmp r8, 'm'
                je .greater.true.m

                cmp r8, 'a'
                je .greater.true.a

                cmp r8, 's'
                je .greater.true.s

                int3

                .greater.true.x:
                    push qword r9
                    push qword [rbp + 0x40]
                    push qword [rbp + 0x38]
                    push qword [rbp + 0x30]
                    push qword [rbp + 0x28]
                    push qword [rbp + 0x20]
                    push qword [rbp + 0x18]
                    push qword [rbp + 0x10]
                    jmp .greater.true.recurse

                .greater.true.m:
                    push qword [rbp + 0x48]
                    push qword [rbp + 0x40]
                    push qword r9
                    push qword [rbp + 0x30]
                    push qword [rbp + 0x28]
                    push qword [rbp + 0x20]
                    push qword [rbp + 0x18]
                    push qword [rbp + 0x10]
                    jmp .greater.true.recurse

                .greater.true.a:
                    push qword [rbp + 0x48]
                    push qword [rbp + 0x40]
                    push qword [rbp + 0x38]
                    push qword [rbp + 0x30]
                    push qword r9
                    push qword [rbp + 0x20]
                    push qword [rbp + 0x18]
                    push qword [rbp + 0x10]
                    jmp .greater.true.recurse

                .greater.true.s:
                    push qword [rbp + 0x48]
                    push qword [rbp + 0x40]
                    push qword [rbp + 0x38]
                    push qword [rbp + 0x30]
                    push qword [rbp + 0x28]
                    push qword [rbp + 0x20]
                    push qword r9
                    push qword [rbp + 0x10]

                .greater.true.recurse:
                    mov r8d, [rdx + op.result]
                    cmp r8, 'A'
                    jne .greater.true.rejected

                    mov rax, [rsp + 0x30]
                    sub rax, [rsp + 0x38]
                    inc rax

                    mov rcx, [rsp + 0x20]
                    sub rcx, [rsp + 0x28]
                    inc rcx

                    mul rcx

                    mov rcx, [rsp + 0x10]
                    sub rcx, [rsp + 0x18]
                    inc rcx

                    mul rcx

                    mov rcx, [rsp]
                    sub rcx, [rsp + 0x8]
                    inc rcx

                    mul rcx

                    add rsp, 0x40
                    pop rdx
                    add r12, rax
                    jmp .greater.false

                    .greater.true.rejected:
                        cmp r8, 'R'
                        jne .greater.true.label

                        add rsp, 0x40
                        pop rdx
                        jmp .greater.false
                    
                    .greater.true.label:
                        xor r9, r9
                        xor rcx, rcx

                    .greater.true.findResult:
                        cmp rcx, rsi
                        je .greater.true.endfindResult

                        cmp [rdi + r9 + rule.lbl], r8d
                        je .greater.true.endfindResult

                        inc rcx
                        add r9, rule_size
                        jmp .greater.true.findResult

                    .greater.true.endfindResult:
                        lea rdx, [rdi + r9 + rule.op1]

                    call recurseFindTotal

                    add rsp, 0x40
                    pop rdx
                    add r12, rax

            .greater.false:
                .greater.false:
                mov r8d, [rdx + op.operand1]
                mov r9d, [rdx + op.operand2]

                cmp r8, 'x'
                je .greater.false.x

                cmp r8, 'm'
                je .greater.false.m

                cmp r8, 'a'
                je .greater.false.a

                cmp r8, 's'
                je .greater.false.s

                int3

                .greater.false.x:
                    push qword [rbp + 0x48]
                    push qword r9
                    push qword [rbp + 0x38]
                    push qword [rbp + 0x30]
                    push qword [rbp + 0x28]
                    push qword [rbp + 0x20]
                    push qword [rbp + 0x18]
                    push qword [rbp + 0x10]
                    jmp .greater.false.recurse

                .greater.false.m:
                    push qword [rbp + 0x48]
                    push qword [rbp + 0x40]
                    push qword [rbp + 0x38]
                    push qword r9
                    push qword [rbp + 0x28]
                    push qword [rbp + 0x20]
                    push qword [rbp + 0x18]
                    push qword [rbp + 0x10]
                    jmp .greater.false.recurse

                .greater.false.a:
                    push qword [rbp + 0x48]
                    push qword [rbp + 0x40]
                    push qword [rbp + 0x38]
                    push qword [rbp + 0x30]
                    push qword [rbp + 0x28]
                    push qword r9
                    push qword [rbp + 0x18]
                    push qword [rbp + 0x10]
                    jmp .greater.false.recurse

                .greater.false.s:
                    push qword [rbp + 0x48]
                    push qword [rbp + 0x40]
                    push qword [rbp + 0x38]
                    push qword [rbp + 0x30]
                    push qword [rbp + 0x28]
                    push qword [rbp + 0x20]
                    push qword [rbp + 0x18]
                    push qword r9

                .greater.false.recurse:
                    add rdx, op_size
                    call recurseFindTotal

                    add rsp, 0x40
                    add r12, rax
                    mov rax, r12

        .end:
            pop r12
            leave
            ret

    ; End recurseFindTotal.



; End of file.