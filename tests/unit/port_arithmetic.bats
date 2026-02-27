#!/usr/bin/env bats
load '../test_helper/common'

@test "ssh_port: slot 1 returns 2201" {
  run ssh_port 1
  assert_success
  assert_output "2201"
}

@test "ssh_port: slot 99 returns 2299" {
  run ssh_port 99
  assert_success
  assert_output "2299"
}

@test "app_port: slot 1 returns 8001" {
  run app_port 1
  assert_success
  assert_output "8001"
}

@test "app_port: slot 50 returns 8050" {
  run app_port 50
  assert_success
  assert_output "8050"
}

@test "alt_port: slot 1 returns 9001" {
  run alt_port 1
  assert_success
  assert_output "9001"
}

@test "alt_port: slot 99 returns 9099" {
  run alt_port 99
  assert_success
  assert_output "9099"
}
