# SRE/SIEM/SOAR Azure Sentinel Deployment

This repository contains **Terraform 4.1.0** code that provisions minimal, functional Azure environments for learning and practicing Site-Reliability Engineering and SOC/detection concepts around Microsoft Sentinel — a `dev` environment (passive MITRE telemetry) and an isolated `attack-lab` environment (active attack simulation against a monitored target).

---

## Overview

**Core Components:**

- `dev` environment:
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
  - **Ansible** (see [Next Up](#next-up-ansible-configuration)) handles OS-level hardening, Sysmon, and Atomic Red Team–driven telemetry generation
- `attack-lab` environment (see [Attack Lab Environment](#attack-lab-environment)): isolated RG/VNet, a Kali Linux attacker VM, and a monitored Windows target VM, feeding telemetry into `dev`'s existing Sentinel workspace

**Goal:** An evolving playground for SRE/SIEM/SOAR skill building — monitoring, observability, incident response, and Azure-native tooling.

**Status:** The Terraform/infrastructure layer is functionally complete for the `dev` environment — modules are environment-agnostic, CI/CD is wired end-to-end with OIDC auth, and branch protections are in place. A second environment, `attack-lab` (isolated Kali + Windows target for attack simulation, see [Attack Lab Environment](#attack-lab-environment) below), was added and deployed on top of the same module set. Active work is now shifting to the Ansible configuration layer described in [Next Up](#next-up-ansible-configuration) below — for both `dev` and `attack-lab`.

---

## Repository Structure

```
.
├── .github
│   └── workflows
│       ├── terraform-apply.yml
│       ├── terraform-plan.yml
│       ├── terraform-apply-attack-lab.yml
│       └── terraform-plan-attack-lab.yml
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
│   ├── local
│   │   ├── backend.tf
│   │   ├── main.tf
│   │   └── variables.tf
│   └── attack-lab
│       ├── backend.tf
│       ├── main.tf
│       ├── outputs.tf
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
│   ├── vm_kali
│   ├── vm_ubuntu
│   └── vm_windows
├── readme.md
└── scripts
    ├── local-ip-apply.sh
    ├── pre-push-check.sh
    └── update-client-ip.sh
```

Module labels (e.g. `module "WinSer1_VM"`, `module "rg"`, `module "network"`) are environment-agnostic, since at the Terraform code level there's no need to differentiate by environment — the same module blocks are reused across `dev`, `attack-lab`, and eventually `staging`/`prod`.

The actual Azure resource *names*, however, remain environment-specific (e.g. the Windows VM's `vm_name` variable defaults to `WinSer1-VM-Dev`). Since resources from multiple environments can end up in the same subscription — or even across subscriptions — having the environment baked into the resource name makes it possible to tell at a glance which environment a given Azure resource belongs to.

---

## Current Scope

  | Resource / Module | Purpose |
  |---|---|
  | `vm_windows` | Windows Server 2022 (small disk) for local experimentation, and reused as the isolated target VM in `attack-lab` |
  | `vm_ubuntu` | Ubuntu 24.04 LTS for Linux-side testing |
  | `vm_kali` | Official Kali Linux marketplace image (attacker VM, `attack-lab` only) — handles the marketplace legal-terms agreement and `plan` block automatically |
  | `log_analytics` | Central collection point for all telemetry |
  | `dcr` | Data Collection Rules: Performance Counters, Windows SecurityEvents, Syslog, and CEF (warning+) |
  | `sentinel` | Core Sentinel workspace for alerts & playbooks |
  | `policy_install_ama` | Azure Policy that installs the Azure Monitor Agent on in-scope VMs |
  | `policy_dcr_association` | Azure Policy that associates VMs with the correct DCRs |
  | `general_rg_policy` | Baseline resource group–level policy assignment |
  | `network` | VNet/subnet/NSG scaffolding for the VMs |
  | `resource_group` | Resource group provisioning |

---

## Attack Lab Environment

`environments/attack-lab` is a second, deliberately isolated environment for attack-simulation work — a Kali Linux attacker VM plus a Windows target VM — built to close the "reactive EDR" gap in the original passive-MITRE-telemetry setup (Sysmon + Atomic Red Team on `dev` only generates and records technique activity; `attack-lab` is where an actual attacker box drives traffic against a target and Defender/Sentinel are watched for detection and response).

**Isolation design (not incidental — see the reasoning, not just the result):**
- Own resource group (`rg-attack-lab-Sentinel-WUS3-01`) and own VNet (`10.124.0.0/16`), with **no peering** to `dev`'s VNet or RG. An attack-simulation box needs a blast-radius boundary from anything Sentinel-integrated, the same principle already applied elsewhere in this project.
- Own `policy_install_ama` / `policy_dcr_association` module instances scoped only to `rg-attack-lab`'s own ID — not shared with `dev`'s policy assignments or state.
- Telemetry from the Windows target flows into `dev`'s *existing* Log Analytics/Sentinel workspace (passed in as `var.law_id`) rather than standing up a second Sentinel instance — cross-lab visibility is achieved at the Log Analytics level, not by bridging networks.
- Same NSG-scoped-to-`client_ip` pattern as `dev` for RDP/SSH/WinRM — no `Any`-sourced inbound rules.

**Known, expected limitation — not a bug:** the Kali VM has no AMA/Sentinel telemetry. The built-in Azure Monitor Agent policy (`a4034bc6-ae50-406d-bf76-50f4ee5a7811`) has its own `imagePublisher`/`imageOffer`/`imageSku` allowlist, and `kali-linux`/`kali` isn't in it — confirmed directly against the live policy definition (`az policy definition show --name a4034bc6-ae50-406d-bf76-50f4ee5a7811 --query "policyRule.if"`), not just the docs. This is architecturally correct anyway: the attacker box isn't meant to self-report into the same pipeline it's being tested against. Only the Windows target is instrumented.

**Marketplace image gotcha (`vm_kali` module):** deploying a marketplace (non-default) image requires an `azurerm_marketplace_agreement` resource plus a matching `plan` block on the VM resource, or the deploy fails with a plan-mismatch error. On a `destroy`/recreate of this environment, Terraform may try to recreate the marketplace agreement even though it still exists in Azure — if so, `terraform import azurerm_marketplace_agreement.kali kali-linux/kali/<plan-sku>` rather than re-applying blind.

---

## CI/CD

- **`terraform-plan.yml`** / **`terraform-plan-attack-lab.yml`** run on pull requests (scoped by path — `environments/dev/**` + `modules/**` for the former, `environments/attack-lab/**` + `modules/**` for the latter) and post the plan as a required status check before merge. Because both watch `modules/**`, a shared-module change (e.g. `vm_windows`) triggers both plan checks — this is intentional, so a change made for one environment can't silently drift the other's state.
- **`terraform-apply.yml`** / **`terraform-apply-attack-lab.yml`** run on pushes to `main`, each scoped to its own environment's paths.
- Both `dev` and `attack-lab` watch `.github/workflows/**` (their own workflow file) in their path filters, so changes to the workflows themselves also trigger a run.
- Authentication uses Azure AD **OIDC federated credentials** — no long-lived secrets. Two federated credentials are configured, one per environment (each covers both that environment's plan and apply jobs, since both declare the same `environment:` in their job definition):
  - `repo:EmberVoid/Terraform-Sentinel-SRE:environment:dev`
  - `repo:EmberVoid/Terraform-Sentinel-SRE:environment:attack-lab`
- **Branch protection** on `main` requires an up-to-date branch, a passing pull request, and passing `plan` status checks (both `dev` and `attack-lab`, when a PR touches shared modules) before merge.

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

One federated credential per GitHub Environment is what's actually needed — **not** one for PRs and one for `main`, despite how that might look at first glance. Both the plan job (PR-triggered) and apply job (push-to-`main`-triggered) declare the same `environment:` key in their job definition, and per [GitHub's own OIDC subject-claim docs](https://docs.github.com/actions/reference/openid-connect-reference), *"the subject claim includes the `pull_request` string... only if the job doesn't reference an environment."* Since both jobs reference an environment, both actually authenticate with an `environment:<name>` subject — one credential per environment covers its plan and apply workflows both.

```powershell
# Federated credential for the dev environment (covers both its plan and apply jobs)
az ad app federated-credential create `
  --id $APP_ID `
  --parameters '{
    "name": "sentinel-sre-env-dev",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:EmberVoid/Terraform-Sentinel-SRE:environment:dev",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Federated credential for the attack-lab environment (same pattern)
az ad app federated-credential create `
  --id $APP_ID `
  --parameters '{
    "name": "sentinel-sre-env-attack-lab",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:EmberVoid/Terraform-Sentinel-SRE:environment:attack-lab",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```
> **Note 2:** The subject field is the important bit — it's a strict match. An earlier version of this repo also created a `repo:...:pull_request`-subject credential on the assumption the plan job authenticated separately from apply; that credential is unused once the plan job's own `environment:` key is set (as it is here) and can be removed if still present.

**7. Add repository/environment secrets**:
In your repo: Settings → Secrets and variables → Actions. Repo-level secrets are visible to every job; environment-scoped secrets (Settings → Environments → *env* → Environment secrets) are visible only to jobs declaring that environment and take precedence over a same-named repo secret.

| Secret name | Value | Scope |
|---|---|---|
| `AZURE_CLIENT_ID` | `$APP_ID` from Part 5 | Repo-level (shared) |
| `AZURE_TENANT_ID` | `$TENANT_ID` from Part 5 | Repo-level (shared) |
| `AZURE_SUBSCRIPTION_ID` | `$SUBSCRIPTION_ID` from Part 5 | Repo-level (shared) |
| `CLIENT_IP` | Your current public IP | Repo-level (shared) |
| `SSH_PUB_KEY` | SSH public key for Linux VMs | Repo-level (shared) |
| `WIN_ADMIN_PASSWORD` | `dev`'s Windows VM admin password | `dev` environment |
| `ATTACKLAB_TARGET_ADMIN_PASSWORD` | `attack-lab`'s Windows target admin password | `attack-lab` environment |
| `DEV_LAW_ID` | `dev`'s Log Analytics workspace resource ID (see [Attack Lab Environment](#attack-lab-environment)) | `attack-lab` environment |

Then set up a GitHub Environment for each apply gate: Settings → Environments → New environment, name it to match the Terraform environment (`dev`, `attack-lab`) for consistency. Under Deployment protection rules, check Required reviewers and add yourself.

> **Note 3:** While researching `backend.tf`, I came across [Atmos (CloudPosse)](https://atmos.tools/), an open-source orchestration tool for Terraform, Kubernetes, Helm, and others that works as a unified CLI and can automate backend configuration. It's better suited to managing multiple projects and is a bit out of scope here, but worth documenting for future reference.

> **Note 4:** This repository is a learning sandbox — treat it as experimental and apply your own security hardening policies as needed.

---

## Next Up: Ansible Configuration

With provisioning complete for both `dev` and `attack-lab`, the project is moving into post-provisioning configuration management. Terraform remains scoped strictly to infrastructure; all in-guest configuration lives in Ansible. Planned in stages:

- [x] **Stage 0 — Scaffolding:** WinRM/SSH connectivity, dynamic inventory generated from Terraform outputs
- [ ] **Stage 1 — Hardening:** SSH/RDP hardening aligned to CIS benchmarks
- [x] **Stage 2 — Windows telemetry (`dev`):**
  - [x] Sysmon (SwiftOnSecurity config) — installed, configured, verified flowing into Sentinel
  - [x] Atomic Red Team via `Invoke-AtomicRedTeam` — T1082, T1059.001 running, confirmed in Log Analytics
  - [x] Scheduled task for continuous/unattended data generation
- [ ] **Stage 3 — Linux telemetry (`dev`):** auditd, rsyslog/CEF forwarding matched to the existing Syslog/CEF DCRs, Linux atomics
- [ ] **Stage 4 — Attack Lab telemetry (`attack-lab`):** Sysmon + Atomic Red Team on `WinTarget1-VM-AttackLab` (same roles as Stage 2, new inventory group); Kali stays deliberately unmonitored (see [Attack Lab Environment](#attack-lab-environment))
- [ ] **Stage 5 — Reactive validation:** run a technique from Kali against the Windows target and confirm it surfaces as a Sentinel alert/incident — the actual "hands-on EDR pipeline" milestone this environment exists for; Defender for Servers Plan 2 is being trial-validated manually (Defender for Cloud) ahead of wiring it into Terraform

### Ansible Scope

| Role / Component | Purpose |
|---|---|
| `inventory/` | Dynamic-from-Terraform-output inventory, WinRM (Windows) and SSH (Linux) connectivity — currently covers `dev`'s WinSer1/UbuDoc1; `attack-lab`'s target/attacker still need adding |
| `roles/sysmon` | Installs Sysmon with the SwiftOnSecurity community config, verified flowing into Sentinel |
| `roles/atomic_red_team` | Installs Invoke-AtomicRedTeam + atomics library, runs pinned MITRE ATT&CK technique tests on a recurring schedule (unattended, SYSTEM context) to generate realistic telemetry |

---

## Future Enhancements

- [ ] Implement Sentinel analytics rules and playbooks for common incident response scenarios
- [ ] Integrate Azure Monitor alerts to trigger auto-scale or remediation steps
- [ ] Expand to `staging`/`prod` environments using the existing environment-agnostic modules
- [ ] Enable Microsoft Defender for Servers Plan 2 via Terraform (`azurerm_security_center_subscription_pricing`) once manually trial-validated

---

> *This project is a living lab; it will keep changing as I acquire new knowledge.*