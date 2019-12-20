; 主引导程序512字节，占据0x0000 7c00~0x0000 7e00
; 所以将栈指针设置为0x7c00 由物理内存空间向下增长
; 将GDT的起始基地址设置为0x0000 7e00 有物理内存空间向上增长

set:
; 初始化代码段，栈段的基地址，将栈指针设置为引导扇区数据段地址
mov ax, cs
mov ss, ax
mov sp, 0x7c00

; 将GDT的线性地址转换为逻辑段地址和偏移地址
mov ax, [cs:gdt_base + 0x7c00] ; GDT内存物理地址的低16位
mov dx, [cs:gdt_base + 0x7c00 + 0x02] ; GDT内存物理地址的高16位

mov bx, 16

mov ds, ax ; 将ds设为GDT逻辑段地址
mov bx, dx ; 将bx设为GDT偏移地址

; 安装描述符
; 初始化GDT第一个描述符为空
mov dword [bx], 0x0000 ; 低4字节
mov dword [bx+0x04], 0x0000 ; 高4字节

; 安装代码段描述符
mov dword [bx+0x08], 0x7c0001ff
mov dword [bx+0x0c], 0x00409800

; 安装数据段描述符(显存映射)
mov dword [bx+0x10], 0x8000ffff
mov dword [bx+0x14], 0x0040920b

; 安装栈段描述符,段界限决定了栈段的最小值
mov dword [bx+0x18], 0x00007a00
mov dword [bx+0x1c], 0x00409600

; 加载GDT的线性基地址和界限到GDTR
mov [cs:gdt_size + 0x7c00], 31 ; 共安装了4个段描述符，占据32个字节内存空间
lgdt [cs:gdt_size + 0x7c00] ; 占据6字节内存空间，低16位为GDT界线值，高32位为GDT线性地址


; 打开第21根地址线
in al, 0x92 ; 从ICH读取端口0x92数据
or al, 0000_0010B ; 将第1位置1,目的为打开A20，使第21根地址线有效
out 0x92, al ; 

; 保护模式下的中断机制尚未建立，应禁止中断
cli ; 将IF标志位置0


; cr0第0位置1，开启保护模式
mov eax, cr0
or eax, 1
mov cr0, eax


; 定义GDT
gdt_size: dw 0 ; GDT界线，占16位
gdt_base: dd 0x00007e00 ; 设置GDT内存物理地址

