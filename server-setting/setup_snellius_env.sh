#!/bin/bash
# Idempotent Snellius environment setup for amr-graphs (py_amr2fred fork).
#
# This pipeline is currently pure-Python/CPU: it calls remote CNR/Uniroma1
# HTTP + SPARQL services for the actual AMR-parsing and WSD models (SPRING,
# EWISER, USeA) rather than running any local torch/transformers model. So,
# unlike GPU-heavy projects, this env does NOT install torch/CUDA — just the
# small dependency set from requirements.txt.
#
# Usage:
#   bash server-setting/setup_snellius_env.sh [--env <name>]
#
# Examples:
#   bash server-setting/setup_snellius_env.sh                # creates/reuses 'amr2fred'
#   bash server-setting/setup_snellius_env.sh --env myenv    # creates/reuses 'myenv'

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── defaults / arg parsing ────────────────────────────────────────────────────
ENV_NAME="${CONDA_ENV:-amr2fred}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --env)   ENV_NAME="$2"; shift 2 ;;
        -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# ── modules (soft — skipped on non-Snellius clusters) ─────────────────────────
module load 2025 2>/dev/null || echo "[WARN] '2025' module not available (non-Snellius?)"

echo "==> Target conda env: ${ENV_NAME}"

if ! command -v conda >/dev/null 2>&1; then
    echo "[FAIL] conda not found on PATH." >&2
    exit 1
fi

# ── locate / create the env ────────────────────────────────────────────────────
if conda env list | grep -q "^${ENV_NAME} "; then
    CONDA_PREFIX_DIR="$(conda env list | grep "^${ENV_NAME} " | awk '{print $NF}')"
    echo "==> Env '${ENV_NAME}' already exists at ${CONDA_PREFIX_DIR}"
else
    CONDA_PREFIX_DIR="$(conda info --base)/envs/${ENV_NAME}"
    echo "==> Env '${ENV_NAME}' does not exist; creating it (python=3.11)..."
    conda create -n "${ENV_NAME}" python=3.11 -y
fi

PYTHON_BIN="${CONDA_PREFIX_DIR}/bin/python"
echo "==> Using: ${PYTHON_BIN}"

# ── install pipeline dependencies ──────────────────────────────────────────────
echo "==> Installing dependencies from requirements.txt..."
"${PYTHON_BIN}" -m pip install -r "${REPO_ROOT}/requirements.txt"

# ── pre-fetch the NLTK corpus the pipeline needs at import time ───────────────
# taf_post_processor.py calls nltk.download('wordnet') on import; doing it here
# (on the login node, which definitely has internet) avoids relying on compute
# nodes reaching nltk's download servers.
echo "==> Pre-fetching NLTK 'wordnet' corpus..."
"${PYTHON_BIN}" -c "import nltk; nltk.download('wordnet')"

# ── verification ───────────────────────────────────────────────────────────────
echo ""
echo "==> Verifying environment..."
"${PYTHON_BIN}" - <<'PY'
import sys
from importlib.metadata import version as pkg_version

ok = True

def check(label, fn):
    global ok
    try:
        v = fn()
        print(f"  [OK]   {label}: {v}")
    except Exception as e:
        ok = False
        print(f"  [FAIL] {label}: {e}")

# Use importlib.metadata for the version string rather than each module's own
# __version__ attribute — several small packages (unidecode, wikimapper)
# don't define one, which would otherwise read as a false failure even
# though the import and the package itself are fine.
check("python", lambda: sys.version.split()[0])
check("unidecode", lambda: (__import__("unidecode"), pkg_version("Unidecode"))[1])
check("requests", lambda: (__import__("requests"), pkg_version("requests"))[1])
check("nltk", lambda: (__import__("nltk"), pkg_version("nltk"))[1])
check("rdflib", lambda: (__import__("rdflib"), pkg_version("rdflib"))[1])
check("SPARQLWrapper", lambda: (__import__("SPARQLWrapper"), pkg_version("SPARQLWrapper"))[1])
check("wikimapper", lambda: (__import__("wikimapper"), pkg_version("wikimapper"))[1])
check("tqdm", lambda: (__import__("tqdm"), pkg_version("tqdm"))[1])

try:
    from nltk.corpus import wordnet
    wordnet.synsets("test")
    print("  [OK]   nltk wordnet corpus loadable")
except Exception as e:
    ok = False
    print(f"  [FAIL] nltk wordnet corpus: {e}")

if not ok:
    print("  [FAIL] Environment verification failed.")
    raise SystemExit(1)
PY

echo ""
echo "==> Done. Environment '${ENV_NAME}' is ready."
echo "    Run on Snellius:   sbatch scripts/sbatch/smoke_test.sbatch"
