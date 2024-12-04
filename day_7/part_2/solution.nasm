;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Advent of Code Christmas Challenge Day 7 - Part II
;
; @brief    Take an input file and the rank of each hand and multiply that by 
;           the hands bid and return of the sum of the values.
;
;           Decided to use a naive n2 algorithm, which is fine, instead of a 
;           sorting algorithm which would get closer to n log n.
;
;           Js are now wild and lowest value.
;
; @file         solution.nasm
; @date         07 Dec 2023
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

struc camel_card_hand

    .cc_card_one:   resb    1
    .cc_card_two:   resb    1
    .cc_card_three: resb    1
    .cc_card_four:  resb    1
    .cc_card_five:  resb    1
    .cc_bid:        resq    1
    .cc_score:      resq    1
    .cc_rank:       resq    1
    .cc_pad:        resb    3

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

    test:   db 1, 1, 1, 1, 1
            dq 777, 0, 0
            db 0, 0, 0


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
        xor rsi, rsi
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
            pop r12                         ; Stack align.
            pop r12
            leave
            ret

    endGetFile:


    ; ; size_t getSolution(char* fileBuffer);
    getSolution:
        push rbp
        mov rbp, rsp
        push r12                        ; Count of hands.
        push r13                        ; Hand buffer.
        push r14                        ; Next line.
        push r15                        ; Current hand.

        ; Let's convert to binary.
        ; Count lines.
        xor rcx, rcx    ; i.
        xor rdx, rdx    ; count.
        xor r15, r15    ; Current hand.


        .countLines:
            mov al, [rdi + rcx]
            test al, al
            jz .endCountLines

            cmp al, 10
            jne .notNewLine

            inc rdx

            .notNewLine:
                inc rcx
                jmp .countLines

        .endCountLines:
            inc rdx     ; For the last line.
            mov r12, rdx

            ; Allocate structs.
            mov rax, rdx
            xor rdx, rdx
            mov rcx, camel_card_hand_size
            mul rcx
            push rdi
            mov rdi, rax
            call memAlloc

            mov r13, rax                ; buffer pointer.
            pop rdi
        
        ; Parse file.
        .while:

            test rdi, rdi
            jz .endWhile

            call getLine                ; rdi remains current line.

            mov r14, rax                ; Save next line.
            xor rcx, rcx
            xor rdx, rdx
            mov rax, camel_card_hand_size
            mul r15
            mov r10, rax

            ; Get numbers.
            .innerWhile:

                cmp cl, 5
                je .endInnerWhile
                
                ; Parse line.
                mov dh, byte [rdi + rcx]
                cmp dh, 'A'
                je .ace

                cmp dh, 'K'
                je .king

                cmp dh, 'Q'
                je .queen

                cmp dh, 'J'
                je .joker

                cmp dh, 'T'
                je .ten

                sub dh, '0'
                jmp .move

                .ace:
                    mov dh, 14
                    jmp .move
                    
                .king:
                    mov dh, 13
                    jmp .move
                    
                .queen: 
                    mov dh, 12
                    jmp .move
                    
                .joker:
                    mov dh, 1
                    jmp .move

                .ten:
                    mov dh, 10

                .move:
                    mov rax, r10
                    add ax, cx
                    mov dl, dh
                    mov [r13 + rax], dl
                    inc cl
                    jmp .innerWhile

            .endInnerWhile:
                push r10
                add rdi, 5
                call scanNumber

                pop r10
                push r10
                mov [r13 + r10 + camel_card_hand.cc_bid], rax
                lea rdi, [r13 + r10]
                call getHandGrade

                pop r10
                mov [r13 + r10 + camel_card_hand.cc_score], rax
                mov qword [r13 + r10 + camel_card_hand.cc_rank], 1
                mov rdi, r14
                inc r15
                jmp .while

        .endWhile:

        ; File parsed. Now need to rank hands.
        xor r15, r15            ; Current hand.
        xor rcx, rcx            ; Current second hand.

        .for:
            cmp r15, r12
            je .endFor

            xor rdx, rdx
            mov rax, camel_card_hand_size
            mul r15
            mov r10, rax            ; Current hand offset.
            xor rcx, rcx

            .innerFor:
                cmp rcx, r12
                je .endInnerFor

                xor rdx, rdx
                mov rax, camel_card_hand_size
                mul rcx
                mov r11, rax            ; Second hand offset.

                cmp r15, rcx
                je .same 

                mov rax, [r13 + r10 + camel_card_hand.cc_score]
                cmp rax, [r13 + r11 + camel_card_hand.cc_score]
                je .equal
                jl .same

                inc qword [r13 + r10 + camel_card_hand.cc_rank]
                jmp .same
                xor rdx, rdx

                .equal:
                    cmp dl, 5
                    je .same

                    mov rsi, r10
                    add rsi, rdx
                    mov r8, r11
                    add r8, rdx
                    mov al, [r13 + rsi]
                    cmp al, [r13 + r8]
                    jl .same

                    cmp al, [r13 + r8]
                    je .sameCard

                    inc qword [r13 + r10 + camel_card_hand.cc_rank]
                    jmp .same

                    .sameCard:
                        inc dl
                        jmp .equal

                .same:
                    inc rcx
                    jmp .innerFor

            .endInnerFor:
                inc r15
                jmp .for

        .endFor:
            ; Now sum all winnings.
            xor rcx, rcx
            xor r8, r8

        .loop:
            cmp rcx, r12
            je .end

            xor rdx, rdx
            mov rax, camel_card_hand_size
            mul rcx
            mov r11, rax            ; Hand offset.

            xor rdx, rdx
            mov rax, [r13 + r11 + camel_card_hand.cc_bid]
            mul qword [r13 + r11 + camel_card_hand.cc_rank]
            add r8, rax
            inc rcx
            jmp .loop
            
        .end:
            mov rax, r8
            pop r15
            pop r14
            pop r13
            pop r12
            leave
            ret

    endGetSolution:


    ; size_t getHandGrade(camel_card_hand* hand);
    getHandGrade:
        push rbp
        mov rbp, rsp
        push rbx

        xor rcx, rcx    ; i.
        xor dx, dx      ; count.
        xor r8w, r8w    ; Highest match.
        inc r8w
        xor r9w, r9w    ; Number of ones.
        xor r10, r10    ; Joker present.

        .for:
            cmp cl, 5
            je .endFor

            mov al, [rdi + rcx]
            cmp al, 1
            jne .noJoker

            inc r10

            .noJoker:

            xor rbx, rbx    ; j.
            xor rdx, rdx    ; num_matches.
        
            .innerFor:
                cmp bl, 5
                je .endInnerFor

                mov ah, [rdi + rbx]
                cmp al, ah
                jne .noMatch

                inc dx

                .noMatch:
                    inc bl
                    jmp .innerFor

            .endInnerFor:
                inc cl

                cmp dx, r8w
                cmovg r8w, dx
                cmp dx, 1
                jne .for

                inc r9b
                jmp .for

        .endFor:
            
        ; Check number of matches to assign grade.
        ; no-pair = 1, 1, 1, 1, 1. = 1
        ; pair = 2, 2, 1, 1, 1. = 2
        ; two-pair = 2, 2, 2, 2, 1. = 3
        ; three = 3, 3, 3, 1, 1. = 4
        ; fullhouse = 3, 3, 3, 2, 2. = 5
        ; four = 4, 4, 4, 4, 1. = 6
        ; five = 5, 5, 5, 5, 5 = 7.

        ; with jokers.
        ; 1         2           3           4           5
        ; 1 = 2     np          np          np          np
        ; 2 = 4     2 = 4       np          np          np
        ; 3 = 5     3 = 6       np          np          np
        ; 4 = 6     np          4 = 6       np          np
        ; np        5 = 7       5 = 7       np          np
        ; 6 = 7     np          np          6 = 7       np
        ; np        np          np          np          7 = 7

        xor rax, rax

        cmp r8w, 1
        je .one

        cmp r8w, 2
        je .two

        cmp r8w, 3
        je .three

        cmp r8w, 4
        je .four

        cmp r8w, 5
        je .five
        jmp .end

        .one:
            mov ax, 1
            cmp r10b, 1
            je .add_1
            jmp .end

        .two:
            cmp r9b, 1
            je .score3

            mov ax, 2
            cmp r10b, 1
            jge .add_2
            jmp .end

            .score3:
                mov ax, 3
                cmp r10b, 1
                je .add_2
                cmp r10b, 2
                je .add_3
                jmp .end

        .three:
            cmp r9b, 2
            je .score4

            mov ax, 5
            cmp r10b, 1
            jge .add_2
            jmp .end

            .score4:
                mov ax, 4
                cmp r10b, 1
                jge .add_2
                jmp .end

        .four:
            mov ax, 6
            cmp r10b, 1
            jge .add_1
            jmp .end

        .five:
            mov ax, 7
            jmp .end

        .add_3:
            inc ax

        .add_2:
            inc ax

        .add_1:
            inc ax

        .end:
            pop rbx
            leave
            ret

    endGetHandGrade:
    

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


    memAlloc:
        push rbp
        mov rbp, rsp
        push r12

        xor rbx, rbx
        mov rax, SYS_BRK        
        syscall

        mov r12, rdi
        add rdi, rax
        mov rax, SYS_BRK
        syscall

        sub rax, r12

        .end:
            pop r12
            leave
            ret

    endMemAlloc:


; End of file.
