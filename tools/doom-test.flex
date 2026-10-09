import "qmp.flex";
import "doom-host.flex";
global dd_checks=0;
fn dd_check(ok,message) {qt_assert(ok,message);dd_checks=dd_checks+1;return 0;}
fn dd_stats() {
    let b=load64(qt_process+16);store64(b+8,0);if load64(b) {store8(load64(b),0);}h_trigger(qt_process,"stats\n");qt_until(" angle=");let end=net_now()+5000;
    while h_find(h_out(qt_process)+h_find(h_out(qt_process)," angle="),"\n")<0 {qt_pump(5);qt_assert(net_now()<end,"game telemetry timed out");}return h_replace(h_out(qt_process),"\r","");
}
fn dd_field(s,label) {let at=h_find(s,label);qt_assert(at>=0,"missing game telemetry");at=at+h_len(label);let negative=load8(s+at)==45;if negative {at=at+1;}let n=0;while load8(s+at)>=48 && load8(s+at)<=57 {n=n*10+load8(s+at)-48;at=at+1;}if negative {return -n;}return n;}
