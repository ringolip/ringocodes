; 内核程序

; 定义常量
core_code_seg_sel     equ 0x38    ; 内核代码段选择子 #7
core_data_seg_sel     equ 0x30    ; 内核数据段选择子 #6
sys_rountine_seg_sel  equ 0x28    ; 内核公共例程段选择子 #5
all_memory_seg_sel    equ 0x08    ; 整个0-4GB内存数据段选择子 #1

; 内核头部，用于加载内核
core_length dd core_end ; 内核程序总长度 0x00

sys_rountine_seg dd section.sys_rountine.start ; 公共例程段起始汇编地址 0x04

core_data_seg dd section.core_data.start ; 核心数据段起始汇编地址 0x08

core_code_seg dd section.core_code.start ; 核心代码段起始汇编地址 0x0c

; 核心代码段入口点
core_entry dd start ; 32位段内偏移地址
           dw core_code_seg_sel ; 内核代码段选择子


; ===================================================================
; 内核公共例程代码段
SECTION sys_rountine vstart=0

; 字符串显示例程
put_string:

put_char:

; 读取逻辑扇区例程
read_hard_disk:

; -------------------------------------------------------------------
; 分配内存例程
allocate_memory:
                                  ; 输入：ECX=程序希望分配的字节述
                                  ; 输出：ECX=分配内存的起始线性地址
    push ds
    push eax
    push ebx

    mov eax, core_data_seg_sel    ; 段选择器DS指向核心数据段
    mov ds, eax

    ; 计算下次分配的起始内存线性地址
    mov eax, [ram_allocate]
    add eax, ecx                  ; 下次分配的内存起始线性地址

    mov ecx, [ram_allocate]       ; 此次分配的内存起始地址

    mov ebx, eax
    and ebx, 0xfffffffc
    add ebx, 4                    ; 将地址4字节对齐

    test eax, 0x00000003          ; 测试下次分配的内存起始线性地址是否4字节对齐
    cmovnz eax, ebx               ; 没有对齐就强制对齐
    mov [ram_allocate], eax       ; 下次从该地址分配内存

    pop ebx
    pop eax
    pop ds

    retf                          ; 返回

; -------------------------------------------------------------------
; 安装段描述符例程
set_up_gdt_descriptor:            ; 输入：EDX:EAX=描述符
                                  ; 输出：CX=描述符的选择子
    push eax
    push ebx
    push edx

    push ds
    push es

    mov ebx, core_data_seg_sel    ; 段选择器DS指向内核数据段
    mov ds, ebx

    sgdt [pgdt]                   ; 取得GDT的基址和界限大小

    mov ebx, all_memory_seg_sel
    mov es, ebx                   ; 段选择器ES指向全部4G内存空间数据段

    ; 计算描述符安装地址
    movzx ebx, word [pgdt]        ; GDT界限零扩展
    inc bx                        ; GDT实际大小，总字节数
    add ebx, [pgdt + 2]           ; 下一个描述符的起始线性地址

    mov [es:ebx], eax             ; 将描述符写入该地址
    mov [es:ebx+4], edx

    add word [pgdt], 8            ; GDT界限值增加一个描述符的大小

    lgdt [pgdt]                   ; 重新加载GDTR，使新的描述符生效

    ; 生成段选择子
    mov ax, [pgdt]
    xor dx, dx
    mov bx,8
    div bx                        ; 得到当前描述符索引号
    mov cx, ax
    shl cx, 3                     ; 将索引号左移，留出TI、RPL位

    pop es
    pop ds

    pop edx
    pop ebx
    pop eax

    retf

; -------------------------------------------------------------------
; 构造描述符
make_gdt_descriptor:              ; 输入：EAX=段的线性基地址
                                  ;      EBX=段界限，低20位
                                  ;      ECX=段属性，各属性都在原始位置，无关位清零
                                  ; 输出：EDX:EAX=完整的描述符
    ; 构造描述符的低32位
    mov edx, eax                  ; 段的线性基地址
    shl eax, 16                   ; 线性基地址的低16位移至EAX的高16位
    or ax, bx                     ; EAX低16位为段界限的低16位

    ; 构造描述符的高32位
    and edx, 0xffff0000           ; 保留段基址高16位
    rol edx, 8                    ; 循环左移8位，最高8位至EDX低8位
    bswap edx                     ; 低8位与高8位数据互换，基地址构造完成

    and ebx, 0x000f0000           ; 保留段界限高4位
    or edx, ebx                   ; 装配段界限高4位

    or edx, ecx                   ; 装配段属性，高32位构造完成

    retf

