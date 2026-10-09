import "host.flex";
fn main(argc,argv) {
    h_environment(argc,argv);h_assert(argc==2,"Usage: build-linux FLEX-COMPILER (from repository root)");let compiler=h_real(load64(argv+8));h_mkdir("build");h_mkdir("build/linux");
    h_ok(h_args(compiler,"--target","baremetal-x86_64","linux.flex","-o","build/flexos-linux.bin"));
    h_compile(compiler,"examples/linux/hello.flex","build/linux/hello.elf");h_compile(compiler,"tools/run-linux.flex","build/run-linux");h_compile(compiler,"tests/linux.flex","build/test-linux");
    h_compile(compiler,"tests/linux-x11.flex","build/test-linux-x11");
    h_print(1,"Built FlexOS Linux ABI kernel, ordinary Linux example, launcher and headless harness.\n");return 0;
}
