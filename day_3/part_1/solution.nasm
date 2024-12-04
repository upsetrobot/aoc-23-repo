;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Advent of Code Christmas Challenge Day 3 - Part I
;
; @brief    Take an input file and sum all numbers adjacent to symbols and 
;           print the sum.
;
; @file         solution.nasm
; @date         03 Dec 2023
; @author       upsetrobot
; @copyright    Copyright (c) 2023
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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

struc sb

	.st_dev:        resb    8
	.st_ino:        resb    8
	.st_nlink:      resb    8
	.st_mode:       resb    4
	.st_uid:        resb    4
	.st_gid:        resb    4
    .__pad0:        resb    4
	.st_rdev:       resb    8
	.st_size:       resb    8
	.st_blksize:    resb    8
	.st_blocks:     resb    8
	.st_atime:      resb    8
	.st_atime_nsec: resb    8
	.st_mtime:      resb    8
	.st_mtime_nsec: resb    8
	.st_ctime:      resb    8
	.st_ctime_nsec: resb    8

endstruc

; Global constants.
section .rodata

    msg         db  "Total Sum: %lld", 10, 0
    error_msg   db  "Error", 0
    filename    db  "input.txt", 0


; Global uninitialized variables.
section .bss

    fd:         resd    1
    stat_buf:   resb    sb_size
    filesize:   resq    1
    buf_ptr:    resq    1


; Global initialized variables.
section .data


; Code.
section .text

    global main
    extern printf
    extern perror
    extern malloc
    extern free

    main:
        push rbp

        mov rdi, filename
        call getFile

        test eax, eax
        js .error

        mov rdi, [buf_ptr]
        call sumFile

        mov rdi, msg
        mov rsi, rax
        call printf

        mov rdi, [buf_ptr]
        call free

        xor rax, rax
        jmp .end

        .error:
            mov rdi, [buf_ptr]
            call free

            xor rax, rax
            not eax
        
        .end:
            pop rbp
            ret


    ; int getFile(char* filename);
    ; ret 0 on success; else ret -1.
    getFile:
        push rbp

        ; Open file.
        ; int open(const char *pathname, int flags, mode_t mode);
        xor esi, esi
        mov rdx, 0777
        mov rax, SYS_OPEN
        syscall

        test eax, eax
        js .error

        mov [fd], eax

        ; Get filesize.
        ; int stat(const char *pathname, struct stat *statbuf);
        mov rdi, filename
        mov rsi, stat_buf
        mov rax, SYS_STAT
        syscall

        test eax, eax
        jnz .close

        mov rax, [stat_buf + sb.st_size] 
        mov [filesize], rax

        ; Reserve memory.
        ; void *malloc(size_t size);
        mov rdi, rax
        inc rdi
        call malloc

        test rax, rax
        jz .close

        mov [buf_ptr], rax

        ; Read file into memory.
        ; ssize_t read(int fd, void *buf, size_t count);
        mov edi, [fd]
        mov rsi, rax
        mov rdx, [filesize]
        mov rax, SYS_READ
        syscall

        test rax, rax
        js .close

        ; Null terminate memory.
        mov rax, [buf_ptr]
        add rax, [filesize]
        mov byte [rax], 0

        ; Close file.
        ; int close(int fd);
        mov edi, [fd]
        mov rax, SYS_CLOSE
        syscall

        test eax, eax
        jnz .error

        xor rax, rax
        jmp .end

        .close:
            mov edi, [fd]
            mov rax, SYS_CLOSE
            syscall

        .error:
            mov rdi, error_msg
            call perror

            xor eax, eax
            not eax

        .end:
            pop rbp
            ret


    ; int sumFile(char* buffer);
    sumFile:
        push rbp
        push r15
        push r14
        push r13
        push r12
        push rbx
        
        ; Get line length (including newline).
        xor rcx, rcx
        not rcx

        .loop:
            inc rcx
            mov dl, 10
            mov al, [rdi + rcx]
            cmp al, dl
            jne .loop

        inc rcx

        ; Scan string for digit.
        ; Do not need to account for the first character based on input.
        ; Need pointers to beginning and end of memory block.

        xor rbx, rbx            ; Sum.
        mov r12, rdi            ; First char.
        mov r13, rcx            ; Line len.

        .next:
            call scanNumber

            test rax, rax
            jz .end

            mov r14, rsi            ; Current first digit.
            mov r15, rdi            ; Current last digit.
            push rax                ; Current value.

            ; Check if line above.
            mov rcx, r14
            dec rcx
            sub rcx, r12
            cmp rcx, r13
            jl .left
            
            ; Scan line above.
            mov rcx, r15
            sub rcx, r14
            add rcx, 3
            mov rdi, r14
            dec rdi
            sub rdi, r13

            .loop1:
                cmp byte [rdi], '.'
                je .inc
                
                cmp byte [rdi], 10
                je .inc
                jmp .found

                .inc:
                    inc rdi
                    loop .loop1

            ; Scan left.
            .left:
                cmp byte [r14 - 1], '.'
                je .right

                cmp byte [r14 - 1], 10
                jne .found

            ; Scan right.
            .right:
                cmp byte [r15 + 1], '.'
                je .below

                cmp byte [r15 + 1], 10
                jne .found

            ; Scan line below.
            .below:
                mov rcx, r12
                add rcx, [filesize]
                sub rcx, r15
                cmp rcx, r13
                jl .notFound
                
                mov rcx, r15
                sub rcx, r14
                add rcx, 3
                mov rdi, r14
                dec rdi
                add rdi, r13

                .loop2:
                    cmp byte [rdi], '.'
                    je .inc1
                    
                    cmp byte [rdi], 10
                    je .inc1
                    jmp .found

                    .inc1:
                        inc rdi
                        loop .loop2

                jmp .notFound

        .found:
            pop rax
            add rbx, rax
            mov rdi, r15
            inc rdi
            jmp .next

        .notFound:
            pop rax
            mov rdi, r15
            inc rdi
            jmp .next
            
        .end:
            mov rax, rbx
            pop rbx
            pop r12
            pop r13
            pop r14
            pop r15
            pop rbp
            ret

    ; int scanNumber(char* findNumStr);
    ; Returns value in rax, first digit ptr in rsi, last digit in rdi.
    scanNumber:
        push rbp

        xor rax, rax
        xor rcx, rcx
        xor rdx, rdx
        xor r8, r8
        xor r11, r11
        dec rdi

        ; Find first digit.
        .loop:
            inc rdi
            mov al, [rdi]

            test al, al
            jz .error

            sub al, '0'
            test al, al
            js .loop

            cmp al, 10
            jge .loop

        mov rsi, rdi

        ; Count digits.
        .loop1:
            mov al, [rdi + rcx]
            sub al, '0'
            test al, al
            js .done

            cmp al, 10
            jge .done

            inc rcx
            jmp .loop1

        .done:
            ; Number of digits = rcx + 1.
            ; Position of first digit = rdi.
            mov r8b, [rdi]
            sub r8b, '0'

            mov rax, 1
            mov r9, 10
            mov r10, rcx
            dec r10

            .square:
                test r10, r10
                jz .out

                mul r9
                dec r10
                jmp .square

            .out:
                mul r8

            add r11, rax
            dec rcx
            test rcx, rcx
            jz .finish

            inc rdi
            jmp .done

        .finish:
            mov rax, r11
            jmp .end
            
        .error:
            xor rax, rax

        .end:
            pop rbp
            ret


; End of file.