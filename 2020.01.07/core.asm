; 内核

; 定义内核所有段选择子
core_data_seg_sel      equ 0x30                 ; 内核数据段选择子
core_code_seg_sel      equ 0x38                 ; 内核代码段选择子
sys_routine_seg_sel    equ 0x28                 ; 公共例程段选择子
core_stack_seg_sel     equ 0x18                 ; 内核堆栈选择子

; ===================================================================
SECTION sys_routine vstart=0
; -------------------------------------------------------------------
; 显示字符串例程
put_string:                                     ; 输入：DS:EBX=字符串地址

; -------------------------------------------------------------------
; 分配内存
allocate_memory:                                ; 输入：ECX=希望分配的字节数
                                                ; 输出：ECX=分配内存的起始线性地址


; -------------------------------------------------------------------
; 在GDT内安装一个新的描述符
set_up_gdt_descriptor:
                                                ; 输入：EAX:EAX=描述符
                                                ; 输出：CX=描述符选择子

; -------------------------------------------------------------------
; 构造门描述符
make_gate_descriptor:
                                                ; 输入：EAX=门代码的段偏移地址
                                                ;       BX=门代码所在段选择子
                                                ;       CX=门属性
                                                ; 输出：EDX:EAX=完整的描述符

; ===================================================================
; 内核数据段
SECTION core_data vstart=0

    salt:                                       ; 系统调用，符号地址检索表
    salt_1             db '@PrintString'
                    times 512-($-salt_1) db 0   ; 例程名512字节
                       dd put_string            ; 4字节例程在段中偏移量
                       dw sys_routine_seg_sel   ; 2字节例程所在段选择子

    salt_item_len     equ $-salt_1              ; 每个条目的字节数
    salt_items        equ ($-salt_1)/salt_item_len ; 表中条目数


    message_1          db '  If you seen this message,that means we '
                       db 'are now in protect mode,and the system '
                       db 'core is loaded,and the video display '
                       db 'routine works perfectly.',0x0d,0x0a,0

    message_2          db '  System wide CALL-GATE mounted.',0x0d,0x0a,0

    message_3          db 0x0d,0x0a,'  Loading user program...',0
    cpu_brand0         db 0x0d,0x0a,'  ',0
    cpu_brand          times 52 db 0            ; cpu信息
    cpu_brand1         db 0x0d,0x0a,0x0d,0x0a,0

    tbc_chain          dd 0                     ; 第一个任务的TCB的线性基地址


; ===================================================================
; 内核代码段
SECTION core_code vstart=0
; -------------------------------------------------------------------
; 在TCB链表上追加任务控制块
append_to_tcb_link:                             ; 输入：ECX=TCB线性基地址




; -------------------------------------------------------------------
; 内核主程序
start:
    mov ecx, core_data_seg_sel
    mov ds, ecx                                 ; DS=内核数据段

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

    ; 安装调用门

    ; 将SALT表中的公共例程地址转换为调用门
    mov edi, salt                               ; SALT起始地址
    mov ecx, salt_items                         ; SALT条目数，总循环数

  .b3:
    push ecx
    mov eax, [sdi+256]                          ; 系统调用例程段内偏移地址
    mov bx, [sdi+260]                           ; 所在段选择子
    mov cx, 1_11_0_1100_000_00000B              ; 门属性

    ; 创建调用门描述符
    call sys_routine_seg_sel:make_gate_descriptor ; 调用过程
    call sys_routine_seg_sel:set_up_gdt_descriptor ; 在GDT中安装门描述符
    mov [sdi+260], cx                           ; 调用门选择子取代代码段选择子

    add edi, salt_item_len                      ; 指向下一个条目
    pop ecx
    loop .b3

    ; 对调用门进行测试
    mov ebx, message_2
    call far [salt_1+256]                       ; 调用例程显示信息

    mov ebx, message_3
    call sys_routine_seg_sel:put_string

    ; 加载用户程序并创建任务
    ; 创建任务控制快
    mov ecx, 0x46
    call sys_routine_seg_sel:allocate_memory







core_code_end:
