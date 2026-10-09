// Linux x86-64 syscall numbers/register ABI, implemented by FlexOS services.
// One process, read-only rootfs, device and local-service descriptors. Unknown calls fail
// with -ENOSYS; unsupported facilities are never reported as successful.
global lx_status=0;
global lx_calls=0;
global lx_fds=0;
global lx_console=7;
global lx_mmap=0x10000000;
global lx_brk=0x8000000;
global lx_fs=0;
global lx_clear_tid=0;
global lx_robust=0;
global lx_trace=0;
fn lx_finish(status) {lx_status=status;ffi_call(0x180400,0,0,0,0,0,0);cpu_halt();return 0;}
fn lx_fault(frame,address,a,b,c,d) {
    platform_output(2,"Linux process fault vector=");platform_output(2,fo_int(load64(frame)));platform_output(2," error=");platform_output(2,fo_int(load64(frame+8)));
    platform_output(2," address=");platform_output(2,fo_int(address));platform_output(2," cpl=");platform_output(2,fo_int(load64(frame+24)&3));platform_output(2,"\n");
    if (load64(frame+24)&3)!=3 {platform_output(2,"Kernel fault: halted.\n");cpu_halt();}return lx_finish(139);
}
fn lx_fd(fd) {if fd<3 || fd>=19 {return 0;}let p=lx_fds+(fd-3)*32;if !load64(p+16) {return 0;}return p;}
fn lx_string(va) {
    let out=fo_take(4096);let i=0;while i<4096 {let p=xp_pointer(va+i,0);if !p {return -14;}let c=load8(p);store8(out+i,c);if !c {return out;}i=i+1;}return -36;
}
fn lx_open(path,flags) {
    let s=lx_string(path);if s<0 {return s;}return lx_open_path(s,flags);
}
fn lx_open_path(s,flags) {
    if (flags&3)>2 {return -22;}s=fo_path(s);if !s {return -13;}let entry=lf_find(s);if !entry {if flags&64 {return -30;}return -2;}let kind=load64(entry+8);
    if flags&~0x90903 {return -22;}if (flags&0x10000) && kind!=1 {return -20;}if (flags&3) && kind!=3 {return -30;}
    let i=0;while i<16 {let fd=lx_fds+i*32;if !load64(fd+16) {store64(fd,entry);store64(fd+8,0);if kind==4 {store64(fd+8,ld_write);}store64(fd+16,1);store64(fd+24,flags);return i+3;}i=i+1;}return -24;
}
fn lx_openat(dirfd,path,flags) {let s=lx_string(path);if s<0 {return s;}if load8(s)!=47 && (dirfd&0xffffffff)!=0xffffff9c {let file=lx_fd(dirfd&0xffffffff);if !file {return -9;}let node=load64(file);if load64(node+8)!=1 {return -20;}s=fo_cat(fo_cat(load64(node),"/"),s);}return lx_open_path(s,flags);}
fn lx_node(dirfd,path,flags) {let s=lx_string(path);if s<0 {return s;}if !load8(s) && (flags&4096) {let file=lx_fd(dirfd);if !file {return -9;}return load64(file);}if load8(s)!=47 && (dirfd&0xffffffff)!=0xffffff9c {let file=lx_fd(dirfd);if !file {return -9;}if load64(load64(file)+8)!=1 {return -20;}s=fo_cat(fo_cat(load64(load64(file)),"/"),s);}s=fo_path(s);if !s {return -13;}let node=lf_find(s);if !node {return -2;}return node;}
fn lx_access(dirfd,path,mode,flags) {if mode&~7 || flags&~512 {return -22;}let node=lx_node(dirfd,path,0);if node<0 {return node;}if mode&2 {return -30;}if (mode&1) && load64(node+8)!=1 {return -13;}return 0;}
fn lx_statx(dirfd,path,flags,mask,va) {if flags&~(4096|256|0x800|0x6000) {return -22;}let node=lx_node(dirfd,path,flags);if node<0 {return node;}if !xp_range(va,256,1) {return -14;}let p=fo_take(256);bm_zero(p,256);let mode=0x21b6;let size=0;let kind=load64(node+8);if kind==1 {mode=0x41ed;}else if kind==2 {mode=0x81a4;size=load64(node+24);}else if kind==5 {mode=0xc1b6;}
    boot_w32(p,0x7ff);boot_w32(p+4,4096);boot_w32(p+16,1);boot_w32(p+20,1000);boot_w32(p+24,1000);boot_w16(p+28,mode);store64(p+32,node-lf_nodes+1);store64(p+40,size);store64(p+48,(size+511)/512);if kind==3 {boot_w32(p+128,29);}if kind==4 {boot_w32(p+128,13);boot_w32(p+132,64);}xp_to_user(va,p,256);return 0;}
