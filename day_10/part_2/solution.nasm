;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Advent of Code Christmas Challenge Day 10 - Part II
;
; @brief    Find the total number of tiles enclosed by the loop.
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

%define FROM_LEFT   0
%define FROM_RIGHT  1
%define FROM_DOWN   2
%define FROM_UP     3

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
                
        ; Count line length so you can move up and down.
        xor rcx, rcx
        dec rcx
        mov al, 10
        cld 
        repne scasb
        not rcx
        mov r13, rcx                    ; line_len.

        ; Scan buffer to find starting point.
        mov rdi, r12
        xor rcx, rcx
        dec rcx
        mov al, 'S'
        cld
        repne scasb
        dec rdi

        mov r14, rdi                    ; start_loc.

        ; This one was surprisingly hard for.  I come up with two possible 
        ; solution. One is to walk the line and note patterns of direction 
        ; changes and to use the length inbetween angles and the directions 
        ; of the angles to divide all spaces into rectangles and to add up the 
        ; areas. The second option is to get into loop somehow and to scan all 
        ; spaces marking them with a marker following the wall till you get 
        ; back to where you started, then to scan the whole buffer counting 
        ; the markers. There are two challenges with the second approach: one 
        ; is getting in the loop, and two is accounting for hallways with 
        ; no width. I chose to try the second (which is more inefficient but 
        ; seemed like it may be easier to implement).

        ; Step 1, get in the loop. 
        ; If I start at 'S', I can move up, down, left, or right. One of those 
        ; is the loop at least. If I land on an angle connected to the 'S', 
        ; then I am still on the wall. Otherwise, I am in or out of the loop. 
        ; If the 'S' is on a corner, then in is diagonal from or toward the 
        ; angle. It seems like I should follow the wall till I get to 
        ; horizontal or vertical line to avoid that. This method would assume 
        ; that the loop has at least one of horizontal or vertical traversal 
        ; which is fine (or if I cared, I could even error out in that case).
        ; If it is '-', then in is one side and out is the other. Same for '|' 
        ; but it is left or right instead of up or down. 
        ; So, if I scan one side until I find the sides of the map, then I 
        ; need to go back to the location and map the other side. I also will 
        ; need to reset the buffer. Bottom + down > buf + size; right + right 
        ; = \n or null; left + left = \n (or < buf); top + up < buf.
        ; So, I need a loadBuffer func. 
        ; I need a markArea func.
        ; I need a getStart func.
        ; Then, loadBuffer, getStart, (move over), markArea (if fail, 
        ; loadBuffer go back to start and move other over, then markArea again)
        ; and then countMarks. 
        ; Actually, I am gonna need to mark lines as well.
        ; Actually, fuck all that. I'm gonna scan from top and set rules for 
        ; counting which involve corners.

        ; r12, buf.
        ; r13, line_len.
        ; r14, s_loc.

        std

        ; Mark loop.
        mov rdi, r14
        mov rsi, r13
        call markBorder

        ; Start scan. 
        mov rdi, r12
        xor rax, rax
        xor rcx, rcx

        .whileNext:
            cmp byte [rdi], 0
            jz .endWhileNext

            mov cl, byte [rdi]
            cmp cl, '~'
            jb .background

            mov cl, [rdi]
            sub cl, '~'
            cmp cl, '|'
            je .vertical
            
            cmp cl, 'F'
            je .horizTop

            cmp cl, 'L'
            je .horizBottom

            .vertical:
                inc rdi

                .whileInside:
                    mov cl, byte [rdi]
                    cmp cl, '~'
                    jb .mark

                    mov cl, [rdi]
                    sub cl, '~'
                    cmp cl, '|'
                    je .background

                    cmp cl, 'L'
                    je .horizTop

                    cmp cl, 'F'
                    je .horizBottom

                    .mark:
                        inc rdi
                        inc rax
                        jmp .whileInside

                .endWhileInside:

            .horizTop:
                inc rdi

                .whileTop:
                    mov cl, [rdi]
                    sub cl, '~'
                    cmp cl, '-'
                    je .continueTop

                    cmp cl, '7'
                    je .background

                    cmp cl, 'J'
                    je .vertical

                    .continueTop:
                        inc rdi
                        jmp .whileTop

                .endWhileTop:

            .horizBottom:
                inc rdi

                .whileBottom:
                    mov cl, [rdi]
                    sub cl, '~'
                    cmp cl, '-'
                    je .continueBottom

                    cmp cl, '7'
                    je .vertical

                    cmp cl, 'J'
                    je .background

                    .continueBottom:
                        inc rdi
                        jmp .whileBottom

                .endWhileBottom:

            .background:
                inc rdi
                jmp .whileNext

        .endWhileNext:

        .end:
            pop r15
            pop r14
            pop r13
            pop r12
            leave
            ret

    ; End getSolution.


    ; void markBorder(char* start, size_t line_len);
    ; Marks border.
    markBorder:
        push rbp
        mov rbp, rsp

        mov r10, rdi                    ; Start.
        xor rax, rax

        jmp .checkAbove

        .while:
            cmp rdi, r10
            je .endWhile

            cmp byte [rdi], '|'
            je .goUpDown

            cmp byte [rdi], '-'
            je .goLeftRight

            cmp byte [rdi], 'L'
            je .goRightUp

            cmp byte [rdi], 'J'
            je .goLeftUp

            cmp byte [rdi], '7'
            je .goLeftDown

            cmp byte [rdi], 'F'
            je .goRightDown

            .goUpDown:
                cmp r8, FROM_DOWN
                je .up
                jmp .down

            .goLeftRight:
                cmp r8, FROM_LEFT
                je .right
                jmp .left

            .goRightUp:
                cmp r8, FROM_UP
                je .right
                jmp .up

            .goLeftUp:
                cmp r8, FROM_UP
                je .left
                jmp .up

            .goLeftDown:
                cmp r8, FROM_DOWN
                je .left
                jmp .down

            .goRightDown:
                cmp r8, FROM_DOWN
                je .right
                jmp .down

            .checkAbove:
                mov r9, rdi
                sub r9, rsi
                cmp byte [r9], '|'
                je .goingUp

                cmp byte [r9], 'F'
                je .goingUp

                cmp byte [r9], '7'
                je .goingUp
                jmp .checkRight

                .goingUp:
                    cmp byte [rdi + rsi], '|'
                    je .cVert1

                    cmp byte [rdi + rsi], 'L'
                    je .cVert1

                    cmp byte [rdi + rsi], 'J'
                    je .cVert1

                    cmp byte [rdi + 1], '-'
                    je .cL1

                    cmp byte [rdi + 1], 'J'
                    je .cL1

                    cmp byte [rdi + 1], '7'
                    je .cL1

                    cmp byte [rdi - 1], '-'
                    je .cJ1

                    cmp byte [rdi - 1], 'L'
                    je .cJ1

                    cmp byte [rdi - 1], 'F'
                    je .cJ1

                    .cVert1:
                        mov byte [rdi], '|'
                        jmp .up

                    .cL1:
                        mov byte [rdi], 'L'
                        jmp .up

                    .cJ1:
                        mov byte [rdi], 'J'
                        jmp .up

            .checkRight:
                cmp byte [rdi + 1], '-'
                je .goingRight

                cmp byte [rdi + 1], 'J'
                je .goingRight

                cmp byte [rdi + 1], '7'
                je .goingRight
                jmp .checkBelow

                .goingRight:
                    mov r9, rdi
                    sub r9, rsi
                    cmp byte [r9], '|'
                    je .cVert2

                    cmp byte [r9], '7'
                    je .cVert2

                    cmp byte [r9], 'F'
                    je .cVert2

                    cmp byte [rdi + rsi], '|'
                    je .cL2

                    cmp byte [rdi + rsi], 'J'
                    je .cL2

                    cmp byte [rdi + rsi], 'L'
                    je .cL2

                    cmp byte [rdi - 1], '-'
                    je .cJ2

                    cmp byte [rdi - 1], 'L'
                    je .cJ2

                    cmp byte [rdi - 1], 'F'
                    je .cJ2

                    .cVert2:
                        mov byte [rdi], 'L'
                        jmp .right

                    .cL2:
                        mov byte [rdi], 'F'
                        jmp .right

                    .cJ2:
                        mov byte [rdi], '-'
                        jmp .right

            .checkBelow:
                cmp byte [rdi + rsi], '|'
                je .goingDown

                cmp byte [rdi + rsi], 'L'
                je .goingDown

                cmp byte [rdi + rsi], 'J'
                je .goingDown
                jmp .checkLeft

                .goingDown:
                    mov r9, rdi
                    sub r9, rsi
                    cmp byte [r9], '|'
                    je .cVert3

                    cmp byte [r9], '7'
                    je .cVert3

                    cmp byte [r9], 'F'
                    je .cVert3

                    cmp byte [rdi + 1], '-'
                    je .cL3

                    cmp byte [rdi + 1], 'J'
                    je .cL3

                    cmp byte [rdi + 1], '7'
                    je .cL3

                    cmp byte [rdi - 1], '-'
                    je .cJ3

                    cmp byte [rdi - 1], 'L'
                    je .cJ3

                    cmp byte [rdi - 1], 'F'
                    je .cJ3

                    .cVert3:
                        mov byte [rdi], '|'
                        jmp .down

                    .cL3:
                        mov byte [rdi], 'F'
                        jmp .down

                    .cJ3:
                        mov byte [rdi], '7'
                        jmp .down

            .checkLeft:
                cmp byte [rdi - 1], '-'
                je .goingLeft

                cmp byte [rdi - 1], 'L'
                je .goingLeft

                cmp byte [rdi - 1], 'F'
                je .goingLeft

                .goingLeft:
                    mov r9, rdi
                    sub r9, rsi
                    cmp byte [r9], '|'
                    je .cVert4

                    cmp byte [r9], '7'
                    je .cVert4

                    cmp byte [r9], 'F'
                    je .cVert4

                    cmp byte [rdi + 1], '-'
                    je .cL4

                    cmp byte [rdi + 1], 'J'
                    je .cL4

                    cmp byte [rdi + 1], '7'
                    je .cL4

                    cmp byte [rdi + rsi], '|'
                    je .cJ4

                    cmp byte [rdi + rsi], 'L'
                    je .cJ4

                    cmp byte [rdi + rsi], 'J'
                    je .cJ4

                    .cVert4:
                        mov byte [rdi], 'J'
                        jmp .left

                    .cL4:
                        mov byte [rdi], '-'
                        jmp .left

                    .cJ4:
                        mov byte [rdi], '7'
                        jmp .left

            .up:
                add byte [rdi], '~'
                sub rdi, rsi
                mov r8, FROM_DOWN
                jmp .while

            .right:
                add byte [rdi], '~'
                inc rdi
                mov r8, FROM_LEFT
                jmp .while

            .left:
                add byte [rdi], '~'
                dec rdi
                mov r8, FROM_RIGHT
                jmp .while

            .down:
                add byte [rdi], '~'
                add rdi, rsi
                mov r8, FROM_UP
                jmp .while

        .endWhile:

        .end:
            leave
            ret

    ; End markBorder.

    
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
