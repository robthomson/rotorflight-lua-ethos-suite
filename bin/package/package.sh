#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

if [[ "${1-}" == "--help" || "${1-}" == "-h" ]]; then
  cat <<'EOF'
Usage: package.sh [lang] [artifact-version] [extra build_package.py args...]

Defaults:
  lang             en
  artifact-version local-test
  build-root       REPO_ROOT/build/package
  output-dir       REPO_ROOT/build/test-output

Examples:
  ./package.sh
  ./package.sh en 2.3.0
  ./package.sh fr 2.3.0-20260208 --release-notes-file /tmp/Notes.md
EOF
  exit 0
fi

LANGUAGE="${1:-en}"
ARTIFACT_VERSION="${2:-local-test}"

if [[ $# -gt 0 ]]; then
  shift
fi
if [[ $# -gt 0 ]]; then
  shift
fi

OUTPUT_DIR="${REPO_ROOT}/build/test-output"
BUILD_ROOT="${REPO_ROOT}/build/package"
export PYTHONUTF8=1
export PYTHONIOENCODING=utf-8

if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="python3"
else
  PYTHON_BIN="python"
fi

echo "[package] language=${LANGUAGE}"
echo "[package] artifact-version=${ARTIFACT_VERSION}"

exec "${PYTHON_BIN}" "${SCRIPT_DIR}/build_package.py" \
  --lang "${LANGUAGE}" \
  --artifact-version "${ARTIFACT_VERSION}" \
  --build-root "${BUILD_ROOT}" \
  --output-dir "${OUTPUT_DIR}" \
  "$@"
