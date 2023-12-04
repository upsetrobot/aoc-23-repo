;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Advent of Code Christmas Challenge Day 4 - Part II
;
; @brief    Take an input file and sum all cards which each given more cards 
;           based on number of winning numbers and print the sum.
;
; @file         solution.nasm
; @date         04 Dec 2023
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
        push r12
        push r13
        push r14
        
        mov r12, 117        ; Line length (including newline)
        mov r13, rdi        ; Base ptr.
        xor r14, r14        ; Score.
        xor rcx, rcx        ; Index.

        .loop:
            mov rax, r12
            imul rcx
            mov rdi, r13
            add rdi, rax

            push rcx        ; Save index.

            call getSumOfLine

            pop rcx
            push rcx

            .innerLoop:
                test rax, rax
                jz .out

                inc rcx
                jmp .loop





            .out:
                inc r14

            





        .loop:
            call getNextLine

            test rax, rax
            jz .lastLine

            mov r13, rax
            call getSumOfLine

            add r12, rax
            mov rdi, r13
            jmp .loop

        .lastLine:
            call getSumOfLine
            add r12, rax
            mov rax, r12
            
        .end:
            pop r12
            pop r13
            pop rbp
            ret

    ; int getSumOfLine(char* line);
    getSumOfLine:
        push rbp
        push r12        ; Current winning number.
        push r13        ; Number of winning numbers available.
        push r14        ; Next winning number position.
        push r15        ; Count of wins.

        ; There are 10 winning numbers.
        ; There are 25 player numbers.
        ; There are no zeros.
        ; Assuming only one match matters.
        add rdi, 9
        mov r13, 10
        xor r15, r15

        .outerLoop:
            test r13, r13
            jz .out

            call scanNumber
            
            mov r14, rdi
            inc r14
            mov r12, rax

            mov rcx, 116
            mov al, '|'
            cld 
            repne scasb
            
            .innerLoop:
                cmp byte [rdi], 10
                je .done

                call scanNumber

                cmp rax, r12
                je .win

                inc rdi
                jmp .innerLoop

            .win:
                inc r15

            .done:
                mov rdi, r14
                dec r13
                jmp .outerLoop

        .out:
            xor rax, rax
            mov rcx, r15
            stc
            rcl rax, cl
            jmp .end

        .error:
            xor rax, rax

        .end:
            pop r15
            pop r14
            pop r13
            pop r12
            pop rbp
            ret


    ; char* getNextLine(char* buf);
    ; Returns 0 if no more lines.
    getNextLine:
        push rbp

        xor rcx, rcx

        .loop:

            cmp byte [rdi + rcx], 0
            je .error

            cmp byte [rdi + rcx], 10
            je .found

            inc rcx
            jmp .loop

        .found:
            mov byte [rdi + rcx], 0

            cmp byte [rdi + rcx + 1], 0
            je .error

            mov rax, rdi
            add rax, rcx
            inc rax
            jmp .end

        .error:
            xor rax, rax

        .end:
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