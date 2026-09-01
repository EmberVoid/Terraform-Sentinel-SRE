#!/usr/bin/env bash
set -euo pipefail

# ---------- 1️⃣  Find the repo root ---------------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_DIR="${REPO_ROOT}/environments/dev"

# ---------- 2️⃣  Load the .env.local file -----------------------------
ENV_FILE="${REPO_ROOT}/scripts/.env.local"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  source "$ENV_FILE"
  set +a
else
  echo "❌ .env.local not found in $REPO_ROOT"
  exit 1
fi

# ---------- 3️⃣  Get live client IP (not the cache — cache is CI's copy) ---
CURRENT_IP="$(curl -s ifconfig.me)"
if [[ -z "$CURRENT_IP" ]]; then
  echo "❌ Could not determine current IP — aborting."
  exit 1
fi
export TF_VAR_client_ip="${CURRENT_IP}/32"
echo "==> Using live IP: ${TF_VAR_client_ip}"

# ---------- 4️⃣  Target only the NSG client_ip rules -------------------
TARGETS=(
  -target="module.network.azurerm_network_security_rule.rdp_rule"
  -target="module.network.azurerm_network_security_rule.ssh_rule"
  -target="module.network.azurerm_network_security_rule.winrm_rule"
)

# ---------- 5️⃣  Run Terraform from environments/dev, not repo root -----
pushd "$ENV_DIR" >/dev/null

echo "==> terraform init (dev)"
terraform init -reconfigure

echo "==> terraform plan (dev) — NSG client_ip rules only"
terraform plan -input=false "${TARGETS[@]}"

echo ""
read -r -p "Apply the above plan? [y/N] " CONFIRM
if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
  terraform apply -input=false -auto-approve "${TARGETS[@]}"
  echo "✅ NSG rules updated for ${TF_VAR_client_ip}"
else
  echo "==> Aborted, no changes applied."
  popd >/dev/null
  exit 1
fi

popd >/dev/null