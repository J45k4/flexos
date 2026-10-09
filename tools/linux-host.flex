import "qemu.flex";
global lh_rootfs=0;
global lh_command=0;
global lh_display=0;
fn lh_quote(s) {return h_cat3("\"",h_replace(h_replace(h_replace(h_replace(s,"\\","\\\\"),"\"","\\\""),"\n","\\n"),"\t","\\t"),"\"");}
fn lh_args(qemu,application,firmware,temp) {
    let bytes=h_read(application);h_save_bytes(h_join(temp,"app.elf"),bytes,h_file_size,384);
    let display=lh_display;if !display {display="none";}
    // QEMU's SDL gl=off still permits SDL's default accelerated renderer.
    // Use the same software presentation path as our headless input tests,
    // unless the caller deliberately selects a different SDL renderer.
    if h_starts(display,"sdl") && !h_getenv("SDL_RENDER_DRIVER") {h_setenv("SDL_RENDER_DRIVER","software");}
    let args=bq_args_display(qemu,h_real("build/flexos-linux.bin"),firmware,display);let memory="128M";if lh_rootfs {memory="256M";}let i=0;while i<h_count(args) {if h_equal(h_at(args,i),"64M") {store64(args+8+i*8,memory);}i=i+1;}
    let modules=h_join(temp,"app.elf");if lh_rootfs {bytes=h_read(lh_rootfs);h_assert(h_file_size<=50331648,"rootfs must be at most 48 MiB");h_save_bytes(h_join(temp,"rootfs.tar"),bytes,h_file_size,384);modules=h_cat3(modules,",",h_join(temp,"rootfs.tar"));}
    h_add(args,"-vga");h_add(args,"std");h_add(args,"-initrd");h_add(args,modules);if lh_command {h_add(args,"-append");h_add(args,lh_command);}return args;
}
