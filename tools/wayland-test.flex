import "qmp.flex";
// Test-only Wayland client. It connects exclusively to our temporary headless
// compositor and uses wlr-virtual-pointer to exercise the host UI input path.
// Protocol: https://github.com/swaywm/wlr-protocols/blob/master/unstable/wlr-virtual-pointer-unstable-v1.xml
global wt_sway=0;
global wt_fd=-1;
global wt_temp=0;
global wt_count=0;
fn wt_stop() {if qt_process {h_save("build/desktop-tests/wayland-qemu.log",h_err(qt_process));}if wt_sway {h_save("build/desktop-tests/wayland-compositor.log",h_err(wt_sway));}qt_stop();qt_companion=0;if wt_fd>=0 {h_close(wt_fd);wt_fd=-1;}if wt_sway {h_stop(wt_sway);wt_sway=0;}return 0;}
fn wt_excerpt(text) {let n=h_len(text);if n>2000 {return text+n-2000;}return text;}
fn wt_assert(ok,message) {if !ok {if wt_sway {h_print(2,wt_excerpt(h_err(wt_sway)));}if qt_process {h_print(2,h_out(qt_process));h_print(2,wt_excerpt(h_err(qt_process)));}wt_stop();h_die(message);}return 0;}
fn wt_check(ok,message) {wt_assert(ok,message);wt_count=wt_count+1;return 0;}
fn wt_u32(p,value) {let i=0;while i<4 {store8(p+i,value>>(i*8));i=i+1;}return 0;}
fn wt_read32(p) {return load8(p)|(load8(p+1)<<8)|(load8(p+2)<<16)|(load8(p+3)<<24);}
fn wt_message(object,opcode,size) {let p=h_zero(h_take(size),size);wt_u32(p,object);wt_u32(p+4,(size<<16)|opcode);return p;}
fn wt_send(p) {let size=wt_read32(p+4)>>16;wt_assert(h_write(wt_fd,p,size)==size,"headless Wayland write failed");return 0;}
fn wt_bind(registry_name,name,id) {let length=h_len(name)+1;let padded=(length+3)&-4;let p=wt_message(2,0,24+padded);
    wt_u32(p+8,registry_name);wt_u32(p+12,length);h_copy(p+16,name,length);wt_u32(p+16+padded,1);wt_u32(p+20+padded,id);wt_send(p);return 0;
}
fn wt_keyboard(manager,seat) {
    wt_bind(seat,"wl_seat",5);wt_bind(manager,"zwp_virtual_keyboard_manager_v1",6);let p=wt_message(6,0,16);wt_u32(p+8,5);wt_u32(p+12,7);wt_send(p);
    // A real keymap gives the private seat keyboard focus, which SDL requires
    // before it enables relative mouse capture. No host keyboard is attached.
    let library=ffi_open("libxkbcommon.so.0");wt_assert(library,"libxkbcommon required for headless input tests");
    let context=ffi_call(ffi_symbol(library,"xkb_context_new"),0,0,0,0,0,0);wt_assert(context,"test keyboard context failed");
    let keymap=ffi_call(ffi_symbol(library,"xkb_keymap_new_from_names"),context,0,0,0,0,0);wt_assert(keymap,"test keyboard keymap failed");
    let text=ffi_call(ffi_symbol(library,"xkb_keymap_get_as_string"),keymap,1,0,0,0,0);wt_assert(text,"test keyboard keymap export failed");
    let size=h_len(text)+1;let fd=syscall(319,"flexos-headless-keymap",1,0,0,0,0);wt_assert(fd>=0 && h_write(fd,text,size)==size,"test keymap memfd failed");
    p=wt_message(7,0,16);wt_u32(p+8,1);wt_u32(p+12,size);let iov=h_take(16);store64(iov,p);store64(iov+8,16);
    let control=h_zero(h_take(24),24);store64(control,20);wt_u32(control+8,1);wt_u32(control+12,1);wt_u32(control+16,fd);
    let msg=h_zero(h_take(56),56);store64(msg+16,iov);store64(msg+24,1);store64(msg+32,control);store64(msg+40,24);
    wt_assert(syscall(46,wt_fd,msg,0,0,0,0)==16,"test keyboard keymap transfer failed");h_close(fd);return 0;
}
fn wt_prepare(sway,temp) {
    wt_temp=temp;h_save(h_join(temp,"sway.conf"),"output * mode 1024x768\ndefault_border none\nseat seat0 attach *\nseat seat0 fallback true\nxwayland disable\n");
    h_setenv("XDG_RUNTIME_DIR",temp);h_setenv("WAYLAND_DISPLAY",0);h_setenv("DISPLAY",0);h_setenv("SWAYSOCK",0);h_setenv("DBUS_SESSION_BUS_ADDRESS",0);
    h_setenv("WLR_BACKENDS","headless");h_setenv("WLR_RENDERER","pixman");h_setenv("WLR_HEADLESS_OUTPUTS","1");h_setenv("SDL_VIDEODRIVER","wayland");h_setenv("GDK_BACKEND","wayland");
    h_setenv("SDL_RENDER_DRIVER","software");h_setenv("LIBGL_ALWAYS_SOFTWARE","1");
    wt_sway=h_spawn(h_args(sway,"--debug","--config",h_join(temp,"sway.conf"),0,0),0,0);qt_companion=wt_sway;
    let socket=0;let end=net_now()+10000;while !socket {let i=0;while i<32 && !socket {let name=h_cat("wayland-",h_int(i));let path=h_join(temp,name);if h_exists(path) {socket=path;h_setenv("WAYLAND_DISPLAY",name);}i=i+1;}
        if !socket {h_pump(wt_sway,10);wt_assert(h_status(wt_sway)==-999 && net_now()<end,"headless Wayland compositor did not start");}
    }
    let address=h_zero(h_take(110),110);store8(address,1);h_copy(address+2,socket,h_len(socket));wt_fd=syscall(41,1,1|0x80000,0,0,0,0);
    wt_assert(wt_fd>=0 && syscall(42,wt_fd,address,h_len(socket)+3,0,0,0)==0,"headless Wayland connect failed");syscall(72,wt_fd,4,2048,0,0,0);
    let request=wt_message(1,1,12);wt_u32(request+8,2);wt_send(request); // wl_display.get_registry
    let bytes=h_buffer();let scratch=h_take(8192);let at=0;let manager=0;let keyboard=0;let seat=0;end=net_now()+5000;
    while !manager || !keyboard || !seat {let n=syscall(0,wt_fd,scratch,8192,0,0,0);if n>0 {h_append(bytes,scratch,n);}else {wt_assert(n==-11 || n==-4,"headless Wayland registry closed");h_pump(wt_sway,5);}
        let more=1;while more && at+8<=h_size(bytes) {let event=h_data(bytes)+at;let header=wt_read32(event+4);let size=header>>16;wt_assert(size>=8,"invalid Wayland event");if at+size>h_size(bytes) {more=0;}
            else {if wt_read32(event)==2 && (header&65535)==0 && size>=24 {let name=h_slice(event+16,wt_read32(event+12)-1);if h_equal(name,"zwlr_virtual_pointer_manager_v1") {manager=wt_read32(event+8);}if h_equal(name,"zwp_virtual_keyboard_manager_v1") {keyboard=wt_read32(event+8);}if h_equal(name,"wl_seat") {seat=wt_read32(event+8);}}at=at+size;}
        }wt_assert(net_now()<end,"headless compositor lacks virtual pointer support");
    }
    wt_bind(manager,"zwlr_virtual_pointer_manager_v1",3);request=wt_message(3,0,16);wt_u32(request+8,0);wt_u32(request+12,4);wt_send(request);wt_keyboard(keyboard,seat);return 0;
}
fn wt_frame() {wt_send(wt_message(4,4,8));return 0;}
fn wt_absolute(x,y) {let p=wt_message(4,1,28);wt_u32(p+8,net_now());wt_u32(p+12,x);wt_u32(p+16,y);wt_u32(p+20,1024);wt_u32(p+24,768);wt_send(p);wt_frame();qt_pause(100);return 0;}
fn wt_relative(dx,dy) {let p=wt_message(4,0,20);wt_u32(p+8,net_now());wt_u32(p+12,dx*256);wt_u32(p+16,dy*256);wt_send(p);wt_frame();qt_pause(60);return 0;}
fn wt_button(down) {let p=wt_message(4,2,20);wt_u32(p+8,net_now());wt_u32(p+12,0x110);wt_u32(p+16,down);wt_send(p);wt_frame();qt_pause(80);return 0;}
fn wt_click() {wt_button(1);wt_button(0);qt_pause(120);return 0;}
fn wt_key(code,down) {let p=wt_message(7,1,20);wt_u32(p+8,net_now());wt_u32(p+12,code);wt_u32(p+16,down);wt_send(p);qt_pause(40);return 0;}
fn wt_modifiers(mask) {let p=wt_message(7,2,24);wt_u32(p+8,mask);wt_send(p);qt_pause(40);return 0;}
fn wt_release_capture() {wt_key(29,1);wt_key(56,1);wt_modifiers(12);wt_key(34,1);wt_key(34,0);wt_modifiers(0);wt_key(56,0);wt_key(29,0);qt_pause(120);return 0;}
fn wt_cursor() {qt_capture("build/desktop-tests/wayland-frame.ppm");let minx=1024;let miny=768;let y=0;while y<768 {let x=0;while x<1024 {if qt_pixel(x,y)==0xf3fbff {if x<minx {minx=x;}if y<miny {miny=y;}}x=x+1;}y=y+1;}
    wt_assert(minx<1024 && miny<768,"guest cursor missing from framebuffer");return (minx-1)|((miny-2)<<32);
}
fn wt_move(x,y) {let position=wt_cursor();let cx=position&0xffffffff;let cy=position>>32;let attempts=0;
    while cx!=x || cy!=y {wt_relative(gq_clamp(x-cx,-64,64),gq_clamp(y-cy,-64,64));position=wt_cursor();cx=position&0xffffffff;cy=position>>32;attempts=attempts+1;wt_assert(attempts<40,"host pointer failed to move guest cursor");}return 0;
}