; ===================================================================
; 内核核心数据段
SECTION core_data vstart=0

    pgdt       dw 0               ; 用于修改GDT，GDT界限
               dd 0               ; GDT基地址

    ram_allocate: dd 0x00100000   ; 下次分配内存时的起始地址，初始地址为0x00100000

    message_1: db '  If you seen this message,that means we '
               db 'are now in protect mode,and the system '
               db  'core is loaded,and the video display '
               db  'routine works perfectly.',0x0d,0x0a,0

    message_5: db '  Loading user program...',0

    core_buffer: times 2048 db 0  ; 内核缓冲区：分析、加工、中转数据

    brand0:    db 0x0d, 0x0a, ' ', 0
    brand:     times 52 db 0
    brand1:    db 0x0d, 0x0a, 0x0d, 0x0a, 0

; ===================================================================
; 内核核心代码段
SECTION core_code vstart=0

; 加载并重定位用户程序
load_relocate_program:
    push ebx
    push ecx
    push edx
    push esi                      ; esi存储用户程序其实逻辑扇区号
    push edi

    push ds
    push es

    mov eax, core_data_seg
    mov ds, eax                   ; 段选择器DS指向内核数据段

    ; 将用户程序第一个扇区读入数据段内核缓冲区
    mov eax, esi                  ; 逻辑扇区号
    mov ebx, core_buffer          ; 内核缓冲区
    call sys_rountine_seg_sel:read_hard_disk ; 调用例程读取逻辑扇区

    ; 获取用户程序所占字节数
    mov eax, [core_buffer]        ; 用户程序大小
    mov ebx, eax
    and ebx, 0xfffffe00           ; 将程序大小低九位清零
    add ebx, 512                  ; 增加一个扇区的字节数
    test eax, 0x000001ff          ; 测试用户程序大小是否为512倍数
    cmovnz eax, ebx               ; 如果不是，采用增加一个扇区的结果

    ; 获取申请内存空间的起始线性地址
    mov ecx, eax                  ; 需要申请的内存数量
    call sys_rountine_seg_sel:allocate_memory ; 调用分配内存例程
    mov ebx, ecx                  ; 申请到的内存起始线性地址
    push ebx                      ; 将首地址压栈

    ; 获取用户程序所占逻辑扇区数
    xor edx, edx
    mov ecx, 512
    div ecx
    mov ecx, eax                  ; 总扇区数

    mov eax, all_memory_seg_sel   ; 段选择器DS指向整个4GB内存区域
    mov ds, eax

    mov eax, esi                  ; 用户程序起始扇区号

    .b1:
    ; 将用户程序全部从扇区读至内存
    call sys_rountine_seg_sel:read_hard_disk ; 起始线性地址已经位于EBX中
    inc eax
    loop .b1                      ; 循环直到读完整个用户程序

    ; 创建用户程序头部段描述符
    pop edi                       ; 用户程序起始地址
    mov eax, edi
    mov ebx, [edi + 4]            ; 头部长度
    dec ebx                       ; 段界限
    mov ecx, 0x00409200           ; 头部段属性值

    call sys_rountine_seg_sel:make_seg_descriptor ; 调用例程创建描述符
    call sys_rountine_seg_sel:set_up_gdt_descriptor ; 调用例程把描述符安装到GDT中
    mov [edi + 4], cx             ; 将段选择子写回用户程序头部

    ; 创建用户程序代码段描述符
    mov eax, edi
    add eax, [edi+0x14]           ; 用户程序代码段内存起始线性地址
    mov ebx, [edi+0x18]           ; 代码段长度
    dec ebx                       ; 段界限
    mov ecx, 0x00409800           ; 代码段属性
    call sys_rountine_seg_sel:make_seg_descriptor
    call sys_rountine_seg_sel:set_up_gdt_descriptor
    mov [edi+0x14], cx            ; 将段选择子写回头部

    ; 创建用户程序数据段描述符
    mov eax, edi
    add eax, [edi+0x1c]
    mov ebx, [edi+0x20]
    dec ebx
    mov ecx, 0x00409800
    call sys_rountine_seg_sel:make_seg_descriptor
    call sys_rountine_seg_sel:set_up_gdt_descriptor
    mov [edi+0x1c], cx

    ; 建立程序堆栈段描述符
    mov ecx, [edi+0x0c]           ; 获取用户程序希望的栈段大小
    mov ebx, 0x000fffff
    sub ebx, ecx                  ; 段界限
    mov eax, 4096
    mul dword [edi+0x0c]          ; 所需栈大小
    mov ecx, eax                  ; 准备为堆栈分配内存
    call sys_rountine_seg_sel:allocate_memory
    add eax, ecx                  ; 得到堆栈的高端物理地址
    mov ecx, 0x00c09600           ; 段属性
    call sys_rountine_seg_sel:make_seg_descriptor
    call sys_rountine_seg_sel:set_up_gdt_descriptor
    mov [edi+0x08], cx



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
