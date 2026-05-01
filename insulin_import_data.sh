#!/bin/env/bash
set -e

processed_data_dir='/Users/steve/dev/mdx2_tests/regression_tests/processed_data'

# process the crystal data
mdx2.import_data "$processed_data_dir/insulin_mdx2_1_0_3/indexed.expt" "$@"

# do some cleanup
rm -r datastore
rm *.nxs