;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Advent of Code Christmas Challenge Day 8 - Part II
;
; @brief    Find number of steps in links of a map to get from one point to 
;           another given directions to go right or left.
;
;           Approach is naive due to high number of solution. Considering 
;           finding a better solution.
;
;           After testing, you can find that each subsequent Z match is a 
;           multiple of the first match. In other words, there is a Z match 
;           every X directions. So, all you have to do is find a number that 
;           has factors of all six rotations. This is the LCM thing. 
;           To find the LCM, there are several methods. I am choosing Euclids 
;           algorithm for GCF and then (a*b)/GCF(a, b) for LCM.
;
; @file         solution.nasm
; @date         09 Dec 2023
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

struc loc_tbl

    .left:  resb    2
    .right: resb    2

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
        push r12
        push r13
        push r14
        push r15
        push rbx

        ; Parse directions.
        call getLine
        
        mov r15, rax                ; next_line.
        mov r12, rdi                ; curr_line.
        call strLen

        mov r13, rax                ; LR_arr_len.
        mov rdi, rax
        call memAlloc

        mov r14, rax                ; LR_arr.
        mov rdi, r12                ; curr_line.
        
        %define L 0
        %define R 1

        xor rcx, rcx                ; i

        .for:
            cmp ecx, r13d
            je .endFor

            cmp byte [rdi + rcx], 'L'
            je .left

            .right:
                mov byte [r14 + rcx], R
                jmp .contFor

            .left:
                mov byte [r14 + rcx], L

            .contFor:
                inc ecx
                jmp .for

        .endFor:
        
        mov rdi, r15
        call getLine

        mov rdi, rax
        mov r15, rax                ; top_line.

        ; Allocate table based on location.
        mov rdi, 0x8000
        shl rdi, 2                  ; loc_arr size in bytes.
        call memAlloc

        mov r12, rax                ; loc_arr.
        mov rdi, r15
        xor rcx, rcx                ; Index.
        xor rdx, rdx                ; ID.
        xor rbx, rbx                ; num_As.
        
        .parseRows:
            test rdi, rdi
            jz .endParseRows

            call getLine

            mov r15, rax            ; next_line
            xor rdx, rdx
            
            mov al, [rdi]
            sub al, 'A'
            add dl, al
            shl dx, 5              ; 5 bits to hold value ('Z' = 25)
            mov al, [rdi + 1]
            sub al, 'A'
            add dl, al
            shl dx, 5
            mov al, [rdi + 2]
            sub al, 'A'
            add dl, al
            mov rcx, rdx            ; Index.
            xor rdx, rdx

            mov r10w, cx
            and r10w, 0x1f          ; Check last 5 bits.
            test r10w, r10w         ; Ends in 'A'.
            jnz .notFirst

            push rcx
            inc ebx

            .notFirst:

            ; Need to get left and right location.
            mov al, [rdi + 7]
            sub al, 'A'
            add dl, al
            shl dx, 5              ; 5 bits to hold value ('Z' = 25)
            mov al, [rdi + 8]
            sub al, 'A'
            add dl, al
            shl dx, 5
            mov al, [rdi + 9]
            sub al, 'A'
            add dl, al

            mov [r12 + rcx*loc_tbl_size], dx
            xor dx, dx

            mov al, [rdi + 12]
            sub al, 'A'
            add dl, al
            shl dx, 5              ; 5 bits to hold value ('Z' = 25)
            mov al, [rdi + 13]
            sub al, 'A'
            add dl, al
            shl dx, 5
            mov al, [rdi + 14]
            sub al, 'A'
            add dl, al

            mov [r12 + rcx*loc_tbl_size + loc_tbl.right], dx
            mov rdi, r15
            jmp .parseRows

        .endParseRows:
            
        ; Follow direction.
        ; Need start location.

        ; So, we have to find direction for each 'A' one at a time till 
        ; they each end in 'Z'. We can make an array of 'A' locations. 
        ; Then, just go through each till they all equal 'Z' which we can 
        ; just sum 'Z' with length of 'A' array to find the condition.

        ; First make array of all 'A' locations. I will just use the stack.
        ; Actually, I am going to push the locations during parsing above.

        ; Make array.
        mov rdi, rbx            ; rbx is arr_of_As_len.
        shl rdi, 1
        call memAlloc

        mov rsi, rax            ; arr_of_As.
        xor ecx, ecx

        .loop:
            cmp ecx, ebx
            je .endLoop

            pop rax
            mov [rsi + rcx*2], ax
            inc ecx
            jmp .loop

        .endLoop:

        ; This is where my solution was not working due to the time complexity 
        ; of counting too high for part II.
        ; New solution requires cycle analysis perhaps.

        ; Save steps for each first Z.
        ; r12 = loc_tbl.
        ; r13 = LR_arr_len.
        ; r14 = LR_arr.
        ; r15 = arr_of_As.
        ; rbx = arr_of_As_len
        xor r9, r9
        xor r10, r10
        xor r11, r11
        mov rdi, r12
        mov r15, rsi
        xor rsi, rsi

        .saveFactors:
            cmp r10, rbx
            je .endSaveFactors
            
            mov si, [r15 + r10*2]
            mov rdx, r14
            xor rcx, rcx
            mov r8, r13
            call getNextZ

            push rax
            inc r10
            jmp .saveFactors

        .endSaveFactors:

        ; Find LCM of all saved Z steps.
        xor rcx, rcx
        xor rdi, rdi
        inc rdi

        .forZs:
            cmp rcx, rbx
            je .endForZs

            pop rsi
            call findLCM

            mov rdi, rax
            inc rcx
            jmp .forZs

        .endForZs:

        .end:
            pop rbx
            pop r15
            pop r14
            pop r13
            pop r12
            leave
            ret

    endGetSolution:


    ; size_t getNextZ(short* table, short currNode, char* directionTbl, uint directionIdx, size_t directionTblLen, );
    ; Returns number of steps. rsi is changed to new node.
    getNextZ:
        push rbp
        mov rbp, rsp

        xor rax, rax

        .loop:
            cmp rcx, r8
            jne .dontRotate

            xor rcx, rcx

            .dontRotate:

            cmp byte [rdx + rcx], R
            je .right

            .left:
                inc rax
                mov r9w, [rdi + rsi*loc_tbl_size + loc_tbl.left]
                mov si, r9w
                and r9w, 0x1f
                cmp r9w, 0x19            ; 'Z' value.
                je .end

                inc rcx
                jmp .loop

            .right:
                inc rax
                mov r9w, [rdi + rsi*loc_tbl_size + loc_tbl.right]
                mov si, r9w
                and r9w, 0x1f
                cmp r9w, 0x19            ; 'Z' value.
                je .end

                inc rcx
                jmp .loop

        .endLoop:

        .end:
            leave
            ret

    .endGetNextZ:


    ; size_t findLCM(size_t a, size_t b);
    ; Returns the LCM of a and b.
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

    endMemAlloc:


; End of file.
