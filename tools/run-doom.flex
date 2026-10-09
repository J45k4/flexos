import "doom-host.flex";
fn main(argc,argv) {
    h_environment(argc,argv);h_assert(argc>=3 && argc<=5,"Usage: run-doom QEMU IWAD [FIRMWARE-DIRECTORY] [DISPLAY] (from repository root)");
    let qemu=h_real(h_executable(load64(argv+8)));let wad=h_real(load64(argv+16));let firmware=0;let display="gtk,gl=off,show-menubar=off";
    if h_getenv("WAYLAND_DISPLAY") {display="sdl,gl=off";}if argc>=4 {firmware=h_real(load64(argv+24));}if argc==5 {display=load64(argv+32);}
    let temp=h_temp();doom_stage(temp,wad);let args=doom_args(qemu,wad,firmware,display,temp);let p=h_spawn(args,0,0);
    while h_status(p)==-999 {h_pump(p,10);h_print(1,h_out(p));let out=load64(p+16);store64(out+8,0);if load64(out) {store8(load64(out),0);}h_print(2,h_err(p));let err=load64(p+24);store64(err+8,0);if load64(err) {store8(load64(err),0);}}
    let status=h_status(p);h_stop(p);h_remove(temp);return status;
}
