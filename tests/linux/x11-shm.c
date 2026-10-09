#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/extensions/XShm.h>
#include <sys/ipc.h>
#include <sys/shm.h>
#include <stdio.h>
#include <string.h>

/* Ordinary Xlib client: a batch of full-window frames must not postpone
 * input until all of its completion events have been delivered. */
int main(void) {
    Display *d=XOpenDisplay("unix:0");if(!d)return 90;
    int s=DefaultScreen(d),completion=XShmGetEventBase(d)+ShmCompletion;
    Window clip=XCreateSimpleWindow(d,RootWindow(d,s),1003,747,31,31,0,0,0);
    GC clipgc=XCreateGC(d,clip,0,0);XSetForeground(d,clipgc,255);
    XMapWindow(d,clip);XFillRectangle(d,clip,clipgc,0,0,31,31);
    Window w=XCreateSimpleWindow(d,RootWindow(d,s),32,32,641,401,0,0,0);
    XSelectInput(d,w,KeyPressMask|KeyReleaseMask);XMapWindow(d,w);
    GC gc=XCreateGC(d,w,0,0);XShmSegmentInfo info;
    XImage *image=XShmCreateImage(d,DefaultVisual(d,s),8,ZPixmap,0,&info,641,401);
    if(!image)return 91;
    info.shmid=shmget(IPC_PRIVATE,image->bytes_per_line*image->height,IPC_CREAT|0600);
    if(info.shmid<0)return 92;
    info.shmaddr=shmat(info.shmid,0,0);if(info.shmaddr==(void*)-1)return 93;
    info.readOnly=False;image->data=info.shmaddr;
    memset(image->data,127,image->bytes_per_line*image->height);
    for(int y=0;y<401;y++)image->data[y*image->bytes_per_line+640]=255;
    XShmAttach(d,&info);XShmPutImage(d,w,gc,image,0,0,0,0,641,401,True);XFlush(d);
    XEvent e;do{XNextEvent(d,&e);}while(e.type!=completion);
    puts("X11 SHM READY");fflush(stdout);
    do{XNextEvent(d,&e);}while(e.type!=KeyPress);
    /* These 2560 request bytes fit in Xlib's output buffer. One XFlush
     * makes one batch: the host releases the key while it is rendering. */
    for(int i=0;i<64;i++)XShmPutImage(d,w,gc,image,0,0,0,0,641,401,True);
    puts("X11 BATCH READY");fflush(stdout);XFlush(d);
    int frames=0,release=0,frames_after_release=0;
    while(frames<64||!release){
        XNextEvent(d,&e);
        if(e.type==KeyRelease)release=1;
        if(e.type==completion){frames++;if(release)frames_after_release++;}
    }
    if(!frames_after_release)return 94;
    printf("X11 SHM PASS: %d completions after release\n",frames_after_release);
    XShmDetach(d,&info);XSync(d,False);image->data=0;XDestroyImage(image);
    shmdt(info.shmaddr);shmctl(info.shmid,IPC_RMID,0);
    XFreeGC(d,gc);XFreeGC(d,clipgc);XDestroyWindow(d,w);XDestroyWindow(d,clip);
    XCloseDisplay(d);return 0;
}
