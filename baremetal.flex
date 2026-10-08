import "core/kernel.flex";
import "platform/baremetal.flex";
fn main() {
    platform_init();fo_init();fo_loop(1);
    platform_output(1,"FlexOS halted.\n");cpu_halt();return 0;
}
