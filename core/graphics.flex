// Portable software renderer. The platform supplies the display dimensions
// and copies rectangles from this buffer into its framebuffer.
import "font.flex";
global g_width=0;
global g_height=0;
global g_back=0;
global g_font=0;
global g_cursor_save=0;
global g_old_x=-1;
global g_old_y=-1;
global g_old_w=0;
global g_old_h=0;
fn g_min(a,b) {if a<b {return a;}return b;}
fn g_max(a,b) {if a>b {return a;}return b;}
fn g_abs(a) {if a<0 {return -a;}return a;}
fn g_pixel(x,y,color) {
    if x<0 || y<0 || x>=g_width || y>=g_height {return 0;}let p=g_back+(y*g_width+x)*4;
    store8(p,color);store8(p+1,color>>8);store8(p+2,color>>16);store8(p+3,0);return 0;
}
fn g_rect(x,y,w,h,color) {
    let right=g_min(g_width,x+w);let bottom=g_min(g_height,y+h);x=g_max(x,0);y=g_max(y,0);
    if right<=x || bottom<=y {return 0;}let pair=color|(color<<32);
    while y<bottom {let p=g_back+(y*g_width+x)*4;let n=right-x;let i=0;
        while i+1<n {store64(p+i*4,pair);i=i+2;}if i<n {g_pixel(x+i,y,color);}y=y+1;
    }return 0;
}
fn g_round(x,y,w,h,r,color) {
    r=g_min(r,g_min(w/2,h/2));if r<=0 {return g_rect(x,y,w,h,color);}
    g_rect(x,y+r,w,h-2*r,color);let row=0;
    while row<r {let inset=0;while (r-inset)*(r-inset)+(r-row)*(r-row)>r*r {inset=inset+1;}
        g_rect(x+inset,y+row,w-2*inset,1,color);g_rect(x+inset,y+h-row-1,w-2*inset,1,color);row=row+1;
    }return 0;
}
fn g_line(x,y,endx,endy,color) {
    let dx=g_abs(endx-x);let dy=-g_abs(endy-y);let sx=-1;let sy=-1;if x<endx {sx=1;}if y<endy {sy=1;}let error=dx+dy;
    while 1 {g_pixel(x,y,color);if x==endx && y==endy {return 0;}let twice=error*2;
        if twice>=dy {error=error+dy;x=x+sx;}if twice<=dx {error=error+dx;y=y+sy;}
    }return 0;
}
fn g_glyph(c,pattern) {let bits=0;let i=0;let at=0;while load8(pattern+i) {let b=load8(pattern+i);if b==48 || b==49 {if b==49 {bits=bits|(1<<at);}at=at+1;}i=i+1;}store64(g_font+c*8,bits);return 0;}
fn g_char(x,y,c,scale,color) {
    if c<32 || c>126 {c=63;}let bits=load64(g_font+c*8);let row=0;
    while row<7 {let col=0;while col<5 {if bits&(1<<(row*5+col)) {g_rect(x+col*scale,y+row*scale,scale,scale,color);}col=col+1;}row=row+1;}return 0;
}
fn g_text(x,y,text,scale,color) {let i=0;while load8(text+i) {g_char(x+i*6*scale,y,load8(text+i),scale,color);i=i+1;}return 0;}
fn g_label(x,y,text,limit,color) {let i=0;while i<limit && load8(text+i) {g_char(x+i*12,y,load8(text+i),2,color);i=i+1;}if i==limit && load8(text+i) {g_text(x+(limit-3)*12,y,"...",2,color);}return 0;}
fn g_icon(kind,x,y,size,color) {
    if kind==1 { // folder
        g_round(x,y+size/4,size,size*3/5,4,color);g_rect(x+2,y+size/8,size/2,size/3,color);g_rect(x+3,y+size/3,size-6,2,0x9ce7dd);
    }else if kind==2 { // note
        g_round(x+size/8,y,size*3/4,size,4,color);g_rect(x+size/4,y+size/4,size/2,2,0x112538);g_rect(x+size/4,y+size/2,size/2,2,0x112538);g_rect(x+size/4,y+size*3/4,size/3,2,0x112538);
    }else if kind==3 { // terminal
        g_round(x,y+size/8,size,size*3/4,4,color);g_round(x+2,y+size/8+2,size-4,size*3/4-4,3,0x111b2c);
        g_line(x+size/5,y+size/3,x+size/3,y+size/2,0xc7eee7);g_line(x+size/3,y+size/2,x+size/5,y+size*2/3,0xc7eee7);g_rect(x+size/2,y+size*2/3,size/4,2,0xc7eee7);
    }else { // Flex mark
        g_round(x,y,size,size,8,color);g_rect(x+size/4,y+size/4,size/2,size/8,0x142238);g_rect(x+size/4,y+size/4,size/8,size/2,0x142238);g_rect(x+size/4,y+size/2,size*3/8,size/8,0x142238);
    }return 0;
}
fn g_cursor(cx,cy) {
    let x=g_max(0,cx-1);let y=g_max(0,cy-1);let w=g_min(32,g_width-x);let h=g_min(32,g_height-y);
    if g_old_x>=0 {platform_display_present(g_back,g_old_x,g_old_y,g_old_w,g_old_h);}
    let row=0;while row<h {let col=0;while col<w {let p=g_back+((y+row)*g_width+x+col)*4;let i=0;while i<4 {store8(g_cursor_save+(row*32+col)*4+i,load8(p+i));i=i+1;}col=col+1;}row=row+1;}
    row=0;while row<19 {g_rect(cx,cy+row,row/2+2,1,0x08111e);if row>1 && row<16 {g_rect(cx+1,cy+row,g_max(1,row/2),1,0xf3fbff);}row=row+1;}
    g_line(cx+6,cy+13,cx+10,cy+23,0x08111e);g_line(cx+7,cy+13,cx+11,cy+23,0xf3fbff);g_line(cx+8,cy+13,cx+12,cy+23,0x08111e);
    platform_display_present(g_back,x,y,w,h);
    row=0;while row<h {let col=0;while col<w {let p=g_back+((y+row)*g_width+x+col)*4;let i=0;while i<4 {store8(p+i,load8(g_cursor_save+(row*32+col)*4+i));i=i+1;}col=col+1;}row=row+1;}
    g_old_x=x;g_old_y=y;g_old_w=w;g_old_h=h;return 0;
}
fn g_init() {
    g_width=platform_display_width();g_height=platform_display_height();g_back=platform_allocate(g_width*g_height*4);g_font=platform_allocate(128*8);g_cursor_save=platform_allocate(4096);
    fo_assert(g_back>0 && g_font>0 && g_cursor_save>0,"desktop renderer allocation failed");g_font_init();return 0;
}
