"""
Smoke test for the amr-graphs (py_amr2fred) pipeline on a Snellius compute node.

This pipeline calls remote CNR/Uniroma1 HTTP + SPARQL services for the actual
AMR-parsing and WSD models (SPRING, EWISER, USeA) — nothing runs locally on
GPU/CPU except plain Python. So the main open question for a compute node
(as opposed to the login node) is simply: does it have outbound internet
access to reach those services.

Steps:
  1. Check outbound connectivity to each remote endpoint the pipeline uses.
  2. Run translate() with post_processing=False (fast path, no big downloads).
  3. Optionally (SMOKE_FULL=1 env var) run translate() with post_processing=True,
     which triggers WSD + a ~832MB/1.8GB Wikidata-mapping DB download on first use.
"""

import os
import sys

import requests

from py_amr2fred import Amr2fred, Glossary

ENDPOINTS = [
    "https://arco.istc.cnr.it/spring/text-to-amr",
    "https://nlp.uniroma1.it/spring/api/text-to-amr",
    "https://arco.istc.cnr.it/usea/api/amr",
    "https://arco.istc.cnr.it/ewiser/wsd",
    "https://arco.istc.cnr.it/usea/api/preprocessing",
    "http://etna.istc.cnr.it/framester2/sparql",
]

SAMPLE_TEXT = "Four boys making pies"


def check_connectivity() -> bool:
    print("== Step 1: outbound connectivity check ==")
    all_ok = True
    for url in ENDPOINTS:
        try:
            requests.head(url, timeout=10)
            print(f"  [OK]   reachable: {url}")
        except Exception as e:
            all_ok = False
            print(f"  [FAIL] unreachable: {url} ({e})")
    return all_ok


def run_basic_translate() -> bool:
    print("\n== Step 2: translate() without post-processing ==")
    try:
        amr2fred = Amr2fred()
        result = amr2fred.translate(
            text=SAMPLE_TEXT,
            serialize=True,
            mode=Glossary.RdflibMode.TURTLE,
            post_processing=False,
        )
        print(f"  [OK]   got {len(result)} chars of Turtle output")
        print("  ---- output (truncated) ----")
        print(result[:1000])
        return True
    except Exception as e:
        print(f"  [FAIL] translate() raised: {e}")
        return False


def run_full_translate() -> bool:
    print("\n== Step 3: translate() with full post-processing ==")
    try:
        amr2fred = Amr2fred()
        result = amr2fred.translate(
            text=SAMPLE_TEXT,
            serialize=True,
            mode=Glossary.RdflibMode.TURTLE,
            post_processing=True,
        )
        print(f"  [OK]   got {len(result)} chars of Turtle output")
        print("  ---- output (truncated) ----")
        print(result[:1000])
        return True
    except Exception as e:
        print(f"  [FAIL] translate() raised: {e}")
        return False


def main() -> int:
    connectivity_ok = check_connectivity()
    basic_ok = run_basic_translate()

    full_ok = True
    if os.environ.get("SMOKE_FULL") == "1":
        full_ok = run_full_translate()
    else:
        print("\n== Step 3: skipped (set SMOKE_FULL=1 to run full post-processing) ==")

    print("\n== Summary ==")
    print(f"  connectivity: {'OK' if connectivity_ok else 'FAIL (some endpoints unreachable)'}")
    print(f"  basic translate: {'OK' if basic_ok else 'FAIL'}")
    if os.environ.get("SMOKE_FULL") == "1":
        print(f"  full translate: {'OK' if full_ok else 'FAIL'}")

    return 0 if (basic_ok and full_ok) else 1


if __name__ == "__main__":
    sys.exit(main())
