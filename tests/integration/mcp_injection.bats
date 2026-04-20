#!/usr/bin/env bats
# ABOUTME: Integration tests for --mcp flag that injects MCP server configs
# ABOUTME: Verifies selective copying of MCP configs from host to container
load '../test_helper/integration'

_name_file() { echo "${BATS_FILE_TMPDIR}/mcp_name"; }

setup_file() {
  TEST_CONTAINER_PREFIX="test-${BATS_ROOT_PID:-$$}"
  TEST_CONTAINER_NAME="${TEST_CONTAINER_PREFIX}-mcp"
  echo "$TEST_CONTAINER_NAME" > "$(_name_file)"

  # Create a fake host settings.json with MCP servers
  export FAKE_CLAUDE_DIR="${BATS_FILE_TMPDIR}/fake-claude"
  mkdir -p "$FAKE_CLAUDE_DIR"
  cat > "$FAKE_CLAUDE_DIR/settings.json" << 'EOF'
{
  "mcpServers": {
    "server-a": {
      "command": "echo",
      "args": ["hello-a"],
      "env": {
        "TOKEN_A": "secret-a"
      }
    },
    "server-b": {
      "command": "echo",
      "args": ["hello-b"],
      "env": {
        "TOKEN_B": "secret-b"
      }
    },
    "server-c": {
      "command": "echo",
      "args": ["hello-c"]
    }
  }
}
EOF

  CLAUDE_CONFIG_DIR="$FAKE_CLAUDE_DIR" \
    "${PROJECT_ROOT}/bin/sandbox-start" "$TEST_CONTAINER_NAME" \
    --stack base --mcp server-a --mcp server-c
}

teardown_file() {
  TEST_CONTAINER_NAME=$(<"$(_name_file)")
  destroy_test_container
}

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  TEST_CONTAINER_NAME=$(<"$(_name_file)")
}

@test "mcp: selected servers are injected into container settings" {
  run container_exec bash -c 'cat /home/ubuntu/.claude/settings.json'
  assert_success
  assert_output --partial '"server-a"'
  assert_output --partial '"server-c"'
}

@test "mcp: non-selected servers are excluded" {
  run container_exec bash -c 'cat /home/ubuntu/.claude/settings.json'
  assert_success
  refute_output --partial '"server-b"'
}

@test "mcp: env vars are preserved in injected config" {
  run container_exec bash -c 'cat /home/ubuntu/.claude/settings.json'
  assert_success
  assert_output --partial '"TOKEN_A"'
  assert_output --partial '"secret-a"'
}

@test "mcp: rejects unknown server name" {
  run "${PROJECT_ROOT}/bin/sandbox-start" "test-mcp-bad-$$" --mcp nonexistent
  assert_failure
  assert_output --partial "not found"
}

@test "mcp: --mcp all copies all servers" {
  local name="test-mcp-all-$$"
  FAKE_CLAUDE_DIR="${BATS_FILE_TMPDIR}/fake-claude"
  CLAUDE_CONFIG_DIR="$FAKE_CLAUDE_DIR" \
    "${PROJECT_ROOT}/bin/sandbox-start" "$name" --stack base --mcp all

  run incus exec "agent-${name}" -- cat /home/ubuntu/.claude/settings.json
  assert_success
  assert_output --partial '"server-a"'
  assert_output --partial '"server-b"'
  assert_output --partial '"server-c"'

  "${PROJECT_ROOT}/bin/sandbox-stop" "$name" --rm 2>/dev/null || true
}
