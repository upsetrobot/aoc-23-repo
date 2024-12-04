;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Advent of Code Christmas Challenge Day 5 - Part II
;
; @brief    Take an input file and find the lowest location from a list of 
;           locations that can be derived from a list of seed ranges.
;
;           Used naive solution. Thought of an incredibly better approach, but 
;           program results while I was editing, so it was not needed.
;
; @file         solution.nasm
; @date         05 Dec 2023
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
    filename    db  "input.txt", 0

    err1        db  "Error 1 Main", 0
    err2        db  "Error 2 getFile", 0
    err3        db  "Error 3 getClosestLocation", 0
    err4        db  "Error 4 findLocation", 0
    err5        db  "Error 5 findNextLocation", 0
    err6        db  "Error 6 getNextLine", 0
    err7        db  "Error 7 scanNumber", 0
    err8        db  "Error 6 parseSection", 0


; Global uninitialized variables.
section .bss

    fd:         resd    1
    stat_buf:   resb    sb_size
    filesize:   resq    1
    buf_ptr:    resq    1

    seed_arr:           resq    1
    seed_arr_len:       resq    1

    seed_to_soil:       resq    1
    seed_to_soil_len:   resq    1

    soil_to_fert:       resq    1
    soil_to_fert_len:   resq    1

    fert_to_water:      resq    1
    fert_to_water_len:  resq    1

    water_to_light:     resq    1
    water_to_light_len: resq    1

    light_to_temp:      resq    1
    light_to_temp_len:  resq    1

    temp_to_humid:      resq    1
    temp_to_humid_len:  resq    1

    humid_to_loc:       resq    1
    humid_to_loc_len:   resq    1


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
        call getClosestLocation

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

            mov al, spl
            and al, 15
            cmp al, 8
            jne .noPush

            push rax
            mov rdi, err1
            call perror

            pop rax
            jmp .push

            .noPush:
                mov rdi, err1
                call perror

            .push:
                xor rax, rax
                not rax
        
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
            push rdi
            push rsi
            push rdx
            push rcx
            push r8
            
            mov al, spl
            and al, 15
            cmp al, 8
            jne .noPush

            push rax
            mov rdi, err2
            call perror

            pop rax
            jmp .push

            .noPush:
                mov rdi, err2
                call perror

            .push:
                pop r8
                pop rcx
                pop rdx
                pop rsi
                pop rdi
                
                xor rax, rax
                not rax

        .end:
            pop rbp
            ret


    ; unsigned long long getClosestLocation(char* fileBuffer);
    getClosestLocation:
        push rbp

        ; Parse file.
        test rdi, rdi
        jz .error       

        call getNextLine

        mov rsi, rax            ; Next line.
        xor r8, r8              ; Count.

        ; Parse seeds.
        .seeds:
            push rsi
            push r8
            call scanNumber

            pop r8
            pop rsi
            cmp rax, -1
            je .doneSeeds

            push rax
            inc r8
            inc rdi
            jmp .seeds

        .doneSeeds:
            mov rdi, r8
            shl rdi, 3
            push r8
            push rsi
            call malloc

            pop rsi
            pop r8
            test rax, rax
            jz .error

            mov [seed_arr], rax
            mov [seed_arr_len], r8
            xor rcx, rcx

            .fillSeeds:
                cmp rcx, r8
                je .doneFillSeeds

                pop rdx
                mov [rax + rcx*8], rdx
                inc rcx
                jmp .fillSeeds

        .doneFillSeeds:
            ; Parse maps.
            ; Get Line.
            mov rdi, rsi        ; Next Line
            test rdi, rdi
            jz .error

            call getNextLine

            mov rdi, rax
            test rdi, rdi
            jz .error

            call getNextLine

            mov rdi, rax
            test rdi, rdi
            jz .error

            call getNextLine

            ; Parse sections.
            mov rsi, rax
            mov rdx, seed_to_soil
            mov rcx, seed_to_soil_len
            call parseSection

            test rax, rax
            jnz .error

            mov rdi, rsi        ; Next Line
            test rdi, rdi
            jz .error

            call getNextLine

            mov rdi, rax
            test rdi, rdi
            jz .error

            call getNextLine

            ; Parse sections.
            mov rsi, rax
            mov rdx, soil_to_fert
            mov rcx, soil_to_fert_len
            call parseSection

            test rax, rax
            jnz .error

            mov rdi, rsi        ; Next Line
            test rdi, rdi
            jz .error

            call getNextLine

            mov rdi, rax
            test rdi, rdi
            jz .error

            call getNextLine

            ; Parse sections.
            mov rsi, rax
            mov rdx, fert_to_water
            mov rcx, fert_to_water_len
            call parseSection

            test rax, rax
            jnz .error

            mov rdi, rsi        ; Next Line
            test rdi, rdi
            jz .error

            call getNextLine

            mov rdi, rax
            test rdi, rdi
            jz .error

            call getNextLine

            ; Parse sections.
            mov rsi, rax
            mov rdx, water_to_light
            mov rcx, water_to_light_len
            call parseSection

            test rax, rax
            jnz .error

            mov rdi, rsi        ; Next Line
            test rdi, rdi
            jz .error

            call getNextLine

            mov rdi, rax
            test rdi, rdi
            jz .error

            call getNextLine

            ; Parse sections.
            mov rsi, rax
            mov rdx, light_to_temp
            mov rcx, light_to_temp_len
            call parseSection

            test rax, rax
            jnz .error

            mov rdi, rsi        ; Next Line
            test rdi, rdi
            jz .error

            call getNextLine

            mov rdi, rax
            test rdi, rdi
            jz .error

            call getNextLine

            ; Parse sections.
            mov rsi, rax
            mov rdx, temp_to_humid
            mov rcx, temp_to_humid_len
            call parseSection

            test rax, rax
            jnz .error

            mov rdi, rsi        ; Next Line
            test rdi, rdi
            jz .error

            call getNextLine

            mov rdi, rax
            test rdi, rdi
            jz .error

            call getNextLine

            ; Parse sections.
            mov rsi, rax
            mov rdx, humid_to_loc
            mov rcx, humid_to_loc_len
            call parseSection

            test rax, rax
            jnz .error

            ; Arrays are filled.
            ; For loop seeds and find minimum.
            xor rdx, rdx        ; Min location.
            not rdx
            xor rcx, rcx        ; i.
            mov r8, [seed_arr_len]

        .for:
            cmp rcx, r8
            je .endFor

            mov rdi, [seed_arr]
            mov r9, [rdi + rcx*8]
            mov rsi, [rdi + rcx*8 + 8]

            push rcx
            xor rcx, rcx    ; i = 0.
            add r9, rsi
            
            .innerFor:
                mov rdi, rsi
                cmp rdi, r9
                jge .break

                push rdi
                push rsi
                push rdx
                push rcx
                push r8
                push r9
                call findLocation

                pop r9
                pop r8
                pop rcx
                pop rdx
                pop rsi
                pop rdi

                cmp rax, rdx
                cmovb rdx, rax
                inc rsi
                jmp .innerFor

            .break:
                pop rcx
                add rcx, 2
                jmp .for

        .endFor:
            mov rax, rdx
            push rax
            mov rdi, [seed_arr]
            call free
            mov rdi, [seed_to_soil]
            call free
            mov rdi, [soil_to_fert]
            call free
            mov rdi, [fert_to_water]
            call free
            mov rdi, [water_to_light]
            call free
            mov rdi, [light_to_temp]
            call free
            mov rdi, [temp_to_humid]
            call free
            mov rdi, [humid_to_loc]
            call free
            pop rax
            jmp .end
        
        .error:
            push rdi
            push rsi
            push rdx
            push rcx
            push r8
            
            mov al, spl
            and al, 15
            cmp al, 8
            jne .noPush

            push rax
            mov rdi, err3
            call perror

            pop rax
            jmp .push

            .noPush:
                mov rdi, err3
                call perror

            .push:
                pop r8
                pop rcx
                pop rdx
                pop rsi
                pop rdi
                
                xor rax, rax
                not rax

        .end:
            pop rbp
            ret


    ; int parseSection(char* line, char* nextline, ull** arr, ull* len);
    ; Returns -1 if error.
    ; rsi remains next line.
    parseSection:
        push rbp
        
        xor r8, r8      ; Count.

        .parse:
            test rdi, rdi
            jz .done

            cmp byte [rdi], 0
            je .done

            cmp byte [rdi], 10
            je .done

            ; Get three numbers.
            push rsi
            push rdx
            push rcx
            push r8
            call scanNumber

            pop r8
            pop rcx
            pop rdx
            pop rsi
            cmp rax, -1
            je .error

            push rax
            inc r8
            inc rdi

            push rsi
            push rdx
            push rcx
            push r8
            call scanNumber

            pop r8
            pop rcx
            pop rdx
            pop rsi
            cmp rax, -1
            je .error

            push rax
            inc r8
            inc rdi

            push rsi
            push rdx
            push rcx
            push r8
            call scanNumber

            pop r8
            pop rcx
            pop rdx
            pop rsi
            cmp rax, -1
            je .error

            push rax
            inc r8

            ; Get Line.
            mov rdi, rsi
            push rcx
            call getNextLine

            ; rdi is line. rax is next line.
            mov rsi, rax
            pop rcx
            jmp .parse            

        .done:
        
            mov rdi, r8
            shl rdi, 3
            push rdi
            push rsi
            push rdx
            push rcx
            push r8
            call malloc

            pop r8
            pop rcx
            pop rdx
            pop rsi
            pop rdi
            test rax, rax
            jz .error

            mov [rdx], rax
            mov [rcx], r8
            xor rcx, rcx

            .loop:
                cmp rcx, r8
                je .out

                pop rdx
                mov [rax + rcx*8], rdx
                inc rcx
                jmp .loop

        .out:
            xor rax, rax
            jmp .end

        .error:
            push rdi
            push rsi
            push rdx
            push rcx
            push r8
            
            mov al, spl
            and al, 15
            cmp al, 8
            jne .noPush

            push rax
            mov rdi, err8
            call perror

            pop rax
            jmp .push

            .noPush:
                mov rdi, err8
                call perror

            .push:
                pop r8
                pop rcx
                pop rdx
                pop rsi
                pop rdi
                
                xor rax, rax
                not rax

        .end:
            pop rbp
            ret


    ; unsigned long long findLocation(unsigned long long seed);
    findLocation:
        push rbp
        
        mov rsi, [seed_to_soil]
        mov rdx, [seed_to_soil_len]
        call findNextLocation
        
        mov rdi, rax
        mov rsi, [soil_to_fert]
        mov rdx, [soil_to_fert_len]
        call findNextLocation
        
        mov rdi, rax
        mov rsi, [fert_to_water]
        mov rdx, [fert_to_water_len]
        call findNextLocation
        
        mov rdi, rax
        mov rsi, [water_to_light]
        mov rdx, [water_to_light_len]
        call findNextLocation
        
        mov rdi, rax
        mov rsi, [light_to_temp]
        mov rdx, [light_to_temp_len]
        call findNextLocation
        
        mov rdi, rax
        mov rsi, [temp_to_humid]
        mov rdx, [temp_to_humid_len]
        call findNextLocation
        
        mov rdi, rax
        mov rsi, [humid_to_loc]
        mov rdx, [humid_to_loc_len]
        call findNextLocation

        .end:
            pop rbp
            ret          
        

    ; unsigned long long findNextLocation(ull src, ull* arr, ull arr_len);
    findNextLocation:
        push rbp
        
        xor rcx, rcx        ; i
        
        .for:
            cmp rcx, rdx
            je .notFound

            mov rax, [rsi + rcx*8]      ; Offset.
            mov r8, [rsi + rcx*8 + 8]   ; Source.
            mov r9, [rsi + rcx*8 + 16]  ; Dest.

            cmp rdi, r8
            jl .out

            mov r10, r8
            add r10, rax
            cmp rdi, r10
            jge .out

            sub rdi, r8
            add rdi, r9
            mov rax, rdi
            jmp .end

            .out:
                add rcx, 3
                jmp .for

        .notFound:
            mov rax, rdi
        
        .end:
            pop rbp
            ret


    ; char* getNextLine(char* buf);
    ; Returns 0 if no more lines.
    ; Replaces newline with null and returns location of next line.
    getNextLine:
        push rbp

        xor rcx, rcx

        .loop:

            test rdi, rdi
            jz .error

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
            push rdi
            push rsi
            push rdx
            push rcx
            push r8
            mov al, spl
            and al, 15
            cmp al, 8
            jne .noPush

            push rdi
            mov rdi, err6
            call perror

            pop rdi
            jmp .push

            .noPush:
                push rax
                push rdi
                mov rdi, err6
                call perror

                pop rdi
                pop rax

            .push:
                pop r8
                pop rcx
                pop rdx
                pop rsi
                pop rdi
                xor rax, rax

        .end:
            pop rbp
            ret

    ; unsigned long long scanNumber(char* findNumStr);
    ; Returns value in rax, first digit ptr in rsi, last digit in rdi.
    ; Returns -1 if error (eventhough unsigned which is stupid.)
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
            push rdi
            push rsi
            push rdx
            push rcx
            push r8
            
            mov al, spl
            and al, 15
            cmp al, 8
            jne .noPush

            push rax
            mov rdi, err7
            call perror

            pop rax
            jmp .push

            .noPush:
                mov rdi, err7
                call perror

            .push:
                pop r8
                pop rcx
                pop rdx
                pop rsi
                pop rdi
                
                xor rax, rax
                not rax

        .end:
            pop rbp
            ret


; End of file.