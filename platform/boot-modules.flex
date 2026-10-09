import "bytes.flex";
// Multiboot 1 binary modules and a constrained static ELF64 game loader.
// Payload memory: 8..12 MiB. WAD copy: 64..112 MiB. Kernel heap: 16..32 MiB.
global boot_wad=0;
global boot_wad_size=0;
fn boot_modules() {
    let info=load64(0x400028);fo_assert(load64(0x400020)==0x2badb002 && info>0,"invalid boot handoff");
    let flags=boot_u32(info);fo_assert((flags&9)==9,"Doom needs memory information and two boot modules");
    let ram=0x100000+boot_u32(info+8)*1024;fo_assert(ram>=0x7000000,"Doom needs 128 MiB RAM");
    fo_assert(boot_u32(info+20)==2,"Doom needs exactly two modules: game ELF and WAD");
    let mods=boot_u32(info+24);fo_assert(mods>0 && mods<=ram-32,"invalid module table");
    let code=boot_u32(mods);let end=boot_u32(mods+4);let data=boot_u32(mods+16);let data_end=boot_u32(mods+20);
    fo_assert(code>=boot_u32(0x400014) && end>code && end<=0x800000,"game module must fit below 8 MiB");
    fo_assert(data>=end && data_end>data && data_end<=0x4000000,"invalid WAD boot module extent");
    boot_wad_size=data_end-data;fo_assert(boot_wad_size>=12 && boot_wad_size<=0x3000000,"WAD size must be 12 bytes..48 MiB");
    fo_assert(boot_u32(data)==0x44415749,"Doom requires an IWAD");let lumps=boot_u32(data+4);let dir=boot_u32(data+8);
    fo_assert(lumps>0 && lumps<=1000000 && dir<=boot_wad_size && lumps*16<=boot_wad_size-dir,"invalid WAD directory");
    boot_wad=0x4000000;boot_copy(boot_wad,data,boot_wad_size);
    let size=end-code;fo_assert(size>=64 && boot_u32(code)==0x464c457f && load8(code+4)==2 && load8(code+5)==1,"game must be little-endian ELF64");
    fo_assert(boot_u16(code+16)==2 && boot_u16(code+18)==62 && boot_u32(code+20)==1,"game must be static x86-64 ELF executable");
    let ph=load64(code+32);let count=boot_u16(code+56);let stride=boot_u16(code+54);let entry=load64(code+24);let entry_ok=0;
    fo_assert(stride==56 && count>0 && count<=32 && ph>=64 && ph<=size && count*stride<=size-ph,"invalid ELF program headers");
    let i=0;while i<count {let header=code+ph+i*stride;let type=boot_u32(header);
        fo_assert(type!=2 && type!=3 && type!=7,"dynamic linking and TLS are unsupported");
        if type==1 {let off=load64(header+8);let address=load64(header+16);let files=load64(header+32);let memory=load64(header+40);
            fo_assert(off>=0 && files>=0 && memory>=files && off<=size && files<=size-off,"invalid ELF file extent");
            fo_assert(address>=0x800000 && address<=0xc00000 && memory<=0xc00000-address,"ELF segment outside game region");
            if (boot_u32(header+4)&1) && entry>=address && entry-address<memory {entry_ok=1;}
        }i=i+1;
    }fo_assert(entry_ok,"ELF entry must be inside executable game segment");
    i=0;while i<count {let header=code+ph+i*stride;if boot_u32(header)==1 {let address=load64(header+16);let files=load64(header+32);let memory=load64(header+40);
        boot_copy(address,code+load64(header+8),files);let n=files;while n<memory {store8(address+n,0);n=n+1;}
    }i=i+1;}
    return entry;
}
