import "../tools/doom-test.flex";
import "../tools/wayland-test.flex";
fn dw_forward(expected) {
    let until=net_now()+150;let s=dd_stats();
    while dd_field(s," forward=")!=expected && net_now()<until {qt_pause(5);s=dd_stats();}
    dd_check(dd_field(s," forward=")==expected,"SDL keyboard command did not respond within 150 ms");
    return s;
}
fn main(argc,argv) {
    h_environment(argc,argv);h_assert(argc==4 || argc==5,"Usage: test-doom-wayland QEMU IWAD SWAY [FIRMWARE]");
    let qemu=h_real(h_executable(load64(argv+8)));let wad=h_real(load64(argv+16));let sway=h_real(h_executable(load64(argv+24)));let firmware=0;if argc==5 {firmware=h_real(load64(argv+32));}
    h_mkdir("build/doom-tests");h_mkdir("build/desktop-tests");let temp=h_temp();wt_prepare(sway,temp);doom_stage(temp,wad);
    let args=doom_args(qemu,wad,firmware,"sdl,gl=off",temp);let socket=h_join(temp,"doom.sock");h_add(args,"-qmp");h_add(args,h_cat3("unix:",socket,",server=on,wait=off"));
    qt_process=h_spawn(args,0,0);qt_until("FlexOS Doom ready");let address=h_zero(h_take(110),110);store8(address,1);h_copy(address+2,socket,h_len(socket));
    qt_fd=syscall(41,1,1|0x80000,0,0,0,0);qt_assert(qt_fd>=0 && syscall(42,qt_fd,address,h_len(socket)+3,0,0,0)==0,"QMP connect failed");
    syscall(72,qt_fd,4,2048,0,0,0);qt_assert(h_has(qt_read(),"QMP"),"QMP greeting missing");qt_execute("qmp_capabilities",0);
    qt_pause(600);wt_absolute(512,384);wt_click();
    // Real evdev -> private Wayland -> SDL -> QEMU -> PS/2 -> FlexOS -> Doom.
    // Measure commands separately from Doom's original momentum/position.
    let codes=h_take(32);store64(codes,103);store64(codes+8,108);store64(codes+16,17);store64(codes+24,31);let i=0;
    while i<4 {let direction=1;if i&1 {direction=-1;}let code=load64(codes+i*8);wt_key(code,1);let s=dw_forward(direction*25);
        dd_check(dd_field(s," input_forward=")==direction,"physical movement key was not held");
        wt_key(code,1);dw_forward(direction*25); // Host key repeat must not add another held reference.
        wt_key(code,0);s=dw_forward(0);dd_check(dd_field(s," input_forward=")==0,"movement key release left a held reference");i=i+1;
    }
    wt_key(17,1);dw_forward(25);wt_key(103,1);dw_forward(25);wt_key(17,0);dw_forward(25);wt_key(103,0);dw_forward(0);
    wt_key(17,1);dw_forward(25);wt_key(17,0);wt_key(31,1);dw_forward(-25);wt_key(31,0);dw_forward(0);
    let s=dd_stats();h_print(1,h_cat3("Maximum SDL key-release queue delay: ",h_int(dd_field(s,"release_ms="))," ms\n"));
    dd_check(dd_field(s,"release_ms=")<100,"SDL key releases backed up in the guest");
    wt_stop();h_remove(temp);h_print(1,h_cat3("PASS: ",h_int(dd_checks)," headless SDL W/S/arrows/repeat/alias/reversal command checks\n"));return 0;
}
