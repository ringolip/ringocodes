; 用户程序

; ===================================================================
; 文件头，用于内核的识别和加载
SECTION header vstart=0

    program_length dd program_end ; 程序总长度 #0x00
    header_length dd header_end   ; 文件头长度 #0x04

    stack_seg dd 0                ; 内核动态分配栈空间，栈段选择子填在此处 #0x08
    stack_len dd 1                ; 栈段大小，4KB为单位 #0x0c

    program_entry dd start        ; 用户程序入口点32位偏移地址 #0x10
    code_seg dd section.code.start ; 代码段起始汇编地址 #0x14
    code_len dd code_end          ; 代码段长度 #0x18

    data_seg dd section.data.start ; 数据段起始汇编地址 #0x1c
    data_len dd data_end          ; 数据段长度 #0x20

; -------------------------------------------------------------------
; SALT
    salt_items dd (header_end - salt)/256 ; 符号表中符号名数量 #0x24

    salt:                         ; #0x28
    PrintString db '@PrintString' ; 每个标号256字节
                times 256-($-PrintString) db 0

    TerminateProgram db '@TerminateProgram'
                times 256-($-TerminateProgram) db 0

    ReadDiskData db '@ReadDiskData'
                times 256-($-ReadDiskData) db 0

header_end:

; ===================================================================
; 数据段
SECTION data vstart=0
    buffer times 1024 db 0        ; 缓冲区

    message_1:     db 0x0d, 0x0a, 0x0d, 0x0a
                   db '**********User program is running**********'
                   db 0x0d, 0x0a, 0

    message_2:     db 'Disk data:', 0x0d, 0x0a, 0


data_end:

; ===================================================================
[bits 32]
; ===================================================================
; 用户程序代码段
SECTION code vstart=0
start: ; 代码段入口点
    mov eax, ds                   ; 用户程序头部段
    mov fs, eax

    mov eax, [stack_seg]          ; 切换回用户程序自己的栈
    mov ss, eax
    mov esp, 0

    mov eax, [data_seg]
    mov ds, eax

    mov ebx, message_1
    call far [fs:PrintString]     ; 调用内核过程

    mov eax, 100                  ; 起始逻辑扇区号
    mov ebx, buffer               ; 缓冲区偏移地址
    call far [fs:ReadDiskData]    ; 调用内核过程

    mov ebx, message_2
    call far [fs:PrintString]

    mov ebx, buffer
    call far [fs:ReadDiskData]    ; 显示从扇区读出的内容

    jmp far [fs:TerminateProgram] ; 返回内核程序

; 代码段结束
code_end:


program_end:
