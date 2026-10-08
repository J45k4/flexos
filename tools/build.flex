import "host.flex";
fn main(argc,argv) {
    h_environment(argc,argv);h_assert(argc==2,"Usage: build FLEX-COMPILER (from repository root)");let compiler=h_real(load64(argv+8));h_mkdir("build/root");
    h_compile(compiler,"kernel.flex","build/flexos");h_compile(compiler,"tests/integration.flex","build/test-flexos");
    if !h_exists("build/root/hello.flex") {h_save("build/root/hello.flex",h_read("apps/hello.flex"));}
    if !h_exists("build/root/read.flex") {h_save("build/root/read.flex",h_read("apps/read.flex"));}
    h_print(1,"Built build/flexos and build/test-flexos; initial apps in build/root.\n");return 0;
}
