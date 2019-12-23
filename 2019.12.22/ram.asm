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

; 安装0号段描述符至GTD
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

; 将cr0Pe位置1，开启保护模式
mov eax, cr0
or eax, cr0
mov cr0, eax

; 以下进入保护模式
; 利用转移指令，清空流水线，并串型化执行
jmp dword 0x0010:flush ; 此时x0010为段选择子，故故跳转至代码段，EIP为flush汇编地址

; 按32位模式进行译码
[bits 32]

flush:
; 将代码段别名描述符安装至段选择器ds
mov eax, 0x0018
mov ds, eax ; 0000_0000_0001_1000B即为段描述符索引号为3

; 安装数据段描述符
mov eax, 0x0008 ; 0000_0000_0000_1000B，即描述符索引号为1
mov es, eax
mov fs,eax
mov gs,eax

; 安装栈段描述符
mov eax, 0x0020 ; 0000_0000_0010_0000B，即描述符为索引号为4
mov ss,eax
xor esp,esp ; 设置栈指针esp的初始值为0

; 向数据段显存映射写入数据
mov dword [es:0x000b8000], 0x072e0750
mov dword [es:0x000b8004], 0x072e074d
mov dword [es:0x000b8008], 0x07200720
mov dword [es:0x000b800c], 0x076b076f

; 对散乱字符进行排序
mov ecx, agdt-string-1 ; 总循环次数为字符串长度-1
; 外循环
external:
push ecx
xor bx,bx ; bx清零

; 内循环
internal:
mov ax, [string+bx]
cmp ah, al ; 将后一个字符与前一个相比较
jge next; 如果后一个字符大于等于前一个，则继续比较下一个
xchg ah, al ; 后一个字符小于前一个，则翻转字符
mov [string+bx], ax ; 写回内脆

next:
; 继续比较下一组字符
inc bx
loop internal ; ecx-1
; 继续下一组外循环
pop ecx
loop external ; ecx-1

; 显示排序好的字符
mov ecx, agdt-string
xor ebx, ebx

display:
mov ah, 0x07 ; 设置显示颜色
mov al, [string+ebx]
mov [es:0xb80a0 + ebx*2], ax ; 从屏幕第二行开始显示
inc ebx
loop display

; 停机
hlt

; 乱序字符串
string:
db 'houdaf8dsf828fphad'

; 初始化GDT
agdt:
dw 0
dd 0x00007e00 ; GTD物理地址，在引导扇区之后

times 510 - ($-$$) db 0
db 0x55, 0xaa
