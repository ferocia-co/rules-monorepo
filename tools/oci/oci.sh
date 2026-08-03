#!/bin/sh
set -eu

usage() {
  cat <<'EOF'
Usage: oci <build|tarball|push> [options]

Discover and operate on rules_monorepo OCI targets by their standard tags.

Options:
  --bazel PATH       Call this repository Bazel wrapper (default: bazelisk).
  --scope QUERY      Query scope (default: //...).
  --image NAME       Select an image; repeatable. Resolution order is full label,
                     generated target, logical name, then stripped `_oci` shorthand.
                     Ambiguous names fail instead of selecting many.
  --all              Select every discovered image.
  --repository REPO  Override the repository for every push target; push-only.
  --tag TAG          Add a runtime push tag; repeatable and push-only.
  --jobs N           Set both Bazel jobs and push processes (default: 4).
                     Explicit split flags take precedence over this legacy alias.
  --bazel-jobs N     Maximum Bazel build jobs (default: 4).
  --push-jobs N      Maximum concurrent push processes (default: 4); push-only.
  --compilation-mode MODE
                     Bazel compilation mode: fastbuild, dbg, or opt (default: opt).
  --dry-run          Query normally, but print operations instead of running.
  -h, --help         Show this help.
EOF
}

die() {
  printf 'oci: %s\n' "$*" >&2
  exit 2
}

append_line() {
  if [ -z "$1" ]; then
    printf '%s' "$2"
  else
    printf '%s\n%s' "$1" "$2"
  fi
}

append_unique_line() {
  if [ -n "$1" ] && printf '%s\n' "$1" | grep -Fqx -- "$2"; then
    printf '%s' "$1"
  else
    append_line "$1" "$2"
  fi
}

print_command() {
  printf '+'
  for argument in "$@"; do
    printf ' %s' "$argument"
  done
  printf '\n'
}

mode=""
bazel="bazelisk"
scope="//..."
images=""
repository=""
tags=""
select_all=0
legacy_jobs=4
bazel_jobs=""
push_jobs=""
push_jobs_set=0
compilation_mode="opt"
dry_run=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    build|tarball|push)
      [ -z "$mode" ] || die "only one mode may be selected"
      mode="$1"
      shift
      ;;
    --bazel)
      [ "$#" -ge 2 ] || die "--bazel requires a path"
      bazel="$2"
      shift 2
      ;;
    --scope)
      [ "$#" -ge 2 ] || die "--scope requires a query scope"
      scope="$2"
      shift 2
      ;;
    --image)
      [ "$#" -ge 2 ] || die "--image requires a name"
      images="$(append_line "$images" "$2")"
      shift 2
      ;;
    --all)
      select_all=1
      shift
      ;;
    --tag)
      [ "$#" -ge 2 ] || die "--tag requires a value"
      tags="$(append_unique_line "$tags" "$2")"
      shift 2
      ;;
    --repository)
      [ "$#" -ge 2 ] || die "--repository requires a value"
      [ -n "$2" ] || die "--repository requires a value"
      case "$2" in
        --*) die "--repository requires a value" ;;
      esac
      [ -z "$repository" ] || die "--repository may only be specified once"
      repository="$2"
      shift 2
      ;;
    --jobs)
      [ "$#" -ge 2 ] || die "--jobs requires a positive integer"
      legacy_jobs="$2"
      case "$legacy_jobs" in
        ''|*[!0-9]*|0) die "--jobs requires a positive integer" ;;
      esac
      shift 2
      ;;
    --bazel-jobs)
      [ "$#" -ge 2 ] || die "--bazel-jobs requires a positive integer"
      bazel_jobs="$2"
      case "$bazel_jobs" in
        ''|*[!0-9]*|0) die "--bazel-jobs requires a positive integer" ;;
      esac
      shift 2
      ;;
    --push-jobs)
      [ "$#" -ge 2 ] || die "--push-jobs requires a positive integer"
      push_jobs="$2"
      case "$push_jobs" in
        ''|*[!0-9]*|0) die "--push-jobs requires a positive integer" ;;
      esac
      push_jobs_set=1
      shift 2
      ;;
    --compilation-mode)
      [ "$#" -ge 2 ] || die "--compilation-mode requires a value"
      compilation_mode="$2"
      case "$compilation_mode" in
        fastbuild|dbg|opt) ;;
        *) die "--compilation-mode must be one of fastbuild, dbg, or opt" ;;
      esac
      shift 2
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

bazel_jobs=${bazel_jobs:-$legacy_jobs}
push_jobs=${push_jobs:-$legacy_jobs}

[ -n "$mode" ] || die "a build, tarball, or push mode is required"
[ "$select_all" -eq 0 ] || [ -z "$images" ] || die "--all and --image are mutually exclusive"
[ "$select_all" -eq 1 ] || [ -n "$images" ] || die "select --all or at least one --image"
[ "$mode" = "push" ] || [ -z "$tags" ] || die "--tag is only valid in push mode"
[ "$mode" = "push" ] || [ -z "$repository" ] || die "--repository is only valid in push mode"
[ "$mode" = "push" ] || [ "$push_jobs_set" -eq 0 ] || die "--push-jobs is only valid in push mode"

