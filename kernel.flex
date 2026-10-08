import "core/kernel.flex";
import "platform/linux.flex";
fn main(argc,argv) {
    let root="build/root";let vm=0;let batch=0;let command=0;let i=1;
    while i<argc {let option=load64(argv+i*8);
        if fo_eq(option,"--help") {platform_output(1,"Usage: flexos [--root DIRECTORY] [--flex VM] [--batch] [--command TEXT]\nLinux-hosted kernel; default filesystem resource: build/root.\n");return 0;}
        if fo_eq(option,"--batch") {batch=1;i=i+1;}
        else {if i+1>=argc {fo_die("missing option value");}let value=load64(argv+(i+1)*8);if fo_eq(option,"--root") {root=value;}else if fo_eq(option,"--flex") {vm=value;}else if fo_eq(option,"--command") {command=value;}else {fo_die("unknown option");}i=i+2;}
    }
    platform_init(root,vm,argc,argv);fo_init();
    if command {platform_output(1,fo_command(command));fo_wait_all();let status=fo_status;fo_shutdown();return status;}
    return fo_loop(!batch && platform_tty());
}
