;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Advent of Code Christmas Challenge Library
;
; @brief    Collection of custom-written functions for various utilities.
;           Functions are written for x64 unix.
;
;           Includes custom version of:
;               fopen       called getFile  (just returns buffer)
;               getline     called getLine
;               itoa        called numToStr
;               scanf       called scanNumber (just for integers)
;               strlen      called strLen
;               malloc      called memAlloc
;               free        called memDealloc (not dynamic; can only be used 
;                           on last allocation and takes the size)
;
;           Also includes:
;               print
;               quadratic
;               sqrt
;               findLCM
;
; @file         lib.nasm
; @date         12 Dec 2023
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

struc file

    .buffer:    resq    1
    .size:      resq    1

endstruc

; Global constants.
section .rodata

    err_getFile             db  "Error getFile", 10, 0
    err_getFile_len         equ $ - err_getFile
    
    err_getLine             db  "Error getLine", 10, 0
    err_getLine_len         equ $ - err_getLine
    
    err_scanNumber          db  "Error scanNumber", 10, 0
    err_scanNumber_len      equ $ - err_scanNumber

    nl                      db  10, 0
    nl_len                  equ $ - nl


; Global uninitialized variables.
section .bss

    stat_buf:   resb    sb_size
    num_str:    resb    MAX_INT_STR_LEN


; Global initialized variables.
section .data

    ; test:   db ""


