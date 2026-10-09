import "../tools/linux-test.flex";
fn main(argc,argv) {
    h_environment(argc,argv);h_assert(argc>=3 && argc<=5,"Usage: test-linux-x11 FLEX QEMU [FIRMWARE] [STATIC-X11-LIB-DIR]");let compiler=h_real(load64(argv+8));let qemu=h_real(h_executable(load64(argv+16)));let firmware=0;if argc>=4 && h_len(load64(argv+24)) {firmware=h_real(load64(argv+24));}let temp=h_temp();
    let args=h_args("cc","-m32","-static","-no-pie","-Wl,-Ttext-segment=0x400000","tests/linux/x11.c");if argc==5 {h_add(args,h_cat("-L",h_real(load64(argv+32))));}h_add(args,"-lX11");h_add(args,"-lxcb");h_add(args,"-lXau");h_add(args,"-lXdmcp");h_add(args,"-o");h_add(args,"build/linux/x11.elf");h_ok(args);
    let app=h_real("build/linux/x11.elf");let hash=h_sha(app);lt_open(qemu,app,firmware,temp);qt_until("X11 READY");qt_capture(h_join(temp,"x11.ppm"));lt_check(qt_pixel(45,45)==0xffffff && qt_pixel(35,35)==0,"ordinary Xlib fill rectangle did not reach VGA");
    qt_key_state("up",1);qt_pause(100);qt_key_state("up",0);qt_until("X11 PASS");lt_done(0);lt_check(h_equal(hash,h_sha(h_join(temp,"app.elf"))),"independent Xlib client ELF was modified");
    args=h_args("cc","-m32","-static","-no-pie","-Wl,-Ttext-segment=0x400000","tests/linux/x11-shm.c");if argc==5 {h_add(args,h_cat("-L",h_real(load64(argv+32))));}h_add(args,"-lXext");h_add(args,"-lX11");h_add(args,"-lxcb");h_add(args,"-lXau");h_add(args,"-lXdmcp");h_add(args,"-o");h_add(args,"build/linux/x11-shm.elf");h_ok(args);
    app=h_real("build/linux/x11-shm.elf");hash=h_sha(app);lt_open(qemu,app,firmware,temp);qt_until("X11 SHM READY");qt_capture(h_join(temp,"x11-shm.ppm"));
    lt_check(qt_pixel(32,32)==0x7f7f7f && qt_pixel(672,432)==0xffffff && qt_pixel(673,432)==0 && qt_pixel(1023,767)==0xffffff,"X11 presentation broke odd widths or screen-edge clipping");
    qt_key_state("up",1);qt_until("X11 BATCH READY");qt_key_state("up",0);qt_until("completions after release");lt_check(h_has(h_out(qt_process),"X11 SHM PASS"),"X11 batch starved key release events");lt_done(0);
    lt_check(h_equal(hash,h_sha(h_join(temp,"app.elf"))),"shared-memory Xlib client ELF was modified");
    h_remove(temp);h_print(1,h_cat3("PASS: ",h_int(lt_checks)," independent Xlib drawing, properties, geometry, shared memory, clipping, input ordering and exit checks\n"));return 0;
}
