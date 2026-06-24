# Firefox Webapps Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install Microsoft Teams and Outlook as standalone Firefox-backed PWAs (via `firefoxpwa`) with their own launchers, declaratively, on the laptop (standalone Home Manager, Linux Mint) and the pc (NixOS).

**Architecture:** `pkgs.firefoxpwa` (wrapped connector with a nix-firefox runtime baked in) + the `pwas-for-firefox` browser extension force-installed via Firefox policy + an idempotent Home Manager activation step that runs `firefoxpwa site install` for each webapp. A single shared Nix helper holds the webapp list and renders the install snippet so both machines stay in sync.

**Tech Stack:** Nix flakes, Home Manager, NixOS, `firefoxpwa` (PWAsForFirefox), NUR (rycee firefox-addons).

## Global Constraints

- `firefoxpwa` attribute = `pkgs.firefoxpwa` (the wrapped one; `firefoxpwa-unwrapped` is the connector-only build — do NOT use it directly). Baked runtime is found via `FFPWA_SYSDATA`, which the wrapper sets; always invoke via the absolute store path `${pkgs.firefoxpwa}/bin/firefoxpwa`.
- Extension id: `firefoxpwa@filips.si`, package `pkgs.nur.repos.rycee.firefox-addons.pwas-for-firefox` (NUR already wired via `inputs.nur.overlays.default`).
- Webapps (source of truth):
  - `{ name = "Microsoft Teams"; url = "https://teams.microsoft.com/"; }`
  - `{ name = "Outlook"; url = "https://outlook.office.com/mail/"; }`
- The site-install activation MUST be idempotent and MUST be wrapped so it can never abort a switch: `( … ) || true`, with internal logic in a subshell (HM concatenates all activation blocks into one bash script).
- Firefox configPath on both machines is the legacy `.mozilla/firefox`; the per-user native-messaging dir on the laptop is therefore `~/.mozilla/native-messaging-hosts/`.
- "Build" = Nix evaluation. There is no unit-test framework; the test cycle for each task is: evaluate/build the config (catches Nix errors) → `switch` → verify observable behavior. Commit after each task.
- Match existing repo style: `_*-lib.nix` for pure shared helpers (see `machines/_monitors-lib.nix`), `*/nixos.nix` vs `*/home.nix` split for pc profiles, HM activation guarded in a subshell (see `machines/laptop/firefox-profile.nix`).

---

## Task 0: Confirm the firefoxpwa CLI surface (no code)

**Files:** none (investigation that pins the exact flags used by every later task).

**Interfaces:**
- Produces: the confirmed `firefoxpwa site install` invocation and the confirmed `firefoxpwa profile list` output substring used as the idempotency grep key.

- [ ] **Step 1: Get firefoxpwa into the shell**

Run:
```bash
. ~/.nix-profile/etc/profile.d/nix.sh 2>/dev/null
nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#firefoxpwa -c firefoxpwa --version
```
Expected: prints `firefoxpwa 2.18.x`.

- [ ] **Step 2: Read the install + list help**

Run:
```bash
nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#firefoxpwa -c firefoxpwa site install --help
nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#firefoxpwa -c firefoxpwa profile list --help
```
Expected: confirms the positional `<MANIFEST_URL>` / document-url argument and the `--name`, `--start-url`, and (if present) a no-manifest flag. Note the exact flag names.

- [ ] **Step 3: Record findings**

Confirm and write down (used verbatim in Tasks 2/4):
- the install command form — expected `firefoxpwa site install <url> --name "<name>"`, plus `--start-url <url>` if `<url>` alone yields no installable manifest;
- the `profile list` line that contains the app name (the idempotency grep key — expected the literal app name, e.g. `Microsoft Teams`).

If `site install <url> --name` rejects a site for lack of a manifest, the fix is to add `--start-url <url>` (and, if required by this firefoxpwa version, a no-manifest flag from the help output). Carry the confirmed form into Tasks 2 and 4.

*(No commit — investigation only.)*

