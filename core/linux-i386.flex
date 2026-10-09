// i386 Linux compatibility ABI. Pointers and scalar layouts follow Linux's
// 32-bit UAPI, while the kernel, allocator and devices remain native Flexscript.
fn li_signed(n) {n=n&0xffffffff;if n&0x80000000 {return n-0x100000000;}return n;}
fn li_tls(va) {
    if !xp_range(va,16,1) {return -14;}let entry=xp_read32(va);let base=xp_read32(va+4);let limit=xp_read32(va+8);let flags=xp_read32(va+12);
    if entry==0xffffffff {entry=6;}if entry<6 || entry>8 || base>=0x40000000 || limit>0xfffff || flags&~127 || flags&6 {return -22;}
    let access=0xf2;if flags&8 {access=0xf0;}if flags&32 {access=access&~128;}let upper=0;if flags&1 {upper=upper|4;}if flags&16 {upper=upper|8;}
    store64(0x191000+entry*8,(limit&65535)|((base&65535)<<16)|(((base>>16)&255)<<32)|(access<<40)|(((limit>>16)&15)<<48)|(upper<<52)|(((base>>24)&255)<<56));xp_write32(va,entry);return 0;
}
fn li_stat(fd,va,extended) {
    let file=lx_fd(fd);if !file && !(fd<=2 && (lx_console&(1<<fd))) {return -9;}let size=64;if extended {size=96;}if !xp_range(va,size,1) {return -14;}
    let p=fo_take(size);bm_zero(p,size);let mode=0x21b6;let length=0;let device=0;
    if file {let node=load64(file);let kind=load64(node+8);if kind==1 {mode=0x41ed;}else if kind==2 {mode=0x81a4;length=load64(node+24);}else if kind==3 {device=0x1d00;}else if kind==4 {device=0xd40;}}
    if extended {store64(p,1);boot_w32(p+12,fd+1);boot_w32(p+16,mode);boot_w32(p+20,1);boot_w32(p+24,1000);boot_w32(p+28,1000);store64(p+32,device);store64(p+44,length);boot_w32(p+52,4096);store64(p+56,(length+511)/512);store64(p+88,fd+1);}
    else {boot_w32(p,1);boot_w32(p+4,fd+1);boot_w16(p+8,mode);boot_w16(p+10,1);boot_w16(p+12,1000);boot_w16(p+14,1000);boot_w32(p+16,device);boot_w32(p+20,length);boot_w32(p+24,4096);boot_w32(p+28,(length+511)/512);}
    xp_to_user(va,p,size);return 0;
}
fn li_clock(clock,va) {if clock!=0 && clock!=1 && clock!=7 {return -22;}if !xp_range(va,8,1) {return -14;}let ms=hp_now()-1;let sec=ms/1000;if clock==0 {sec=sec+rtc_epoch;}xp_write32(va,sec);xp_write32(va+4,(ms%1000)*1000000);return 0;}
fn li_time(va,tz) {if va && !xp_range(va,8,1) || tz && !xp_range(tz,8,1) {return -14;}let ms=hp_now()-1;if va {xp_write32(va,rtc_epoch+ms/1000);xp_write32(va+4,(ms%1000)*1000);}if tz {xp_write64(tz,0);}return 0;}
fn li_sleep(va,remain) {if !xp_range(va,8,0) || remain && !xp_range(remain,8,1) {return -14;}let sec=xp_read32(va);let ns=xp_read32(va+4);if sec>10 || ns>=1000000000 {return -22;}let until=hp_now()+sec*1000+(ns+999999)/1000000;while hp_now()<until {ld_poll_input();}if remain {xp_write64(remain,0);}return 0;}
fn li_iov(nr,fd,va,count) {if count>1024 {return -22;}if count && !xp_range(va,count*8,0) {return -14;}let i=0;let total=0;while i<count {let n=0;let address=xp_read32(va+i*8);let size=xp_read32(va+i*8+4);if nr==145 {n=lx_read(fd,address,size);}else {n=lx_write(fd,address,size);}if n<0 {if total {return total;}return n;}total=total+n;if n<size {return total;}i=i+1;}return total;}
fn li_call(nr,a,b,c,d,e,f) {
    if nr==395 {return ms_get(a,b,c);}if nr==396 {return ms_control(a,b,c,32);}if nr==397 {return ms_attach(a,b,c);}if nr==398 {return ms_detach(a);}
    if nr==117 {let call=a&65535;if call==23 {return ms_get(b,c,d);}if call==24 {return ms_control(b,c,e,32);}if call==22 {return ms_detach(e);}if call==21 {if !xp_range(d,4,1) {return -14;}let address=ms_attach(b,e,c);if address<0 {return address;}xp_write32(d,address);return 0;}return -38;}
    if nr==33 {return lx_access(-100,a,b,0);}if nr==307 || nr==439 {return lx_access(a,b,c,d);}if nr==383 {return lx_statx(a,b,c,d,e);}
    if nr==359 {return ls_socket(a,b,c);}if nr==362 {return ls_connect(a,b,c);}if nr==370 {return ls_message(a,b,c,0,32);}if nr==372 {return ls_message(a,b,c,1,32);}
    if nr==369 {if e || f {return -95;}return ls_write(a,b,c,d);}if nr==371 {if e || f {return -95;}return ls_read(a,b,c,d);}
    if nr==102 {if !xp_range(b,24,0) {return -14;}let x=xp_read32(b);let y=xp_read32(b+4);let z=xp_read32(b+8);if a==1 {return ls_socket(x,y,z);}if a==3 {return ls_connect(x,y,z);}if a==16 || a==17 {return ls_message(x,y,z,a==17,32);}if a==9 {return ls_write(x,y,z,xp_read32(b+12));}if a==10 {return ls_read(x,y,z,xp_read32(b+12));}return -95;}
    if nr==1 || nr==252 {return lx_finish(a&255);}if nr==3 {return lx_read(a,b,c);}if nr==4 {return lx_write(a,b,c);}if nr==5 {return lx_open(a,b&~0x8000);}if nr==6 {return lx_close(a);}
    if nr==19 {return lx_seek(a,li_signed(b),c);}if nr==20 || nr==224 {return 1;}if nr==64 {return 0;}if nr==24 || nr==47 || nr==49 || nr==50 || nr==199 || nr==200 || nr==201 || nr==202 {return 1000;}
    if nr==140 {if !xp_range(d,8,1) {return -14;}let result=lx_seek(a,(b<<32)|c,e);if result<0 {return result;}xp_write64(d,result);return 0;}
    if nr==45 {return lx_break(a);}if nr==91 {return lx_unmap(a,b);}if nr==125 {return lx_protect(a,b,c);}if nr==192 {return lx_map(a,b,c,d,e,f*4096);}
    if nr==90 {if !xp_range(a,24,0) {return -14;}return lx_map(xp_read32(a),xp_read32(a+4),xp_read32(a+8),xp_read32(a+12),xp_read32(a+16),xp_read32(a+20));}
    if nr==54 {return lx_ioctl(a,b,c);}if nr==55 || nr==221 {return lx_fcntl(a,b,c);}if nr==108 {return li_stat(a,b,0);}if nr==197 {return li_stat(a,b,1);}if nr==122 {return lx_uname(a);}
    if nr==78 {return li_time(a,b);}if nr==13 {if a && !xp_range(a,4,1) {return -14;}let sec=rtc_epoch+(hp_now()-1)/1000;if a {xp_write32(a,sec);}return sec;}
    if nr==265 {return li_clock(a,b);}if nr==403 {return lx_clock(a,b);}if nr==162 {return li_sleep(a,b);}if nr==267 {if b || a!=0 && a!=1 {return -22;}return li_sleep(c,d);}if nr==407 {if b || a!=0 && a!=1 {return -22;}return lx_sleep(c,d);}
    if nr==168 {return lx_poll(a,b,li_signed(c));}if nr==145 || nr==146 {return li_iov(nr,a,b,c);}if nr==220 {return lx_getdents(a,b,c);}if nr==295 {return lx_openat(a,b,c&~0x8000);}
    if nr==243 {return li_tls(a);}if nr==258 {if a && !xp_range(a,4,1) {return -14;}lx_clear_tid=a;return 1;}if nr==311 {if b!=12 || !xp_range(a,12,0) {return -22;}lx_robust=a;return 0;}if nr==340 {return lx_limit(a,b,c,d);}
    return -38;
}
fn li_dispatch(frame,a,b,c,d,e) {
    lx_calls=lx_calls+1;ld_poll_input();let mark=fo_mark();let nr=load64(frame+96)&0xffffffff;let result=li_call(nr,load64(frame+40)&0xffffffff,load64(frame+112)&0xffffffff,load64(frame+72)&0xffffffff,load64(frame+80)&0xffffffff,load64(frame+88)&0xffffffff,load64(frame+32)&0xffffffff);
    if lx_trace {platform_output(2,"I386 ");platform_output(2,fo_int(nr));platform_output(2," -> ");platform_output(2,fo_int(result));platform_output(2,"\n");}fo_reset(mark);return result&0xffffffff;
}
