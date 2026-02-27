#!/usr/bin/env bats
load '../test_helper/integration'

# Persist the container name so all tests (which run in subprocesses) share it.
_name_file() { echo "${BATS_FILE_TMPDIR}/port_fwd_name"; }

setup_file() {
  # Override the prefix so create_test_container computes a stable name
  TEST_CONTAINER_PREFIX="test-${BATS_ROOT_PID:-$$}"
  create_test_container --slot 98
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

@test "SSH proxy device exists with correct listen port" {
  run vm_exec "incus config device get agent-${TEST_CONTAINER_NAME} ssh-proxy listen"
  assert_success
  assert_output --partial "2298"  # 2200 + 98
}

@test "SSH proxy device connects to container port 22" {
  run vm_exec "incus config device get agent-${TEST_CONTAINER_NAME} ssh-proxy connect"
  assert_success
  assert_output --partial ":22"
}

@test "App proxy device exists with correct listen port" {
  run vm_exec "incus config device get agent-${TEST_CONTAINER_NAME} app-proxy listen"
  assert_success
  assert_output --partial "8098"  # 8000 + 98
}

@test "App proxy device connects to container port 8080" {
  run vm_exec "incus config device get agent-${TEST_CONTAINER_NAME} app-proxy connect"
  assert_success
  assert_output --partial ":8080"
}

@test "Alt proxy device exists with correct listen port" {
  run vm_exec "incus config device get agent-${TEST_CONTAINER_NAME} alt-proxy listen"
  assert_success
  assert_output --partial "9098"  # 9000 + 98
}

@test "Alt proxy device connects to container port 9090" {
  run vm_exec "incus config device get agent-${TEST_CONTAINER_NAME} alt-proxy connect"
  assert_success
  assert_output --partial ":9090"
}

@test "port forwarding works end-to-end: listener on 8080 reachable from host" {
  # Start a simple HTTP responder inside the container using python3 (more portable than nc)
  container_exec bash -c '
    nohup python3 -c "
import http.server, socketserver
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header(\"Content-Length\", \"2\")
        self.end_headers()
        self.wfile.write(b\"ok\")
    def log_message(self, *a): pass
socketserver.TCPServer((\"\", 8080), H).serve_forever()
" &>/dev/null &'
  sleep 2

  # Curl from the VM (host-side of the proxy)
  run vm_exec "curl -sf --max-time 5 http://127.0.0.1:8098"
  assert_success
  assert_output "ok"
}