---

## Task 1: Shared webapp helper

**Files:**
- Create: `machines/_webapps-lib.nix`

**Interfaces:**
- Produces:
  - `webapps` — a list of `{ name :: string; url :: string; }`.
  - `installScript { firefoxpwa }` — a function taking the `pkgs.firefoxpwa` derivation and returning a bash string: an idempotent, `|| true`-guarded subshell that installs each webapp in `webapps` if `firefoxpwa profile list` does not already name it. Invokes the connector as `${firefoxpwa}/bin/firefoxpwa`.

- [ ] **Step 1: Write the helper**

Create `machines/_webapps-lib.nix`:
```nix
# Shared definition of the Firefox PWAs (Teams, Outlook) and the idempotent
# `firefoxpwa site install` snippet, so the laptop (HM) and pc (NixOS+HM)
# activation scripts install the same set from one source of truth.
{ lib }:
let
  webapps = [
    { name = "Microsoft Teams"; url = "https://teams.microsoft.com/"; }
    { name = "Outlook"; url = "https://outlook.office.com/mail/"; }
  ];

  # Render one idempotent install line per webapp. `firefoxpwa profile list`
  # prints each installed site's name; skip install when the name is already
  # present. Names are fixed strings here, so a plain grep -F is safe.
  installLine = ffpwa: app: ''
    "${ffpwa}/bin/firefoxpwa" profile list 2>/dev/null | grep -qF ${lib.escapeShellArg app.name} \
      || "${ffpwa}/bin/firefoxpwa" site install ${lib.escapeShellArg app.url} --name ${lib.escapeShellArg app.name}
  '';

  # Whole block in a subshell + `|| true`: HM concatenates all activation
  # blocks into ONE bash script, so a bare failure here could abort the entire
  # switch. The guard makes a network error / refused install a no-op that
  # retries on the next switch instead of breaking activation.
  installScript = { firefoxpwa }: ''
    (
    ${lib.concatMapStrings (installLine firefoxpwa) webapps}
    ) || true
  '';
in
{
  inherit webapps installScript;
}
```

> If Task 0 found that a webapp needs `--start-url`, add `--start-url ${lib.escapeShellArg app.url}` to the `site install` line in `installLine`. If a webapp needs a different start URL than its document URL, add a `startUrl` field to its record and use it.

- [ ] **Step 2: Verify it evaluates**

Run:
```bash
. ~/.nix-profile/etc/profile.d/nix.sh 2>/dev/null
nix --extra-experimental-features 'nix-command flakes' eval --impure --expr \
  'let lib = (import <nixpkgs> {}).lib; m = import ./machines/_webapps-lib.nix { inherit lib; }; in builtins.length m.webapps' 2>&1 | tail -1
```
Expected: prints `2`.

- [ ] **Step 3: Commit**

```bash
git add machines/_webapps-lib.nix
git commit -m "feat(webapps): shared firefoxpwa webapp list + install snippet"
```

---

## Task 2: Laptop webapps module

**Files:**
- Create: `machines/laptop/profiles/webapps.nix`
- Modify: `machines/laptop/home.nix` (add to `imports`)

**Interfaces:**
- Consumes: `machines/_webapps-lib.nix` (`webapps`, `installScript`); `pkgs.firefoxpwa`; `pkgs.nur.repos.rycee.firefox-addons.pwas-for-firefox`.
- Produces: nothing other tasks consume (terminal for the laptop).

- [ ] **Step 1: Write the module**

