import "core/kernel.flex";
import "platform/baremetal.flex";
import "platform/hpet.flex";
import "platform/rtc.flex";
import "platform/linux-elf.flex";
import "platform/linux-devices.flex";
import "core/linux-files.flex";
import "core/linux-io.flex";
import "core/linux-syscalls.flex";
import "core/linux-i386.flex";
import "core/x11.flex";
import "core/linux-sockets.flex";
import "core/linux-shm.flex";
fn main() {
    bm_console_init();le_prepare();platform_init();fo_init();hp_init();rtc_init();lx_fds=platform_allocate(512);lf_init();ld_init();
    xp_setup(native_callback(lx_dispatch),native_callback(lx_fault),native_callback(li_dispatch));let entry=le_module();let stack=le_stack();
    platform_output(1,"FlexOS Linux ABI ready: static x86 ELF, user mode, syscall services\n");
    let enter=0x180300;if le_bits==32 {enter=0x180900;}ffi_call(enter,entry,stack,0,0,0,0);
    platform_output(1,"Linux process exited status=");platform_output(1,fo_int(lx_status));platform_output(1," syscalls=");platform_output(1,fo_int(lx_calls));platform_output(1,"\nFlexOS kernel resumed.\n");cpu_halt();return 0;
}
