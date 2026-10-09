import "pc-desktop.flex";
// Linux fbdev and evdev structures. Programs use ordinary Linux file APIs;
// only these drivers know about the VGA and PS/2 hardware.
global ld_events=0;
global ld_write=0;
global ld_state=0;
global ld_extended=0;
global ld_pause=0;
global ld_grab=-1;
global ld_fb_next=0x30000000;
fn ld_init() {platform_graphics_init();platform_input_init();ld_events=platform_allocate(6144);ld_state=platform_allocate(256);return 0;}
fn ld_event(type,code,value) {let p=ld_events+(ld_write%256)*24;let ms=hp_now()-1;store64(p,ms/1000);store64(p+8,(ms%1000)*1000);boot_w16(p+16,type);boot_w16(p+18,code);boot_w32(p+20,value);ld_write=ld_write+1;return 0;}
fn ld_code(code,ext) {if !ext {return code;}if code==72 {return 103;}if code==80 {return 108;}if code==75 {return 105;}if code==77 {return 106;}if code==29 {return 97;}if code==56 {return 100;}if code==28 {return 96;}if code==53 {return 98;}if code==71 {return 102;}if code==79 {return 107;}if code==73 {return 104;}if code==81 {return 109;}if code==82 {return 110;}if code==83 {return 111;}if code==91 {return 125;}if code==92 {return 126;}return 0;}
fn ld_poll_input() {
    while port_in8(0x64)&1 {let status=port_in8(0x64);let value=port_in8(0x60);
        if !(status&32) {if ld_pause {ld_pause=ld_pause-1;}else if value==0xe1 {ld_pause=5;}else if value==0xe0 {ld_extended=1;}
            else {let code=ld_code(value&127,ld_extended);ld_extended=0;if code {let down=!(value&128);let old=load8(ld_state+code);store8(ld_state+code,down);
                if down || old {let state=down;if down && old {state=2;}ld_event(1,code,state);ld_event(0,0,0);}
            }}
        }
    }return 0;
}
fn ld_read(file,va,n) {
    if n<24 {return -22;}ld_poll_input();let pos=load64(file+8);if ld_grab>=0 && lx_fds+(ld_grab-3)*32!=file {return -11;}
    if pos<ld_write-256 {pos=ld_write-256;let event=fo_take(24);bm_zero(event,24);boot_w16(event+18,3);if !xp_range(va,24,1) {return -14;}xp_to_user(va,event,24);store64(file+8,pos);return 24;}
    if pos==ld_write {if load64(file+24)&2048 {return -11;}while pos==ld_write {ld_poll_input();}}
    let count=(ld_write-pos)*24;if count>n {count=n/24*24;}if !xp_range(va,count,1) {return -14;}let i=0;while i<count {xp_to_user(va+i,ld_events+(pos%256)*24,24);pos=pos+1;i=i+24;}store64(file+8,pos);return count;
}
fn ld_ioctl(fd,request,va) {
    let file=lx_fd(fd);if !file {return -9;}let kind=load64(load64(file)+8);
    if kind==3 {
        if request==0x4600 {if !xp_range(va,160,1) {return -14;}let p=fo_take(160);bm_zero(p,160);boot_w32(p,pc_width);boot_w32(p+4,pc_height);boot_w32(p+8,pc_width);boot_w32(p+12,pc_height);boot_w32(p+24,32);
            boot_w32(p+32,16);boot_w32(p+36,8);boot_w32(p+44,8);boot_w32(p+48,8);boot_w32(p+60,8);boot_w32(p+68,24);boot_w32(p+72,8);xp_to_user(va,p,160);return 0;
        }
        if request==0x4602 {if !xp_range(va,80,1) {return -14;}let p=fo_take(80);bm_zero(p,80);boot_copy(p,"FlexOS VGA",11);store64(p+16,pc_fb);boot_w32(p+24,pc_width*pc_height*4);boot_w32(p+36,2);boot_w32(p+48,pc_width*4);xp_to_user(va,p,80);return 0;}
        return -25;
    }
    if kind==4 {
        if request==0x40044590 {if va {if ld_grab>=0 && ld_grab!=fd {return -16;}ld_grab=fd;}else if ld_grab==fd {ld_grab=-1;}return 0;}
        let number=request&255;let size=(request>>16)&0x3fff;if (request&0xff00)==0x4500 && (number==0x20 || number==0x21) && size>0 && size<=256 {
            if !xp_range(va,size,1) {return -14;}let p=fo_take(size);bm_zero(p,size);if number==0x20 {store8(p,3);}else {let i=1;while i<=126 && i/8<size {store8(p+i/8,load8(p+i/8)|(1<<(i%8)));i=i+1;}}xp_to_user(va,p,size);return size;
        }return -25;
    }return -25;
}
fn ld_fb_map(n,prot,flags,offset) {
    let size=pc_width*pc_height*4;if n<=0 || n>size || offset<0 || (offset&4095) || offset>size-n || flags!=1 || prot<1 || prot>3 {return -22;}
    let length=(n+4095)&-4096;let start=ld_fb_next;if length>0x3e000000-start {return -12;}let p=0;
    while p<length {let slot=xp_pte(start+p,1);if !slot {let undo=0;while undo<p {xp_unmap(start+undo);undo=undo+4096;}return -12;}store64(slot,(pc_fb+offset+p)|xp_flags(prot)|24);p=p+4096;}
    ld_fb_next=start+length;return start;
}
