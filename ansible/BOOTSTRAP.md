# Ansible Bootstrap — Manual Steps Log

Steps required to get Ansible working against the lab VMs that are **not**
captured by Terraform or committed config. Needed again if setting up a new
control node machine, or (for the per-VM section) if a VM is destroyed and
recreated. Stage 0 (WinRM/SSH connectivity, dynamic inventory scaffolding) is
complete as of this version — `win_ping` and `ping` both succeed.

## Control node setup (one-time per machine)

- [x] Install `pipx`, then `ansible-core` via `pipx install --include-deps ansible-core`
- [x] Install collections into project-local path (from `ansible/`):
      `ansible-galaxy collection install -r requirements.yml -p ./collections`
      — verify with `ansible-galaxy collection list`, should show `ansible.windows`,
      `community.windows`, `ansible.posix` resolving under `./collections`, not `~/.ansible`
- [x] Install `pywinrm` into the same isolated venv as `ansible-core` (required for the
      WinRM connection plugin — separate from collections, which only cover Ansible-specific
      content, not general Python dependencies):
      `pipx inject ansible-core pywinrm`
- [x] Fix system locale if `ansible-lint` errors with "unable to initialize preferred locale"
      (was missing `es_CR.UTF-8` generation on this machine):
      `sudo locale-gen es_CR.UTF-8 && sudo update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8`
- [x] `pipx inject ansible-core ansible-lint --include-apps` (plain `pipx inject` doesn't
      expose the CLI on PATH — `--include-apps` is required, unlike the `pywinrm` step above
      which is a library, not a CLI tool)
- [x] VS Code: set `ansible.python.interpreterPath` in `.vscode/settings.json` to the pipx
      venv's python (absolute path — `~` does not expand in VS Code JSON settings)
- [x] Create `ansible/.vault_pass` locally (gitignored) holding the Ansible Vault password,
      referenced via `vault_password_file = ./.vault_pass` in `ansible.cfg`
- [x] SSH: confirm which local keypair actually matches what was provisioned via Terraform's
      `TF_VAR_pub_key` — don't assume `~/.ssh/id_rsa` by default; check `group_vars/linux/vars.yml`
      for the path currently in use (`~/.ssh/id_ed25519` as of this setup)
- [x] SSH: one-time manual connection to accept each VM's host key before Ansible can connect
      non-interactively: `ssh -i ~/.ssh/id_ed25519 sendockadmin@<public_ip>`, accept fingerprint, exit
- [x] Recommended VS Code extensions: HashiCorp Terraform, Ansible (Red Hat), YAML (Red Hat),
      GitHub Actions, markdownlint, GitLens
- [x] Client IP: if reconnecting from a new/changed network, run `scripts/update-client-ip.sh`
      from repo root before relying on RDP/SSH/WinRM access — updates the `CLIENT_IP` GH
      secret used by the NSG rules (see `scripts/pre-push-check.sh`, which warns on drift
      but does not auto-update)

## Reminders on always-required conventions

- Always run Ansible commands from inside `ansible/` — relative paths in `ansible.cfg`
  (collections, inventory, vault password file) resolve against the current working
  directory, not the config file's own location.
- Always use fully-qualified collection names for non-builtin modules (e.g.
  `ansible.windows.win_ping`, not `win_ping`) — current `ansible-core` doesn't apply
  legacy short-name redirects to ad-hoc commands.

## Per-VM setup (redo if VM is destroyed/recreated)

### Windows VM (WinRM)
- [x] RDP into the VM, run as Administrator in PowerShell:
  ```powershell
  # 1. Enable WinRM service, auto-start, default listener + firewall exceptions
  Enable-PSRemoting -Force
  # 2. Self-signed cert for the HTTPS listener
  $cert = New-SelfSignedCertificate -DnsName $env:COMPUTERNAME -CertStoreLocation Cert:\LocalMachine\My
  # 3. Create the HTTPS listener bound to that cert
  New-Item -Path WSMan:\localhost\Listener -Transport HTTPS -Address * -CertificateThumbPrint $cert.Thumbprint -Force
  # 4. Enable Basic auth (matches ansible_winrm_transport: basic in our inventory)
  Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $true
  # 5. Open the guest's own Windows Firewall for 5986 (separate from the Azure NSG rule already in place)
  New-NetFirewallRule -Name "WinRM-HTTPS" -DisplayName "WinRM over HTTPS" -Enabled True -Direction Inbound -Protocol TCP -LocalPort 5986
  ```
- [ ] Or Run WinRM enablement PowerShell (enable remoting, create self-signed cert + HTTPS
      listener on 5986, enable Basic auth, open Windows Firewall for 5986) — see
      `ansible/docs/winrm-setup.ps1` (TODO: extract into a saved script once confirmed working)

- [x] Verify listener on the guest: `winrm enumerate winrm/config/listener` — confirm
      `Transport = HTTPS`, `Port = 5986`, `CertificateThumbprint` populated
- [x] Validated with `ansible windows -m ansible.windows.win_ping` — SUCCESS

### Linux VM (SSH)
- [x] No manual provisioning step — SSH key auth already set up via Terraform (`TF_VAR_pub_key`), however a first manual ssh -v -i ~/.ssh/id_ed25519 sendockadmin@<IP> might be required to the VM's host key as Ansible runs non-interactively with no terminal for that prompt to appear in, so it fails.
- [x] Confirmed correct local keypair (`~/.ssh/id_ed25519`, not the originally-assumed `id_rsa`)
      and accepted host key manually once (see control-node section above)
- [x] Validated with `ansible linux -m ping` — SUCCESS

## Known gaps / future work

- **Windows admin password duplicated** between GH Secrets (CI/Terraform) and Ansible
  Vault (local) — no single source of truth yet. Candidate fix: Azure Key Vault, read by
  both Terraform and Ansible. Deferred (see project README/roadmap).

- **WinRM bootstrap is fully manual per-VM** (RDP in, run PowerShell by hand) — this is a
  one-time cost per VM's lifetime, not a recurring one, but resurfaces every time a VM is
  destroyed/recreated. Candidate fix: Azure Custom Script Extension
  (`azurerm_virtual_machine_extension`) to run the WinRM-enablement script automatically
  at VM boot. Worth deciding first whether "enabling WinRM so Ansible can manage the VM"
  belongs in Terraform (infra provisioning) or Ansible (configuration) given the strict
  separation this project maintains between the two — not just a technical change, a
  boundary decision.

- **SSH host-key acceptance is manual per-VM** (first connection must be interactive) —
  same one-time-per-VM-lifetime caveat as above. Candidate fixes: `ssh-keyscan <ip> >>
  ~/.ssh/known_hosts` as a scripted, non-interactive step; or `host_key_checking = False`
  in `ansible.cfg` for this lab specifically (trades away the check rather than automating
  around it — worth being deliberate about that tradeoff rather than defaulting to it).

- **NSG rules are not scoped per-OS — security gap, not just a nice-to-have.** Currently
  one subnet (`modules/network`) with one NSG attached at the subnet level
  (`azurerm_subnet_network_security_group_association`), containing all three rules
  (RDP/3389, SSH/22, WinRM/5986). This means the Windows VM has SSH open despite running
  no SSH server, and the Linux VM has RDP and WinRM open despite running neither — likely
  fail closed today since nothing's listening behind them, but still unnecessary attack
  surface. Because the NSG is subnet-level (not NIC-level), fixing this properly means
  **splitting into two subnets** (one per VM/OS), each with its own NSG and only the
  relevant rule(s) — a real topology change to `modules/network`, not a quick patch.
  Deferred to Stage 1 (hardening) rather than done ad hoc.