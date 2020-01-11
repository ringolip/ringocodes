

; 定义常量，内核所有段选择子
core_data_seg_sel      equ 0x30                 ; 内核数据段选择子
core_code_seg_sel      equ 0x38                 ; 内核代码段选择子
sys_routine_seg_sel    equ 0x28                 ; 公共例程段选择子
core_stack_seg_sel     equ 0x18                 ; 内核堆栈选择子
all_memory_seg_sel     equ 0x0008               ; 整个0-4GB内存空间段选择子

; 内核头部，用于加载内核头部
core_length      dd core_end                    ;核心程序总长度#00

sys_routine_seg  dd section.sys_routine.start   ;系统公用例程段位置#04

core_data_seg    dd section.core_data.start     ;核心数据段位置#08

core_code_seg    dd section.core_code.start     ;核心代码段位置#0c

core_entry       dd start                       ;核心代码段入口点#10
                 dw core_code_seg_sel





; ===================================================================
SECTION core_code vstrat=0
; -------------------------------------------------------------------
start:
    mov ecx, core_data_seg_sel
    mov ds, ecx                                 ; DS=内核数据段

    mov ecx, all_memory_seg_sel
    mov es, eax                                 ; ES=整个4GB内存空间

    mov ebx, message_1
    call sys_routine_seg_sel:put_string         ; 调用公共例程显示字符串

    mov eax, 0
    cpuid                                       ; 查看cpu能够调用的最大功能数

    mov eax, 0x80000002                         ; 调用cpu0x80000002-0x80000004功能
    cpuid
    mov [cpu_brand+0x00], eax
    mov [cpu_brand+0x04], ebx
    mov [cpu_brand+0x08], ecx
    mov [cpu_brand+0x0c], edx

    mov eax, 0x80000003
    cpuid
    mov [cpu_brand+0x10], eax
    mov [cpu_brand+0x14], ebx
    mov [cpu_brand+0x18], ecx
    mov [cpu_brand+0x1c], edx

    mov eax, 0x80000004
    cpuid
    mov [cpu_brand+0x20], eax
    mov [cpu_brand+0x24], ebx
    mov [cpu_brand+0x28], ecx
    mov [cpu_brand+0x2c], edx

    mov ebx, cpu_brand0
    call sys_routine_seg_sel:put_string         ; 调用公共例程显示cpu信息
    mov ebx, cpu_brand
    call sys_routine_seg_sel:put_string
    mov ebx, cpu_brand1
    call sys_routine_seg_sel:put_string

    ; 为内核任务创建页目录和页表
    mov ecx, 1024                               ; 页目录表共1024目录项
    mov ebx, 0x00020000                         ; 页目录表物理地址
    xor esi, esi                                ; 页目录第一项偏移地址

  .b1:
    mov dword [es:ebx+esi], 0x00000000          ; 页目录所有表项清0
    add esi, 4
    loop .b1

    ; 在页目录中创建指向自己的目录项
    mov dword [es:ebx+4092], 0x20000003
    ; 在页目录中创建与线性地址0x00000000对应的目录项
    mov dword [es:ebx+0x00], 0x21000003         ; 写入目录项（页表的物理地址和属性）



    ; 创建页表
    mov ebx, 0x00021000                         ; 页表的物理地址
    xor eax, eax                                ; 起始页的物理地址
    xor esi, esi                                ; 定位每一个页表项

  .b2:
    mov edx, eax
    or edx, 0x00000003                          ; 写入页表项属性
    mov [es:ebx+esi*4], edx                     ; 登记页的物理地址





core_code_end:
