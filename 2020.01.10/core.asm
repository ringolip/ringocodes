

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
SECTION core_data vstart=0

program_manager_tss     dd 0                    ; 程序管理器的TSS基地址
                        dw 0                    ; 程序管理器的TSS描述符选择子
program_manager_msg1    db  0x0d,0x0a
                        db  '[PROGRAM MANAGER]: Hello! I am Program Manager,'
                        db  'run at CPL=0.Now,create user task and switch '
                        db  'to it by the CALL instruction...',0x0d,0x0a,0

program_manager_msg2    db  0x0d,0x0a
                        db  '[PROGRAM MANAGER]: I am glad to regain control.'
                        db  'Now,create another user task and switch to '
                        db  'it by the JMP instruction...',0x0d,0x0a,0

program_manager_msg3    db  0x0d,0x0a
                        db  '[PROGRAM MANAGER]: I am gain control again,'
                        db  'HALT...',0

core_msg0               db  0x0d,0x0a
                        db  '[SYSTEM CORE]: Uh...This task initiated with '
                        db  'CALL instruction or an exeception/ interrupt,'
                        db  'should use IRETD instruction to switch back...'
                        db  0x0d,0x0a,0

core_msg1               db  0x0d,0x0a
                        db  '[SYSTEM CORE]: Uh...This task initiated with '
                        db  'JMP instruction,  should switch to Program '
                        db  'Manager directly by the JMP instruction...'
                        db  0x0d,0x0a,0

core_data_end:

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

; -------------------------------------------------------------------
; 终止当前任务
terminate_current_task:                         ; 执行此例程时，当前任务仍在运行

    pushfd                                      ; EFLAGS压栈
    mov edx, [esp]
    add esp, 4

    mov eax, all_memory_seg_sel
    mov ds, eax

    ; 测试NT位
    test 0100_0000_0000_0000B
    jnz .b1                                     ; 如果NT=1
    mov ebx, core_msg1                          ; NT=0
    call sys_routine_seg_sel:put_string
    jmp far [program_manager_tss]               ; 切换任务

  .b1:
    mov ebx, core_msg0
    call sys_routine_seg_sel:put_string
    iretd                                       ; 转换到前一个任务

sys_routine_end:

