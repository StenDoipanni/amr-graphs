#!/bin/bash
#SBATCH --job-name=amr2fred-smoke
#SBATCH --partition=rome
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=00:15:00
#SBATCH --output=logs/%x_%j.out
#SBATCH --error=logs/%x_%j.err
#
# CPU-only smoke test for the amr-graphs (py_amr2fred fork) pipeline.
#
# The pipeline currently has no local ML model to run on GPU: it calls
# remote CNR/Uniroma1 HTTP+SPARQL services for the actual AMR-parsing (SPRING)
# and WSD (EWISER/USeA) models. So this job just needs a CPU node with
# outbound internet access — no --partition=gpu_h100 needed (yet).
#
# NOTE: verify the partition name below is correct for your account with
# `sinfo -o "%P %l %D"` before running — Snellius partition names/limits can
# change between allocations.
#
# Usage:
#   sbatch scripts/sbatch/smoke_test.sbatch          # fast path only
#   SMOKE_FULL=1 sbatch scripts/sbatch/smoke_test.sbatch  # + full post-processing
#                                                          (downloads ~832MB/1.8GB
#                                                           Wikidata-mapping DB
#                                                           on first run)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO_ROOT}"
mkdir -p logs

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
