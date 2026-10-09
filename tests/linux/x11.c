#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static int bad_window=0;
static int expected_error(Display *d,XErrorEvent *event) {if(event->error_code==BadWindow)bad_window++;else exit(93);return 0;}
int main(void) {
    Display *d=XOpenDisplay("unix:0");if(!d)return 90;
    int s=DefaultScreen(d);Window w=XCreateSimpleWindow(d,RootWindow(d,s),32,32,160,100,0,0,0);
    XSelectInput(d,w,ExposureMask|KeyPressMask|KeyReleaseMask);XMapWindow(d,w);
    GC gc=XCreateGC(d,w,0,0);XSetForeground(d,gc,WhitePixel(d,s));XFillRectangle(d,w,gc,10,10,80,60);
    const unsigned char name[]="generic client";XChangeProperty(d,w,XA_WM_NAME,XA_STRING,8,PropModeReplace,name,sizeof(name));
    Atom type;int format;unsigned long count,after;unsigned char *value=0;
    if(XGetWindowProperty(d,w,XA_WM_NAME,0,100,False,XA_STRING,&type,&format,&count,&after,&value)||type!=XA_STRING||format!=8||count!=sizeof(name)||memcmp(value,name,sizeof(name)))return 91;
    XFree(value);Window root;int x,y;unsigned width,height,border,depth;
    if(!XGetGeometry(d,w,&root,&x,&y,&width,&height,&border,&depth)||width!=160||height!=100||depth!=8)return 92;
    XSetErrorHandler(expected_error);XMapWindow(d,0);XSync(d,False);if(bad_window!=1)return 94;XSetErrorHandler(0);
    XSync(d,False);puts("X11 READY");fflush(stdout);int down=0;
    for(;;){XEvent e;XNextEvent(d,&e);if(e.type==KeyPress&&XKeycodeToKeysym(d,e.xkey.keycode,0)==0xff52)down=1;if(e.type==KeyRelease&&down)break;}
    XFreeGC(d,gc);XDestroyWindow(d,w);XCloseDisplay(d);puts("X11 PASS");return 0;
}
