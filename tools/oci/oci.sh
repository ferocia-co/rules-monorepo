#!/bin/sh
set -eu

usage() {
  cat <<'EOF'
Usage: oci <build|tarball|push> [options]

Discover and operate on rules_monorepo OCI targets by their standard tags.

Options:
  --bazel PATH       Call this repository Bazel wrapper (default: bazelisk).
  --scope QUERY      Query scope (default: //...).
  --image NAME       Select a logical image name or target; repeatable.
  --all              Select every discovered image.
  --repository REPO  Override the repository for every push target; push-only.
  --tag TAG          Add a runtime push tag; repeatable and push-only.
  --jobs N           Maximum Bazel jobs/push processes (default: 4).
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
jobs=4
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
      tags="$(append_line "$tags" "$2")"
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
      jobs="$2"
      case "$jobs" in
        ''|*[!0-9]*|0) die "--jobs requires a positive integer" ;;
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

[ -n "$mode" ] || die "a build, tarball, or push mode is required"
[ "$select_all" -eq 0 ] || [ -z "$images" ] || die "--all and --image are mutually exclusive"
[ "$select_all" -eq 1 ] || [ -n "$images" ] || die "select --all or at least one --image"
[ "$mode" = "push" ] || [ -z "$tags" ] || die "--tag is only valid in push mode"
[ "$mode" = "push" ] || [ -z "$repository" ] || die "--repository is only valid in push mode"

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

query="attr(tags, '${query_tag}', ${scope})"
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
    found=0
    for target in $discovered; do
      target_name=${target##*:}
      logical_name=${target_name%"$suffix"}
      case "$requested" in
        "$target"|"$target_name"|"$logical_name")
          if ! printf '%s\n' "$selected" | grep -Fqx "$target"; then
            selected="$(append_line "$selected" "$target")"
          fi
          found=1
          ;;
      esac
    done
    [ "$found" -eq 1 ] || die "image not found for ${mode}: ${requested}"
  done
  IFS=$old_ifs
fi

if [ "$mode" = "build" ] || [ "$mode" = "tarball" ]; then
  set -- build "--jobs=$jobs"
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
  exit 0
fi

run_push() {
  push_target="$1"
  set -- run "$push_target" --
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
  if [ "$running" -ge "$jobs" ]; then
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
