import "host.flex";
fn main(argc,argv) {
    h_environment(argc,argv);h_assert(argc==2,"Usage: build-baremetal FLEX-COMPILER (from repository root)");
    let compiler=h_real(load64(argv+8));h_mkdir("build");
    h_ok(h_args(compiler,"--target","baremetal-x86_64","baremetal.flex","-o","build/flexos-baremetal.bin"));
    h_ok(h_args(compiler,"--target","baremetal-x86_64","desktop.flex","-o","build/flexos-desktop.bin"));
    h_compile(compiler,"tests/baremetal.flex","build/test-baremetal");
    h_compile(compiler,"tools/run-qemu.flex","build/run-qemu");
    h_compile(compiler,"tools/run-desktop.flex","build/run-desktop");h_compile(compiler,"tests/desktop.flex","build/test-desktop");
    h_compile(compiler,"tests/desktop-wayland.flex","build/test-desktop-wayland");
    h_print(1,"Built serial and desktop boot images, QEMU launchers and native test harnesses.\n");return 0;
}
