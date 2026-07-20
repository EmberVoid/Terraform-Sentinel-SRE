#!/usr/bin/env bash
clear
set -e  # stop on first failure

#!/usr/bin/env bash
clear
set -e

echo "==> terraform fmt (repo-wide)"
terraform fmt -recursive ..

for ENV_DIR in ../environments/*/; do
  ENV=$(basename "$ENV_DIR")
  echo ""
  echo "========================================================="
  echo "========> Checking environment: ${ENV}"
  echo "========================================================="

  (
    cd "$ENV_DIR"

    echo "==> terraform init (${ENV})"
    terraform init -backend=false

    echo "==> terraform validate (${ENV})"
    terraform validate

    terraform output -json

    echo "==> tflint (${ENV})"
    tflint --init
    tflint --recursive

    #echo "==> checkov (${ENV})"
    #echo "==> checkov"
    #checkov -d . --framework terraform
  )
done

echo ""
echo "All checks passed across all environments ✅"