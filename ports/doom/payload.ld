ENTRY(doom_entry)
PHDRS { code PT_LOAD FLAGS(5); data PT_LOAD FLAGS(6); }
SECTIONS {
  . = 0x800000;
  .text : { *(.text .text.*) } :code
  .rodata : { *(.rodata .rodata.*) } :code
  . = ALIGN(4096);
  .data : { *(.data .data.*) } :data
  .bss : { *(.bss .bss.*) *(COMMON) } :data
  /DISCARD/ : { *(.eh_frame*) *(.comment) *(.note*) }
}
