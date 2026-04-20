#!/usr/bin/env bats
# ABOUTME: Integration tests for --env-file flag
# ABOUTME: Verifies per-project env file loading and override behavior
load '../test_helper/integration'

_name_file() { echo "${BATS_FILE_TMPDIR}/env_file_name"; }

setup_file() {
  TEST_CONTAINER_PREFIX="test-${BATS_ROOT_PID:-$$}"
  TEST_CONTAINER_NAME="${TEST_CONTAINER_PREFIX}-env-file"
  echo "$TEST_CONTAINER_NAME" > "$(_name_file)"

  # Create env file
  export TEST_ENV_FILE="${BATS_FILE_TMPDIR}/test.env"
  cat > "$TEST_ENV_FILE" << 'EOF'
# A comment
PROJECT_NAME=my-project
DB_HOST=localhost

# Override global var (GITHUB_TOKEN would come from ~/.sandbox/env)
CUSTOM_OVERRIDE=from-env-file
EOF

  "${PROJECT_ROOT}/bin/sandbox-start" "$TEST_CONTAINER_NAME" \
    --stack base \
    --env-file "$TEST_ENV_FILE" \
    --env CUSTOM_OVERRIDE=from-cli
}

teardown_file() {
  TEST_CONTAINER_NAME=$(<"$(_name_file)")
  destroy_test_container
}

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  TEST_CONTAINER_NAME=$(<"$(_name_file)")
}

@test "env-file: vars from file are available in container" {
  run container_exec bash -lc 'echo $PROJECT_NAME'
  assert_success
  assert_output "my-project"
}

@test "env-file: multiple vars from file work" {
  run container_exec bash -lc 'echo $DB_HOST'
  assert_success
  assert_output "localhost"
}

@test "env-file: --env overrides env-file values" {
  run container_exec bash -lc 'echo $CUSTOM_OVERRIDE'
  assert_success
  assert_output "from-cli"
}

@test "env-file: comments and blank lines are skipped" {
  # Should not have a variable called '# A comment'
  run container_exec bash -lc 'env | grep "^#" || echo "no comment vars"'
  assert_output "no comment vars"
}

@test "env-file: rejects nonexistent file" {
  run "${PROJECT_ROOT}/bin/sandbox-start" "test-bad-envfile-$$" \
    --env-file /nonexistent/path
  assert_failure
  assert_output --partial "not found"
}
