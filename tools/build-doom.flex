import "host.flex";
fn bd_split(s) {let v=h_vec();let i=0;while load8(s+i) {while load8(s+i)==32 {i=i+1;}let start=i;while load8(s+i) && load8(s+i)!=32 {i=i+1;}if i>start {h_add(v,h_slice(s+start,i-start));}}return v;}
// The OS, loader and build harness are Flexscript. Doom is an external C game.
fn main(argc,argv) {
    h_environment(argc,argv);h_assert(argc==3,"Usage: build-doom FLEX-COMPILER DOOMGENERIC-SOURCE-DIRECTORY (stb_sprintf.h in dependency root)");
    let compiler=h_real(load64(argv+8));let source=h_real(load64(argv+16));let cc=h_executable("cc");
    h_mkdir("build");h_mkdir("build/doom");
    let objects=h_vec();let make=h_read(h_join(source,"Makefile"));let at=0;
    while load8(make+at) && !h_starts(make+at,"SRC_DOOM = ") {at=at+1;}h_assert(load8(make+at),"DoomGeneric source list missing");at=at+11;
    let names=h_buffer();while load8(make+at) && load8(make+at)!=10 {h_append(names,make+at,1);at=at+1;}
    let list=bd_split(h_data(names));let i=0;
    while i<h_count(list) {let name=h_at(list,i);let n=h_len(name);
        if n>2 && !h_equal(name,"doomgeneric_xlib.o") {
            let obj=h_join("build/doom",name);let c=h_cat(h_slice(name,n-2),".c");let input=h_join(source,c);
            if h_equal(name,"i_input.o") {
                // DoomGeneric stops its event loop after each release. Several
                // released keys then take several 35-Hz tics to reach gameplay.
                // Patch only a build copy; retain upstream shift/character logic.
                let original=h_read(input);let before="            }\n            break;\n";
                h_assert(h_has(original,before),"DoomGeneric key-release patch does not match this source revision");
                let patched=h_replace(original,before,"            }\n");h_assert(h_len(original)-h_len(patched)==19,"DoomGeneric key-release patch must match exactly once");
                input="build/doom/i_input.c";h_save(input,patched);
            }
            let args=h_args(cc,"-std=c11","-c","-O2","-ffreestanding","-fno-builtin");h_add(args,"-fno-stack-protector");
            h_add(args,"-fno-pie");h_add(args,"-mno-red-zone");h_add(args,"-ffunction-sections");h_add(args,"-fdata-sections");h_add(args,"-w");h_add(args,"-D_DEFAULT_SOURCE");
            h_add(args,"-DDOOMGENERIC_RESX=320");h_add(args,"-DDOOMGENERIC_RESY=200");h_add(args,h_cat("-I",source));h_add(args,input);h_add(args,"-o");h_add(args,obj);h_ok(args);h_add(objects,obj);
        }i=i+1;
    }
    let args=h_args(cc,"-std=c11","-c","-O2","-ffreestanding","-fno-builtin");h_add(args,"-fno-stack-protector");h_add(args,"-fno-pie");h_add(args,"-mno-red-zone");h_add(args,"-ffunction-sections");h_add(args,"-fdata-sections");
    h_add(args,"-DDOOMGENERIC_RESX=320");h_add(args,"-DDOOMGENERIC_RESY=200");h_add(args,h_cat("-I",source));h_add(args,h_cat("-I",h_dir(h_dir(source))));h_add(args,"ports/doom/adapter.c");h_add(args,"-o");h_add(args,"build/doom/adapter.o");h_ok(args);h_add(objects,"build/doom/adapter.o");
    args=h_args("ld","--gc-sections","-T","ports/doom/payload.ld","-o","build/doom/doom.elf");i=0;while i<h_count(objects) {h_add(args,h_at(objects,i));i=i+1;}h_ok(args);
    h_ok(h_args(compiler,"--target","baremetal-x86_64","doom.flex","-o","build/flexos-doom.bin"));
    h_compile(compiler,"tools/run-doom.flex","build/run-doom");h_compile(compiler,"tests/doom.flex","build/test-doom");
    h_compile(compiler,"tests/doom-wayland.flex","build/test-doom-wayland");
    h_print(1,"Built native Doom payload, FlexOS Doom kernel, launcher and headless test harness.\n");return 0;
}
