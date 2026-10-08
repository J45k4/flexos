import "../core/memory.flex";
// Linux adapter: resource descriptors, host I/O, and restricted VM processes.
global p_root=-1;
global p_error=0;
global p_vm=0;
global p_env=0;
global p_cache=0;
global p_run_id=0;
fn platform_title() {return "FlexOS hosted kernel";}
fn platform_banner() {return "FlexOS · hosted Flexscript kernel\nType help to begin.\n";}
fn platform_resources() {return "filesystem / local read,write\nexecution flexscript-vm local restricted\n";}
fn platform_allocate(n) {return alloc(n);}
fn platform_free(p,n) {return syscall(11,p,n,0,0,0,0);}
fn platform_exit(status) {return syscall(60,status,0,0,0,0,0);}
fn platform_close(fd) {if fd>=0 {syscall(3,fd,0,0,0,0,0);}return 0;}
fn platform_output(fd,s) {let n=fo_len(s);let done=0;while done<n {let k=syscall(1,fd,s+done,n-done,0,0,0);if k>0 {done=done+k;}else if k!=-4 {return -1;}}return 0;}
fn platform_now() {let p=fo_take(16);if syscall(228,1,p,0,0,0,0)<0 {return 0;}return load64(p)*1000+load64(p+8)/1000000;}
fn platform_error() {return p_error;}
fn p_open(path,flags,mode) {
    let relative=path+1;if !load8(relative) {relative=".";}let how=fo_take(24);store64(how,flags);store64(how+8,mode);store64(how+16,10);
    let fd=syscall(437,p_root,relative,how,24,0,0);if fd<0 {p_error=fd;}return fd;
}
fn platform_directory(path) {let fd=p_open(path,0x90000,0);if fd<0 {return fd;}platform_close(fd);return 0;}
fn platform_read(path) {
    p_error=0;let fd=p_open(path,0x80800,0);if fd<0 {return 0;}let stat=fo_take(144);
    if syscall(5,fd,stat,0,0,0,0)<0 || (load64(stat+24)&61440)!=32768 {platform_close(fd);p_error=-22;return 0;}
    let b=fo_buffer();let scratch=fo_take(4096);let more=1;
    while more {
        let n=syscall(0,fd,scratch,4096,0,0,0);
        if n>0 {if load64(b+8)+n>65536 {platform_close(fd);p_error=-27;return 0;}let i=0;while i<n {if !load8(scratch+i) {platform_close(fd);p_error=-22;return 0;}i=i+1;}fo_append(b,scratch,n);}
        else if n!=-4 {if n<0 {platform_close(fd);p_error=n;return 0;}more=0;}
    }platform_close(fd);return fo_data(b);
}
fn platform_write(path,text) {
    // Open without truncation, verify a regular file, then truncate/write.
    let fd=p_open(path,0xa0841,384);if fd<0 {return fd;}let stat=fo_take(144);
    if syscall(5,fd,stat,0,0,0,0)<0 || (load64(stat+24)&61440)!=32768 {platform_close(fd);return -22;}
    let status=syscall(77,fd,0,0,0,0,0);if status<0 {platform_close(fd);return status;}let done=0;let n=fo_len(text);
    while done<n {let k=syscall(1,fd,text+done,n-done,0,0,0);if k>0 {done=done+k;}else if k!=-4 {platform_close(fd);return k;}}
    status=syscall(74,fd,0,0,0,0,0);platform_close(fd);return status;
}
fn p_parent(path) {
    let n=fo_len(path);if n<=1 {return -22;}let i=n-1;while i>0 && load8(path+i)!=47 {i=i-1;}let parent="/";if i {parent=fo_slice(path,i);}return p_open(parent,0x90000,0);
}
fn p_name(path) {let i=fo_len(path)-1;while i>=0 && load8(path+i)!=47 {i=i-1;}return path+i+1;}
fn platform_mkdir(path) {let fd=p_parent(path);if fd<0 {return fd;}let status=syscall(258,fd,p_name(path),448,0,0,0);platform_close(fd);return status;}
fn platform_remove(path) {let fd=p_parent(path);if fd<0 {return fd;}let status=syscall(263,fd,p_name(path),0,0,0,0);platform_close(fd);return status;}
fn platform_list(path) {
    let fd=p_open(path,0x90000,0);if fd<0 {return 0;}let bytes=fo_take(8192);let b=fo_buffer();let more=1;
    while more {let n=syscall(217,fd,bytes,8192,0,0,0);if n<0 {platform_close(fd);p_error=n;return 0;}if !n {more=0;}let i=0;
        while i<n {if n-i<20 {platform_close(fd);p_error=-22;return 0;}let size=load8(bytes+i+16)|(load8(bytes+i+17)<<8);if size<20 || size>n-i {platform_close(fd);p_error=-22;return 0;}
            let name=bytes+i+19;let length=0;while length<size-19 && load8(name+length) {length=length+1;}if length==size-19 {platform_close(fd);p_error=-22;return 0;}
            if !fo_eq(name,".") && !fo_eq(name,"..") {let k=0;while k<length {let c=load8(name+k);if c<32 || c==127 {fo_text(b,"?");}else {fo_append(b,name+k,1);}k=k+1;}if load8(bytes+i+18)==4 {fo_text(b,"/");}fo_text(b,"\n");}i=i+size;
        }
    }platform_close(fd);return fo_data(b);
}
fn platform_wait(apps,count,timeout,stdin) {
    let poll=fo_take(136);let fd=-1;if stdin {fd=0;}store64(poll,(fd&0xffffffff)|(1<<32));let i=0;
    while i<count {let app=apps+i*96;fd=-1;if load64(app+40)==1 {fd=load64(app+32);}store64(poll+(i+1)*8,(fd&0xffffffff)|(1<<32));i=i+1;}
    syscall(7,poll,count+1,timeout,0,0,0);return 0;
}
fn platform_input(p,n) {let poll=fo_take(8);store64(poll,1<<32);let ready=syscall(7,poll,1,0,0,0,0);if ready<=0 {return -11;}return syscall(0,0,p,n,0,0,0);}
fn platform_app_read(fd,p,n) {return syscall(0,fd,p,n,0,0,0);}
fn platform_app_output(p,n) {
    // Guest output is text. Do not let guests emit terminal control sequences.
    let b=fo_buffer();let i=0;while i<n {let c=load8(p+i);if c==10 || c==9 || c>=32 && c!=127 {fo_append(b,p+i,1);}else {fo_text(b,"?");}i=i+1;}platform_output(1,fo_data(b));return 0;
}
fn platform_status(pid) {let p=fo_take(8);let r=syscall(61,pid,p,1,0,0,0);if r==0 || r==-4 {return -999;}if r!=pid {return -1;}let status=load64(p)&0xffff;if status&127 {return -(status&127);}return (status>>8)&255;}
fn platform_stop(pid) {return syscall(62,pid,9,0,0,0,0);}
fn p_letter(c) {return (c>=65 && c<=90)||(c>=97 && c<=122)||c==95;}
fn p_self_contained(source) {
    let i=0;
    while load8(source+i) {
        let c=load8(source+i);
        if c==47 && load8(source+i+1)==47 {while load8(source+i) && load8(source+i)!=10 {i=i+1;}}
        else if c==34 {i=i+1;let more=1;while load8(source+i) && more {let d=load8(source+i);i=i+1;if d==92 && load8(source+i) {i=i+1;}else if d==34 {more=0;}}}
        else if p_letter(c) {let start=i;while p_letter(load8(source+i)) || (load8(source+i)>=48 && load8(source+i)<=57) {i=i+1;}if fo_eq(fo_slice(source+start,i-start),"import") {return 0;}}
        else {i=i+1;}
    }return 1;
}
fn p_arg(args,index,value) {store64(args+index*8,value);return index+1;}
fn platform_launch(app,source,arguments,count) {
    if !p_vm {return -2;}if !p_self_contained(source) {return -22;}p_run_id=p_run_id+1;
    let cache=fo_cat(fo_cat(p_cache,"/app-"),fo_cat(fo_int(p_run_id),".flex"));let fd=syscall(2,cache,0xa00c1,384,0,0,0);if fd<0 {return fd;}
    let size=fo_len(source);let wrote=0;while wrote<size {let n=syscall(1,fd,source+wrote,size-wrote,0,0,0);if n>0 {wrote=wrote+n;}else if n!=-4 {platform_close(fd);return n;}}platform_close(fd);
    let args=fo_take((count+14)*8);let at=0;at=p_arg(args,at,p_vm);at=p_arg(args,at,"run");at=p_arg(args,at,"--restricted");at=p_arg(args,at,"--no-url-imports");at=p_arg(args,at,"--memory=4m");at=p_arg(args,at,"--fuel=1000000");at=p_arg(args,at,"--timeout-ms=1000");if load64(app+16)&1 {at=p_arg(args,at,"--allow-read=.");}at=p_arg(args,at,cache);let i=0;while i<count {at=p_arg(args,at,load64(arguments+i*8));i=i+1;}store64(args+at*8,0);
    let pipe=fo_take(8);if syscall(293,pipe,0x80000,0,0,0,0)<0 {return -1;}let parent=syscall(39,0,0,0,0,0,0);let pid=syscall(57,0,0,0,0,0,0);
    if pid<0 {platform_close(load64(pipe)&0xffffffff);platform_close(load64(pipe)>>32);return pid;}
    if !pid {
        syscall(157,1,9,0,0,0,0);if syscall(110,0,0,0,0,0,0)!=parent {platform_exit(126);}syscall(109,0,0,0,0,0,0);
        let input=syscall(2,"/dev/null",0,0,0,0,0);if input<0 {platform_exit(126);}syscall(33,input,0,0,0,0,0);syscall(33,load64(pipe)>>32,1,0,0,0,0);syscall(33,load64(pipe)>>32,2,0,0,0,0);
        if syscall(81,p_root,0,0,0,0,0)<0 || syscall(436,3,0xffffffff,0,0,0,0)<0 {platform_exit(126);}
        let limit=fo_take(16);store64(limit,536870912);store64(limit+8,536870912);syscall(160,9,limit,0,0,0,0);
        store64(limit,2);store64(limit+8,2);syscall(160,0,limit,0,0,0,0);store64(limit,0);store64(limit+8,0);syscall(160,4,limit,0,0,0,0);
        syscall(59,p_vm,args,p_env,0,0,0);platform_exit(127);
    }
    platform_close(load64(pipe)>>32);fd=load64(pipe)&0xffffffff;syscall(72,fd,4,2048,0,0,0);store64(app+24,pid);store64(app+32,fd);return 0;
}
fn p_absolute(path) {if load8(path)==47 {return fo_keep(path);}let cwd=fo_take(4096);fo_assert(syscall(79,cwd,4096,0,0,0,0)>0,"getcwd failed");return fo_keep(fo_cat(fo_cat(cwd,"/"),path));}
fn platform_init(root,vm,argc,argv) {
    p_env=argv+(argc+1)*8;p_root=syscall(2,root,0x90000,0,0,0,0);fo_assert(p_root>=0,"cannot open filesystem root; create it first");
    let probe=p_open("/",0x90000,0);fo_assert(probe>=0,"Linux openat2 resource confinement is required");platform_close(probe);
    if vm {p_vm=p_absolute(vm);fo_assert(syscall(21,p_vm,1,0,0,0,0)==0,"VM executable is not accessible");}
    let random=fo_take(8);fo_assert(syscall(318,random,8,0,0,0,0)==8,"cache nonce failed");let hex="0123456789abcdef";let suffix=fo_take(17);let i=0;while i<8 {let c=load8(random+i);store8(suffix+i*2,load8(hex+(c>>4)));store8(suffix+i*2+1,load8(hex+(c&15)));i=i+1;}store8(suffix+16,0);
    p_cache=fo_keep(fo_cat("/tmp/flexos-",suffix));fo_assert(syscall(83,p_cache,448,0,0,0,0)==0,"cannot create private app cache");return 0;
}
fn platform_cleanup() {let i=1;while i<=p_run_id {let path=fo_cat(fo_cat(p_cache,"/app-"),fo_cat(fo_int(i),".flex"));syscall(87,path,0,0,0,0,0);i=i+1;}syscall(84,p_cache,0,0,0,0,0);platform_close(p_root);return 0;}
fn platform_tty() {let termios=fo_take(64);return syscall(16,0,0x5401,termios,0,0,0)==0;}
