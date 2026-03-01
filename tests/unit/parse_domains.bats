#!/usr/bin/env bats
load '../test_helper/common'

@test "parse_domains_file: strips comment lines" {
  cat > "${TEST_TMPDIR}/domains.txt" << 'EOF'
# This is a comment
example.com
# Another comment
foo.org
EOF
  run parse_domains_file "${TEST_TMPDIR}/domains.txt"
  assert_success
  assert_line --index 0 "example.com"
  assert_line --index 1 "foo.org"
  refute_line --partial "#"
}

@test "parse_domains_file: strips blank lines" {
  cat > "${TEST_TMPDIR}/domains.txt" << 'EOF'
example.com

foo.org


bar.net
EOF
  run parse_domains_file "${TEST_TMPDIR}/domains.txt"
  assert_success
  assert_line --index 0 "example.com"
  assert_line --index 1 "foo.org"
  assert_line --index 2 "bar.net"
  # Should be exactly 3 lines
  [ "${#lines[@]}" -eq 3 ]
}

@test "parse_domains_file: strips inline comments" {
  cat > "${TEST_TMPDIR}/domains.txt" << 'EOF'
example.com  # main site
foo.org      # secondary
EOF
  run parse_domains_file "${TEST_TMPDIR}/domains.txt"
  assert_success
  assert_line --index 0 "example.com"
  assert_line --index 1 "foo.org"
}

@test "parse_domains_file: preserves wildcard domains" {
  cat > "${TEST_TMPDIR}/domains.txt" << 'EOF'
.googleapis.com
exact.example.com
EOF
  run parse_domains_file "${TEST_TMPDIR}/domains.txt"
  assert_success
  assert_line --index 0 ".googleapis.com"
  assert_line --index 1 "exact.example.com"
}

@test "parse_domains_file: strips leading and trailing whitespace" {
  cat > "${TEST_TMPDIR}/domains.txt" << 'EOF'
  example.com
	foo.org
EOF
  run parse_domains_file "${TEST_TMPDIR}/domains.txt"
  assert_success
  assert_line --index 0 "example.com"
  assert_line --index 1 "foo.org"
}

@test "resolve_domains_file: explicit path takes priority" {
  touch "${TEST_TMPDIR}/explicit.txt"
  run resolve_domains_file "${TEST_TMPDIR}/explicit.txt"
  assert_success
  assert_output "${TEST_TMPDIR}/explicit.txt"
}

@test "resolve_domains_file: dies if explicit path does not exist" {
  run resolve_domains_file "/nonexistent/path.txt"
  assert_failure
  assert_output --partial "not found"
}

@test "resolve_domains_file: falls back to bundled default" {
  # With no explicit path and no user override, should find bundled default
  run resolve_domains_file ""
  assert_success
  assert_output --partial "anthropic-default.txt"
}

@test "parse_domains_file: file with only comments produces empty output" {
  cat > "${TEST_TMPDIR}/comments-only.txt" << 'EOF'
# comment one
# comment two
# comment three
EOF
  run parse_domains_file "${TEST_TMPDIR}/comments-only.txt"
  assert_success
  assert_output ""
}

@test "parse_domains_file: empty file produces empty output" {
  touch "${TEST_TMPDIR}/empty.txt"
  run parse_domains_file "${TEST_TMPDIR}/empty.txt"
  assert_success
  assert_output ""
}

@test "bundled anthropic-default.txt parses without errors" {
  run parse_domains_file "${PROJECT_ROOT}/domains/anthropic-default.txt"
  assert_success
  # Should have a significant number of domains
  [ "${#lines[@]}" -gt 50 ]
}
