// Flexscript game services. The original Doom engine is a separate native ELF.
global doom_entry=0;
global doom_frames=0;
global doom_queue=0;
global doom_read=0;
global doom_write=0;
global doom_release_delay=0;
global doom_keys=0;
global doom_scans=0;
global doom_counts=0;
global doom_ext=0;
global doom_ctype=0;
global doom_mouse_count=0;
global doom_mouse_flags=0;
global doom_mouse_x=0;
global doom_mouse_y=0;
global doom_mouse_buttons=0;
global doom_mouse_dirty=0;
global doom_mouse_event=0;
global doom_quit=0;
global doom_serial=0;
global doom_serial_size=0;
fn doom_enqueue(key,down) {
    if !key {return 0;}if load8(doom_keys+key)==down {return 0;}store8(doom_keys+key,down);
    fo_assert(doom_write-doom_read<256,"game input queue overflow");let record=doom_queue+(doom_write%256)*16;
    store64(record,512|(down<<8)|key);store64(record+8,hp_now());doom_write=doom_write+1;return 0;
}
fn doom_key(code,ext) {
    if ext {if code==72 {return 0xad;}if code==80 {return 0xaf;}if code==75 {return 0xac;}if code==77 {return 0xae;}}
    if code==1 {return 27;}if code==28 {return 13;}if code==14 {return 127;}if code==15 {return 9;}
    if code==29 {return 0xa3;}if code==56 {return 0xb8;}if code==42 || code==54 {return 0xb6;}if code==57 {return 0xa2;}
    if code==17 {return 0xad;}if code==31 {return 0xaf;}if code==30 {return 0xa0;}if code==32 {return 0xa1;}
    if code>=59 && code<=68 {return code+128;}return pc_ascii(code);
}
fn doom_keyboard(code,ext,down) {
    let slot=code+ext*128;if load8(doom_scans+slot)==down {return 0;}store8(doom_scans+slot,down);
    let key=doom_key(code,ext);if !key {return 0;}let count=load8(doom_counts+key);if down {count=count+1;}else {count=count-1;}
    store8(doom_counts+key,count);return doom_enqueue(key,count>0);
}
fn doom_poll() {
    while port_in8(0x64)&1 {let status=port_in8(0x64);let value=port_in8(0x60);
        if status&32 {
            if !doom_mouse_count {if value&8 {doom_mouse_flags=value;doom_mouse_count=1;}}
            else if doom_mouse_count==1 {doom_mouse_x=value;if doom_mouse_flags&16 {doom_mouse_x=doom_mouse_x-256;}doom_mouse_count=2;}
            else {doom_mouse_count=0;let dy=value;if doom_mouse_flags&32 {dy=dy-256;}
                if !(doom_mouse_flags&192) {store64(doom_mouse_event+8,load64(doom_mouse_event+8)+doom_mouse_x*4);store64(doom_mouse_event+16,load64(doom_mouse_event+16)+dy*4);}
                doom_mouse_buttons=(doom_mouse_flags&1)|((doom_mouse_flags&4)>>1)|((doom_mouse_flags&2)<<1);doom_mouse_dirty=1;
            }
        }else if value==0xe0 {doom_ext=1;}
        else {let ext=doom_ext;doom_ext=0;let code=value&127;let down=!(value&128);if code==88 && down {doom_quit=1;}else {doom_keyboard(code,ext,down);}}
    }return 0;
}
fn doom_draw(source,width,height) {
    fo_assert(width==320 && height==200,"unexpected game framebuffer");let y=0;
    // 3x pixel scaling to 960x600. BGRA is shared with native standard VGA.
    while y<200 {let x=0;let row=g_back+((y*3+84)*1024+32)*4;
        while x<320 {let pair=load64(source+(y*320+x)*4);let left=pair&0xffffffff;let right=(pair>>32)&0xffffffff;let p=row+x*12;
            store64(p,left|(left<<32));store64(p+8,left|(right<<32));store64(p+16,right|(right<<32));x=x+2;
        }boot_copy(row+4096,row,3840);boot_copy(row+8192,row,3840);doom_poll();y=y+1;
    }platform_display_present(g_back,32,84,960,600);doom_frames=doom_frames+1;
    return 0;
}
fn doom_host(op,a,b,c,d,e) {
    if op==1 {return doom_draw(a,b,c);}
    if op==2 {let p=platform_allocate(a);if p<0 {return 0;}return p;}
    if op==3 {return platform_free(a,0);}
    if op==4 {return load64(a-16);}
    if op==5 {return platform_output(1,a);}
    if op==6 {platform_output(1,"Doom exited, status=");platform_output(1,fo_int(a));platform_output(1,"\n");cpu_halt();}
    if op==7 {return doom_ctype;}
    if op==8 {doom_poll();return hp_now();}
    if op==9 {let until=hp_now()+a;while hp_now()<until {doom_poll();}return 0;}
    if op==10 {doom_poll();if doom_read==doom_write {return 0;}let record=doom_queue+(doom_read%256)*16;let v=load64(record);
        if !(v&256) {let delay=hp_now()-load64(record+8);if delay>doom_release_delay {doom_release_delay=delay;}}
        doom_read=doom_read+1;return v;
    }
    if op==11 {doom_poll();if !doom_mouse_dirty {return 0;}doom_mouse_dirty=0;store64(doom_mouse_event,doom_mouse_buttons);return doom_mouse_event;}
    fo_die("unknown game service");return 0;
}
fn doom_value(which) {return ffi_call(doom_entry,2,0,which,0,0,0);}
fn doom_stats() {
    let mark=fo_mark();platform_output(1,"DOOM STATS frames=");platform_output(1,fo_int(doom_frames));
    platform_output(1," tic=");platform_output(1,fo_int(doom_value(0)));platform_output(1," state=");platform_output(1,fo_int(doom_value(1)));
    platform_output(1," x=");platform_output(1,fo_int(doom_value(2)));platform_output(1," y=");platform_output(1,fo_int(doom_value(3)));
    platform_output(1," ammo=");platform_output(1,fo_int(doom_value(4)));platform_output(1," release_ms=");platform_output(1,fo_int(doom_release_delay));
    platform_output(1," input_forward=");platform_output(1,fo_int(load8(doom_keys+0xad)-load8(doom_keys+0xaf)));
    platform_output(1," forward=");platform_output(1,fo_int(doom_value(6)));platform_output(1," side=");platform_output(1,fo_int(doom_value(7)));
    platform_output(1," momx=");platform_output(1,fo_int(doom_value(8)));platform_output(1," momy=");platform_output(1,fo_int(doom_value(9)));
    platform_output(1," angle=");platform_output(1,fo_int(doom_value(5)));platform_output(1,"\n");fo_reset(mark);return 0;
}
fn doom_services_init() {
    doom_queue=platform_allocate(4096);doom_keys=platform_allocate(256);doom_scans=platform_allocate(256);doom_counts=platform_allocate(256);doom_serial=platform_allocate(128);doom_mouse_event=platform_allocate(24);
    let table=platform_allocate(768);doom_ctype=table+256;let c=0;while c<256 {let bits=0;
        // glibc ctype table flags are network-order 16-bit words.
        if c>=65 && c<=90 {bits=bits|0x0100|0x0400|8;}if c>=97 && c<=122 {bits=bits|0x0200|0x0400|8;}
        if c>=48 && c<=57 {bits=bits|0x0800|8;}if c==32 || c>=9 && c<=13 {bits=bits|0x2000;}
        if c>=48 && c<=57 || c>=65 && c<=70 || c>=97 && c<=102 {bits=bits|0x1000;}
        if c>=32 && c<=126 {bits=bits|0x4000;}if c>=33 && c<=126 {bits=bits|0x8000;}
        store8(doom_ctype+c*2,bits);store8(doom_ctype+c*2+1,bits>>8);c=c+1;
    }return 0;
}
fn doom_serial_poll() {
    while port_in8(0x3fd)&1 {let c=port_in8(0x3f8);if c==10 || c==13 {if doom_serial_size {store8(doom_serial+doom_serial_size,0);
        if fo_eq(doom_serial,"stats") {doom_stats();}else if fo_eq(doom_serial,"quit") {doom_quit=1;}
        doom_serial_size=0;
    }}else if doom_serial_size<127 {store8(doom_serial+doom_serial_size,c);doom_serial_size=doom_serial_size+1;}}
    return 0;
}
