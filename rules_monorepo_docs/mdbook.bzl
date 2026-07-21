"""mdBook build rules."""

def _validate_relative_path(attr_name, value):
    if not value:
        fail("{} must not be empty".format(attr_name))

    if value.startswith("/") or value.startswith("\\"):
        fail("{} must be a relative path, got '{}'".format(attr_name, value))

    if "\\" in value:
        fail("{} must use forward slashes, got '{}'".format(attr_name, value))

    segments = value.split("/")
    if "" in segments or "." in segments or ".." in segments:
        fail("{} must not contain empty, . or .. path segments, got '{}'".format(attr_name, value))

def _package_relative_path(ctx, file):
    short_path = file.short_path
    package = ctx.label.package

    if package:
        prefix = package + "/"
        if short_path.startswith(prefix):
            return short_path[len(prefix):]
    elif not short_path.startswith("../"):
        return short_path

    fail(
        "mdbook_docs inputs must be files in package '{}' or its subdirectories; got {}".format(
            package,
            short_path,
        ),
    )

def _book_root(book_rel):
    if "/" not in book_rel:
        return "."

    return book_rel.rsplit("/", 1)[0]

def _mdbook_docs_impl(ctx):
    _validate_relative_path("out_dir", ctx.attr.out_dir)

    build_dir = ctx.attr.build_dir if ctx.attr.build_dir else ctx.attr.out_dir
    _validate_relative_path("build_dir", build_dir)

    files = [ctx.file.book] + ctx.files.srcs
    postbuild_script_rel = ""
    if ctx.file.postbuild_script:
        files.append(ctx.file.postbuild_script)
        postbuild_script_rel = _package_relative_path(ctx, ctx.file.postbuild_script)

    staged_paths = {}
    manifest_lines = []

    for file in files:
        rel = _package_relative_path(ctx, file)
        if rel in staged_paths and staged_paths[rel] != file.path:
            fail("multiple mdbook_docs inputs stage to '{}'".format(rel))

        staged_paths[rel] = file.path
        manifest_lines.append("{}\t{}".format(file.path, rel))

    book_rel = _package_relative_path(ctx, ctx.file.book)
    book_root = _book_root(book_rel)

    manifest = ctx.actions.declare_file("{}_mdbook_manifest.txt".format(ctx.label.name))
    ctx.actions.write(
        output = manifest,
        content = "\n".join(manifest_lines) + "\n",
    )

    out = ctx.actions.declare_directory(ctx.attr.out_dir)

    ctx.actions.run_shell(
        inputs = files + [manifest, ctx.executable.mdbook],
        tools = [ctx.executable.mdbook],
        outputs = [out],
        mnemonic = "MdBookBuild",
        progress_message = "Building mdBook docs %{label}",
        arguments = [
            ctx.executable.mdbook.path,
            manifest.path,
            out.path,
            book_root,
            build_dir,
            postbuild_script_rel,
        ],
        command = """\
set -euo pipefail

execroot="$PWD"
mdbook="$execroot/$1"
manifest="$execroot/$2"
out="$execroot/$3"
book_root_rel="$4"
build_dir="$5"
postbuild_script_rel="$6"

stage="$(mktemp -d "${TMPDIR:-/tmp}/mdbook_docs.XXXXXX")"
trap 'rm -rf "$stage"' EXIT

while IFS="$(printf '\\t')" read -r src rel; do
    dest="$stage/$rel"
    mkdir -p "$(dirname "$dest")"
    cp -f "$src" "$dest"
done < "$manifest"

book_root="$stage/$book_root_rel"
(cd "$book_root" && "$mdbook" build . --dest-dir "$build_dir")
if [ -n "$postbuild_script_rel" ]; then
    (cd "$book_root" && bash "$postbuild_script_rel")
fi

build_output="$book_root/$build_dir"
if [ ! -d "$build_output" ]; then
    echo "mdbook_docs: mdBook did not create build_dir '$build_dir'" >&2
    exit 1
fi

rm -rf "$out"
mkdir -p "$out"
cp -R "$build_output"/. "$out"/
""",
    )

    return [DefaultInfo(files = depset([out]))]

mdbook_docs = rule(
    implementation = _mdbook_docs_impl,
    doc = "Builds an mdBook site from Bazel-managed sources.",
    attrs = {
        "book": attr.label(
            allow_single_file = True,
            doc = "The package-relative book.toml file.",
            mandatory = True,
        ),
        "srcs": attr.label_list(
            allow_files = True,
            doc = "Source files used by mdBook, usually glob([\"src/**\"]).",
        ),
        "mdbook": attr.label(
            allow_files = True,
            cfg = "exec",
            doc = "Executable mdBook binary, for example @mdbook_bin//:mdbook.",
            executable = True,
            mandatory = True,
        ),
        "postbuild_script": attr.label(
            allow_single_file = True,
            doc = "Optional package-relative shell script run from the book root after mdBook builds.",
        ),
        "out_dir": attr.string(
            default = "book",
            doc = "Declared directory output name.",
        ),
        "build_dir": attr.string(
            doc = "mdBook destination directory relative to book.toml. Defaults to out_dir.",
        ),
    },
)
