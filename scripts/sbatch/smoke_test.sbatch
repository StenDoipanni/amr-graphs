#!/bin/bash
#SBATCH --job-name=amr2fred-smoke
#SBATCH --partition=staging
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --time=00:15:00
#SBATCH --output=logs/%x_%j.out
#SBATCH --error=logs/%x_%j.err
#
# CPU-only smoke test for the amr-graphs (py_amr2fred fork) pipeline.
#
# The pipeline currently has no local ML model to run on GPU: it calls
# remote CNR/Uniroma1 HTTP+SPARQL services for the actual AMR-parsing (SPRING)
# and WSD (EWISER/USeA) models. It needs outbound internet access, which
# regular compute partitions (rome/genoa) typically don't have — the
# `staging` partition is the one meant for external data transfer, and is
# also what this account's budget (accinfo: cbuild, gpu_a100, gpu_h100,
# gpu_mig, gpu_vis, staging) actually grants.
#
# Once local GPU models replace the remote API calls, switch --partition to
# gpu_h100/gpu_a100 and add --gpus=1 (or similar) — those are also in this
# account's budget, `staging` is not appropriate for GPU compute.
#
# Usage:
#   sbatch scripts/sbatch/smoke_test.sbatch          # fast path only
#   SMOKE_FULL=1 sbatch scripts/sbatch/smoke_test.sbatch  # + full post-processing
#                                                          (downloads ~832MB/1.8GB
#                                                           Wikidata-mapping DB
#                                                           on first run)

set -euo pipefail

# Slurm copies the submitted script into a spool directory and runs that
# copy, so ${BASH_SOURCE[0]} inside the job points there, not at this file's
# real location in the repo — use $SLURM_SUBMIT_DIR (the directory `sbatch`
# was invoked from) instead, falling back to $PWD for manual/local runs.
REPO_ROOT="${SLURM_SUBMIT_DIR:-$PWD}"
cd "${REPO_ROOT}"
# Slurm already creates logs/ itself to satisfy --output/--error above; this
# is just a defensive no-op for local/manual runs, and must never abort the
# job if it hits a transient permission/filesystem hiccup re-touching a path
# Slurm just created.
mkdir -p logs 2>/dev/null || true

ENV_NAME="${CONDA_ENV:-amr2fred}"

module load 2025 2>/dev/null || echo "[WARN] '2025' module not available"

# shellcheck disable=SC1091
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate "${ENV_NAME}"

export PYTHONPATH="${REPO_ROOT}${PYTHONPATH:+:${PYTHONPATH}}"

echo "==> Host: $(hostname)"
echo "==> Python: $(which python) ($(python --version))"
echo "==> SMOKE_FULL=${SMOKE_FULL:-0}"

python scripts/smoke_test.py
