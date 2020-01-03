; 主引导程序

; 声明内核程序的位置
core_start_address equ 0x00040000 ; 在内存中的起始地址0x00040000
core_start_sector equ 0x00000001 ; 在硬盘中的起始逻辑扇区

; 为进入保护模式做准备工作
mov ax, cs
mov ss, ax ; 初始化栈段
mov sp, 0x7c00 ; 初始化栈指针

; 计算GDT逻辑地址
mov eax, [cs:pgdt + 0x7c00 + 0x02] ; GDT32位起始物理地址
xor edx, edx
mov ebx, 16
div ebx ; 分解位16位逻辑地址

mov ds,eax ; DS指向GDT段地址
mov ebx, edx ; ebx指向段内偏移地址

; 在GDT中安装段描述符

; #1描述符，数据段，对应0~4G线性地址空间
mov dword [ebx + 0x08], 0x0000ffff ; 基地址为0，段界限为0xfffff
mov dword [ebx + 0x0c], 0x00cf9200 ; 粒度为4kb，存储器段描述符

; #2描述符，保护模式下代码段描述符
mov dword [ebx + 0x10], 0x7c0001ff ; 基地址为0x00007c00，段界限为0x001ff
mov dword [ebx + 0x14], 0x00409800 ; 粒度为1字节，代码段描述符

; #3描述符，保护模式下的堆栈描述符
mov dword [ebx + 0x18], 0x7c00fffe ; 基地址为0x00007c00, 界限0xffffe
mov dword [ebx + 0x1c], 0x00cf8600 ; 粒度为4kb

; #4描述符，保护模式下显示缓冲区描述符
mov dword [ebx + 0x20], 0x80007fff ; 基地址为0x000b8000, 界限0x07fff
mov dword [ebx + 0x24], 0x0040920b ; 粒度为1字节

; 初始化描述符表寄存器GDTR
mov word [cs:pgdt + 0x7c00], 39 ; GDT界限
lgdt [cs:pgdt + 0x7c00] ; 加载GDT线性基地址和边界至GDTR

; 打开A20
in al, 0x92
or al, 0000_0010B
out 0x92, al

; 保护模式下中断机制尚未建立，禁止中断
cli

; 设置PE位，开启保护模式
mov eax, cr0
or eax, 1
mov cr0, eax

; 以下进入保护模式

; 清空流水线并串型化处理器
jmp dword 0x0010:flush ; 段选择子的描述符索引为2号描述符

[bits 32]

; 开始加载内核
flush:
; 初始化各段寄存器
mov eax, 0x0008
mov ds,eax ; DS指向数据段的4GB内存空间

mov eax, 0x0018
mov ss,eax ; SS指向堆栈段内存空间
xor esp,esp

; 把内核程序读入内存
mov edi, core_start_address
mov eax, core_start_sector
mov ebx, edi
call read_first_disk ; 调用过程读取内核程序的第一个扇区

; 计算内核程序所占扇区数
mov eax, [edi] ; 内核程序总大小
xor edx, edx
mov ecx, 512
div ecx

or edx, edx ; 判断是否能整除
jnz @1 ; 未能整除，剩余扇区不需要再减1
dec eax ; 已经读取了一个扇区，得出剩余的扇区数

; 未能整除时
@1:
; 若内核程序总大小不到一个扇区
or eax, eax
jz setup
; 读取剩余扇区
mov ecx, eax ; 待读取的剩余的扇区数
mov eax, core_start_sector
inc eax ; 第二个逻辑扇区

; 从逻辑扇区读取剩余内核程序
@2:
call read_first_disk
inc eax
loop @2

; 安装内核程序的各个段描述符
setup:
mov esi, [0x0070 + pgdt + 0x02] # ESI指向GDT起始线性地址

; 建立公共例程段描述符
mov eax, [edi + 0x04] ; 公共例程段起始汇编地址
mov ebx, [edi + 0x08] ; 核心数据段起始汇编地址

sub ebx, eax ; 计算公共例程段界限
dec ebx

add eax, edi ; 公共例程段在内存的线性地址
mov ecx, 0x00409800 ; 字节粒度的代码段描述符
call make_gdt_descriptor ; 调用过程，获得描述符

mov [esi + 0x28], eax ; #5描述符，内核公共例程段描述符
mov [esi + 0x2c], edx

; 建立核心数据段描述符
mov eax, [edi + 0x08] ; 核心数据段起始汇编地址
mov ebx, [edi + 0x0c] ; 核心代码段起始汇编地址

sub ebx,eax ; 计算核心数据段界限
dec ebx

add eax, edi ; 核心数据段在内存中的线性地址
mov eax, 0x00409200 ; 字节粒度在数据段描述符
call make_gdt_descriptor ; 调用过程，获得描述符

mov [esi + 0x30], eax ; #6描述符，内核核心数据段描述符
mov [esi + 0x34], edx

; 建立核心代码段数据描述符
mov eax, [edi + 0x0c] ; 核心代码段起始汇编地址
mov ebx, [edi + 0x00] ; 内核程序总长度

sub ebx, eax ; 计算核心代码段界限
dec ebx

add eax, edi ; 核心代码段在内存中的线性地址
mov ecx, 0x00409800 ; 字节粒度的代码段描述符
call make_gdt_descriptor ; 调用过程，获得描述符

mov [esi + 0x30], eax ; #7描述符，内核核心代码段描述符
mov [esi + 0x34], edx

; 重新加载GDTR
mov word [0x7c00 + pgdt], 63 ; 通过4GB数据段修改GDTR界限
lgdt [0x7c00 + pgdt]

; 跳转至内核核心程序入口处
jmp far [edi + 0x10]




; 从硬盘读取一个逻辑扇区
read_first_disk:


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

    ret

; -------------------------------------------------------------------
pgdt:
dw 0 ; GDT界限
dd 0x00007e00 ; GDT线性基地址

times 510 - ($-$$) db 0
                   db 0x55, 0xaa
