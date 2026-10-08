// Portable word/byte helpers. Allocation and deallocation are adapter operations.
global fo_blocks=0;
global fo_used=0;
global fo_capacity=0;
fn fo_len(s) {let n=0;if s {while load8(s+n) {n=n+1;}}return n;}
fn fo_die(s) {platform_output(2,"FlexOS: ");platform_output(2,s);platform_output(2,"\n");platform_exit(1);return 0;}
fn fo_assert(ok,s) {if !ok {fo_die(s);}return 0;}
fn fo_take(n) {
    fo_assert(n>=0 && n<=1048576,"allocation limit");n=(n+7)/8*8;
    if !fo_blocks || n>fo_capacity-fo_used {let size=65536;if n+16>size {size=(n+4111)/4096*4096;}let p=platform_allocate(size);fo_assert(p>0,"allocation failed");store64(p,fo_blocks);store64(p+8,size);fo_blocks=p;fo_capacity=size-16;fo_used=0;}
    let p=fo_blocks+16+fo_used;fo_used=fo_used+n;return p;
}
fn fo_mark() {fo_used=fo_capacity;return fo_blocks;}
fn fo_reset(mark) {while fo_blocks!=mark {let p=fo_blocks;fo_blocks=load64(p);platform_free(p,load64(p+8));}fo_capacity=0;if fo_blocks {fo_capacity=load64(fo_blocks+8)-16;}fo_used=fo_capacity;return 0;}
fn fo_copy(to,from,n) {let i=0;while i<n {store8(to+i,load8(from+i));i=i+1;}return to;}
fn fo_slice(s,n) {let p=fo_take(n+1);fo_copy(p,s,n);store8(p+n,0);return p;}
fn fo_keep(s) {let n=fo_len(s);let p=platform_allocate(n+1);fo_assert(p>0,"persistent allocation failed");fo_copy(p,s,n);store8(p+n,0);return p;}
fn fo_eq(a,b) {if !a || !b {return a==b;}let i=0;while load8(a+i) && load8(a+i)==load8(b+i) {i=i+1;}return load8(a+i)==load8(b+i);}
fn fo_cat(a,b) {let n=fo_len(a);let k=fo_len(b);let p=fo_take(n+k+1);fo_copy(p,a,n);fo_copy(p+n,b,k);store8(p+n+k,0);return p;}
fn fo_int(n) {let p=fo_take(32);let i=31;store8(p+i,0);let negative=n<0;if !negative {n=-n;}while n<=-10 {i=i-1;store8(p+i,48-n%10);n=n/10;}i=i-1;store8(p+i,48-n);if negative {i=i-1;store8(p+i,45);}return p+i;}
fn fo_buffer() {let p=fo_take(24);store64(p,0);store64(p+8,0);store64(p+16,0);return p;}
fn fo_append(b,s,n) {let size=load64(b+8);let cap=load64(b+16);fo_assert(n>=0 && size+n<=262144,"buffer limit");if size+n+1>cap {let next=1024;while next<size+n+1 {next=next*2;}let p=fo_take(next);fo_copy(p,load64(b),size);store64(b,p);store64(b+16,next);}fo_copy(load64(b)+size,s,n);store64(b+8,size+n);store8(load64(b)+size+n,0);return b;}
fn fo_text(b,s) {return fo_append(b,s,fo_len(s));}
fn fo_data(b) {if !load64(b) {fo_text(b,"");}return load64(b);}
