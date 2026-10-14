use std::env;

fn main() {
    let directory = env::var("NATIVE_DIRECTORY").expect("native fixture directory");
    println!("cargo:rustc-link-search=native={directory}");
    println!("cargo:rustc-link-lib=static=native_fixture");
}
