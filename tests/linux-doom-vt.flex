import "../tools/linux-memory-test.flex";
fn main(argc,argv) {
    h_environment(argc,argv);h_assert(argc==2 || argc==3,"Usage: test-linux-doom-vt QEMU [FIRMWARE] (from repository root)");let qemu=h_real(h_executable(load64(argv+8)));let firmware=0;if argc==3 {firmware=h_real(load64(argv+16));}
    let temp=h_temp();h_mkdir("build/linux-doom-tests");let elf=h_real("build/linux-doom/doom.elf");let hash=h_sha(elf);let symbols=h_ok(h_args("nm","-P",elf,0,0,0));ld_symbols=h_out(symbols);ld_layout=h_read("build/linux-doom/layout.txt");
    lh_rootfs=h_real("build/linux-doom/rootfs.tar");lh_command="-iwad /freedoom1.wad -nosound -noendoom -warp 1 1 -skill 2";lt_open(qemu,elf,firmware,temp);qt_until("I_InitGraphics");qt_pause(2000);
    lt_check(h_has(h_out(qt_process),"adding /freedoom1.wad"),"Linux game did not load the ordinary rootfs IWAD");
    lt_check(dt_u32(dt_symbol("gamestate"))==0 && dt_u32(dt_symbol("leveltime"))>0,"unchanged Linux Doom did not enter live gameplay");
    let ring3=0;let attempts=0;while attempts<20 && !ring3 {let regs=qt_execute("human-monitor-command","{\"command-line\":\"info registers\"}");ring3=h_has(regs,"CPL=3") && h_has(regs,"CS64");attempts=attempts+1;qt_pause(5);}lt_check(ring3,"Linux Doom did not execute in ring 3");
    qt_capture(h_join(temp,"game.ppm"));let pixels=0;let y=200;while y<550 {let x=210;while x<810 {if qt_pixel(x,y)!=0 {pixels=pixels+1;}x=x+20;}y=y+20;}lt_check(pixels>200 && qt_pixel(0,0)==0,"ordinary fbdev mapping did not display gameplay");qt_png("build/linux-doom-tests/start.png");
    let player=dt_symbol("players")+dt_u32(dt_symbol("consoleplayer"))*dt_offset(0);let mo=dt_user(player+dt_offset(1));let x=dt_u32(mo+dt_offset(3));let y0=dt_u32(mo+dt_offset(4));let tic=dt_u32(dt_symbol("gametic"));
    qt_key_state("up",1);qt_pause(400);qt_key_state("up",0);qt_pause(120);lt_check(dt_u32(mo+dt_offset(3))!=x || dt_u32(mo+dt_offset(4))!=y0,"standard Linux evdev arrow input did not move the player");
    let angle=dt_u32(mo+dt_offset(5));qt_key_state("left",1);qt_pause(300);qt_key_state("left",0);qt_pause(120);let stopped=dt_u32(mo+dt_offset(5));lt_check(stopped!=angle,"standard Linux evdev arrow input did not turn");qt_pause(180);lt_check(dt_u32(mo+dt_offset(5))==stopped,"Linux evdev key release did not stop rotation");
    let ammo=dt_u32(player+dt_offset(2));qt_key_state("ctrl",1);qt_pause(500);qt_key_state("ctrl",0);qt_pause(120);lt_check(dt_u32(player+dt_offset(2))<ammo,"ordinary Linux keyboard fire did not consume ammunition");lt_check(dt_u32(dt_symbol("gametic"))>tic,"real game ticks did not advance");qt_png("build/linux-doom-tests/playing.png");
    qt_key("esc");qt_pause(300);qt_png("build/linux-doom-tests/menu.png");qt_key("esc");qt_pause(100);qt_key("f10");qt_pause(300);qt_key("y");lt_done(0);
    lt_check(h_equal(hash,h_sha(elf)) && h_equal(hash,h_sha(h_join(temp,"app.elf"))),"Linux Doom ELF changed for FlexOS");h_remove(temp);h_print(1,h_cat3("PASS: ",h_int(lt_checks)," unchanged Linux Doom, ring-3, rootfs, fbdev, evdev, gameplay and exit checks\n"));return 0;
}
