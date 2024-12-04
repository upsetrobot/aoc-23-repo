;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Advent of Code Christmas Challenge Day 1 - Part II
;
; @brief    Take an input file and scan each line for first and last integers
;           and adds them together and prints the sum. Include strings that 
;           spell out single-digit numbers in calculation.
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



; Global uninitialized variables.
section .bss

    fd:         resd    1
    stat_buf:   resb    sb_size
    filesize:   resq    1
    buf_ptr:    resq    1


; Global initialized variables.
section .data

    msg         db  "Total Sum: %d", 10, 0
    error_msg   db  "Error", 0
    filename    db  "input.txt", 0


section .text

    global main
    extern printf
    extern perror
    extern malloc
    extern free

    main:
        push rbp

        call getFile

        test eax, eax
        js .error

        mov rcx, [buf_ptr]
        xor r8, r8

        .loop:
            mov rdi, rcx
            call getNextLine

            test rax, rax
            jz .lastLine

            push rax

            call getSumOfLine
            
            pop rcx
            add r8, rax
            jmp .loop

        .lastLine:
            call getSumOfLine
            
            add r8, rax

        mov rdi, msg
        mov esi, r8d
        call printf 

        mov rdi, [buf_ptr]
        call free
        jmp .end

        .error:
            mov rdi, [buf_ptr]
            call free

            xor rax, rax
            not eax

        .end:
            pop rbp
            ret


    ; ret 0 on success; else ret -1.
    getFile:
        push rbp

        ; Open file.
        ; int open(const char *pathname, int flags, mode_t mode);
        mov rdi, filename
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


    ; int getSumOfLine(char* line);
    getSumOfLine:
        push rbp

        xor rax, rax
        xor rcx, rcx
        xor rdx, rdx
        not rcx

        .findFirst:

            inc rcx
            mov al, [rdi + rcx]

            test al, al
            jz .error

            cmp al, 'o'
            je .checkOne

            cmp al, 't'
            je .checkTwoThree

            cmp al, 'f'
            je .checkFourFive

            cmp al, 's'
            je .checkSixSeven

            cmp al, 'e'
            je .checkEight

            cmp al, 'n'
            je .checkNine

            sub al, '0'
            js .findFirst

            cmp al, 10
            jge .findFirst
            jmp .done

            .checkOne:
                cmp byte [rdi + rcx + 1], 'n'
                jne .findFirst

                cmp byte [rdi + rcx + 2], 'e'
                jne .findFirst

                mov al, 1
                jmp .done

            .checkTwoThree:
                cmp byte [rdi + rcx + 1], 'w'
                jne .checkThree

                cmp byte [rdi + rcx + 2], 'o'
                jne .findFirst

                mov al, 2
                jmp .done

            .checkThree:
                cmp byte [rdi + rcx + 1], 'h'
                jne .findFirst

                cmp byte [rdi + rcx + 2], 'r'
                jne .findFirst

                cmp byte [rdi + rcx + 3], 'e'
                jne .findFirst

                cmp byte [rdi + rcx + 4], 'e'
                jne .findFirst

                mov al, 3
                jmp .done

            .checkFourFive:
                cmp byte [rdi + rcx + 1], 'o'
                jne .checkFive

                cmp byte [rdi + rcx + 2], 'u'
                jne .findFirst

                cmp byte [rdi + rcx + 3], 'r'
                jne .findFirst

                mov al, 4
                jmp .done

            .checkFive:
                cmp byte [rdi + rcx + 1], 'i'
                jne .findFirst

                cmp byte [rdi + rcx + 2], 'v'
                jne .findFirst

                cmp byte [rdi + rcx + 3], 'e'
                jne .findFirst

                mov al, 5
                jmp .done

            .checkSixSeven:
                cmp byte [rdi + rcx + 1], 'i'
                jne .checkSeven

                cmp byte [rdi + rcx + 2], 'x'
                jne .findFirst

                mov al, 6
                jmp .done

            .checkSeven:
                cmp byte [rdi + rcx + 1], 'e'
                jne .findFirst

                cmp byte [rdi + rcx + 2], 'v'
                jne .findFirst

                cmp byte [rdi + rcx + 3], 'e'
                jne .findFirst

                cmp byte [rdi + rcx + 4], 'n'
                jne .findFirst

                mov al, 7
                jmp .done

            .checkEight:
                cmp byte [rdi + rcx + 1], 'i'
                jne .findFirst

                cmp byte [rdi + rcx + 2], 'g'
                jne .findFirst

                cmp byte [rdi + rcx + 3], 'h'
                jne .findFirst

                cmp byte [rdi + rcx + 4], 't'
                jne .findFirst

                mov al, 8
                jmp .done

            .checkNine:
                cmp byte [rdi + rcx + 1], 'i'
                jne .findFirst

                cmp byte [rdi + rcx + 2], 'n'
                jne .findFirst

                cmp byte [rdi + rcx + 3], 'e'
                jne .findFirst

                mov al, 9
                jmp .done

            .done:
                mov dl, 10
                imul dl

        .findlast:
            .loop:
                cmp byte [rdi + rcx], 0
                je .out

                inc rcx
                jmp .loop

            .out:
                dec rcx
                mov dl, [rdi + rcx]

                cmp dl, 'e'
                je .check1359

                cmp dl, 'o'
                je .check2

                cmp dl, 'r'
                je .check4

                cmp dl, 'x'
                je .check6

                cmp dl, 'n'
                je .check7

                cmp dl, 't'
                je .check8

                sub dl, '0'
                js .out

                cmp dl, 10
                jge .out
                jmp .doneLast

                .check1359:
                    cmp byte [rdi + rcx - 1], 'n'
                    jne .check35

                    cmp byte [rdi + rcx - 2], 'o'
                    jne .check9

                    mov dl, 1
                    jmp .doneLast

                .check35:
                    cmp byte [rdi + rcx - 1], 'e'
                    jne .check5

                    cmp byte [rdi + rcx - 2], 'r'
                    jne .out

                    cmp byte [rdi + rcx - 3], 'h'
                    jne .out

                    cmp byte [rdi + rcx - 4], 't'
                    jne .out

                    mov dl, 3
                    jmp .doneLast

                .check5:
                    cmp byte [rdi + rcx - 1], 'v'
                    jne .out

                    cmp byte [rdi + rcx - 2], 'i'
                    jne .out

                    cmp byte [rdi + rcx - 3], 'f'
                    jne .out

                    mov dl, 5
                    jmp .doneLast

                .check9:

                    cmp byte [rdi + rcx - 2], 'i'
                    jne .out

                    cmp byte [rdi + rcx - 3], 'n'
                    jne .out

                    mov dl, 9
                    jmp .doneLast

                .check2:
                    cmp byte [rdi + rcx - 1], 'w'
                    jne .out

                    cmp byte [rdi + rcx - 2], 't'
                    jne .out

                    mov dl, 2
                    jmp .doneLast

                .check4:
                    cmp byte [rdi + rcx - 1], 'u'
                    jne .out

                    cmp byte [rdi + rcx - 2], 'o'
                    jne .out

                    cmp byte [rdi + rcx - 3], 'f'
                    jne .out

                    mov dl, 4
                    jmp .doneLast                

                .check6:
                    cmp byte [rdi + rcx - 1], 'i'
                    jne .out

                    cmp byte [rdi + rcx - 2], 's'
                    jne .out

                    mov dl, 6
                    jmp .doneLast

                .check7:
                    cmp byte [rdi + rcx - 1], 'e'
                    jne .out

                    cmp byte [rdi + rcx - 2], 'v'
                    jne .out

                    cmp byte [rdi + rcx - 3], 'e'
                    jne .out

                    cmp byte [rdi + rcx - 4], 's'
                    jne .out

                    mov dl, 7
                    jmp .doneLast

                .check8:
                    cmp byte [rdi + rcx - 1], 'h'
                    jne .out

                    cmp byte [rdi + rcx - 2], 'g'
                    jne .out

                    cmp byte [rdi + rcx - 3], 'i'
                    jne .out

                    cmp byte [rdi + rcx - 4], 'e'
                    jne .out

                    mov dl, 8

                .doneLast:
                    add al, dl
                    jmp .end

        .error:
            xor rax, rax

        .end:
            pop rbp
            ret


; End of file.