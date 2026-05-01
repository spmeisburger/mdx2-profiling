#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${SCRIPT_DIR}/data"
INSULIN_DIR="${DATA_DIR}/insulin_2_1_10deg"

[[ -d "$INSULIN_DIR" ]] || { echo "Error: missing data directory: $INSULIN_DIR" >&2; exit 1; }

nproc=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --nproc)
      [[ $# -ge 2 ]] || { echo "Missing value for --nproc" >&2; exit 2; }
      nproc="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

[[ "$nproc" =~ ^[1-9][0-9]*$ ]] || { echo "--nproc must be a positive integer" >&2; exit 2; }

# run DIALS to get the geometry
dials.import "$INSULIN_DIR/insulin_2_1_*.cbf"
dials.import "$INSULIN_DIR/insulin_2_bkg_1_*.cbf" output.experiments=background.expt
dials.find_spots imported.expt nproc=$nproc
dials.index imported.expt strong.refl space_group=I213

# process the background data
mdx2.import_data background.expt --outfile background_data.nxs --nproc $nproc
mdx2.bin_image_series background_data.nxs 2 50 50 --valid_range 0 200 --outfile background_binned.nxs --nproc $nproc

# process the crystal data
mdx2.import_data indexed.expt --nproc $nproc
mdx2.import_geometry indexed.expt
mdx2.find_peaks geometry.nxs data.nxs --count_threshold 20 --nproc $nproc
mdx2.mask_peaks geometry.nxs data.nxs peaks.nxs --nproc $nproc
mdx2.integrate geometry.nxs data.nxs --mask mask.nxs --subdivide 2 2 2 --nproc $nproc

# apply corrections and refine a simple scaling model
mdx2.correct geometry.nxs integrated.nxs --background background_binned.nxs 
mdx2.scale corrected.nxs --mca2020
mdx2.merge corrected.nxs --scale scales.nxs --split randomHalf

# reintegrate on a finer grid
mdx2.reintegrate geometry.nxs data.nxs --scale scales.nxs --mask mask.nxs --subdivide 3 3 3 --background background_binned.nxs --nproc $nproc

# do some cleanup
rm -r datastore
rm *.nxs
rm *.expt
rm *.refl