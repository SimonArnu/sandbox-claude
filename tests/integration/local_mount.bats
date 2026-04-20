#!/usr/bin/env bats
# ABOUTME: Integration tests for --local-dir host directory mounting
# ABOUTME: Verifies bind-mount into container and uid mapping
load '../test_helper/integration'

_name_file() { echo "${BATS_FILE_TMPDIR}/local_mount_name"; }

setup_file() {
  TEST_CONTAINER_PREFIX="test-${BATS_ROOT_PID:-$$}"
  TEST_CONTAINER_NAME="${TEST_CONTAINER_PREFIX}-local-mount"
  echo "$TEST_CONTAINER_NAME" > "$(_name_file)"

  # Create a temporary directory with a marker file
  export TEST_LOCAL_DIR="${BATS_FILE_TMPDIR}/local-repo"
  mkdir -p "$TEST_LOCAL_DIR"
  echo "hello from host" > "$TEST_LOCAL_DIR/marker.txt"

  "${PROJECT_ROOT}/bin/sandbox-start" "$TEST_CONTAINER_NAME" \
    --stack base --local-dir "$TEST_LOCAL_DIR"
}

teardown_file() {
  TEST_CONTAINER_NAME=$(<"$(_name_file)")
  destroy_test_container
}

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  TEST_CONTAINER_NAME=$(<"$(_name_file)")
  TEST_LOCAL_DIR="${BATS_FILE_TMPDIR}/local-repo"
}

@test "local-dir: container has workspace mounted" {
  run container_exec test -f /workspace/project/marker.txt
  assert_success
}

@test "local-dir: file content is readable from container" {
  run container_exec cat /workspace/project/marker.txt
  assert_success
  assert_output "hello from host"
}

@test "local-dir: writes from container appear on host" {
  container_exec bash -c 'echo "written by container" > /workspace/project/from-container.txt'
  run cat "$TEST_LOCAL_DIR/from-container.txt"
  assert_success
  assert_output "written by container"
  rm -f "$TEST_LOCAL_DIR/from-container.txt"
}

@test "local-dir: metadata records local-dir" {
  run get_metadata "agent-${TEST_CONTAINER_NAME}" "local-dir"
  assert_success
  assert_output "$TEST_LOCAL_DIR"
}

@test "local-dir: mutually exclusive with repo URL" {
  run "${PROJECT_ROOT}/bin/sandbox-start" "test-conflict-$$" \
    git@github.com:me/repo.git --local-dir /tmp
  assert_failure
  assert_output --partial "Cannot use --local-dir with a repo URL"
}
