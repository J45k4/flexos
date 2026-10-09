global rtc_epoch=0;
fn rtc_byte(index) {port_out8(0x70,index|128);return port_in8(0x71);}
fn rtc_number(n,binary) {if binary {return n;}return (n>>4)*10+(n&15);}
fn rtc_leap(year) {return year%4==0 && (year%100!=0 || year%400==0);}
fn rtc_init() {
    let stable=0;let second=0;let minute=0;let hour=0;let day=0;let month=0;let year=0;let century=0;let config=0;
    while !stable {while rtc_byte(10)&128 {}second=rtc_byte(0);minute=rtc_byte(2);hour=rtc_byte(4);day=rtc_byte(7);month=rtc_byte(8);year=rtc_byte(9);century=rtc_byte(0x32);config=rtc_byte(11);stable=!(rtc_byte(10)&128) && second==rtc_byte(0);}
    let binary=config&4;second=rtc_number(second,binary);minute=rtc_number(minute,binary);let pm=hour&128;hour=rtc_number(hour&127,binary);if !(config&2) {hour=hour%12;if pm {hour=hour+12;}}
    day=rtc_number(day,binary);month=rtc_number(month,binary);year=rtc_number(year,binary);century=rtc_number(century,binary);if century<19 || century>99 {century=20;}year=century*100+year;
    fo_assert(year>=1970 && year<=2099 && month>=1 && month<=12 && day>=1 && day<=31 && hour<24 && minute<60 && second<60,"invalid CMOS clock");
    let days=0;let y=1970;while y<year {days=days+365+rtc_leap(y);y=y+1;}let m=1;while m<month {let count=31;if m==2 {count=28+rtc_leap(year);}else if m==4 || m==6 || m==9 || m==11 {count=30;}days=days+count;m=m+1;}
    rtc_epoch=(((days+day-1)*24+hour)*60+minute)*60+second;return 0;
}
