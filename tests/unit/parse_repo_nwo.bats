#!/usr/bin/env bats
load '../test_helper/common'

@test "parse_repo_nwo: SSH URL with .git suffix" {
  run parse_repo_nwo "git@github.com:me/alpha.git"
  assert_success
  assert_output "me/alpha"
}

@test "parse_repo_nwo: HTTPS URL with .git suffix" {
  run parse_repo_nwo "https://github.com/me/alpha.git"
  assert_success
  assert_output "me/alpha"
}

@test "parse_repo_nwo: SSH URL without .git suffix" {
  run parse_repo_nwo "git@github.com:org/repo"
  assert_success
  assert_output "org/repo"
}

@test "parse_repo_nwo: HTTPS URL without .git suffix" {
  run parse_repo_nwo "https://github.com/org/repo"
  assert_success
  assert_output "org/repo"
}

@test "parse_repo_nwo: deeply nested org/repo" {
  run parse_repo_nwo "git@github.com:my-org/my-repo.git"
  assert_success
  assert_output "my-org/my-repo"
}
