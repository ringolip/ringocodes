; 内核程序

; 定义常量
core_code_seg_sel equ 0x38 ; 内核代码段选择子 #7
core_data_seg_sel equ 0x30 ; 内核数据段选择子 #6
sys_rountine_seg_sel equ 0x28 ; 内核公共例程段选择子 #5


; 内核头部，用于加载内核
core_length dd core_end ; 内核程序总长度 0x00

sys_rountine_seg dd section.sys_rountine.start ; 公共例程段起始汇编地址 0x04

core_data_seg dd section.core_data.start ; 核心数据段起始汇编地址 0x08

core_code_seg dd section.core_code.start ; 核心代码段起始汇编地址 0x0c

; 核心代码段入口点
core_entry dd start ; 32位段内偏移地址
           dw core_code_seg_sel ; 内核代码段选择子

; 内核公共例程代码段
SECTION sys_rountine vstart=0

put_string: ; 字符串显示例程

put_char:


; 内核核心数据段
SECTION core_data vstart=0

    message_1: db '  If you seen this message,that means we '
               db 'are now in protect mode,and the system '
               db  'core is loaded,and the video display '
               db  'routine works perfectly.',0x0d,0x0a,0

    message_5: db '  Loading user program...',0


    brand0:    db 0x0d, 0x0a, ' ', 0
    brand:     times 52 db 0 ;
    brand1:    db 0x0d, 0x0a, 0x0d, 0x0a, 0


; 内核核心代码段
SECTION core_code vstart=0

; 加载并重定位用户程序
load_relocate_program:



start:
    mov ecx, core_data_seg_sel ; DS指向内核数据段
    mov ds, ecx

    ; 调用公共例程显示字符串
    mov ebx, message_1
    call sys_rountine_seg_sel:put_string

    ; 显示处理器品牌信息
    mov eax, 0 ; 查看处理器能够执行的最大功能号
    cpuid

    mov eax, 0x80000002 ; 调用0x80000002～0x80000004功能，返回ASCII码
    cpuid
    mov [brand + 0x00], eax
    mov [brand + 0x04], ebx
    mov [brand + 0x08], ecx
    mov [brand + 0x0c], edx

    mov eax, 0x80000003
    cpuid
    mov [brand + 0x10], eax
    mov [brand + 0x14], ebx
    mov [brand + 0x18], ecx
    mov [brand + 0x1c], edx

    mov eax, 0x80000004
    cpuid
    mov [brand + 0x10], eax
    mov [brand + 0x14], ebx
    mov [brand + 0x18], ecx
    mov [brand + 0x1c], edx

    mov ebx, brand0
    call sys_rountine_seg_sel:put_string ; 回车，换行
    mov ebx, brand
    call sys_rountine_seg_sel:put_string ; 显示CPU品牌信息
    mov ebx, brand1
    call sys_rountine_seg_sel:put_string ; 回车，换行，回车，换行


    ; 加载用户程序
    mov ebx, message_5
    call sys_rountine_seg_sel:put_string

    mov esi, 50 ; 用户程序位于50号逻辑扇区
    call load_relocate_program ; 调用过程加载并重定位用户程序

    






core_end:
