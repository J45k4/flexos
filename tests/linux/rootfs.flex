global checks=0;
fn check(ok) {if !ok {syscall(1,1,"ROOTFS FAIL\n",12,0,0,0);syscall(60,80,0,0,0,0,0);}checks=checks+1;return 0;}
fn same(a,b) {let i=0;while load8(a+i) && load8(a+i)==load8(b+i) {i=i+1;}return load8(a+i)==load8(b+i);}
fn main(argc,argv) {
    check(argc==3 && same(load64(argv+8),"hello world") && same(load64(argv+16),""));
    let p=alloc(4096);let dir=syscall(257,0xffffff9c,"/data",0x90000,0,0,0);check(dir>=3);
    let fd=syscall(257,dir,"bytes.bin",0x80000,0,0,0);check(fd>=3);check(syscall(72,fd,1,0,0,0,0)==1);check(syscall(72,fd,2,0,0,0,0)==0 && syscall(72,fd,1,0,0,0,0)==0);
    check(syscall(5,fd,p+256,0,0,0,0)==0 && load64(p+304)==4 && (load64(p+280)&0xf000)==0x8000);
    store64(p+512,p);store64(p+520,2);store64(p+528,p+2);store64(p+536,2);check(syscall(19,fd,p+512,2,0,0,0)==4 && load8(p)==65 && load8(p+1)==0 && load8(p+2)==255 && load8(p+3)==66);
    check(syscall(0,fd,p,4,0,0,0)==0);check(syscall(8,fd,1,0,0,0,0)==1 && syscall(0,fd,p,2,0,0,0)==2 && load8(p)==0 && load8(p+1)==255);
    check(syscall(2,"/data/bytes.bin",1,0,0,0,0)==-30 && syscall(2,"/data/new",65,0,0,0,0)==-30);
    check(syscall(257,fd,"child",0,0,0,0)==-20 && syscall(257,999,"child",0,0,0,0)==-9);
    check(syscall(217,dir,p,4096,0,0,0)>0 && syscall(217,dir,p,4096,0,0,0)==0);
    check(syscall(3,fd,0,0,0,0,0)==0 && syscall(3,dir,0,0,0,0,0)==0);
    store64(p+512,"ROOTFS ");store64(p+520,7);store64(p+528,"PASS\n");store64(p+536,5);check(syscall(20,1,p+512,2,0,0,0)==12);return 0;
}