Create `machines/laptop/profiles/webapps.nix`:
```nix
# Firefox PWAs (Teams, Outlook) on the laptop (standalone HM, non-NixOS).
# - firefoxpwa on PATH (connector + CLI; runtime is baked into the package).
# - Native-messaging host manifest hand-placed in the per-user dir, because a
#   non-NixOS Firefox has no nativeMessagingHosts wrapper. Every Firefox build
#   scans ~/.mozilla/native-messaging-hosts/.
# - Browser extension force-installed via Firefox policy (merges with the
#   policies in profiles/theming.nix).
# - Idempotent site install on activation (see machines/_webapps-lib.nix).
{ config, lib, pkgs, ... }:
let
  webappsLib = import ../../_webapps-lib.nix { inherit lib; };
  addons = pkgs.nur.repos.rycee.firefox-addons;
in
{
  home.packages = [ pkgs.firefoxpwa ];

  home.file.".mozilla/native-messaging-hosts/firefoxpwa.json".source =
    "${pkgs.firefoxpwa}/lib/mozilla/native-messaging-hosts/firefoxpwa.json";

  programs.firefox.policies.ExtensionSettings."firefoxpwa@filips.si" = {
    installation_mode = "force_installed";
    install_url = "file://${addons.pwas-for-firefox}/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}/firefoxpwa@filips.si.xpi";
  };

  home.activation.installWebapps =
    lib.hm.dag.entryAfter [ "installPackages" ]
      (webappsLib.installScript { firefoxpwa = pkgs.firefoxpwa; });
}
```

> The xpi filename under the NUR addon is `<addonId>.xpi` = `firefoxpwa@filips.si.xpi`, in the standard Firefox extensions dir keyed by the toolkit app id `{ec8030f7-c20a-464f-9b0e-13a3a9e97384}` — same shape as the uBlock/Proton entries in `theming.nix`. Confirm the exact path in Step 2; if it differs, correct `install_url`.

- [ ] **Step 2: Verify the xpi path exists**

Run:
```bash
. ~/.nix-profile/etc/profile.d/nix.sh 2>/dev/null
P=$(nix --extra-experimental-features 'nix-command flakes' build --impure --no-link --print-out-paths --expr \
  'let f = builtins.getFlake (toString ./.); p = import f.inputs.nixpkgs { system = "x86_64-linux"; overlays = [ f.inputs.nur.overlays.default ]; }; in p.nur.repos.rycee.firefox-addons.pwas-for-firefox')
find "$P" -name '*.xpi'
```
Expected: prints a path ending in `firefoxpwa@filips.si.xpi`. If the directory id or filename differs, update `install_url` to match.

- [ ] **Step 3: Add to laptop imports**

In `machines/laptop/home.nix`, add `./profiles/webapps.nix` to the `imports` list (alongside the other `./profiles/*.nix` entries).

- [ ] **Step 4: Build the config (test: it evaluates)**

Run:
```bash
. ~/.nix-profile/etc/profile.d/nix.sh 2>/dev/null
nix --extra-experimental-features 'nix-command flakes' build --no-link .#homeConfigurations.niklas.activationPackage 2>&1 | tail -20
```
Expected: builds with no evaluation error. (The `niklas` homeConfiguration is the laptop output per `machines/laptop/home.nix`.)

- [ ] **Step 5: Switch (close Firefox first — the profile-adoption script aborts if Firefox is running)**

Run:
```bash
home-manager switch --flake .#niklas 2>&1 | tail -30
```
Expected: activation completes; `installWebapps` runs without aborting the switch.

- [ ] **Step 6: Verify (test: behavior)**

Run:
```bash
. ~/.nix-profile/etc/profile.d/nix.sh 2>/dev/null
firefoxpwa profile list
ls ~/.mozilla/native-messaging-hosts/firefoxpwa.json
ls ~/.local/share/applications/FFPWA-*.desktop
```
Expected: `profile list` shows "Microsoft Teams" and "Outlook"; the manifest symlink exists; one `FFPWA-*.desktop` per app exists.

**Gate:** If `site install` failed (no installable manifest), apply the Task 0 fallback (`--start-url`, etc.) in `machines/_webapps-lib.nix`, re-run Steps 4–6, and only then proceed. The laptop is the proving ground before duplicating to pc.

- [ ] **Step 7: Verify idempotency**

Run `home-manager switch --flake .#niklas` again.
Expected: completes; `firefoxpwa profile list` still shows exactly one Teams and one Outlook (no duplicates).

- [ ] **Step 8: Launch check**

Open the launcher and confirm a standalone window:
```bash
firefoxpwa profile list   # note an installed site's ULID
```
Launch its `~/.local/share/applications/FFPWA-<id>.desktop` (from the app menu or `gtk-launch`). Expected: opens in its own window, app-id `FFPWA-<id>`.

- [ ] **Step 9: Commit**

```bash
git add machines/laptop/profiles/webapps.nix machines/laptop/home.nix machines/_webapps-lib.nix
git commit -m "feat(webapps): laptop firefoxpwa module (Teams + Outlook)"
```

---

## Task 3: pc NixOS wiring (package + manifest + extension)

**Files:**
- Create: `machines/pc/profiles/webapps/nixos.nix`
- Modify: `machines/pc/default.nix` (add to `imports`)

**Interfaces:**
- Consumes: `pkgs.firefoxpwa`; `pkgs.nur.repos.rycee.firefox-addons.pwas-for-firefox`. Relies on the existing NixOS `programs.firefox.enable = true` in `machines/pc/profiles/core/nixos.nix`.
- Produces: a working connector + extension for the pc's system Firefox (consumed by Task 4's activation at runtime).

- [ ] **Step 1: Write the NixOS module**

Create `machines/pc/profiles/webapps/nixos.nix`:
```nix
# Firefox PWAs on the pc (NixOS). System Firefox is enabled in core/nixos.nix,
# so use the blessed NixOS mechanism: put firefoxpwa in PATH AND register it as
# a native-messaging host so the browser extension can detect the connector.
# The baked runtime is the nix Firefox (no download). Site install itself runs
# as the user in webapps/home.nix.
{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.firefoxpwa ];
  programs.firefox.nativeMessagingHosts.packages = [ pkgs.firefoxpwa ];

  programs.firefox.policies.ExtensionSettings."firefoxpwa@filips.si" = {
    installation_mode = "force_installed";
    install_url = "file://${pkgs.nur.repos.rycee.firefox-addons.pwas-for-firefox}/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}/firefoxpwa@filips.si.xpi";
  };
}
```

> `programs.firefox.policies` here merges with the existing `ExtensionSettings` block in `machines/pc/profiles/core/nixos.nix` (different keys, attrset deep-merge). Use the xpi path confirmed in Task 2 Step 2.

- [ ] **Step 2: Add to pc imports**

In `machines/pc/default.nix`, add `./profiles/webapps/nixos.nix` to the `imports` list (alongside the other `./profiles/*/nixos.nix` entries).

- [ ] **Step 3: Build (test: it evaluates)**

Run on the pc (or eval-only anywhere):
```bash
nix --extra-experimental-features 'nix-command flakes' build --no-link .#nixosConfigurations.<pc-hostname>.config.system.build.toplevel 2>&1 | tail -20
```
Expected: builds with no evaluation error. (Use the pc hostname from `machines/pc/vars.nix`; the flake exposes it under `nixosConfigurations`.)

- [ ] **Step 4: Commit**

```bash
git add machines/pc/profiles/webapps/nixos.nix machines/pc/default.nix
git commit -m "feat(webapps): pc NixOS wiring for firefoxpwa (connector + extension)"
```

---

## Task 4: pc activation (site install)

**Files:**
- Create: `machines/pc/profiles/webapps/home.nix`
- Modify: `machines/pc/home.nix` (add to `imports`)

**Interfaces:**
- Consumes: `machines/_webapps-lib.nix` (`installScript`); `pkgs.firefoxpwa`.
- Produces: terminal for the pc.

- [ ] **Step 1: Write the HM module**

Create `machines/pc/profiles/webapps/home.nix`:
```nix
# Site install for the pc PWAs. The package + native-messaging host + extension
# come from webapps/nixos.nix; this only runs the idempotent
# `firefoxpwa site install` as the user (see machines/_webapps-lib.nix).
{ lib, pkgs, ... }:
let
  webappsLib = import ../../../_webapps-lib.nix { inherit lib; };
in
{
  home.activation.installWebapps =
    lib.hm.dag.entryAfter [ "installPackages" ]
      (webappsLib.installScript { firefoxpwa = pkgs.firefoxpwa; });
}
```