fn lx_write(fd,va,n) {
    let file=lx_fd(fd);if file && load64(load64(file)+8)==5 {return ls_write(fd,va,n,0);}
    if fd<1 || fd>2 || !(lx_console&(1<<fd)) {return -9;}if n<0 || n>1048576 {return -22;}if !n {return 0;}if !xp_range(va,n,0) {return -14;}
    let i=0;while i<n {bm_put(load8(xp_pointer(va+i,0)));i=i+1;}return n;
}
fn lx_read(fd,va,n) {
    if n<0 || n>1048576 {return -22;}if !n {if fd==0 && (lx_console&1) || lx_fd(fd) {return 0;}return -9;}
    if fd==0 && (lx_console&1) {if !xp_range(va,n,1) {return -14;}while !(port_in8(0x3fd)&1) {ld_poll_input();}let i=0;while i<n && (port_in8(0x3fd)&1) {store8(xp_pointer(va+i,1),port_in8(0x3f8));i=i+1;}return i;}
    let file=lx_fd(fd);if !file {return -9;}let node=load64(file);let kind=load64(node+8);if kind==5 {return ls_read(fd,va,n,0);}if kind==4 {return ld_read(file,va,n);}if kind==1 {return -21;}if kind!=2 {return -22;}
    let content=load64(node+16);let pos=load64(file+8);let remaining=load64(node+24)-pos;
    if remaining<=0 {return 0;}if n>remaining {n=remaining;}if !xp_range(va,n,1) {return -14;}xp_to_user(va,content+pos,n);store64(file+8,pos+n);return n;
}
fn lx_close(fd) {if fd>=0 && fd<=2 && (lx_console&(1<<fd)) {lx_console=lx_console&~(1<<fd);return 0;}let file=lx_fd(fd);if !file {return -9;}if ld_grab==fd {ld_grab=-1;}if xs_fd==fd {xs_fd=-1;}bm_zero(file,32);return 0;}
fn lx_stat(fd,va) {
    let file=lx_fd(fd);if !file && !(fd>=0 && fd<=2 && (lx_console&(1<<fd))) {return -9;}if !xp_range(va,144,1) {return -14;}
    let s=fo_take(144);bm_zero(s,144);store64(s,1);store64(s+8,fd+1);store64(s+16,1);let mode=0x21b6;let size=0;
    if file {let node=load64(file);let kind=load64(node+8);if kind==1 {mode=0x41ed;}else if kind==2 {mode=0x81a4;size=load64(node+24);}else {mode=0x21b6;if kind==3 {store64(s+40,0x1d00);}else {store64(s+40,0xd40);}}}
    store64(s+24,mode|(1000<<32));store64(s+32,1000);store64(s+48,size);store64(s+56,4096);store64(s+64,(size+511)/512);xp_to_user(va,s,144);return 0;
}
fn lx_seek(fd,offset,whence) {
    let file=lx_fd(fd);if !file {if fd>=0 && fd<=2 {return -29;}return -9;}if load64(load64(file)+8)!=2 {return -29;}let pos=offset;if whence==1 {pos=pos+load64(file+8);}else if whence==2 {pos=pos+load64(load64(file)+24);}else if whence!=0 {return -22;}
    if pos<0 || pos>0x7fffffff {return -22;}store64(file+8,pos);return pos;
}
fn lx_map(address,n,prot,flags,fd,offset) {
    let file=lx_fd(fd);if file && load64(load64(file)+8)==3 {return ld_fb_map(n,prot,flags,offset);}
    if n<=0 || n>0x4000000 || prot<0 || prot>7 || flags!=34 || (fd&0xffffffff)!=0xffffffff || offset!=0 {return -22;}
    let length=(n+4095)&-4096;let start=lx_mmap;if length>0x30000000-start {return -12;}let p=start;
    while p<start+length {if !xp_map(p,prot) {let rollback=start;while rollback<p {xp_unmap(rollback);rollback=rollback+4096;}return -12;}p=p+4096;}
    lx_mmap=start+length;return start;
}
fn lx_unmap(address,n) {if address<0x400000 || address>=0x40000000 || (address&4095) || n<=0 || n>0x40000000-address {return -22;}let end=(address+n+4095)&-4096;while address<end {xp_unmap(address);address=address+4096;}return 0;}
fn lx_protect(address,n,prot) {
    if address<0x400000 || address>=0x40000000 || (address&4095) || n<0 || n>0x40000000-address || prot<0 || prot>7 {return -22;}let end=(address+n+4095)&-4096;let p=address;
    while p<end {let slot=xp_pte(p,0);if !slot || !load64(slot) {return -12;}p=p+4096;}
    while address<end {let slot=xp_pte(address,0);store64(slot,(load64(slot)&0xfffff018)|xp_flags(prot));address=address+4096;}return 0;
}
fn lx_break(address) {
    if address<0x8000000 || address>=0x10000000 {return lx_brk;}let old=(lx_brk+4095)&-4096;let end=(address+4095)&-4096;let p=old;
    if end>old {while p<end {if !xp_map(p,3) {let rollback=old;while rollback<p {xp_unmap(rollback);rollback=rollback+4096;}return lx_brk;}p=p+4096;}}
    else {p=end;while p<old {xp_unmap(p);p=p+4096;}}lx_brk=address;return address;
}
fn lx_uname(va) {
    if !xp_range(va,390,1) {return -14;}let s=fo_take(390);bm_zero(s,390);boot_copy(s,"FlexOS",7);boot_copy(s+65,"flexos",7);boot_copy(s+130,"0.1-linux-abi",14);boot_copy(s+195,"Flexscript kernel",18);boot_copy(s+260,"x86_64",7);xp_to_user(va,s,390);return 0;
}
fn lx_clock(clock,va) {if clock!=0 && clock!=1 && clock!=7 {return -22;}if !xp_range(va,16,1) {return -14;}let ms=hp_now()-1;let seconds=ms/1000;if clock==0 {seconds=seconds+rtc_epoch;}xp_write64(va,seconds);xp_write64(va+8,(ms%1000)*1000000);return 0;}
fn lx_time(va,tz) {if va && !xp_range(va,16,1) || tz && !xp_range(tz,8,1) {return -14;}let ms=hp_now()-1;if va {xp_write64(va,rtc_epoch+ms/1000);xp_write64(va+8,(ms%1000)*1000);}if tz {xp_write64(tz,0);}return 0;}
fn lx_sleep(va,remain) {
    if !xp_range(va,16,0) || remain && !xp_range(remain,16,1) {return -14;}let seconds=xp_read64(va);let nanos=xp_read64(va+8);if seconds<0 || seconds>10 || nanos<0 || nanos>=1000000000 {return -22;}
    let until=hp_now()+seconds*1000+(nanos+999999)/1000000;while hp_now()<until {ld_poll_input();}if remain {xp_write64(remain,0);xp_write64(remain+8,0);}return 0;
}
fn lx_arch(op,address) {
    if op==0x1002 {if address<0 || address>=0x40000000 {return -1;}lx_fs=address;ffi_call(0x180200,0xc0000100,address,0,0,0,0);return 0;}
    if op==0x1003 {if !xp_range(address,8,1) {return -14;}xp_write64(address,lx_fs);return 0;}return -22;
}
fn lx_limit(pid,resource,new,old) {
    if pid!=0 && pid!=1 {return -3;}if new {return -1;}let value=0;if resource==3 {value=1048576;}else if resource==7 {value=19;}else {return -22;}
    if old {if !xp_range(old,16,1) {return -14;}xp_write64(old,value);xp_write64(old+8,value);}return 0;
}
fn lx_call(nr,a,b,c,d,e,f) {
    if nr==29 {return ms_get(a,b,c);}if nr==30 {return ms_attach(a,b,c);}if nr==31 {return ms_control(a,b,c,64);}if nr==67 {return ms_detach(a);}
    if nr==21 {return lx_access(-100,a,b,0);}if nr==269 || nr==439 {return lx_access(a,b,c,d);}if nr==332 {return lx_statx(a,b,c,d,e);}
    if nr==41 {return ls_socket(a,b,c);}if nr==42 {return ls_connect(a,b,c);}if nr==46 {return ls_message(a,b,c,0,64);}if nr==47 {return ls_message(a,b,c,1,64);}if nr==44 {if e || f {return -95;}return ls_write(a,b,c,d);}if nr==45 {if e || f {return -95;}return ls_read(a,b,c,d);}
    if nr==0 {return lx_read(a,b,c);}if nr==1 {return lx_write(a,b,c);}if nr==2 {return lx_open(a,b);}if nr==3 {return lx_close(a);}if nr==5 {return lx_stat(a,b);}if nr==8 {return lx_seek(a,b,c);}
    if nr==7 {return lx_poll(a,b,c);}if nr==16 {return lx_ioctl(a,b,c);}if nr==19 || nr==20 {return lx_iov(nr,a,b,c);}if nr==72 {return lx_fcntl(a,b,c);}if nr==217 {return lx_getdents(a,b,c);}
    if nr==9 {return lx_map(a,b,c,d,e,f);}if nr==10 {return lx_protect(a,b,c);}if nr==11 {return lx_unmap(a,b);}if nr==12 {return lx_break(a);}if nr==35 {return lx_sleep(a,b);}if nr==39 || nr==186 {return 1;}
    if nr==60 || nr==231 {return lx_finish(a&255);}if nr==63 {return lx_uname(a);}if nr==102 || nr==104 || nr==107 || nr==108 {return 1000;}if nr==110 {return 0;}
    if nr==228 {return lx_clock(a,b);}if nr==257 {return lx_openat(a,b,c);}
    if nr==96 {return lx_time(a,b);}if nr==201 {if a && !xp_range(a,8,1) {return -14;}let now=rtc_epoch+(hp_now()-1)/1000;if a {xp_write64(a,now);}return now;}
    if nr==230 {if b!=0 || a!=0 && a!=1 {return -22;}return lx_sleep(c,d);}
    if nr==158 {return lx_arch(a,b);}if nr==218 {if a && !xp_range(a,4,1) {return -14;}lx_clear_tid=a;return 1;}
    if nr==273 {if b!=24 {return -22;}if !xp_range(a,24,0) {return -14;}lx_robust=a;return 0;}if nr==302 {return lx_limit(a,b,c,d);}
    return -38;
}
fn lx_dispatch(frame,a,b,c,d,e) {
    lx_calls=lx_calls+1;ld_poll_input();let mark=fo_mark();let nr=load64(frame+96);let result=lx_call(nr,load64(frame+88),load64(frame+80),load64(frame+72),load64(frame+64),load64(frame+56),load64(frame+48));
    if lx_trace {platform_output(2,"SYSCALL ");platform_output(2,fo_int(nr));platform_output(2," -> ");platform_output(2,fo_int(result));platform_output(2,"\n");}fo_reset(mark);return result;
}
