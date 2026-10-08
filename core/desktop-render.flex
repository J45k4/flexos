// Drawing only; controllers and input dispatch live in desktop.flex.
fn d_button(x,y,w,text,accent) {let color=0x2a384e;if accent {color=0x62ddc3;}g_round(x,y,w,32,7,color);let ink=0xd9e5f2;if accent {ink=0x102b31;}g_text(x+12,y+9,text,2,ink);return 0;}
fn d_wallpaper() {
    let y=0;while y<g_height {let r=12+y*7/g_height;let green=21+y*13/g_height;let blue=37+y*20/g_height;g_rect(0,y,g_width,1,(r<<16)|(green<<8)|blue);y=y+1;}
    // A quiet geometric wallpaper, drawn by the guest rather than a bitmap.
    g_round(g_width-368,84,280,280,56,0x172d41);g_round(g_width-340,112,224,224,42,0x1b3549);
    g_rect(g_width-284,166,112,22,0x24485a);g_rect(g_width-284,166,22,112,0x24485a);g_rect(g_width-284,222,82,22,0x24485a);
    g_text(32,78,"FlexOS",4,0xbbeee7);g_text(34,120,"Your space.",2,0x768fa6);
    g_text(g_width-338,g_height-152,"Make room",3,0x648697);g_text(g_width-338,g_height-120,"for ideas.",3,0x648697);
    let kind=1;while kind<=4 {let top=178+(kind-1)*112;g_round(40,top,64,64,15,0x203449);g_icon(kind,56,top+16,32,0x6ee0c9);
        let name=d_name(kind);if kind==4 {name="About";}g_text(40,top+76,name,2,0xb8cada);kind=kind+1;}
    g_rect(0,0,g_width,42,0x101b2c);g_icon(4,18,10,22,0x6ee0c9);g_text(52,14,"FlexOS",2,0xd7e9f1);
    g_text(g_width/2-66,14,"Workspace 1",2,0x91a9bd);g_round(g_width-284,8,142,28,7,0x213246);g_text(g_width-272,15,"RAM storage",2,0x9fb7c8);
    g_round(g_width-120,8,100,28,7,0x24394b);g_text(g_width-100,15,"Power",2,0xc9dce8);return 0;
}
fn d_frame(kind) {
    let win=d_window(kind);let x=load64(win);let y=load64(win+8);let w=load64(win+16);let h=load64(win+24);
    g_round(x-6,y+8,w+12,h+6,17,0x080f1b);let border=0x35485e;if d_focus==kind {border=0x609c9e;}
    g_round(x,y,w,h,12,border);g_round(x+1,y+1,w-2,h-2,11,0x182537);g_rect(x+1,y+42,w-2,1,0x354559);
    g_icon(kind,x+14,y+11,22,0x7bddca);g_text(x+48,y+14,d_name(kind),2,0xd7e8f1);
    g_rect(x+w-96,y+24,12,2,0xa3b5c9);g_rect(x+w-64,y+14,12,12,0xa3b5c9);g_rect(x+w-62,y+16,8,8,0x182537);
    g_round(x+w-38,y+8,28,28,6,0x3a2a3b);g_line(x+w-29,y+16,x+w-20,y+25,0xf0b9c6);g_line(x+w-29,y+25,x+w-20,y+16,0xf0b9c6);
    if !load64(win+48) {g_line(x+w-15,y+h-7,x+w-7,y+h-15,0x5c7088);g_line(x+w-11,y+h-7,x+w-7,y+h-11,0x5c7088);}
    if kind==1 {d_draw_files(x,y,w,h);}else if kind==2 {d_draw_notes(x,y,w,h);}else if kind==3 {d_draw_terminal(x,y,w,h);}else {d_draw_about(x,y,w,h);}return 0;
}
fn d_draw_about(x,y,w,h) {
    g_text(x+28,y+66,"Hello, FlexOS.",3,0xe4f3f4);g_text(x+28,y+108,"Everything starts here.",2,0x9cb4c6);
    let card=0;while card<3 {let left=x+28+card*184;g_round(left,y+170,172,116,10,0x24364a);g_icon(card+1,left+16,y+188,28,0x72ddc9);
        g_text(left+16,y+234,d_name(card+1),2,0xe3edf5);let description="Browse RAM";if card==1 {description="Make a note";}if card==2 {description="Run commands";}
        g_text(left+16,y+263,description,1,0x9eb7c7);card=card+1;
    }
    g_text(x+28,y+h-92,"One workspace. Your everyday tools.",2,0xb2c9d7);
    g_text(x+28,y+h-56,"F1 Launcher   F2 Notes   F3 Files   F4 Terminal",1,0x7f9aaf);
    g_text(x+28,y+h-36,"Files are kept in RAM for this session.",1,0x7f9aaf);return 0;
}
fn d_draw_files(x,y,w,h) {
    d_button(x+20,y+54,64,"Up",0);d_button(x+96,y+54,132,"New note",1);d_button(x+w-120,y+54,100,"Refresh",0);
    g_label(x+248,y+64,d_files_path,g_max(1,(w-396)/12),0x90aabc);
    let visible=(h-156)/36;if d_file_selected<d_file_scroll {d_file_scroll=d_file_selected;}if d_file_selected>=d_file_scroll+visible {d_file_scroll=d_file_selected-visible+1;}
    let i=0;while i<visible && i+d_file_scroll<d_file_count {let index=i+d_file_scroll;let row=d_file_rows+index*16;let top=y+112+i*36;
        if index==d_file_selected {g_round(x+16,top-5,w-32,32,6,0x294559);}g_icon(2-load64(row+8),x+28,top,22,0x68d7c2);g_label(x+66,top+4,load64(row),(w-108)/12,0xcadbe6);i=i+1;
    }
    if !d_file_count {g_text(x+28,y+126,"This folder is empty.",2,0x8ba4ba);}g_label(x+20,y+h-28,d_files_status,(w-56)/12,0x8faabc);return 0;
}
fn d_draw_notes(x,y,w,h) {
    g_label(x+24,y+64,d_basename(d_note_path),(w-164)/12,0xa9c6d5);d_button(x+w-106,y+54,82,"Save",1);
    g_round(x+20,y+102,w-40,h-152,8,0x101c2b);let cols=d_note_columns();let lines=(h-170)/20;let location=d_note_location(d_note_cursor);let caret_row=location/4096;let caret_col=location%4096;
    if caret_row<d_note_scroll {d_note_scroll=caret_row;}if caret_row>=d_note_scroll+lines {d_note_scroll=caret_row-lines+1;}
    if d_note_select {g_rect(x+28,y+110,w-56,h-168,0x214d5a);}if !d_note_len {g_text(x+30,y+114,"Write something...",2,0x5f7c90);}
    let i=0;let row=0;let col=0;while i<d_note_len {let c=load8(d_note+i);if c==10 {row=row+1;col=0;}else {if row>=d_note_scroll && row<d_note_scroll+lines {g_char(x+30+col*12,y+114+(row-d_note_scroll)*20,c,2,0xd6e7ec);}col=col+1;if col>=cols {row=row+1;col=0;}}i=i+1;}
    if d_focus==2 && !d_note_select {g_rect(x+30+caret_col*12,y+112+(caret_row-d_note_scroll)*20,2,18,0x79e9d0);}
    g_label(x+24,y+h-28,d_note_status,(w-54)/12,0x87a7b8);if d_note_dirty {g_rect(x+10,y+15,3,12,0xf0c879);}return 0;
}
fn d_draw_terminal(x,y,w,h) {
    g_round(x+14,y+54,w-28,h-74,8,0x0c1726);let cols=(w-48)/12;let lines=(h-142)/20;let total=0;let col=0;let i=0;
    while i<d_term_len {if load8(d_term+i)==10 {total=total+1;col=0;}else {col=col+1;if col>=cols {total=total+1;col=0;}}i=i+1;}
    let skip=g_max(0,total-lines+1);let row=0;col=0;i=0;
    while i<d_term_len {let c=load8(d_term+i);if c==10 {row=row+1;col=0;}else {if row>=skip && row<skip+lines {g_char(x+24+col*12,y+68+(row-skip)*20,c,2,0xa8d5d2);}col=col+1;if col>=cols {row=row+1;col=0;}}i=i+1;}
    g_rect(x+24,y+h-73,w-48,1,0x24394b);let prompt=fo_cat(fo_cat("flexos:",fo_cwd)," > ");let prompt_len=fo_len(prompt);let input_cols=cols-prompt_len;
    if input_cols<6 {prompt="> ";prompt_len=2;input_cols=cols-2;}g_label(x+24,y+h-58,prompt,cols,0x6ee3c9);
    let start=g_max(0,d_input_cursor-input_cols+1);g_label(x+24+prompt_len*12,y+h-58,d_input+start,input_cols,0xe0edf3);
    if d_focus==3 {g_rect(x+24+(prompt_len+d_input_cursor-start)*12,y+h-60,2,18,0x6ee3c9);}return 0;
}
fn d_dock() {
    let x=(g_width-460)/2;let y=g_height-82;g_round(x-4,y+4,468,66,17,0x070f1b);g_round(x,y,460,64,14,0x22334a);
    if d_menu {g_round(x+8,y+8,48,48,10,0x375e6b);}g_icon(4,x+16,y+16,32,0x6ee0c9);g_rect(x+68,y+14,1,36,0x425568);
    let kind=1;while kind<=4 {let left=x+82+(kind-1)*76;if d_focus==kind && d_visible(kind) {g_round(left+2,y+8,58,48,10,0x354b62);}
        g_icon(kind,left+16,y+16,32,0x8cddcf);if load64(d_window(kind)+32) {let color=0x8299ae;if d_visible(kind) {color=0x77e6ca;}g_rect(left+26,y+57,12,3,color);}kind=kind+1;
    }return 0;
}
fn d_popovers() {
    if d_menu {let x=(g_width-460)/2;let y=g_height-362;g_round(x-4,y+6,276,274,16,0x080f1b);g_round(x,y,268,270,12,0x25364b);g_text(x+20,y+20,"Applications",2,0xcbdfea);
        let kind=1;while kind<=4 {let top=y+56+(kind-1)*48;if d_inside(x+8,top,252,44) {g_round(x+8,top,252,44,7,0x344e63);}g_icon(kind,x+20,top+8,26,0x73deca);g_text(x+64,top+14,d_name(kind),2,0xcfe1eb);kind=kind+1;}
    }
    if d_power {g_round(g_width-224,52,196,70,10,0x2b3e52);g_text(g_width-204,78,"Shut down",2,0xf4c1c7);}return 0;
}
fn d_render() {d_wallpaper();let i=0;while i<d_count {let kind=load64(d_order+i*8);if d_visible(kind) {d_frame(kind);}i=i+1;}d_dock();d_popovers();return 0;}
