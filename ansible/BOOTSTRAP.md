# Ansible Bootstrap — Manual Steps Log

Steps required to get Ansible working against the lab VMs that are **not**
captured by Terraform or committed config. Needed again if setting up a new
control node machine, or (for the per-VM section) if a VM is destroyed and
recreated. Keep this updated as Stage 0 (and later stages) progress.

## Control node setup (one-time per machine)

- [x] Install `pipx`, then `ansible-core` via `pipx install --include-deps ansible-core`
- [x] Install collections into project-local path: `ansible-galaxy collection install -r requirements.yml -p ./collections`
- [x] Fix system locale (was missing `es_CR.UTF-8` generation, broke `ansible-lint`):
      `sudo locale-gen es_CR.UTF-8 && sudo update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8`
- [x] `pipx inject ansible-core ansible-lint --include-apps` (plain `pipx inject` doesn't expose the CLI on PATH)
- [x] VS Code: set `ansible.python.interpreterPath` in `.vscode/settings.json` to the pipx venv's
      python (absolute path — `~` does not expand in VS Code JSON settings)
- [x] Create `ansible/.vault_pass` locally (gitignored) holding the Ansible Vault password,
      referenced via `vault_password_file` in `ansible.cfg`
- [ ] Recommended VS Code extensions: HashiCorp Terraform, Ansible (Red Hat), YAML (Red Hat),
      GitHub Actions, markdownlint, GitLens

## Per-VM setup (redo if VM is destroyed/recreated)

### Windows VM (WinRM)
- [x] NSG rule for inbound 5986 added via Terraform (`azurerm_network_security_rule.winrm_rule`,
      scoped to `var.client_ip`, same pattern as the RDP/SSH rules) — merged and deployed
- [ ] RDP into the VM
- [ ] Run WinRM enablement PowerShell on the guest itself (enable remoting, create self-signed
      cert + HTTPS listener on 5986, enable Basic auth, open Windows Firewall for 5986) —
      see `ansible/docs/winrm-setup.ps1` (TODO: extract into a saved script once confirmed working)
- [ ] Validate with `ansible windows -m win_ping` from the control node

### Linux VM (SSH)
- [x] No manual step — SSH key auth already provisioned via Terraform (`TF_VAR_pub_key`),
      matching private key already present locally at `~/.ssh/id_rsa`
- [ ] Validate with `ansible linux -m ping` from the control node

## Known gaps / future work
- Windows admin password duplicated between GH Secrets (CI/Terraform) and Ansible Vault
  (local) — no single source of truth yet. Candidate fix: Azure Key Vault, read by both
  Terraform and Ansible. Deferred for now (see project README/roadmap).
- WinRM setup above is currently manual per-VM. Could be automated later via Azure VM
  Custom Script Extension or a bootstrap script run at provision time.
- GitHub `dev` environment occasionally shows a deployment pending briefly before checks
  run — observed to self-resolve without changes (likely a transient GitHub-side delay,
  not a required-reviewer gate). Worth re-checking `Settings → Environments → dev →
  Deployment protection rules` if it recurs or stalls indefinitely.
