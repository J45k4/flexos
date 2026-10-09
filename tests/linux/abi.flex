global checks=0;
fn length(s) {let i=0;while load8(s+i) {i=i+1;}return i;}
fn text(s) {return syscall(1,1,s,length(s),0,0,0);}
fn number(n) {let p=alloc(32);let i=31;store8(p+i,0);while n>=10 {i=i-1;store8(p+i,48+n%10);n=n/10;}i=i-1;store8(p+i,48+n);text(p+i);return 0;}
fn check(ok) {if !ok {text("ABI CHECK FAILED after ");number(checks);text(" checks\n");syscall(60,77,0,0,0,0,0);}checks=checks+1;return 0;}
fn same(a,b) {let i=0;while load8(a+i) && load8(a+i)==load8(b+i) {i=i+1;}return load8(a+i)==load8(b+i);}
fn main(argc,argv) {
    check(argc==1 && load64(argv)!=0 && load64(argv+8)==0);let env=argv+(argc+1)*8;while load64(env) {env=env+8;}let aux=env+8;let page=0;let headers=0;let entry=0;
    while load64(aux) {if load64(aux)==6 {page=load64(aux+8);}if load64(aux)==3 {headers=load64(aux+8);}if load64(aux)==9 {entry=load64(aux+8);}aux=aux+16;}
    check(page==4096 && headers>0 && (load64(headers)&0xffffffff)==1 && entry>=0x400000);
    check(syscall(65535,0,0,0,0,0,0)==-38);check(syscall(1,99,"x",1,0,0,0)==-9);check(syscall(1,1,0x100000,1,0,0,0)==-14);
    let p=alloc(8192);check(p>0 && !(p&4095));check(load64(p)==0 && load64(p+8184)==0);store8(p+4095,65);store8(p+4096,66);store8(p+4097,10);
    check(syscall(1,1,p+4095,3,0,0,0)==3);check(syscall(10,p,4096,1,0,0,0)==0);let readonly=syscall(2,"welcome.txt",0,0,0,0,0);check(readonly>=3 && syscall(0,readonly,p,1,0,0,0)==-14);syscall(3,readonly,0,0,0,0,0);
    check(syscall(10,p,4096,0,0,0,0)==0);check(syscall(1,1,p,1,0,0,0)==-14);check(syscall(10,p,4096,3,0,0,0)==0 && load8(p+4095)==65);
    check(syscall(11,p,8192,0,0,0,0)==0);check(syscall(1,1,p,1,0,0,0)==-14);check(syscall(10,p,4096,3,0,0,0)==-12);
    let base=syscall(12,0,0,0,0,0,0);check(syscall(12,base+8192,0,0,0,0,0)==base+8192);store64(base+4096,12345);check(load64(base+4096)==12345);check(syscall(12,base,0,0,0,0,0)==base);
    p=alloc(4096);let time=p;check(syscall(228,1,time,0,0,0,0)==0);let before=load64(time)*1000000000+load64(time+8);store64(p+16,0);store64(p+24,10000000);
    check(syscall(35,p+16,0,0,0,0,0)==0);check(syscall(228,1,time,0,0,0,0)==0 && load64(time)*1000000000+load64(time+8)>before);check(syscall(228,9999,time,0,0,0,0)==-22);
    check(syscall(63,p+128,0,0,0,0,0)==0 && same(p+388,"x86_64"));
    let fd=syscall(257,-100,"welcome.txt",0,0,0,0);check(fd>=3);check(syscall(5,fd,p+512,0,0,0,0)==0 && load64(p+560)>0);
    check(syscall(0,fd,p+1024,7,0,0,0)==7);store8(p+1031,0);check(same(p+1024,"Welcome"));check(syscall(8,fd,0,0,0,0,0)==0);
    check(syscall(3,fd,0,0,0,0,0)==0 && syscall(0,fd,p+1024,1,0,0,0)==-9);
    check(syscall(2,"missing.txt",0,0,0,0,0)==-2);check(syscall(2,0x100000,0,0,0,0,0)==-14);
    text("ABI PASS ");number(checks);text(" checks\n");return 23;
}
