; 内核

; 定义内核所有段选择子
core_data_seg_sel      equ 0x30                 ; 内核数据段选择子
core_code_seg_sel      equ 0x38                 ; 内核代码段选择子
sys_routine_seg_sel    equ 0x28                 ; 公共例程段选择子
core_stack_seg_sel     equ 0x18                 ; 内核堆栈选择子
all_memory_seg_sel     equ 0x0008               ; 整个0-4GB内存空间段选择子

; ===================================================================
SECTION sys_routine vstart=0
; -------------------------------------------------------------------
; 显示字符串例程
put_string:                                     ; 输入：DS:EBX=字符串地址


; -------------------------------------------------------------------
; 读取硬盘所选逻辑扇区
read_hard_disk:
                                                ; 输入：EAX=逻辑扇区号
                                                ;      DS:EBX=内核缓冲区地址
                                                ; 输出：EBX=EBX+12


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
; 构造段描述符
make_seg_descriptor:                            ; 输入：EAX=段的线性基地址
                                                ;      EBX=段界限
                                                ;      ECX=段属性
                                                ; 输出：EDX:EAX=段描述符



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

    core_buffer        times 2048 db 0          ; 内核缓冲区

    cpu_brand0         db 0x0d,0x0a,'  ',0
    cpu_brand          times 52 db 0            ; cpu信息
    cpu_brand1         db 0x0d,0x0a,0x0d,0x0a,0

    tbc_chain          dd 0                     ; 第一个任务的TCB的线性基地址


; ===================================================================
; 内核代码段
SECTION core_code vstart=0
; -------------------------------------------------------------------
; 在LDT中安装描述符
fill_descriptor_in_ldt:
                                                ; 输入：EDX:EAX=描述符
                                                ;      EBX=TCB基地址
                                                ; 输出：CX=描述符选择子
    push eax
    push edx
    push edi
    push ds

    mov ecx, all_memory_seg_sel
    mov ds, ecx

    mov edi, [ebx+0x0c]                         ; 获得LDT基地址

    xor ecx, ecx
    mov cx, [ebx+0x0a]                          ; 获得LDT界限
    inc cx                                      ; LDT总字节数

    mov [edi+ecx+0x00], eax                     ; 安装描述符低32位
    mov [edi+ecx+0x04], edx                     ; 安装描述符高32位

    add cx, 8                                   ; 更新LDT界限值
    dec cx
    mov [ebx+0x0a], cx

    mov ax, cx                                  ; 计算当前描述符索引值
    xor dx, dx
    mov cx, 8
    div cx

    mov cx, ax
    shl cx                                      ; 当前描述符索引值
    or cx, 0000_0000_0000_0100B                 ; 段选择子，TI=1，指向LDT，RPL=00

    pop ds
    pop edi
    pop edx
    pop eax

    ret

; -------------------------------------------------------------------
; 加载并重定位用户程序
load_relocate_program:
                                                ; 输入：PUSH 逻辑扇区号
                                                ;      PUSH 任务控制块基地址
                                                ; 输出：无

    pushad                                      ; 寄存器压栈

    push ds
    push es

    mov ebp, esp                                ; 方便访问堆栈中的内容

    mov eax, all_memory_seg_sel
    mov es, eax

    mov ecx, 160
    call sys_routine_seg_sel:allocate_memory    ; 申请内存空间，用于创建LDT

    mov esi, [ebp+11*4]                         ; TCB起始线性地址
    mov [es:esi+0x0c], ecx                      ; 将LDT线性地址登记到TCB中
    mov [es:esi+0x0a], 0xffff                   ; LDT现在为0字节，所以界限值为0xffff

    mov eax, core_data_seg_sel
    mov ds, eax

    mov eax, [ebp+12*4]                         ; 用户程序所在逻辑扇区号
    mov ebx, core_buffer
    call sys_routine_seg_sel:read_hard_disk     ; 读取用户程序第一个逻辑扇区

    pass                                        ; 判断用户程序的大小

    mov ecx, eax                                ; 申请用户程序内存空间
    call sys_routine_seg_sel:allocate_memory
    mov [es:esi+0x06], ecx                      ; 将用户程序线性地址登记到TCB中

    pass                                        ; 加载用户程序至内存

    mov edi, [es:esi+0x06]                      ; 用户程序基地址

    ; 建立头部段描述符
    mov eax, edi
    mov ebx, [edi+0x04]                         ; 头部段长度
    dec ebx
    mov ecx, 0x0040f200                         ; 0100_1111_0010，特权级DPL为3
    call sys_routine_seg_sel:make_seg_descriptor

    ; 在LDT中安装描述符
    mov ebx, esi                                ; TCB起始线性地址
    call fill_descriptor_in_ldt

    or cx, 0000_0000_0000_0011B                 ; 设置头部选择子请求特权级RPL置3
    mov [es:esi+0x44], cx                       ; 登记头部选择子到TCB
    mov [edi+0x04]                              ; 登记头部选择子到头部程序


; -------------------------------------------------------------------
; 在TCB链表上追加任务控制块
append_to_tcb_link:                             ; 输入：ECX=TCB线性基地址
    push eax
    push edx
    push ds
    push es

    mov eax, core_data_seg_sel                  ; DS指向内核数据段，以访问tcb_chain
    mov ds, eax
    mov eax, all_memory_seg_sel                 ; ES指向4G内存空间，以访问所有TCB
    mov es, eax

    mov dword [es:ecx], 0                       ; 当前TCB首地址内容清零，表明这是链表最后一个TCB

    mov eax, [tcb_chain]                        ; 查看整个链表是否为空
    or eax, eax
    jz .notcb

  .searc:
    mov edx, eax                                ; 检查下一个TCB首地址内容是否为空
    mov eax, [es:edx]
    or eax, eax                                 ; 不为空则继续检查之后的TCB首地址内容
    jnz .search

    mov [es:edx], ecx                           ; 将此TCB的首地址，写入链表最后一项的首地址
    jmp .retpc

  .notcb:
    mov [tcb_chain], ecx                        ; 链表为空，将链表内容指向当前TCB首地址

  .retpc:
    pop es
    pop ds
    pop edx
    pop eax

    ret

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
    call sys_routine_seg_sel:allocate_memory    ; 得到申请内存的起始线性地址ECX
    call append_to_tcb_link                     ; 在TCB链表上追加TCB

    ; 使用栈传递参数
    push dword 50                               ; 用户程序位于的逻辑扇区
    push eax                                    ; 当前TCB起始线性地址

    call load_relocate_program                  ; 加载并重定位用户程序

    ; 程序代码段描述符
    ; 程序数据段描述符
    ; 程序堆栈段描述符

    ; 重定位用户程序的SALT表





core_code_end:
