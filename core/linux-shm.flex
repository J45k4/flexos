// System V shared memory: bounded segment and attachment tables, real shared
// physical pages, independent mappings, and deletion after all references end.
global ms_segments=0;
global ms_attachments=0;
global ms_next=1;
global ms_owned=0;
fn ms_init() {if !ms_segments {ms_segments=platform_allocate(512);ms_attachments=platform_allocate(768);ms_owned=platform_allocate(16384);}return 0;}
fn ms_find(id) {if !ms_segments || id<=0 {return 0;}let i=0;while i<8 {let s=ms_segments+i*64;if load64(s)==id {return s;}i=i+1;}return 0;}
fn ms_owns(physical) {if !ms_owned || physical<0x2000000 || physical>=0x6000000 {return 0;}return load8(ms_owned+(physical-0x2000000)/4096);}
fn ms_drop(s) {if !load64(s+40) || load64(s+32) || load64(s+56) {return 0;}let count=(load64(s+16)+4095)/4096;let pages=load64(s+24);let i=0;while i<count {let p=load64(pages+i*8);store8(ms_owned+(p-0x2000000)/4096,0);store64(p,xp_free);xp_free=p;i=i+1;}platform_free(pages,count*8);bm_zero(s,64);return 0;}
fn ms_get(key,size,flags) {
    ms_init();if flags&~0x7ff || size<0 || size>8388608 {return -22;}let i=0;let empty=0;
    while i<8 {let s=ms_segments+i*64;if !load64(s) {empty=s;}else if key && load64(s+8)==key && !load64(s+40) {if (flags&0x600)==0x600 {return -17;}if size>load64(s+16) {return -22;}return load64(s);}i=i+1;}
    if key && !(flags&512) {return -2;}if !size {return -22;}if !empty {return -28;}let count=(size+4095)/4096;let pages=platform_allocate(count*8);if pages<0 {return -12;}i=0;
    while i<count {let physical=xp_page();if !physical {let j=0;while j<i {let p=load64(pages+j*8);store64(p,xp_free);xp_free=p;j=j+1;}platform_free(pages,count*8);return -12;}store64(pages+i*8,physical);i=i+1;}
    i=0;while i<count {store8(ms_owned+(load64(pages+i*8)-0x2000000)/4096,1);i=i+1;}store64(empty,ms_next);ms_next=ms_next+1;store64(empty+8,key);store64(empty+16,size);store64(empty+24,pages);store64(empty+48,flags&511);return load64(empty);
}
fn ms_attach(id,address,flags) {
    let s=ms_find(id);if !s {return -22;}if address || flags&~4096 {return -22;}let i=0;let slot=0;while i<32 {let a=ms_attachments+i*24;if !load64(a) {slot=a;}i=i+1;}if !slot {return -24;}
    let n=(load64(s+16)+4095)&-4096;let start=lx_mmap;if n>0x30000000-start {return -12;}let prot=3;if flags&4096 {prot=1;}i=0;
    while i<n {let pte=xp_pte(start+i,1);if !pte {let j=0;while j<i {store64(xp_pte(start+j,0),0);j=j+4096;}return -12;}store64(pte,load64(load64(s+24)+(i/4096)*8)|xp_flags(prot));i=i+4096;}
    lx_mmap=start+n;store64(slot,s);store64(slot+8,start);store64(slot+16,n);store64(s+32,load64(s+32)+1);return start;
}
fn ms_detach(address) {if !ms_attachments {return -22;}let i=0;while i<32 {let a=ms_attachments+i*24;if load64(a) && load64(a+8)==address {let s=load64(a);let n=load64(a+16);let j=0;while j<n {let slot=xp_pte(address+j,0);if slot {store64(slot,0);}j=j+4096;}bm_zero(a,24);store64(s+32,load64(s+32)-1);ms_drop(s);return 0;}i=i+1;}return -22;}
fn ms_control(id,command,va,bits) {
    let s=ms_find(id);if !s {return -22;}command=command&~256;if command==0 {store64(s+40,1);ms_drop(s);return 0;}if command!=2 {return -22;}let size=112;let segment=48;let pid=80;let attached=88;if bits==32 {size=84;segment=36;pid=64;attached=72;}if !xp_range(va,size,1) {return -14;}
    let p=fo_take(size);bm_zero(p,size);boot_w32(p,load64(s+8));boot_w32(p+4,1000);boot_w32(p+8,1000);boot_w32(p+12,1000);boot_w32(p+16,1000);boot_w32(p+20,load64(s+48));boot_w32(p+pid,1);boot_w32(p+pid+4,1);if bits==32 {boot_w32(p+segment,load64(s+16));boot_w32(p+attached,load64(s+32)+load64(s+56));}else {store64(p+segment,load64(s+16));store64(p+attached,load64(s+32)+load64(s+56));}xp_to_user(va,p,size);return 0;
}
fn ms_copy(destination,s,offset,n) {if offset<0 || n<0 || offset>load64(s+16) || n>load64(s+16)-offset {return -22;}let copied=0;while copied<n {let take=4096-(offset&4095);if take>n-copied {take=n-copied;}let physical=load64(load64(s+24)+(offset/4096)*8)+(offset&4095);boot_copy(destination+copied,physical,take);offset=offset+take;copied=copied+take;}return 0;}