case "$scope" in
  //*|@*//*) ;;
  *) die "--scope must be a Bazel query scope" ;;
esac

workspace="${BUILD_WORKSPACE_DIRECTORY:-}"
[ -n "$workspace" ] || die "BUILD_WORKSPACE_DIRECTORY is not set; run this tool with bazel run"
cd "$workspace"

case "$mode" in
  build)
    query_tag="oci_image"
    suffix="_image"
    ;;
  tarball)
    query_tag="oci_tarball"
    suffix="_tarball"
    ;;
  push)
    query_tag="oci_push"
    suffix="_push"
    ;;
esac

# attr() accepts a regular expression and performs a partial match. Word
# boundaries keep private/internal tags such as internal_image_manifest out of
# discovery while matching the exact public contract tag in a string-list.
query="attr(tags, '\\b${query_tag}\\b', ${scope})"
discovered=""
for target in $("$bazel" query "$query" --output=label); do
  case "$target" in
    *"$suffix") discovered="$(append_line "$discovered" "$target")" ;;
  esac
done
[ -n "$discovered" ] || die "no ${query_tag} targets found under ${scope}"

selected=""
if [ "$select_all" -eq 1 ]; then
  selected="$discovered"
else
  old_ifs=$IFS
  IFS='
'
  for requested in $images; do
    full_label_matches=""
    target_name_matches=""
    logical_name_matches=""
    conventional_name_matches=""
    for target in $discovered; do
      target_name=${target##*:}
      logical_name=${target_name%"$suffix"}
      conventional_name=$logical_name
      case "$conventional_name" in
        *_oci) conventional_name=${conventional_name%_oci} ;;
      esac

      if [ "$requested" = "$target" ]; then
        full_label_matches="$(append_line "$full_label_matches" "$target")"
      fi
      if [ "$requested" = "$target_name" ]; then
        target_name_matches="$(append_line "$target_name_matches" "$target")"
      fi
      if [ "$requested" = "$logical_name" ]; then
        logical_name_matches="$(append_line "$logical_name_matches" "$target")"
      fi
      if [ "$requested" = "$conventional_name" ]; then
        conventional_name_matches="$(append_line "$conventional_name_matches" "$target")"
      fi
    done

    match_tier=""
    matches=""
    if [ -n "$full_label_matches" ]; then
      match_tier="full-label"
      matches=$full_label_matches
    elif [ -n "$target_name_matches" ]; then
      match_tier="generated target-name"
      matches=$target_name_matches
    elif [ -n "$logical_name_matches" ]; then
      match_tier="logical-name"
      matches=$logical_name_matches
    elif [ -n "$conventional_name_matches" ]; then
      match_tier="conventional shorthand"
      matches=$conventional_name_matches
    else
      die "image not found for ${mode}: ${requested}"
    fi

    case "$matches" in
      *'
'*)
        display_matches=$(printf '%s' "$matches" | tr '\n' ' ')
        die "ambiguous image selection for ${mode}: ${requested} matches multiple targets at ${match_tier} tier: ${display_matches}"
        ;;
    esac
    selected="$(append_unique_line "$selected" "$matches")"
  done
  IFS=$old_ifs
fi

build_selected_targets() {
  set -- build "--compilation_mode=$compilation_mode" "--jobs=$bazel_jobs"
  old_ifs=$IFS
  IFS='
'
  for target in $selected; do
    set -- "$@" "$target"
  done
  IFS=$old_ifs
  if [ "$dry_run" -eq 1 ]; then
    print_command "$bazel" "$@"
  else
    "$bazel" "$@"
  fi
}

build_selected_targets

if [ "$mode" = "build" ] || [ "$mode" = "tarball" ]; then
  exit 0
fi

run_push() {
  push_target="$1"
  set -- run "--compilation_mode=$compilation_mode" "$push_target" --
  if [ -n "$repository" ]; then
    set -- "$@" --repository "$repository"
  fi
  old_ifs=$IFS
  IFS='
'
  for push_tag in $tags; do
    set -- "$@" --tag "$push_tag"
  done
  IFS=$old_ifs
  if [ "$dry_run" -eq 1 ]; then
    print_command "$bazel" "$@"
  else
    "$bazel" "$@"
  fi
}

if [ "$dry_run" -eq 1 ]; then
  old_ifs=$IFS
  IFS='
'
  for target in $selected; do
    run_push "$target"
  done
  IFS=$old_ifs
  exit 0
fi

pids=""
running=0
status=0
old_ifs=$IFS
IFS='
'
for target in $selected; do
  run_push "$target" &
  pid=$!
  if [ -z "$pids" ]; then
    pids=$pid
  else
    pids="$pids $pid"
  fi
  running=$((running + 1))
  if [ "$running" -ge "$push_jobs" ]; then
    first=${pids%% *}
    if ! wait "$first"; then
      status=1
    fi
    case "$pids" in
      *' '*) pids=${pids#* } ;;
      *) pids="" ;;
    esac
    running=$((running - 1))
  fi
done
IFS=$old_ifs

while [ -n "$pids" ]; do
  first=${pids%% *}
  if ! wait "$first"; then
    status=1
  fi
  case "$pids" in
    *' '*) pids=${pids#* } ;;
    *) pids="" ;;
  esac
done
exit "$status"
