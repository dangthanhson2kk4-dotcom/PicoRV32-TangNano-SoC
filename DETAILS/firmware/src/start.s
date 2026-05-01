# start.s - Startup code cho PicoRV32
.section .text.init
.global _start

_start:
    # 1. Thiết lập Stack Pointer (sp)
    lui sp, %hi(0x4000)
    addi sp, sp, %lo(0x4000)

    # 2. Xóa các thanh ghi khác (Tùy chọn nhưng nên làm)
    li gp, 0
    li tp, 0

    # 3. Nhảy đến hàm main trong file C
    jal ra, main

    # 4. Nếu main thoát (vòng lặp vô tận bị hỏng), treo CPU ở đây
loop_forever:
    j loop_forever

    