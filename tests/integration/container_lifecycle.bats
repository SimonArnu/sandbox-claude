#!/usr/bin/env bats
load '../test_helper/integration'

# Use a unique name per run to avoid collisions.
# We persist it via BATS_FILE_TMPDIR so all tests (which run in separate
# subprocesses) share the same container name.
_lifecycle_name_file() { echo "${BATS_FILE_TMPDIR}/lifecycle_name"; }

setup_file() {
  echo "test-${BATS_ROOT_PID:-$$}-lifecycle" > "$(_lifecycle_name_file)"
}

teardown_file() {
  local name
  name=$(<"$(_lifecycle_name_file)")
  # Safety net: destroy if any test left it behind
  "${PROJECT_ROOT}/bin/sandbox-stop" "$name" --rm 2>/dev/null || true
}

_name() { cat "$(_lifecycle_name_file)"; }

@test "sandbox-create: creates a container successfully" {
  local LIFECYCLE_NAME; LIFECYCLE_NAME=$(_name)
  run "${PROJECT_ROOT}/bin/sandbox-create" "$LIFECYCLE_NAME" --stack base
  assert_success
  assert_output --partial "ready"
}

@test "sandbox-list: shows the container as Running" {
  local LIFECYCLE_NAME; LIFECYCLE_NAME=$(_name)
  run "${PROJECT_ROOT}/bin/sandbox-list"
  assert_success
  assert_output --partial "agent-${LIFECYCLE_NAME}"
  assert_output --partial "RUNNING"
}

@test "container has correct metadata: stack=base" {
  local LIFECYCLE_NAME; LIFECYCLE_NAME=$(_name)
  run get_metadata "agent-${LIFECYCLE_NAME}" "stack"
  assert_success
  assert_output "base"
}

@test "container has a valid slot assigned" {
  local LIFECYCLE_NAME; LIFECYCLE_NAME=$(_name)
  run get_metadata "agent-${LIFECYCLE_NAME}" "slot"
  assert_success
  # Slot should be a number 1-99
  [[ "${output}" =~ ^[0-9]+$ ]]
  (( output >= 1 && output <= 99 ))
}

@test "can execute a command inside the container" {
  local LIFECYCLE_NAME; LIFECYCLE_NAME=$(_name)
  run vm_run incus exec "agent-${LIFECYCLE_NAME}" -- echo "hello from container"
  assert_success
  assert_output "hello from container"
}

@test "sandbox-stop: stops the container" {
  local LIFECYCLE_NAME; LIFECYCLE_NAME=$(_name)
  run "${PROJECT_ROOT}/bin/sandbox-stop" "$LIFECYCLE_NAME"
  assert_success
  assert_output --partial "Stopped"
}

@test "sandbox-list: shows the container as Stopped after stop" {
  local LIFECYCLE_NAME; LIFECYCLE_NAME=$(_name)
  run "${PROJECT_ROOT}/bin/sandbox-list"
  assert_success
  assert_output --partial "agent-${LIFECYCLE_NAME}"
  assert_output --partial "STOPPED"
}

@test "sandbox-stop --rm: removes the container entirely" {
  local LIFECYCLE_NAME; LIFECYCLE_NAME=$(_name)
  run "${PROJECT_ROOT}/bin/sandbox-stop" "$LIFECYCLE_NAME" --rm
  assert_success
  assert_output --partial "Deleted"
}

@test "container no longer exists after --rm" {
  local LIFECYCLE_NAME; LIFECYCLE_NAME=$(_name)
  run vm_exec "incus info agent-${LIFECYCLE_NAME} 2>&1"
  assert_failure
}