; Code.
section .text

    ; file* getFile(char* filename);
    ; 
    ; @brief    Loads a file into a buffer.
    ;
    ;           `file` struct is {void* buffer, size_t filesize}.
    ; 
    ; @return   file*   Returns pointer to `file` struct or returns `NULL` on 
    ;                   failure.
    ;
    getFile:
        push rbp
        mov rbp, rsp
        push r12
        push r13
        push r14

        mov r12, rdi

        ; Open file.
        ; int open(const char *pathname, int flags, mode_t mode);
        xor esi, esi
        mov rdx, 0777
        mov rax, SYS_OPEN
        syscall

        test eax, eax
        js .err

        mov r13d, eax                   ; fd.

        ; Reserve file structure.
        mov rdi, file_size
        call memAlloc

        mov r14, rax                    ; file*.

        ; Get filesize.
        ; int stat(const char *pathname, struct stat *statbuf);
        mov rdi, r12
        mov rsi, stat_buf
        mov rax, SYS_STAT
        syscall

        test eax, eax
        js .errClose

        mov rax, [stat_buf + sb.st_size]
        mov [r14 + file.size], rax

        ; Reserve memory.
        ; void* malloc(size_t size);
        mov rdi, rax
        add rdi, 2
        call memAlloc

        test rax, rax
        jz .errClose

        mov [r14], rax

        ; Read file into memory.
        ; ssize_t read(int fd, void *buf, size_t count);
        mov edi, r13d
        mov rsi, rax
        mov rdx, [r14 + file.size]
        mov rax, SYS_READ
        syscall

        test rax, rax
        js .errClose

        ; Null terminate memory.
        mov rax, [r14]
        mov rcx, [r14 + file.size]
        mov byte [rax + rcx], 0
        mov byte [rax + rcx + 1], 0

        ; Close file.
        ; int close(int fd);
        mov edi, r13d
        mov rax, SYS_CLOSE
        syscall

        test eax, eax
        js .err

        mov rax, r14
        jmp .end

        .errClose:
            mov edi, r13d
            mov rax, SYS_CLOSE
            syscall

        .err:
            mov rdi, STDERR
            mov rsi, err_getFile
            mov rdx, err_getFile_len
            mov rax, SYS_WRITE
            syscall

            xor rax, rax                    ; NULL.

        .end:
            pop r14
            pop r13
            pop r12
            leave
            ret

    ; End getFile.


    ; char* getNextLine(char* buf);
    ; 
    ; @brief    Replaces newline with `NULL` and returns pointer to next line.
    ;
    ; @return   char*   Returns pointer to next line or NULL if no more lines.
    ;
    getLine:
        push rbp
        mov rbp, rsp

        xor rcx, rcx

        test rdi, rdi
        jz .err

        .loop:
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
            xor rax, rax                    ; NULL.

        .end:
            leave
            ret

    ; End getLine.


    ; long long scanNumber(char* string);
    ;
    ; @brief    Scans string for first integer encountered. Parses positive 
    ;           and negative integers.
    ;
    ; @return   long long   Signed integer if found; Returns 
    ;                       0x7FFFFFFFFFFFFFFF if no number was found.
    ;                       Moves rdi to last digit.
    ;
    ; @todo     Find better solution.
    ; @todo     Review and improve implementation.
    ;
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
    ;
    ; @brief    Fill buffer with digits based on number (i.e. convert number 
    ;           to str).
    ;
    ; @return   Returns pointer to buffer.
    ;
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


    ; void print(char* msg, bool newline);
    ;
    ; @brief    Prints the given string to standard out. If the `newline` 
    ;           variable is TRUE, then also prints a newline at the end.
    ; 
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


    ; size_t strlen(char* string);
    ; 
    ; @brief    Counts the length of a NULL-terminated string and returns the 
    ;           length in bytes.
    ;
    ; @return   size_t  Returns the byte-length of the string.
    strLen:
        push rbp
        mov rbp, rsp

        push -1
        pop rcx
        xor al, al
        cld
        repne scasb

        not rcx
        lea rax, [rcx - 1]

        .end:
            leave
            ret

    ; End strLen.


    ; void* memAlloc(size_t n);
    ;
    ; @brief    Allocates `n` bytes of memory and returns the address of the 
    ;           new memory block.
    ;
    ; @return   void*   Returns pointer to memory block.
    ;
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

        cmp rax, r12
        je .err

        sub rax, r12
        jmp .end

        .err:
            xor rax, rax

        .end:
            pop rbx
            pop r12
            leave
            ret

    ; End memAlloc.


    ; size_t memDealloc(size_t n);
    ;
    ; @brief    Deallocates `n` bytes of memory and returns the address of the 
    ;           new memory block.
    ;
    ;           Should only be called to deallocate last allocation, not 
    ;           previous allocations.
    ;
    ; @return   size_t  Returns -1 if error, otherwise returns number of bytes. 
    ;
    memDealloc:
        push rbp
        mov rbp, rsp
        push r12
        push rbx

        push rdi

        xor rbx, rbx
        mov rax, SYS_BRK
        syscall

        pop r12
        mov rsi, rax

        mov rdi, rax
        sub rdi, r12
        mov rax, SYS_BRK
        syscall

        cmp rax, rsi
        je .err

        mov rax, rsi
        jmp .end

        .err:
            or rax, FUNC_FAILURE

        .end:
            pop rbx
            pop r12
            leave
            ret

    ; End memDealloc.


    ; size_t quadratic(size_t a, size_t b, size_t c, bool secondSolution);
    ;
    ; @brief    Computes the integer quadratic solution of a quadratic 
    ;           equation with the given parameters. First solution is given 
    ;           by default. If `secondSolution` is set, then the second root 
    ;           is given.
    ;
    ; @return   size_t  Returns the calculated root.
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
    ;
    ; @brief    Calculates the positive integer square root of the given 
    ;           integer. Answer is rounded to nearest integer.
    ;
    ; @return   size_t  Returns the integer square root.
    ;
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


    ; size_t findLCM(size_t a, size_t b);
    ;
    ; @brief    Returns the least common multiple of the two given integers.
    ;
    ; @return   size_t  Returns the LCM of `a` and `b`.
    findLCM:
        push rbp
        mov rbp, rsp
        push r12
        push r13

        mov r12, rdi        ; a.
        mov r13, rsi        ; b.

        ; Find greater number.
        cmp rdi, rsi
        jge .whileNot0

        xchg rdi, rsi

        ; Find gcf(a, b).
        .whileNot0:
            test rsi, rsi
            jz .endWhileNot0

            cmp rdi, rsi
            jge .cont

            xchg rdi, rsi

            .cont:
                sub rdi, rsi
                jmp .whileNot0
        
        .endWhileNot0:

        ; rdi = gcf.
        mov rax, r12
        xor rdx, rdx
        mul r13
        xor rdx, rdx
        div rdi

        .end:
            pop r13
            pop r12
            leave
            ret

    .endFindLCM:


; End of file.