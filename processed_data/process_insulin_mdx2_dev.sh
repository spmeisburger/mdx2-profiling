#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DATA_DIR="${ROOT_DIR}/data"
INSULIN_DIR="${DATA_DIR}/insulin_2_1_10deg"

[[ -d "$INSULIN_DIR" ]] || { echo "Error: missing data directory: $INSULIN_DIR" >&2; exit 1; }

# settings
nproc=4
proc_dir='insulin_mdx2_dev'

# verify mdx2 version
if ! command -v mdx2.version &>/dev/null; then
  echo "Error: mdx2.version not found. Check your python environment." >&2
  exit 1
fi

# if directory insulin_mdx2_dev exists, remove its contents, otherwise create it
if [[ -d $proc_dir ]]; then
  echo "Directory $proc_dir already exists, removing contents..." >&2
  rm -rf $proc_dir/*
else
  mkdir $proc_dir
fi

cd $proc_dir

# run DIALS to get the geometry
dials.import "$INSULIN_DIR/insulin_2_1_*.cbf"
#dials.import "$INSULIN_DIR/insulin_2_bkg_1_*.cbf" output.experiments=background.expt
dials.find_spots imported.expt nproc=$nproc
dials.index imported.expt strong.refl space_group=I213

# process the background data
#mdx2.import_data background.expt --outfile background_data.nxs --nproc $nproc
#mdx2.bin_image_series background_data.nxs 2 50 50 --valid_range 0 200 --outfile background_binned.nxs --nproc $nproc

# process the crystal data
mdx2.import_data indexed.expt --nproc $nproc --processing none
mdx2.import_geometry indexed.expt
mdx2.find_peaks geometry.nxs data.nxs --count_threshold 20 --nproc $nproc
mdx2.mask_peaks geometry.nxs data.nxs peaks.nxs --nproc $nproc
mdx2.integrate geometry.nxs data.nxs --mask mask.nxs --subdivide 2 2 2 --nproc $nproc

# apply corrections and refine a simple scaling model
#mdx2.correct geometry.nxs integrated.nxs --background background_binned.nxs 
#mdx2.scale corrected.nxs --mca2020
#mdx2.merge corrected.nxs --scale scales.nxs --split randomHalf

# reintegrate on a finer grid
#mdx2.reintegrate geometry.nxs data.nxs --scale scales.nxs --mask mask.nxs --subdivide 3 3 3 --background background_binned.nxs --nproc $nproc