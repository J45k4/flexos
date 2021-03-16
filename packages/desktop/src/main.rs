#![feature(core_intrinsics)]
#![no_std]
#![no_main]

pub mod panic;

use alloc::Vec;

#[no_mangle]
pub fn _start() -> ! {
    let mut vec: Vec<i32> = Vec::new();
    loop {}
}
