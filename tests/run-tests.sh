#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Check BATS is installed
if ! command -v bats &>/dev/null; then
  echo "Error: bats-core is not installed."
  echo "  macOS:  brew install bats-core"
  echo "  Linux:  apt install bats (or see https://github.com/bats-core/bats-core)"
  exit 1
fi

# Check helper libraries
if [ ! -d "${SCRIPT_DIR}/test_helper/bats-support" ] || [ ! -d "${SCRIPT_DIR}/test_helper/bats-assert" ]; then
  echo "Error: BATS helper libraries not found. Run:"
  echo "  git clone --depth 1 https://github.com/bats-core/bats-support tests/test_helper/bats-support"
  echo "  git clone --depth 1 https://github.com/bats-core/bats-assert tests/test_helper/bats-assert"
  exit 1
fi

TIER="${1:-all}"

case "$TIER" in
  unit)
    echo "Running unit tests..."
    bats "${SCRIPT_DIR}/unit/"
    ;;
  integration)
    echo "Running integration tests (requires sandbox-setup)..."
    bats "${SCRIPT_DIR}/integration/"
    ;;
  all)
    echo "Running unit tests..."
    bats "${SCRIPT_DIR}/unit/"
    echo ""
    echo "Running integration tests (requires sandbox-setup)..."
    bats "${SCRIPT_DIR}/integration/"
    ;;
  *)
    echo "Usage: $0 [unit|integration|all]"
    exit 1
    ;;
esac
