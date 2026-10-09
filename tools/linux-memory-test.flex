import "linux-test.flex";
global ld_symbols=0;
global ld_layout=0;
fn dt_hex(c) {if c>=48 && c<=57 {return c-48;}if c>=97 && c<=102 {return c-87;}if c>=65 && c<=70 {return c-55;}return -1;}
fn dt_number(s,base) {let value=0;let i=0;while dt_hex(load8(s+i))>=0 && dt_hex(load8(s+i))<base {value=value*base+dt_hex(load8(s+i));i=i+1;}qt_assert(i>0,"missing debugger number");return value;}
fn dt_symbol(name) {let s=h_cat("\n",ld_symbols);let i=h_find(s,h_cat3("\n",name," "));qt_assert(i>=0,"missing upstream game symbol");return dt_number(s+i+h_len(name)+4,16);}
fn dt_offset(index) {let s=ld_layout;let i=0;while i<index {while load8(s)!=32 && load8(s) {s=s+1;}qt_assert(load8(s)==32,"missing game ABI offset");s=s+1;i=i+1;}return dt_number(s,10);}
fn dt_physical(p) {let r=qt_execute("human-monitor-command",h_cat3("{\"command-line\":\"xp /1gx ",h_int(p),"\"}"));let i=h_find(r,": 0x");qt_assert(i>=0,"missing QEMU physical memory result");return dt_number(r+i+4,16);}
fn dt_address(p) {
    qt_assert(p>=0x400000 && p<0x40000000,"invalid game user address");let directory=dt_physical(0x112000+((p>>21)&511)*8);qt_assert((directory&1) && !(directory&128),"missing user page table");
    let page=dt_physical((directory&0xfffff000)+((p>>12)&511)*8);qt_assert(page&1,"missing user page");return (page&0xfffff000)+(p&4095);
}
fn dt_user(p) {return dt_physical(dt_address(p));}
fn dt_u32(p) {return dt_user(p)&0xffffffff;}
