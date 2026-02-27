#!/usr/bin/env bats
load '../test_helper/integration'

# Persist container names and IP so all tests (which run in subprocesses) share them.
_name_a_file() { echo "${BATS_FILE_TMPDIR}/iso_name_a"; }
_name_b_file() { echo "${BATS_FILE_TMPDIR}/iso_name_b"; }
_ip_b_file()   { echo "${BATS_FILE_TMPDIR}/iso_ip_b"; }

setup_file() {
  local pid="${BATS_ROOT_PID:-$$}"
  local CONTAINER_A_NAME="test-${pid}-iso-a"
  local CONTAINER_B_NAME="test-${pid}-iso-b"

  echo "$CONTAINER_A_NAME" > "$(_name_a_file)"
  echo "$CONTAINER_B_NAME" > "$(_name_b_file)"

  # Create two containers
  "${PROJECT_ROOT}/bin/sandbox-create" "$CONTAINER_A_NAME" --stack base
  "${PROJECT_ROOT}/bin/sandbox-create" "$CONTAINER_B_NAME" --stack base

  # Wait for container B networking to be ready
  local attempts=0
  while ! vm_exec "incus exec agent-${CONTAINER_B_NAME} -- ip addr show eth0 2>/dev/null | grep -q 'inet '" 2>/dev/null; do
    attempts=$((attempts + 1))
    if (( attempts > 30 )); then
      echo "Timed out waiting for container B networking" >&2
      return 1
    fi
    sleep 1
  done

  # Get container B's IP for cross-container tests
  local ip
  ip=$(vm_exec "
    incus list agent-${CONTAINER_B_NAME} -f csv -c 4 2>/dev/null \
      | grep -oE '10\.[0-9]+\.[0-9]+\.[0-9]+' | head -1
  ")
  echo "$ip" > "$(_ip_b_file)"
}

teardown_file() {
  local name_a name_b
  name_a=$(<"$(_name_a_file)")
  name_b=$(<"$(_name_b_file)")
  "${PROJECT_ROOT}/bin/sandbox-stop" "$name_a" --rm 2>/dev/null || true
  "${PROJECT_ROOT}/bin/sandbox-stop" "$name_b" --rm 2>/dev/null || true
}

# Restore names/IP in each test subprocess
setup() {
  TEST_TMPDIR="$(mktemp -d)"
  CONTAINER_A_NAME=$(<"$(_name_a_file)")
  CONTAINER_B_NAME=$(<"$(_name_b_file)")
  CONTAINER_B_IP=$(<"$(_ip_b_file)")
}

@test "container A cannot ping container B" {
  run vm_run incus exec "agent-${CONTAINER_A_NAME}" -- ping -c 1 -W 3 "$CONTAINER_B_IP"
  assert_failure
}

@test "container A cannot TCP connect to container B on port 22" {
  run vm_run incus exec "agent-${CONTAINER_A_NAME}" -- \
    bash -c "echo test | nc -w 3 ${CONTAINER_B_IP} 22 2>&1; exit \$?"
  assert_failure
}

@test "Incus default profile has port_isolation enabled" {
  run vm_exec "incus profile show default"
  assert_success
  assert_output --partial "security.port_isolation"
}
