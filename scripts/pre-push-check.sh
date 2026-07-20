#!/usr/bin/env bash
clear
set -e  # stop on first failure

SCRIPT_DIR="$(dirname "$0")"
ENV_FILE="${SCRIPT_DIR}/.env.local"

if [ -f "$ENV_FILE" ]; then
  # shellcheck source=/dev/null
  source "$ENV_FILE"
else
  echo "❌ Missing ${ENV_FILE} — needed for local terraform plan (TF_VAR_* secrets)."
  echo "   Copy scripts/.env.local.example and fill in real values."
  exit 1
fi

echo "==> Checking Azure CLI auth"
if ! az account show > /dev/null 2>&1; then
  echo "❌ Not logged in to Azure CLI. Run 'az login' first."
  exit 1
fi
echo "==> Logged in as: $(az account show --query user.name -o tsv) (sub: $(az account show --query name -o tsv))"

echo "==> Checking client IP for drift"
CURRENT_IP=$(curl -s ifconfig.me)
CACHE_FILE="$(dirname "$0")/.last_known_ip"
CACHED_IP=$(cat "$CACHE_FILE" 2>/dev/null || echo "")

if [ -z "$CURRENT_IP" ]; then
  echo "⚠️  Could not determine current IP (network issue?) — skipping IP drift check."
  echo "⚠️  TF_VAR_client_ip will fall back to .env.local / .last_known_ip if set."
else
  export TF_VAR_client_ip="${CURRENT_IP}/32"
  echo "==> Using live IP for local plan: ${TF_VAR_client_ip}"

  if [ "$CURRENT_IP" != "$CACHED_IP" ]; then
    echo "⚠️  WARNING: Your current IP (${CURRENT_IP}) differs from the last known CLIENT_IP (${CACHED_IP:-<none>})."
    echo "⚠️  Run ./update-client-ip.sh before pushing if you need CI to reach the VMs, or the NSG rules will reject connections from this network."
  else
    echo "==> Client IP unchanged (${CURRENT_IP}), matches cached value"
  fi
fi

echo "==> terraform fmt (repo-wide)"
terraform fmt -recursive ..

for ENV_DIR in ../environments/*/; do
  ENV=$(basename "$ENV_DIR")

  #Currently, skipping local env as it is not actually deployed
  if [[ "$ENV" == "local" ]]; then
    echo "==> Skipping local environment"
    continue
  fi

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
    #checkov -d . --framework terraform

    echo "==> terraform init (${ENV}, real backend) for drift/plan check"
    terraform init -reconfigure

    echo "==> terraform plan (${ENV}) - checking for drift/pending changes"
    set +e
    terraform plan -input=false -detailed-exitcode
    plan_exit=$?
    set -e

    case $plan_exit in
      0) echo "✅ [${ENV}] No drift, no pending changes." ;;
      1) echo "❌ [${ENV}] terraform plan failed — fix errors before pushing."; exit 1 ;;
      2)
        echo "⚠️  [${ENV}] Plan shows changes — continuing push automatically."
        ;;
    esac
  )
done

echo ""
echo "All checks passed across all environments ✅"
echo -e "If starting a new branch, remember to:\n- git status \n- git checkout main \n- git pull origin main \n- git checkout -b <new-branch> \n To avoid merge conflicts."