fn out(s,n) {return syscall(1,1,s,n,0,0,0);}
fn check(ok) {if !ok {out("DEVICE FAIL\n",12);syscall(60,79,0,0,0,0,0);}return 0;}
fn main() {
    let fb=syscall(2,"/dev/fb0",2,0,0,0,0);check(fb>=3);let info=alloc(4096);check(syscall(16,fb,0x4600,info,0,0,0)==0);
    check((load64(info)&0xffffffff)==1024 && (load64(info+4)&0xffffffff)==768 && (load64(info+24)&0xffffffff)==32);
    check(syscall(16,fb,0x4602,info+256,0,0,0)==0 && (load64(info+304)&0xffffffff)==4096);
    let pixels=syscall(9,0,3145728,3,1,fb,0);check(pixels>0);store64(pixels+(32*1024+32)*4,0x006ee0c9006ee0c9);
    let dir=syscall(257,0xffffff9c,"/dev/input",0x90000,0,0,0);check(dir>=3);check(syscall(217,dir,info,4096,0,0,0)>0);check(syscall(3,dir,0,0,0,0,0)==0);
    let fd=syscall(2,"/dev/input/event0",2048,0,0,0,0);check(fd>=3);check(syscall(16,fd,0x80084520,info,0,0,0)>=0 && (load8(info)&2));
    check(syscall(16,fd,0x80604521,info,0,0,0)>=0 && (load8(info+3)&16) && (load8(info+3)&64));
    check(syscall(0,fd,info,24,0,0,0)==-11);let poll=info+512;store64(poll,fd|(1<<32));check(syscall(7,poll,1,0,0,0,0)==0);
    out("DEVICES READY\n",14);let down=0;let up=0;while !up {store64(poll,fd|(1<<32));check(syscall(7,poll,1,1000,0,0,0)>=0);
        if (load64(poll)>>48)&1 {let n=syscall(0,fd,info,24,0,0,0);check(n==24);if (load64(info+16)&0xffff)==1 && ((load64(info+16)>>16)&0xffff)==17 {let state=load64(info+20)&0xffffffff;if state==1 {down=1;}else if state==0 {check(down);up=1;}}}
    }
    check(syscall(11,pixels,3145728,0,0,0,0)==0);let p=syscall(9,0,4096,3,34,0xffffffff,0);check(p>0);store64(p,12345);check(load64(p)==12345);out("DEVICE PASS\n",12);return 0;
}
