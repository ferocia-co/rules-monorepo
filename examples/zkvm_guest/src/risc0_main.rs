unsafe extern "C" {
    fn risc0_native_add(left: u32, right: u32) -> u32;
}

fn main() {
    std::hint::black_box(unsafe { risc0_native_add(20, 22) });
}
