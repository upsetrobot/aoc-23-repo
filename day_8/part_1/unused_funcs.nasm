section .text

    ; size_t quadratic(size_t a, size_t b, size_t c, bool secondSolution);
    quadratic:
        push rbp
        mov rbp, rsp
        push rbx
        push r12
        push r13
        push r14

        mov rax, rdi
        mov rbx, rsi
        mov r14, rcx
        mov rcx, rdx
        mov r12, rdx

        ; 4ac
        shl rax, 2
        xor rdx, rdx
        imul rcx
        mov r13, rax                ; r13 = 4ac.

        ; b^2 - 4ac.
        mov rax, rbx
        xor rdx, rdx
        imul rax
        sub rax, r13                ; rax = b^2 - 4ac.
        push rdi
        mov rdi, rax

        ; sqrt(b^2 - 4ac)
        call sqrt

        pop rdi
        
        ; -b + sqrt(b^2 - 4ac).
        xor r13, r13
        sub r13, rbx

        test r14, r14
        jz .add

        sub r13, rax
        jmp .finish

        .add:        
            add r13, rax                ; r13 = -b + sqrt(b^2 - 4ac).

        .finish:
            mov rax, r13

            ; final.
            mov rcx, rdi
            shl rcx, 1
            cqo
            idiv rcx
        
        .end:
            pop r14
            pop r13
            pop r12
            pop rbx
            leave
            ret

    .endquadratic:


    ; size_t sqrt(size_t square);
    ; Nearest integer sqrt. Need to account for remainder somehow.
    sqrt:
        push rbp
        mov rbp, rsp
        mov rax, rdi

        cqo                 ; Find abs(a).
        xor rax, rdx
        sub rax, rdx
        mov rdx, -1
        
        inc rax             ; Find sqrt(abs(a)).
        shr rax, 1
        .loop:
            inc rdx
            sub rax, rdx
            ja .loop

        mov rax, rdx

        .end:
            leave
            ret

    endsqrt:

