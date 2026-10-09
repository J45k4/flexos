import "linux-host.flex";
fn main(argc,argv) {
    h_environment(argc,argv);h_assert(argc>=3,"Usage: run-linux QEMU STATIC-LINUX-ELF [FIRMWARE] [--rootfs TAR] [--display DISPLAY] [-- APP-ARGS]");
    let qemu=h_real(h_executable(load64(argv+8)));let app=h_real(load64(argv+16));let firmware=0;let i=3;
    while i<argc {let arg=load64(argv+i*8);if h_equal(arg,"--") {i=i+1;lh_command="";while i<argc {if h_len(lh_command) {lh_command=h_cat(lh_command," ");}lh_command=h_cat(lh_command,lh_quote(load64(argv+i*8)));i=i+1;}}
        else if h_equal(arg,"--rootfs") || h_equal(arg,"--display") {h_assert(i+1<argc,"missing launcher option value");i=i+1;if h_equal(arg,"--rootfs") {lh_rootfs=h_real(load64(argv+i*8));}else {lh_display=load64(argv+i*8);}i=i+1;}
        else {h_assert(!firmware && !h_starts(arg,"--"),"invalid launcher argument");firmware=h_real(arg);i=i+1;}
    }
    let temp=h_temp();let p=h_spawn(lh_args(qemu,app,firmware,temp),0,0);let out=0;let err=0;let input=h_take(8192);let pending=0;let sent=0;let stdin=1;let poll=h_take(8);
    while h_status(p)==-999 {
        h_pump(p,10);let size=h_size(load64(p+16));if size>out {h_write(1,h_out(p)+out,size-out);out=size;}size=h_size(load64(p+24));if size>err {h_write(2,h_err(p)+err,size-err);err=size;}
        if h_has(h_out(p),"FlexOS kernel resumed.") {let at=h_find(h_out(p),"Linux process exited status=");let status=0;if at>=0 {at=at+28;while load8(h_out(p)+at)>=48 && load8(h_out(p)+at)<=57 {status=status*10+load8(h_out(p)+at)-48;at=at+1;}}h_stop(p);h_remove(temp);return status;}
        // UART initialization clears its FIFO; forward stdin only after boot.
        if h_has(h_out(p),"FlexOS Linux ABI ready") {
            if pending>sent {let n=syscall(1,load64(p+32),input+sent,pending-sent,0,0,0);if n>0 {sent=sent+n;}else {h_assert(n==-11 || n==-4,"QEMU input failed");}}
            else if stdin {store64(poll,1<<32);if syscall(7,poll,1,0,0,0,0)>0 {let n=syscall(0,0,input,8192,0,0,0);if n>0 {pending=n;sent=0;}else if n==0 {stdin=0;}}}
        }
    }
    let status=h_status(p);h_stop(p);h_remove(temp);return status;
}
