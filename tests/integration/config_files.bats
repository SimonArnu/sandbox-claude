#!/usr/bin/env bats
# ABOUTME: Integration tests for global and per-project config files
# ABOUTME: Verifies ~/.sandbox/config and .sandbox.conf auto-loading
load '../test_helper/integration'

_name_file() { echo "${BATS_FILE_TMPDIR}/config_name"; }

setup_file() {
  TEST_CONTAINER_PREFIX="test-${BATS_ROOT_PID:-$$}"

  # Create a project dir with .sandbox.conf
  export TEST_PROJECT_DIR="${BATS_FILE_TMPDIR}/my-project"
  mkdir -p "$TEST_PROJECT_DIR"
  echo "marker from project" > "$TEST_PROJECT_DIR/marker.txt"

  cat > "$TEST_PROJECT_DIR/.sandbox.conf" << EOF
stack=base
mcp=server-a
env=FROM_PROJECT_CONF=yes
EOF

  # Create a fake claude settings for MCP
  export FAKE_CLAUDE_DIR="${BATS_FILE_TMPDIR}/fake-claude"
  mkdir -p "$FAKE_CLAUDE_DIR"
  cat > "$FAKE_CLAUDE_DIR/settings.json" << 'MCPEOF'
{
  "mcpServers": {
    "server-a": {
      "command": "echo",
      "args": ["hello-a"]
    },
    "server-b": {
      "command": "echo",
      "args": ["hello-b"]
    }
  }
}
MCPEOF

  # Create a global config
  export SANDBOX_CONFIG="${BATS_FILE_TMPDIR}/global-config"
  cat > "$SANDBOX_CONFIG" << EOF
ssh-key=${BATS_FILE_TMPDIR}/fake-key
env=FROM_GLOBAL=yes
env=OVERRIDE_ME=global
EOF

  # Create a fake SSH key
  ssh-keygen -t ed25519 -f "${BATS_FILE_TMPDIR}/fake-key" -N "" -q

  TEST_CONTAINER_NAME="${TEST_CONTAINER_PREFIX}-config"
  echo "$TEST_CONTAINER_NAME" > "$(_name_file)"

  SANDBOX_CONFIG="$SANDBOX_CONFIG" \
  CLAUDE_CONFIG_DIR="$FAKE_CLAUDE_DIR" \
    "${PROJECT_ROOT}/bin/sandbox-start" "$TEST_CONTAINER_NAME" \
    --local-dir "$TEST_PROJECT_DIR" \
    --env OVERRIDE_ME=cli
}

teardown_file() {
  TEST_CONTAINER_NAME=$(<"$(_name_file)")
  destroy_test_container
}

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  TEST_CONTAINER_NAME=$(<"$(_name_file)")
}

@test "config: project dir is mounted (from --local-dir)" {
  run container_exec cat /workspace/project/marker.txt
  assert_success
  assert_output "marker from project"
}

@test "config: env from project .sandbox.conf is set" {
  run container_exec bash -lc 'echo $FROM_PROJECT_CONF'
  assert_success
  assert_output "yes"
}

@test "config: env from global config is set" {
  run container_exec bash -lc 'echo $FROM_GLOBAL'
  assert_success
  assert_output "yes"
}

@test "config: CLI --env overrides both config files" {
  run container_exec bash -lc 'echo $OVERRIDE_ME'
  assert_success
  assert_output "cli"
}

@test "config: mcp from project config is injected" {
  run container_exec bash -c 'cat /home/ubuntu/.claude/settings.json'
  assert_success
  assert_output --partial '"server-a"'
  refute_output --partial '"server-b"'
}

@test "config: ssh key from global config is loaded" {
  run container_exec bash -c 'SSH_AUTH_SOCK=/run/ssh-agent.sock ssh-add -l 2>&1'
  assert_success
  assert_output --partial "ED25519"
}
