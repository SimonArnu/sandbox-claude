#!/usr/bin/env bats
load '../test_helper/common'

@test "container_name: simple name" {
  run container_name "myproject"
  assert_success
  assert_output "agent-myproject"
}

@test "container_name: name with hyphens" {
  run container_name "my-project-v2"
  assert_success
  assert_output "agent-my-project-v2"
}
