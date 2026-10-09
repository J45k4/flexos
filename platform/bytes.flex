fn boot_u16(p) {return load8(p)|(load8(p+1)<<8);}
fn boot_u32(p) {return boot_u16(p)|(boot_u16(p+2)<<16);}
fn boot_w16(p,n) {store8(p,n);store8(p+1,n>>8);return 0;}
fn boot_w32(p,n) {boot_w16(p,n);boot_w16(p+2,n>>16);return 0;}
fn boot_copy(to,from,n) {let i=0;while i+8<=n {store64(to+i,load64(from+i));i=i+8;}while i<n {store8(to+i,load8(from+i));i=i+1;}return to;}
