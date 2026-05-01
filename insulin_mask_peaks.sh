#!/bin/env/bash
set -e

processed_data_dir='/Users/steve/dev/mdx2_tests/regression_tests/processed_data'

ln -s "$processed_data_dir/insulin_mdx2_1_0_3/datastore" datastore

mdx2.mask_peaks \
  "$processed_data_dir/insulin_mdx2_1_0_3/geometry.nxs" \
  "$processed_data_dir/insulin_mdx2_1_0_3/data.nxs" \
  "$processed_data_dir/insulin_mdx2_1_0_3/peaks.nxs" \
   "$@" # --nproc 1

# do some cleanup
rm *.nxs
rm datastore