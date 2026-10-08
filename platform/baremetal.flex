import "../core/memory.flex";
// First native target: one x86-64 CPU, >=64 MiB RAM, polled 16550 COM1.
// Page tables and a stack are installed by the Flexscript compiler backend.
// Interrupts remain masked; storage is an owned RAM filesystem, not host files.
global bm_heap=0x1000000;
global bm_free=0;
global bm_files=0;
global bm_error=0;
global bm_last_cr=0;
fn platform_title() {return "FlexOS bare-metal kernel";}
fn platform_banner() {return "FlexOS · bare-metal Flexscript kernel\nCPU: x86-64 long mode; Linux: absent\nType help to begin.\n";}
fn platform_resources() {return "filesystem / ram read,write (volatile)\nconsole COM1 serial\nexecution unavailable (bare-metal VM port pending)\n";}
fn bm_zero(p,n) {let i=0;while i<n {store8(p+i,0);i=i+1;}return p;}
fn platform_allocate(n) {
    if n<0 || n>8388608 {return -12;}n=(n+7)/8*8;let prev=0;let block=bm_free;
    while block {
        if load64(block)>=n {
            if prev {store64(prev+8,load64(block+8));}else {bm_free=load64(block+8);}
            return bm_zero(block+16,load64(block));
        }prev=block;block=load64(block+8);
    }
    if bm_heap+n+16>0x2000000 {return -12;}
    block=bm_heap;bm_heap=bm_heap+n+16;store64(block,n);store64(block+8,0);
    return bm_zero(block+16,n);
}
fn platform_free(p,n) {
    if p<0x1000010 || p>=bm_heap {platform_output(2,"Invalid kernel free\n");cpu_halt();}
    let block=p-16;store64(block+8,bm_free);bm_free=block;return 0;
}
fn bm_put(c) {while !(port_in8(0x3fd)&32) {}port_out8(0x3f8,c);return 0;}
fn platform_output(fd,text) {let i=0;while load8(text+i) {let c=load8(text+i);if c==10 {bm_put(13);}bm_put(c);i=i+1;}return i;}
fn platform_exit(status) {
    platform_output(2,"Kernel stopped, status=");platform_output(2,fo_int(status));platform_output(2,"\n");cpu_halt();return 0;
}
fn platform_input(p,n) {
    let i=0;
    while i<n && (port_in8(0x3fd)&1) {
        let c=port_in8(0x3f8);
        if c==10 && bm_last_cr {bm_last_cr=0;}
        else {
            bm_last_cr=c==13;if c==13 {c=10;}
            // Echo complete lines; input remains bounded in the shared core.
            if c==10 {bm_put(13);bm_put(10);}else {if c>=32 || c==9 {bm_put(c);}}
            store8(p+i,c);i=i+1;if c==10 {return i;}
        }
    }if !i {return -11;}return i;
}
fn platform_wait(apps,count,timeout,stdin) {return 0;}
fn platform_now() {return 0;}
fn platform_error() {return bm_error;}
fn bm_find(path) {
    let i=0;while i<64 {let entry=bm_files+i*32;if load64(entry) && fo_eq(load64(entry),path) {return entry;}i=i+1;}return 0;
}
fn bm_parent(path) {
    let n=fo_len(path);let i=0;let slash=0;while i<n {if load8(path+i)==47 {slash=i;}i=i+1;}
    if !slash {return "/";}return fo_slice(path,slash);
}
fn platform_directory(path) {if fo_eq(path,"/") {return 0;}let entry=bm_find(path);if !entry {return -2;}if load64(entry+8)!=1 {return -20;}return 0;}
fn bm_add(path,kind,text) {
    if fo_eq(path,"/") {return -17;}
    let status=platform_directory(bm_parent(path));if status<0 {return status;}
    let i=0;while i<64 {let entry=bm_files+i*32;if !load64(entry) {
        store64(entry,fo_keep(path));store64(entry+8,kind);if kind==2 {store64(entry+16,fo_keep(text));}return 0;
    }i=i+1;}return -28;
}
fn platform_read(path) {
    let entry=bm_find(path);bm_error=-2;if fo_eq(path,"/") {bm_error=-21;}
    if !entry {return 0;}if load64(entry+8)!=2 {bm_error=-21;return 0;}
    bm_error=0;return fo_slice(load64(entry+16),fo_len(load64(entry+16)));
}
fn platform_write(path,text) {
    if fo_len(text)>65536 {return -27;}if fo_eq(path,"/") {return -21;}
    let entry=bm_find(path);if !entry {return bm_add(path,2,text);}if load64(entry+8)!=2 {return -21;}
    let old=load64(entry+16);let content=fo_keep(text);store64(entry+16,content);platform_free(old,fo_len(old)+1);return 0;
}
fn platform_mkdir(path) {if bm_find(path) || fo_eq(path,"/") {return -17;}return bm_add(path,1,0);}
fn platform_remove(path) {
    if fo_eq(path,"/") {return -13;}let entry=bm_find(path);if !entry {return -2;}
    if load64(entry+8)==1 {let i=0;while i<64 {let child=bm_files+i*32;if load64(child) && fo_eq(bm_parent(load64(child)),path) {return -39;}i=i+1;}}
    let name=load64(entry);platform_free(name,fo_len(name)+1);
    if load64(entry+16) {let text=load64(entry+16);platform_free(text,fo_len(text)+1);}
    bm_zero(entry,32);return 0;
}
fn platform_list(path) {
    bm_error=platform_directory(path);if bm_error<0 {return 0;}
    let b=fo_buffer();let i=0;while i<64 {let entry=bm_files+i*32;
        if load64(entry) && fo_eq(bm_parent(load64(entry)),path) {
            let name=load64(entry);let offset=fo_len(bm_parent(name));if offset>1 {offset=offset+1;}
            fo_text(b,name+offset);if load64(entry+8)==1 {fo_text(b,"/");}fo_text(b,"\n");
        }i=i+1;
    }return fo_data(b);
}
// VM process operations are deliberately unavailable on this initial target.
fn platform_launch(app,source,arguments,count) {return -38;}
fn platform_app_read(fd,p,n) {return 0;}
fn platform_app_output(p,n) {let i=0;while i<n {bm_put(load8(p+i));i=i+1;}return 0;}
fn platform_status(pid) {return -1;}
fn platform_stop(pid) {return -38;}
fn platform_close(fd) {return 0;}
fn platform_cleanup() {return 0;}
fn platform_init() {
    // 115200 baud, 8N1, FIFO enabled, interrupts off.
    port_out8(0x3f9,0);port_out8(0x3fb,128);port_out8(0x3f8,1);port_out8(0x3f9,0);
    port_out8(0x3fb,3);port_out8(0x3fa,199);port_out8(0x3fc,11);
    fo_assert(load64(0x400020)==0x2badb002,"invalid Multiboot handoff");
    let info=load64(0x400028);
    fo_assert(info>0 && (load64(info)&1),"Multiboot memory information required");
    let upper=(load64(info+8)&0xffffffff)*1024;
    fo_assert(upper>=0x2000000,"insufficient guest RAM for kernel heap");
    // Exercise full word arithmetic and memory before exposing a shell.
    let probe=platform_allocate(8);store64(probe,0x123456789abcdef0);
    fo_assert(load64(probe)==0x123456789abcdef0,"64-bit memory self-check failed");platform_free(probe,8);
    bm_files=platform_allocate(2048);
    platform_write("/welcome.txt","Welcome to FlexOS. This kernel and its boot code were generated by Flexscript.\nStorage is volatile RAM. Type help for commands.");
    return 0;
}
