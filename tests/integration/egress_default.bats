#!/usr/bin/env bats
load '../test_helper/integration'

# Persist the container name so all tests (which run in subprocesses) share it.
_name_file() { echo "${BATS_FILE_TMPDIR}/egress_default_name"; }

setup_file() {
  # Override the prefix so create_test_container computes a stable name
  TEST_CONTAINER_PREFIX="test-${BATS_ROOT_PID:-$$}"
  create_test_container
  # Persist the name that create_test_container computed
  echo "$TEST_CONTAINER_NAME" > "$(_name_file)"
}

teardown_file() {
  TEST_CONTAINER_NAME=$(<"$(_name_file)")
  destroy_test_container
}

# Restore the container name in each test subprocess
setup() {
  TEST_TMPDIR="$(mktemp -d)"
  TEST_CONTAINER_NAME=$(<"$(_name_file)")
}

@test "DNS (port 53) is allowed" {
  # dig is not installed in the base container; use getent ahosts instead
  run container_exec getent ahosts example.com
  assert_success
  # Should return at least one IPv4 address
  assert_output --regexp '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'
}

@test "HTTPS (port 443) is allowed" {
  run container_exec curl -sf --max-time 10 -o /dev/null -w '%{http_code}' https://example.com
  assert_success
}

@test "HTTP (port 80) is allowed" {
  run container_exec curl -sf --max-time 10 -o /dev/null -w '%{http_code}' http://example.com
  assert_success
}

@test "SSH (port 22) outbound is allowed" {
  # Test that we can at least TCP-connect to github.com:22
  # ssh-keyscan returns the server's host key, proving TCP connection succeeded
  run container_exec bash -c 'ssh-keyscan -T 5 github.com 2>/dev/null | head -1'
  assert_success
  assert_output --partial "github.com"
}

@test "arbitrary port (5432) is blocked by default iptables" {
  # nc to a known-reachable IP on a non-allowed port should fail/timeout
  run container_exec bash -c 'echo test | nc -w 3 8.8.8.8 5432 2>&1; exit $?'
  assert_failure
}

@test "arbitrary port (6379) is blocked by default iptables" {
  run container_exec bash -c 'echo test | nc -w 3 8.8.8.8 6379 2>&1; exit $?'
  assert_failure
}
