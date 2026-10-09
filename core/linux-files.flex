// Binary-safe Linux file catalog. File data may be a read-only boot archive;
// paths/descriptors/devices are general OS resources, independent of programs.
global lf_nodes=0;
global lf_count=0;
fn lf_find(path) {let i=0;while i<lf_count {let node=lf_nodes+i*32;if fo_eq(load64(node),path) {return node;}i=i+1;}return 0;}
fn lf_add(path,kind,data,size) {fo_assert(lf_count<128 && !lf_find(path),"duplicate path or rootfs file limit");let node=lf_nodes+lf_count*32;lf_count=lf_count+1;store64(node,fo_keep(path));store64(node+8,kind);store64(node+16,data);store64(node+24,size);return node;}
fn lf_octal(p,n) {let i=0;let value=0;while i<n {let c=load8(p+i);if c==0 || c==32 {return value;}fo_assert(c>=48 && c<=55,"invalid rootfs octal field");value=value*8+c-48;i=i+1;}return value;}
fn lf_tar_string(p,n) {let i=0;while i<n && load8(p+i) {i=i+1;}return fo_slice(p,i);}
fn lf_archive() {
    let offset=0;while offset+512<=le_archive_size {let h=le_archive+offset;if !load8(h) {return 0;}let sum=0;let i=0;while i<512 {if i>=148 && i<156 {sum=sum+32;}else {sum=sum+load8(h+i);}i=i+1;}
        fo_assert(sum==lf_octal(h+148,8),"invalid rootfs tar checksum");fo_assert(fo_eq(lf_tar_string(h+257,5),"ustar"),"rootfs requires ustar format");let size=lf_octal(h+124,12);
        fo_assert(size<=le_archive_size-offset-512,"invalid rootfs file extent");let name=lf_tar_string(h,100);let prefix=lf_tar_string(h+345,155);if fo_len(prefix) {name=fo_cat(fo_cat(prefix,"/"),name);}
        let path=fo_path(name);fo_assert(path,"invalid rootfs path");let type=load8(h+156);fo_assert(type==0 || type==48 || type==53,"rootfs supports regular files and directories only");
        if !fo_eq(path,"/") {let kind=2;if type==53 {kind=1;}lf_add(path,kind,h+512,size);}offset=offset+512+((size+511)&-512);
    }fo_assert(offset==le_archive_size,"truncated rootfs tar header");return 0;
}
fn lf_init() {
    lf_nodes=platform_allocate(4096);lf_add("/",1,0,0);if le_archive {lf_archive();}
    if !lf_find("/welcome.txt") {let file=bm_find("/welcome.txt");let text=load64(file+16);lf_add("/welcome.txt",2,text,fo_len(text));}
    if !lf_find("/dev") {lf_add("/dev",1,0,0);}if !lf_find("/dev/input") {lf_add("/dev/input",1,0,0);}
    fo_assert(!lf_find("/dev/fb0") && !lf_find("/dev/input/event0"),"rootfs cannot replace built-in devices");lf_add("/dev/fb0",3,0,0);lf_add("/dev/input/event0",4,0,0);return 0;
}
