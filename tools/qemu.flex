import "host.flex";
fn bq_args(qemu,image,firmware) {
    return bq_args_display(qemu,image,firmware,"none");
}
fn bq_args_display(qemu,image,firmware,display) {
    let args=h_args(qemu,"-accel","tcg","-m","64M","-smp");h_add(args,"1");
    h_add(args,"-display");h_add(args,display);h_add(args,"-monitor");h_add(args,"none");
    h_add(args,"-serial");h_add(args,"stdio");h_add(args,"-nic");h_add(args,"none");
    h_add(args,"-no-reboot");h_add(args,"-no-shutdown");h_add(args,"-kernel");h_add(args,image);
    if firmware {h_add(args,"-L");h_add(args,firmware);}return args;
}
