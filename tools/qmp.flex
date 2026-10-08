import "qemu.flex";
// Real QEMU input and framebuffer inspection for native desktop tests.
global qt_process=0;
global qt_companion=0;
global qt_fd=-1;
global qt_mouse_x=512;
global qt_mouse_y=384;
global qt_ppm=0;
global qt_pixels=0;
fn qt_assert(ok,message) {if !ok {if qt_process {h_print(2,h_out(qt_process));h_print(2,h_err(qt_process));h_stop(qt_process);}if qt_companion {h_stop(qt_companion);}h_die(message);}return 0;}
fn qt_pump(ms) {h_pump(qt_process,ms);if qt_companion {h_pump(qt_companion,0);}return 0;}
fn qt_pause(ms) {let end=net_now()+ms;while net_now()<end {qt_pump(5);}return 0;}
fn qt_until(text) {let end=net_now()+10000;while !h_has(h_out(qt_process),text) {qt_pump(5);qt_assert(h_status(qt_process)==-999 && net_now()<end,h_cat("missing guest output: ",text));}return 0;}
fn qt_read() {
    let b=h_buffer();let scratch=h_take(8192);let end=net_now()+5000;
    while 1 {let n=syscall(0,qt_fd,scratch,8192,0,0,0);if n>0 {h_append(b,scratch,n);if load8(scratch+n-1)==10 {return h_data(b);}}
        else {qt_assert(n==-11 || n==-4,"QMP socket closed");qt_pump(5);}qt_assert(net_now()<end,"QMP timed out");
    }return 0;
}
fn qt_execute(name,arguments) {
    let command=h_cat3("{\"execute\":\"",name,"\"");if arguments {command=h_cat3(command,",\"arguments\":",arguments);}command=h_cat(command,"}\n");
    qt_assert(h_write(qt_fd,command,h_len(command))==h_len(command),"QMP request failed");let response=qt_read();qt_assert(h_has(response,"\"return\""),h_cat("QMP error: ",response));return response;
}
fn qt_open(qemu,image,firmware,temp) {
    return qt_open_display(qemu,image,firmware,temp,"none");
}
fn qt_open_display(qemu,image,firmware,temp,display) {
    let socket=h_join(temp,"desktop.sock");let args=bq_args_display(qemu,image,firmware,display);h_add(args,"-vga");h_add(args,"std");h_add(args,"-qmp");h_add(args,h_cat3("unix:",socket,",server=on,wait=off"));
    qt_process=h_spawn(args,0,0);qt_until("FlexOS desktop ready");qt_until("flexos:/ > ");
    let address=h_zero(h_take(110),110);store8(address,1);h_copy(address+2,socket,h_len(socket));qt_fd=syscall(41,1,1|0x80000,0,0,0,0);
    qt_assert(qt_fd>=0 && syscall(42,qt_fd,address,h_len(socket)+3,0,0,0)==0,"QMP connect failed");syscall(72,qt_fd,4,2048,0,0,0);qt_assert(h_has(qt_read(),"QMP"),"QMP greeting missing");qt_execute("qmp_capabilities",0);qt_pause(300);return 0;
}
fn qt_events(events) {return qt_execute("input-send-event",h_cat3("{\"events\":[",events,"]}"));}
fn qt_key_state(code,down) {let value="false";if down {value="true";}return qt_events(h_cat3("{\"type\":\"key\",\"data\":{\"down\":",value,h_cat3(",\"key\":{\"type\":\"qcode\",\"data\":\"",code,"\"}}}")));}
fn qt_key(code) {qt_key_state(code,1);qt_key_state(code,0);return 0;}
fn qt_button(down) {let value="false";if down {value="true";}qt_events(h_cat3("{\"type\":\"btn\",\"data\":{\"button\":\"left\",\"down\":",value,"}}"));qt_pause(40);return 0;}
fn gq_clamp(n,minimum,maximum) {if n<minimum {return minimum;}if n>maximum {return maximum;}return n;}
fn qt_move(x,y) {
    while qt_mouse_x!=x || qt_mouse_y!=y {let dx=gq_clamp(x-qt_mouse_x,-96,96);let dy=gq_clamp(y-qt_mouse_y,-96,96);
        let events=h_cat3("{\"type\":\"rel\",\"data\":{\"axis\":\"x\",\"value\":",h_int(dx),"}},");
        events=h_cat(events,h_cat3("{\"type\":\"rel\",\"data\":{\"axis\":\"y\",\"value\":",h_int(dy),"}}"));qt_events(events);qt_mouse_x=qt_mouse_x+dx;qt_mouse_y=qt_mouse_y+dy;qt_pause(15);
    }qt_pause(40);return 0;
}
fn qt_click(x,y) {qt_move(x,y);qt_button(1);qt_button(0);qt_pause(160);return 0;}
fn qt_shortcut(modifier,key) {qt_key_state(modifier,1);qt_key(key);qt_key_state(modifier,0);qt_pause(120);return 0;}
fn qt_type(text) {
    let i=0;while load8(text+i) {let c=load8(text+i);let shift=0;let code=0;if c>=65 && c<=90 {shift=1;c=c+32;}
        if c>=97 && c<=122 || c>=48 && c<=57 {code=h_take(2);store8(code,c);store8(code+1,0);}
        else if c==32 {code="spc";}else if c==10 {code="ret";}else if c==46 {code="dot";}else if c==45 {code="minus";}else if c==47 {code="slash";}
        else if c==39 {code="apostrophe";}else if c==34 {code="apostrophe";shift=1;}else if c==33 {code="1";shift=1;}
        else if c==58 {code="semicolon";shift=1;}else if c==95 {code="minus";shift=1;}else if c==61 {code="equal";}
        qt_assert(code,"unmapped test character");if shift {qt_key_state("shift",1);}qt_key(code);if shift {qt_key_state("shift",0);}i=i+1;
        // Give the guest time to drain the emulated PS/2 queue between
        // characters, including when TCG competes with another test guest.
        qt_pause(20);
    }qt_pause(150);return 0;
}
fn qt_serial(command) {let b=load64(qt_process+16);store64(b+8,0);if load64(b) {store8(load64(b),0);}h_trigger(qt_process,h_cat(command,"\n"));qt_until("flexos:/ > ");return h_replace(h_out(qt_process),"\r","");}
fn qt_capture(path) {
    qt_execute("screendump",h_cat3("{\"filename\":\"",h_absolute(path),"\"}"));qt_ppm=h_read(path);
    qt_assert(h_starts(qt_ppm,"P6\n1024 768\n255\n"),"unexpected framebuffer image");qt_pixels=qt_ppm+16;qt_assert(h_file_size==16+1024*768*3,"framebuffer size mismatch");return 0;
}
fn qt_pixel(x,y) {let p=qt_pixels+(y*1024+x)*3;return (load8(p)<<16)|(load8(p+1)<<8)|load8(p+2);}
fn qt_png(path) {qt_execute("screendump",h_cat3("{\"filename\":\"",h_absolute(path),"\",\"format\":\"png\"}"));return 0;}
fn qt_stop() {if qt_fd>=0 {h_close(qt_fd);qt_fd=-1;}if qt_process {h_stop(qt_process);qt_process=0;}return 0;}
