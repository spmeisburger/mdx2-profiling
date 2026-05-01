#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
processed_data_dir="${SCRIPT_DIR}/processed_data"

[[ -d "$processed_data_dir" ]] || { echo "Error: missing processed_data directory: $processed_data_dir" >&2; exit 1; }

# process the crystal data
mdx2.import_data "$processed_data_dir/insulin_mdx2_1_0_3/indexed.expt" "$@"

# do some cleanup
rm -r datastore
rm *.nxs