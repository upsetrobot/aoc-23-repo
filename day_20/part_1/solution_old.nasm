;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Advent of Code Christmas Challenge Day 20 - Part I
;
; @brief    Uh, this one is a little complicated to me, it seems like a 
;           digital logic circuit thing. Goal is to parse configuration and 
;           give the number of low pulses multiplied by the number of high 
;           pulses that are sent by all components after an initial low pulse 
;           is sent 1000 times.
;
; @file         solution.nasm
; @date         31 Dec 2023
; @author       upsetrobot
; @copyright    Copyright (c) 2023
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Thoughts:
;
; Well, I thought about using boolean algebra, but the goal is not to find the 
; output, so I do not think that will be helpful. You can also think of this 
; as some sort of state machine, so we could possibly build the machine as 
; an object that returns the number of low and high pulse every time you 
; give it a pulse. Even better, if you were able to set it up based on the 
; number of pulse given. It would propagate the pulse and count them, then do 
; it again n times. I suppose that is the naive solution. Are there any 
; better solutions such as a mathematic solution? I don't think it matters as 
; the it would not take that long to run I think. Okay, that it the approach.
;
; Maybe it would be easier to build the components first.
; Actually, I kinda wanna just do this with functions as the components.
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

%define ON  0xff
%define OFF 0

%define LOW     0x7f
%define HIGH    0xff

%define BROADCAST   0
%define FLIPFLOP    1
%define CONJ        2

