# rules_monorepo_docs

`rules_monorepo_docs` provides reusable documentation rules for Bazel
monorepos.

## mdBook Setup

Download the pinned mdBook release binary in `MODULE.bazel`:

```starlark
download_mdbook = use_repo_rule(
    "@rules_monorepo//rules_monorepo_docs:repositories.bzl",
    "download_mdbook",
)
download_mdbook(name = "mdbook_bin")
```

Then build a book from package-relative sources:

```starlark
load("@rules_monorepo//rules_monorepo_docs:defs.bzl", "mdbook_docs")

mdbook_docs(
    name = "docs",
    book = "book.toml",
    mdbook = "@mdbook_bin//:mdbook",
    srcs = glob(["src/**"]),
)
```

The rule stages `book.toml` and `srcs` into a temporary package root, runs the
supplied `mdbook` executable, and copies the mdBook destination directory into
the declared Bazel directory output. The default destination and output
directory is `book`; set `build_dir` when mdBook should write elsewhere, and set
`out_dir` when the Bazel output directory should use another name.

If a book needs deterministic post-processing, pass `postbuild_script`. The
script must be one of the staged package files and runs from the book root after
`mdbook build` completes.
