// Ordinary Linux target: the same ELF runs unchanged on Linux and FlexOS.
fn main(argc,argv) {
    let message="Hello from an unchanged Linux binary!\n";
    syscall(1,1,message,38,0,0,0);let p=alloc(16);if p<0 {return 1;}store64(p,123456789);
    if load64(p)!=123456789 {return 2;}return 0;
}
