# SRE‑Focused Azure Sentinel Deployment

This repository contains **Terraform 4.1.0** code that provisions a minimal yet functional Azure environment for learning and practicing Site‑Reliability Engineering concepts around Microsoft Sentinel.

## Overview

- Deploys a **Windows 2022 VM** (small‑disk) and an **Ubuntu 24‑04‑LTS VM**  
- Installs a **Log Analytics Workspace** that feeds into Sentinel
- Configures:
  - **Performance Counter DCR**
  - **SecurityEvents Windows Event DCR**
  - A **Sentinel workspace**
  - An **Activity Log policy** to ingest Azure activity logs
- (In future) will add **Ansible** playbooks for:
  - Populating the VMs with *Log of Loud* (LOLBins) and administrative tools
  - Generating realistic Sentinel‑consuming event traffic

The goal is an evolving playground for SRE skill building monitoring, observability, incident response, and Azure‑native tooling.

## Current Scope

| Resource | Purpose |
|----------|---------|
| `windows_vm` | Windows 2022 with small disk for local experimentation |
| `linux_vm`  | Ubuntu 24‑04‑LTS for Linux‑side testing |
| `log_analytics_ws` | Central collection point for all telemetry |
| `dcr_perf_counter` | Performance counters from VMs → Sentinel |
| `dcr_windows_event` | Windows SecurityEvents → Sentinel |
| `sentinel_workspace` | Core Sentinel workspace for alerts & playbooks |
| `activity_log_policy` | Ingests Azure activity logs into Sentinel |

## Prerequisites

- **Azure CLI 2.88** (`az --version`) – use the latest release to avoid deprecations.  
- Terraform 4.1.0 (the version this repo was tested against).  
- An active Azure subscription with sufficient RBAC for resource creation.

> **Note:** The repository is a learning sandbox; treat it as experimental and keep security hardening to your own policies.

## Future Enhancements

- Add **Ansible** for automated OS hardening and LOLBin deployment.
- Expand DCRs for additional Windows/Linux logs (Syslog, PowerShell, etc.).
- Implement Sentinel playbooks for common incident response scenarios.
- Integrate Azure Monitor alerts to trigger Auto‑Scale or remediation steps.

---

> *This project is a living lab; it will be changing as I acquire new SRE knowledge.*