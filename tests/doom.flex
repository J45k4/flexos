import "../tools/doom-test.flex";
fn dd_reject(qemu,wad,firmware,temp,kind,message) {
    doom_stage(temp,wad);
    if kind==1 {let p=h_read("build/doom/doom.elf");let size=h_file_size;let ph=load64(p+32);store64(p+ph+16,0x1000000);h_save_bytes(h_join(temp,"game.elf"),p,size,384);}
    else if kind==2 {let p=h_read(wad);let size=h_file_size;store8(p+8,255);store8(p+9,255);store8(p+10,255);store8(p+11,255);h_save_bytes(h_join(temp,"game.wad"),p,size,384);}
    else {let p=h_read("build/doom/doom.elf");let size=h_file_size;store64(p+24,0x1000000);h_save_bytes(h_join(temp,"game.elf"),p,size,384);}
    qt_process=h_spawn(doom_args(qemu,wad,firmware,"none",temp),0,0);qt_until(message);dd_check(!h_has(h_out(qt_process),"FlexOS Doom ready"),"invalid boot module was executed");qt_stop();return 0;
}
fn main(argc,argv) {
    h_environment(argc,argv);h_assert(argc==3 || argc==4,"Usage: test-doom QEMU IWAD [FIRMWARE-DIRECTORY]");let qemu=h_real(h_executable(load64(argv+8)));let wad=h_real(load64(argv+16));let firmware=0;if argc==4 {firmware=h_real(load64(argv+24));}
    h_mkdir("build/doom-tests");let temp=h_temp();doom_stage(temp,wad);let args=doom_args(qemu,wad,firmware,"none",temp);let socket=h_join(temp,"doom.sock");
    h_add(args,"-qmp");h_add(args,h_cat3("unix:",socket,",server=on,wait=off"));qt_process=h_spawn(args,0,0);qt_until("FlexOS Doom ready");
    let address=h_zero(h_take(110),110);store8(address,1);h_copy(address+2,socket,h_len(socket));qt_fd=syscall(41,1,1|0x80000,0,0,0,0);
    qt_assert(qt_fd>=0 && syscall(42,qt_fd,address,h_len(socket)+3,0,0,0)==0,"QMP connect failed");syscall(72,qt_fd,4,2048,0,0,0);qt_assert(h_has(qt_read(),"QMP"),"QMP greeting missing");qt_execute("qmp_capabilities",0);qt_pause(300);
    qt_capture("build/doom-tests/frame.ppm");qt_png("build/doom-tests/start.png");let different=0;let y=84;while y<684 {let x=32;while x<992 {if qt_pixel(x,y)!=qt_pixel(32,84) {different=different+1;}x=x+15;}y=y+15;}
    dd_check(different>500,"Doom framebuffer is blank");let s=dd_stats();let tic=dd_field(s,"tic=");dd_check(dd_field(s,"state=")==0,"original engine is not in live gameplay");dd_check(dd_field(s,"frames=")>1,"game frames are not advancing");
    // Release several keys in quick succession, leaving a turn release last.
    // The upstream input loop's break after each keyup takes one game tic per
    // release and leaves that turn active long after the hardware keyup.
    let keys=h_args("4","5","6","7","8","9");h_add(keys,"0");h_add(keys,"left");let i=0;
    while i<h_count(keys) {qt_key_state(h_at(keys,i),1);qt_pause(10);i=i+1;}qt_pause(200);
    i=0;while i<h_count(keys) {qt_key_state(h_at(keys,i),0);qt_pause(5);i=i+1;}qt_pause(250);s=dd_stats();
    h_print(1,h_cat3("Maximum queued key-release delay: ",h_int(dd_field(s,"release_ms="))," ms\n"));
    dd_check(dd_field(s,"release_ms=")<100,"key releases backed up across game tics");
    let stopped=dd_field(s,"angle=");qt_pause(150);s=dd_stats();dd_check(dd_field(s,"angle=")==stopped,"turn remained active after a burst of key releases");
    let angle=dd_field(s,"angle=");qt_key_state("right",1);qt_pause(450);qt_key_state("right",0);qt_pause(120);s=dd_stats();dd_check(dd_field(s,"angle=")!=angle,"held turn key did not change player angle");let released=dd_field(s,"angle=");qt_pause(250);s=dd_stats();dd_check(dd_field(s,"angle=")==released,"key release did not stop turning");
    let x=dd_field(s," x=");let py=dd_field(s," y=");qt_key_state("up",1);qt_pause(500);qt_key_state("up",0);qt_pause(120);s=dd_stats();dd_check(dd_field(s," x=")!=x || dd_field(s," y=")!=py,"held movement key did not move real player");
    let ammo=dd_field(s,"ammo=");qt_key_state("ctrl",1);qt_pause(500);qt_key_state("ctrl",0);qt_pause(100);s=dd_stats();dd_check(dd_field(s,"ammo=")<ammo,"fire did not consume real engine ammunition");dd_check(dd_field(s,"tic=")>tic,"HPET game ticks did not advance");qt_png("build/doom-tests/playing.png");
    angle=dd_field(s,"angle=");qt_move(600,384);qt_pause(150);s=dd_stats();dd_check(dd_field(s,"angle=")!=angle,"relative PS/2 mouse did not turn the player");ammo=dd_field(s,"ammo=");qt_button(1);qt_pause(300);qt_button(0);qt_pause(100);s=dd_stats();dd_check(dd_field(s,"ammo=")<ammo,"mouse fire did not consume ammunition");
    qt_key("esc");qt_pause(200);qt_png("build/doom-tests/menu.png");qt_key("esc");qt_pause(200);
    qt_key("f12");qt_until("FlexOS Doom halted.");let regs=qt_execute("human-monitor-command","{\"command-line\":\"info registers\"}");dd_check(h_has(regs,"CPL=0") && h_has(regs,"CS64") && h_has(regs,"HLT=1"),"Doom did not run/halt in native ring-0 long mode");
    qt_stop();dd_reject(qemu,wad,firmware,temp,1,"ELF segment outside game region");dd_reject(qemu,wad,firmware,temp,2,"invalid WAD directory");dd_reject(qemu,wad,firmware,temp,3,"ELF entry must be inside executable game segment");
    h_remove(temp);h_print(1,h_cat3("PASS: ",h_int(dd_checks)," real Doom engine/framebuffer/gameplay/held-input/releases/HPET/module-boundary checks in headless QEMU\n"));return 0;
}
