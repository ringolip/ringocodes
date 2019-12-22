; 存储器的保护

; 初始化栈段和栈指针
mov eax, cs
mov ss, eax
mov sp, 0x7c00

; 计算GDT的逻辑地址和偏移地址
mov eax, [cs:agdt + 0x7c00 + 0x02] ; GDT32位线性地址
xor edx, edx ; edx置0
mov ebx, 16
div ebx

; 初始化数据段和段偏移地址，DS指向GDT所在逻辑段
mov ds, eax ; eax低16位为逻辑段地址
mov ebx, edx ; edx低16位为段偏移地址

; 安装0号段描述符
mov dword [ebx+0x00], 0x00000000
mov dword [ebx+0x04], 0x00000000

; 安装数据段描述符
; 段界限为0xfffff，段粒度为4KB，段界限为内存最大值4GB
mov dword [ebx+0x08], 0x0000ffff
mov dword [ebx+0x0c], 0x00cf9200

; 安装代码段描述符
mov dword [ebx+0x10], 0x7c0001ff
mov dword [ebx+0x14], 0x00409800

; 安装代码段别名描述符，将其定义为可读可写的数据段
mov dword [ebx+0x18], 0x7c0001ff
mov dword [ebx+0x1c], 0x00409200 ; 可读可写

; 安装栈段描述符
mov dword [ebx+0x20], 0x7c00fffe
mov dword [ebx+0x24], 0x00cf9600

; 初始化描述符表GDTR
mov word [cs:agdt + 0x7c00], 39

lgdt [cs:agdt+0x7c00] ; 6字节

; 开启A20
in al, 0x92
or al, 0000_0010B
out al, 0x92

; 关闭中断
cli

; 将cr0Pe位置1
mov eax, cr0
or eax, cr0
mov cr0, eax

; 以下进入保护模式


; 初始化GDT
agdt: 
dw 0
dd 0x00007e00 ; 在引导扇区之后

times 510 - ($-$$)

