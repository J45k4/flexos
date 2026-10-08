import "host.flex";
fn main(argc,argv) {
    h_environment(argc,argv);h_assert(argc>=2 && argc<=4,"Usage: run-desktop QEMU [FIRMWARE-DIRECTORY] [DISPLAY] (from repository root)");
    let qemu=h_real(h_executable(load64(argv+8)));let display="gtk,gl=off,show-menubar=off";
    // SDL supports native relative-pointer capture on Wayland; GTK's PS/2
    // pointer path relies on X11-style warping. Explicit display choices win.
    if h_getenv("WAYLAND_DISPLAY") {display="sdl,gl=off";}if argc==4 {display=load64(argv+24);}
    let args=h_args(qemu,"-accel","tcg","-m","64M","-smp");h_add(args,"1");h_add(args,"-vga");h_add(args,"std");
    h_add(args,"-name");h_add(args,"FlexOS Desktop");h_add(args,"-display");h_add(args,display);h_add(args,"-monitor");h_add(args,"none");
    h_add(args,"-serial");h_add(args,"stdio");h_add(args,"-nic");h_add(args,"none");h_add(args,"-no-reboot");h_add(args,"-no-shutdown");
    h_add(args,"-kernel");h_add(args,h_real("build/flexos-desktop.bin"));if argc>=3 {h_add(args,"-L");h_add(args,h_real(load64(argv+16)));}
    let words=h_take((h_count(args)+1)*8);let i=0;while i<h_count(args) {store64(words+i*8,h_at(args,i));i=i+1;}store64(words+i*8,0);
    syscall(59,qemu,words,h_env,0,0,0);h_die("cannot start desktop QEMU");return 1;
}
