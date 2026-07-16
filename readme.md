# SRE-Focused Azure Sentinel Deployment

This repository contains **Terraform 4.1.0** code that provisions a minimal yet functional Azure environment for learning and practicing Site-Reliability Engineering concepts around Microsoft Sentinel.

---

## Overview

**Core Components:**

- Deploys a **Windows 2022 VM** (small-disk) and an **Ubuntu 24.04 LTS VM**
- Installs a **Log Analytics Workspace** that feeds into Sentinel
- Configures:
  - Performance Counter DCR
  - SecurityEvents Windows Event DCR
  - A Sentinel workspace
  - An Activity Log policy to ingest Azure activity logs
- *(Planned)* **Ansible** playbooks for:
  - Populating the VMs with administrative tools
  - Generating realistic Sentinel-consuming event traffic

**Goal:** An evolving playground for SRE skill building — monitoring, observability, incident response, and Azure-native tooling.

---

## Current Scope

| Resource | Purpose |
|---|---|
| `windows_vm` | Windows 2022 with small disk for local experimentation |
| `linux_vm` | Ubuntu 24.04 LTS for Linux-side testing |
| `log_analytics_ws` | Central collection point for all telemetry |
| `dcr_perf_counter` | Performance counters from VMs → Sentinel |
| `dcr_windows_event` | Windows SecurityEvents → Sentinel |
| `sentinel_workspace` | Core Sentinel workspace for alerts & playbooks |
| `activity_log_policy` | Ingests Azure activity logs into Sentinel |

---

## Prerequisites

- **Azure CLI 2.88** (`az --version`) — use the latest release to avoid deprecations
- **Terraform 1.15.8** (`terraform --version`)
- **azurerm 4.1.0** (`terraform providers`)
- An active Azure subscription with sufficient RBAC for resource creation
- A manually created Storage Account with a Blob Container to store Terraform remote state (see below)

### Setting Up Remote State (Azure CloudShell / PowerShell)

Before running Terraform, create the backend storage manually. This keeps the state backend separate from the workload resource group.

**1. Set variables** (adjust names/region as needed):

```powershell
$RG_StateName = "ResourceGroupName"
$LOCATION = "eastus"
$STORAGE_ACCOUNT = "storageaccountname"   # must be globally unique, lowercase, no dashes
$CONTAINER_NAME = "tfstate"
```

**2. Create the resource group** (dedicated to backend infra, kept separate from your workload RG):

```powershell
az group create --name $RG_StateName --location $LOCATION
```

**3. Create the storage account:**

```powershell
az storage account create `
  --name $STORAGE_ACCOUNT `
  --resource-group $RG_StateName `
  --location $LOCATION `
  --sku Standard_LRS `
  --encryption-services blob `
  --min-tls-version TLS1_2 `
  --allow-blob-public-access false
```

**4. Create the blob container** to hold the `.tfstate` file:

```powershell
az storage container create `
  --name $CONTAINER_NAME `
  --account-name $STORAGE_ACCOUNT `
  --auth-mode login
```

**5. Create an Azure AD App Registration for GitHub OIDC**:

```powershell
# Create the app registration
$APP_NAME="YourAppRegistrationName"
$SUBSCRIPTION_ID=$(az account show --query id -o tsv)
$TENANT_ID=$(az account show --query tenantId -o tsv)

az ad sp create-for-rbac --name $APP_NAME --role Contributor --scopes "/subscriptions/$SUBSCRIPTION_ID"
#Write down the details

#Get AppID for later steps:
$APP_ID=$(az ad app list --display-name $APP_NAME --query "[0].appId" -o tsv)

#I also suggest writing down the objectId, appId and displayName, it can be very handy when troubleshooting future issues.
az ad sp show --id $APP_ID --query "{objectId:id, appId:appId, displayName:displayName}"

#And granting the App/Service Principal the Resource Policy Contributor and Role Based Access Control Administrator since we'll need it later:
az role assignment create `
  --assignee $APP_ID `
  --role "Resource Policy Contributor" `
  --scope "/subscriptions/$SUBSCRIPTION_ID"

az role assignment create `
  --assignee $APP_ID `
  --role "Role Based Access Control Administrator" `
  --scope "/subscriptions/$SUBSCRIPTION_ID"

# Get your subscription and tenant IDs — you'll need these as GitHub secrets
echo "Subscription ID: $SUBSCRIPTION_ID"
echo "Tenant ID: $TENANT_ID"
```
> **Note 1:** For the time we are giving contributor access at the sub level, as we can't give it to the RG level as it does not exit yet. Plus during Microsoft Sentinel deployment we'll need the Resource Policy Contributor at a Sub level.

**6. Trust GitHub via Federated Credentials**:
We need two federated credentials: one for pull requests (plan) and one for the main branch (apply).

```powershell
# Federated credential for PRs (plan workflow)
az ad app federated-credential create `
  --id $APP_ID `
  --parameters '{
    "name": "sentinel-sre-pull-requests",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:EmberVoid/Terraform-Sentinel-SRE:pull_request",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Federated credential for main branch (apply workflow)
az ad app federated-credential create `
  --id $APP_ID `
  --parameters '{
    "name": "sentinel-sre-env-dev",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:EmberVoid/Terraform-Sentinel-SRE:environment:dev",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```
> **Note 2:** The subject field is the important bit — it's a strict match. If you later use GitHub Environments, the subject format changes to repo:OWNER/REPO:environment:NAME, so keep that in mind if you tighten this further

**6. Trust GitHub via Federated Credentials**:
In your repo: Settings → Secrets and variables → Actions → New repository secret. Add:

| Secret name | Value |
|---|---|
| `AZURE_CLIENT_ID` | `$APP_ID` from Part 5 |
| `AZURE_TENANT_ID` | `$TENANT_ID` from Part 5 |
| `AZURE_SUBSCRIPTION_ID` | `$SUBSCRIPTION_ID` from Part 5 |

Then set up a GitHub Environment for the apply gate: Settings → Environments → New environment, name it production (or dev if you'd rather match your Terraform environment naming — just be consistent). Under Deployment protection rules, check Required reviewers and add yourself

> **Note 3:** While researching `backend.tf`, I came across [Atmos (CloudPosse)](https://atmos.tools/), an open-source orchestration tool for Terraform, Kubernetes, Helm, and others that works as a unified CLI and can automate backend configuration. It's better suited to managing multiple projects and is a bit out of scope here, but worth documenting for future reference.

> **Note 4:** This repository is a learning sandbox — treat it as experimental and apply your own security hardening policies as needed.

---

## Future Enhancements

- [ ] Add **Ansible** for automated OS hardening and LOLBin deployment
- [ ] Expand DCRs for additional Windows/Linux logs (Syslog, PowerShell, etc.)
- [ ] Implement Sentinel playbooks for common incident response scenarios
- [ ] Integrate Azure Monitor alerts to trigger auto-scale or remediation steps

---

> *This project is a living lab; it will keep changing as I acquire new SRE knowledge.*