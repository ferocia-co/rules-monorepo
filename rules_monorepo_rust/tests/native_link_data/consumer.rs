use native_link_data::native_value;

fn main() {
    assert_eq!(native_value(), 42);
}

#[test]
fn calls_transitive_native_archive() {
    assert_eq!(native_value(), 42);
}
