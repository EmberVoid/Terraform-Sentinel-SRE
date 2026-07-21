# SRE/SIEM/SOAR Azure Sentinel Deployment

This repository contains **Terraform 4.1.0** code that provisions a minimal yet functional Azure environment for learning and practicing Site-Reliability Engineering concepts around Microsoft Sentinel.

---

## Overview

**Core Components:**

- Deploys a **Windows 2022 VM** (small-disk) and an **Ubuntu 24.04 LTS VM**
- Deploys a **Log Analytics Workspace** that Sentinel feeds into 
- Configures:
  - Performance Counter DCR
  - SecurityEvents Windows Event DCR
  - Syslog and CEF DCRs (Linux, warning level and above)
  - A Sentinel workspace
  - An Activity Log policy to ingest Azure activity logs
  - Azure Policy–driven AMA (Azure Monitor Agent) installation and DCR association, so agent rollout and telemetry wiring are enforced at the policy level rather than per-VM
  - A general resource group policy baseline
- *(Up next)* **Ansible** playbooks for:
  - OS-level hardening (SSH/RDP, CIS-aligned baselines)
  - Populating the VMs with administrative and attack-simulation tooling
  - Generating realistic Sentinel-consuming event traffic

**Goal:** An evolving playground for SRE/SIEM/SOAR skill building — monitoring, observability, incident response, and Azure-native tooling.

**Status:** The Terraform/infrastructure layer is functionally complete for the `dev` environment — modules are environment-agnostic, CI/CD is wired end-to-end with OIDC auth, and branch protections are in place. Active work is now shifting to the Ansible configuration layer described in [Next Up](#next-up-ansible-configuration) below.

---

## Repository Structure

```
.
├── .github
│   └── workflows
│       ├── terraform-apply.yml
│       └── terraform-plan.yml
├── ansible
│   ├── ansible.cfg
│   ├── BOOTSTRAP.md
│   ├── Troubleshooting.md
│   ├── inventory
│   │   ├── group_vars
│   │   │   ├── linux
│   │   │   └── windows
│   │   └── hosts.yml
│   ├── playbooks
│   │   └── site.yml
│   ├── requirements.yml
│   └── roles
│       ├── atomic_red_team
│       │   ├── defaults
│       │   └── tasks
│       └── sysmon
│           ├── defaults
│           ├── files
│           ├── handlers
│           └── tasks
├── environments
│   ├── dev
│   │   ├── backend.tf
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── variables.tf
│   └── local
│       ├── backend.tf
│       ├── main.tf
│       └── variables.tf
├── modules
│   ├── dcr
│   ├── general_rg_policy
│   ├── log_analytics
│   ├── network
│   ├── policy_dcr_association
│   ├── policy_install_ama
│   ├── resource_group
│   ├── sentinel
│   ├── vm_ubuntu
│   └── vm_windows
├── readme.md
└── scripts
    ├── pre-push-check.sh
    └── update-client-ip.sh
```

Module labels (e.g. `module "WinSer1_VM"`, `module "rg"`, `module "network"`) are environment-agnostic, since at the Terraform code level there's no need to differentiate by environment — the same module blocks are reused across `dev` and, eventually, `staging`/`prod`.

The actual Azure resource *names*, however, remain environment-specific (e.g. the Windows VM's `vm_name` variable defaults to `WinSer1-VM-Dev`). Since resources from multiple environments can end up in the same subscription — or even across subscriptions — having the environment baked into the resource name makes it possible to tell at a glance which environment a given Azure resource belongs to.

---

## Current Scope

  | Resource / Module | Purpose |
  |---|---|
  | `vm_windows` | Windows Server 2022 (small disk) for local experimentation |
  | `vm_ubuntu` | Ubuntu 24.04 LTS for Linux-side testing |
  | `log_analytics` | Central collection point for all telemetry |
  | `dcr` | Data Collection Rules: Performance Counters, Windows SecurityEvents, Syslog, and CEF (warning+) |
  | `sentinel` | Core Sentinel workspace for alerts & playbooks |
  | `policy_install_ama` | Azure Policy that installs the Azure Monitor Agent on in-scope VMs |
  | `policy_dcr_association` | Azure Policy that associates VMs with the correct DCRs |
  | `general_rg_policy` | Baseline resource group–level policy assignment |
  | `network` | VNet/subnet/NSG scaffolding for the VMs |
  | `resource_group` | Resource group provisioning |

---

## CI/CD

- **`terraform-plan.yml`** runs on pull requests and posts the plan as a required status check before merge.
- **`terraform-apply.yml`** runs on pushes to `main`.
- Both workflows watch `.github/workflows/**` in their path filters, so changes to the workflows themselves also trigger a run.
- Authentication uses Azure AD **OIDC federated credentials** — no long-lived secrets. Two federated credentials are configured:
  - `repo:EmberVoid/Terraform-Sentinel-SRE:pull_request` for the plan workflow
  - `repo:EmberVoid/Terraform-Sentinel-SRE:environment:dev` for the apply workflow, scoped to the `dev` GitHub Environment
- **Branch protection** on `main` requires an up-to-date branch, a passing pull request, and a passing `plan` status check before merge.

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

## Next Up: Ansible Configuration

With provisioning complete, the project is moving into post-provisioning configuration management. Terraform remains scoped strictly to infrastructure; all in-guest configuration lives in Ansible. Planned in stages:

- [x] **Stage 0 — Scaffolding:** WinRM/SSH connectivity, dynamic inventory generated from Terraform outputs
- [ ] **Stage 1 — Hardening:** SSH/RDP hardening aligned to CIS benchmarks
- [ ] **Stage 2 — Windows telemetry:**
  - [x] Sysmon (SwiftOnSecurity config) — installed, configured, verified flowing into Sentinel
  - [x] Atomic Red Team via `Invoke-AtomicRedTeam` — T1082, T1059.001 running, confirmed in Log Analytics
  - [ ] Scheduled task for continuous/unattended data generation
- [ ] **Stage 3 — Linux telemetry:** auditd, rsyslog/CEF forwarding matched to the existing Syslog/CEF DCRs, Linux atomics

### Ansible Scope

| Role / Component | Purpose |
|---|---|
| `inventory/` | Dynamic-from-Terraform-output inventory, WinRM (Windows) and SSH (Linux) connectivity |
| `roles/sysmon` | Installs Sysmon with the SwiftOnSecurity community config, verified flowing into Sentinel |
| `roles/atomic_red_team` | Installs Invoke-AtomicRedTeam + atomics library, runs pinned MITRE ATT&CK technique tests to generate realistic telemetry |

---

## Future Enhancements

- [ ] Implement Sentinel analytics rules and playbooks for common incident response scenarios
- [ ] Integrate Azure Monitor alerts to trigger auto-scale or remediation steps
- [ ] Expand to `staging`/`prod` environments using the existing environment-agnostic modules

---

> *This project is a living lab; it will keep changing as I acquire new knowledge.*