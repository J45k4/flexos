import "host.flex";
fn doom_args(qemu,wad,firmware,display,temp) {
    let args=h_args(qemu,"-accel","tcg","-m","128M","-smp");h_add(args,"1");h_add(args,"-vga");h_add(args,"std");
    h_add(args,"-name");h_add(args,"FlexOS Doom");h_add(args,"-display");h_add(args,display);h_add(args,"-monitor");h_add(args,"none");
    h_add(args,"-serial");h_add(args,"stdio");h_add(args,"-nic");h_add(args,"none");h_add(args,"-no-reboot");h_add(args,"-no-shutdown");
    h_add(args,"-kernel");h_add(args,h_real("build/flexos-doom.bin"));h_add(args,"-initrd");
    // Give QEMU safe local names: Multiboot's initrd list uses comma and spaces
    // as separators, even when ordinary argv quoting is correct.
    h_add(args,h_cat3(h_join(temp,"game.elf"),",",h_join(temp,"game.wad")));
    if firmware {h_add(args,"-L");h_add(args,firmware);}return args;
}
fn doom_stage(temp,wad) {
    let p=h_read("build/doom/doom.elf");h_save_bytes(h_join(temp,"game.elf"),p,h_file_size,384);
    p=h_read(wad);h_assert(h_file_size>=12 && h_file_size<=50331648 && (load64(p)&0xffffffff)==0x44415749,"Expected an IWAD of at most 48 MiB");h_save_bytes(h_join(temp,"game.wad"),p,h_file_size,384);return 0;
}
