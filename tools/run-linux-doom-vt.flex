import "host.flex";
fn main(argc,argv) {
    h_environment(argc,argv);h_assert(argc==2 || argc==3,"Usage: run-linux-doom-vt QEMU [FIRMWARE] (from repository root)");
    let launcher=h_real("build/run-linux");let args=h_args(launcher,h_real(h_executable(load64(argv+8))),h_real("build/linux-doom/doom.elf"),0,0,0);if argc==3 {h_add(args,h_real(load64(argv+16)));}
    h_add(args,"--rootfs");h_add(args,h_real("build/linux-doom/rootfs.tar"));h_add(args,"--display");let display="gtk,gl=off,show-menubar=off";if h_getenv("WAYLAND_DISPLAY") {display="sdl,gl=off";}h_add(args,display);
    h_add(args,"--");h_add(args,"-iwad");h_add(args,"/freedoom1.wad");h_add(args,"-nosound");h_add(args,"-noendoom");h_add(args,"-warp");h_add(args,"1");h_add(args,"1");h_add(args,"-skill");h_add(args,"2");
    let words=h_take((h_count(args)+1)*8);let i=0;while i<h_count(args) {store64(words+i*8,h_at(args,i));i=i+1;}store64(words+i*8,0);syscall(59,launcher,words,h_env,0,0,0);h_die("cannot execute generic Linux launcher");return 1;
}
