#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <test_script.sh> [args ...]" >&2
  exit 2
}

format_hms() {
  local t=${1:-0}
  printf '%02d:%02d:%02d' $((t/3600)) $(((t%3600)/60)) $((t%60))
}

next_output_dir() {
  local base=${1:-output}
  local max=0
  local d n

  shopt -s nullglob
  for d in "$base"-*; do
    [[ -d "$d" ]] || continue
    n=${d##*-}
    [[ $n =~ ^[0-9]+$ ]] || continue
    (( n > max )) && max=$n
  done
  shopt -u nullglob

  echo "$base-$((max + 1))"
}

summarize_logs() {
  shopt -s nullglob
  local files=(*.log)
  shopt -u nullglob

  if ((${#files[@]} == 0)); then
    echo "No .log files found."
    return
  fi

  local lines
  lines=$(
    awk '/completed in| - Starting/ {
      ts = substr($0, 1, 23)
      msg = $0
      sub(/^.* - /, "", msg)
      print ts "\t" msg
    }' "${files[@]}" | sort -k1,1
  )

  if [[ -n "$lines" ]]; then
    printf '%s\n' "$lines"
  else
    echo "No lines matching completed in found."
  fi
}

run_with_profile() {
  local profile_file=$1
  shift

  # GNU time supports --version and -f
  if /usr/bin/time --version >/dev/null 2>&1; then
    /usr/bin/time -f "real %e\nuser %U\nsys %S\nmaxrss_kb %M" -o "$profile_file" "$@"
  else
    # BSD/macOS time
    /usr/bin/time -lp -o "$profile_file" "$@"
  fi
}

tree_rss_kib() {
  local root_pid="$1"
  ps -axo pid=,ppid=,rss= | awk -v root="$root_pid" '
    {
      pid=$1; ppid=$2; r=$3
      rss[pid]=r
      kids[ppid]=kids[ppid] " " pid
    }
    END {
      top=1
      stack[1]=root
      seen[root]=1
      total=0

      while (top > 0) {
        p=stack[top--]
        total += (rss[p] + 0)

        n=split(kids[p], arr, " ")
        for (i=1; i<=n; i++) {
          c=arr[i]
          if (c != "" && !seen[c]) {
            seen[c]=1
            stack[++top]=c
          }
        }
      }

      print total + 0
    }
  '
}

monitor_tree_peak() {
  local root_pid="$1"
  local out_file="$2"
  local interval="${3:-0.5}"
  local peak_kib=0
  local peak_ts=""

  while kill -0 "$root_pid" 2>/dev/null; do
    cur_kib="$(tree_rss_kib "$root_pid" 2>/dev/null || echo 0)"
    if [[ "$cur_kib" =~ ^[0-9]+$ ]] && (( cur_kib > peak_kib )); then
      peak_kib="$cur_kib"
      peak_ts="$(date '+%Y-%m-%d %H:%M:%S')"
    fi
    sleep "$interval"
  done

  peak_mib="$(awk -v k="$peak_kib" 'BEGIN{printf "%.2f", k/1024}')"
  {
    echo "peak_tree_rss_mib: $peak_mib"
    echo "peak_seen_at:      $peak_ts"
  } > "$out_file"
}

append_tree_memory_profile() {
  local tree_profile_file="${1:-tree_rss.profile}"
  if [[ -s "$tree_profile_file" ]]; then
    cat "$tree_profile_file"
  else
    echo "No tree memory profile found."
  fi
}

append_resource_profile() {
  local profile_file=${1:-run.profile}

  if [[ ! -s "$profile_file" ]]; then
    echo "No resource profile found."
    return
  fi

  local real_s user_s sys_s maxrss_raw max_rss_kib max_rss_bytes max_rss_mib cpu_pct os_name
  real_s=$(awk '/^real / {print $2; exit}' "$profile_file")
  user_s=$(awk '/^user / {print $2; exit}' "$profile_file")
  sys_s=$(awk '/^sys /  {print $2; exit}' "$profile_file")

  real_s=${real_s:-0}
  user_s=${user_s:-0}
  sys_s=${sys_s:-0}

  cpu_pct=$(awk -v u="$user_s" -v s="$sys_s" -v r="$real_s" 'BEGIN{
    if (r > 0) printf "%.1f", ((u + s) / r) * 100;
    else print "0.0";
  }')

  echo "real_s:       $real_s"
  echo "user_s:       $user_s"
  echo "sys_s:        $sys_s"
  echo "cpu_pct_est:  $cpu_pct"
}

run_profile() {
  local test_script=${1:-}
  shift || true

  [[ -n "$test_script" ]] || usage
  [[ -f "$test_script" ]] || { echo "Script not found: $test_script" >&2; exit 2; }

  local root_dir script_abs out_base outdir start_epoch end_epoch elapsed exit_code
  local cmdline
  root_dir=$(pwd)
  script_abs=$(cd "$(dirname "$test_script")" && pwd)/$(basename "$test_script")

  # Build exact command string with shell-safe quoting
  printf -v cmdline '%q ' bash "$script_abs" "$@"
  cmdline=${cmdline% }

  out_base=$(basename "$test_script")
  out_base=${out_base%.sh}
  outdir=$(next_output_dir "runs/$out_base")

  mkdir -p "$outdir"
  start_epoch=$(date +%s)

  (
    cd "$outdir"

    set +e
    run_with_profile run.profile bash "$script_abs" "$@" &
    timed_pid=$!

    monitor_tree_peak "$timed_pid" tree_rss.profile 0.5 &
    mon_pid=$!

    wait "$timed_pid"
    exit_code=$?

    wait "$mon_pid" || true
    set -e

    end_epoch=$(date +%s)
    elapsed=$((end_epoch - start_epoch))

    {
      echo
      echo "------------------SUMMARY------------------"
      summarize_logs
      echo
      echo "------------------PROFILE------------------"
      printf 'Command: %s\n' "$cmdline"
      printf 'Overall wall time: %s (%ss)\n' "$(format_hms "$elapsed")" "$elapsed"
      printf 'Exit code: %s\n' "$exit_code"
      echo "--------------------CPU--------------------"
      append_resource_profile run.profile
      echo "-------------------MEMORY------------------"
      append_tree_memory_profile tree_rss.profile
      echo "-------------------------------------------"
    } | tee summary.log

    exit "$exit_code"
  )
}

self_test() {
  local profile_file
  profile_file=$(mktemp /tmp/_run_profile_selftest.XXXXXX)
  run_with_profile "$profile_file" sleep 1
  append_resource_profile "$profile_file"
  rm -f "$profile_file"
}

if [[ $# -eq 0 ]]; then
  echo "No script provided, running self-test." >&2
  self_test
else
  run_profile "$@"
fi