; ===================================================================
SECTION core_code vstart=0
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

    ; 程序代码段描述符
    ; 程序数据段描述符
    ; 程序堆栈段描述符

    ; 重定位用户程序的SALT表
    ; 未加载LDTR，LDT还未生效
    mov eax, all_memory_seg_sel
    mov es,eax

    mov eax, core_data_seg_sel
    mov ds, eax

    cld                                         ; 正向比较

    mov ecx, [es:edi+0x24]                      ; U-SALT的条目数
    add edi, 0x28                               ; ES:EDI=U-SALT的起始线性地址

  .b2:
    push ecx
    push edi

    mov ecx, salt_items                         ; 内核SALT条目数
    mov esi, salt                               ; DS:ESI=内核SALT的起始线性地址

  .b3:
    push edi
    push esi
    push ecx

    mov ecx, 64                                 ; 每次比较4字节，至多比较64次
    repe cmpsd
    jnz .b4
    mov eax, [esi]                              ; 内核次匹配例程的段内偏移地址
    mov [edi-256], eax                          ; 写入用户程序头部

    mov ax, [esi+0x04]                          ; 调用门选择子
    or ax, 0000_0000_0000_0011B                 ; 将RPL特权级设为3

    mov [edi-252], ax                           ; 回填调用门选择子至用户头部

  .b4:
    pop ecx
    pop esi
    pop edi
    add esi, salt_item_len                      ; ESI指向内核SALT下一个表项
    loop .b3

    pop edi
    pop ecx
    add edi, 256                                ; EDI指向U-SALT下一个表项
    loop .b2

    ; 为任务定义额外的栈
    mov esi, [ebp+11*4]                         ; 在当前栈中取得TCB线性基地址

    ; 创建0特权级所需要的栈
    mov ecx, 4096
    mov eax, ecx
    mov [es:esi+0x1a], eax
    shr dword [es:esi+0x1a], 12                 ; 将堆栈大小写入TCB，以4KB为单位

    call sys_routine_seg_sel:allocate_memory
    add eax, ecx                                ; 堆栈的基地址为其高地址
    mov [es:esi+0x1e], eax                      ; 堆栈线性基地址写入TCB

    mov ebx, 0xffffe                            ; 堆栈段界限
    mov ecx, 0x00c09600                         ; 堆栈段属性，1100_1001_0110B，粒度4KB，DPL特权级为0
    call sys_routine_seg_sel:make_seg_descriptor  ; 创建堆栈描述符

    mov ebx, esi                                ; TCB基地址
    call sys_routine_seg_sel:fill_descriptor_in_ldt ; 将描述符安装到LDT中

    or cx, 0000_0000_0000_0000B                 ; 设置段描述符选择子RPL特权级为0
    mov [es:esi+0x22], cx                       ; 将栈选择子写入TCB
    mov dword [es:esi+0x24], 0                  ; 将栈的初始ESP写入TCB

    ; 创建特权级1所需要的栈

    ; 创建特权级2所需要的栈

    ; 创建LDT段描述符
    mov eax, [es:esi+0x0c]
    movzx ebx, word [es:esi+0x0a]
    mov ecx, 0x00408200
    call sys_routine_seg_sel:make_seg_descriptor
    call sys_routine_seg_sel:set_up_gdt_descriptor ; 将LDT段描述符安装至GDT
    mov [es:esi+0x10], cx                       ; 将LDT段选择子写入TCB

    ; 创建用户程序的TSS
    mov ecx, 104
    mov [es:esi+0x12], cx
    dec word [es:esi+0x12]                      ; TSS界限值写入TCB
    call sys_routine_seg_sel:allocate_memory    ; 为TSS申请内存空间
    mov [es:esi+0x14], ecx                      ; TSS线性基地址写入TCB

    mov word[es:ecx+0x00], 0                    ; 将指向前一个任务的指针置0，表明这是唯一的任务

    ; 登记特权级栈的信息至TSS
    mov edx, [es:esi+0x24]                      ; 特权级0的栈初始ESP
    mov [es:ecx+0x04], edx
    mov dx, [es:esi+0x22]                       ; 特权级0的栈选择子
    mov word [es:ecx+0x08], dx

    mov edx, [es:esi+0x32]
    mov [es:ecx+0x12], edx
    mov dx, [es:esi+0x30]
    mov word [es:ecx+0x16], dx

    mov edx, [es:esi+0x40]
    mov [es:ecx+0x20], edx
    mov dx, [es:esi+0x32]
    mov word [es:ecx+0x24], dx

    mov dx, [es:esi+0x10]
    mov word [es:ecx+0x96]                      ; LDT段选择子

    mov dx, [es:esi+0x12]
    mov word [es:ecx+0x102], dx                 ; 不存在I/O许可映射区

    mov word [es:ecx+0x100], 0                  ; 在任务刚创建时，B=0
    mov dword [es:ecx+28],0                     ;登记CR3(PDBR)

    ; 完善TSS内容
    mov ebx, [ebp+11*4]                         ; 从堆栈中取得用户程序TCB基地址
    mov edi, [es:ebx+0x06]                      ; 从TCB取得任务程序基地址

    mov edx, [es:edi+0x10]                      ; 登记用户程序入口点(EIP)至TSS
    mov [es:ecx+32], edx

    mov dx,[es:edi+0x14]                        ;登记程序代码段（CS）选择子
    mov [es:ecx+76],dx                          ;到TSS中

    mov dx,[es:edi+0x08]                        ;登记程序堆栈段（SS）选择子
    mov [es:ecx+80],dx                          ;到TSS中

    mov dx,[es:edi+0x04]                        ;登记程序数据段（DS）选择子
    mov word [es:ecx+84],dx                     ;到TSS中。注意，它指向程序头部段

    mov word [es:ecx+72],0                      ;TSS中的ES=0

    mov word [es:ecx+88],0                      ;TSS中的FS=0

    pushfd                                      ; 标志寄存器EFLAGS压栈
    pop edx
    mov [es:ecx+36], edx                        ; EFLAGS内容写入TSS

    ; 在GDT中安装TSS
    mov eax, [es:esi+0x14]
    movzx ebx, word [es:esi+0x12]
    mov eax, 0x00408900                         ; 特权级DPL=0的TSS描述符
    call sys_routine_seg_sel:make_seg_descriptor ; 创建TSS段描述符
    call sys_routine_seg_sel:set_up_gdt_descriptor ; 在GTD中安装TSS段描述符
    mov [es:esi+0x18], cx                       ; 将TSS选择子登记至TCB

    pop es
    pop ds

    popad

    ret 8                                       ; 将调用过程前压栈的参数丢弃

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

    ; 安装调用门

    ; 将内核SALT表中的公共例程地址转换为调用门
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

    ; 为程序管理器的TSS分配内存空间
    mov ecx, 104
    call sys_routine_seg_sel:allocate_memory
    mov [program_manager_tss+0x00], ecx         ; 程序管理器的TSS基地址

    ; 设置TSS
    mov word [es:ecx+96], 0                     ; 没有LDT
    mov word [es:ecx+00], 0                     ; 任务管理器为当前唯一任务
    mov dword [es:ecx+28], 0                    ; 不分页
    mov word [es:ecx+100], 0                    ; T=0
    mov word [es:ecx+102], 103                  ; 没有I/O位图
                                                ; 不需要0，1，2特权级堆栈

    ; 创建TSS描述符，并安装到GDT
    mov eax, [program_manager_tss]              ; 起始线性地址
    mov ebx, 103                                ; 段界限
    mov ecx, 0x00408900                         ; 段属性，TSS描述符，特权级0
    call sys_routine_seg_sel:make_seg_descriptor ; 创建TSS描述符
    call sys_routine_seg_sel:set_up_gdt_descriptor ; 将描述符安装到GDT

    mov [program_manager_tss+0x04], cx          ; TSS描述符选择子

    ; 任务寄存器TR的内容决定了当前的任务是谁
    ltr cx                                      ; 将任务管理器的TSS选择子写入TR

    ; 任务管理器任务正在执行
    mov ebx, program_manager_msg1
    call sys_routine_seg_sel:put_string

    ; 加载用户程序
    mov ecx, 0x46
    call sys_routine_seg_sel:allocate_memory    ; 申请用户程序的TCB内存空间
    call append_to_tcb_link                     ; 将用户程序TCB加到TCB链上

    ; 以压栈的形式传入参数
    push dword 50                               ; 用户程序其实逻辑扇区号
    push ecx                                    ; 用户程序的TCB起始基地址

    call load_relocate_program

    ; 切换任务
    call far [es:ebx+0x14]                      ; 嵌套于旧任务中

    mov ebx, program_manager_msg2
    call sys_routine_seg_sel:put_string

    ; 创建新的用户任务并发起任务切换
    mov ecx, 0x46
    call sys_routine_seg_sel:allocate_memory
    call append_to_tcb_link

    push dword 50
    push ecx
    call load_relocate_program

    ; 任务切换
    jmp far [es:ebx+0x14]                       ; 独立任务

    mov ebx, program_manager_msg3
    call sys_routine_seg_sel:put_string

    hlt

  core_code_end:
