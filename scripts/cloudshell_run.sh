#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export USER=nmplace
export AZURE_EXTENSION_USE_DYNAMIC_INSTALL=yes_without_prompt
az account set --subscription "Azure for Students"
RG=rg-data789-hw4-nmplace
if [ "$(az group exists -n "$RG")" != false ]; then
  echo "Resource group already exists; inspect it before redeploying."
  exit 1
fi
cleanup() {
  trap - EXIT
  echo "=== SAME-DAY TEARDOWN ==="
  date -Is
  if [ "$(az group exists -n "$RG")" = true ]; then
    bash teardown_azure.sh
    az group wait -n "$RG" --deleted --interval 15 --timeout 1800
  fi
  echo "$ az group exists -n $RG"
  az group exists -n "$RG"
}
trap cleanup EXIT
printf 'Nicholas Place | nmplace@unc.edu | DATA 789 HW4\n'
date -Is
az account show --query name -o tsv
sha256sum deploy_azure.sh config.env
bash deploy_azure.sh
FQDN=$(az containerapp show -n trustbank-fraud -g "$RG" --query properties.configuration.ingress.fqdn -o tsv)
echo "=== PUBLIC ENDPOINT: https://${FQDN} ==="
curl --fail-with-body -sS --retry 5 --retry-delay 5 --retry-all-errors "https://${FQDN}/health"
echo
bash scripts/smoke_test.sh "https://${FQDN}"
echo "=== EVIDENCE CAPTURE WINDOW: teardown in 60 seconds ==="
sleep 60
