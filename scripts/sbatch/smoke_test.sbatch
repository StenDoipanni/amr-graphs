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
