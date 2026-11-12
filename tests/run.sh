#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash tests/static.sh
bash tests/dispatch.sh
bash tests/lifecycle.sh
echo 'PASS: full suite'
