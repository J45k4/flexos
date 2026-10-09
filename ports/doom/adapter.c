/* SPDX-License-Identifier: GPL-2.0-or-later
 * Game-side ABI adapter for the external GPL-2.0-or-later DoomGeneric payload.
 * All hardware, allocation, WAD storage, clocks and input live in Flexscript.
 * This file is linked into the game ELF, never into the FlexOS kernel. */
#include <stdint.h>
#include <stddef.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <ctype.h>
#include <sys/types.h>
#include <sys/stat.h>
#include "doomgeneric.h"
#include "doomstat.h"
#include "d_event.h"
#undef strchr
#undef strrchr
#undef strstr
#define STB_SPRINTF_IMPLEMENTATION
#define STB_SPRINTF_NOFLOAT
#include "stb_sprintf.h"

typedef uint64_t (*host_fn)(uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t);
static host_fn host;
static unsigned char *wad;
static size_t wad_size;
FILE *stdin=(FILE*)1,*stdout=(FILE*)2,*stderr=(FILE*)3;
static int err;
int *__errno_location(void) {return &err;}
void *malloc(size_t n) {return (void*)host(2,n,0,0,0,0);}
void free(void *p) {if(p) host(3,(uintptr_t)p,0,0,0,0);}
void *memset(void *p,int c,size_t n) {unsigned char *d=p;while(n--) *d++=c;return p;}
void *memcpy(void *p,const void *s,size_t n) {unsigned char *d=p;const unsigned char *a=s;while(n--) *d++=*a++;return p;}
void *memmove(void *p,const void *s,size_t n) {unsigned char *d=p;const unsigned char *a=s;if(d<a) return memcpy(p,s,n);while(n) {--n;d[n]=a[n];}return p;}
int memcmp(const void *a,const void *b,size_t n) {const unsigned char *x=a,*y=b;while(n--) {if(*x!=*y) return *x-*y;x++;y++;}return 0;}
void *calloc(size_t n,size_t s) {if(s && n>SIZE_MAX/s) return NULL;return malloc(n*s);}
void *realloc(void *p,size_t n) {if(!p) return malloc(n);void *q=malloc(n);if(q) {size_t old=host(4,(uintptr_t)p,0,0,0,0);memcpy(q,p,old<n?old:n);free(p);}return q;}
size_t strlen(const char *s) {size_t n=0;while(s[n]) n++;return n;}
char *strcpy(char *d,const char *s) {char *r=d;while((*d++=*s++));return r;}
char *strncpy(char *d,const char *s,size_t n) {size_t i=0;while(i<n && s[i]) {d[i]=s[i];i++;}while(i<n) d[i++]=0;return d;}
char *strcat(char *d,const char *s) {strcpy(d+strlen(d),s);return d;}
int strcmp(const char *a,const char *b) {while(*a && *a==*b) {a++;b++;}return (unsigned char)*a-(unsigned char)*b;}
int strncmp(const char *a,const char *b,size_t n) {while(n && *a && *a==*b) {a++;b++;n--;}return n?(unsigned char)*a-(unsigned char)*b:0;}
char *strchr(const char *s,int c) {do {if(*s==(char)c) return (char*)s;}while(*s++);return NULL;}
char *strrchr(const char *s,int c) {char *r=NULL;do {if(*s==(char)c) r=(char*)s;}while(*s++);return r;}
char *strstr(const char *s,const char *v) {size_t n=strlen(v);if(!n) return (char*)s;while(*s) {if(!strncmp(s,v,n)) return (char*)s;s++;}return NULL;}
char *strdup(const char *s) {size_t n=strlen(s)+1;char *p=malloc(n);if(p) memcpy(p,s,n);return p;}
static int lower(int c) {return c>='A'&&c<='Z'?c+32:c;}
int strcasecmp(const char *a,const char *b) {while(*a && lower(*a)==lower(*b)) {a++;b++;}return lower((unsigned char)*a)-lower((unsigned char)*b);}
int strncasecmp(const char *a,const char *b,size_t n) {while(n && *a && lower(*a)==lower(*b)) {a++;b++;n--;}return n?lower((unsigned char)*a)-lower((unsigned char)*b):0;}
long strtol(const char *s,char **end,int base) {while(*s==' '||*s=='\t') s++;int neg=*s=='-';if(*s=='+'||*s=='-') s++;if(!base) base=*s=='0'?8:10;if((base==16||base==8) && s[0]=='0' && lower(s[1])=='x') {base=16;s+=2;}long n=0;while(1) {int c=lower(*s);int d=c>='0'&&c<='9'?c-'0':c>='a'&&c<='z'?c-'a'+10:99;if(d>=base) break;n=n*base+d;s++;}if(end) *end=(char*)s;return neg?-n:n;}
int atoi(const char *s) {return strtol(s,NULL,10);}
double atof(const char *s) {return (double)strtol(s,NULL,10);}
int abs(int n) {return n<0?-n:n;}
int vsnprintf(char *s,size_t n,const char *f,va_list a) {return stbsp_vsnprintf(s,(int)n,f,a);}
int snprintf(char *s,size_t n,const char *f,...) {va_list a;va_start(a,f);int r=vsnprintf(s,n,f,a);va_end(a);return r;}
int sprintf(char *s,const char *f,...) {va_list a;va_start(a,f);int r=stbsp_vsprintf(s,f,a);va_end(a);return r;}
int vfprintf(FILE *f,const char *fmt,va_list a) {char b[2048];int n=vsnprintf(b,sizeof b,fmt,a);if(f==stdout||f==stderr) host(5,(uintptr_t)b,0,0,0,0);return n;}
int fprintf(FILE *f,const char *fmt,...) {va_list a;va_start(a,fmt);int r=vfprintf(f,fmt,a);va_end(a);return r;}
int printf(const char *fmt,...) {va_list a;va_start(a,fmt);int r=vfprintf(stdout,fmt,a);va_end(a);return r;}
int putchar(int c) {char b[2]={(char)c,0};host(5,(uintptr_t)b,0,0,0,0);return c;}
int puts(const char *s) {host(5,(uintptr_t)s,0,0,0,0);putchar('\n');return 0;}
int fflush(FILE *f) {return 0;}
int sscanf(const char *s,const char *fmt,...) {int base=10;if(strchr(fmt,'x')||strchr(fmt,'X')) base=16;else if(strchr(fmt,'o')) base=8;else if(strchr(fmt,'i')) base=0;while(*s==' '||*s=='\t') s++;if(strstr(fmt,"0x")||strstr(fmt,"0X")) {if(s[0]!='0'||lower(s[1])!='x') return 0;s+=2;}else if(strstr(fmt," 0%")) {if(*s!='0') return 0;s++;}char *end;long n=strtol(s,&end,base);if(end==s) return 0;va_list a;va_start(a,fmt);*va_arg(a,int*)=(int)n;va_end(a);return 1;}
int fscanf(FILE *f,const char *fmt,...) {return EOF;}
/* Only the boot WAD is a readable file. Configuration/save files are unavailable. */
typedef struct {size_t at;} game_file;
FILE *fopen(const char *path,const char *mode) {size_t n=strlen(path);if(mode[0]!='r'||n<8||strcasecmp(path+n-8,"doom.wad")) return NULL;game_file *f=malloc(sizeof *f);if(!f) return NULL;f->at=0;return (FILE*)f;}
int fclose(FILE *f) {if((uintptr_t)f>3) free(f);return 0;}
int fseek(FILE *fp,long off,int whence) {game_file *f=(game_file*)fp;long next=off;if(whence==SEEK_CUR) next+=f->at;else if(whence==SEEK_END) next+=wad_size;if(next<0||(size_t)next>wad_size) return -1;f->at=next;return 0;}
long ftell(FILE *fp) {return ((game_file*)fp)->at;}
size_t fread(void *p,size_t s,size_t n,FILE *fp) {game_file *f=(game_file*)fp;if(!s) return 0;size_t available=(wad_size-f->at)/s;if(n>available) n=available;memcpy(p,wad+f->at,s*n);f->at+=s*n;return n;}
size_t fwrite(const void *p,size_t s,size_t n,FILE *fp) {return 0;}
int putc(int c,FILE *f) {return fputc(c,f);}
int fputc(int c,FILE *f) {if(f==stdout||f==stderr) return putchar(c);return EOF;}
int fgetc(FILE *fp) {unsigned char c;return fread(&c,1,1,fp)==1?c:EOF;}
char *getenv(const char *name) {return NULL;}
int mkdir(const char *path,mode_t m) {return -1;}
int remove(const char *p) {return -1;}
int rename(const char *p,const char *q) {return -1;}
int system(const char *s) {return -1;}
char *strerror(int n) {return "Game file unavailable";}
void exit(int status) {host(6,status,0,0,0,0);for(;;);}
void abort(void) {exit(1);}
int atexit(void (*f)(void)) {return 0;}
static int upper_table[384];static const int *upper_ptr;
const int **__ctype_toupper_loc(void) {if(!upper_ptr) {upper_ptr=upper_table+128;for(int c=-128;c<256;c++) upper_table[c+128]=c>=97&&c<=122?c-32:c;}return &upper_ptr;}
double fabs(double n) {return n<0?-n:n;}
static const unsigned short *ctype_table;
const unsigned short **__ctype_b_loc(void) {if(!ctype_table) ctype_table=(void*)host(7,0,0,0,0,0);return &ctype_table;}
void DG_Init(void) {}
void DG_DrawFrame(void) {host(1,(uintptr_t)DG_ScreenBuffer,DOOMGENERIC_RESX,DOOMGENERIC_RESY,0,0);}
void DG_SleepMs(uint32_t ms) {host(9,ms,0,0,0,0);}
uint32_t DG_GetTicksMs(void) {return host(8,0,0,0,0,0);}
int DG_GetKey(int *pressed,unsigned char *key) {
    uint64_t v=host(10,0,0,0,0,0);if(!v) {
        int64_t *m=(void*)host(11,0,0,0,0,0);
        if(m) {event_t event={0};event.type=ev_mouse;event.data1=m[0];event.data2=m[1];event.data3=m[2];D_PostEvent(&event);m[1]=m[2]=0;}
        return 0;
    }*pressed=(v>>8)&1;*key=v&255;return 1;
}
void DG_SetWindowTitle(const char *s) {host(5,(uintptr_t)s,0,0,0,0);}
/* Six-word entry ABI: init/tick/telemetry. No host OS or dynamic linker. */
uint64_t doom_entry(uint64_t op,uint64_t callback,uint64_t data,uint64_t size,uint64_t extra,uint64_t unused) {
    if(!op) {host=(host_fn)callback;wad=(void*)data;wad_size=size;
        static char *args[]={"doom","-iwad","doom.wad","-nogui","-nosound","-mb","6","-warp","1","1","-skill","2"};
        doomgeneric_Create(sizeof args/sizeof args[0],args);return 0;
    }
    if(op==1) {doomgeneric_Tick();return 0;}
    if(op==2) {if(data==0) return gametic;if(data==1) return gamestate;if(data==2) return (uint32_t)players[consoleplayer].mo->x;if(data==3) return (uint32_t)players[consoleplayer].mo->y;if(data==4) return players[consoleplayer].ammo[am_clip];if(data==5) return (uint32_t)players[consoleplayer].mo->angle;
        if(data==6) return (int64_t)players[consoleplayer].cmd.forwardmove;
        if(data==7) return (int64_t)players[consoleplayer].cmd.sidemove;
        if(data==8) return (int64_t)players[consoleplayer].mo->momx;
        if(data==9) return (int64_t)players[consoleplayer].mo->momy;
    }
    return 0;
}
