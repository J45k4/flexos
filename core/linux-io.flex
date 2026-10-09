fn lx_getdents(fd,va,n) {
    let file=lx_fd(fd);if !file {return -9;}let folder=load64(file);if load64(folder+8)!=1 {return -20;}if n<0 || n>1048576 {return -22;}
    let path=load64(folder);let cursor=load64(file+8);let written=0;
    while cursor<lf_count+2 {let name=0;let kind=1;let inode=1;
        if cursor==0 {name=".";}else if cursor==1 {name="..";}else {let node=lf_nodes+(cursor-2)*32;let full=load64(node);
            if !fo_eq(full,path) && fo_eq(bm_parent(full),path) {let at=fo_len(path);if at>1 {at=at+1;}name=full+at;kind=load64(node+8);inode=cursor-1;}
        }
        if name {let length=fo_len(name);let size=(20+length+7)&-8;if size>n-written {if !written {return -22;}store64(file+8,cursor);return written;}
            if !xp_range(va+written,size,1) {return -14;}let record=fo_take(size);bm_zero(record,size);store64(record,inode);store64(record+8,cursor+1);boot_w16(record+16,size);let type=8;if kind==1 {type=4;}else if kind>=3 {type=2;}store8(record+18,type);boot_copy(record+19,name,length);xp_to_user(va+written,record,size);written=written+size;
        }cursor=cursor+1;
    }store64(file+8,cursor);return written;
}
fn lx_poll(va,count,timeout) {
    if count<0 || count>256 {return -22;}if !xp_range(va,count*8,1) && count {return -14;}let until=hp_now()+timeout;
    while 1 {ld_poll_input();let ready=0;let i=0;while i<count {let item=xp_read64(va+i*8);let fd=item&0xffffffff;let events=(item>>32)&65535;let revents=0;
            if fd<0x80000000 {if fd<=2 {if !(lx_console&(1<<fd)) {revents=32;}else if fd==0 {if port_in8(0x3fd)&1 {revents=events&1;}}else {revents=events&4;}}
                else {let file=lx_fd(fd);if !file {revents=32;}else {let kind=load64(load64(file)+8);if kind==5 {if ls_ready(fd) {revents=events&1;}revents=revents|(events&4);}else if kind==4 {if load64(file+8)<ld_write && (ld_grab<0 || ld_grab==fd) {revents=events&1;}}else {revents=events&5;}}}
            }xp_write64(va+i*8,(item&0x0000ffffffffffff)|(revents<<48));if revents {ready=ready+1;}i=i+1;
        }if ready || timeout==0 || timeout>0 && hp_now()>=until {return ready;}
    }return 0;
}
fn lx_ioctl(fd,request,va) {
    let file=lx_fd(fd);if file && load64(load64(file)+8)==5 {if request==0x541b {if !xp_range(va,4,1) {return -14;}xp_write32(va,ls_ready(fd));return 0;}return -25;}
    if fd>=0 && fd<=2 && (lx_console&(1<<fd)) {
        if request==0x5401 || request==0x802c542a {let size=36;if request!=0x5401 {size=44;}if !xp_range(va,size,1) {return -14;}let p=fo_take(size);bm_zero(p,size);boot_w32(p+8,0x8bd);store8(p+23,1);if size==44 {boot_w32(p+36,115200);boot_w32(p+40,115200);}xp_to_user(va,p,size);return 0;}
        if request==0x5413 {if !xp_range(va,8,1) {return -14;}xp_write64(va,25|(80<<16)|(pc_width<<32)|(pc_height<<48));return 0;}return -25;
    }return ld_ioctl(fd,request,va);
}
fn lx_iov(nr,fd,va,count) {
    if count<0 || count>1024 {return -22;}if count && !xp_range(va,count*16,0) {return -14;}let total=0;let i=0;
    while i<count {let address=xp_read64(va+i*16);let size=xp_read64(va+i*16+8);let n=0;if nr==19 {n=lx_read(fd,address,size);}else {n=lx_write(fd,address,size);}
        if n<0 {if total {return total;}return n;}total=total+n;if n<size {return total;}i=i+1;
    }return total;
}
fn lx_fcntl(fd,op,value) {
    let file=lx_fd(fd);if !file {if fd<0 || fd>2 || !(lx_console&(1<<fd)) {return -9;}if op==1 {return 0;}if op==3 {if fd {return 1;}return 0;}return -22;}
    if op==1 {return (load64(file+24)>>19)&1;}if op==2 {store64(file+24,(load64(file+24)&~0x80000)|((value&1)<<19));return 0;}
    if op==3 {return load64(file+24)&~0x80000;}if op==4 {if value&~2051 {return -22;}store64(file+24,(load64(file+24)&~2048)|(value&2048));return 0;}return -22;
}
