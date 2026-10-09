// QEMU PC HPET at its standard MMIO address. IRQs remain disabled.
// The 64-bit free-running counter avoids lost polling ticks and CPU-speed assumptions.
global hp_period=0;
fn hp_init() {
    let caps=load64(0xfed00000);hp_period=(caps>>32)&0xffffffff;
    fo_assert((caps&8192) && hp_period>0 && hp_period<=100000000,"64-bit HPET required");
    store64(0xfed00010,0);store64(0xfed000f0,0);store64(0xfed00010,1);return 0;
}
fn hp_now() {return 1+load64(0xfed000f0)/(1000000000000/hp_period);}
