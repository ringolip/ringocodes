
; -------------------------------------------------------------------
; 用户程序相关的统计数据

    program_length          dd program_end            ; 程序总长度0x00
    entry_point             dd start                  ; 程序入口点0x04
    ; 用户SALT表信息
    salt_position           dd salt_begin             ; SALT起始偏移量
    salt_items              dd (salt_end-salt_begin)/256 ; SALT条目数

; -------------------------------------------------------------------
; 程序中用到的数据

           ; 符号地址检索表
           salt_begin:

           PrintString      db  '@PrintString'
                       times 256-($-PrintString) db 0

           TerminateProgram db  '@TerminateProgram'
                       times 256-($-TerminateProgram) db 0
; -------------------------------------------------------------------

           reserved  times 256*500 db 0            ;保留一个空白区，以演示分页

; -------------------------------------------------------------------
           ReadDiskData     db  '@ReadDiskData'
                       times 256-($-ReadDiskData) db 0

           PrintDwordAsHex  db  '@PrintDwordAsHexString'
                       times 256-($-PrintDwordAsHex) db 0

           salt_end:

           message_0        db  0x0d,0x0a,
                            db  '  ............User task is running with '
                            db  'paging enabled!............',0x0d,0x0a,0

           space            db  0x20,0x20,0

; -------------------------------------------------------------------
    [bits 32]
; -------------------------------------------------------------------
; 可执行代码
start:





program_end:
