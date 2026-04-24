#!/usr/bin/env bash
# Database reset helper. Not used in this project — there is no application
# database. Kept as a stub so test.sh's structural check still passes and so
# a future workload module that needs an RDS reset has an obvious home.
#
# If you add a database-bearing workload, replace this body with the real
# reset logic (typically: drop & recreate schema, or terraform destroy +
# apply scoped to the database module).
set -euo pipefail
echo "scripts/db-reset.sh: no-op (this project has no application database)"
