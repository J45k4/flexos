// QEMU standard VGA/Bochs VBE and polled i8042 PS/2 adapters.
// References: https://www.qemu.org/docs/master/specs/standard-vga.html
global pc_fb=0;
global pc_width=1024;
global pc_height=768;
global pc_mouse_x=512;
global pc_mouse_y=384;
global pc_mouse_packet=0;
global pc_mouse_count=0;
global pc_shift=0;
global pc_control=0;
global pc_alt=0;
global pc_caps=0;
global pc_extended=0;
fn pc_pci(slot,offset) {port_out32(0xcf8,0x80000000|(slot<<11)|offset);return port_in32(0xcfc);}
fn pc_vbe(index,value) {port_out16(0x1ce,index);port_out16(0x1cf,value);return 0;}
fn pc_vbe_read(index) {port_out16(0x1ce,index);return port_in16(0x1cf);}
fn platform_graphics_init() {
    let slot=0;while slot<32 && pc_pci(slot,0)!=0x11111234 {slot=slot+1;}
    fo_assert(slot<32,"QEMU standard VGA required (-vga std)");pc_fb=pc_pci(slot,16)&0xfffffff0;
    fo_assert(pc_fb>=0x2000000 && pc_fb+pc_width*pc_height*4<=0x100000000,"invalid VGA framebuffer BAR");
    let id=pc_vbe_read(0);fo_assert(id>=0xb0c0 && id<=0xb0c5,"Bochs VBE unavailable");
    pc_vbe(4,0);pc_vbe(1,pc_width);pc_vbe(2,pc_height);pc_vbe(3,32);pc_vbe(4,0x41);
    fo_assert(pc_vbe_read(1)==pc_width && pc_vbe_read(2)==pc_height && pc_vbe_read(3)==32 && pc_vbe_read(6)==pc_width,"VGA mode rejected");
    platform_output(1,"Desktop display: 1024x768x32 framebuffer\n");return 0;
}
fn platform_display_width() {return pc_width;}
fn platform_display_height() {return pc_height;}
fn platform_display_present(p,x,y,w,h) {
    let row=0;while row<h {let offset=((y+row)*pc_width+x)*4;let at=0;
        while at+1<w {store64(pc_fb+offset+at*4,load64(p+offset+at*4));at=at+2;}
        if at<w {let i=0;while i<4 {store8(pc_fb+offset+at*4+i,load8(p+offset+at*4+i));i=i+1;}}
        row=row+1;
    }return 0;
}
fn pc_ready() {let i=0;while port_in8(0x64)&2 {i=i+1;if i>1000000 {return 0;}}return 1;}
fn pc_command(value) {fo_assert(pc_ready(),"PS/2 controller busy");port_out8(0x64,value);return 0;}
fn pc_data(value) {fo_assert(pc_ready(),"PS/2 controller busy");port_out8(0x60,value);return 0;}
fn pc_read() {let i=0;while !(port_in8(0x64)&1) {i=i+1;if i>1000000 {return -1;}}return port_in8(0x60);}
fn pc_mouse_command(value) {pc_command(0xd4);pc_data(value);fo_assert(pc_read()==0xfa,"PS/2 mouse did not acknowledge");return 0;}
fn platform_input_init() {
    pc_command(0xad);pc_command(0xa7);let i=0;while (port_in8(0x64)&1) && i<64 {port_in8(0x60);i=i+1;}
    pc_command(0x20);let config=pc_read();fo_assert(config>=0,"PS/2 configuration unavailable");
    pc_command(0x60);pc_data((config|64)&0xcc); // translation on, IRQs off, both clocks on
    pc_command(0xae);pc_command(0xa8);pc_data(0xf6);fo_assert(pc_read()==0xfa,"PS/2 keyboard reset failed");
    pc_data(0xf4);fo_assert(pc_read()==0xfa,"PS/2 keyboard enable failed");pc_mouse_command(0xf6);pc_mouse_command(0xf4);
    pc_mouse_packet=platform_allocate(8);platform_output(1,"Desktop input: PS/2 keyboard and mouse\n");return 0;
}
fn pc_ascii(code) {
    if code>=2 && code<=13 {if pc_shift {return load8("!@#$%^&*()_+"+code-2);}return load8("1234567890-="+code-2);}
    let c=0;if code>=16 && code<=25 {c=load8("qwertyuiop"+code-16);}
    else if code>=30 && code<=38 {c=load8("asdfghjkl"+code-30);}
    else if code>=44 && code<=50 {c=load8("zxcvbnm"+code-44);}
    if c {if (!pc_shift && pc_caps) || (pc_shift && !pc_caps) {c=c-32;}return c;}
    if code==26 {if pc_shift {return 123;}return 91;}if code==27 {if pc_shift {return 125;}return 93;}
    if code==39 {if pc_shift {return 58;}return 59;}if code==40 {if pc_shift {return 34;}return 39;}
    if code==41 {if pc_shift {return 126;}return 96;}if code==43 {if pc_shift {return 124;}return 92;}
    if code==51 {if pc_shift {return 60;}return 44;}if code==52 {if pc_shift {return 62;}return 46;}
    if code==53 {if pc_shift {return 63;}return 47;}if code==57 {return 32;}return 0;
}
// Event: type, key/character or pointer x, modifiers or pointer y, buttons.
// Key codes: ASCII; 256+ for navigation, 300+ for function keys.
fn platform_desktop_poll(event) {
    while port_in8(0x64)&1 {
        let status=port_in8(0x64);let value=port_in8(0x60);
        if status&32 {
            if !pc_mouse_count && !(value&8) {return 0;}store8(pc_mouse_packet+pc_mouse_count,value);pc_mouse_count=pc_mouse_count+1;
            if pc_mouse_count==3 {pc_mouse_count=0;let flags=load8(pc_mouse_packet);let dx=load8(pc_mouse_packet+1);let dy=load8(pc_mouse_packet+2);
                if flags&16 {dx=dx-256;}if flags&32 {dy=dy-256;}
                if !(flags&192) {pc_mouse_x=pc_mouse_x+dx;pc_mouse_y=pc_mouse_y-dy;}
                if pc_mouse_x<0 {pc_mouse_x=0;}if pc_mouse_x>=pc_width {pc_mouse_x=pc_width-1;}
                if pc_mouse_y<0 {pc_mouse_y=0;}if pc_mouse_y>=pc_height {pc_mouse_y=pc_height-1;}
                store64(event,2);store64(event+8,pc_mouse_x);store64(event+16,pc_mouse_y);store64(event+24,flags&7);return 1;
            }
        }else {
            if value==0xe0 {pc_extended=1;}else {let extended=pc_extended;pc_extended=0;let released=value&128;let code=value&127;
                if !extended && code==42 {if released {pc_shift=pc_shift&2;}else {pc_shift=pc_shift|1;}}
                else if !extended && code==54 {if released {pc_shift=pc_shift&1;}else {pc_shift=pc_shift|2;}}
                else if code==29 {pc_control=!released;}else if code==56 {pc_alt=!released;}
                else if !released {
                    let key=0;if code==58 {pc_caps=!pc_caps;}else if code==1 {key=27;}else if code==14 {key=8;}else if code==15 {key=9;}
                    else if code==28 {key=10;}else if extended {
                        if code==75 {key=256;}else if code==77 {key=257;}else if code==72 {key=258;}else if code==80 {key=259;}
                        else if code==71 {key=260;}else if code==79 {key=261;}else if code==83 {key=262;}else if code==91 {key=300;}
                    }else if code>=59 && code<=62 {key=300+code-59;}else {key=pc_ascii(code);}
                    if key {store64(event,1);store64(event+8,key);store64(event+16,(pc_shift!=0)|(pc_control<<1)|(pc_alt<<2));return 1;}
                }
            }
        }
    }return 0;
}
