

; 定义常量，内核所有段选择子
core_data_seg_sel      equ 0x30                 ; 内核数据段选择子
core_code_seg_sel      equ 0x38                 ; 内核代码段选择子
sys_routine_seg_sel    equ 0x28                 ; 公共例程段选择子
core_stack_seg_sel     equ 0x18                 ; 内核堆栈选择子
all_memory_seg_sel     equ 0x0008               ; 整个0-4GB内存空间段选择子

; 内核头部，用于加载内核头部
core_length      dd core_end                    ; 核心程序总长度#00

sys_routine_seg  dd section.sys_routine.start   ; 系统公用例程段位置#04

core_data_seg    dd section.core_data.start     ; 核心数据段位置#08

core_code_seg    dd section.core_code.start     ; 核心代码段位置#0c

core_entry       dd start                       ; 核心代码段入口点#10
                 dw core_code_seg_sel
; ===================================================================
SECTION sys_routine vstart=0
; -------------------------------------------------------------------
; 搜索空闲的页，并把它安装在页目录表和页表
alloc_install_a_page:                           ; 输入：EBX=页的线性地址
    push eax
    push ebx
    push esi
    push ds

    mov eax, all_memory_seg_sel
    mov ds, eax

    ; 检查该线性地址所对应页表是否存在
    ; 得到该页目录项的线性地址
    mov esi, ebx
    and esi, 0xffc00000                        ; 保留线性地址的高10位
    shr esi, 20                                ; 得到页目录索引的表内偏移
    or esi, 0xfffff000                         ; 要访问目录项的线性地址

    test dword [esi], 0x00000001               ; 检查页表是否已经存在
    jnz .b1

    ; 创建该线性地址所对应的页表
    call alloc_a_4k_page                       ; 分配一个页作为页表
    or eax, 0x00000007                         ; 为页表添加属性
    mov [esi], eax                             ; 将页表登记至页目录

  .b1:
    ;分配一个最终的页
    mov esi, ebx                               ; 页的线性地址
    shr esi, 10
    and esi, 0x003ff000
    or esi, 0xffc00000                         ; 得到该页表的线性地址

    and ebx, 0x003ff000
    shr ebx, 10
    or esi, ebx                                ; 页表项的线性地址

    call alloc_install_a_page                  ; 分配一个页
    or eax, 0x00000007                         ; 为页添加属性
    mov [esi], eax                             ; 将页表项内容修改为页的物理地址

    pop ds
    pop esi
    pop ebx
    pop eax

    retf

; -------------------------------------------------------------------
; 分配一个4KB的页
alloc_a_4k_page:                                ; 输出：EAX=页的物理地址
    push ebx
    push ecx
    push edx
    push ds

    mov eax, all_memory_seg_sel
    mov ds, eax

    xor eax, eax
  .b1:
    bts [page_bit_map], eax                     ; 检查位串
    jnc .b2                                     ; 该比特空闲
    inc eax                                     ; 测试下一位
    cmp eax, page_map_len*8                     ; 判断是否测试了所有比特位
    jl .b1

    mov ebx, message_3                          ; 没有找到空闲页
    call sys_routine_seg_sel:put_string
    hlt

  .b2:
    shl eax, 12                                 ; 该比特所对应页表的物理地址

    pop ds
    pop edx
    pop ecx
    pop ebx

    ret

; ===================================================================
SECTION core_data vstart=0
; -------------------------------------------------------------------
    pgdt               dw 0                     ; 用于设置和修改GDT
                       dd 0
    ;页映射位串
    page_bit_map       db  0xff,0xff,0xff,0xff,0xff,0x55,0x55,0xff
                       db  0xff,0xff,0xff,0xff,0xff,0x55,0x55,0xff
                       db  0xff,0xff,0xff,0xff,0xff,0x55,0x55,0xff
                       db  0xff,0xff,0xff,0xff,0xff,0x55,0x55,0xff ; 最低端1MB内存空间
                       db  0x55,0x55,0x55,0x55,0x55,0x55,0x55,0x55
                       db  0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
                       db  0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
                       db  0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    page_map_len       equ $ - page_bit_map     ; 位串的字节数

  ;符号地址检索表
  salt:
    salt_1             db  '@PrintString'
                       times 256-($-salt_1) db 0
                       dd  put_string
                       dw  sys_routine_seg_sel

    salt_2             db  '@ReadDiskData'
                       times 256-($-salt_2) db 0
                       dd  read_hard_disk_0
                       dw  sys_routine_seg_sel

    salt_3             db  '@PrintDwordAsHexString'
                       times 256-($-salt_3) db 0
                       dd  put_hex_dword
                       dw  sys_routine_seg_sel

    salt_4             db  '@TerminateProgram'
                       times 256-($-salt_4) db 0
                       dd  terminate_current_task
                       dw  sys_routine_seg_sel

    salt_item_len      equ $-salt_4
    salt_items         equ ($-salt)/salt_item_len
    message_1          db  '  Paging is enabled.System core is mapped to'
                       db  ' address 0x80000000.', 0x0d, 0x0a, 0

    core_next_laddr    dd  0x80100000             ; 内核中下一个可用于自由分配的内存空间的线性地址

