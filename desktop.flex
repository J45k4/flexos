import "core/desktop.flex";
import "platform/baremetal.flex";
import "platform/pc-desktop.flex";
fn main() {
    platform_init();fo_init();platform_graphics_init();platform_input_init();desktop_init();desktop_loop();
    fo_shutdown();platform_output(1,"FlexOS desktop halted.\n");cpu_halt();return 0;
}
