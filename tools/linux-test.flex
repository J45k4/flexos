import "linux-host.flex";
import "qmp.flex";
global lt_checks=0;
global lt_serial=0;
fn lt_check(ok,message) {qt_assert(ok,message);lt_checks=lt_checks+1;return 0;}
fn lt_open(qemu,app,firmware,temp) {
    lt_serial=lt_serial+1;let socket=h_join(temp,h_cat3("linux-",h_int(lt_serial),".sock"));let args=lh_args(qemu,app,firmware,temp);
    h_add(args,"-qmp");h_add(args,h_cat3("unix:",socket,",server=on,wait=off"));qt_process=h_spawn(args,0,0);qt_until("FlexOS Linux ABI ready");
    let address=h_zero(h_take(110),110);store8(address,1);h_copy(address+2,socket,h_len(socket));qt_fd=syscall(41,1,1|0x80000,0,0,0,0);
    qt_assert(qt_fd>=0 && syscall(42,qt_fd,address,h_len(socket)+3,0,0,0)==0,"QMP connect failed");syscall(72,qt_fd,4,2048,0,0,0);qt_assert(h_has(qt_read(),"QMP"),"QMP greeting missing");qt_execute("qmp_capabilities",0);return 0;
}
fn lt_done(status) {
    qt_until("FlexOS kernel resumed.");lt_check(h_has(h_out(qt_process),h_cat3("Linux process exited status=",h_int(status)," syscalls=")),"incorrect Linux exit status");
    // Serial readiness can reach the host before the final UART flush/HLT.
    let halted=0;let attempts=0;while !halted && attempts<40 {let regs=qt_execute("human-monitor-command","{\"command-line\":\"info registers\"}");halted=h_has(regs,"CPL=0") && h_has(regs,"HLT=1");if !halted {qt_pause(5);}attempts=attempts+1;}
    lt_check(halted,"kernel did not resume/halt after user process");qt_stop();return 0;
}
fn lt_compile(compiler,temp,name,source) {let path=h_join(temp,h_cat(name,".flex"));let elf=h_join(temp,h_cat(name,".elf"));h_save(path,source);h_compile(compiler,path,elf);return elf;}
