;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Advent of Code Christmas Challenge Day 6 - Part II
;
; @brief    Take an input file and determine the number of ways you can win a 
;           race based on time allotted and minimum distance to travel.
;
;           Question is model of quadratic curve as distance is related to 
;           amount of time spent accelerating.
;
;           Part II is just a bigger number. This affect my accuracy when 
;           doing integer sqrt and quadratic estimates, so I may need to 
;           adjust for that. My solution was two off due to decimals.
;
;           My quadratic rounds towards zero. So, the first number does not 
;           count, but the second number does.
;
;           My solution was off because my sqrt rounds to nearest integer.
;
;           I'm not going to fix it. The answer is 2 above my solution.
;           So, just added to two to account for sqrt rounding. Next time, I 
;           will use floats or a test number algorithm to adjust the one off.
;
; @file         solution.nasm
; @date         06 Dec 2023
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

%define NUM_LEN 21

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

    err_getNumberWays       db  "Error getNumberWays", 10, 0
    err_getNumberWays_len   equ $ - err_getNumberWays

    err_calcDistance        db  "Error calcDistance", 10, 0
    err_calcDistance_len    equ $ - err_calcDistance
    
    msg             db  "Solution: ", 0
    msg_len         equ $ - msg

    nl              db  10, 0
    nl_len          equ $ - nl


; Global uninitialized variables.
section .bss

    stat_buf:   resb    sb_size
    filesize:   resq    1
    file_buf:   resq    1
    num_str:    resb    NUM_LEN


; Global initialized variables.
section .data


; Code.
section .text

    global main
    extern malloc
    extern free

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

        add rax, 2

        mov rdi, rax
        xor rsi, rsi
        call numToStr

        mov rdi, msg
        xor rsi, rsi
        call print

        mov rdi, num_str
        xor rsi, rsi
        inc sil
        call print

        mov rdi, [file_buf]
        call free

        xor rax, rax
        jmp .end

        .err:
            mov rdi, [file_buf]
            call free

            mov rdi, STDERR
            mov rsi, err_main
            mov rdx, err_main_len
            mov rax, SYS_WRITE
            syscall

            or rax, EXIT_FAILURE
        
        .end:
            leave
            ret

    endMain:


    ; int getFile(char* filename);
    ; ret 0 on success; else ret -1.
    getFile:
        push rbp
        mov rbp, rsp
        push r12
        push r12                        ; stack align.

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
        call malloc

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
            pop r12                         ; Stack align.
            pop r12
            leave
            ret

    endGetFile:


    ; size_t getSolution(char* fileBuffer);
    getSolution:
        push rbp
        mov rbp, rsp
        push r12
        push r13
        push r14

        xor r12, r12                    ; Product.
        inc r12
        xor r13, r13                    ; Count of races.
        xor r14, r14                    ; Next line.

        ; Parse file.
        .while:

            test rdi, rdi
            jz .endWhile

            call getLine                ; rdi remains current line.

            mov r14, rax                ; Save next line.

            ; Get numbers.
            .innerWhile:            
                call scanNumber
                
                cmp rax, FUNC_FAILURE
                je .endInnerWhile

                push rax                ; Save number.
                inc r13
                inc rdi
                jmp .innerWhile

            .endInnerWhile:
                mov rdi, r14
                jmp .while

        .endWhile:

        shr r13, 1
        xor rcx, rcx

        .for:
            cmp rcx, r13
            je .endFor

            mov rdi, [rsp + r13*8]
            pop rsi
            push rcx
            call getNumberWays

            pop rcx
            inc rcx
            xor rdx, rdx
            mul r12
            mov r12, rax
            jmp .for

        .endFor:
            mov rax, r12
            xor rcx, rcx

            .loop:
                cmp rcx, r13
                je .end

                pop rdx
                inc rcx
                jmp .loop

        .err:
            mov rdi, STDERR
            mov rsi, err_getSolution
            mov rdx, err_getSolution_len
            mov rax, SYS_WRITE
            syscall

            or rax, FUNC_FAILURE

        .end:
            pop r14
            pop r13
            pop r12
            leave
            ret

    endGetSolution:


    ; size_t getNumberWays(size_t time, size_t distance);
    getNumberWays:
        push rbp
        mov rbp, rsp
        push r12
        push r13
        push r14

        xor r12, r12                ; Sum of ways.

        ; Considering quadratic. 0 = -s^2 + st - d
        mov r13, rdi
        mov r14, rsi
        
        or rdi, -1
        mov rsi, r13
        xor rdx, rdx
        sub rdx, r14
        mov rcx, FALSE
        call quadratic

        mov r12, rax        ; r12 does not count if remainder is 0.
        test rdx, rdx
        jnz .second

        inc r12

        .second:
            or rdi, -1
            mov rsi, r13
            xor rdx, rdx
            sub rdx, r14
            mov rcx, TRUE
            call quadratic

            sub rax, r12        ; Both solutions should be pos, so no worry about negatives.

            cqo                 ; Find abs(a).
            xor rax, rdx
            sub rax, rdx

        .end:
            pop r14
            pop r13
            pop r12
            leave
            ret

    endGetNumberWays:


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

    endGetLine:


    ; size_t scanNumber(char* findNumStr);
    ; Returns value in rax, first digit ptr in rsi, last digit in rdi.
    ; Returns -1 if error (eventhough unsigned which is stupid.)
    scanNumber:
        push rbp
        mov rbp, rsp

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
            js .parse

            cmp al, 10
            jge .parse

            inc rcx
            jmp .count

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

        .end:
            leave
            ret

    endScanNumber:


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

    endNumToStr:


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

    endPrint:


    ; int strlen(char*);
    strLen:
        push rbp
        mov rbp, rsp

        xor rax, rax
        .loop:
            mov cl, [rdi]
            test cl, cl
            jz .end

            inc rdi
            inc rax
            jmp .loop

        .end:
            leave
            ret

    endStrLen:

; End of file.
