;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Advent of Code Christmas Challenge Day 9 - Part I
;
; @brief    Find the sum of the projection for each line of numbers.
;
;           I tried Newton's interpolation, but that turned out more complex 
;           than my own idea due to the fact that the problem is a simplified 
;           polynomial equation finder questions given points (and simpler 
;           because they are just one point from each other). My method is 
;           not the best, but it cuts out some of the middle of the triangle.
;
;           If the part II turns out to be do the same thing for some point 
;           farther away, then something like interpolation to get the 
;           equation may be needed.
;
; @file         solution.nasm
; @date         10 Dec 2023
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
%define NULL            0

%define TRUE    1
%define FALSE   0

%define MAX_INT_STR_LEN 21

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

    filename                db  "input.txt", 0
    err_main                db  "Error Main", 10, 0
    err_main_len            equ $ - err_main

    err_getFile             db  "Error getFile", 10, 0
    err_getFile_len         equ $ - err_getFile
    
    err_getLine             db  "Error getLine", 10, 0
    err_getLine_len         equ $ - err_getLine
    
    err_scanNumber          db  "Error scanNumber", 10, 0
    err_scanNumber_len      equ $ - err_scanNumber

    err_getSolution         db  "Error getSolution", 10, 0
    err_getSolution_len     equ $ - err_getSolution
    
    msg             db  "Solution: ", 0
    msg_len         equ $ - msg

    nl              db  10, 0
    nl_len          equ $ - nl


; Global uninitialized variables.
section .bss

    stat_buf:   resb    sb_size
    filesize:   resq    1
    file_buf:   resq    1
    num_str:    resb    MAX_INT_STR_LEN


; Global initialized variables.
section .data

    ; test:   db ""


; Code.
section .text

    global main

    ; Main function.
    main:
        push rbp
        mov rbp, rsp

        mov rdi, filename
        call getFile

        test eax, eax
        js .err

        mov rdi, [file_buf]
        call getSolution

        mov rdi, rax
        mov rsi, 1
        call numToStr

        mov rdi, msg
        xor rsi, rsi
        call print

        mov rdi, num_str
        xor rsi, rsi
        inc sil
        call print

        xor rax, rax
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


    ; int getFile(char* filename);
    ; ret 0 on success; else ret -1.
    getFile:
        push rbp
        mov rbp, rsp
        push r12

        ; Open file.
        ; int open(const char *pathname, int flags, mode_t mode);
        xor esi, esi
        mov rdx, 0777
        mov rax, SYS_OPEN
        syscall

        test eax, eax
        js .err

        mov r12d, eax                   ; fd.

        ; Get filesize.
        ; int stat(const char *pathname, struct stat *statbuf);
        mov rdi, filename
        mov rsi, stat_buf
        mov rax, SYS_STAT
        syscall

        test eax, eax
        js .errClose

        mov rax, [stat_buf + sb.st_size] 
        mov [filesize], rax

        ; Reserve memory.
        ; void *malloc(size_t size);
        mov rdi, rax
        inc rdi
        ; call malloc
        call memAlloc

        test rax, rax
        jz .errClose

        mov [file_buf], rax

        ; Read file into memory.
        ; ssize_t read(int fd, void *buf, size_t count);
        mov edi, r12d
        mov rsi, rax
        mov rdx, [filesize]
        mov rax, SYS_READ
        syscall

        test rax, rax
        js .errClose

        ; Null terminate memory.
        mov rax, [file_buf]
        add rax, [filesize]
        mov byte [rax], 0

        ; Close file.
        ; int close(int fd);
        mov edi, r12d
        mov rax, SYS_CLOSE
        syscall

        test eax, eax
        js .err

        xor rax, rax
        jmp .end

        .errClose:
            mov edi, r12d
            mov rax, SYS_CLOSE
            syscall

        .err:
            mov rdi, STDERR
            mov rsi, err_getFile
            mov rdx, err_getFile_len
            mov rax, SYS_WRITE
            syscall

            or rax, FUNC_FAILURE

        .end:
            pop r12
            leave
            ret

    ; End getFile.


    ; size_t getSolution(char* fileBuffer);
    getSolution:
        push rbp
        mov rbp, rsp
        push rbx
        push r12
        push r13
        push r14
        push r15

        mov r13, rdi                        ; curr_line.
        xor r14, r14                        ; num_arr_len.
        xor r15, r15                        ; sum.

        ; Count numbers to get number to allocate for array.
        .whileNotZero:
            cmp byte [rdi], 10              ; Check for newline.
            je .endWhileNotZero

            cmp byte [rdi], 0               ; Check for null.
            je .endWhileNotZero

            cmp byte [rdi], ' '             ; Check for space.
            jne .dontCount

            inc r14

            .dontCount:
                inc rdi
                jmp .whileNotZero

        .endWhileNotZero:

        ; Allocate array.
        inc r14                              ; num_arr_len.
        mov rdi, r14
        shl rdi, 3
        call memAlloc

        mov rdi, r13
        mov r13, rax                         ; num_arr
        
        .whileLine:
            test rdi, rdi
            jz .endWhileLine

            call getLine

            mov r12, rax                    ; nxt_line.

            ; Scan numbers.
            .whileNum:
                call scanNumber             ; rdi = last digit.

                mov rbx, 0x7fffffffffffffff
                cmp rax, rbx
                je .endWhileNum

                push rax
                inc rdi
                jmp .whileNum

            .endWhileNum:

            ; Fill array.
            mov rcx, r14
            dec rcx

            .fillArr:
                test rcx, rcx
                jl .endFillArr

                pop rax
                mov [r13 + rcx*8], rax
                dec rcx
                jmp .fillArr

            .endFillArr:

            ; Need temp array.
            mov rdi, r14
            shl rdi, 3
            call memAlloc

            mov rdi, rax
            mov rsi, r13
            mov rdx, r14
            call getNxtNum

            add r15, rax
            mov rdi, r12
            jmp .whileLine

        .endWhileLine:

        mov rax, r15

        .end:
            pop r15
            pop r14
            pop r13
            pop r12
            pop rbx
            leave
            ret
    
    ; End getSolution.
    

    ; size_t getNxtNum(size*t temp_arr, size_t* arr, size_t arrLen);
    ; Returns number to add to last element.
    getNxtNum:
        push rbp
        mov rbp, rsp
        push r12
        push r13
        push r14
        push r15

        mov r12, rdi
        mov r13, rsi
        mov r14, rdx

        mov r8, 2                   ; Not used in subord func.
        lea r9, [r13 + r14*8 - 8]   ; Not used in subord func.
        xor r10, r10

        add r10, [r9]

        .whileNotEqual:

            mov rdi, r12
            mov rsi, r13
            mov rdx, r8
            call getBottom

            mov r15, rax

            sub r9, 8
            mov rdi, r12
            mov rsi, r9
            mov rdx, r8
            call getBottom

            add r10, rax

            ; Check for zero.
            test rax, rax
            ; jnz .cont

            ; test r15, r15
            jz .endWhileNotEqual

            .cont:

            inc r8
            jmp .whileNotEqual

        .endWhileNotEqual:
            mov rax, r10
        
        .end:
            pop r15
            pop r14
            pop r13
            pop r12
            leave
            ret

    ; End getNxtNum.


    ; size_t getBottom(size_t* temp_arr, size_t* arr, size_t arr_len);
    getBottom:
        push rbp
        mov rbp, rsp

        xor rcx, rcx

        .copyArr:
            cmp rcx, rdx
            jz .findBottom

            mov rax, [rsi + rcx*8]
            mov [rdi + rcx*8], rax
            inc rcx
            jmp .copyArr

        .findBottom:
            cmp rdx, 1
            je .endFindBottom

            mov rcx, rdx
            dec rcx

            .loop:
                test rcx, rcx
                jz .endLoop

                mov rax, [rdi + rcx*8]
                sub rax, [rdi + rcx*8 - 8]
                mov [rdi + rcx*8], rax
                dec rcx
                jmp .loop

            .endLoop:

            add rdi, 8
            dec rdx
            jmp .findBottom

        .endFindBottom:

        .end:
            leave
            ret
        
    ; End getBottom.

    
    ; char* getNextLine(char* buf);
    ; Returns NULL if no more lines.
    ; Replaces newline with null and returns location of next line.
    ; Outputs: rax = nextline, rdi = currentline, 
    getLine:
        push rbp
        mov rbp, rsp

        xor rcx, rcx

        .loop:

            test rdi, rdi
            jz .err

            cmp byte [rdi + rcx], 0
            je .err

            cmp byte [rdi + rcx], 10
            je .found

            inc rcx
            jmp .loop

        .found:
            mov byte [rdi + rcx], 0

            cmp byte [rdi + rcx + 1], 0
            je .err

            mov rax, rdi
            add rax, rcx
            inc rax
            jmp .end

        .err:
            push rdi
            mov rdi, STDERR
            mov rsi, err_getLine
            mov rdx, err_getFile_len
            mov rax, SYS_WRITE
            syscall

            pop rdi
            xor rax, rax

        .end:
            leave
            ret

    ; End getLine.


    ; size_t scanNumber(char* findNumStr);
    ; Returns value in rax, first digit ptr in rsi, last digit in rdi.
    ; Returns -1 if error (eventhough unsigned which is stupid.)
    scanNumber:
        push rbp
        mov rbp, rsp
        push r12

        xor r12, r12        ; 1 if negative.

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
            jz .err

            sub al, '0'
            test al, al
            js .loop

            cmp al, 10
            jge .loop

        mov rsi, rdi

        ; Count digits.
        .count:
            mov al, [rdi + rcx]
            sub al, '0'
            test al, al
            js .check

            cmp al, 10
            jge .check

            inc rcx
            jmp .count

        ; Check for negative.
        .check:
            cmp byte [rsi - 1], '-'
            jne .parse

            inc r12

        ; Parse digits into value.
        .parse:
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
            jmp .parse

        .finish:
            mov rax, r11

            ; Negative if needed.
            test r12, r12
            jz .end

            xor rcx, rcx
            sub rcx, rax
            mov rax, rcx
            jmp .end
            
        .err:
            push rdi
            push rsi
            
            mov rdi, STDERR
            mov rsi, err_scanNumber
            mov rdx, err_scanNumber_len
            mov rax, SYS_WRITE
            syscall

            pop rsi
            pop rdi                
            or rax, FUNC_FAILURE

            ; adjustment
            shr rax, 1            

        .end:
            pop r12
            leave
            ret

    ; End scanNumber.


    ; char* numToStr(size_t num, bool signed);
    ; Fill buffer with digits based on number (i.e. convert number to str).
    ; Returns pointer to buffer.
    numToStr:
        push rbp
        mov rbp, rsp

        test rdi, rdi
        jz .zero

        xor r8, r8
        mov rax, rdi
        xor rcx, rcx
        mov cl, 10

        .loop:
            test rsi, rsi
            jz .udiv

            cqo
            idiv rcx
            mov r9, rax
            xchg rax, rdx
            cqo
            xor rax, rdx
            sub rax, rdx
            push rax
            mov rax, r9

            jmp .divDone

            .udiv:
                xor rdx, rdx
                div rcx
                push rdx
                
            .divDone:
                inc r8
                test rax, rax
                jz .endLoop
                jmp .loop

        .endLoop:
            xor rcx, rcx

        test rsi, rsi
        jz .loopWrite

        test rdi, rdi
        jns .loopWrite

        xor r9, r9
        mov r9b, '-'
        sub r9b, '0'
        push r9
        inc r8

        .loopWrite:
            cmp rcx, r8
            je .endLoopWrite

            pop rdx
            add dl, '0'
            mov [num_str + rcx], dl
            inc rcx
            jmp .loopWrite

        .endLoopWrite:
            mov byte [num_str + rcx], 0
            jmp .end

        .zero:
            mov byte [num_str], '0'
            mov byte [num_str + 1], 0
            
        .end:
            mov rax, num_str
            leave
            ret

    ; End numToStr.


    ; void print(char*, bool newline);
    print:
        push rbp
        mov rbp, rsp
        push r12
        push r13

        mov r12, rdi
        mov r13, rsi

        call strLen

        mov rdi, STDOUT
        mov rsi, r12
        mov rdx, rax
        mov rax, SYS_WRITE
        syscall

        test r13, r13
        jz .end

        mov rdi, STDOUT
        mov rsi, nl
        mov rdx, nl_len
        mov rax, SYS_WRITE
        syscall

        .end:
            xor rax, rax
            pop r13
            pop r12
            leave
            ret

    ; End print.


    ; int strlen(char*);
    strLen:
        push rbp
        mov rbp, rsp

        xor rcx, rcx
        dec rcx
        xor al, al
        cld
        repne scasb

        not rcx
        lea rax, [rcx-1]

        .end:
            leave
            ret

    ; End strLen.


    ; void* memAlloc(size_t n);
    memAlloc:
        push rbp
        mov rbp, rsp
        push r12
        push rbx

        xor rbx, rbx
        mov rax, SYS_BRK        
        syscall

        mov r12, rdi
        add rdi, rax
        mov rax, SYS_BRK
        syscall

        sub rax, r12

        .end:
            pop rbx
            pop r12
            leave
            ret

    ; End memAlloc.


; End of file.
