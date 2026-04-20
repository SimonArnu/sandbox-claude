#!/usr/bin/env bats
# ABOUTME: Integration tests for --mount flag (extra bind-mounts)
# ABOUTME: Verifies multiple host directories can be mounted into a container
load '../test_helper/integration'

_name_file() { echo "${BATS_FILE_TMPDIR}/mount_name"; }

setup_file() {
  TEST_CONTAINER_PREFIX="test-${BATS_ROOT_PID:-$$}"
  TEST_CONTAINER_NAME="${TEST_CONTAINER_PREFIX}-mount"
  echo "$TEST_CONTAINER_NAME" > "$(_name_file)"

  # Create test directories
  mkdir -p "${BATS_FILE_TMPDIR}/dir-a"
  mkdir -p "${BATS_FILE_TMPDIR}/dir-b"
  echo "from-dir-a" > "${BATS_FILE_TMPDIR}/dir-a/a.txt"
  echo "from-dir-b" > "${BATS_FILE_TMPDIR}/dir-b/b.txt"

  "${PROJECT_ROOT}/bin/sandbox-start" "$TEST_CONTAINER_NAME" \
    --stack base \
    --mount "${BATS_FILE_TMPDIR}/dir-a:/home/ubuntu/dir-a" \
    --mount "${BATS_FILE_TMPDIR}/dir-b:/home/ubuntu/dir-b"
}

teardown_file() {
  TEST_CONTAINER_NAME=$(<"$(_name_file)")
  destroy_test_container
}

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  TEST_CONTAINER_NAME=$(<"$(_name_file)")
}

@test "mount: first directory is accessible" {
  run container_exec cat /home/ubuntu/dir-a/a.txt
  assert_success
  assert_output "from-dir-a"
}

@test "mount: second directory is accessible" {
  run container_exec cat /home/ubuntu/dir-b/b.txt
  assert_success
  assert_output "from-dir-b"
}

@test "mount: writes from container appear on host" {
  container_exec bash -c 'echo "written" > /home/ubuntu/dir-a/from-container.txt'
  run cat "${BATS_FILE_TMPDIR}/dir-a/from-container.txt"
  assert_success
  assert_output "written"
  rm -f "${BATS_FILE_TMPDIR}/dir-a/from-container.txt"
}

@test "mount: rejects invalid format (missing colon)" {
  run "${PROJECT_ROOT}/bin/sandbox-start" "test-bad-mount-$$" \
    --mount /tmp/no-colon
  assert_failure
  assert_output --partial "source:dest"
}

@test "mount: rejects nonexistent source" {
  run "${PROJECT_ROOT}/bin/sandbox-start" "test-bad-mount2-$$" \
    --mount /nonexistent/path:/home/ubuntu/nope
  assert_failure
  assert_output --partial "not found"
}

@test "mount: works alongside --local-dir" {
  local name="test-mount-combo-$$"
  local project_dir="${BATS_FILE_TMPDIR}/combo-project"
  mkdir -p "$project_dir"
  echo "project-file" > "$project_dir/proj.txt"

  "${PROJECT_ROOT}/bin/sandbox-start" "$name" \
    --stack base \
    --local-dir "$project_dir" \
    --mount "${BATS_FILE_TMPDIR}/dir-a:/home/ubuntu/extra"

  run incus exec "agent-${name}" -- cat /workspace/project/proj.txt
  assert_success
  assert_output "project-file"

  run incus exec "agent-${name}" -- cat /home/ubuntu/extra/a.txt
  assert_success
  assert_output "from-dir-a"

  "${PROJECT_ROOT}/bin/sandbox-stop" "$name" --rm 2>/dev/null || true
}

@test "mount: available from config file" {
  local name="test-mount-conf-$$"
  local project_dir="${BATS_FILE_TMPDIR}/conf-project"
  mkdir -p "$project_dir"
  cat > "$project_dir/.sandbox.conf" << EOF
mount=${BATS_FILE_TMPDIR}/dir-a:/home/ubuntu/from-conf
EOF

  "${PROJECT_ROOT}/bin/sandbox-start" "$name" \
    --stack base --local-dir "$project_dir"

  run incus exec "agent-${name}" -- cat /home/ubuntu/from-conf/a.txt
  assert_success
  assert_output "from-dir-a"

  "${PROJECT_ROOT}/bin/sandbox-stop" "$name" --rm 2>/dev/null || true
}