> Path depth: `machines/pc/profiles/webapps/home.nix` → `_webapps-lib.nix` is three levels up (`../../../`). Confirm against the laptop module's two-level `../../` (it lives one directory shallower).

- [ ] **Step 2: Add to pc HM imports**

In `machines/pc/home.nix`, add `./profiles/webapps/home.nix` to the `imports` list.

- [ ] **Step 3: Build (test: it evaluates)**

Run:
```bash
nix --extra-experimental-features 'nix-command flakes' build --no-link .#nixosConfigurations.<pc-hostname>.config.system.build.toplevel 2>&1 | tail -20
```
Expected: builds with no evaluation error (HM is built as part of the system toplevel via the `home-manager` NixOS module in `machines/pc/default.nix`).

- [ ] **Step 4: Switch + verify on the pc (test: behavior)**

Run on the pc:
```bash
sudo nixos-rebuild switch --flake .#<pc-hostname> 2>&1 | tail -30
firefoxpwa profile list
ls ~/.local/share/applications/FFPWA-*.desktop
```
Expected: rebuild completes; `profile list` shows Teams + Outlook; launchers exist. Re-run the rebuild once more → no duplicate installs.

- [ ] **Step 5: Commit**

```bash
git add machines/pc/profiles/webapps/home.nix machines/pc/home.nix
git commit -m "feat(webapps): pc site-install activation (Teams + Outlook)"
```

---

## Task 5: Documentation

**Files:**
- Modify: `README.md` (if it documents per-machine profiles/modules — match existing structure)

**Interfaces:** none.

- [ ] **Step 1: Check whether README lists modules**

Run: `grep -n "profiles\|firefox\|module" README.md | head`
If the README enumerates profiles/modules, add a one-line "webapps" entry describing the firefoxpwa PWAs (Teams, Outlook) and that the app list lives in `machines/_webapps-lib.nix`. If it does not, skip this task.

- [ ] **Step 2: Commit (only if README changed)**

```bash
git add README.md
git commit -m "docs(webapps): note firefoxpwa webapps module"
```

---

## Self-Review

**Spec coverage:**
- firefoxpwa package on PATH → Task 2 (laptop `home.packages`), Task 3 (pc `environment.systemPackages`). ✓
- Native-messaging manifest, per-machine split → Task 2 (`home.file`), Task 3 (`nativeMessagingHosts.packages`). ✓
- Extension force-install → Task 2 + Task 3 (`ExtensionSettings`, rycee xpi). ✓
- Webapp list as single source of truth → Task 1 (`_webapps-lib.nix`), consumed by Tasks 2 + 4. ✓
- Idempotent, switch-safe activation → Task 1 (`installScript`, subshell + `|| true` + grep guard), wired in Tasks 2 + 4. ✓
- nix-firefox runtime / no download → Global Constraints (baked, `FFPWA_SYSDATA`); no task needs to install a runtime. ✓
- Verification (profile list, launchers, idempotency) → Task 2 Steps 6–8, Task 4 Step 4. ✓
- Risk: manifest may need `--start-url` → Task 0 + Task 2 gate + lib note. ✓

**Placeholder scan:** No TBD/TODO/"handle edge cases"; `<pc-hostname>` is an explicit lookup (from `machines/pc/vars.nix`), not a placeholder for logic. Task 0 deliberately defers the exact install flags to a confirm-by-running step, with a concrete default and a concrete fallback.

**Type consistency:** `installScript { firefoxpwa = …; }` defined in Task 1 is called identically in Tasks 2 and 4. `webapps` is a `{name; url;}` list throughout. xpi id `firefoxpwa@filips.si` and toolkit dir id `{ec8030f7-…}` identical in Tasks 2 and 3.
