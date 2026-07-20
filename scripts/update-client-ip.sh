#!/usr/bin/env bash
set -e

CURRENT_IP=$(curl -s ifconfig.me)
CACHE_FILE="$(dirname "$0")/.last_known_ip"
CACHED_IP=$(cat "$CACHE_FILE" 2>/dev/null || echo "")

if [ -z "$CURRENT_IP" ]; then
  echo "⚠️  Could not determine current IP (network issue?) — skipping secret update."
  exit 1
fi

if [ "$CURRENT_IP" == "$CACHED_IP" ]; then
  echo "==> Client IP unchanged (${CURRENT_IP}), skipping secret update"
  exit 0
fi

echo "==> IP changed: ${CACHED_IP:-<none>} -> ${CURRENT_IP}, updating CLIENT_IP secret"
gh secret set CLIENT_IP --body "${CURRENT_IP}/32"
echo "$CURRENT_IP" > "$CACHE_FILE"
echo "==> Done. Re-run the apply workflow to apply the new IP to the NSG rules."