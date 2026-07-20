#!/usr/bin/env bash
clear
set -e  # stop on first failure

echo "==> Checking client IP for drift"
CURRENT_IP=$(curl -s ifconfig.me)
CACHE_FILE="./.last_known_ip"
CACHE_FILE="$(dirname "$0")/.last_known_ip"
CACHED_IP=$(cat "$CACHE_FILE" 2>/dev/null || echo "")

if [ -z "$CURRENT_IP" ]; then
  echo "⚠️  Could not determine current IP (network issue?) — skipping drift check."
elif [ "$CURRENT_IP" != "$CACHED_IP" ]; then
  echo "⚠️  WARNING: Your current IP (${CURRENT_IP}) differs from the last known CLIENT_IP (${CACHED_IP:-<none>})."
  echo "⚠️  Run ./update-client-ip.sh before pushing if you need CI to reach the VMs, or the NSG rules will reject connections from this network."
else
  echo "==> Client IP unchanged (${CURRENT_IP}), no action needed"
fi

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