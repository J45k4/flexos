import "../tools/linux-memory-test.flex";
import "../tools/wayland-test.flex";
global iw_command=0;
global iw_max_press=0;
global iw_max_release=0;
fn iw_key(code,down) {
    // Do not use wt_key's fixed pause: measure from the actual host event.
    let p=wt_message(7,1,20);wt_u32(p+8,net_now());wt_u32(p+12,code);wt_u32(p+16,down);wt_send(p);return 0;
}
fn iw_wait(turn,direction,start) {
    let matched=0;while !matched && net_now()-start<150 {
        let value=dt_physical(iw_command);if turn {value=(value>>16)&65535;if value>=32768 {value=value-65536;}}
        else {value=value&255;if value>=128 {value=value-256;}}
        matched=direction==0 && value==0 || direction>0 && value>0 || direction<0 && value<0;
    }
    let elapsed=net_now()-start;lt_check(matched && elapsed<=150,"historical Linux Doom SDL movement command did not react within 150 ms");
    if direction {if elapsed>iw_max_press {iw_max_press=elapsed;}}else {if elapsed>iw_max_release {iw_max_release=elapsed;}}return 0;
}
fn main(argc,argv) {
    h_environment(argc,argv);h_assert(argc==3 || argc==4,"Usage: test-linux-doom-wayland QEMU SWAY [FIRMWARE]");let qemu=h_real(h_executable(load64(argv+8)));let sway=h_real(h_executable(load64(argv+16)));let firmware=0;if argc==4 {firmware=h_real(load64(argv+24));}
    h_mkdir("build/desktop-tests");let temp=h_temp();wt_prepare(sway,temp);h_setenv("SDL_RENDER_DRIVER",0);let elf=h_real("build/linux-id-doom/objects/linuxxdoom");let hash=h_sha(elf);
    ld_symbols=h_out(h_ok(h_args("nm","-P",elf,0,0,0)));ld_layout=h_read("build/linux-id-doom/layout.txt");lh_rootfs=h_real("build/linux-id-doom/rootfs.tar");lh_command="-display unix:0 -warp 1 1 -skill 2 -2";lh_display="sdl,gl=off";
    lt_open(qemu,elf,firmware,temp);lt_check(h_equal(h_getenv("SDL_RENDER_DRIVER"),"software"),"Linux launcher did not choose its tested SDL renderer");qt_until("Using MITSHM extension");qt_pause(1500);wt_absolute(512,384);wt_click();
    let player=dt_symbol("players")+dt_u32(dt_symbol("consoleplayer"))*dt_offset(0);iw_command=dt_address(player+dt_offset(6));
    // Physical Wayland -> SDL -> PS/2 -> X11 -> original engine ticcmds.
    // Check commands, rather than treating original movement inertia as lag.
    let i=0;while i<12 {let turn=i>=6;let positive=103;let negative=108;if turn {positive=105;negative=106;}
        let start=net_now();iw_key(positive,1);iw_wait(turn,1,start);qt_pause(65);
        start=net_now();iw_key(positive,1);iw_wait(turn,1,start); // Host repeat cannot create another held reference.
        start=net_now();iw_key(positive,0);iw_key(negative,1);iw_wait(turn,-1,start);qt_pause(65);
        start=net_now();iw_key(negative,0);iw_wait(turn,0,start);qt_pause(37);i=i+1;
    }
    let start=net_now();iw_key(103,1);iw_wait(0,1,start);start=net_now();iw_key(108,1);iw_wait(0,0,start);
    start=net_now();iw_key(103,0);iw_wait(0,-1,start);start=net_now();iw_key(108,0);iw_wait(0,0,start);
    h_print(1,h_cat3("Maximum SDL command start/reversal: ",h_int(iw_max_press)," ms\n"));h_print(1,h_cat3("Maximum SDL command release: ",h_int(iw_max_release)," ms\n"));
    lt_check(h_equal(hash,h_sha(elf)) && h_equal(hash,h_sha(h_join(temp,"app.elf"))),"Linux Doom ELF changed for SDL input");wt_stop();h_remove(temp);
    h_print(1,h_cat3("PASS: ",h_int(lt_checks)," unchanged Linux Doom SDL start, reversal, repeat, simultaneous-key and release checks\n"));return 0;
}
