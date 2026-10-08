import "kernel.flex";
import "graphics.flex";
import "desktop-render.flex";
// Portable desktop state and event loop. Built-ins share the filesystem service;
// the PC adapter only delivers input events and copies framebuffer rectangles.
// Window record: x,y,w,h,open,minimized,maximized,saved x/y/w/h (128 bytes).
global d_windows=0;
global d_order=0;
global d_count=0;
global d_focus=0;
global d_dirty=1;
global d_cursor_dirty=1;
global d_mouse_x=512;
global d_mouse_y=384;
global d_buttons=0;
global d_menu=0;
global d_power=0;
global d_quit=0;
global d_drag=0;
global d_drag_kind=0;
global d_drag_x=0;
global d_drag_y=0;
global d_drag_wx=0;
global d_drag_wy=0;
global d_drag_w=0;
global d_drag_h=0;
global d_note=0;
global d_note_len=0;
global d_note_cursor=0;
global d_note_path=0;
global d_note_dirty=0;
global d_note_select=0;
global d_note_scroll=0;
global d_note_status=0;
global d_term=0;
global d_term_len=0;
global d_input=0;
global d_input_len=0;
global d_input_cursor=0;
global d_history=0;
global d_files_path=0;
global d_file_names=0;
global d_file_rows=0;
global d_file_count=0;
global d_file_selected=0;
global d_file_scroll=0;
global d_files_status=0;
global d_new_counter=0;
fn d_name(kind) {if kind==1 {return "Files";}if kind==2 {return "Notes";}if kind==3 {return "Terminal";}return "About FlexOS";}
fn d_window(kind) {return d_windows+(kind-1)*128;}
fn d_inside(x,y,w,h) {return d_mouse_x>=x && d_mouse_y>=y && d_mouse_x<x+w && d_mouse_y<y+h;}
fn d_visible(kind) {let win=d_window(kind);return load64(win+32) && !load64(win+40);}
fn d_min_width(kind) {if kind==1 || kind==4 {return 540;}return 440;}
fn d_front(kind) {
    let i=0;while i<d_count && load64(d_order+i*8)!=kind {i=i+1;}
    if i<d_count {while i+1<d_count {store64(d_order+i*8,load64(d_order+(i+1)*8));i=i+1;}d_count=d_count-1;}
    store64(d_order+d_count*8,kind);d_count=d_count+1;d_focus=kind;d_dirty=1;return 0;
}
fn d_focus_next() {d_focus=0;let i=d_count;while i>0 {i=i-1;let kind=load64(d_order+i*8);if d_visible(kind) {d_focus=kind;return 0;}}return 0;}
fn d_open(kind) {
    let win=d_window(kind);store64(win+32,1);store64(win+40,0);d_front(kind);d_menu=0;d_power=0;
    if kind==1 {d_files_refresh();}platform_output(1,fo_cat(fo_cat("Desktop opened ",d_name(kind)),"\n"));return 0;
}
fn d_close(kind) {store64(d_window(kind)+32,0);d_focus_next();d_dirty=1;platform_output(1,fo_cat(fo_cat("Desktop closed ",d_name(kind)),"\n"));return 0;}
fn d_minimize(kind) {store64(d_window(kind)+40,1);d_focus_next();d_dirty=1;platform_output(1,fo_cat(fo_cat("Desktop minimized ",d_name(kind)),"\n"));return 0;}
fn d_maximize(kind) {
    let win=d_window(kind);if load64(win+48) {let i=0;while i<4 {store64(win+i*8,load64(win+56+i*8));i=i+1;}store64(win+48,0);}
    else {let i=0;while i<4 {store64(win+56+i*8,load64(win+i*8));i=i+1;}store64(win,16);store64(win+8,48);store64(win+16,g_width-32);store64(win+24,g_height-144);store64(win+48,1);}
    d_dirty=1;platform_output(1,fo_cat(fo_cat("Desktop toggled maximize ",d_name(kind)),"\n"));return 0;
}
fn d_cycle() {let i=d_count-1;while i>=0 {let kind=load64(d_order+i*8);if kind!=d_focus && d_visible(kind) {d_front(kind);return 0;}i=i-1;}return 0;}
fn d_note_message(text) {let old=d_note_status;d_note_status=fo_keep(text);if old {platform_free(old,fo_len(old)+1);}return 0;}
fn d_files_message(text) {let old=d_files_status;d_files_status=fo_keep(text);if old {platform_free(old,fo_len(old)+1);}return 0;}
fn d_join(path,name) {if fo_eq(path,"/") {return fo_cat(path,name);}return fo_cat(fo_cat(path,"/"),name);}
fn d_parent(path) {let i=0;let last=0;while load8(path+i) {if load8(path+i)==47 {last=i;}i=i+1;}if !last {return "/";}return fo_slice(path,last);}
fn d_basename(path) {let i=0;let last=0;while load8(path+i) {if load8(path+i)==47 {last=i+1;}i=i+1;}return path+last;}
fn d_files_refresh() {
    let text=platform_list(d_files_path);d_file_count=0;
    if !text {d_files_message("Cannot read this directory.");return 0;}
    let n=fo_len(text);if n>=8192 {d_files_message("Directory listing is too large.");return 0;}fo_copy(d_file_names,text,n+1);
    let at=0;let i=0;while i<n && d_file_count<64 {if load8(d_file_names+i)==10 {
        store8(d_file_names+i,0);let directory=i>at && load8(d_file_names+i-1)==47;if directory {store8(d_file_names+i-1,0);}
        let row=d_file_rows+d_file_count*16;store64(row,d_file_names+at);store64(row+8,directory);d_file_count=d_file_count+1;at=i+1;
    }i=i+1;}d_file_selected=g_min(d_file_selected,g_max(0,d_file_count-1));d_file_scroll=0;d_files_message("Click a folder or text file to open it.");d_dirty=1;return 0;
}
fn d_set_directory(path) {fo_copy(d_files_path,path,fo_len(path)+1);d_file_selected=0;d_files_refresh();return 0;}
fn d_note_open(path) {
    if d_note_dirty && !fo_eq(path,d_note_path) {d_files_message("Save your note before opening another file.");d_open(2);return 0;}
    if d_note_dirty && fo_eq(path,d_note_path) {d_open(2);return 0;}
    let text=platform_read(path);if !text {d_files_message("This file could not be opened.");return 0;}
    let n=fo_len(text);if n>=8192 {d_files_message("Notes can open files up to 8 KiB.");return 0;}
    let old=d_note_path;d_note_path=fo_keep(path);platform_free(old,fo_len(old)+1);fo_copy(d_note,text,n+1);d_note_len=n;d_note_cursor=n;d_note_scroll=0;d_note_select=0;d_note_dirty=0;
    d_note_message("Opened from RAM storage.");d_open(2);return 0;
}
fn d_files_open(index) {
    if index<0 || index>=d_file_count {return 0;}let row=d_file_rows+index*16;let path=d_join(d_files_path,load64(row));
    if load64(row+8) {d_set_directory(path);}else {d_note_open(path);}return 0;
}
fn d_new_note() {
    if d_note_dirty {d_files_message("Save your current note first.");d_open(2);return 0;}
    let path=0;let found=0;while !found {d_new_counter=d_new_counter+1;path=d_join(d_files_path,fo_cat(fo_cat("Note ",fo_int(d_new_counter)),".txt"));found=!platform_read(path) && platform_directory(path)<0;}
    if platform_write(path,"")<0 {d_files_message("Could not create a note.");return 0;}d_note_open(path);d_files_refresh();return 0;
}
fn d_note_save() {let status=platform_write(d_note_path,d_note);if status<0 {d_note_message("Could not save this note.");}
    else {d_note_dirty=0;d_note_message("Saved to RAM. Files disappear on shutdown.");platform_output(1,fo_cat(fo_cat("Desktop saved ",d_note_path),"\n"));}
    d_dirty=1;return 0;
}
fn d_note_change() {if !d_note_dirty {d_note_message("Unsaved changes");}d_note_dirty=1;d_dirty=1;return 0;}
fn d_note_clear_selection() {if d_note_select {d_note_len=0;d_note_cursor=0;store8(d_note,0);d_note_select=0;}return 0;}
fn d_note_insert(c) {d_note_clear_selection();if d_note_len>=8191 {d_note_message("Note is full (8 KiB limit).");return 0;}
    let i=d_note_len;while i>=d_note_cursor {store8(d_note+i+1,load8(d_note+i));i=i-1;}store8(d_note+d_note_cursor,c);d_note_cursor=d_note_cursor+1;d_note_len=d_note_len+1;d_note_change();return 0;
}
fn d_note_delete(backward) {
    if d_note_select {d_note_clear_selection();d_note_change();return 0;}
    if backward {if !d_note_cursor {return 0;}d_note_cursor=d_note_cursor-1;}else if d_note_cursor>=d_note_len {return 0;}
    let i=d_note_cursor;while i<d_note_len {store8(d_note+i,load8(d_note+i+1));i=i+1;}d_note_len=d_note_len-1;d_note_change();return 0;
}
fn d_note_columns() {return (load64(d_window(2)+16)-60)/12;}
fn d_note_location(cursor) {let row=0;let col=0;let i=0;let cols=d_note_columns();while i<cursor {if load8(d_note+i)==10 {row=row+1;col=0;}else {col=col+1;if col>=cols {row=row+1;col=0;}}i=i+1;}return row*4096+col;}
fn d_note_seek(wanted_row,wanted_col) {
    let row=0;let col=0;let i=0;let candidate=0;let cols=d_note_columns();wanted_row=g_max(0,wanted_row);
    while i<=d_note_len {if row==wanted_row {candidate=i;if col>=wanted_col {return i;}}if row>wanted_row {return candidate;}
        if i==d_note_len {return i;}if load8(d_note+i)==10 {row=row+1;col=0;}else {col=col+1;if col>=cols {row=row+1;col=0;}}i=i+1;
    }return d_note_len;
}
fn d_term_append(text) {
    let n=fo_len(text);if n>=16384 {text=text+n-16383;n=16383;d_term_len=0;}
    if d_term_len+n>=16384 {let drop=d_term_len+n-16383;let i=0;while i<d_term_len-drop {store8(d_term+i,load8(d_term+i+drop));i=i+1;}d_term_len=d_term_len-drop;}
    fo_copy(d_term+d_term_len,text,n);d_term_len=d_term_len+n;store8(d_term+d_term_len,0);d_dirty=1;return 0;
}
fn d_term_exec() {
    d_term_append(fo_cat(fo_cat(fo_cat("flexos:",fo_cwd)," > "),fo_cat(d_input,"\n")));fo_copy(d_history,d_input,d_input_len+1);
    if fo_eq(d_input,"clear") {d_term_len=0;store8(d_term,0);}else if fo_eq(d_input,"exit") {d_close(3);}
    else if fo_eq(d_input,"shutdown") {d_quit=1;}else {d_term_append(fo_command(d_input));}
    d_input_len=0;d_input_cursor=0;store8(d_input,0);d_dirty=1;return 0;
}
fn d_input_insert(c) {if d_input_len>=511 {return 0;}let i=d_input_len;while i>=d_input_cursor {store8(d_input+i+1,load8(d_input+i));i=i-1;}store8(d_input+d_input_cursor,c);d_input_len=d_input_len+1;d_input_cursor=d_input_cursor+1;return 0;}
fn d_input_delete(backward) {if backward {if !d_input_cursor {return 0;}d_input_cursor=d_input_cursor-1;}else if d_input_cursor>=d_input_len {return 0;}let i=d_input_cursor;while i<d_input_len {store8(d_input+i,load8(d_input+i+1));i=i+1;}d_input_len=d_input_len-1;return 0;}
fn d_keyboard(key,mods) {
    d_dirty=1;
    if key==303 && (mods&4) {if d_focus {d_close(d_focus);}return 0;}
    if key==9 && (mods&4) {d_cycle();return 0;}
    if (mods&6)==6 && (key==116 || key==84) {d_open(3);return 0;}
    if key==300 {d_menu=!d_menu;d_power=0;return 0;}if key==301 {d_open(2);return 0;}if key==302 {d_open(1);return 0;}if key==303 {d_open(3);return 0;}
    if key==27 {d_menu=0;d_power=0;d_note_select=0;return 0;}
    if d_menu {if key>=49 && key<=52 {d_open(key-48);}return 0;}
    if d_focus==2 {
        if mods&2 {if key==115 || key==83 {d_note_save();}else if key==97 || key==65 {d_note_select=1;}return 0;}
        if key==8 {d_note_delete(1);}else if key==262 {d_note_delete(0);}else if key==256 {d_note_cursor=g_max(0,d_note_cursor-1);d_note_select=0;}
        else if key==257 {d_note_cursor=g_min(d_note_len,d_note_cursor+1);d_note_select=0;}
        else if key>=258 && key<=261 {let location=d_note_location(d_note_cursor);let row=location/4096;let col=location%4096;
            if key==258 {row=row-1;}if key==259 {row=row+1;}if key==260 {col=0;}if key==261 {col=d_note_columns();}d_note_cursor=d_note_seek(row,col);d_note_select=0;
        }else if key==9 {let i=0;while i<4 {d_note_insert(32);i=i+1;}}
        else if key==10 || key>=32 && key<127 {d_note_insert(key);}
    }else if d_focus==3 {
        if mods&2 {if key==108 || key==76 {d_term_len=0;store8(d_term,0);}else if key==97 || key==65 {d_input_cursor=0;}else if key==101 || key==69 {d_input_cursor=d_input_len;}else if key==99 || key==67 {d_input_len=0;d_input_cursor=0;store8(d_input,0);d_term_append("^C\n");}return 0;}
        if key==10 {d_term_exec();}else if key==8 {d_input_delete(1);}else if key==262 {d_input_delete(0);}
        else if key==256 {d_input_cursor=g_max(0,d_input_cursor-1);}else if key==257 {d_input_cursor=g_min(d_input_len,d_input_cursor+1);}
        else if key==260 {d_input_cursor=0;}else if key==261 {d_input_cursor=d_input_len;}
        else if key==258 {d_input_len=fo_len(d_history);fo_copy(d_input,d_history,d_input_len+1);d_input_cursor=d_input_len;}
        else if key==259 {d_input_len=0;d_input_cursor=0;store8(d_input,0);}else if key>=32 && key<127 {d_input_insert(key);}
    }else if d_focus==1 {
        if key==258 {d_file_selected=g_max(0,d_file_selected-1);}else if key==259 {d_file_selected=g_min(d_file_count-1,d_file_selected+1);}else if key==10 {d_files_open(d_file_selected);}
        else if key==8 {d_set_directory(d_parent(d_files_path));}
    }return 0;
}
fn d_content_click(kind,x,y,w,h) {
    if kind==4 {let card=0;while card<3 {if d_inside(x+28+card*184,y+170,172,116) {d_open(card+1);return 0;}card=card+1;}}
    else if kind==2 {
        if d_inside(x+w-106,y+54,82,32) {d_note_save();return 0;}
        if d_inside(x+20,y+102,w-40,h-152) {let row=(d_mouse_y-y-112)/20+d_note_scroll;let col=(d_mouse_x-x-30)/12;d_note_cursor=d_note_seek(g_max(0,row),g_max(0,col));d_note_select=0;}
    }else if kind==1 {
        if d_inside(x+20,y+54,64,32) {d_set_directory(d_parent(d_files_path));return 0;}
        if d_inside(x+96,y+54,132,32) {d_new_note();return 0;}
        if d_inside(x+w-120,y+54,100,32) {d_files_refresh();return 0;}
        let index=(d_mouse_y-y-112)/36+d_file_scroll;if d_mouse_y>=y+112 && d_mouse_y<y+h-42 && index<d_file_count {d_file_selected=index;d_files_open(index);}
    }return 0;
}
fn d_mouse(x,y,buttons) {
    let pressed=(buttons&1) && !(d_buttons&1);let released=!(buttons&1) && (d_buttons&1);d_buttons=buttons;
    if x!=d_mouse_x || y!=d_mouse_y {d_cursor_dirty=1;}d_mouse_x=x;d_mouse_y=y;
    if d_drag && (buttons&1) {
        let win=d_window(d_drag_kind);if d_drag==1 {store64(win,g_max(0,g_min(g_width-80,d_drag_wx+x-d_drag_x)));store64(win+8,g_max(40,g_min(g_height-130,d_drag_wy+y-d_drag_y)));}
        else {store64(win+16,g_max(d_min_width(d_drag_kind),g_min(g_width-d_drag_wx-8,d_drag_w+x-d_drag_x)));store64(win+24,g_max(280,g_min(g_height-d_drag_wy-90,d_drag_h+y-d_drag_y)));}
        d_dirty=1;
    }
    if released && d_drag {platform_output(1,fo_cat(fo_cat("Desktop moved/resized ",d_name(d_drag_kind)),"\n"));d_drag=0;}
    if !pressed {return 0;}d_dirty=1;
    if d_power {d_power=0;if d_inside(g_width-224,52,196,70) {d_quit=1;return 0;}}
    if d_inside(g_width-120,8,100,28) {d_power=1;d_menu=0;return 0;}
    if d_menu {let mx=(g_width-460)/2;let my=g_height-362;
        if d_inside(mx,my,268,270) {let item=(y-my-56)/48;if y>=my+56 && item>=0 && item<4 {d_open(item+1);}return 0;}d_menu=0;
    }
    let dock=(g_width-460)/2;let dock_y=g_height-82;
    if d_inside(dock,dock_y,64,64) {d_menu=!d_menu;return 0;}
    if d_inside(dock+82,dock_y,4*76,64) {let kind=(x-dock-82)/76+1;if kind<=4 {if d_visible(kind) && d_focus==kind {d_minimize(kind);}else {d_open(kind);}return 0;}}
    let i=d_count;while i>0 {i=i-1;let kind=load64(d_order+i*8);let win=d_window(kind);
        let wx=load64(win);let wy=load64(win+8);let ww=load64(win+16);let wh=load64(win+24);
        if d_visible(kind) && d_inside(wx,wy,ww,wh) {
            d_front(kind);
            if y<wy+42 {
                if x>=wx+ww-42 {d_close(kind);return 0;}if x>=wx+ww-74 {d_maximize(kind);return 0;}if x>=wx+ww-106 {d_minimize(kind);return 0;}
                if !load64(win+48) {d_drag=1;}
            }else if !load64(win+48) && x>=wx+ww-20 && y>=wy+wh-20 {d_drag=2;}
            else {d_content_click(kind,wx,wy,ww,wh);return 0;}
            if d_drag {d_drag_kind=kind;d_drag_x=x;d_drag_y=y;d_drag_wx=wx;d_drag_wy=wy;d_drag_w=ww;d_drag_h=wh;}return 0;
        }
    }
    let kind=1;while kind<=4 {if d_inside(28,172+(kind-1)*112,112,92) {d_open(kind);return 0;}kind=kind+1;}d_focus=0;return 0;
}
fn desktop_init() {
    g_init();d_windows=platform_allocate(4*128);d_order=platform_allocate(32);d_note=platform_allocate(8192);d_note_path=fo_keep("/notes.txt");
    d_term=platform_allocate(16384);d_input=platform_allocate(512);d_history=platform_allocate(512);d_files_path=platform_allocate(4096);fo_copy(d_files_path,"/",2);
    d_file_names=platform_allocate(8192);d_file_rows=platform_allocate(64*16);d_note_message("New note. Ctrl+S saves to RAM.");d_files_message("");
    let kind=1;while kind<=4 {let win=d_window(kind);store64(win,192+kind*22);store64(win+8,104+kind*22);store64(win+16,620);store64(win+24,424);kind=kind+1;}
    store64(d_window(2),320);store64(d_window(2)+8,164);store64(d_window(2)+16,580);
    store64(d_window(3),186);store64(d_window(3)+8,214);store64(d_window(3)+16,660);store64(d_window(3)+24,400);
    store64(d_window(4),242);store64(d_window(4)+8,126);
    d_term_append("FlexOS Terminal\nType help for filesystem commands.\nUse clear to reset, exit to close this window.\n\n");d_files_refresh();d_open(4);
    platform_output(1,"FlexOS desktop ready\n");fo_tty=1;fo_prompt();return 0;
}
fn desktop_loop() {
    let event=platform_allocate(32);let serial=platform_allocate(128);
    while !d_quit {let mark=fo_mark();let count=0;
        while count<128 && platform_desktop_poll(event) {if load64(event)==1 {d_keyboard(load64(event+8),load64(event+16));}else {d_mouse(load64(event+8),load64(event+16),load64(event+24));}count=count+1;}
        let n=platform_input(serial,128);if n>0 && fo_feed(serial,n) {if d_visible(1) {d_files_refresh();}d_dirty=1;}if fo_quit {d_quit=1;}
        if d_dirty {d_render();platform_display_present(g_back,0,0,g_width,g_height);d_dirty=0;d_cursor_dirty=1;}
        if d_cursor_dirty {g_cursor(d_mouse_x,d_mouse_y);d_cursor_dirty=0;}fo_reset(mark);
    }return 0;
}
