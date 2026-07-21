# Ansible Stage 0 — Troubleshooting Log

Real issues hit while setting up scaffolding, with root cause and fix, for
pattern-matching against future problems that might look similar on the surface.

## Locale error breaking ansible-lint
**Symptom:** `ERROR: Ansible could not initialize the preferred locale: unsupported
locale setting` when running `ansible-lint` (surfaced via the VS Code Ansible extension).
**Root cause:** System had `es_CR.UTF-8` referenced across most `LC_*` env vars, but that
locale was never generated on disk (`locale -a` didn't list it) — only `en_*` variants and
`C`/`POSIX` were actually built.
**Fix:** `sudo locale-gen es_CR.UTF-8`, then `sudo update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8`,
new terminal to pick up the change.
**Pattern to remember:** `update-locale` only *writes config*; `locale-gen` is what
actually *generates* the locale data. Config pointing at an ungenerated locale fails
silently in some tools, loudly (and confusingly) in others.

## `ansible-vault create` failing with "No such file or directory: 'vi'"
**Symptom:** Vault creation failed trying to launch an editor.
**Root cause:** No `vi` on PATH (minimal Ubuntu install).
**Fix:** `EDITOR="code --wait" ansible-vault create <path>` (or `nano` as a lighter
fallback). The `--wait` flag is required for GUI editors — without it, Ansible would
encrypt an empty file before you finish editing.

## `ansible-lint` extension error persisted after locale fix
**Symptom:** VS Code Ansible extension still errored after ansible-lint worked fine
from the terminal.
**Root cause:** `pipx inject ansible-core ansible-lint` installs the package into the
venv but does **not** expose its CLI entry point on PATH by default.
**Fix:** `pipx inject ansible-core ansible-lint --include-apps`.

## `ansible-inventory --list` showing unresolved `{{ vault_var }}` template
**Symptom:** `ansible_password` field showed the literal Jinja string, not the
decrypted value.
**Root cause:** Not a bug — `ansible-inventory` intentionally does not run the Jinja
templating engine on hostvars; it shows raw declarations. Templating only happens
during an actual playbook/ad-hoc task run.
**Fix:** N/A — expected behavior, confirmed correct resolution instead via an actual
`win_ping` run once WinRM was live.

## `win_ping` — "Cannot resolve to an action or module"
**Symptom:** Both bare `win_ping` and fully-qualified `ansible.windows.win_ping` failed
to resolve.
**Root cause:** Collections were never actually installed into the project-local
`./collections` path — `ansible-galaxy collection install -r requirements.yml -p ./collections`
either wasn't re-run after switching to project-scoping, or didn't complete. Confirmed via
`ansible-galaxy collection list` returning empty and the `ansible_collections/` subfolder
not existing on disk.
**Fix:** Re-run the install command for real; verify with `ansible-galaxy collection list`
before retrying the module.
**Pattern to remember:** Bare module names like `win_ping` rely on legacy short-name
redirects that current `ansible-core` doesn't apply to ad-hoc commands — always use the
FQCN (`ansible.windows.win_ping`) going forward regardless of whether collections are
installed correctly.

## `win_ping` — "winrm or requests is not installed: No module named 'winrm'"
**Symptom:** After fixing the collections-path issue above, FQCN `ansible.windows.win_ping`
resolved correctly but still failed at connection time.
**Root cause:** The WinRM *connection plugin* depends on `pywinrm`, a regular third-party
Python library — separate from Ansible collections entirely. `ansible-galaxy` only
installs Ansible-specific content (modules/plugins/docs); it doesn't manage general
Python dependencies. `pywinrm` was never installed into the pipx-managed venv
`ansible-core` actually runs in.
**Fix:** `pipx inject ansible-core pywinrm` (no `--include-apps` needed — it's a library
being imported, not a CLI tool being exposed on PATH).
**Result:** `ansible windows -m ansible.windows.win_ping` → SUCCESS. This was the final
blocker for Stage 0.

## SSH: "Host key verification failed" then later "Permission denied (publickey)"
**Symptom:** Two sequential SSH failures against the Linux VM via Ansible.
**Root cause (1st):** Ansible runs non-interactively, so it can't answer the normal
"are you sure you want to continue connecting?" host-key prompt — first-ever connection
to a host always needs this accepted somewhere.
**Fix (1st):** One-time manual `ssh` to the VM directly, accept the fingerprint, which
populates `~/.ssh/known_hosts`.
**Root cause (2nd):** `ansible_ssh_private_key_file` was pointing at `~/.ssh/id_rsa`,
but the VM was actually provisioned against a different keypair
(`~/.ssh/id_ed25519`) — assumed default location was wrong, never actually confirmed
against what Terraform's `TF_VAR_pub_key` provisioned.
**Fix (2nd):** Updated `ansible_ssh_private_key_file` in `group_vars/linux/vars.yml` to
`~/.ssh/id_ed25519`. Diagnosed via `ssh -v` directly (bypassing Ansible) to see exactly
which key was offered/rejected — worth reaching for `-v` earlier next time a
publickey auth failure isn't self-explanatory.

- **Lint extension false-positive: "role not found"**: the IDE's ansible-lint
  extension runs its own internal syntax-check that doesn't reliably inherit
  ansible.cfg's roles_path — it evaluates roles in list order and halts at
  the first failure, so only the *first* role in a playbook's `roles:` list
  ever shows this error (subsequent roles appear to pass, but were never
  actually checked). Confirmed not a real problem: `ansible-lint roles/<role>/`
  and `ansible-playbook <playbook> --syntax-check` (the real tools, run
  directly) both correctly resolve roles via ansible.cfg's roles_path and
  pass clean. Fix, if wanted: `set -Ux ANSIBLE_ROLES_PATH (pwd)/roles` —
  but this is a machine-wide env var, not project-scoped, so it'll affect
  any other Ansible projects on this machine too. Left unset; treating this
  as a known, ignorable extension quirk instead.

  - **`Set-PSRepository -Name PSGallery -InstallationPolicy Trusted` fails with
  "NonInteractive mode" / NuGet provider error**: Windows Server 2022 doesn't
  ship with the NuGet package provider pre-installed. The first PSGallery
  interaction normally prompts to install it interactively — over WinRM
  there's no one to answer the prompt, so it fails outright instead of
  hanging. Fix: explicitly install NuGet first, non-interactively:
  `Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force`
  before any PSGallery/PowerShellGet task.

- **`Install-AtomicRedTeam` not recognized immediately after running
  `install-atomicredteam.ps1`**: the script only *defines* the
  `Install-AtomicRedTeam` function — it doesn't call it. Running a .ps1
  file directly executes it in a child scope, so any function it defines
  disappears once the script finishes; the very next command can't find
  it. Fix: dot-source the script (`. path\to\script.ps1`) instead of
  invoking it directly — this runs it in the current scope, so the
  function persists for the following `Install-AtomicRedTeam ...` call.

  - **`.ansible-lint` config errors: "Additional properties are not allowed
  ('roles_path' was unexpected)"** then **"None is not of type 'object'"**:
  `roles_path` was mistakenly added to `.ansible-lint` (copying the
  ansible.cfg pattern) — it's not a valid key in ansible-lint's config
  schema at all. Removing the key but leaving only a comment/`---` marker
  then failed differently, since an empty YAML document parses to `None`,
  which also fails the schema (expects an object). Fix: delete the file
  entirely — `.ansible-lint` isn't required to exist; ansible-lint falls
  back to its own defaults with no config file present. `ansible.cfg`'s
  `roles_path` was already sufficient on its own the whole time.

  ### Invoke-AtomicTest not recognized when run as SYSTEM (scheduled task)

**Symptom:** `atomic_red_team` role installs and runs cleanly via Ansible
(`run.yml`), but the scheduled task created in `schedule.yml` fails every
time with:

```
The term 'Invoke-AtomicTest' is not recognized as the name of a cmdlet,
function, script file, or operable program.
```

`Import-Module` on `Invoke-AtomicRedTeam.psd1` (absolute path) does not
error — the module manifest loads. The exported function is simply never
registered.

**Cause:** `install-atomicredteam.ps1` installs its own dependency,
`powershell-yaml` (used to parse atomic test YAML definitions), with:

```powershell
Install-Module -Name powershell-yaml -Scope CurrentUser -Force
```

`CurrentUser` scope puts the module in the profile of whichever account
Ansible connected as over WinRM (e.g. `sentineladmin`). The scheduled
task runs as `SYSTEM`, which has its own separate `$env:PSModulePath` and
cannot see that profile. `Invoke-AtomicRedTeam` depends on
`powershell-yaml` internally, so it silently fails to finish initializing
and `Invoke-AtomicTest` is never exported — with no error at import time.

Ad-hoc `win_shell` runs (`run.yml`) never hit this, because those execute
in the WinRM connection's own user context, where `CurrentUser` scope is
sufficient.

**Fix:** Reinstall `powershell-yaml` at `AllUsers` scope after
`install-atomicredteam.ps1` runs, gated on its own presence check —
*not* on `atomic_red_team_needs_update` (that variable tracks atomics
library freshness on a 7-day cycle; reusing it here means the fix
silently doesn't run again until the next cache-refresh window):

```yaml
- name: Check if powershell-yaml is available machine-wide
  ansible.windows.win_shell: >
    [bool](Get-Module -ListAvailable -Name powershell-yaml | Where-Object Path -NotMatch '\\Users')
  args:
    executable: powershell
  register: atomic_red_team_powershell_yaml_check
  changed_when: false

- name: Ensure powershell-yaml is available machine-wide (required for SYSTEM-context runs)
  ansible.windows.win_shell: >
    Install-Module -Name powershell-yaml -Scope AllUsers -Force
  args:
    executable: powershell
  when: "'True' not in atomic_red_team_powershell_yaml_check.stdout"
```

**Verify:** Trigger the task manually and tail the log —
`Start-ScheduledTask -TaskName "AtomicRedTeam-ScheduledRun"`, then check
`C:\AtomicRedTeam\scheduled-run.log`. A successful run shows only the
start/finish banners with nothing in between (`Invoke-AtomicTest`'s
progress output goes to a stream `Out-File`/`2>&1` doesn't capture) and
completes in several seconds rather than instantly — an immediate
start-to-finish gap (<2s) with no output at all is the old failure mode,
not success.

---

### `win_shell` fails to parse a PowerShell command ending a quoted string in a backslash

**Symptom:** A `win_shell` task fails at the Ansible parsing stage
(before the module ever runs) with:

```
failed at splitting arguments, either an unbalanced jinja2 block or quotes
```

...even though every quote and brace in the command is actually balanced.

**Cause:** Ansible's free-form argument splitter (`split_args`) treats a
backslash immediately before a closing quote as escaping that quote,
regardless of quote type (`'` or `"`) or how many backslashes precede it.
A PowerShell regex literal like `'\\Users\\'` — a perfectly valid pattern
in PowerShell — reads to Ansible's parser as an unterminated string,
because the last character before the final `'` is a `\`.

Confirmed directly against `ansible.parsing.splitter.split_args`: strings
ending `...\\'` fail regardless of surrounding content; the same string
with the trailing backslash removed (`...\\'` → `...'`) parses cleanly.
Curly braces (`{ }`) from PowerShell script blocks were suspected first
but ruled out — they parse fine on their own.

**Fix:** Never let a quoted string inside a `win_shell`/`win_command`
one-liner end in a literal backslash. Where the match doesn't need to be
anchored, drop the trailing backslash rather than escaping it — e.g.
`-NotMatch '\\Users'` (substring match) instead of `'\\Users\\'`. If a
trailing backslash is unavoidable, pad with an extra literal character
after it inside the same quotes.