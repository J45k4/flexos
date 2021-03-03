#![feature(core_intrinsics)]
#![no_std]
#![no_main]

pub mod panic;

#[no_mangle]
pub fn _start() -> ! {
    loop {}
}
