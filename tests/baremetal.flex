import "../tools/qemu.flex";
global qb_checks=0;
global qb_process=0;
global qb_qmp_fd=-1;
fn qb_check(ok,message) {
    if !ok && qb_process {h_print(2,h_out(qb_process));h_print(2,h_err(qb_process));h_stop(qb_process);}
    h_assert(ok,message);qb_checks=qb_checks+1;return 0;
}
fn qb_until(text) {
    let end=net_now()+10000;
    while !h_has(h_out(qb_process),text) {
        h_pump(qb_process,5);
        if h_status(qb_process)!=-999 || net_now()>end {qb_check(0,h_cat("missing QEMU output: ",text));}
    }return 0;
}
fn qb_clear() {let b=load64(qb_process+16);store64(b+8,0);if load64(b) {store8(load64(b),0);}return 0;}
fn qb_qmp_read() {
    let b=h_buffer();let scratch=h_take(8192);let end=net_now()+3000;
    while 1 {
        let n=syscall(0,qb_qmp_fd,scratch,8192,0,0,0);
        if n>0 {h_append(b,scratch,n);if load8(scratch+n-1)==10 {return h_data(b);}}
        else {if n!=-11 && n!=-4 {qb_check(0,"QMP connection closed");}h_sleep(5);}
        if net_now()>end {qb_check(0,"QMP response timed out");}
    }return 0;
}
fn qb_qmp(command) {qb_check(h_write(qb_qmp_fd,command,h_len(command))>0,"QMP write failed");return qb_qmp_read();}
fn qb_qmp_open(path) {
    let address=h_zero(h_take(110),110);store8(address,1);h_copy(address+2,path,h_len(path));
    qb_qmp_fd=syscall(41,1,1|0x80000,0,0,0,0);qb_check(qb_qmp_fd>=0,"QMP socket failed");
    qb_check(syscall(42,qb_qmp_fd,address,h_len(path)+3,0,0,0)==0,"QMP connect failed");syscall(72,qb_qmp_fd,4,2048,0,0,0);
    qb_check(h_has(qb_qmp_read(),"QMP"),"QMP greeting missing");
    qb_check(h_has(qb_qmp("{\"execute\":\"qmp_capabilities\"}\n"),"return"),"QMP capabilities failed");return 0;
}
fn qb_command(command,prompt) {
    qb_clear();h_trigger(qb_process,h_cat(command,"\n"));qb_until(prompt);
    let output=h_replace(h_out(qb_process),"\r","");
    // Drop the UART's command echo, so checks prove responses rather than
    // accidentally accepting the test's own input as kernel output.
    let first=h_find(output,"\n");qb_check(first>=0,"missing UART echo");return output+first+1;
}
fn qb_reject(compiler,temp,source,message,bare) {
    let path=h_join(temp,"invalid.flex");h_save(path,source);let target=h_join(temp,"invalid.bin");let args=0;
    if bare {args=h_args(compiler,"--target","baremetal-x86_64",path,"-o",target);}else {args=h_args(compiler,path,"-o",target,0,0);}
    let p=h_run(args);qb_check(h_status(p)==1 && h_has(h_err(p),message),h_cat("missing target rejection: ",h_err(p)));qb_check(!h_exists(target),"rejected compilation created an output");return 0;
}
fn main(argc,argv) {
    h_environment(argc,argv);h_assert(argc==3 || argc==4,"Usage: test-baremetal FLEX-COMPILER QEMU [FIRMWARE-DIRECTORY]");
    let compiler=h_real(load64(argv+8));let qemu=h_real(h_executable(load64(argv+16)));let firmware=0;if argc==4 {firmware=h_real(load64(argv+24));}
    let temp=h_temp();let image=h_join(temp,"flexos.bin");let second=h_join(temp,"second.bin");
    h_ok(h_args(compiler,"--target","baremetal-x86_64","baremetal.flex","-o",image));
    h_ok(h_args(compiler,"--target","baremetal-x86_64","baremetal.flex","-o",second));
    qb_check(h_equal(h_sha(image),h_sha(second)),"bare-metal image is not reproducible");
    let bytes=h_read(image);let size=h_file_size;
    qb_check((load64(bytes)&0xffffffff)==0x1badb002,"Multiboot header missing");
    qb_check((((load64(bytes)&0xffffffff)+(load64(bytes+4)&0xffffffff)+(load64(bytes+8)&0xffffffff))&0xffffffff)==0,"Multiboot checksum invalid");
    qb_check((load64(bytes+16)&0xffffffff)==0x400000 && (load64(bytes+20)&0xffffffff)==0x400000+size,"Multiboot load extent invalid");
    qb_check((load64(bytes+28)&0xffffffff)==0x400078,"Multiboot entry invalid");
    qb_reject(compiler,temp,"fn main(){return alloc(8);}","alloc and syscall require Linux",1);
    qb_reject(compiler,temp,"fn main(){return syscall(60,0,0,0,0,0,0);}","alloc and syscall require Linux",1);
    qb_reject(compiler,temp,"fn main(argc,argv){return argc;}","bare-metal main must take zero parameters",1);
    qb_reject(compiler,temp,"fn main(){return ffi_open(\"libc.so.6\");}","FFI is unavailable on bare metal",1);
    qb_reject(compiler,temp,"fn main(){return port_in8(0x3f8);}","hardware builtins require",0);
    let qmp=h_join(temp,"qmp.sock");let args=bq_args(qemu,image,firmware);h_add(args,"-qmp");h_add(args,h_cat3("unix:",qmp,",server=on,wait=off"));
    qb_process=h_spawn(args,0,0);qb_until("flexos:/ > ");qb_qmp_open(qmp);
    let registers=qb_qmp("{\"execute\":\"human-monitor-command\",\"arguments\":{\"command-line\":\"info registers\"}}\n");
    qb_check(h_has(registers,"CPL=0") && h_has(registers,"CS64"),h_cat("guest did not enter ring-0 long mode: ",registers));
    qb_check(h_has(h_out(qb_process),"bare-metal Flexscript kernel") && h_has(h_out(qb_process),"Linux: absent"),"bare-metal banner missing");
    let output=qb_command("resources","flexos:/ > ");qb_check(h_has(output,"filesystem / ram") && h_has(output,"console COM1 serial"),"native resource adapter missing");
    qb_check(h_has(output,"VM port pending"),"unimplemented execution provider advertised as available");
    qb_command("write app.flex 'fn main(){return 0;}'","flexos:/ > ");qb_command("app placeholder app.flex","flexos:/ > ");
    qb_check(h_has(qb_command("run placeholder","flexos:/ > "),"execution provider is unavailable"),"bare-metal app execution boundary is unclear");
    qb_check(h_has(qb_command("pwd","flexos:/ > "),"/\n"),"initial cwd incorrect");
    qb_check(h_has(qb_command("cat welcome.txt","flexos:/ > "),"This kernel and its boot code were generated by Flexscript"),"boot filesystem missing");
    qb_command("mkdir projects","flexos:/ > ");qb_command("cd projects","flexos:/projects > ");
    qb_command("write notes.txt \"Hello from bare metal\"","flexos:/projects > ");
    qb_check(h_has(qb_command("cat notes.txt","flexos:/projects > "),"Hello from bare metal\n"),"RAM file did not round trip");
    qb_check(h_has(qb_command("ls","flexos:/projects > "),"notes.txt\n"),"directory listing incorrect");
    qb_check(h_has(qb_command("pwd","flexos:/projects > "),"/projects\n"),"cwd normalization incorrect");
    qb_command("write notes.txt 'Unicode 你好 🌱'","flexos:/projects > ");
    qb_check(h_has(qb_command("cat notes.txt","flexos:/projects > "),"Unicode 你好 🌱\n"),"UTF-8 file replacement failed");
    qb_command("write 'with spaces.txt' \"first\\nsecond\"","flexos:/projects > ");
    qb_check(h_has(qb_command("cat 'with spaces.txt'","flexos:/projects > "),"first\nsecond\n"),"quoted paths or escaped contents failed");
    qb_command("cd /","flexos:/ > ");
    qb_check(h_has(qb_command("cat /../../welcome.txt","flexos:/ > "),"escapes"),"above-root traversal accepted");
    qb_check(h_has(qb_command("mkdir /projects","flexos:/ > "),"already exists"),"duplicate directory accepted");
    qb_check(h_has(qb_command("write /projects x","flexos:/ > "),"is a directory"),"file write replaced a directory");
    qb_check(h_has(qb_command("cat /missing","flexos:/ > "),"not found"),"missing path did not fail");
    qb_command("cd projects","flexos:/projects > ");qb_command("rm notes.txt","flexos:/projects > ");
    qb_check(h_has(qb_command("cat notes.txt","flexos:/projects > "),"not found"),"file removal failed");
    // More arena resets and allocation/free cycles than fit in the fixed heap
    // without reclamation. The real guest must survive, not just print a banner.
    let i=0;while i<300 {let mark=h_mark();qb_command("write reused.txt x","flexos:/projects > ");qb_command("rm reused.txt","flexos:/projects > ");h_reset(mark);i=i+1;}
    qb_check(h_has(qb_command("pwd","flexos:/projects > "),"/projects\n"),"kernel heap failed to reclaim allocations");
    qb_clear();h_trigger(qb_process,"exit\n");qb_until("FlexOS halted.");qb_check(h_status(qb_process)==-999,"QEMU exited instead of halting the guest");
    registers=qb_qmp("{\"execute\":\"human-monitor-command\",\"arguments\":{\"command-line\":\"info registers\"}}\n");
    qb_check(h_has(registers,"HLT=1"),h_cat("guest CPU did not halt: ",registers));
    h_close(qb_qmp_fd);qb_qmp_fd=-1;h_stop(qb_process);qb_process=0;
    qb_process=h_spawn(bq_args(qemu,image,firmware),0,0);qb_until("flexos:/ > ");
    qb_check(h_has(qb_command("cat projects/with spaces.txt","flexos:/ > "),"wrong number"),"fresh boot shell unavailable");
    qb_check(h_has(qb_command("cat '/projects/with spaces.txt'","flexos:/ > "),"not found"),"RAM files survived a fresh boot");
    h_stop(qb_process);qb_process=0;h_remove(temp);
    h_print(1,h_cat3("PASS: ",h_int(qb_checks)," bare-metal boot/compiler/UART/RAM filesystem checks in QEMU\n"));return 0;
}
