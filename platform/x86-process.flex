import "bytes.flex";
// One user address space. Trampolines remain identity-mapped supervisor pages
// in both CR3s, so Linux executables can use 0x400000 while the kernel lives
// at the same virtual address in its own page tables. No app-specific ABI.
global xp_table=0x116000;
global xp_physical=0x2000000;
global xp_free=0;
global xp_emit=0;
fn xp_hex(s) {let i=0;while load8(s+i) {if load8(s+i)==32 {i=i+1;}else {let a=load8(s+i);let b=load8(s+i+1);if a>=65 {a=a-55;}else {a=a-48;}if b>=65 {b=b-55;}else {b=b-48;}store8(xp_emit,a*16+b);xp_emit=xp_emit+1;i=i+2;}}return 0;}
fn xp_word(n) {store64(xp_emit,n);xp_emit=xp_emit+8;return 0;}
fn xp_dword(n) {let i=0;while i<4 {store8(xp_emit,n>>(i*8));xp_emit=xp_emit+1;i=i+1;}return 0;}
fn xp_relative(target) {return xp_dword(target-xp_emit-4);}
fn xp_pte(va,create) {
    if va<0x400000 || va>=0x40000000 {return 0;}
    let directory=0x112000+(va>>30)*4096;let slot=directory+((va>>21)&511)*8;let value=load64(slot);
    if value&128 {if !create {return 0;}if xp_table>=0x178000 {return 0;}let p=xp_table;xp_table=xp_table+4096;bm_zero(p,4096);store64(slot,p|7);value=p|7;}
    return (value&0xfffff000)+((va>>12)&511)*8;
}
fn xp_page() {
    let p=xp_free;if p {xp_free=load64(p);}else {if xp_physical>=0x6000000 {return 0;}p=xp_physical;xp_physical=xp_physical+4096;}
    bm_zero(p,4096);return p;
}
fn xp_flags(prot) {let flags=4;if prot {flags=flags|1;}if prot&2 {flags=flags|2;}if !(prot&4) {flags=flags|0x8000000000000000;}return flags;}
fn xp_map(va,prot) {let slot=xp_pte(va,1);if !slot || load64(slot) {return 0;}let p=xp_page();if !p {return 0;}store64(slot,p|xp_flags(prot));return p;}
fn xp_unmap(va) {let slot=xp_pte(va,0);if slot && load64(slot) {let p=load64(slot)&0xfffff000;store64(slot,0);if p>=0x2000000 && p<0x6000000 && !ms_owns(p) {store64(p,xp_free);xp_free=p;}}return 0;}
fn xp_pointer(va,write) {let slot=xp_pte(va,0);if !slot {return 0;}let value=load64(slot);if !(value&1) || write && !(value&2) {return 0;}return (value&0xfffff000)+(va&4095);}
fn xp_range(va,n,write) {if n<0 || va<0x400000 || va>=0x40000000 || n>0x40000000-va {return 0;}if !n {return 1;}let end=va+n;while va<end {if !xp_pointer(va,write) {return 0;}va=(va&-4096)+4096;}return 1;}
fn xp_read64(va) {let value=0;let i=0;while i<8 {value=value|(load8(xp_pointer(va+i,0))<<(i*8));i=i+1;}return value;}
fn xp_read32(va) {let value=0;let i=0;while i<4 {value=value|(load8(xp_pointer(va+i,0))<<(i*8));i=i+1;}return value;}
fn xp_write32(va,value) {let i=0;while i<4 {store8(xp_pointer(va+i,1),value>>(i*8));i=i+1;}return 0;}
fn xp_write64(va,value) {let i=0;while i<8 {store8(xp_pointer(va+i,1),value>>(i*8));i=i+1;}return 0;}
fn xp_to_user(va,source,n) {let i=0;while i<n {let count=4096-(va&4095);if count>n-i {count=n-i;}boot_copy(xp_pointer(va,1),source+i,count);va=va+count;i=i+count;}return 0;}
fn xp_setup(dispatch,fault,dispatch32) {
    // PML4/PDPT and four directories: identity map privileged hardware/kernel;
    // individual user pages replace only their own 2-MiB directory entry.
    bm_zero(0x110000,0x68000);store64(0x110000,0x111007);let i=0;
    while i<4 {store64(0x111000+i*8,(0x112000+i*4096)|7);i=i+1;}
    i=0;while i<2048 {store64(0x112000+i*8,(i*0x200000)|0x83);i=i+1;}
    bm_zero(0x190000,0x5000);let gdt=0x191000;
    store64(gdt+8,0x00af9a000000ffff);store64(gdt+16,0x00cf92000000ffff);
    store64(gdt+24,0x00cff2000000ffff);store64(gdt+32,0x00affa000000ffff);
    store64(gdt+40,0x00cffa000000ffff); // ring-3 32-bit compatibility code
    // Leave indices 6..8 for Linux's i386 TLS selectors. The 64-bit TSS
    // occupies two descriptors at indices 11/12 instead.
    store64(gdt+88,0x0000891920000067); // 104-byte TSS at 0x192000
    store64(0x192004,0x280000);store64(0x192024,0x260000);store8(0x192066,104); // RSP0, IST1, no I/O bitmap
    store64(0x191100,103|(gdt<<16));store8(0x191108,0);store8(0x191109,0);
    store64(0x191110,4095|(0x193000<<16));
    // GDT/IDT/TSS setup bridge: lgdt [rdi]; lidt [rsi]; ltr ax; ret.
    xp_emit=0x180000;xp_hex("0F 01 17 0F 01 1E 66 B8 58 00 0F 00 D8 C3");
    // rdmsr(rdi) -> rax and wrmsr(rdi,rsi), System V word ABI.
    xp_emit=0x180100;xp_hex("89 F9 0F 32 48 C1 E2 20 48 09 D0 C3");
    xp_emit=0x180200;xp_hex("89 F9 48 89 F0 48 89 F2 48 C1 EA 20 0F 30 C3");
    // Enter user mode, keeping the kernel continuation in protected memory.
    xp_emit=0x180300;xp_hex("55 53 41 54 41 55 41 56 41 57 48 B8");xp_word(0x190000);xp_hex("48 89 20 B8");xp_dword(0x110000);xp_hex("0F 22 D8 6A 1B 56 6A 02 6A 23 57");
    xp_hex("31 C0 31 DB 31 C9 31 D2 31 F6 31 FF 31 ED 45 31 C0 45 31 C9 45 31 D2 45 31 DB 45 31 E4 45 31 ED 45 31 F6 45 31 FF 48 CF");
    // Exit/fault discards the syscall stack and resumes the kernel caller.
    xp_emit=0x180400;xp_hex("B8");xp_dword(0x100000);xp_hex("0F 22 D8 48 B8");xp_word(0x190000);xp_hex("48 8B 20 41 5F 41 5E 41 5D 41 5C 5B 5D 31 C0 C3");
    // SYSCALL does not switch RSP. Save it without touching user registers.
    // Frame: r15,r14,r13,r12,rbp,rbx,r9,r8,r10,rdx,rsi,rdi,rax,
    // followed by the five-word IRETQ frame (rip,cs,rflags,rsp,ss).
    xp_emit=0x180500;xp_hex("FC 48 89 25");xp_relative(0x190008);xp_hex("48 BC");xp_word(0x280000);
    xp_hex("6A 1B FF 35");xp_relative(0x190008);xp_hex("41 53 6A 23 51 50 57 56 52 41 52 41 50 41 51 53 55 41 54 41 55 41 56 41 57");
    xp_hex("48 89 E7 B8");xp_dword(0x100000);xp_hex("0F 22 D8 48 B8");xp_word(dispatch);xp_hex("FF D0 48 89 44 24 60 B8");xp_dword(0x110000);xp_hex("0F 22 D8 48 8B 4C 24 68 4C 8B 5C 24 78");
    xp_hex("41 5F 41 5E 41 5D 41 5C 5D 5B 41 59 41 58 41 5A 5A 5E 5F 58 48 CF");
    // Normal i386 Linux entry uses compatibility mode and the same separate
    // address space. DS/ES are flat user data; libc installs its own GS TLS.
    xp_emit=0x180900;xp_hex("55 53 41 54 41 55 41 56 41 57 48 B8");xp_word(0x190000);xp_hex("48 89 20 B8");xp_dword(0x110000);xp_hex("0F 22 D8 6A 1B 56 6A 02 6A 2B 57 66 B8 1B 00 8E D8 8E C0");
    xp_hex("31 C0 31 DB 31 C9 31 D2 31 F6 31 FF 31 ED 45 31 C0 45 31 C9 45 31 D2 45 31 DB 45 31 E4 45 31 ED 45 31 F6 45 31 FF 48 CF");
    // INT 0x80 switches stacks through the TSS. Preserve ECX as well as all
    // other i386 registers; its Linux argument ABI differs from SYSCALL.
    xp_emit=0x180a00;xp_hex("FC 51 41 53 50 57 56 52 41 52 41 50 41 51 53 55 41 54 41 55 41 56 41 57 48 89 E7 B8");xp_dword(0x100000);xp_hex("0F 22 D8 48 B8");xp_word(dispatch32);xp_hex("FF D0 48 89 44 24 60 B8");xp_dword(0x110000);xp_hex("0F 22 D8 41 5F 41 5E 41 5D 41 5C 5D 5B 41 59 41 58 41 5A 5A 5E 5F 58 41 5B 59 48 CF");
    let gate80=0x193000+128*16;store64(gate80,0xa00|(8<<16)|(0xee<<40)|(0x18<<48));
    // All CPU exceptions use a private IST stack. Fault callbacks receive
    // vector/error/rip/cs/rflags/rsp/ss and CR2; user faults terminate one app.
    xp_emit=0x180700;xp_hex("FA FC 48 89 E7 0F 20 D6 B8");xp_dword(0x100000);xp_hex("0F 22 D8 48 B8");xp_word(fault);xp_hex("48 83 E4 F0 FF D0 FA F4 EB FC");
    i=0;while i<32 {let handler=0x181000+i*32;xp_emit=handler;
        if !(i==8 || i>=10 && i<=14 || i==17 || i==21 || i==29 || i==30) {xp_hex("6A 00");}
        xp_hex("6A");store8(xp_emit,i);xp_emit=xp_emit+1;xp_hex("E9");xp_relative(0x180700);
        let gate=0x193000+i*16;store64(gate,(handler&65535)|(8<<16)|(1<<32)|(0x8e<<40)|(((handler>>16)&65535)<<48));store64(gate+8,handler>>32);i=i+1;
    }
    ffi_call(0x180000,0x191100,0x191110,0,0,0,0);
    let efer=ffi_call(0x180100,0xc0000080,0,0,0,0,0);ffi_call(0x180200,0xc0000080,efer|0x801,0,0,0,0);
    ffi_call(0x180200,0xc0000081,8<<32,0,0,0,0);ffi_call(0x180200,0xc0000082,0x180500,0,0,0,0);ffi_call(0x180200,0xc0000084,0x44700,0,0,0,0);
    return 0;
}
