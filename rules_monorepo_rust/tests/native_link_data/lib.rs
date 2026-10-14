extern "C" {
    fn native_fixture_value() -> u32;
}

pub fn native_value() -> u32 {
    // SAFETY: The linked fixture defines this argument-free C function.
    unsafe { native_fixture_value() }
}
