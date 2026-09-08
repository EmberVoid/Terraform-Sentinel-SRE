# SRE/SIEM/SOAR Azure Sentinel Deployment

Terraform 4.1.0 code that provisions Azure environments for learning Site-Reliability Engineering and SOC/detection work around Microsoft Sentinel. Two environments live here: `dev`, which generates passive MITRE telemetry, and `attack-lab`, an isolated environment where a Kali VM attacks a monitored Windows target.

---

## Overview

**`dev` environment:**

Deploys a Windows 2022 VM (small-disk) and an Ubuntu 24.04 LTS VM, plus a Log Analytics Workspace that Sentinel feeds into. On top of that:

- Performance Counter DCR
- SecurityEvents Windows Event DCR
- Syslog and CEF DCRs (Linux, warning level and above)
- A Sentinel workspace
- An Activity Log policy to ingest Azure activity logs
- Azure Policy-driven AMA (Azure Monitor Agent) installation and DCR association, so agent rollout and telemetry wiring happen at the policy level instead of per-VM
- A general resource group policy baseline

Ansible (see [Next Up](#next-up-ansible-configuration)) handles OS hardening, Sysmon, and Atomic Red Team-driven telemetry generation.

**`attack-lab` environment** (see [Attack Lab Environment](#attack-lab-environment)): its own resource group and VNet, a Kali Linux attacker VM, and a monitored Windows target. Telemetry from the target flows into `dev`'s existing Sentinel workspace.

**Goal:** a playground for SRE/SIEM/SOAR skill building. Monitoring, incident response, Azure-native tooling.

**Status:** the Terraform layer is done for `dev` — modules are environment-agnostic, CI/CD runs end to end with OIDC auth, branch protections are in place. `attack-lab` was added on top of the same modules and is deployed. Work now is shifting to Ansible, for both environments.

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

Module labels (`module "WinSer1_VM"`, `module "rg"`, `module "network"`) don't need to differentiate by environment at the Terraform level, so the same module blocks get reused across `dev`, `attack-lab`, and eventually `staging`/`prod`.

Azure resource *names* do stay environment-specific — the Windows VM's `vm_name` defaults to `WinSer1-VM-Dev`. Multiple environments can land in the same subscription, so baking the environment into the name is how you tell resources apart at a glance.

---

## Current Scope

  | Resource / Module | Purpose |
  |---|---|
  | `vm_windows` | Windows Server 2022 (small disk) for local experimentation, and reused as the isolated target VM in `attack-lab` |
  | `vm_ubuntu` | Ubuntu 24.04 LTS for Linux-side testing |
  | `vm_kali` | Official Kali Linux marketplace image, attacker VM, `attack-lab` only. Handles the marketplace agreement and `plan` block automatically |
  | `log_analytics` | Central collection point for all telemetry |
  | `dcr` | Data Collection Rules: performance counters, Windows SecurityEvents, Syslog, CEF (warning+) |
  | `sentinel` | Core Sentinel workspace for alerts and playbooks |
  | `policy_install_ama` | Azure Policy that installs the Azure Monitor Agent on in-scope VMs |
  | `policy_dcr_association` | Azure Policy that associates VMs with the correct DCRs |
  | `general_rg_policy` | Baseline resource group-level policy assignment |
  | `network` | VNet/subnet/NSG scaffolding for the VMs |
  | `resource_group` | Resource group provisioning |

---

## Attack Lab Environment

`environments/attack-lab` is an isolated environment for attack-simulation work: a Kali Linux attacker VM and a Windows target VM. `dev`'s Sysmon and Atomic Red Team setup only generates and records technique activity on its own VMs. `attack-lab` is where something actually attacks a target and Defender/Sentinel get watched for detection and response.

It's isolated on purpose, not by accident:

- Own resource group (`rg-attack-lab-Sentinel-WUS3-01`) and own VNet (`10.124.0.0/16`), no peering to `dev`. An attack-simulation box needs a blast-radius boundary from anything Sentinel-integrated.
- Own `policy_install_ama` / `policy_dcr_association` instances scoped only to `rg-attack-lab`, not shared with `dev`'s policy assignments or state.
- The Windows target's telemetry flows into `dev`'s existing Log Analytics/Sentinel workspace (`var.law_id`) instead of a second Sentinel instance. Cross-lab visibility happens at the Log Analytics level, not by bridging networks.
- Same NSG pattern as `dev` for RDP/SSH/WinRM: scoped to `client_ip`, nothing sourced from `Any`.

The Kali VM has no AMA or Sentinel telemetry, and that's expected. The built-in Azure Monitor Agent policy (`a4034bc6-ae50-406d-bf76-50f4ee5a7811`) has its own `imagePublisher`/`imageOffer`/`imageSku` allowlist, and `kali-linux`/`kali` isn't on it — confirmed against the live policy definition (`az policy definition show --name a4034bc6-ae50-406d-bf76-50f4ee5a7811 --query "policyRule.if"`), not just the docs. It's also the right shape anyway: the attacker box shouldn't self-report into the same pipeline it's being tested against. Only the Windows target is instrumented.

One gotcha in the `vm_kali` module: deploying a marketplace image needs an `azurerm_marketplace_agreement` resource plus a matching `plan` block on the VM, or the deploy fails with a plan-mismatch error. If you destroy and recreate this environment, Terraform may try to recreate the marketplace agreement even though it still exists in Azure. If that happens, import it instead of re-applying blind: `terraform import azurerm_marketplace_agreement.kali kali-linux/kali/<plan-sku>`.

---

## CI/CD

`terraform-plan.yml` and `terraform-plan-attack-lab.yml` run on pull requests and post the plan as a required status check before merge. Each is scoped by path — `environments/dev/**` + `modules/**` for one, `environments/attack-lab/**` + `modules/**` for the other. Both watch `modules/**`, so a shared-module change (say, `vm_windows`) triggers both plan checks. That's intentional: a change made for one environment shouldn't be able to silently drift the other's state.

`terraform-apply.yml` and `terraform-apply-attack-lab.yml` run on pushes to `main`, each scoped to its own environment's paths. Both also watch `.github/workflows/**` for their own workflow file.

Authentication uses Azure AD OIDC federated credentials, no long-lived secrets. One credential per environment, not per trigger type — both the plan and apply jobs for an environment authenticate the same way, since both declare that environment in their job definition:

- `repo:EmberVoid/Terraform-Sentinel-SRE:environment:dev`
- `repo:EmberVoid/Terraform-Sentinel-SRE:environment:attack-lab`

Branch protection on `main` requires an up-to-date branch, a passing pull request, and passing plan checks (both `dev` and `attack-lab`, when a PR touches shared modules) before merge.

---

## Prerequisites

- Azure CLI 2.88 (`az --version`), use the latest release to avoid deprecations
- Terraform 1.15.8 (`terraform --version`)
- azurerm 4.1.0 (`terraform providers`)
- An active Azure subscription with sufficient RBAC for resource creation
- A manually created Storage Account with a Blob Container to store Terraform remote state (see below)

### Setting Up Remote State (Azure CloudShell / PowerShell)

Create the backend storage manually before running Terraform. This keeps the state backend separate from the workload resource group.

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
> **Note 1:** For now we're giving contributor access at the sub level, since we can't scope to the RG yet (it doesn't exist). We also need Resource Policy Contributor at the sub level for the Sentinel deployment.

**6. Trust GitHub via Federated Credentials**:

One federated credential per GitHub Environment is what you actually need, not one for PRs and one for `main`. Both the plan job (PR-triggered) and the apply job (triggered on push to `main`) declare the same `environment:` key in their job definition, and per [GitHub's OIDC subject-claim docs](https://docs.github.com/actions/reference/openid-connect-reference), the subject claim only includes `pull_request` when the job doesn't reference an environment. Since both jobs reference one, both authenticate with an `environment:<name>` subject. One credential per environment covers both its plan and apply jobs.

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
> **Note 2:** The subject field is a strict match. An earlier version of this repo also created a `repo:...:pull_request`-subject credential, on the assumption the plan job authenticated separately from apply. It doesn't, once the plan job sets its own `environment:` key (it does here), so that credential is unused and can be removed if it's still around.

**7. Add repository/environment secrets**:
Settings → Secrets and variables → Actions. Repo-level secrets are visible to every job; environment-scoped secrets (Settings → Environments → *env* → Environment secrets) are visible only to jobs declaring that environment, and take precedence over a same-named repo secret.

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

Then set up a GitHub Environment for each apply gate: Settings → Environments → New environment, named to match the Terraform environment (`dev`, `attack-lab`). Under Deployment protection rules, check Required reviewers and add yourself.

> **Note 3:** While researching `backend.tf` I ran across [Atmos (CloudPosse)](https://atmos.tools/), an open-source orchestration tool for Terraform/Kubernetes/Helm that automates backend config. Better suited to managing multiple projects than what's needed here, but worth remembering.

> **Note 4:** This repository is a learning sandbox. Treat it as experimental and apply your own hardening as needed.

---

## Next Up: Ansible Configuration

Provisioning is done for both `dev` and `attack-lab`. Terraform stays scoped to infrastructure; anything in-guest lives in Ansible.

- [x] **Stage 0 — Scaffolding:** WinRM/SSH connectivity, dynamic inventory generated from Terraform outputs
- [ ] **Stage 1 — Hardening:** SSH/RDP hardening aligned to CIS benchmarks
- [x] **Stage 2 — Windows telemetry (`dev`):**
  - [x] Sysmon (SwiftOnSecurity config), installed, configured, verified flowing into Sentinel
  - [x] Atomic Red Team via `Invoke-AtomicRedTeam`, T1082 and T1059.001 running, confirmed in Log Analytics
  - [x] Scheduled task for continuous/unattended data generation
- [ ] **Stage 3 — Linux telemetry (`dev`):** auditd, rsyslog/CEF forwarding matched to the existing Syslog/CEF DCRs, Linux atomics
- [ ] **Stage 4 — Attack Lab telemetry (`attack-lab`):** Sysmon and Atomic Red Team on `WinTarget1-VM-AttackLab` (same roles as Stage 2, new inventory group). Kali stays unmonitored on purpose, see [Attack Lab Environment](#attack-lab-environment)
- [ ] **Stage 5 — Reactive validation:** run a technique from Kali against the Windows target and confirm it shows up as a Sentinel alert or incident. This is the actual point of the environment. Defender for Servers Plan 2 is being trial-validated manually in Defender for Cloud before it gets wired into Terraform

### Ansible Scope

| Role / Component | Purpose |
|---|---|
| `inventory/` | Dynamic-from-Terraform-output inventory, WinRM (Windows) and SSH (Linux). Currently covers `dev`'s WinSer1/UbuDoc1; `attack-lab`'s target/attacker still need adding |
| `roles/sysmon` | Installs Sysmon with the SwiftOnSecurity community config, verified flowing into Sentinel |
| `roles/atomic_red_team` | Installs Invoke-AtomicRedTeam and the atomics library, runs pinned MITRE ATT&CK technique tests on a schedule (unattended, SYSTEM context) to generate realistic telemetry |

---

## Future Enhancements

- [ ] Sentinel analytics rules and playbooks for common incident response scenarios
- [ ] Azure Monitor alerts triggering auto-scale or remediation steps
- [ ] Expand to `staging`/`prod` using the existing environment-agnostic modules
- [ ] Enable Microsoft Defender for Servers Plan 2 via Terraform (`azurerm_security_center_subscription_pricing`) once manually trial-validated

---

> This project is a living lab. It keeps changing as I learn more.