; Struc definitions.
struc component
    .type:          resb    1
    .label:         resb    8
    .targets:       resq    10
    .onOff:         resb    1
    .input:         resb    1
    .input_label:   resq    1
    .mem:           resq    9      ; 8 bytes for label, 1 for state.

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

        xor r8, r8                  ; component_arr.
        xor r9, r9                  ; component_arr_len.
        xor r10, r10                ; curr_component.

        .parse:
            test rdi, rdi
            jz .endParse

            ; Allocate memory for component.
            .makeComponent:
                push rdi
                mov rdi, component_size
                call memAlloc

                test r8, r8
                jnz .initialized

                mov r8, rax

            .initialized:
                mov r10, rax
                pop rdi
                inc r9

                ; Fill component.
                push rdi
                mov rdi, r10
                mov rcx, component_size

                .fill:
                    mov byte [rdi], NULL
                    inc rdi
                    loop .fill

                pop rdi

            call getLine

            mov rsi, rax
            cmp byte [rdi], '%'
            je .parse.flipflop

            cmp byte [rdi], '&'
            je .parse.conj

            cmp byte [rdi], 'b'
            je .parse.broadcaster

            int3

            .parse.flipflop:
                inc rdi
                xor rcx, rcx

                .parse.flipflop.label:
                    cmp byte [rdi], ' '
                    je .parse.flipflop.endLabel

                    mov dl, byte [rdi]
                    mov byte [r10 + rcx + component.label], dl
                    inc rcx
                    inc rdi
                    jmp .parse.flipflop.label

                .parse.flipflop.endLabel:

                mov byte [r10 + component.type], FLIPFLOP
                mov byte [r10 + component.onOff], OFF
                add rdi, 4
                lea r11, [r10 + component.targets]

                .parse.flipflop.targets:
                    xor rcx, rcx                    

                    .parse.flipflop.targets.label:
                        cmp byte [rdi], ','
                        je .parse.flipflop.targets.endLabel

                        cmp byte [rdi], NULL
                        je .parse.flipflop.endTargets

                        mov dl, byte [rdi]
                        mov byte [r11 + rcx], dl
                        inc rcx
                        inc rdi
                        jmp .parse.flipflop.targets.label

                    .parse.flipflop.targets.endLabel:
                        add r11, 8
                        add rdi, 2
                        jmp .parse.flipflop.targets

                .parse.flipflop.endTargets:
                    jmp .next

            .parse.conj:
                inc rdi
                xor rcx, rcx

                .parse.conj.label:
                    cmp byte [rdi], ' '
                    je .parse.conj.endLabel

                    mov dl, byte [rdi]
                    mov byte [r10 + rcx + component.label], dl
                    inc rcx
                    inc rdi
                    jmp .parse.conj.label

                .parse.conj.endLabel:

                mov byte [r10 + component.type], CONJ
                add rdi, 4
                lea r11, [r10 + component.targets]

                .parse.conj.targets:
                    xor rcx, rcx                    

                    .parse.conj.targets.label:
                        cmp byte [rdi], ','
                        je .parse.conj.targets.endLabel

                        cmp byte [rdi], NULL
                        je .parse.conj.endTargets

                        mov dl, byte [rdi]
                        mov byte [r11 + rcx], dl
                        inc rcx
                        inc rdi
                        jmp .parse.conj.targets.label

                    .parse.conj.targets.endLabel:
                        add r11, 8
                        add rdi, 2
                        jmp .parse.conj.targets

                .parse.conj.endTargets:
                    jmp .next

            .parse.broadcaster:
                mov qword [r10 + component.label], 'broad'
                mov byte [r10 + component.type], BROADCAST
                add rdi, 15
                lea r11, [r10 + component.targets]

                .parse.broadcaster.targets:
                    xor rcx, rcx                    

                    .parse.broadcaster.targets.label:
                        cmp byte [rdi], ','
                        je .parse.broadcaster.targets.endLabel

                        cmp byte [rdi], NULL
                        je .parse.broadcaster.endTargets

                        mov dl, byte [rdi]
                        mov byte [r11 + rcx], dl
                        inc rcx
                        inc rdi
                        jmp .parse.broadcaster.targets.label

                    .parse.broadcaster.targets.endLabel:
                        add r11, 8
                        add rdi, 2
                        jmp .parse.broadcaster.targets

                .parse.broadcaster.endTargets:
                    jmp .next

            .next:
                mov rdi, rsi
                jmp .parse

        .endParse:

        xor rcx, rcx
        mov r10, r8

        .findBroadcast:
            cmp rcx, r9
            je .endFindBroadcast

            cmp qword [r10 + component.label], "broad"
            je .endFindBroadcast

            add r10, component_size
            inc rcx
            jmp .findBroadcast

        .endFindBroadcast:
        
        xor rcx, rcx
        xor r12, r12                ; low_sum.
        xor r13, r13                ; high_sum.

        .run:int3
            cmp rcx, 1000
            je .endRun

            inc r12

            push rcx
            push r10
            mov rdi, r10
            call broadcaster

            pop r10
            pop rcx
            inc rcx

            call propagate



            jmp .run

        .endRun:
            mov rax, r12
            mul r13
        
        .end:
            pop r15
            pop r14
            pop r13
            pop r12
            leave
            ret

    ; End getSolution.


    ; void broadcaster(
    ;   component* component, 
    ;   size_t input_pulse,         ; Not used.
    ;   component* component_arr,   ; r8.
    ;   size_t component_arr_len    ; r9.
    ; );
    ;
    ; @brief    blah.
    ;
    broadcaster:
        push rbp
        mov rbp, rsp

        ; Send low to all targets.
        lea r10, [rdi + component.targets]
        mov rax, [r10]
        
        .forAllTargets:
            cmp qword [r10], NULL
            je .endForAllTargets

            xor rcx, rcx
            mov r11, r8

            .findTarget:
                cmp rcx, r9
                je .endFindTarget

                cmp rax, [r11 + component.label]
                je .endFindTarget

                add r11, component_size
                inc rcx
                jmp .findTarget

            .endFindTarget:

            mov byte [r11 + component.input], LOW
            mov rdx, [rdi + component.label]
            mov [r11 + component.input_label], rdx
            inc r12                 ; low_counter.
            add r10, 8
            mov rax, [r10]
            jmp .forAllTargets

        .endForAllTargets:

        ; ; Now that all are set, execute each target.
        ; lea r10, [rdi + component.targets]
        ; mov rax, [r10]
        
        ; .forAllTargets2:
        ;     cmp qword [r10], NULL
        ;     je .endForAllTargets2

        ;     xor rcx, rcx
        ;     mov r11, r8

        ;     .findTarget2:
        ;         cmp rcx, r9
        ;         je .endFindTarget2

        ;         cmp rax, [r11 + component.label]
        ;         je .endFindTarget2

        ;         add r11, component_size
        ;         inc rcx
        ;         jmp .findTarget2

        ;     .endFindTarget2:

        ;     cmp byte [r11 + component.type], FLIPFLOP
        ;     je .flipflop

        ;     cmp byte [r11 + component.type], CONJ
        ;     je .conj

        ;     int3

        ;     .flipflop:
        ;         push rdi
        ;         push r10
        ;         push r11
        ;         mov rdi, r11
        ;         call flipflop

        ;         pop r11
        ;         pop r10
        ;         pop rdi
        ;         jmp .forAllTargets2.next

        ;     .conj:
        ;         push rdi
        ;         push r10
        ;         push r11
        ;         mov rdi, r11
        ;         call conj

        ;         pop r11
        ;         pop r10
        ;         pop rdi
        ;         jmp .forAllTargets2.next
            
        ;     .forAllTargets2.next:
        ;         add r10, 8
        ;         mov rax, [r10]
        ;         jmp .forAllTargets2

        ; .endForAllTargets2:

        .end:
            leave
            ret

    ; End broadcaster.


    ;
    ;   component* component_arr,   ; r8.
    ;   size_t component_arr_len    ; r9.
    ;
    propagate:
        push rbp
        mov rbp, rsp

        ; Go through each component and process pulses.
        mov rdi, r9
        xor rcx, rcx

        .for:
            cmp rcx, r9
            je .endFor

            ; Check if component has pulse. 

        .endFor:



        .end:
            leave
            ret

    ; End propagate.


    ; void flipflop(
    ;   component* component, 
    ;   size_t input_pulse,
    ;   component* component_arr,   ; r8.
    ;   size_t component_arr_len    ; r9.
    ; );
    ;
    ; @brief    blah.
    ;
    flipflop:
        push rbp
        mov rbp, rsp

        ; High pulse, do nothing.
        cmp byte [rdi + component.input], HIGH
        je .end

        ; Low pulse, switch between on and off.
        not byte [rdi + component.onOff]

        ; Send pulse to targets.
        lea r10, [rdi + component.targets]
        mov rax, [r10]
        
        .forAllTargets:
            cmp qword [r10], NULL
            je .endForAllTargets

            xor rcx, rcx
            mov r11, r8

            .findTarget:
                cmp rcx, r9
                je .endFindTarget

                cmp rax, [r11 + component.label]
                je .endFindTarget

                add r11, component_size
                inc rcx
                jmp .findTarget

            .endFindTarget:

            cmp byte [rdi + component.onOff], OFF
            je .off

            .on:
                mov byte [r11 + component.input], HIGH
                inc r13
                jmp .cont

            .off:
                mov byte [r11 + component.input], LOW
                inc r12

            .cont:
                mov rdx, [rdi + component.label]
                mov [r11 + component.input_label], rdx
                add r10, 8
                mov rax, [r10]
                jmp .forAllTargets

        .endForAllTargets:

        ; Now that all are set, execute each target.
        lea r10, [rdi + component.targets]
        mov rax, [r10]
        
        .forAllTargets2:
            cmp qword [r10], NULL
            je .endForAllTargets2

            xor rcx, rcx
            mov r11, r8

            .findTarget2:
                cmp rcx, r9
                je .endFindTarget2

                cmp rax, [r11 + component.label]
                je .endFindTarget2

                add r11, component_size
                inc rcx
                jmp .findTarget2

            .endFindTarget2:

            cmp byte [r11 + component.type], FLIPFLOP
            je .flipflop

            cmp byte [r11 + component.type], CONJ
            je .conj

            int3

            .flipflop:
                push rdi
                push r10
                push r11
                mov rdi, r11
                call flipflop

                pop r11
                pop r10
                pop rdi
                jmp .forAllTargets2.next

            .conj:
                push rdi
                push r10
                push r11
                mov rdi, r11
                call conj

                pop r11
                pop r10
                pop rdi
                jmp .forAllTargets2.next
            
            .forAllTargets2.next:
                add r10, 8
                mov rax, [r10]
                jmp .forAllTargets2

        .endForAllTargets2:

        .end:
            leave
            ret

    ; End flipflop.


    ; void conj();
    ;
    conj:
        push rbp
        mov rbp, rsp

        lea rdx, [rdi + component.mem]
        mov r10, [rdi + component.input_label]
        mov r11b, [rdi + component.input]

        ; Set memory.
        .forMem:
            cmp qword [rdx], NULL
            je .new

            cmp r10, [rdx]
            je .endForMem

            add rdx, 9
            jmp .forMem

            .new:
                mov [rdx], r10

        .endForMem:
            mov [rdx + 8], r11b

        lea rdx, [rdi + component.mem]

        .checkForAllHigh:
            cmp qword [rdx], NULL
            je .allHigh

            cmp byte [rdx + 8], LOW
            je .notAllHigh

            add rdx, 9
            jmp .checkForAllHigh

        .allHigh:
            ; Send low pulse.
            mov rsi, LOW
            jmp .send

        .notAllHigh:
            ; Send hight pulse.
            mov rsi, HIGH

        .send:
            lea r10, [rdi + component.targets]
            mov rax, [r10]
        
        .forAllTargets:
            cmp qword [r10], NULL
            je .endForAllTargets

            xor rcx, rcx
            mov r11, r8

            .findTarget:
                cmp rcx, r9
                je .endFindTarget

                cmp rax, [r11 + component.label]
                je .endFindTarget

                add r11, component_size
                inc rcx
                jmp .findTarget

            .endFindTarget:

            cmp sil, LOW
            je .low

            .high:
                mov byte [r11 + component.input], HIGH
                inc r13
                jmp .cont

            .low:
                mov byte [r11 + component.input], LOW
                inc r12

            .cont:
                mov rdx, [rdi + component.label]
                mov [r11 + component.input_label], rdx
                add r10, 8
                mov rax, [r10]
                jmp .forAllTargets

        .endForAllTargets:

        ; Now that all are set, execute each target.
        lea r10, [rdi + component.targets]
        mov rax, [r10]
        
        .forAllTargets2:
            cmp qword [r10], NULL
            je .endForAllTargets2

            xor rcx, rcx
            mov r11, r8

            .findTarget2:
                cmp rcx, r9
                je .endFindTarget2

                cmp rax, [r11 + component.label]
                je .endFindTarget2

                add r11, component_size
                inc rcx
                jmp .findTarget2

            .endFindTarget2:

            cmp byte [r11 + component.type], FLIPFLOP
            je .flipflop

            cmp byte [r11 + component.type], CONJ
            je .conj

            int3

            .flipflop:
                push rdi
                push r10
                push r11
                mov rdi, r11
                call flipflop

                pop r11
                pop r10
                pop rdi
                jmp .forAllTargets2.next

            .conj:
                push rdi
                push r10
                push r11
                mov rdi, r11
                call conj

                pop r11
                pop r10
                pop rdi
                jmp .forAllTargets2.next
            
            .forAllTargets2.next:
                add r10, 8
                mov rax, [r10]
                jmp .forAllTargets2

        .endForAllTargets2:

        .end:
            leave
            ret

    ; End conj.



; End of file.