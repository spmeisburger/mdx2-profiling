#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DATA_DIR="${ROOT_DIR}/data"
MAC1_DIR="${DATA_DIR}/mac1_1_10deg"

[[ -d "$MAC1_DIR" ]] || { echo "Error: missing data directory: $MAC1_DIR" >&2; exit 1; }

# settings
nproc=4
proc_dir='mac1_1_mdx2_1_0_3'
mdx2_version='1.0.3'

# verify mdx2 version
if ! command -v mdx2.version &>/dev/null; then
  echo "Error: mdx2.version not found. Check your python environment." >&2
  exit 1
fi

mdx2_version=$(mdx2.version 2>/dev/null | awk '/^mdx2:/ {print $2}')

if [[ "$mdx2_version" != "$mdx2_version" ]]; then
  echo "Error: expected mdx2 version $mdx2_version, got '${mdx2_version:-unknown}'." >&2
  exit 1
fi

# if directory mac1_1_mdx2_1_0_3 exists, remove its contents, otherwise create it
if [[ -d $proc_dir ]]; then
  echo "Directory $proc_dir already exists, removing contents..." >&2
  rm -rf $proc_dir/*
else
  mkdir $proc_dir
fi

cd $proc_dir

# run DIALS to get the geometry
dials.import "$MAC1_DIR/mac1_1_4796_master.h5" image_range=1,100
dials.import "$MAC1_DIR/mac1_1_bg_4797_master.h5" image_range=1,10 output.experiments=background.expt
dials.find_spots imported.expt nproc=$nproc
dials.index imported.expt strong.refl space_group=P43

# process the background data
mdx2.import_data background.expt --outfile background_data.nxs --nproc $nproc
mdx2.bin_image_series background_data.nxs 5 20 20 --valid_range 0 100 --outfile background_binned.nxs --nproc $nproc

# process the crystal data
mdx2.import_data indexed.expt --nproc $nproc
mdx2.import_geometry indexed.expt
mdx2.find_peaks geometry.nxs data.nxs --count_threshold 10 --nproc $nproc
mdx2.mask_peaks geometry.nxs data.nxs peaks.nxs --nproc $nproc
mdx2.integrate geometry.nxs data.nxs --mask mask.nxs --subdivide 2 2 4 --nproc $nproc

# apply corrections and refine a simple scaling model
mdx2.correct geometry.nxs integrated.nxs --background background_binned.nxs 
mdx2.scale corrected.nxs --mca2020
mdx2.merge corrected.nxs --scale scales.nxs --split randomHalf

# reintegrate on a finer grid
mdx2.reintegrate geometry.nxs data.nxs --scale scales.nxs --mask mask.nxs --subdivide 3 3 6 --background background_binned.nxs --nproc $nproc