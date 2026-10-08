import "qemu.flex";
fn main(argc,argv) {
    h_environment(argc,argv);h_assert(argc==2 || argc==3,"Usage: run-qemu QEMU [FIRMWARE-DIRECTORY] (from repository root)");
    let qemu=h_real(h_executable(load64(argv+8)));let firmware=0;if argc==3 {firmware=h_real(load64(argv+16));}
    let args=bq_args(qemu,h_real("build/flexos-baremetal.bin"),firmware);
    let words=h_take((h_count(args)+1)*8);let i=0;while i<h_count(args) {store64(words+i*8,h_at(args,i));i=i+1;}store64(words+i*8,0);
    syscall(59,qemu,words,h_env,0,0,0);h_die("cannot start QEMU");return 1;
}
