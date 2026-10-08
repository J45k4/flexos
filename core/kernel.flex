import "memory.flex";
// The core owns paths, app capabilities, supervision policy, and the event loop.
global fo_cwd=0;
global fo_apps=0;
global fo_app_count=0;
global fo_status=0;
global fo_quit=0;
global fo_words=0;
global fo_word_count=0;
global fo_line_buffer=0;
global fo_line_size=0;
global fo_discard_line=0;
global fo_tty=0;
fn fo_error(s) {fo_status=1;return fo_cat(fo_cat("Error: ",s),"\n");}
fn fo_fs_error(code) {
    if code==-2 {return fo_error("path not found");}if code==-17 {return fo_error("path already exists");}if code==-20 {return fo_error("not a directory");}
    if code==-21 {return fo_error("path is a directory");}if code==-18 || code==-40 {return fo_error("path escapes the filesystem resource or is an unsafe link");}
    if code==-13 {return fo_error("permission denied");}if code==-27 {return fo_error("file limit is 64 KiB");}if code==-22 {return fo_error("unsupported file or invalid path");}
    return fo_error(fo_cat("filesystem failure ",fo_int(code)));
}
fn fo_path(input) {
    if !fo_len(input) || fo_len(input)>4095 {return 0;}let source=input;if load8(input)!=47 {source=fo_cat(fo_cat(fo_cwd,"/"),input);}
    let parts=fo_take(32768);let count=0;let i=0;
    while load8(source+i) {
        while load8(source+i)==47 {i=i+1;}let start=i;while load8(source+i) && load8(source+i)!=47 {i=i+1;}
        if i>start {let part=fo_slice(source+start,i-start);if fo_eq(part,"..") {if !count {return 0;}count=count-1;}else if !fo_eq(part,".") {if count>=1024 {return 0;}store64(parts+count*8,part);count=count+1;}}
    }
    let b=fo_buffer();fo_text(b,"/");i=0;while i<count {if i {fo_text(b,"/");}fo_text(b,load64(parts+i*8));i=i+1;}if load64(b+8)>4095 {return 0;}return fo_data(b);
}
fn fo_parse(line) {
    fo_words=fo_take(256);fo_word_count=0;let i=0;
    while load8(line+i) {
        while load8(line+i)==32 || load8(line+i)==9 {i=i+1;}if !load8(line+i) {return 1;}if fo_word_count==32 {return 0;}let b=fo_buffer();let quote=0;
        while load8(line+i) && (quote || (load8(line+i)!=32 && load8(line+i)!=9)) {
            let c=load8(line+i);i=i+1;
            if c==92 && quote!=39 {let next=load8(line+i);if !next {return 0;}i=i+1;if next==110 {next=10;}else if next==116 {next=9;}else if next==114 {next=13;}let one=fo_take(1);store8(one,next);fo_append(b,one,1);}
            else if !quote && (c==34 || c==39) {quote=c;}
            else if c==quote {quote=0;}else {fo_append(b,line+i-1,1);}
        }
        if quote {return 0;}store64(fo_words+fo_word_count*8,fo_data(b));fo_word_count=fo_word_count+1;
    }return 1;
}
fn fo_arg(index) {if index>=fo_word_count {return "";}return load64(fo_words+index*8);}
fn fo_name(s) {let n=fo_len(s);if !n || n>32 {return 0;}let i=0;while i<n {let c=load8(s+i);if !((c>=65 && c<=90)||(c>=97 && c<=122)||(c>=48 && c<=57)||c==45||c==95) {return 0;}i=i+1;}return 1;}
fn fo_find(name) {let i=0;while i<fo_app_count {let app=fo_apps+i*96;if fo_eq(load64(app),name) {return app;}i=i+1;}return 0;}
fn fo_running() {let count=0;let i=0;while i<fo_app_count {if load64(fo_apps+i*96+40)==1 {count=count+1;}i=i+1;}return count;}
fn fo_tick() {
    let i=0;let buffer=fo_take(4096);
    while i<fo_app_count {
        let app=fo_apps+i*96;
        if load64(app+40)==1 {
            if !load64(app+72) && platform_now()-load64(app+56)>5000 {platform_stop(load64(app+24));}
            let more=load64(app+32)>=0;
            while more {
                let n=platform_app_read(load64(app+32),buffer,4096);
                if n>0 {
                    store64(app+64,load64(app+64)+n);
                    store64(app+80,load8(buffer+n-1));
                    if load64(app+64)>1048576 {if !load64(app+72) {platform_stop(load64(app+24));}more=0;}
                    else {platform_output(1,fo_cat(fo_cat("[",load64(app)),"] "));platform_app_output(buffer,n);}
                }else {more=0;if n==0 {platform_close(load64(app+32));store64(app+32,-1);}}
            }
            if !load64(app+72) {let status=platform_status(load64(app+24));if status!=-999 {store64(app+48,status);store64(app+72,1);}}
            // Reap once, then drain the pipe to EOF before reporting completion.
            if load64(app+72) && load64(app+32)<0 {store64(app+40,2);if load64(app+64) && load64(app+80)!=10 {platform_output(1,"\n");}platform_output(1,fo_cat(fo_cat(fo_cat("Exited ",load64(app))," status="),fo_cat(fo_int(load64(app+48)),"\n")));}
        }i=i+1;
    }return 0;
}
fn fo_wait_all() {while fo_running() {fo_tick();platform_wait(fo_apps,fo_app_count,20,0);}return 0;}
fn fo_wait_app(app) {while load64(app+40)==1 {fo_tick();platform_wait(fo_apps,fo_app_count,20,0);}return 0;}
fn fo_command(line) {
    fo_status=0;if !fo_parse(line) {return fo_error("invalid quoting or too many arguments");}if !fo_word_count {return "";}let command=fo_arg(0);
    if fo_eq(command,"help") {return fo_cat(platform_title(),"\nhelp | resources | pwd | ls [PATH] | cd PATH | cat PATH\nwrite PATH TEXT | mkdir PATH | rm PATH\napp NAME SOURCE | apps | grant NAME fs.read | revoke NAME fs.read\nrun NAME [ARGS...] | ps | wait | stop NAME | exit\nPaths are inside the mounted resource. Apps start restricted.\n");}
    if fo_eq(command,"resources") {return platform_resources();}
    if fo_eq(command,"pwd") {return fo_cat(fo_cwd,"\n");}
    if fo_eq(command,"exit") {fo_quit=1;return "";}
    if fo_eq(command,"wait") {fo_wait_all();return "";}
    if fo_eq(command,"ls") || fo_eq(command,"cd") || fo_eq(command,"cat") || fo_eq(command,"write") || fo_eq(command,"mkdir") || fo_eq(command,"rm") {
        let arg=fo_arg(1);if fo_eq(command,"ls") && fo_word_count==1 {arg=".";}
        if fo_word_count>3 || (!fo_eq(command,"write") && fo_word_count>2) || (fo_eq(command,"write") && fo_word_count!=3) {return fo_error("wrong number of filesystem arguments");}
        let path=fo_path(arg);if !path {return fo_error("invalid path or path escapes the filesystem resource");}let result=0;
        if fo_eq(command,"ls") {let listing=platform_list(path);if !listing {return fo_fs_error(platform_error());}return listing;}
        if fo_eq(command,"cat") {let content=platform_read(path);if !content {return fo_fs_error(platform_error());}return fo_cat(content,"\n");}
        if fo_eq(command,"cd") {result=platform_directory(path);if !result {let old=fo_cwd;fo_cwd=fo_keep(path);platform_free(old,fo_len(old)+1);return "";}}
        else if fo_eq(command,"write") {result=platform_write(path,fo_arg(2));}
        else if fo_eq(command,"mkdir") {result=platform_mkdir(path);}
        else if fo_eq(command,"rm") {result=platform_remove(path);}
        if result<0 {return fo_fs_error(result);}return "";
    }
    if fo_eq(command,"app") {
        if fo_word_count!=3 || !fo_name(fo_arg(1)) {return fo_error("usage: app NAME SOURCE; names are 1..32 letters, digits, _ or -");}
        if fo_find(fo_arg(1)) {return fo_error("app name already registered");}if fo_app_count==16 {return fo_error("app registry limit is 16");}
        let path=fo_path(fo_arg(2));if !path {return fo_error("invalid source path");}let source=platform_read(path);if !source {return fo_fs_error(platform_error());}
        let app=fo_apps+fo_app_count*96;store64(app,fo_keep(fo_arg(1)));store64(app+8,fo_keep(path));store64(app+16,0);store64(app+24,0);store64(app+32,-1);store64(app+40,0);store64(app+48,0);fo_app_count=fo_app_count+1;
        return fo_cat(fo_cat("Registered ",fo_arg(1)),"\n");
    }
    if fo_eq(command,"apps") || fo_eq(command,"ps") {
        let b=fo_buffer();let i=0;while i<fo_app_count {let app=fo_apps+i*96;fo_text(b,load64(app));fo_text(b," ");
            if fo_eq(command,"apps") {fo_text(b,load64(app+8));fo_text(b," capabilities=");if load64(app+16)&1 {fo_text(b,"fs.read");}else {fo_text(b,"none");}}
            else {let state=load64(app+40);if state==1 {fo_text(b,"running");}else if state==2 {fo_text(b,fo_cat("exited status=",fo_int(load64(app+48))));}else {fo_text(b,"registered");}}
            fo_text(b,"\n");i=i+1;}return fo_data(b);
    }
    if fo_eq(command,"grant") || fo_eq(command,"revoke") {
        if fo_word_count!=3 || !fo_eq(fo_arg(2),"fs.read") {return fo_error("supported app capability: fs.read");}let app=fo_find(fo_arg(1));if !app {return fo_error("unknown app");}
        // Revocation stops the running invocation before changing its grant.
        if fo_eq(command,"revoke") {if load64(app+40)==1 && !load64(app+72) {platform_stop(load64(app+24));}store64(app+16,0);fo_wait_app(app);}else {store64(app+16,1);}
        return fo_cat(fo_cat("Capabilities updated for ",fo_arg(1)),"\n");
    }
    if fo_eq(command,"run") {
        if fo_word_count<2 {return fo_error("usage: run NAME [ARGS...]");}let app=fo_find(fo_arg(1));if !app {return fo_error("unknown app");}if load64(app+40)==1 {return fo_error("app is already running");}
        let source=platform_read(load64(app+8));if !source {return fo_fs_error(platform_error());}
        let result=platform_launch(app,source,fo_words+16,fo_word_count-2);
        if result<0 {if result==-38 {return fo_error("execution provider is unavailable on this target");}if result==-22 {return fo_error("apps must be self-contained; source imports are not allowed yet");}return fo_error(fo_cat("cannot launch app: ",fo_int(result)));}
        store64(app+40,1);store64(app+56,platform_now());store64(app+64,0);store64(app+72,0);store64(app+80,0);return fo_cat(fo_cat("Started ",load64(app)),"\n");
    }
    if fo_eq(command,"stop") {if fo_word_count!=2 {return fo_error("usage: stop NAME");}let app=fo_find(fo_arg(1));if !app {return fo_error("unknown app");}if load64(app+40)==1 && !load64(app+72) {platform_stop(load64(app+24));}return "";}
    return fo_error(fo_cat("unknown command: ",command));
}
fn fo_init() {fo_cwd=fo_keep("/");fo_apps=platform_allocate(1536);fo_assert(fo_apps>0,"app registry allocation failed");fo_line_buffer=platform_allocate(4096);fo_assert(fo_line_buffer>0,"line allocation failed");return 0;}
fn fo_prompt() {if fo_tty {platform_output(1,fo_cat(fo_cat("flexos:",fo_cwd)," > "));}return 0;}
fn fo_shutdown() {let i=0;while i<fo_app_count {let app=fo_apps+i*96;if load64(app+40)==1 && !load64(app+72) {platform_stop(load64(app+24));}i=i+1;}fo_wait_all();platform_cleanup();return 0;}
// Shared console line discipline for serial shells and the desktop console.
fn fo_feed(input,n) {
    if n==0 {if fo_line_size && !fo_discard_line {store8(fo_line_buffer+fo_line_size,0);platform_output(1,fo_command(fo_line_buffer));}fo_quit=1;return 1;}
    let i=0;let lines=0;while i<n && !fo_quit {let c=load8(input+i);
        if c==10 {if fo_discard_line {platform_output(1,fo_error("command exceeds 4095 bytes or contains a zero byte"));}else {store8(fo_line_buffer+fo_line_size,0);platform_output(1,fo_command(fo_line_buffer));}fo_line_size=0;fo_discard_line=0;fo_prompt();lines=lines+1;}
        else if c!=13 {if !c || fo_line_size==4095 {fo_discard_line=1;}else if !fo_discard_line {store8(fo_line_buffer+fo_line_size,c);fo_line_size=fo_line_size+1;}}i=i+1;
    }return lines;
}
fn fo_loop(interactive) {
    fo_tty=interactive;let mark=fo_mark();if fo_tty {platform_output(1,platform_banner());fo_prompt();}fo_reset(mark);
    // Allocate input independently so command-arena resets cannot invalidate it.
    let input=platform_allocate(4096);fo_assert(input>0,"input allocation failed");
    while !fo_quit {
        fo_tick();platform_wait(fo_apps,fo_app_count,50,1);let n=platform_input(input,4096);
        if n==0 {if fo_line_size && !fo_discard_line {store8(fo_line_buffer+fo_line_size,0);platform_output(1,fo_command(fo_line_buffer));}fo_quit=1;}
        else if n>0 {fo_feed(input,n);}else if n!=-11 && n!=-4 {fo_quit=1;}
        fo_reset(mark);
    }
    fo_shutdown();return 0;
}