; ===================================================================
SECTION core_code vstart=0
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
    add eax, 0x1000                             ; 下一页的物理地址
    inc esi                                     ; 下一个页表项
    cmp esi, 256                                ; 只登记低端1MB的前256个页
    jl .b2

    ; 将页表其余表项登记为无效
  .b3:
    mov dword [es:ebx+esi*4], 0x00000000
    inc esi
    cmp esi, 1024
    jl .b3

    ; 将页目录表的物理基地址传送至寄存器CR3
    mov eax, 0x00020000
    mov cr3, eax

    ; 开启页功能
    mov eax, cr0
    or eax, 0x80000000                            ; 将最高位置1
    mov cr0, eax                                  ; 传回cr0，开启页功能

    ; 在页目录内创建与线性地址0x80000000对应的目录项
    ; 当线性地址高20位为0xfffff000时， 访问的就是页目录自己
    mov ebx, 0xfffff000                           ; 页目录自己的线性地址
    mov esi, 0x80000000
    shr esi, 22                                   ; 保留高十位
    shl esi, 2                                    ; 目录表内的偏移量
    mov [es:ebx+esi], 0x00021003

    sgdt [pgdt]                                   ; 获取GDT信息
    mov ebx, [pgdt+2]                             ; GDT起始线性基地址

    ; 将段描述符线性基地址加0x80000000
    or dword [es:ebx+0x10+4], 0x80000000
    or dword [es:ebx+0x18+4], 0x80000000
    or dword [es:ebx+0x20+4], 0x80000000
    or dword [es:ebx+0x28+4], 0x80000000
    or dword [es:ebx+0x30+4], 0x80000000
    or dword [es:ebx+0x38+4], 0x80000000

    add dword [pgdt+2], 0x80000000                ; GDT起始线性基地址加0x80000000

    lgdt [pgdt]                                   ; 使修改后的GDT生效

    ; 显示刷新段寄存器内容，使处理器转去内存高地址执行
    jmp core_code_seg_sel:flush

  flush:
    ; 重新加载段寄存器的高速缓存器
    mov eax, core_stack_seg_sel
    mov ss, eax

    mov eax, core_data_seg_sel
    mov ds, eax

    mov ebx, message_1
    call sys_routine_seg_sel:put_string

    ; 安装供用户程序使用的调用门
    mov edi, salt                                 ; 内核SALT表起始位置
    mov ecx, salt_items                           ; 内核SALT表的条目数量
  .b4:
    push ecx
    mov eax, [edi+256]                            ; 该条目入口点的32位偏移地址
    mov bx, [edi+260]                             ; 该条目入口点的段选择子
    mov cx, 1_11_0_1100_000_00000B                ; 特权级为3的调用门

    call sys_routine_seg_sel:make_gate_descriptor
    call sys_routine_seg_sel:set_up_gdt_descriptor

    add [edi+260], cx                             ; 将调用门选择子回填
    add edi, salt_item_len                        ; 指向下一个SALT条目
    pop ecx
    loop .b4

    ; 对门进行测试
    mov ebx, message_2
    call far [salt_1+256]                         ; 通过门显示信息

    ; 使内核的一部分成为任务

    ; 创建内核任务的TSS
    mov ebx, core_next_laddr
    call sys_routine_seg_sel:alloc_install_a_page ; 申请物理页
    add dword [core_next_laddr], 4096             ; 下一个可自由分配的内存空间的线性地址

    ; 在程序管理器的TSS中设置必要的项目
    mov word [es:ebx+0], 0                        ; 前一个任务的指针
    mov eax, cr3
    mov dword [es:ebx+28], eax                    ; 登记CR3

    mov word [es:ebx+96], 0                       ; 没有LDT， 处理器允许没有LDT的任务
    mov word [es:ebx+100], 0
    mov word [es:ebx+102], 103                    ; 没有I/O位图

    ; 创建程序管理器的TSS描述符，并安装到GDT中
    mov eax, ebx
    mov ebx, 103
    mov ecx, 0x00408900
    call sys_routine_seg_sel:make_seg_descriptor
    call sys_routine_seg_sel:set_up_gdt_descriptor
    mov [program_man_tss+4], cx                   ; 保存程序管理器的TSS描述符选择子

    ; 将当前任务的TSS描述符传送到任务寄存器TR
    ltr cx

    ; "任务管理器"任务正在运行


core_code_end:
