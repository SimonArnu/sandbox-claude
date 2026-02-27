# Tests

## Prerequisites

1. **BATS** (Bash Automated Testing System):
   ```bash
   brew install bats-core    # macOS
   apt install bats           # Debian/Ubuntu
   ```

2. **Helper libraries** (one-time):
   ```bash
   git clone --depth 1 https://github.com/bats-core/bats-support tests/test_helper/bats-support
   git clone --depth 1 https://github.com/bats-core/bats-assert tests/test_helper/bats-assert
   ```

3. **For integration tests**: `sandbox-setup` must be completed (golden images built).

## Running Tests

```bash
# All tests
./tests/run-tests.sh

# Unit tests only (~1 second)
./tests/run-tests.sh unit

# Integration tests only (~2-5 minutes, creates real containers)
./tests/run-tests.sh integration

# Single test file
bats tests/unit/parse_domains.bats
bats tests/integration/egress_domains.bats
```

## Test Structure

- `tests/unit/` — Fast tests for pure functions (no infrastructure needed)
- `tests/integration/` — Tests using real Incus containers (requires sandbox-setup)
- `tests/test_helper/` — Shared setup and helpers
- `tests/fixtures/` — Test data files (domain allowlists, etc.)
