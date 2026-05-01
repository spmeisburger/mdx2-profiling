#!/usr/bin/env bash
set -e

# Same as insulin.integrate.sh, but labeled so that
# it's clear it was run using a feature branch of mdx2.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
processed_data_dir="${SCRIPT_DIR}/processed_data/insulin_mdx2_dev"

[[ -d "$processed_data_dir" ]] || { echo "Error: missing processed dataset: $processed_data_dir" >&2; exit 1; }

ln -s "$processed_data_dir/datastore" datastore

mdx2.integrate \
  "$processed_data_dir/geometry.nxs" \
  "$processed_data_dir/data.nxs" \
  --mask "$processed_data_dir/mask.nxs" \
  --subdivide 2 2 2 \
   "$@" # --nproc 1

# do some cleanup
rm *.nxs
rm datastore