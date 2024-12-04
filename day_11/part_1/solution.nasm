;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Advent of Code Christmas Challenge Day 11 - Part I
;
; @brief    Find the sum of the distances between each of the galaxies.
;
; @file         solution.nasm
; @date         11 Dec 2023
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

    nl              db  10
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
        push r12
        push r13
        push r14
        push r15

        mov r12, rdi                    ; buf.
        call expandUniverse

        ; Make list of galaxies.
        mov r12, rax                    ; New expanded universe buffer.
        mov rdi, r12
        xor rcx, rcx

        .whileGalaxies:
            cmp byte [rdi], 0
            je .endWhileGalaxies

            cmp byte [rdi], '#'
            jne .next

            push rdi
            inc rcx

            .next:
                inc rdi
                jmp .whileGalaxies

        .endWhileGalaxies:

        mov r14, rcx                    ; gal_arr_len.
        mov rdi, rcx
        shl rdi, 3
        call memAlloc

        mov r13, rax                    ; gal_arr.
        mov rcx, r14

        .fillGalaxyArr:
            test rcx, rcx
            jz .endFillGalaxyArr

            pop rdi
            mov [r13 + rcx*8 - 8], rdi
            dec rcx
            jmp .fillGalaxyArr

        .endFillGalaxyArr:

        ; For each galaxy, get distance to every other galaxy.
        xor rcx, rcx
        xor r15, r15                    ; sum.

        .forGalaxy:
            cmp rcx, r14
            je .endForGalaxy

            mov rdx, rcx
            inc rdx

            .forOtherGalaxy:
                cmp rdx, r14
                je .endforOtherGalaxy

                push rcx
                push rdx
                mov rdi, [r13 + rcx*8]
                mov rsi, [r13 + rdx*8]
                mov rdx, r12
                call getDistanceBetween

                pop rdx
                pop rcx
                add r15, rax
                inc rdx
                jmp .forOtherGalaxy

            .endforOtherGalaxy:

            inc rcx
            jmp .forGalaxy

        .endForGalaxy:
            mov rax, r15
        
        .end:
            pop r15
            pop r14
            pop r13
            pop r12
            leave
            ret

    ; End getSolution.


    ; char* expandUniverse(char* universe);
    ; Returns new universe.
    expandUniverse:
        push rbp
        mov rbp, rsp
        push r12
        push r13
        push r14
        push r15

        mov r12, rdi                        ; curr_uni.

        ; Allocate universe 4 times big.
        ; Get size of universe.
        call strLen

        mov r13, rax                        ; uni_sz.
        inc r13
        mov rdi, r13
        shl rdi, 2
        call memAlloc

        mov r14, rax                        ; new_uni_1.

        mov rdi, r13
        shl rdi, 2
        call memAlloc

        mov r15, rax                        ; new_uni_2.
        
        ; Get line_len.
        mov rdi, r12
        xor rcx, rcx
        dec rcx
        mov al, 10
        cld
        repne scasb
        not rcx
        mov r8, rcx                         ; line_len.
        mov rdi, r12
        mov rsi, r14
        xor r9, r9                          ; num_lines.

        .expandRows:
            xor rdx, rdx                    ; expand_flag.
            inc r9

            .forLine:
                mov al, [rdi]
                test al, al
                jz .endExpandRows

                mov [rsi], al
                cmp al, 10
                je .endForLine

                cmp al, '#'
                jne .dontSetExpand

                inc rdx

                .dontSetExpand:
                    inc rdi
                    inc rsi
                    mov al, [rdi]
                    jmp .forLine

            .endForLine:

            inc rdi
            inc rsi
            test rdx, rdx
            jnz .expandRows

            .addRow:
                xchg rdi, rsi
                mov rcx, r8
                dec rcx
                mov al, '.'
                cld
                repnz stosb
                inc r9
                mov byte [rdi], 10
                inc rdi
                xchg rdi, rsi
                jmp .expandRows

        .endExpandRows:

        mov r10, r14
        dec r10

        .expandColumns:

            ; Scan column.
            inc r10
            mov rdi, r10
            cmp byte [rdi], 10
            je .endExpandColumns

            xor rcx, rcx
            xor rdx, rdx                        ; expand_flag.
            not rdx

            .forCol:
                cmp rcx, r9
                je .endForCol

                cmp byte [rdi], '#'
                jne .dontSetExpandCols

                xor rdx, rdx

                .dontSetExpandCols:
                    add rdi, r8
                    inc rcx
                    jmp .forCol

            .endForCol:

            test rdx, rdx
            jz .expandColumns

            ; Mark column.
            xor rcx, rcx
            mov rdi, r10

            .markCols:
                cmp rcx, r9
                je .expandColumns

                mov byte [rdi], 'X'
                add rdi, r8
                inc rcx
                jmp .markCols

        .endExpandColumns:

        mov rdi, r14
        mov rsi, r15

        .getUniverse:
            mov al, [rdi]
            test al, al
            jz .endGetUniverse

            cmp al, 'X'
            jne .copy

            mov byte [rsi], '.'
            inc rsi
            mov byte [rsi], '.'
            inc rsi
            inc rdi
            jmp .getUniverse

            .copy:
                mov [rsi], al
                inc rsi
                inc rdi
                jmp .getUniverse

        .endGetUniverse:

        mov rax, r15

        .end:
            pop r15
            pop r14
            pop r13
            pop r12
            leave
            ret

    ; End expandUniverse.


    ; size_t getDistanceBetween(char* galaxy_1, char* galaxy_2, char* buf);
    getDistanceBetween:
        push rbp
        mov rbp, rsp

        mov r8, rdi
        mov r9, rdx

        mov rdi, r9
        xor rcx, rcx
        not rcx
        mov al, 10
        cld
        repne scasb
        not rcx                         ; line_len (including \n).
        mov r11, rcx

        mov rax, rsi
        sub rax, r8
        xor rdx, rdx
        div rcx                
        mov r10, rdx                    ; delta_x.

        ; Check for right or left.
        xor rcx, rcx
        xor rax, rax
        inc rcx
        inc rax

        .checkNewLine:
            cmp byte [r8 + rcx], 10
            je .checkNewLine2

            cmp byte [r8 + rcx], 0
            je .checkNewLine2

            inc rcx
            jmp .checkNewLine

        .checkNewLine2:
            cmp byte [rsi + rax], 10
            je .endCheckNewLine

            cmp byte [rsi + rax], 0
            je .endCheckNewLine

            inc rax
            jmp .checkNewLine

        .endCheckNewLine:

        cmp rax, rcx
        jle .dontInvert

        mov rdx, r11
        sub rdx, r10
        mov r10, rdx

        .dontInvert:

        mov rdi, r8
        xor rdx, rdx
        
        .countNewlines:
            cmp rdi, rsi
            jge .endCountNewlines

            cmp byte [rdi], 10
            jne .cont

            inc rdx

            .cont:
                inc rdi
                jmp .countNewlines
            

        .endCountNewlines:

        mov rax, rdx
        add rax, r10

        .end:
            leave
            ret

    ; End getDistanceBetween.

    
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
