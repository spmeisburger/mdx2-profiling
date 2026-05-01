#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
processed_data_dir="${SCRIPT_DIR}/processed_data"

[[ -d "$processed_data_dir" ]] || { echo "Error: missing processed_data directory: $processed_data_dir" >&2; exit 1; }

# process the crystal data

ln -s "$processed_data_dir/insulin_mdx2_1_0_3/datastore" datastore

mdx2.find_peaks \
  "$processed_data_dir/insulin_mdx2_1_0_3/geometry.nxs" \
  "$processed_data_dir/insulin_mdx2_1_0_3/data.nxs" \
  --count_threshold 20 \
   "$@" # --nproc 1

# do some cleanup
rm *.nxs
rm datastore