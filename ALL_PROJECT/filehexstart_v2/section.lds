/* sections.lds - Linker Script cho 16KB RAM */
MEMORY
{
    /* RAM bắt đầu từ 0, độ dài 16KB */
    RAM (xrw) : ORIGIN = 0x00000000, LENGTH = 16K
}

SECTIONS
{
    /* Code và Read-only data */
    .text : {
        *(.text)
        *(.text.*)
        *(.rodata)
        *(.rodata.*)
    } > RAM

    /* Global data */
    .data : {
        *(.data)
        *(.data.*)
        *(.sdata)
    } > RAM

    /* Biến chưa khởi tạo */
    .bss : {
        *(.bss)
        *(.sbss)
    } > RAM
}