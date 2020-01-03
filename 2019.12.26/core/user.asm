; 用户程序

; ===================================================================
; 文件头，用于内核的识别和加载
SECTION header vstart=0

    program_length dd program_end ; 程序总长度 #0x00
    header_length dd header_end ; 文件头长度 #0x04

    stack_seg dd 0 ; 内核动态分配栈空间，栈段选择子填在此处 #0x08
    stack_len dd 1 ; 栈段大小，4KB为单位 #0x0c

    program_entry dd start ; 用户程序入口点32位偏移地址 #0x10
    code_seg dd section.code.start ; 代码段起始汇编地址 #0x14
    code_len dd code_end ; 代码段长度 #0x18

    data_seg dd section.data.start ; 数据段起始汇编地址 #0x1c
    data_len dd data_end ; 数据段长度 #0x20

; 建立符号-地址检索表
    salt_items dd (header_end - salt)/256 ; 符号表中符号名数量 #0x24
; 操作系统API
    salt:
    PrintString db '@PrintString' ; 每个标号256字节
                times 256-($-PrintString) db 0

    TerminateProgram db '@TerminateProgram'
                times 256-($-TerminateProgram) db 0

    ReadDiskData db '@ReadDiskData'
                times 256-($-ReadDiskData) db 0



header_end:

; 数据段
SECTION data vstart=0


data_end:


; 用户程序代码段
SECTION code vstart=0
start: ; 代码段入口点

; 代码段结束
code_end:


program_end:
