; 理解BIOS中断

; =============================================================================
SECTION header vstart=0                          ; 用户程序头部段
    program_length           dd program_end      ; 程序总长度0x00

    program_entry            dw start            ; 偏移地址0x04
                             dd section.code.start ; 段地址0x06

    relocation_tbl:                              ; 段重定位表0x10
    code_segment             dd section.code.start
    data_segment             dd section.data.start
    stack_segment            dd section.stack.start

    relocation_tbl_len       dw ($-relocation_tbl)/4 ; 段重定位表项个数

header_end:

; =============================================================================
SECTION code align=16 vstart=0
start:
    mov ax, [stack_segment]
    mov ss, ax
    mov sp, ss_pointer
    mov ax, [data_segment]
    mov ds, ax

    mov cx, msg_end-message
    mov bx, message

  .put_c:
      mov ah, 0x0e    ; 执行int0x10的0x0e号调用
      mov al, [bx]
      int 0x10
      inc bx
      loop .put_c

  .reps:
      mov ah, 0x00    ; 执行int0x16的0x00号功能监听键盘
      int 16

      mov ah, 0x0e    ; 执行0x10的0x0e号调用
      mov bl, 0x07
      int 0x10

      jmp .reps

; =============================================================================
SECTION data align=16 vstart=0
    message       db 'Hello, friend!',0x0d,0x0a
                  db 'This simple procedure used to demonstrate '
                  db 'the BIOS interrupt.',0x0d,0x0a
                  db 'Please press the keys on the keyboard ->'
    msg_end:


; =============================================================================
SECTION stack align=16 vstart=0
              resb 256
ss_pointer:

; =============================================================================
SECTION program_trial
program_end:
