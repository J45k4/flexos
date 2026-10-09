import "host.flex";
fn main(argc,argv) {
    h_environment(argc,argv);h_assert(argc==4,"Usage: build-linux-doom-vt FLEX DOOMGENERIC-SOURCE IWAD (from repository root)");let compiler=h_real(load64(argv+8));let source=h_real(load64(argv+16));let wad=h_real(load64(argv+24));
    h_mkdir("build/linux-doom");h_mkdir("build/linux-doom/objects");h_mkdir("build/linux-doom/rootfs");
    // Use upstream Linux build rules and sources, including its existing VT
    // backend and unmodified input loop. No FlexOS adapter or custom libc.
    let args=h_args("make","-f","Makefile.linuxvt","CC=cc","CFLAGS=-O2 -DNORMALUNIX -DLINUX -DSNDSERV -D_DEFAULT_SOURCE -DDOOMGENERIC_RESX=640 -DDOOMGENERIC_RESY=400","LDFLAGS=-static -no-pie -Wl,--gc-sections");
    h_add(args,h_cat("OBJDIR=",h_real("build/linux-doom/objects")));h_add(args,h_cat("OUTPUT=",h_absolute("build/linux-doom/doom.elf")));h_add(args,"-j2");let p=h_wait(h_spawn(args,"",source));h_check(p,0,0);
    // Inspect the upstream ABI for the external headless test only. Nothing
    // is linked into the game or exposed by the FlexOS kernel for this.
    h_save("build/linux-doom/layout.c","#include <stddef.h>\n#include <stdio.h>\n#include \"d_player.h\"\nint main(void){printf(\"%zu %zu %zu %zu %zu %zu\\n\",sizeof(player_t),offsetof(player_t,mo),offsetof(player_t,ammo),offsetof(mobj_t,x),offsetof(mobj_t,y),offsetof(mobj_t,angle));return 0;}\n");
    args=h_args("cc","-I",source,"build/linux-doom/layout.c","-o","build/linux-doom/layout");h_ok(args);p=h_ok(h_args(h_real("build/linux-doom/layout"),0,0,0,0,0));h_save("build/linux-doom/layout.txt",h_out(p));
    let data=h_read(wad);h_assert(h_file_size<=50331648,"IWAD must fit in rootfs");h_save_bytes("build/linux-doom/rootfs/freedoom1.wad",data,h_file_size,384);
    // Preserve upstream controls; this build disables configuration loading.
    syscall(87,"build/linux-doom/rootfs/controls.cfg",0,0,0,0,0);
    args=h_args("tar","--format=ustar","-cf","build/linux-doom/rootfs.tar","-C","build/linux-doom/rootfs");h_add(args,".");h_ok(args);
    h_ok(h_args(compiler,"--target","baremetal-x86_64","linux.flex","-o","build/flexos-linux.bin"));
    h_compile(compiler,"tools/run-linux.flex","build/run-linux");h_compile(compiler,"tools/run-linux-doom-vt.flex","build/run-linux-doom-vt");h_compile(compiler,"tests/linux-doom-vt.flex","build/test-linux-doom-vt");
    h_print(1,"Built unchanged upstream Linux Doom, ordinary rootfs, generic FlexOS Linux kernel and headless test.\n");return 0;
}
