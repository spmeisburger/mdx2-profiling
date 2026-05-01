# regression_tests

Small regression/profiling scripts for mdx2 and dials workflows.

## Prerequisites

- Bash
- `dials.*` commands on `PATH`
- `mdx2.*` commands on `PATH`
- Local data directories reconstructed in this repo:
  - `data/`
  - `processed_data/`

These scripts now derive paths from each script location, so they work from any clone path and any current working directory.

## Expected layout

- `data/insulin_2_1_10deg/...`
- `data/mac1_1_10deg/...`
- `processed_data/insulin_mdx2_1_0_3/...`
- `processed_data/insulin_mdx2_dev/...`
- `processed_data/mac1_1_mdx2_1_0_3/...`

## Smoke tests

From this directory:

```bash
./run_profile.sh insulin_import_data.sh --nproc 4
./run_profile.sh insulin_find_peaks.sh --nproc 4
./run_profile.sh insulin_e2e.sh --nproc 4
```

`run_profile.sh` writes outputs under `runs/`.

## Reconstructing data

A future `fetch_data.sh` script can recreate `data/` and `processed_data/` in the structure above.
