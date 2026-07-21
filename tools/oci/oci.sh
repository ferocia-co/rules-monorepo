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
  --push-execution MODE
                     Push launcher execution: direct or bazel-run (default: direct).
                     bazel-run is the rollback path; push-only.
  --compilation-mode MODE
                     Bazel compilation mode: fastbuild, dbg, or opt (default: opt).
  --profile PATH     Write a Bazel JSON trace profile for the batch build.
  --execution-log PATH
                     Write a compact Bazel execution log for the batch build.
  --build-event-json PATH
                     Write a JSON Build Event Protocol file for the batch build.
                     Each output option may be specified only once.
  --dry-run          Query and resolve launchers, but only print build/push operations.
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
push_execution="direct"
push_execution_set=0
compilation_mode="opt"
profile_path=""
execution_log_path=""
build_event_json_path=""
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
    --push-execution)
      [ "$#" -ge 2 ] || die "--push-execution requires a value"
      push_execution="$2"
      case "$push_execution" in
        direct|bazel-run) ;;
        *) die "--push-execution must be one of direct or bazel-run" ;;
      esac
      push_execution_set=1
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
    --profile)
      [ "$#" -ge 2 ] || die "--profile requires a path"
      [ -n "$2" ] || die "--profile requires a path"
      case "$2" in
        --*) die "--profile requires a path" ;;
      esac
      [ -z "$profile_path" ] || die "--profile may only be specified once"
      profile_path="$2"
      shift 2
      ;;
    --execution-log)
      [ "$#" -ge 2 ] || die "--execution-log requires a path"
      [ -n "$2" ] || die "--execution-log requires a path"
      case "$2" in
        --*) die "--execution-log requires a path" ;;
      esac
      [ -z "$execution_log_path" ] || die "--execution-log may only be specified once"
      execution_log_path="$2"
      shift 2
      ;;
    --build-event-json)
      [ "$#" -ge 2 ] || die "--build-event-json requires a path"
      [ -n "$2" ] || die "--build-event-json requires a path"
      case "$2" in
        --*) die "--build-event-json requires a path" ;;
      esac
      [ -z "$build_event_json_path" ] || die "--build-event-json may only be specified once"
      build_event_json_path="$2"
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
[ "$mode" = "push" ] || [ "$push_execution_set" -eq 0 ] || die "--push-execution is only valid in push mode"
[ -z "$profile_path" ] || [ "$profile_path" != "$execution_log_path" ] || die "profiling output paths must be distinct"
[ -z "$profile_path" ] || [ "$profile_path" != "$build_event_json_path" ] || die "profiling output paths must be distinct"
[ -z "$execution_log_path" ] || [ "$execution_log_path" != "$build_event_json_path" ] || die "profiling output paths must be distinct"

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
  if [ "$mode" = "push" ] && [ "$push_execution" = "direct" ]; then
    # Direct launchers need their executable, manifest, and runfiles available
    # locally even when a remote cache or executor served the build.
    set -- "$@" --remote_download_outputs=all
  fi
  if [ -n "$profile_path" ]; then
    set -- "$@" "--profile=$profile_path"
  fi
  if [ -n "$execution_log_path" ]; then
    set -- "$@" "--execution_log_compact_file=$execution_log_path"
  fi
  if [ -n "$build_event_json_path" ]; then
    set -- "$@" "--build_event_json_file=$build_event_json_path"
  fi
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

