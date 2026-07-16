"""Load-only coverage for the public rules_rust facade."""

load(
    ":cargo_defs.bzl",
    "RustWasmBindgenInfo",
    "cargo_build_script",
    "rust_binary",
    "rust_clippy",
    "rust_doc",
    "rust_doc_test",
    "rust_library",
    "rust_proc_macro",
    "rust_test",
    "rust_test_suite",
    "rust_wasm_bindgen",
    "rust_wasm_bindgen_test",
    "rust_wasm_bindgen_toolchain",
    "rustfmt_test",
)
load(":extensions.bzl", rust_wasm_bindgen_extension = "rust_wasm_bindgen")

def rust_facade_load_test():
    # Referencing every binding makes accidental removal fail during package
    # loading, before consumer migrations reach individual BUILD packages.
    _ = [
        RustWasmBindgenInfo,
        cargo_build_script,
        rust_binary,
        rust_clippy,
        rust_doc,
        rust_doc_test,
        rust_library,
        rust_proc_macro,
        rust_test,
        rust_test_suite,
        rust_wasm_bindgen,
        rust_wasm_bindgen_extension,
        rust_wasm_bindgen_test,
        rust_wasm_bindgen_toolchain,
        rustfmt_test,
    ]
    native.filegroup(
        name = "rust_facade_load_test",
        srcs = [],
        testonly = True,
    )
