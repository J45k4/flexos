import "core/kernel.flex";
import "core/graphics.flex";
import "platform/baremetal.flex";
import "platform/pc-desktop.flex";
import "platform/boot-modules.flex";
import "platform/hpet.flex";
import "core/doom.flex";
fn main() {
    // Set up UART before validating binary modules. Copy modules before heap use.
    port_out8(0x3f9,0);port_out8(0x3fb,128);port_out8(0x3f8,1);port_out8(0x3f9,0);port_out8(0x3fb,3);port_out8(0x3fa,199);port_out8(0x3fc,11);
    doom_entry=boot_modules();platform_init();fo_init();platform_graphics_init();platform_input_init();hp_init();g_init();doom_services_init();
    g_rect(0,0,1024,768,0x101b2c);g_text(32,28,"FlexOS / DOOM",3,0x6ee0c9);
    g_text(32,718,"Arrows: move/turn  WASD: move/strafe  Ctrl: fire  Space: use",2,0xd7e9f1);g_text(32,744,"Shift: run  Esc: menu  F12: halt  Storage: RAM only",2,0x91a9bd);
    platform_display_present(g_back,0,0,1024,768);platform_output(1,"Loading native Doom payload and boot IWAD...\n");
    ffi_call(doom_entry,0,native_callback(doom_host),boot_wad,boot_wad_size,0,0);
    // The first painted frame can still be inside Doom's blocking opening wipe.
    // Announce readiness only after initialization and that transition finish.
    platform_output(1,"FlexOS Doom ready: native original engine, Linux absent\n");
    while !doom_quit {doom_poll();ffi_call(doom_entry,1,0,0,0,0,0);doom_serial_poll();}
    platform_output(1,"FlexOS Doom halted.\n");cpu_halt();return 0;
}
