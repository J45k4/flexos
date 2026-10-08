import "../tools/pty.flex";
global ft_checks=0;
global ft_binary=0;
global ft_vm=0;
global ft_root=0;
fn ft_check(ok,message) {h_assert(ok,message);ft_checks=ft_checks+1;return 0;}
fn ft_run(commands) {let args=h_args(ft_binary,"--root",ft_root,"--flex",ft_vm,"--batch");let p=h_wait(h_spawn(args,commands,0));ft_check(h_status(p)==0,h_cat("kernel failed: ",h_err(p)));ft_check(h_equal(h_err(p),""),h_err(p));return h_out(p);}
fn ft_command(command,status) {let args=h_args(ft_binary,"--root",ft_root,"--command",command,0);return h_check(h_run(args),status,0);}
fn ft_fixture(path,source) {h_save(h_join(ft_root,path),source);return 0;}
fn ft_guest(name,path,arguments,needle) {
    let script=h_cat3("app ",name,h_cat3(" ",path,h_cat3("\nrun ",name,h_cat3(" ",arguments,"\nwait\nps\nexit\n"))));
    let output=ft_run(script);ft_check(h_has(output,needle),h_cat("missing guest result: ",output));return output;
}
fn main(argc,argv) {
    h_environment(argc,argv);h_assert(argc==3,"Usage: test-flexos NATIVE-COMPILER VM-COMPILER");let compiler=h_real(load64(argv+8));ft_vm=h_real(load64(argv+16));let temp=h_temp();ft_binary=h_join(temp,"flexos");ft_root=h_join(temp,"root");h_mkdir(ft_root);h_compile(compiler,"kernel.flex",ft_binary);
    let output=h_out(ft_command("help",0));ft_check(h_has(output,"hosted kernel") && h_has(output,"run NAME"),"shell help missing");
    ft_check(h_equal(h_out(ft_command("pwd",0)),"/\n"),"root path incorrect");ft_check(h_has(h_out(ft_command("resources",0)),"filesystem / local"),"filesystem resource missing");
    output=ft_run("mkdir projects\ncd projects\npwd\nwrite notes.txt \"Hello from FlexOS\"\ncat notes.txt\nls\ncd ..\npwd\nexit\n");
    ft_check(h_has(output,"/projects/\n")==0 && h_has(output,"/projects\n"),"cwd normalization incorrect");ft_check(h_has(output,"Hello from FlexOS\n") && h_has(output,"notes.txt\n"),"filesystem commands failed");ft_check(h_equal(h_read(h_join(ft_root,"projects/notes.txt")),"Hello from FlexOS"),"file content did not persist");
    output=ft_run("write '/file with spaces.txt' 'Unicode 你好 🌱'\ncat '/file with spaces.txt'\nwrite escaped.txt \"first\\nsecond\"\ncat escaped.txt\nexit\n");ft_check(h_has(output,"Unicode 你好 🌱") && h_has(output,"first\nsecond"),"quoting, UTF-8 or escapes failed");
    ft_check(h_has(h_out(ft_command("cat missing",1)),"path not found"),"missing path did not fail");ft_check(h_has(h_out(ft_command("cd /file with spaces.txt",1)),"wrong number"),"extra path arguments accepted");
    ft_check(h_has(h_out(ft_command("cd /projects/notes.txt",1)),"not a directory"),"cd to regular file accepted");ft_check(h_has(h_out(ft_command("cd ..",1)),"escapes"),"parent traversal accepted");ft_check(h_has(h_out(ft_command("cat /../../etc/passwd",1)),"escapes"),"absolute traversal accepted");
    output=ft_run("cd /projects\ncd /missing\npwd\nexit\n");ft_check(h_has(output,"Error: path not found\n/projects\n"),"failed cd changed cwd");
    ft_check(h_has(h_out(ft_command("write notes.txt",1)),"wrong number"),"missing write value accepted");ft_check(h_has(h_out(ft_command("write bad.txt \"unclosed",1)),"invalid quoting"),"unclosed quote accepted");
    ft_check(h_has(h_out(ft_command("unknown",1)),"unknown command"),"unknown command accepted");
    let outside=h_join(temp,"outside.txt");h_save(outside,"PRIVATE OUTSIDE RESOURCE");h_assert(syscall(88,outside,h_join(ft_root,"escape"),0,0,0,0)==0,"escape symlink setup failed");
    ft_check(h_has(h_out(ft_command("cat escape",1)),"escapes"),"symlink read escaped root");ft_check(h_has(h_out(ft_command("write escape changed",1)),"unsafe link"),"symlink write escaped root");ft_check(h_equal(h_read(outside),"PRIVATE OUTSIDE RESOURCE"),"outside file changed");
    h_assert(syscall(88,temp,h_join(ft_root,"escape-dir"),0,0,0,0)==0,"directory symlink setup failed");ft_command("mkdir escape-dir/injected",1);ft_check(!h_exists(h_join(temp,"injected")),"mkdir escaped root");ft_command("rm escape-dir/outside.txt",1);ft_check(h_exists(outside),"unlink escaped root");
    h_assert(syscall(88,"projects/notes.txt",h_join(ft_root,"safe-link"),0,0,0,0)==0,"inside symlink setup failed");ft_check(h_has(h_out(ft_command("cat safe-link",0)),"Hello from FlexOS"),"safe internal symlink denied");
    let large=h_take(65537);let i=0;while i<65537 {store8(large+i,120);i=i+1;}h_save_bytes(h_join(ft_root,"large.txt"),large,65537,384);ft_check(h_has(h_out(ft_command("cat large.txt",1)),"64 KiB"),"file limit not enforced");
    h_save_bytes(h_join(ft_root,"binary.dat"),"a\0b",3,384);ft_check(h_has(h_out(ft_command("cat binary.dat",1)),"unsupported"),"zero-byte text file accepted");
    ft_command("rm /projects/notes.txt",0);ft_check(!h_exists(h_join(ft_root,"projects/notes.txt")),"rm failed");ft_command("mkdir /projects",1);
    ft_fixture("hello.flex",h_read("apps/hello.flex"));ft_fixture("read.flex",h_read("apps/read.flex"));ft_fixture("secret.txt","Scoped resource secret");
    output=ft_guest("hello","/hello.flex","","Hello from a FlexOS app!\n");ft_check(h_has(output,"hello exited status=0"),"hello app status missing");
    output=ft_guest("reader","/read.flex","secret.txt","host capability denied");ft_check(h_has(output,"reader exited status=70"),"read without capability did not trap");
    output=ft_run("app reader /read.flex\ngrant reader fs.read\nrun reader secret.txt\nwait\napps\nrevoke reader fs.read\nrun reader secret.txt\nwait\napps\nexit\n");
    ft_check(h_has(output,"Scoped resource secret") && h_has(output,"capabilities=fs.read") && h_has(output,"capabilities=none"),"grant or revoke failed");ft_check(h_has(output,"Exited reader status=70"),"revoked capability still usable");
    output=ft_run("app reader /read.flex\ngrant reader fs.read\nrun reader ../outside.txt\nwait\nexit\n");ft_check(!h_has(output,"PRIVATE OUTSIDE RESOURCE") && h_has(output,"Exited reader status=3"),h_cat("guest read escaped resource: ",output));
    ft_fixture("write.flex","fn main(){return syscall(2,\"guest-created.txt\",577,384,0,0,0);}");ft_guest("writer","/write.flex","","host capability denied");ft_check(!h_exists(h_join(ft_root,"guest-created.txt")),"guest write reached host filesystem");
    ft_fixture("network.flex","fn main(){return syscall(41,2,1,0,0,0,0);}");ft_guest("network","/network.flex","","host capability denied");
    ft_fixture("ffi.flex","fn main(){return ffi_open(\"libc.so.6\");}");ft_guest("ffi","/ffi.flex","","host capability denied (raw FFI)");
    ft_fixture("loop.flex","fn main(){while 1{}return 0;}");output=ft_guest("loop","/loop.flex","","instruction budget exhausted");ft_check(h_has(output,"loop exited status=70"),"infinite loop did not stop");
    ft_fixture("imports.flex","import \"../outside.flex\"; fn main(){return 0;}");output=ft_run("app imports imports.flex\nrun imports\nps\nexit\n");ft_check(h_has(output,"source imports are not allowed") && !h_has(output,"Started imports"),"source imports escaped compile boundary");
    ft_fixture("strings.flex","// import outside\nfn main(){syscall(1,1,\"import in a string\",18,0,0,0);return 0;}");ft_guest("strings","strings.flex","","import in a string");
    ft_fixture("args.flex","fn length(s){let n=0;while load8(s+n){n=n+1;}return n;}fn main(argc,argv){let s=load64(argv+8);syscall(1,1,s,length(s),0,0,0);return argc;}");output=ft_guest("args","args.flex","\"an argument with spaces\"","an argument with spaces");ft_check(h_has(output,"args exited status=2"),"guest argv incorrect");
    ft_fixture("bad.flex","fn main(){return missing;}");ft_guest("bad","bad.flex","","undefined variable");
    output=ft_run("app loop loop.flex\nrun loop\nstop loop\nwait\nps\nexit\n");ft_check(h_has(output,"loop exited status=") && !h_has(output,"loop running"),"stopped app was not reaped");
    output=ft_run("app loop loop.flex\napp hello hello.flex\ngrant loop fs.read\nrun loop\nrun hello\nrevoke loop fs.read\nwait\napps\nexit\n");ft_check(h_has(output,"Hello from a FlexOS app!") && h_has(output,"loop /loop.flex capabilities=none"),"revocation stopped unrelated app or retained capability");
    output=ft_run("app loop loop.flex\nrun loop\nexit\n");ft_check(h_has(output,"Exited loop status="),"shutdown did not reap running app");
    output=ft_run("app loop loop.flex\nrun loop\n");ft_check(h_has(output,"Exited loop status="),"EOF did not reap running app");
    ft_fixture("burst.flex","fn main(){let p=alloc(4096);let i=0;while i<4096{store8(p+i,120);i=i+1;}i=0;while i<64{syscall(1,1,p,4096,0,0,0);i=i+1;}syscall(1,1,\"END-OF-OUTPUT\\n\",14,0,0,0);return 0;}");ft_guest("burst","burst.flex","","END-OF-OUTPUT\n");
    output=ft_run("app hello hello.flex\napp hello hello.flex\nrun missing\ngrant hello network\napp 'bad name' hello.flex\nexit\n");ft_check(h_has(output,"already registered") && h_has(output,"unknown app") && h_has(output,"supported app capability") && h_has(output,"usage: app"),"registry errors not handled");
    let many=h_buffer();i=0;while i<17 {h_text(many,h_cat3("app a",h_int(i)," hello.flex\n"));i=i+1;}h_text(many,"exit\n");ft_check(h_has(ft_run(h_data(many)),"registry limit is 16"),"app registry unbounded");
    let commands=h_buffer();i=0;while i<4096 {h_text(commands,"x");i=i+1;}h_text(commands,"\npwd\nexit\n");output=ft_run(h_data(commands));ft_check(h_has(output,"command exceeds 4095") && h_has(output,"/\n"),"long line did not recover");
    let tty=hp_open_args(h_args(ft_binary,"--root",ft_root,0,0,0));h_until(tty,"flexos:/ > ",3000);ft_check(h_has(h_out(tty),"hosted Flexscript kernel"),"interactive banner missing");
    hp_send(tty,"cd projects\npwd\n");ft_check(h_has(h_out(tty),"flexos:/projects > ") && h_has(h_out(tty),"/projects\r\n"),"interactive cwd/prompt failed");hp_finish(tty,"exit\n",0);ft_check(h_status(tty)==0,"interactive exit failed");
    h_print(1,h_cat3("PASS: ",h_int(ft_checks)," native FlexOS filesystem/shell/capability/VM checks\n"));return 0;
}
