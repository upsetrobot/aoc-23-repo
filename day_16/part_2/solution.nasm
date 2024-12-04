;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Advent of Code Christmas Challenge Day 16 - Part II
;
; @brief    Return largest number of tiles "energized" by a beam by starting 
;           from a choice of edge tiles.
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

%define NO_ENERGY   '.'
%define ENERGY      'o'


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

        push rdi
        call strLen

        pop rdi
        mov r12, rax                    ; str_len.
        lea r12, [rdi + r12]            ; bottom_right.

        ; We probably want line_len.
        push rdi
        mov al, 0xa
        xor rcx, rcx
        not rcx
        cld
        repne scasb
        not rcx
        pop rdi
        mov r13, rcx                    ; line_len.

        xor r14, r14                    ; max.
        mov r15, rdi                    ; pos.

        .left:
            cmp r15, r12
            jg .endLeft

            push rdi
            mov rsi, r15
            mov rdx, RIGHT
            call getConfig

            pop rdi
            cmp rax, r14
            jle .contLeft

            mov r14, rax

            .contLeft:
                add r15, r13
                jmp .left

        .endLeft:

        lea r15, [rdi + r13 - 2]

        .right:
            cmp r15, r12
            jg .endRight

            push rdi
            mov rsi, r15
            mov rdx, LEFT
            call getConfig

            pop rdi
            cmp rax, r14
            jle .contRight

            mov r14, rax

            .contRight:
                add r15, r13
                jmp .right

        .endRight:

        mov r15, rdi

        .top:
            cmp byte [r15], NEWLINE
            je .endTop

            push rdi
            mov rsi, r15
            mov rdx, DOWN
            call getConfig

            pop rdi
            cmp rax, r14
            jle .contTop

            mov r14, rax

            .contTop:
                inc r15
                jmp .top

        .endTop:

        lea r15, [r12 - 1]

        .bottom:
            cmp byte [r15], NEWLINE
            je .endBottom

            push rdi
            mov rsi, r15
            mov rdx, UP
            call getConfig

            pop rdi
            cmp rax, r14
            jle .contBottom

            mov r14, rax

            .contBottom:
                dec r15
                jmp .bottom

        .endBottom:

        mov rax, r14

        .end:
            pop r15
            pop r14
            pop r13
            pop r12
            leave
            ret

    ; End getSolution.


    ; size_t getConfig(char* fileBuffer, char* start, char dir);
    ;
    ; @brief    Gets total number of energized tiles for given starting 
    ;           position.
    ;
    ; @return   size_t  Returns number of energized tiles.
    getConfig:
        push rbp
        mov rbp, rsp
        push r12
        push r13
        push r14

        ; You could just walk as if you were the beam and count the tiles as 
        ; go. You would have to recuse when split and add the result. You 
        ; would also have to return when the beam ends on a wall. 
        ; The problem there would be not double counting. 

        ; Another approach would be to mark the buffer as the beam moves. 
        ; You solve the double counting problem, but you make a problem of 
        ; losing information on how split beams should behave. 
        ; To get around that, you could encode the mark and the type of 
        ; interactor (meaning there is a '/' and a 'A' which is an energized 
        ; '/'). 

        ; We could also have another buffer that gets marked so that split 
        ; beams can still interact and just mark the answer buffer as they 
        ; go. This would solve both problems as it should be recusive safe.
        ; You could also encode the results somehow like a bitmap or something 
        ; (which would be the same approach but without an entire buffer 
        ; copied). The bitmap idea seems kinda cool. It would still have to 
        ; be a buffer of some sort, cause not all positions would fit in 64
        ; bits. That kind of makes copying the whole buffer feel a little 
        ; simpler. The bitmap idea also has to handle padding. 

        ; I'm gonna just try the double buffer. 

        ; Allocate copy of buf size.
        push rdi
        push rsi
        push rdx
        call strLen

        pop rdx
        pop rsi        
        pop rdi
        mov r12, rax                    ; str_len.

        push rdi
        push rsi
        push rdx
        lea rdi, [rax + 1]
        call memAlloc

        pop rdx
        pop rsi
        pop rdi

        mov r13, rax                    ; ans_buf.

        ; We probably want line_len.
        push rdi
        push rsi
        mov al, 0xa
        xor rcx, rcx
        not rcx
        cld
        repne scasb
        not rcx
        pop rsi
        pop rdi
        mov r14, rcx                    ; line_len.

        ; Fill with x's.
        push rdi
        push rdx
        mov rdi, r13
        mov rcx, r12
        xor rdx, rdx
        inc rdx

        .fill:
            cmp rdx, r14
            jne .noEnergy

            mov byte [rdi], NEWLINE
            xor rdx, rdx
            inc rdx
            jmp .contFill

            .noEnergy:
                mov byte [rdi], NO_ENERGY
                inc rdx

            .contFill:
                inc rdi
                loop .fill

        mov byte byte [rdi], NULL
        pop rdx
        pop rdi

        ; Okay, we need a recursive beam function.
        push rdi
        mov r8, rsi
        mov r9, rdx
        mov rsi, r13
        mov rdx, r14
        mov rcx, r12        
        call beam

        pop rdi

        ; Count marks.
        mov rdi, r13
        xor rdx, rdx
        mov rcx, r12

        .for:
            or byte [rdi], 0xf              ; 0xf is bottom of ENERGY.
            cmp byte [rdi], ENERGY
            jne .cont

            inc rdx

            .cont:
                inc rdi
                loop .for

        ; Deallocate second buffer.
        push rdx
        lea rdi, [r12 + 1]
        call memDealloc

        pop rax

        .end:
            pop r14
            pop r13
            pop r12
            leave
            ret

    ; End getConfig.


    ; void beam(
    ;   char* buf, 
    ;   char* ans_buf, 
    ;   size_t line_len, 
    ;   size_t str_len, 
    ;   size_t start,
    ;   size_t dir
    ; );
    ;
    ; @brief    Moves a beam through the buffer and marks the copy as it goes.
    ;
    beam:
        push rbp
        mov rbp, rsp
        push r12
        push r13
        push r14

        ; Need to check for recursive loops. If starting position is in 
        ; list with directions, then return and that would work, but that 
        ; would eliminate the use of the second buffer and require a list.
        ; ugh.

        ; If you could encode directions in second buffer, then that would 
        ; work. But we would need to be able to encode all direction in one 
        ; location and derive that info later.
        ;
        ; A bit mask maybe if we and with slot we can get direction. 

        mov r12, rdi                    ; top_left.
        lea r13, [rdi + rcx]            ; bottom_right.
        mov rdi, r8

        xor r14, r14                    ; loop_mitigator.

        ; Check for direction to fix recursive loops.
        mov r10, rdi
        sub r10, r12
        add r10, rsi
        cmp byte [r10], NO_ENERGY
        je .whileChar

        cmp byte [r10], NEWLINE
        je .whileChar

        xor r11, r11
        mov r11b, [r10]
        and r11, 0xf                    ; Clear upper bits.
        and r11, r9
        test r11, r11
        jnz .endWhileChar

        .whileChar:
            cmp byte [rdi], NULL
            je .endWhileChar

            cmp byte [rdi], NEWLINE
            je .endWhileChar

            cmp rdi, r12
            jl .endWhileChar

            cmp rdi, r13
            jg .endWhileChar

            ; Mark buf.
            mov r10, rdi
            sub r10, r12
            add r10, rsi
            mov r11, ENERGY
            and r11, 0xf0               ; Clear the bottom four bits.
            add r11, r9                 ; Encoded char.

            mov byte [r10], r11b

            cmp byte [rdi], '|'
            je .pipeVert

            cmp byte [rdi], '-'
            je .pipeHoriz

            cmp byte [rdi], '/'
            je .mirrorRight

            cmp byte [rdi], '\'
            je .mirrorLeft

            .move:
                cmp r9, RIGHT
                je .movingRight

                cmp r9, DOWN
                je .movingDown

                cmp r9, LEFT
                je .movingLeft

                cmp r9, UP
                je .movingUp

                int3                        ; Should not happen.

                .movingRight:
                    mov r9, RIGHT
                    inc rdi
                    jmp .whileChar

                .movingDown:
                    mov r9, DOWN
                    add rdi, rdx
                    jmp .whileChar

                .movingLeft:
                    mov r9, LEFT
                    dec rdi
                    jmp .whileChar

                .movingUp:
                    mov r9, UP
                    sub rdi, rdx
                    jmp .whileChar

            .pipeVert:
                cmp r9, RIGHT
                je .hitPipeVert

                cmp r9, LEFT
                je .hitPipeVert

                ; Fix endless loop.
                cmp r14, 1000
                je .endWhileChar

                inc r14
                jmp .move

                .hitPipeVert:
                    xor r14, r14

                    ; Send beam down.
                    push rdi
                    lea r8, [rdi + rdx]
                    mov rdi, r12
                    mov rsi, rsi
                    mov rdx, rdx
                    mov rcx, rcx
                    mov r9, DOWN
                    call beam

                    pop rdi

                    ; Send beam up.
                    mov r9, UP
                    jmp .move

            .pipeHoriz:
                cmp r9, DOWN
                je .hitPipeHoriz

                cmp r9, UP
                je .hitPipeHoriz

                ; Fix endless loop.
                cmp r14, 1000
                je .endWhileChar

                inc r14
                jmp .move

                .hitPipeHoriz:
                    xor r14, r14

                    ; Send beam right.
                    push rdi
                    lea r8, [rdi + 1]
                    mov rdi, r12
                    mov rsi, rsi
                    mov rdx, rdx
                    mov rcx, rcx
                    mov r9, RIGHT
                    call beam

                    pop rdi

                    ; Send beam left.
                    mov r9, LEFT
                    jmp .move

            .mirrorLeft:
                cmp r9, RIGHT
                je .movingDown

                cmp r9, DOWN
                je .movingRight

                cmp r9, LEFT
                je .movingUp

                cmp r9, UP
                je .movingLeft

                int3                        ; Should not get here.

            .mirrorRight:
                cmp r9, RIGHT
                je .movingUp

                cmp r9, DOWN
                je .movingLeft

                cmp r9, LEFT
                je .movingDown

                cmp r9, UP
                je .movingRight

                int3                        ; Should not get here.

        .endWhileChar:
            xor rax, rax
            jmp .end

        .err:
            or rax, FUNC_FAILURE

        .end:
            pop r14
            pop r13
            pop r12
            leave
            ret
    
    ; End beam.


; End of file.