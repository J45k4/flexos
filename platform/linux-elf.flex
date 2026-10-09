import "x86-process.flex";
global le_bits=64;
global le_stride=56;
global le_entry=0;
global le_phdr=0;
global le_count=0;
global le_source=0;
global le_size=0;
global le_command=0;
global le_archive=0;
global le_archive_size=0;
fn le_prepare() {
    let info=load64(0x400028);fo_assert(info>0 && (boot_u32(info)&9)==9,"Linux target needs memory information and one ELF boot module");
    fo_assert(0x100000+boot_u32(info+8)*1024>=0x7000000,"Linux target needs 128 MiB RAM");
    let count=boot_u32(info+20);fo_assert(count==1 || count==2,"Linux target needs an ELF and optional rootfs tar module");let mods=boot_u32(info+24);
    fo_assert(mods>0 && mods<0x1000000-count*16,"invalid application module table");let code=boot_u32(mods);let end=boot_u32(mods+4);
    fo_assert(code>=boot_u32(0x400014) && end>code && end<=0x1000000,"application module must fit below kernel heap");le_source=code;le_size=end-code;
    if boot_u32(info)&4 {le_command=boot_u32(info+16);}
    if count==2 {fo_assert(0x100000+boot_u32(info+8)*1024>=0xf000000,"rootfs target needs 256 MiB RAM");let start=boot_u32(mods+16);let last=boot_u32(mods+20);
        fo_assert(start>=end && last>start && last<=0x6000000 && last-start<=0x3000000,"invalid rootfs module extent");le_archive=0xc000000;le_archive_size=last-start;boot_copy(le_archive,start,le_archive_size);
    }return 0;
}
fn le_module() {return le_load(le_source,le_size);}
fn le_field(h,offset) {
    if le_bits==64 {return load64(h+offset);}
    let at=offset/2;if offset==48 {at=28;}return boot_u32(h+at);
}
fn le_flags(h) {if le_bits==32 {return boot_u32(h+24);}return boot_u32(h+4);}
fn le_load(code,size) {
    fo_assert(size>=52 && boot_u32(code)==0x464c457f && (load8(code+4)==1 || load8(code+4)==2) && load8(code+5)==1 && load8(code+6)==1,"application must be little-endian ELF32 or ELF64");
    let header=64;let machine=62;let ph=0;let count=0;let stride=0;let entry=0;let entry_ok=0;
    if load8(code+4)==1 {le_bits=32;header=52;machine=3;ph=boot_u32(code+28);count=boot_u16(code+44);stride=boot_u16(code+42);entry=boot_u32(code+24);le_stride=32;}
    else {fo_assert(size>=64,"truncated ELF64 header");ph=load64(code+32);count=boot_u16(code+56);stride=boot_u16(code+54);entry=load64(code+24);}
    let hs=0;if le_bits==32 {hs=boot_u16(code+40);}else {hs=boot_u16(code+52);}
    fo_assert(boot_u16(code+16)==2 && boot_u16(code+18)==machine && boot_u32(code+20)==1 && hs==header,"application must be static x86 ET_EXEC");
    fo_assert(stride==le_stride && count>0 && count<=128 && ph>=header && ph<=size && count*stride<=size-ph,"invalid application program headers");
    let i=0;while i<count {let h=code+ph+i*stride;let type=boot_u32(h);fo_assert(type!=2 && type!=3,"dynamic linking is not supported yet");
        if type==7 {let off=le_field(h,8);let files=le_field(h,32);let memory=le_field(h,40);fo_assert(off>=0 && files>=0 && memory>=files && off<=size && files<=size-off && memory<=0x100000,"invalid TLS template");}
        if type==1 {let off=le_field(h,8);let va=le_field(h,16);let files=le_field(h,32);let memory=le_field(h,40);let align=le_field(h,48);
            fo_assert(off>=0 && files>=0 && memory>=files && off<=size && files<=size-off,"invalid application file extent");
            fo_assert(va>=0x400000 && va<0x8000000 && memory>=0 && memory<=0x8000000-va,"application segment outside supported address range");
            fo_assert(align>=0 && (align<=1 || align<=0x200000 && !(align&(align-1)) && !((va-off)&(align-1))),"invalid application segment alignment");
            fo_assert((le_flags(h)&7)==le_flags(h),"invalid application segment flags");
            if (le_flags(h)&1) && entry>=va && entry-va<files {entry_ok=1;}
            if ph>=off && ph+count*stride<=off+files {le_phdr=va+ph-off;}
            let j=0;while j<i {let other=code+ph+j*stride;if boot_u32(other)==1 {let start=le_field(other,16);let n=le_field(other,40);fo_assert(!memory || !n || va>=start+n || start>=va+memory,"overlapping application segments");}j=j+1;}
        }i=i+1;
    }fo_assert(entry_ok,"application entry must be inside executable file bytes");
    i=0;while i<count {let h=code+ph+i*stride;if boot_u32(h)==1 {let va=le_field(h,16);let memory=le_field(h,40);let files=le_field(h,32);let start=va&-4096;let end=(va+memory+4095)&-4096;
        let flags=le_flags(h);let prot=0;if flags&4 {prot=prot|1;}if flags&2 {prot=prot|2;}if flags&1 {prot=prot|4;}
        while start<end {let slot=xp_pte(start,1);fo_assert(slot,"application page-table limit");let old=load64(slot);
            if !old {fo_assert(xp_map(start,prot),"application memory limit");}
            else {let combined=old|xp_flags(prot);if prot&4 {combined=combined&0x7fffffffffffffff;}store64(slot,combined);}
            start=start+4096;
        }
        // Load through physical aliases, including read-only code pages.
        let n=0;while n<files {let pte=xp_pte(va+n,0);let p=(load64(pte)&0xfffff000)+((va+n)&4095);let take=4096-((va+n)&4095);if take>files-n {take=files-n;}boot_copy(p,code+le_field(h,8)+n,take);n=n+take;}
    }i=i+1;}
    if !le_phdr {le_phdr=0x7fff000;fo_assert(xp_map(le_phdr,1),"program-header mapping failed");fo_assert(count*stride<=4096,"unmapped program-header table is too large");boot_copy(xp_pointer(le_phdr,0),code+ph,count*stride);}
    le_entry=entry;le_count=count;return entry;
}
fn le_stack_word(p,value) {if le_bits==32 {return xp_write32(p,value);}return xp_write64(p,value);}
fn le_stack() {
    let p=0x3ff00000;while p<0x40000000 {fo_assert(xp_map(p,3),"application stack allocation failed");p=p+4096;}
    let argc=1;if le_command && load8(le_command) {fo_assert(fo_len(le_command)<=8192 && fo_parse(le_command),"invalid application arguments");if fo_word_count {argc=fo_word_count;}}
    let name=0x3fffffe0;xp_to_user(name,"/app",5);let env=0x3fffffd0;xp_to_user(env,"FLEXOS=1",9);let home=0x3fffffc0;xp_to_user(home,"HOME=/",7);let display=0x3fffffa0;xp_to_user(display,"DISPLAY=unix:0",15);let strings=0x3fff0000;let word=le_bits/8;
    let stack=0x3ffefe00;le_stack_word(stack,argc);le_stack_word(stack+word,name);let i=1;while i<argc {let s=load64(fo_words+i*8);let n=fo_len(s)+1;xp_to_user(strings,s,n);le_stack_word(stack+word*(1+i),strings);strings=strings+n;i=i+1;}
    le_stack_word(stack+word*(1+argc),0);le_stack_word(stack+word*(2+argc),env);le_stack_word(stack+word*(3+argc),home);le_stack_word(stack+word*(4+argc),display);le_stack_word(stack+word*(5+argc),0);
    let aux=stack+word*(6+argc);let items=fo_take(192);store64(items,3);store64(items+8,le_phdr);store64(items+16,4);store64(items+24,le_stride);store64(items+32,5);store64(items+40,le_count);
    store64(items+48,6);store64(items+56,4096);store64(items+64,9);store64(items+72,le_entry);store64(items+80,11);store64(items+88,1000);store64(items+96,12);store64(items+104,1000);store64(items+112,13);store64(items+120,1000);store64(items+128,14);store64(items+136,1000);store64(items+144,23);store64(items+152,0);store64(items+160,31);store64(items+168,name);store64(items+176,0);store64(items+184,0);
    i=0;while i<24 {le_stack_word(aux+i*word,load64(items+i*8));i=i+1;}return stack;
}
