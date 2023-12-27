;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Advent of Code Christmas Challenge Day 17 - Part I
;
; @brief    Find the minimum sum of the digits along the path from the top 
;           right to bottom left while only being able to move 3 consecutive 
;           step in one direction at most at one time.
;
;           I found three solutions that work on the smaller dataset but not 
;           on the larger one. So, I am gonna start over.
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

        ; I feel like this should be a shortest path problem. 
        ; I also feel that there are a limited number of path option with 
        ; every move, so you could possibly do a 'choose next lowest' thing.
        ; The issue there is that a cheaper path may be ahead of a short 
        ; path that is higher than the lowest short path.

        ; Sounds like its best to do graph shortest path. So I guess we are 
        ; gonna have to build a graph (unless we can use the input as the 
        ; graph in some way). This is gonna be a pain.
        ; Actually, due to the weird rules and the fact that you dont want to 
        ; revisit nodes, we can just make a custom recursive algorithm.

        ; ... Still too slow, need to know if a node where are visiting has a 
        ; shorter path to source, so we can not hit it more than once. So, we 
        ; can use an array with values for shortest path to each point. if we 
        ; are less than a visited node, then we update the list. 
        ; Actually, this may need some change from my approach as this is 
        ; starting to sound more like shortest path to all nodes approach. 
        ; Hmmmm, just gotta figure out the array thing (which ends being a 
        ; variation of memoization with dynamic programming I think). If we 
        ; have not visited, update the list and continue. If we have, check 
        ; the list, if new path is shorter, update the list and continue; if 
        ; not, go back. Not sure if that will work as intended, but let's try 
        ; that.

        xor rcx, rcx
        not rcx
        mov al, NEWLINE
        push rdi
        cld
        repne scasb
        pop rdi
        not rcx
        mov r12, rcx                    ; line_len.

        ; Need to get bottom_right.
        push rdi

        .loop:
            cmp byte [rdi], NULL
            je .endLoop

            inc rdi
            jmp .loop

        .endLoop:
            mov r14, rdi                ; bottom_right.
            pop rdi

        ; Allocate arr.
        push rdi
        mov rsi, r14
        sub rsi, rdi
        mov r13, rsi                    ; arr_len.
        lea rdi, [rsi*8]
        call memAlloc

        pop rdi
        mov rbx, rax                    ; arr.

        ; Fill. Make all values max.
        push rdi
        mov rdi, rbx
        lea rcx, [r13*8]

        .fill:
            mov byte [rdi], -1
            inc rdi
            loop .fill

        pop rdi

        ; Take min of going right and going down.
        mov r10, rdi
        mov r11, r14
        xor r15, r15
        not r15                         ; curr_shortest_path.

        lea rdi, [rdi]
        mov rsi, r12
        xor rdx, rdx
        lea rcx, [r14 - 1]
        mov r8, RIGHT
        xor r9, r9
        inc rdi
        call findPath

        mov r10, rdi
        mov r11, r14
        ; xor r15, r15
        ; not r15                         ; curr_shortest_path.

        lea rdi, [rdi]
        mov rsi, r12
        xor rdx, rdx
        lea rcx, [r14 - 1]
        mov r8, DOWN
        xor r9, r9
        inc rdi
        call findPath

        mov rax, r15

        .end:
            pop rbx
            pop r15
            pop r14
            pop r13
            pop r12
            leave
            ret

    ; End getSolution.


    ; size_t findPath(
    ;   char* pos, 
    ;   size_t line_len,
    ;   size_t path_len,
    ;   char* target,
    ;   char dir,
    ;   char steps,
    ;   char* top_left,
    ;   char* bottom_right,
    ; );
    ;
    ; @brief    Find the shortest path to lower-right corner.
    ;
    ; @return   size_t  Length of place or FUNC_FAILURE if err.
    ;
    findPath:
        push rbp
        mov rbp, rsp
        push r12

        ; r10 = top_left.
        ; r11 = bottom_right.
        ; r13 = arr_len.
        ; r15 = curr_shortest_path.
        ; rbx = arr.

        cmp rdx, r15
        ja .err

        mov r12, -1                         ; shortest path.
        
        cmp rdi, rcx
        je .foundTarget
        
        ; Check for out of bounds.
        cmp rdi, r10
        jl .err

        cmp rdi, r11
        jge .err

        cmp byte [rdi], NEWLINE
        je .err

        ; You get three ways to go, but they depend on the direction you are 
        ; going. Also need to check if node has been visited before.

        ; Okay, if it has been visited before, check the array and update the 
        ; value if new path is shorter. If not visited, update the list.

        ; Actually, make every node path really high, then when visiting it,
        ; if lower, update it. That way, my "visit" to prevent running into 
        ; yourself isn't messed up. So, that takes care of updating. So, 
        ; before updating, we need to check the value and if it is lower, 
        ; then we return failure I think because there is a shorter path to 
        ; this point from source.

        ; Check list.
        ; Add current value to path.
        xor rax, rax
        mov al, byte [rdi]
        sub al, '0'
        add rdx, rax

        mov rax, rdi
        sub rax, r10                        ; index.
        cmp rdx, [rbx + rax*8]              ; Treating equal paths as equal?
        ja .err

        ; Update list.
        mov [rbx + rax*8], rdx

        ; Not sure what is going to be messed up, but now check if we have 
        ; been to this point during this traversal. This may not be needed 
        ; anymore.
        cmp byte [rdi], VISITED
        jle .err
        
        sub byte [rdi], VISIT

        cmp r8, LEFT
        je .fromRight

        cmp r8, RIGHT
        je .fromLeft

        cmp r8, UP
        je .fromBelow

        cmp r8, DOWN
        je .fromAbove

        .fromLeft:
            cmp r9, MAX_STEPS
            je .fromLeftUp

            .fromLeftRight:
                push rdi
                push rdx
                push r8
                inc rdi
                mov r8, RIGHT
                inc r9
                call findPath

                pop r8
                pop rdx
                pop rdi
                cmp rax, r12
                jae .fromLeftUp

                mov r12, rax

            .fromLeftUp:
                push rdi
                push rdx
                push r8
                sub rdi, rsi
                mov r8, UP
                xor r9, r9
                call findPath

                pop r8
                pop rdx
                pop rdi
                cmp rax, r12
                jae .fromLeftDown

                mov r12, rax

            .fromLeftDown:
                push rdi
                push rdx
                push r8
                add rdi, rsi
                mov r8, DOWN
                xor r9, r9
                call findPath

                pop r8
                pop rdx
                pop rdi
                cmp rax, r12
                jae .doneLeft

                mov r12, rax

            .doneLeft:
                mov rax, r12
                jmp .unvisit

        .fromRight:
            cmp r9, MAX_STEPS
            je .fromRightUp

            .fromRightLeft:
                push rdi
                push rdx
                push r8
                dec rdi
                mov r8, LEFT
                inc r9
                call findPath

                pop r8
                pop rdx
                pop rdi
                cmp rax, r12
                jae .fromRightUp

                mov r12, rax

            .fromRightUp:
                push rdi
                push rdx
                push r8
                sub rdi, rsi
                mov r8, UP
                xor r9, r9
                call findPath

                pop r8
                pop rdx
                pop rdi
                cmp rax, r12
                jae .fromRightDown

                mov r12, rax

            .fromRightDown:
                push rdi
                push rdx
                push r8
                add rdi, rsi
                mov r8, DOWN
                xor r9, r9
                call findPath

                pop r8
                pop rdx
                pop rdi
                cmp rax, r12
                jae .doneRight

                mov r12, rax

            .doneRight:
                mov rax, r12
                jmp .unvisit

        .fromBelow:
            cmp r9, MAX_STEPS
            je .fromBelowLeft

            .fromBelowUp:
                push rdi
                push rdx
                push r8
                sub rdi, rsi
                mov r8, UP
                inc r9
                call findPath

                pop r8
                pop rdx
                pop rdi
                cmp rax, r12
                jae .fromBelowLeft

                mov r12, rax            

            .fromBelowLeft:
                push rdi
                push rdx
                push r8
                dec rdi
                mov r8, LEFT
                xor r9, r9
                call findPath

                pop r8
                pop rdx
                pop rdi
                cmp rax, r12
                jae .fromBelowRight

                mov r12, rax

            .fromBelowRight:
                push rdi
                push rdx
                push r8
                inc rdi
                mov r8, RIGHT
                xor r9, r9
                call findPath

                pop r8
                pop rdx
                pop rdi
                cmp rax, r12
                jae .doneBelow

                mov r12, rax

            .doneBelow:
                mov rax, r12
                jmp .unvisit

        .fromAbove:
            cmp r9, MAX_STEPS
            je .fromAboveLeft

            .fromAboveDown:
                push rdi
                push rdx
                push r8
                add rdi, rsi
                mov r8, DOWN
                inc r9
                call findPath

                pop r8
                pop rdx
                pop rdi
                cmp rax, r12
                jae .fromAboveLeft

                mov r12, rax

            .fromAboveLeft:
                push rdi
                push rdx
                push r8
                dec rdi
                mov r8, LEFT
                xor r9, r9
                call findPath

                pop r8
                pop rdx
                pop rdi
                cmp rax, r12
                jae .fromAboveRight

                mov r12, rax

            .fromAboveRight:
                push rdi
                push rdx
                push r8
                inc rdi
                mov r8, RIGHT
                xor r9, r9
                call findPath

                pop r8
                pop rdx
                pop rdi
                cmp rax, r12
                jae .doneAbove

                mov r12, rax

            .doneAbove:
                mov rax, r12
                jmp .unvisit
            
        .foundTarget:
            xor rax, rax
            mov al, byte [rdi]
            sub al, '0'
            add rax, rdx
            cmp rax, r15
            ja .err

            mov r15, rax
            jmp .end

        .unvisit:
            add byte [rdi], VISIT
            jmp .end
        
        .err:
            or rax, FUNC_FAILURE

        .end:
            pop r12
            leave
            ret
    
    ; End findPath.


; End of file.