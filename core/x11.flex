// Bounded core X11 service. Wire-format requests, resources and events are
// independent of applications; Linux clients connect through AF_UNIX streams.
// One little-endian client, indexed 8-bit windows and MIT-SHM images.
global xs_in=0;
global xs_in_size=0;
global xs_out=0;
global xs_head=0;
global xs_tail=0;
global xs_setup=0;
global xs_sequence=0;
global xs_resources=0;
global xs_focus=0;
global xs_input_cursor=0;
global xs_fd=-1;
global xs_trace=0;
global xs_properties=0;
fn xs_queue(p,n) {if n>1048576-xs_tail {if xs_head {boot_copy(xs_out,xs_out+xs_head,xs_tail-xs_head);xs_tail=xs_tail-xs_head;xs_head=0;}}if n>1048576-xs_tail {return -105;}boot_copy(xs_out+xs_tail,p,n);xs_tail=xs_tail+n;return 0;}
fn xs_resource(id) {if id<=0 {return 0;}let i=0;while i<64 {let r=xs_resources+i*96;if load64(r)==id {return r;}i=i+1;}return 0;}
fn xs_new(id,kind) {if id==0 || xs_resource(id) {return 0;}let i=0;while i<64 {let r=xs_resources+i*96;if !load64(r) {bm_zero(r,96);store64(r,id);store64(r+8,kind);return r;}i=i+1;}return 0;}
fn xs_reply(n) {let p=fo_take(n);bm_zero(p,n);store8(p,1);boot_w16(p+2,xs_sequence);boot_w32(p+4,(n-32)/4);return p;}
fn xs_error(code,op,id) {let p=fo_take(32);bm_zero(p,32);store8(p+1,code);boot_w16(p+2,xs_sequence);boot_w32(p+4,id);store8(p+10,op);return xs_queue(p,32);}
fn xs_init() {
    if !xs_in {xs_in=platform_allocate(262144);xs_out=platform_allocate(1048576);xs_resources=platform_allocate(6144);xs_properties=platform_allocate(3072);}
    xs_in_size=0;xs_head=0;xs_tail=0;xs_setup=0;xs_sequence=0;xs_focus=0;xs_input_cursor=ld_write;
    // Release owned buffers when a client disconnects/reconnects.
    let i=0;while i<64 {let r=xs_resources+i*96;if load64(r+48) {if load64(r+8)==6 {let s=load64(r+48);store64(s+56,load64(s+56)-1);ms_drop(s);}else {let size=load64(r+16)*load64(r+24);if load64(r+8)==4 {size=2048;}platform_free(load64(r+48),size);}}i=i+1;}bm_zero(xs_resources,6144);i=0;while i<64 {let prop=xs_properties+i*48;if load64(prop+32) {platform_free(load64(prop+32),load64(prop+40));}i=i+1;}bm_zero(xs_properties,3072);
    let root=xs_new(1,1);store64(root+16,pc_width);store64(root+24,pc_height);store64(root+64,2);store64(root+80,8);
    let cmap=xs_new(2,4);let palette=platform_allocate(2048);store64(cmap+48,palette);i=0;while i<256 {store64(palette+i*8,i*0x010101);i=i+1;}return 0;
}
fn xs_property(window,atom,create) {let i=0;let empty=0;while i<64 {let p=xs_properties+i*48;if load64(p)==window && load64(p+8)==atom {return p;}if !load64(p) {empty=p;}i=i+1;}if create && empty {store64(empty,window);store64(empty+8,atom);return empty;}return 0;}
fn xs_greeting() {
    let p=fo_take(136);bm_zero(p,136);store8(p,1);boot_w16(p+2,11);boot_w16(p+6,32);boot_w32(p+8,1);boot_w32(p+12,0x200000);boot_w32(p+16,0x1fffff);boot_w16(p+24,8);boot_w16(p+26,65535);
    store8(p+28,1);store8(p+29,2);store8(p+32,32);store8(p+33,32);store8(p+34,8);store8(p+35,255);boot_copy(p+40,"FlexOS X",8);
    store8(p+48,1);store8(p+49,1);store8(p+50,32);store8(p+56,8);store8(p+57,8);store8(p+58,32);
    boot_w32(p+64,1);boot_w32(p+68,2);boot_w32(p+72,255);boot_w16(p+84,pc_width);boot_w16(p+86,pc_height);boot_w16(p+88,270);boot_w16(p+90,200);boot_w16(p+92,1);boot_w16(p+94,1);boot_w32(p+96,3);store8(p+102,8);store8(p+103,1);
    store8(p+104,8);boot_w16(p+106,1);boot_w32(p+112,3);store8(p+116,3);store8(p+117,8);boot_w16(p+118,256);return xs_queue(p,136);
}
fn xs_values(r,p,mask) {let i=0;let n=0;while i<15 {if mask&(1<<i) {let value=boot_u32(p+n*4);if i==11 {store64(r+56,value);}if i==13 {store64(r+64,value);}n=n+1;}i=i+1;}return n;}
fn xs_present(r) {
    if load64(r+8)!=1 || !load64(r+72) || !load64(r+48) {return 0;}let cmap=xs_resource(load64(r+64));if !cmap || load64(cmap+8)!=4 {return 0;}
    let colors=load64(cmap+48);let w=load64(r+16);let h=load64(r+24);let rx=load64(r+32);let ry=load64(r+40);let left=0;let top=0;let right=w;let bottom=h;
    // Clip once. Keep row pointers and bounds out of the conversion loop:
    // synchronous rendering otherwise holds up every client and input event.
    if rx<0 {left=-rx;}if ry<0 {top=-ry;}if right>pc_width-rx {right=pc_width-rx;}if bottom>pc_height-ry {bottom=pc_height-ry;}
    if left>=right || top>=bottom {return 0;}let source=load64(r+48)+top*w+left;let target=pc_fb+((ry+top)*pc_width+rx+left)*4;let count=right-left;let pairs=count/2;let y=top;
    while y<bottom {let from=source;let to=target;let end=source+pairs*2;
        while from<end {let first=load64(colors+load8(from)*8);let second=load64(colors+load8(from+1)*8);store64(to,first|(second<<32));from=from+2;to=to+8;}
        if count&1 {boot_w32(to,load64(colors+load8(from)*8));}
        ld_poll_input();source=source+w;target=target+pc_width*4;y=y+1;
    }
    // Keys drained during this frame must precede its completion event so
    // clients waiting for that event can process them in the same iteration.
    xs_input();return 0;
}
fn xs_keysym(code,shift) {
    if code==1 {return 0xff1b;}if code==14 {return 0xff08;}if code==15 {return 0xff09;}if code==28 || code==96 {return 0xff0d;}if code==29 {return 0xffe3;}if code==97 {return 0xffe4;}
    if code==42 {return 0xffe1;}if code==54 {return 0xffe2;}if code==56 {return 0xffe9;}if code==100 {return 0xffea;}if code==57 {return 32;}if code>=59 && code<=68 {return 0xffbe+code-59;}if code==87 {return 0xffc8;}if code==88 {return 0xffc9;}
    if code==103 {return 0xff52;}if code==108 {return 0xff54;}if code==105 {return 0xff51;}if code==106 {return 0xff53;}
    let c=0;if code>=2 && code<=13 {let s="1234567890-=";if shift {s="!@#$%^&*()_+";}return load8(s+code-2);}
    if code>=16 && code<=27 {c=load8("qwertyuiop[]"+code-16);}if code>=30 && code<=41 {c=load8("asdfghjkl;'`"+code-30);}if code>=43 && code<=53 {c=load8("\\zxcvbnm,./"+code-43);}if shift && c>=97 && c<=122 {c=c-32;}return c;
}
fn xs_input() {
    if xs_fd<0 || !xs_setup {return 0;}ld_poll_input();if xs_input_cursor<ld_write-256 {xs_input_cursor=ld_write-256;}
    while xs_input_cursor<ld_write {let ev=ld_events+(xs_input_cursor%256)*24;xs_input_cursor=xs_input_cursor+1;let type=boot_u16(ev+16);let code=boot_u16(ev+18);let down=boot_u32(ev+20);
        if type==1 && xs_focus && down<=1 {let r=xs_resource(xs_focus);let mask=1;if !down {mask=2;}if r && (load64(r+56)&mask) {let p=fo_take(32);bm_zero(p,32);let event=2;if !down {event=3;}store8(p,event);store8(p+1,code+8);boot_w16(p+2,xs_sequence);boot_w32(p+4,load64(ev)*1000+load64(ev+8)/1000);boot_w32(p+8,1);boot_w32(p+12,xs_focus);store8(p+30,1);xs_queue(p,32);}}
    }return 0;
}
fn xs_shm_request(p,n) {
    let op=load8(p+1);if op==0 {if n!=4 {return xs_error(16,128,0);}let out=xs_reply(32);boot_w16(out+8,1);boot_w16(out+12,1000);boot_w16(out+14,1000);store8(out+16,2);return xs_queue(out,32);}
    if op==1 {if n!=16 {return xs_error(16,128,0);}let s=ms_find(boot_u32(p+8));if !s || load8(p+12)>1 {return xs_error(128,128,boot_u32(p+8));}let r=xs_new(boot_u32(p+4),6);if !r {return xs_error(14,128,boot_u32(p+4));}store64(r+48,s);store64(r+80,load8(p+12));store64(s+56,load64(s+56)+1);return 0;}
    if op==2 {if n!=8 {return xs_error(16,128,0);}let r=xs_resource(boot_u32(p+4));if !r || load64(r+8)!=6 {return xs_error(128,128,boot_u32(p+4));}let s=load64(r+48);store64(s+56,load64(s+56)-1);bm_zero(r,96);ms_drop(s);return 0;}
    if op==3 {if n!=40 {return xs_error(16,128,0);}let id=boot_u32(p+4);let r=xs_resource(id);if !r || load64(r+8)>2 {return xs_error(9,128,id);}let shared=xs_resource(boot_u32(p+32));if !shared || load64(shared+8)!=6 {return xs_error(128,128,boot_u32(p+32));}let s=load64(shared+48);let width=boot_u16(p+12);let height=boot_u16(p+14);let sx=boot_u16(p+16);let sy=boot_u16(p+18);let w=boot_u16(p+20);let h=boot_u16(p+22);let dx=boot_u16(p+24);let dy=boot_u16(p+26);let stride=(width+3)&-4;let offset=boot_u32(p+36);
        if load8(p+28)!=8 || load8(p+29)!=2 || !w || !h || sx>width || w>width-sx || sy>height || h>height-sy || dx>load64(r+16) || w>load64(r+16)-dx || dy>load64(r+24) || h>load64(r+24)-dy || offset>load64(s+16) || stride*height>load64(s+16)-offset {return xs_error(2,128,id);}
        let row=0;while row<h {ms_copy(load64(r+48)+(dy+row)*load64(r+16)+dx,s,offset+(sy+row)*stride+sx,w);row=row+1;}xs_present(r);
        // Off-screen windows and pixmaps also complete without deferring keys.
        xs_input();
        if load8(p+30) {let out=fo_take(32);bm_zero(out,32);store8(out,64);boot_w16(out+2,xs_sequence);boot_w32(out+4,id);boot_w16(out+8,3);store8(out+10,128);boot_w32(out+12,boot_u32(p+32));boot_w32(out+16,offset);return xs_queue(out,32);}return 0;
    }return xs_error(1,128,op);
}
fn xs_request(p,n) {
    let op=load8(p);let id=0;if n>=8 {id=boot_u32(p+4);}let r=xs_resource(id);if xs_trace {platform_output(2,"X11 ");platform_output(2,fo_int(op));platform_output(2," bytes=");platform_output(2,fo_int(n));platform_output(2,"\n");}
    if op==18 {if n<24 || !r || load64(r+8)!=1 {return xs_error(3,op,id);}let format=load8(p+16);let bytes=boot_u32(p+20)*(format/8);if (format!=8 && format!=16 && format!=32) || bytes>16384 || ((bytes+3)&-4)!=n-24 || load8(p+1)>2 {return xs_error(16,op,id);}let prop=xs_property(id,boot_u32(p+8),1);if !prop {return xs_error(11,op,id);}let old=load64(prop+32);let length=load64(prop+40);let mode=load8(p+1);if mode && old && (load64(prop+16)!=boot_u32(p+12) || load64(prop+24)!=format) {return xs_error(8,op,id);}if !mode {length=0;}if bytes+length>16384 {return xs_error(11,op,id);}let data=platform_allocate(bytes+length);if data<0 {if !old {bm_zero(prop,48);}return xs_error(11,op,id);}if mode==1 {boot_copy(data,p+24,bytes);if length {boot_copy(data+bytes,old,length);}}else {if length {boot_copy(data,old,length);}boot_copy(data+length,p+24,bytes);}if old {platform_free(old,load64(prop+40));}store64(prop+16,boot_u32(p+12));store64(prop+24,format);store64(prop+32,data);store64(prop+40,length+bytes);return 0;}
    if op==20 {if n!=24 || !r || load64(r+8)!=1 {return xs_error(3,op,id);}let prop=xs_property(id,boot_u32(p+8),0);let out=xs_reply(32);if !prop {return xs_queue(out,32);}let length=load64(prop+40);let requested=boot_u32(p+12);if requested && requested!=load64(prop+16) {store8(out+1,load64(prop+24));boot_w32(out+8,load64(prop+16));boot_w32(out+12,length);return xs_queue(out,32);}let offset=boot_u32(p+16)*4;if offset>length {return xs_error(2,op,offset);}let count=length-offset;let limit=boot_u32(p+20)*4;if count>limit {count=limit;}out=xs_reply(32+((count+3)&-4));store8(out+1,load64(prop+24));boot_w32(out+8,load64(prop+16));boot_w32(out+12,length-offset-count);boot_w32(out+16,count/(load64(prop+24)/8));boot_copy(out+32,load64(prop+32)+offset,count);let status=xs_queue(out,32+((count+3)&-4));if load8(p+1) && offset+count==length {platform_free(load64(prop+32),length);bm_zero(prop,48);}return status;}
    if op==98 {if n<8 || ((boot_u16(p+4)+3)&-4)!=n-8 {return xs_error(16,op,0);}let out=xs_reply(32);if boot_u16(p+4)==7 && fo_eq(fo_slice(p+8,7),"MIT-SHM") {store8(out+8,1);store8(out+9,128);store8(out+10,64);store8(out+11,128);}return xs_queue(out,32);}
    if op==128 {return xs_shm_request(p,n);}
    if op==99 {let out=xs_reply(40);store8(out+1,1);store8(out+32,7);boot_copy(out+33,"MIT-SHM",7);return xs_queue(out,40);}
    if op==43 {let out=xs_reply(32);boot_w32(out+8,xs_focus);return xs_queue(out,32);}
    if op==101 {if n!=8 {return xs_error(16,op,0);}let count=load8(p+5);let out=xs_reply(32+count*8);store8(out+1,2);let i=0;while i<count {let code=load8(p+4)+i-8;boot_w32(out+32+i*8,xs_keysym(code,0));boot_w32(out+36+i*8,xs_keysym(code,1));i=i+1;}return xs_queue(out,32+count*8);}
    if op==119 {let out=xs_reply(48);store8(out+1,2);store8(out+32,50);store8(out+33,62);store8(out+36,37);store8(out+37,105);store8(out+38,64);store8(out+39,108);return xs_queue(out,48);}
    if op==1 || op==53 {let minimum=32;if op==53 {minimum=16;}if n<minimum || !xs_resource(boot_u32(p+8)) {return xs_error(3,op,boot_u32(p+8));}let w=boot_u16(p+16);let h=boot_u16(p+18);let kind=1;let x=boot_u16(p+12);let y=boot_u16(p+14);
        if op==53 {w=boot_u16(p+12);h=boot_u16(p+14);kind=2;x=0;y=0;}if !w || !h || w>1024 || h>768 || load8(p+1)!=8 && !(op==1 && load8(p+1)==0) && !(op==53 && load8(p+1)==1) {return xs_error(2,op,id);}
        if op==1 {let mask=boot_u32(p+28);let values=0;let bit=0;while bit<15 {if mask&(1<<bit) {values=values+1;}bit=bit+1;}if mask&~32767 || n!=32+values*4 {return xs_error(16,op,id);}}
        r=xs_new(id,kind);if !r {return xs_error(14,op,id);}store64(r+16,w);store64(r+24,h);store64(r+32,x);store64(r+40,y);let buffer=platform_allocate(w*h);if buffer<0 {bm_zero(r,96);return xs_error(11,op,id);}store64(r+48,buffer);store64(r+64,2);let depth=load8(p+1);if !depth {depth=8;}store64(r+80,depth);if op==1 {xs_values(r,p+32,boot_u32(p+28));}return 0;
    }
    if op==2 {if !r || load64(r+8)!=1 {return xs_error(3,op,id);}if n<12 {return xs_error(16,op,id);}let mask=boot_u32(p+8);let count=0;let i=0;while i<15 {if mask&(1<<i) {count=count+1;}i=i+1;}if mask&~32767 || n!=12+count*4 {return xs_error(16,op,id);}xs_values(r,p+12,mask);return 0;}
    if op==8 {if !r || load64(r+8)!=1 {return xs_error(3,op,id);}store64(r+72,1);xs_focus=id;xs_present(r);if load64(r+56)&32768 {let out=fo_take(32);bm_zero(out,32);store8(out,12);boot_w16(out+2,xs_sequence);boot_w32(out+4,id);boot_w16(out+12,load64(r+16));boot_w16(out+14,load64(r+24));xs_queue(out,32);}return 0;}
    if op==14 {if !r || load64(r+8)>2 {return xs_error(9,op,id);}let out=xs_reply(32);store8(out+1,load64(r+80));boot_w32(out+8,1);boot_w16(out+12,load64(r+32));boot_w16(out+14,load64(r+40));boot_w16(out+16,load64(r+16));boot_w16(out+18,load64(r+24));return xs_queue(out,32);}
    if op==55 || op==56 {if n<12 {return xs_error(16,op,id);}let offset=12;if op==55 {offset=16;if n<16 || !xs_resource(boot_u32(p+8)) {return xs_error(9,op,boot_u32(p+8));}}let mask=boot_u32(p+offset-4);let count=0;let i=0;while i<23 {if mask&(1<<i) {count=count+1;}i=i+1;}if mask&~0x7fffff || n!=offset+count*4 {return xs_error(16,op,id);}
        if op==55 {r=xs_new(id,3);}if !r || load64(r+8)!=3 {return xs_error(13,op,id);}i=0;count=0;while i<23 {if mask&(1<<i) {if i==2 {store64(r+16,boot_u32(p+offset+count*4));}count=count+1;}i=i+1;}return 0;
    }
    if op==78 {if n!=16 {return xs_error(16,op,id);}r=xs_new(id,4);if !r {return xs_error(14,op,id);}let buffer=platform_allocate(2048);if buffer<0 {bm_zero(r,96);return xs_error(11,op,id);}store64(r+48,buffer);return 0;}
    if op==89 {if !r || load64(r+8)!=4 {return xs_error(12,op,id);}if n<8 || (n-8)%12 {return xs_error(16,op,id);}let i=8;while i<n {let index=boot_u32(p+i);if index>255 {return xs_error(2,op,index);}let palette=load64(r+48);let value=load64(palette+index*8);let flags=load8(p+i+10);if flags&1 {value=(value&0xffff)|(load8(p+i+5)<<16);}if flags&2 {value=(value&0xff00ff)|(load8(p+i+7)<<8);}if flags&4 {value=(value&0xffff00)|load8(p+i+9);}store64(palette+index*8,value);i=i+12;}i=0;while i<64 {let window=xs_resources+i*96;if load64(window+64)==id {xs_present(window);}i=i+1;}return 0;}
    if op==72 {if n<24 || !r || load64(r+8)>2 {return xs_error(9,op,id);}let gc=xs_resource(boot_u32(p+8));if !gc || load64(gc+8)!=3 {return xs_error(13,op,boot_u32(p+8));}let w=boot_u16(p+12);let h=boot_u16(p+14);let x=boot_u16(p+16);let y=boot_u16(p+18);let stride=(w+3)&-4;
        if load8(p+1)!=2 || load8(p+21)!=8 || load8(p+20) || !w || !h || stride*h!=n-24 {return xs_error(8,op,id);}let row=0;while row<h {let column=0;while column<w {if x+column<load64(r+16) && y+row<load64(r+24) {store8(load64(r+48)+(y+row)*load64(r+16)+x+column,load8(p+24+row*stride+column));}column=column+1;}row=row+1;}xs_present(r);return 0;
    }
    if op==70 {if n<12 || (n-12)%8 || !r || load64(r+8)>2 {return xs_error(9,op,id);}let gc=xs_resource(boot_u32(p+8));if !gc || load64(gc+8)!=3 {return xs_error(13,op,boot_u32(p+8));}let i=12;while i<n {let x=boot_u16(p+i);let y=boot_u16(p+i+2);let w=boot_u16(p+i+4);let h=boot_u16(p+i+6);let yy=y;while yy<y+h && yy<load64(r+24) {let xx=x;while xx<x+w && xx<load64(r+16) {store8(load64(r+48)+yy*load64(r+16)+xx,load64(gc+16));xx=xx+1;}yy=yy+1;}i=i+8;}xs_present(r);return 0;}
    if op==93 {if n!=32 || !xs_resource(boot_u32(p+8)) || !xs_resource(boot_u32(p+12)) {return xs_error(4,op,id);}if !xs_new(id,5) {return xs_error(14,op,id);}return 0;}
    if op==4 || op==54 || op==60 || op==79 || op==95 {if !r || id<=2 {return xs_error(2,op,id);}if load64(r+48) {let size=load64(r+16)*load64(r+24);if load64(r+8)==4 {size=2048;}platform_free(load64(r+48),size);}if xs_focus==id {xs_focus=0;}bm_zero(r,96);return 0;}
    if op==127 {return 0;}return xs_error(1,op,id);
}
fn xs_feed(va,n) {
    if n<0 || n>262144-xs_in_size {return -105;}if !xp_range(va,n,0) && n {return -14;}let i=0;while i<n {store8(xs_in+xs_in_size+i,load8(xp_pointer(va+i,0)));i=i+1;}xs_in_size=xs_in_size+n;let consumed=0;
    if !xs_setup {if xs_in_size<12 {return n;}if load8(xs_in)!=108 || boot_u16(xs_in+2)!=11 {return -71;}let size=12+((boot_u16(xs_in+6)+3)&-4)+((boot_u16(xs_in+8)+3)&-4);if xs_in_size<size {return n;}xs_setup=1;xs_greeting();consumed=size;}
    while xs_in_size-consumed>=4 {let size=boot_u16(xs_in+consumed+2)*4;if !size {return -71;}if xs_in_size-consumed<size {boot_copy(xs_in,xs_in+consumed,xs_in_size-consumed);xs_in_size=xs_in_size-consumed;return n;}xs_sequence=xs_sequence+1;xs_request(xs_in+consumed,size);consumed=consumed+size;}
    boot_copy(xs_in,xs_in+consumed,xs_in_size-consumed);xs_in_size=xs_in_size-consumed;return n;
}
