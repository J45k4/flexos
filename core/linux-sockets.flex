// Local stream descriptors connected to the built-in X11 service endpoint.
// Internet sockets and application bind/listen are not implemented yet.
global ls_node=0;
fn ls_socket(domain,type,protocol) {if domain!=1 {return -97;}if (type&15)!=1 || type&~0x80801 || protocol {return -22;}if !ls_node {ls_node=platform_allocate(32);store64(ls_node+8,5);}let i=0;while i<16 {let file=lx_fds+i*32;if !load64(file+16) {store64(file,ls_node);store64(file+8,0);store64(file+16,1);let flags=0;if type&0x80000 {flags=flags|0x80000;}if type&0x800 {flags=flags|2048;}store64(file+24,flags);return i+3;}i=i+1;}return -24;}
fn ls_connect(fd,va,n) {let file=lx_fd(fd);if !file || load64(load64(file)+8)!=5 {return -88;}if n<3 || n>110 || !xp_range(va,n,0) {return -14;}if (load8(xp_pointer(va,0))|(load8(xp_pointer(va+1,0))<<8))!=1 {return -97;}let name=fo_take(109);let start=2;if !load8(xp_pointer(va+2,0)) {start=3;}let i=start;while i<n {store8(name+i-start,load8(xp_pointer(va+i,0)));i=i+1;}store8(name+n-start,0);if !fo_eq(name,"/tmp/.X11-unix/X0") {return -2;}if load64(file+8) {return -106;}if xs_fd>=0 {return -111;}xs_init();xs_fd=fd;store64(file+8,1);return 0;}
fn ls_ready(fd) {if fd!=xs_fd {return 0;}xs_input();return xs_tail-xs_head;}
fn ls_read(fd,va,n,flags) {if flags&~0x40000040 {return -95;}if fd!=xs_fd {return -107;}if n<0 || n>1048576 {return -22;}if !n {return 0;}if !xp_range(va,n,1) {return -14;}let file=lx_fd(fd);while !ls_ready(fd) {if (flags&64) || (load64(file+24)&2048) {return -11;}}
    let count=xs_tail-xs_head;if count>n {count=n;}xp_to_user(va,xs_out+xs_head,count);xs_head=xs_head+count;if xs_head==xs_tail {xs_head=0;xs_tail=0;}return count;
}
fn ls_write(fd,va,n,flags) {if fd!=xs_fd {return -107;}if flags&~16448 {return -95;}return xs_feed(va,n);}
fn ls_message(fd,va,flags,receive,bits) {
    let size=56;let word=8;if bits==32 {size=28;word=4;}if !xp_range(va,size,receive) {return -14;}let iov=0;let count=0;if bits==32 {iov=xp_read32(va+8);count=xp_read32(va+12);}else {iov=xp_read64(va+16);count=xp_read64(va+24);}if count>1024 || count && !xp_range(iov,count*word*2,0) {return -22;}
    let i=0;let total=0;while i<count {let address=0;let length=0;if bits==32 {address=xp_read32(iov+i*8);length=xp_read32(iov+i*8+4);}else {address=xp_read64(iov+i*16);length=xp_read64(iov+i*16+8);}let n=0;if receive {n=ls_read(fd,address,length,flags);}else {n=ls_write(fd,address,length,flags);}if n<0 {if total {return total;}return n;}total=total+n;if n<length {i=count;}else {i=i+1;}}
    if receive {if bits==32 {xp_write32(va+20,0);xp_write32(va+24,0);}else {xp_write64(va+40,0);xp_write32(va+48,0);}}return total;
}
