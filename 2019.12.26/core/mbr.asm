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

; 在保护模式下访问
flush:
; 开始加载内核

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

; 判断内核程序有多大
mov eax, [edi] ; 内核程序总大小


; 从硬盘读取一个逻辑扇区
read_first_disk:
push eax
push ecx
push edx

push eax







pgdt:
dw 0 ; GDT界限
dd 0x00007e00 ; GDT线性基地址
