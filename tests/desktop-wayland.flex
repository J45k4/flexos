import "../tools/wayland-test.flex";
fn main(argc,argv) {
    h_environment(argc,argv);h_assert(argc>=4 && argc<=6,"Usage: test-desktop-wayland FLEX QEMU SWAY [FIRMWARE] [DISPLAY] (from repository root)");
    let compiler=h_real(load64(argv+8));let qemu=h_real(h_executable(load64(argv+16)));let sway=h_real(h_executable(load64(argv+24)));
    let firmware=0;if argc>=5 {firmware=h_real(load64(argv+32));}let display="sdl,gl=off";if argc==6 {display=load64(argv+40);}
    h_mkdir("build/desktop-tests");let temp=h_temp();let image=h_join(temp,"desktop.bin");h_ok(h_args(compiler,"--target","baremetal-x86_64","desktop.flex","-o",image));
    wt_prepare(sway,temp);qt_open_display(qemu,image,firmware,temp,display);qt_pause(1200);wt_absolute(512,384);wt_click();qt_pause(200);
    let before=wt_cursor();wt_relative(48,-24);let after=wt_cursor();
    qt_png("build/desktop-tests/wayland-input.png");
    wt_check((after&0xffffffff)>(before&0xffffffff)+10 && (after>>32)<(before>>32)-5,"captured host mouse did not move the guest pointer");
    wt_move(72,310);wt_click();qt_until("Desktop opened Notes");wt_check(h_has(h_out(qt_process),"Desktop opened Notes"),"host mouse click did not open Notes");
    wt_move(500,184);wt_button(1);wt_relative(-40,40);wt_button(0);qt_until("Desktop moved/resized Notes");qt_capture("build/desktop-tests/wayland-frame.ppm");
    wt_check(qt_pixel(300,610)==0x182537,"host mouse drag did not move the window");qt_png("build/desktop-tests/wayland-mouse.png");
    wt_release_capture();before=wt_cursor();wt_relative(32,16);after=wt_cursor();wt_check(after==before,"Ctrl+Alt+G did not release mouse capture");
    wt_absolute(512,384);wt_click();before=wt_cursor();wt_relative(24,12);after=wt_cursor();
    wt_check((after&0xffffffff)>(before&0xffffffff)+5 && (after>>32)>(before>>32)+3,"mouse capture did not resume after clicking the display");
    wt_stop();h_remove(temp);h_print(1,h_cat3("PASS: ",h_int(wt_count)," headless Wayland host mouse capture/movement/click/drag checks\n"));return 0;
}
