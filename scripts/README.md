# Scripts Directory

> **Purpose**: Automation scripts for common development tasks. "If it happens twice, automate it."

## Available Scripts

### Compliance generators (run when CSV/SSP source data changes)

| Script | Purpose | Usage |
|--------|---------|-------|
| `gen-controls-csv.py` | Regenerate `controls/nist-800-171-mapping.csv` from inline catalog. | `python3 scripts/gen-controls-csv.py` |
| `gen-ssp.py` | Regenerate `ssp/SSP.md` from the CSV + inline `WRITTEN` table. | `python3 scripts/gen-ssp.py` |

### Compliance guards (run by `compliance-checks.yml`; safe locally)

| Script | Purpose | Usage |
|--------|---------|-------|
| `check-controls-csv.py` | Validate CSV row count, schema, family set, ID regex. Exits non-zero on first failure. | `python3 scripts/check-controls-csv.py` |
| `check-ssp.sh` | Assert SSP header count matches CSV, exactly 100 TODO stubs, every CSV `full` row has a non-TODO SSP entry. | `bash scripts/check-ssp.sh` |

### Repo / template scripts (kept from the upstream template)

| Script | Purpose | Usage |
|--------|---------|-------|
| `verify-env.sh` | Check environment setup | `./scripts/verify-env.sh` |
| `db-reset.sh` | Reset database to clean state (no DB in this repo; kept for parity) | `./scripts/db-reset.sh` |
| `setup.sh` | One-command project setup | `./scripts/setup.sh` |
| `auto-rebase-overlapping.sh`, `multi-dispatch-safety.sh`, `parse-ownership-table.sh`, plus `test-*.sh` | Multi-agent coordination + tests; see `docs/guides/multi-agent-coordination.md`. | invoked by `test.sh` |

## Usage Guidelines

### For Agents

Before marking a task complete, run verification:
```bash
./scripts/verify-env.sh
```

### For Developers

One-command setup for new clones:
```bash
./scripts/setup.sh
```

## Creating New Scripts

1. Create the script in this directory
2. Add a shebang: `#!/bin/bash`
3. Make it executable: `chmod +x scripts/your-script.sh`
4. Add error handling: `set -e` (exit on error)
5. Document it in this README
6. Add to `test.sh` verification if critical

## Script Template

```bash
#!/bin/bash
# Description: What this script does
# Usage: ./scripts/script-name.sh [args]

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { printf "${GREEN}[INFO]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1"; }

# Your script logic here

log_info "Done!"
```

## Best Practices

1. **Idempotent**: Scripts should be safe to run multiple times
2. **Verbose**: Output what's happening for debugging
3. **Fail Fast**: Use `set -e` to stop on first error
4. **Check Dependencies**: Verify required tools exist before running
5. **Document**: Add usage comments at the top of each script
