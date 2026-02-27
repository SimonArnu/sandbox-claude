#!/usr/bin/env bash
# tests/test_helper/integration.bash — Helpers for integration tests

TEST_HELPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
load "${TEST_HELPER_DIR}/common.bash"

# Generate a unique test container name to avoid collisions
# Uses BATS_TEST_FILENAME basename + PID for uniqueness
_test_suite_name() {
  basename "${BATS_TEST_FILENAME}" .bats | tr '_' '-'
}

TEST_CONTAINER_PREFIX="test-$$"

# Create a test container. Pass extra flags as arguments.
# Usage: create_test_container [--restrict-domains] [--domains-file /path]
# Sets TEST_CONTAINER_NAME for use in tests.
create_test_container() {
  local suite
  suite=$(_test_suite_name)
  TEST_CONTAINER_NAME="${TEST_CONTAINER_PREFIX}-${suite}"

  "${PROJECT_ROOT}/bin/sandbox-create" "$TEST_CONTAINER_NAME" --stack base "$@"

  # Wait for networking to be ready (container just started)
  local attempts=0
  while ! vm_exec "incus exec agent-${TEST_CONTAINER_NAME} -- ip addr show eth0 2>/dev/null | grep -q 'inet '" 2>/dev/null; do
    attempts=$((attempts + 1))
    if (( attempts > 30 )); then
      echo "Timed out waiting for container networking" >&2
      return 1
    fi
    sleep 1
  done
}

# Get the container's IPv4 address
get_container_ip() {
  vm_exec "
    incus list agent-${TEST_CONTAINER_NAME} -f csv -c 4 2>/dev/null \
      | grep -oE '10\.[0-9]+\.[0-9]+\.[0-9]+' | head -1
  "
}

# Destroy the test container (stop + rm)
destroy_test_container() {
  if [[ -n "${TEST_CONTAINER_NAME:-}" ]]; then
    "${PROJECT_ROOT}/bin/sandbox-stop" "$TEST_CONTAINER_NAME" --rm 2>/dev/null || true
  fi
}

# Execute a command inside the test container
container_exec() {
  vm_run incus exec "agent-${TEST_CONTAINER_NAME}" -- "$@"
}
