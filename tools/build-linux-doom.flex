import "host.flex";
fn main(argc,argv) {
    h_environment(argc,argv);h_assert(argc==4 || argc==5,"Usage: build-linux-doom FLEX ID-LINUXDOOM-SOURCE IWAD [STATIC-X11-LIB-DIR]");let compiler=h_real(load64(argv+8));let source=h_real(load64(argv+16));let wad=h_real(load64(argv+24));
    h_mkdir("build/linux-id-doom/objects");h_mkdir("build/linux-id-doom/compat");h_mkdir("build/linux-id-doom/rootfs");
    // The historical engine needs 32-bit pointers and legacy system headers.
    // Supply the missing headers in the build environment; engine files stay
    // byte-for-byte upstream, including its original X11 graphics/input code.
    h_save("build/linux-id-doom/compat/errnos.h","#include <errno.h>\n");h_save("build/linux-id-doom/compat/values.h","#include <limits.h>\n#define MAXINT INT_MAX\n#define MININT INT_MIN\n#define MAXSHORT SHRT_MAX\n#define MINSHORT SHRT_MIN\n#define MAXLONG LONG_MAX\n#define MINLONG LONG_MIN\n#define MAXCHAR SCHAR_MAX\n#define MINCHAR SCHAR_MIN\n");
    let cflags=h_cat("CFLAGS=-m32 -O2 -std=gnu89 -fcommon -fno-strict-aliasing -fwrapv -DNORMALUNIX -DLINUX -DSNDSERV -Wno-implicit-function-declaration -Wno-int-conversion -include errno.h -I",h_real("build/linux-id-doom/compat"));
    let ldflags="LDFLAGS=-m32 -static -no-pie -Wl,-Ttext-segment=0x400000";if argc==5 {ldflags=h_cat3(ldflags," -L",h_real(load64(argv+32)));}
    let args=h_args("make","-s","CC=cc",cflags,ldflags,"LIBS=-lXext -lX11 -lxcb -lXau -lXdmcp -lm -lpthread");h_add(args,h_cat("O=",h_real("build/linux-id-doom/objects")));h_add(args,"-j2");let p=h_wait(h_spawn(args,"",source));h_check(p,0,0);
    h_save("build/linux-id-doom/layout.c","#include <stddef.h>\n#include <stdio.h>\n#include \"d_player.h\"\nint main(void){printf(\"%zu %zu %zu %zu %zu %zu %zu\\n\",sizeof(player_t),offsetof(player_t,mo),offsetof(player_t,ammo),offsetof(mobj_t,x),offsetof(mobj_t,y),offsetof(mobj_t,angle),offsetof(player_t,cmd));return 0;}\n");
    args=h_args("cc","-m32","-static","-I",source,"build/linux-id-doom/layout.c");h_add(args,"-std=gnu89");h_add(args,"-I");h_add(args,h_real("build/linux-id-doom/compat"));h_add(args,"-DLINUX");h_add(args,"-o");h_add(args,"build/linux-id-doom/layout");h_ok(args);p=h_ok(h_args(h_real("build/linux-id-doom/layout"),0,0,0,0,0));h_save("build/linux-id-doom/layout.txt",h_out(p));
    let data=h_read(wad);h_assert(h_file_size<=50331648,"IWAD must fit in rootfs");h_save_bytes("build/linux-id-doom/rootfs/doom.wad",data,h_file_size,384);
    args=h_args("tar","--format=ustar","-cf","build/linux-id-doom/rootfs.tar","-C","build/linux-id-doom/rootfs");h_add(args,".");h_ok(args);
    h_ok(h_args(compiler,"--target","baremetal-x86_64","linux.flex","-o","build/flexos-linux.bin"));h_compile(compiler,"tools/run-linux.flex","build/run-linux");h_compile(compiler,"tools/run-linux-doom.flex","build/run-linux-doom");h_compile(compiler,"tests/linux-doom.flex","build/test-linux-doom");h_compile(compiler,"tests/linux-doom-wayland.flex","build/test-linux-doom-wayland");
    h_print(1,"Built unchanged historical id Linux Doom, normal static 32-bit libc/Xlib, FlexOS Linux/X11 and headless test.\n");return 0;
}