labels_match() {
  expected_label="$1"
  resolved_label="$2"

  [ "$expected_label" = "$resolved_label" ] && return 0
  case "$expected_label" in
    //*) [ "$resolved_label" = "@@${expected_label}" ] ;;
    @*//*)
      # cquery stringifies external labels canonically (for example
      # @@repo+//pkg:target), while query may return an apparent @repo label.
      # The selected query contains only the exact requested targets. Matching
      # their package/target suffix is safe as long as it is unique; the caller
      # rejects ambiguous matches before any launcher runs.
      expected_suffix=${expected_label#*//}
      resolved_suffix=${resolved_label#*//}
      [ "$expected_suffix" = "$resolved_suffix" ]
      ;;
    *) return 1 ;;
  esac
}

resolve_direct_launch_plan() {
  cquery_expression="set("
  old_ifs=$IFS
  IFS='
'
  for target in $selected; do
    cquery_expression="${cquery_expression}${target} "
  done
  IFS=$old_ifs
  cquery_expression="${cquery_expression})"
  starlark_expression='str(target.label) + "\t" + providers(target)["DefaultInfo"].files_to_run.executable.path'

  if ! resolved_launchers=$("$bazel" cquery \
    "--compilation_mode=$compilation_mode" \
    --remote_download_outputs=all \
    "$cquery_expression" \
    --output=starlark \
    "--starlark:expr=$starlark_expression"); then
    die "failed to resolve push launchers with cquery"
  fi
  [ -n "$resolved_launchers" ] || die "cquery returned no push launchers"

  if ! execution_root=$("$bazel" info execution_root); then
    die "failed to resolve Bazel execution root"
  fi
  case "$execution_root" in
    /*) ;;
    *) die "Bazel execution root is not an absolute path: ${execution_root}" ;;
  esac

  tab=$(printf '\t')
  launch_plan=""
  resolved_count=0
  IFS='
'
  for resolved_entry in $resolved_launchers; do
    resolved_label=${resolved_entry%%"$tab"*}
    executable_path=${resolved_entry#*"$tab"}
    [ "$resolved_label" != "$resolved_entry" ] || die "invalid cquery launcher record: ${resolved_entry}"
    [ -n "$resolved_label" ] || die "cquery returned a launcher without a target label"
    [ -n "$executable_path" ] || die "cquery returned an empty launcher path for ${resolved_label}"
    resolved_count=$((resolved_count + 1))
  done

  selected_count=0
  for target in $selected; do
    selected_count=$((selected_count + 1))
    matching_count=0
    matching_path=""
    for resolved_entry in $resolved_launchers; do
      resolved_label=${resolved_entry%%"$tab"*}
      executable_path=${resolved_entry#*"$tab"}
      if labels_match "$target" "$resolved_label"; then
        matching_count=$((matching_count + 1))
        matching_path=$executable_path
      fi
    done
    [ "$matching_count" -gt 0 ] || die "cquery did not return a launcher for ${target}"
    [ "$matching_count" -eq 1 ] || die "cquery returned multiple launchers for ${target}"

    case "$matching_path" in
      /*) launcher=$matching_path ;;
      *) launcher="${execution_root}/${matching_path}" ;;
    esac

    for existing_entry in $launch_plan; do
      existing_launcher=${existing_entry#*"$tab"}
      [ "$existing_launcher" != "$launcher" ] || die "multiple push targets resolved to launcher ${launcher}"
    done
    if [ "$dry_run" -eq 0 ]; then
      [ -f "$launcher" ] || die "push launcher does not exist after build: ${launcher}"
      [ -x "$launcher" ] || die "push launcher is not executable after build: ${launcher}"
    fi
    launch_plan="$(append_line "$launch_plan" "${target}${tab}${launcher}")"
  done
  IFS=$old_ifs

  [ "$resolved_count" -eq "$selected_count" ] || die "cquery returned ${resolved_count} launchers for ${selected_count} selected targets"

  # Reject unexpected cquery results as well as missing ones. In particular,
  # this catches apparent/canonical external-repository collisions safely.
  IFS='
'
  for resolved_entry in $resolved_launchers; do
    resolved_label=${resolved_entry%%"$tab"*}
    matching_count=0
    for target in $selected; do
      if labels_match "$target" "$resolved_label"; then
        matching_count=$((matching_count + 1))
      fi
    done
    [ "$matching_count" -eq 1 ] || die "cquery result does not uniquely match a selected target: ${resolved_label}"
  done
  IFS=$old_ifs
}

print_push() {
  push_target="$1"
  launcher="$2"
  if [ "$push_execution" = "direct" ]; then
    set -- "$launcher"
  else
    set -- "$bazel" run "--compilation_mode=$compilation_mode" "$push_target" --
  fi
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
  if [ "$push_execution" = "direct" ]; then
    printf '# direct push %s\n' "$push_target"
  fi
  print_command "$@"
}

if [ "$dry_run" -eq 1 ]; then
  if [ "$push_execution" = "direct" ]; then
    resolve_direct_launch_plan
  fi
  old_ifs=$IFS
  IFS='
'
  if [ "$push_execution" = "direct" ]; then
    for plan_entry in $launch_plan; do
      target=${plan_entry%%"$tab"*}
      launcher=${plan_entry#*"$tab"}
      print_push "$target" "$launcher"
    done
  else
    for target in $selected; do
      print_push "$target" ""
    done
  fi
  IFS=$old_ifs
  exit 0
fi

pids=""
running=0
status=0

terminate_children() {
  children=$pids
  old_cleanup_ifs=$IFS
  IFS=' '
  for child in $children; do
    kill -TERM "$child" 2>/dev/null || true
  done
  for child in $children; do
    wait "$child" 2>/dev/null || true
  done
  IFS=$old_cleanup_ifs
  pids=""
}

handle_signal() {
  signal_status="$1"
  trap - HUP INT TERM
  terminate_children
  exit "$signal_status"
}

trap 'handle_signal 129' HUP
trap 'handle_signal 130' INT
trap 'handle_signal 143' TERM

schedule_push() {
  push_target="$1"
  launcher="$2"
  if [ "$push_execution" = "direct" ]; then
    set -- "$launcher"
  else
    set -- "$bazel" run "--compilation_mode=$compilation_mode" "$push_target" --
  fi
  if [ -n "$repository" ]; then
    set -- "$@" --repository "$repository"
  fi
  old_schedule_ifs=$IFS
  IFS='
'
  for push_tag in $tags; do
    set -- "$@" --tag "$push_tag"
  done
  IFS=$old_schedule_ifs

  # Start the external command from this shell instead of backgrounding a
  # function. That makes $! the launcher/Bazel client itself on every supported
  # shell, so signal cleanup never targets an intermediate subshell.
  "$@" &
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
}

if [ "$push_execution" = "direct" ]; then
  resolve_direct_launch_plan
fi

old_ifs=$IFS
IFS='
'
if [ "$push_execution" = "direct" ]; then
  for plan_entry in $launch_plan; do
    target=${plan_entry%%"$tab"*}
    launcher=${plan_entry#*"$tab"}
    schedule_push "$target" "$launcher"
  done
else
  for target in $selected; do
    schedule_push "$target" ""
  done
fi
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
trap - HUP INT TERM
exit "$status"
