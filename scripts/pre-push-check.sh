#!/usr/bin/env bash
set -e  # stop on first failure

cd ../environments/dev

echo "==> terraform fmt"
terraform fmt -recursive ..   # fixes formatting across modules + environments

echo "==> terraform init"
terraform init -backend=false   # -backend=false skips remote state/auth for a quick local check

echo "==> terraform validate"
terraform validate

echo "==> tflint"
tflint --init
tflint --recursive

#echo "==> checkov"
#checkov -d . --framework terraform

echo "All checks passed ✅ Continue with commit and push."