;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Advent of Code Christmas Challenge Day 20 - Part I
;
; @brief    Uh, this one is a little complicated to me, it seems like a 
;           digital logic circuit thing. Goal is to parse configuration and 
;           give the number of low pulses multiplied by the number of high 
;           pulses that are sent by all components after an initial low pulse 
;           is sent 1000 times.
;
;           Worked for samples - not the full input. Determined we need a 
;           queue as the order seems to be the only possible problem (if one 
;           module receives two inputs at once (right after each other)).
;
; @file         solution.nasm
; @date         31 Dec 2023
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

%define ON  0xff
%define OFF 0

%define LOW         0x7f
%define HIGH        0xff

%define BROADCAST   0
%define FLIPFLOP    1
%define CONJ        2
%define UNTYPED     3

; Struc definitions.
struc component
    .label:         resb    8
    .type:          resb    1
    .onOff:         resb    1
    .input:         resb    1
    .output:        resb    1
    .pad:           resb    4
    .inputter:      resq    1
    .targets:       resq    9    
    .mem:           resq    13      ; 8 bytes pointer, 1 for state.

endstruc


; Global constants.
section .rodata

    filename                db  "input.txt", 0
    
    err_main                db  "Error Main", 10, 0
    err_main_len            equ $ - err_main
    
    msg                     db  "Solution: ", 0
    input_state             db  "---- INPUT STATE ----", 0
    output_state            db  "---- OUTPUT STATE ----", 0


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

        xor rsi, rsi                ; nxt_ln.
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

            .fillArr:
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
            mov byte [r10 + component.input], OFF
            mov byte [r10 + component.output], OFF
            cmp byte [rdi], '%'
            je .parse.flipflop

            cmp byte [rdi], '&'
            je .parse.conj

            cmp byte [rdi], 'b'
            je .parse.broadcaster

            int3

            .parse.flipflop:
                mov byte [r10 + component.type], FLIPFLOP
                mov byte [r10 + component.onOff], OFF
                jmp .parse.label

            .parse.conj:
                mov byte [r10 + component.type], CONJ
                jmp .parse.label

            .parse.broadcaster:
                mov byte [r10 + component.type], BROADCAST
                mov qword [r10 + component.label], "broa"
                add rdi, 15
                jmp .parse.targets

            .parse.label:
                inc rdi
                xor rcx, rcx

                .parse.label.label:
                    cmp byte [rdi], ' '
                    je .parse.endLabel

                    mov dl, byte [rdi]
                    mov byte [r10 + rcx + component.label], dl
                    inc rcx
                    inc rdi
                    jmp .parse.label.label

            .parse.endLabel:
                add rdi, 4

            .parse.targets:
                lea r11, [r10 + component.targets]

                .parse.targets.target:
                    xor rcx, rcx

                    .parse.targets.target.label:
                        cmp byte [rdi], ','
                        je .parse.targets.target.endLabel

                        cmp byte [rdi], NULL
                        je .parse.targets.end

                        mov dl, byte [rdi]
                        mov byte [r11 + rcx], dl
                        inc rcx
                        inc rdi
                        jmp .parse.targets.target.label

                    .parse.targets.target.endLabel:
                        add r11, 8
                        add rdi, 2
                        jmp .parse.targets.target

            .parse.targets.end:
                mov rdi, rsi
                jmp .parse

        .endParse:

        ; Resolve pointers and find broadcast.
        xor rcx, rcx
        mov rdi, r8         ; curr_component.
        xor r10, r10        ; broadcast_component.

        .resolve:
            cmp rcx, r9
            je .endResolve

            cmp qword [rdi + component.label], "broa"
            cmove r10, rdi
            lea r11, [rdi + component.targets]
            
            .resolve.targets:
                cmp qword [r11], NULL
                je .resolve.targets.end

                xor rax, rax    ; count for finding.
                mov rdx, r8     ; curr_component for finding.

                .resolve.targets.find:
                    cmp rax, r9
                    je .untypedModule

                    mov r12, [rdx + component.label]
                    cmp r12, [r11]
                    jne .resolve.targets.find.next

                    mov [r11], rdx
                    lea rsi, [rdx + component.mem]

                    .resolve.targets.find.mem:
                        cmp qword [rsi], NULL
                        je .resolve.targets.find.mem.new

                        add rsi, 9
                        jmp .resolve.targets.find.mem

                    .resolve.targets.find.mem.new:
                        mov [rsi], rdi
                        mov byte [rsi + 8], LOW
                        jmp .resolve.targets.find.end

                    .resolve.targets.find.next:
                        add rdx, component_size
                        inc rax
                        jmp .resolve.targets.find

                .untypedModule:
                    ; Need to add module I guess.
                    push rdi
                    push rsi
                    push rdx
                    push rcx
                    push r8
                    push r9
                    push r10
                    push rax
                    push r11
                    
                    mov rdi, component_size
                    call memAlloc

                    push rax
                    mov rcx, component_size
                    mov rdi, rax
                    mov al, NULL
                    cld
                    rep movsb
                    pop rax
                    pop r11

                    mov byte [rax + component.type], UNTYPED
                    mov rdx, [r11]
                    mov [rax + component.label], rdx
                    mov [r11], rax

                    pop rax                    
                    pop r10
                    pop r9
                    pop r8
                    pop rcx
                    pop rdx
                    pop rsi
                    pop rdi

                    inc r9

                .resolve.targets.find.end:

                add r11, 8
                jmp .resolve.targets

            .resolve.targets.end:

            add rdi, component_size
            inc rcx
            jmp .resolve

        .endResolve:

        xor rcx, rcx
        xor r12, r12                ; low_sum.
        xor r13, r13                ; high_sum.
        mov rdi, r8
        mov rsi, r9
        
        .run:
            cmp rcx, 4
            je .run.end

            mov byte [r10 + component.input], LOW   ; Set broadcast.
            push rcx
            push r10
            call process

            pop r10
            pop rcx
            inc rcx
            jmp .run

        .run.end:
            mov rax, r12
            mul r13
        
        .end:
            pop r13
            pop r12
            leave
            ret

    ; End getSolution.


    ; void process(component* arr, size_t component_arr_len);
    ;
    ; @brief    Processes all active inputs to outputs, then move outputs to 
    ;           inputs and repeats process till no more inputs are activated. 
    ;           Counts low and high pulses and add them to r12 and r13.
    ;
    process:
        push rbp
        mov rbp, rsp

        .top:
            ; Go through each component and process inputs to outputs.
            ; And count inputs.

            ; Print state 1.
            xor rcx, rcx
            mov r10, rdi

            push rdi
            push rsi
            push rcx
            push r8
            push r9
            push r10
            mov rdi, input_state
            mov rsi, TRUE
            call print
            pop r10
            pop r9
            pop r8
            pop rcx
            pop rsi
            pop rdi
                
            .loop1:
                cmp rcx, r9
                je .endLoop1

                push rdi
                push rsi
                push rcx
                push r8
                push r9
                push r10
                lea rdi, [r10 + component.label]
                mov rsi, TRUE
                call print
                pop r10
                pop r9
                pop r8
                pop rcx
                pop rsi
                pop rdi

                push rdi
                push rsi
                push rcx
                push r8
                push r9
                push r10
                xor rdi, rdi
                mov dil, [r10 + component.input]
                mov rsi, FALSE
                call numToStr

                mov rdi, rax
                mov rsi, TRUE
                call print
                pop r10
                pop r9
                pop r8
                pop rcx
                pop rsi
                pop rdi

                push rdi
                push rsi
                push rcx
                push r8
                push r9
                push r10
                xor rdi, rdi
                mov dil, [r10 + component.output]
                mov rsi, FALSE
                call numToStr

                mov rdi, rax
                mov rsi, TRUE
                call print

                mov rdi, nl 
                mov rsi, TRUE
                call print
                pop r10
                pop r9
                pop r8
                pop rcx
                pop rsi
                pop rdi

                inc rcx
                add r10, component_size
                jmp .loop1
            
            .endLoop1:

            xor rcx, rcx
            mov r10, rdi

            .for:
                cmp rcx, rsi
                je .for.end

                cmp byte [r10 + component.input], OFF
                je .for.next

                cmp byte [r10 + component.type], BROADCAST
                je .for.broadcast

                cmp byte [r10 + component.type], FLIPFLOP
                je .for.flipflop

                cmp byte [r10 + component.type], CONJ
                je .for.conj

                ; Assume untyped.
                cmp byte [r10 + component.type], UNTYPED
                jne .fail

                cmp byte [r10 + component.input], HIGH
                je .countHigh

                inc r12
                mov byte [r10 + component.input], OFF
                jmp .for.next

                .countHigh:
                    inc r13
                    mov byte [r10 + component.input], OFF
                    jmp .for.next

                .fail:
                    int3

                .for.broadcast:
                    mov al, byte [r10 + component.input]
                    mov byte [r10 + component.input], OFF
                    mov byte [r10 + component.output], al
                    cmp al, LOW
                    je .for.broadcast.low

                    .for.broadcast.high:
                        inc r13
                        jmp .for.next

                    .for.broadcast.low:
                        inc r12
                        jmp .for.next

                .for.flipflop:
                    mov al, byte [r10 + component.input]
                    mov byte [r10 + component.input], OFF
                    cmp al, HIGH
                    je .for.flipflop.high

                    not byte [r10 + component.onOff]
                    cmp byte [r10 + component.onOff], ON
                    je .for.flipflop.sendHigh

                    mov byte [r10 + component.output], LOW
                    jmp .for.flipflop.low

                    .for.flipflop.sendHigh:
                        mov byte [r10 + component.output], HIGH

                    .for.flipflop.low:
                        inc r12
                        jmp .for.next

                    .for.flipflop.high:
                        inc r13
                        jmp .for.next

                .for.conj:
                    mov al, byte [r10 + component.input]
                    mov byte [r10 + component.input], OFF

                    ; Update memory.
                    lea rdx, [r10 + component.mem]
                    mov r11, [r10 + component.inputter]

                    .for.conj.for:
                        cmp qword [rdx], NULL
                        je .for.conj.for.end

                        cmp [rdx], r11
                        je .for.conj.for.update

                        add rdx, 9
                        jmp .for.conj.for

                    .for.conj.for.update:
                        mov byte [rdx + 8], al

                    .for.conj.for.end:

                    ; Check memory.
                    lea rdx, [r10 + component.mem]

                    .for.conj.check:
                        cmp qword [rdx], NULL
                        je .for.conj.sendLow

                        cmp byte [rdx + 8], HIGH
                        jne .for.conj.sendHigh

                        add rdx, 9
                        jmp .for.conj.check

                    .for.conj.sendLow:
                        mov byte [r10 + component.output], LOW
                        cmp al, LOW
                        je .for.conj.low
                        jmp .for.conj.high
                        
                    .for.conj.sendHigh:
                        mov byte [r10 + component.output], HIGH
                        cmp al, LOW
                        je .for.conj.low

                    .for.conj.high:
                        inc r13
                        jmp .for.next

                    .for.conj.low:
                        inc r12
                        jmp .for.next

                .for.next:
                    add r10, component_size
                    inc rcx
                    jmp .for

            .for.end:

            ; Print state 2.
            xor rcx, rcx
            mov r10, rdi

            push rdi
            push rsi
            push rcx
            push r8
            push r9
            push r10
            mov rdi, output_state
            mov rsi, TRUE
            call print
            pop r10
            pop r9
            pop r8
            pop rcx
            pop rsi
            pop rdi
                
            .loop2:
                cmp rcx, r9
                je .endLoop2

                push rdi
                push rsi
                push rcx
                push r8
                push r9
                push r10
                lea rdi, [r10 + component.label]
                mov rsi, TRUE
                call print
                pop r10
                pop r9
                pop r8
                pop rcx
                pop rsi
                pop rdi

                push rdi
                push rsi
                push rcx
                push r8
                push r9
                push r10
                xor rdi, rdi
                mov dil, [r10 + component.input]
                mov rsi, FALSE
                call numToStr

                mov rdi, rax
                mov rsi, TRUE
                call print
                pop r10
                pop r9
                pop r8
                pop rcx
                pop rsi
                pop rdi

                push rdi
                push rsi
                push rcx
                push r8
                push r9
                push r10
                xor rdi, rdi
                mov dil, [r10 + component.output]
                mov rsi, FALSE
                call numToStr

                mov rdi, rax
                mov rsi, TRUE
                call print

                mov rdi, nl 
                mov rsi, TRUE
                call print
                pop r10
                pop r9
                pop r8
                pop rcx
                pop rsi
                pop rdi

                inc rcx
                add r10, component_size
                jmp .loop2
            
            .endLoop2:

            ; Now go through all outputs and move them to inputs.
            mov r10, rdi
            xor rcx, rcx
            xor r14, r14                    ; no_outputs_flag.

            .outputs:
                cmp rcx, rsi
                je .outputs.end

                cmp byte [r10 + component.output], OFF
                je .outputs.next

                lea r11, [r10 + component.targets]
                xor rdx, rdx
                mov al, [r10 + component.output]

                .outputs.targets:
                    cmp qword [r11], NULL
                    je .outputs.targets.end

                    inc r14
                    mov rdx, [r11]
                    mov [rdx + component.inputter], r10
                    mov [rdx + component.input], al
                    add r11, 8
                    jmp .outputs.targets

                .outputs.targets.end:
                    mov byte [r10 + component.output], OFF

                .outputs.next:
                    add r10, component_size
                    inc rcx
                    jmp .outputs

            .outputs.end:
                test r14, r14
                jz .end
                jmp .top

        .end:
            leave
            ret

    ; End broadcaster.


; End of file.