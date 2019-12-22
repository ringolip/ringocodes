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
mov word [cs:gdt_size + 0x7c00], 31 ; 共安装了4个段描述符，占据32个字节内存空间
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

; 此刻已处于实模式下
; 利用转移指令，清空流水线，并串行化执行
jmp dword 0x0008: flush ; 此时0x0008为段选择子，故跳转到代码段，EIP为flush偏移地址

; 按32位模式进行译码
[bits 32]

; 将显存映射加载至数据段
flush:
mov cx, 0000_0000_000_10_000B ; 段描述符索引为2
mov ds, cx ; 将显存映射加载进数据段选择器ds

; 将字符写入显存映射
mov byte [0x00], 'P'
mov byte [0x02], 'r'
mov byte [0x04], 'o'
mov byte [0x06], 't'
mov byte [0x08], 'e'
mov byte [0x0a], 'c'
mov byte [0x0c], 't'
mov byte [0x0e], ' '
mov byte [0x10], 'm'
mov byte [0x12], 'o'
mov byte [0x14], 'd'
mov byte [0x16], 'e'
mov byte [0x18], ' '
mov byte [0x1a], 'O'
mov byte [0x1c], 'K'

; 将描述符加载至栈段ss
mov cx, 0000_0000_000_11_000B ; 段选择子为3号描述符
mov ss, cx ; 加载至栈段
mov esp, 0x7c00 ; 栈指针为0x7c00

; 测试压栈是否以双字进行操作
mov ebp, esp ; 将栈指针拷贝至EBP
push byte '.' ; 将数据压栈
sub ebp, 4
cmp ebp, esp 
jnz not_equal ; 如果不相等，则不是以双字进行压栈
pop eax
mov byte [0x1e], al ; 相等则将数据传送至之前的数据之后


not_equal:
hlt ; 停机指令



; 定义GDT
gdt_size: dw 0 ; GDT界线，占16位
gdt_base: dd 0x00007e00 ; 设置GDT内存物理地址

times 510 - ($-$$) db 0
db 0x55, 0xaa