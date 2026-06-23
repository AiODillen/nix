# Per-Machine Profile Split Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the shared `profiles/` tree + `mySystem` options/toggles with two self-contained per-machine trees (NixOS PC, standalone laptop) that share only the flake inputs.

**Architecture:** Each machine gets its own `vars.nix` (plain attrset), its own copies of the helper modules (`firefox-profile.nix`, `nixgl.nix`, `monitors.nix`), and its own `profiles/`. `flake.nix` imports each machine's `vars.nix` and threads it as the `vars` specialArg. Feature toggles disappear: a profile runs iff it is imported. Cut over one machine at a time so the flake stays buildable after each task.

**Tech Stack:** Nix flakes, home-manager (release-26.05), NixOS (nixos-26.05), stylix, nixGL.

## Global Constraints

- Only `flake.nix` + `flake.lock` are shared between machines. No shared `profiles/`, `settings.nix`, `modules/`, `users/`, or `template/`.
- No `mySystem` namespace, no `lib.mkIf <toggle>` guards, no `osConfig`/`settings` args in profiles. Profiles read values from the `vars` specialArg only.
- No behavioural change vs the current tree: same packages, theming (`scheme = "monokai"`, `polarity = "dark"`), locale (`en_US.UTF-8` / `de_DE.UTF-8`, xkb `de`/`nodeadkeys`), desktop (niri).
- PC identity: `hostname = "nixos"`, `user = "dillen"`. Laptop identity: `user = "niklas"`, `gpu = "mesa"`, `flakePath = "~/Documents/nix"`.
- gnome profiles are dropped (neither machine uses them).
- Firefox profile name is the fixed `"default"`; `configPath = ".mozilla/firefox"`; the first-activation adoption script is kept on both machines.
- Duplication across machines (niri config.kdl, nixgl, firefox adoption, monitors module, theming/locale values, wallpaper) is intentional.
- Verification per task is Nix evaluation/build, not unit tests. The repo has no test framework.

**Transformation rule (applies to every moved profile):**
1. Change the module arg header to take `{ vars, ... }` (plus `lib`/`pkgs`/`config`/`inputs` as that file already needs).
2. Delete any `lib.mkIf <guard> { ... }` wrapper — keep the inner body at top level.
3. Replace every `settings.<X>` and `osConfig.mySystem.<X>` reference with the `vars.<X>` equivalent (mapping table in each task).
4. Leave all other content (packages, stylix targets, activation scripts, policies) byte-identical.

---

## File map

```
flake.nix                         (rewritten — both halves)
machines/
  pc/
    vars.nix                      (new)
    default.nix                   (rewritten)
    hardware.nix                  (unchanged)
    home.nix                      (new — replaces users/home.nix)
    monitors.nix                  (rewritten — osConfig→vars, self-contained)
    firefox-profile.nix           (new — copy of modules/home/firefox-profile.nix)
    wallpaper.png                 (new — copy of root wallpaper.png)
    profiles/
      core/{nixos.nix,home.nix}
      shell/{nixos.nix,home.nix}
      theming/{nixos.nix,home.nix}
      gaming/{nixos.nix,home.nix}
      ai/{nixos.nix,home.nix,claude-plugins.nix}
      local-ai/nixos.nix
      storage/nixos.nix
      desktop/niri/{nixos.nix,home.nix,config.kdl,waybar.nix}
  laptop/
    vars.nix                      (new)
    home.nix                      (rewritten — imports local profiles)
    monitors.nix                  (rewritten — self-contained kanshi schema + profiles)
    nixgl.nix                     (new — copy of template/profiles/nixgl.nix, settings→vars)
    firefox-profile.nix           (new — copy of modules/home/firefox-profile.nix)
    wallpaper.png                 (new — copy of root wallpaper.png)
    README.md                     (new — from template/README.md, rewritten)
    profiles/
      core.nix shell.nix locale.nix theming.nix ai.nix gaming.nix gpu.nix niri.nix
      niri/config.kdl             (new — copy)
DELETED: profiles/, settings.nix, modules/, users/, template/, wallpaper.png (root)
```

Cutover order: **Task 1 laptop → Task 2 PC → Task 3 delete dead tree + docs.** After Task 1 the laptop builds from its new tree while the PC still builds from the old shared tree (nothing the PC uses is removed yet). After Task 2 both build from new trees. Task 3 deletes the now-unreferenced old tree.

---

### Task 1: Laptop self-contained + wired

Move the laptop (standalone home-manager) onto its own tree and flip the laptop half of `flake.nix`. The PC is untouched and keeps building off the old shared tree.

**Files:**
- Create: `machines/laptop/vars.nix`
- Create: `machines/laptop/nixgl.nix` (from `template/profiles/nixgl.nix`)
- Create: `machines/laptop/firefox-profile.nix` (from `modules/home/firefox-profile.nix`)
- Create: `machines/laptop/wallpaper.png` (copy of `wallpaper.png`)
- Create: `machines/laptop/profiles/core.nix` `shell.nix` `locale.nix` `theming.nix` `ai.nix` `gaming.nix` `gpu.nix` `niri.nix` (from `template/profiles/*.nix`)
- Create: `machines/laptop/profiles/niri/config.kdl` (copy of `profiles/desktop/niri/config.kdl`)
- Rewrite: `machines/laptop/home.nix`
- Rewrite: `machines/laptop/monitors.nix` (self-contained; was `imports = [ ../../modules/home/monitors.nix ]`)
- Modify: `flake.nix` (laptop half only)
- Delete at end of task: `machines/laptop/device.nix` (folded into `vars.nix`)

**`vars.<X>` mapping for laptop profiles** (replaces today's `settings.<X>`):

| old `settings.` | new `vars.` |
|---|---|
| `username` | `user` |
| `homeDirectory` | `homeDirectory` |
| `gpu` | `gpu` |
| `flakePath` | `flakePath` |
| `scheme` | `scheme` |
| `polarity` | `polarity` |
| `wallpaper` | `wallpaper` |
| `localeMain` | `localeMain` |
| `localeRegional` | `localeRegional` |
| `xkbLayout` | `xkbLayout` |
| `xkbVariant` | `xkbVariant` |
| `theming` (bool) | *(remove guard — always on)* |
| `ai` (bool) | *(remove guard)* |
| `gaming` (bool) | *(remove guard)* |
| `desktop == "niri"` | *(remove guard — niri always imported)* |

- [ ] **Step 1: Create `machines/laptop/vars.nix`**

```nix
# Laptop (Mint, standalone home-manager) — all config values for this machine.
# Plain attrset, imported by flake.nix and threaded to profiles as `vars`.
{
  user = "niklas";
  homeDirectory = "/home/niklas";
  gpu = "mesa";                 # "mesa" (Intel/AMD) | "nvidia" — picks the nixGL wrapper
  flakePath = "~/Documents/nix";

  scheme = "monokai";
  polarity = "dark";
  wallpaper = ./wallpaper.png;

  localeMain = "en_US.UTF-8";
  localeRegional = "de_DE.UTF-8";
  xkbLayout = "de";
  xkbVariant = "nodeadkeys";
}
```

- [ ] **Step 2: Copy the helper modules and niri config**

```bash
cp wallpaper.png machines/laptop/wallpaper.png
git mv template/profiles/nixgl.nix machines/laptop/nixgl.nix
cp modules/home/firefox-profile.nix machines/laptop/firefox-profile.nix
mkdir -p machines/laptop/profiles/niri
cp profiles/desktop/niri/config.kdl machines/laptop/profiles/niri/config.kdl
```

In `machines/laptop/nixgl.nix` change the function arg `{ pkgs, inputs, settings }` to `{ pkgs, inputs, vars }` and replace the two `settings.gpu` reads with `vars.gpu`. Leave everything else identical.

- [ ] **Step 3: Move the laptop profiles**

```bash
git mv template/profiles/core.nix    machines/laptop/profiles/core.nix
git mv template/profiles/shell.nix   machines/laptop/profiles/shell.nix
git mv template/profiles/locale.nix  machines/laptop/profiles/locale.nix
git mv template/profiles/theming.nix machines/laptop/profiles/theming.nix
git mv template/profiles/ai.nix      machines/laptop/profiles/ai.nix
git mv template/profiles/gaming.nix  machines/laptop/profiles/gaming.nix
git mv template/profiles/gpu.nix     machines/laptop/profiles/gpu.nix
git mv template/profiles/niri.nix    machines/laptop/profiles/niri.nix
```

Apply the transformation rule + `vars.` mapping to each:

- `core.nix`: header `{ pkgs, ... }` unchanged (no settings used). No guard. No change to body.
- `shell.nix`: header `{ vars, ... }`. Body: `${settings.flakePath}#${settings.username}` → `${vars.flakePath}#${vars.user}`.
- `locale.nix`: header `{ vars, ... }`. `settings.localeRegional`→`vars.localeRegional`, `settings.localeMain`→`vars.localeMain`, `settings.xkbLayout`→`vars.xkbLayout`, `settings.xkbVariant`→`vars.xkbVariant`.
- `theming.nix`: header `{ lib, pkgs, vars, ... }` (drop `lib`? it is only used for `lib.mkIf` — after removing the guard, drop `lib` from the header). Final header `{ pkgs, vars, ... }`. Remove the `lib.mkIf settings.theming` wrapper, keep `{ stylix = {...}; programs.firefox = {...}; }` at top level. `settings.polarity`→`vars.polarity`, `settings.wallpaper`→`vars.wallpaper`, `settings.scheme`→`vars.scheme`.
- `ai.nix`: header `{ lib, pkgs, vars, ... }` (lib still used by `lib.hm.dag`). Remove `lib.mkIf settings.ai` wrapper, keep the body (`home.sessionPath`, all `home.activation.*`) at top level. No other `settings.` references inside.
- `gaming.nix`: header `{ pkgs, ... }` (drop `lib`, drop guard). Remove `lib.mkIf settings.gaming` wrapper.
- `gpu.nix`: header `{ pkgs, inputs, vars, ... }`. `import ./nixgl.nix { inherit pkgs inputs settings; }` → `import ./nixgl.nix { inherit pkgs inputs vars; }`. The `import` path stays `./nixgl.nix` (now `machines/laptop/nixgl.nix`).
- `niri.nix`: header `{ config, lib, pkgs, inputs, vars, ... }` (lib still used for `lib.replaceStrings`). Remove `lib.mkIf (settings.desktop == "niri")` wrapper. Replace the `builtins.readFile ../../profiles/desktop/niri/config.kdl` path with `builtins.readFile ./niri/config.kdl`. `import ./nixgl.nix { inherit pkgs inputs settings; }`→`{ inherit pkgs inputs vars; }`. Replace `settings.xkbLayout`→`vars.xkbLayout`, `settings.xkbVariant`→`vars.xkbVariant`, `settings.homeDirectory`→`vars.homeDirectory`, `settings.username`→`vars.user`.

- [ ] **Step 4: Rewrite `machines/laptop/monitors.nix` self-contained**

The kanshi schema currently lives in `modules/home/monitors.nix` (imported). Inline it so the laptop owns it. Copy the full body of `modules/home/monitors.nix` into a new `machines/laptop/_monitors-lib.nix` and import that, OR inline the options. Simplest: copy the lib module:

```bash
cp modules/home/monitors.nix machines/laptop/_monitors-lib.nix
```

Then rewrite `machines/laptop/monitors.nix` header to `{ vars, ... }`, change `imports = [ ../../modules/home/monitors.nix ]` → `imports = [ ./_monitors-lib.nix ]`, and `settings.desktop == "niri"` → `true` (niri is the laptop's only desktop; keep `enable = true;`). Leave the `profiles` list (docked/mobile) unchanged.

- [ ] **Step 5: Rewrite `machines/laptop/home.nix`**

```nix
# Laptop standalone home-manager entry. Self-contained: imports this machine's
# own profiles + helper modules. Built via the `niklas` homeConfigurations
# output in the root flake.nix.
{ vars, ... }:
{
  imports = [
    ./firefox-profile.nix
    ./profiles/core.nix
    ./profiles/shell.nix
    ./profiles/locale.nix
    ./profiles/theming.nix
    ./profiles/ai.nix
    ./profiles/gaming.nix
    ./profiles/gpu.nix
    ./profiles/niri.nix
    ./monitors.nix
  ];

  home.username = vars.user;
  home.homeDirectory = vars.homeDirectory;
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;
}
```

- [ ] **Step 6: Flip the laptop half of `flake.nix`**

Remove the `laptopCfg = (lib.evalModules { ... }).config.mySystem;` block and the entire `hmSettings = { ... };` block. Add near the other `let` bindings:

```nix
laptopVars = import ./machines/laptop/vars.nix;
```

Replace the `homeConfigurations` output with (no `optionalAttrs` guard):

```nix
homeConfigurations.${laptopVars.user} = home-manager.lib.homeManagerConfiguration {
  pkgs = hmPkgs;
  extraSpecialArgs = { inherit inputs; vars = laptopVars; };
  modules = [
    inputs.stylix.homeModules.stylix
    ./machines/laptop/home.nix
  ];
};
```

Leave `hmPkgs` as-is. Do **not** touch the `nixosConfigurations` / `cfg` / `checks` parts yet (the PC still uses them).

- [ ] **Step 7: Remove the now-unused laptop device file**

```bash
git rm machines/laptop/device.nix
```

- [ ] **Step 8: Verify laptop builds and PC still builds**

```bash
nix build .#homeConfigurations.niklas.activationPackage --no-link 2>&1 | tail -20
nix build .#nixosConfigurations.nixos.config.system.build.toplevel --no-link 2>&1 | tail -20
```
Expected: both succeed with no evaluation errors. (The PC build still references the old shared tree, which is intentionally still present.)

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "refactor: move laptop onto self-contained per-machine tree

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: PC self-contained + wired

Move the NixOS PC onto its own tree and flip the PC half of `flake.nix`. After this task nothing imports the old shared `profiles/`, `settings.nix`, `modules/`, `users/`, or `template/`.

**Files:**
- Create: `machines/pc/vars.nix`
- Create: `machines/pc/firefox-profile.nix` (copy of `modules/home/firefox-profile.nix`)
- Create: `machines/pc/wallpaper.png` (copy of `wallpaper.png`)
- Create: `machines/pc/home.nix` (replaces `users/home.nix`)
- Move: `profiles/{core,shell,theming,gaming,ai,local-ai,storage}` and `profiles/desktop/niri` → `machines/pc/profiles/...`
- Rewrite: `machines/pc/default.nix`
- Rewrite: `machines/pc/monitors.nix` (self-contained; osConfig→vars)
- Modify: `flake.nix` (PC half)

**`vars.<X>` mapping for PC profiles** (replaces today's `config.mySystem.<X>` in system modules and `osConfig.mySystem.<X>` in home modules):

| old reference | new `vars.` |
|---|---|
| `config.mySystem.user.name` / `osConfig.mySystem.user.name` | `vars.user` |
| `mySystem.user.fullName` | `vars.fullName` |
| `mySystem.user.extraGroups` | `vars.extraGroups` |
| `mySystem.hostname` | `vars.hostname` |
| `mySystem.timezone` | `vars.timezone` |
| `mySystem.locale.*` (`main`/`regional`/`consoleKeymap`/`xkbLayout`/`xkbVariant`) | `vars.localeMain` / `vars.localeRegional` / `vars.consoleKeymap` / `vars.xkbLayout` / `vars.xkbVariant` |
| `mySystem.kernel` | `vars.kernel` |
| `mySystem.theming.scheme/polarity/wallpaper` | `vars.scheme` / `vars.polarity` / `vars.wallpaper` |
| `mySystem.gaming.gamescope.{width,height}` | `vars.gamescope.{width,height}` |
| `mySystem.localAi.rocmGfx` | `vars.rocmGfx` |
| `mySystem.storage.automount.mounts` | `vars.storageMounts` |
| `mySystem.desktop == "niri"` | *(remove guard — niri always imported)* |
| `mySystem.{theming,ai,gaming,localAi,storage.automount}.enable` | *(remove guard — profile imported iff wanted)* |

- [ ] **Step 1: Create `machines/pc/vars.nix`**

```nix
# Main PC (NixOS) — all config values for this machine. Plain attrset, imported
# by flake.nix and threaded to system + home modules as `vars`.
{
  hostname = "nixos";
  user = "dillen";
  fullName = "dillen";
  extraGroups = [ "networkmanager" "wheel" ];

  scheme = "monokai";
  polarity = "dark";
  wallpaper = ./wallpaper.png;

  timezone = "Europe/Berlin";
  localeMain = "en_US.UTF-8";
  localeRegional = "de_DE.UTF-8";
  consoleKeymap = "de-latin1-nodeadkeys";
  xkbLayout = "de";
  xkbVariant = "nodeadkeys";

  kernel = "default";

  gamescope = { width = 3440; height = 1440; };
  rocmGfx = "11.0.0";

  # Automounts under /home/<user>. Empty = none (matches current PC config).
  storageMounts = [ ];
}
```

> Note: the current PC has `gaming.enable = false`, `ai.enable = false`, `localAi.enable = false`, `storage.automount.enable = false`. Those profiles are **not imported** by the PC after this task (see Step 4 import list). `gamescope`/`rocmGfx`/`storageMounts` are kept in `vars.nix` for when those profiles are re-added, but are unused while unimported. If any `nixos.nix` references them at the top level (outside a removed guard), keep that file imported; otherwise omit the import.

- [ ] **Step 2: Copy helpers**

```bash
cp wallpaper.png machines/pc/wallpaper.png
cp modules/home/firefox-profile.nix machines/pc/firefox-profile.nix
```

- [ ] **Step 3: Move the PC profiles**

```bash
mkdir -p machines/pc/profiles/desktop
git mv profiles/core        machines/pc/profiles/core
git mv profiles/shell       machines/pc/profiles/shell
git mv profiles/theming     machines/pc/profiles/theming
git mv profiles/gaming      machines/pc/profiles/gaming
git mv profiles/ai          machines/pc/profiles/ai
git mv profiles/local-ai    machines/pc/profiles/local-ai
git mv profiles/storage     machines/pc/profiles/storage
git mv profiles/desktop/niri machines/pc/profiles/desktop/niri
```

Apply the transformation rule + `vars.` mapping to each moved file. Per-file specifics:

- `core/nixos.nix`: change `config.mySystem.*` / guards per mapping; header gains `vars` if it reads values. (Read the file; apply mapping to any `config.mySystem` it uses.)
- `core/home.nix`: currently `{ ... }: { xdg.enable = true; }` — unchanged.
- `shell/nixos.nix`, `shell/home.nix`: `shell/home.nix` is static (no settings) — unchanged. Apply mapping to `shell/nixos.nix` if it reads `mySystem`.
- `theming/nixos.nix`: header `{ vars, ... }` (+ `pkgs` if used); map `mySystem.theming.scheme/polarity/wallpaper`→`vars.*`; remove the `enable` guard.
- `theming/home.nix`: header `{ vars, ... }`; remove `lib.mkIf osConfig.mySystem.theming.enable`; keep `programs.firefox` + `stylix.targets.*` body. (No scheme/polarity here — those are in `theming/nixos.nix`.)
- `gaming/home.nix`: header `{ vars, pkgs, ... }`; remove `lib.mkIf osConfig.mySystem.gaming.enable`; `osConfig.mySystem.gaming.gamescope`→`vars.gamescope`. (Only imported if PC enables gaming — it does not today, so this file is **not** in the Step 4 import list.)
- `gaming/nixos.nix`: same mapping; only imported when gaming wanted.
- `ai/{nixos,home,claude-plugins}.nix`: map `osConfig.mySystem.ai.enable` guard away; not imported today.
- `local-ai/nixos.nix`: map `mySystem.localAi.*`; not imported today.
- `storage/nixos.nix`: map `mySystem.storage.automount.mounts`→`vars.storageMounts`; not imported today.
- `desktop/niri/nixos.nix`: header `{ vars, ... }`; remove `desktop == "niri"` guard; map any locale refs.
- `desktop/niri/home.nix`: header `{ lib, config, vars, ... }`; remove `lib.mkIf (osConfig.mySystem.desktop == "niri")`; `osConfig.mySystem.locale.xkbLayout/xkbVariant`→`vars.xkbLayout/xkbVariant`. Keep `imports = [ ./waybar.nix ]`.
- `desktop/niri/waybar.nix`: unchanged (static).

> Read each `nixos.nix` before editing — only `core`, `shell`, `theming`, `desktop/niri` are in the PC's active import set today (the others are gated off by disabled toggles). Apply the mapping to the active set; the inactive ones still get moved (so the directory is complete) but need not be import-clean this task as long as they are not imported.

- [ ] **Step 4: Create `machines/pc/home.nix`** (replaces `users/home.nix`)

```nix
# NixOS user's home-manager config. Self-contained: imports this machine's home
# profiles + helper modules. Receives `vars` via home-manager.extraSpecialArgs.
{ vars, ... }:
{
  imports = [
    ./firefox-profile.nix
    ./profiles/core/home.nix
    ./profiles/theming/home.nix
    ./profiles/desktop/niri/home.nix
    ./profiles/shell/home.nix
    ./monitors.nix
  ];

  home.username = vars.user;
  home.homeDirectory = "/home/${vars.user}";
  home.stateVersion = "26.05";
}
```

> This list mirrors the **currently active** home profiles for the PC (`core`, `theming`, `niri`, `shell`, plus monitors + firefox). `ai`/`gaming` home profiles are omitted because the PC has them disabled today. To re-enable later, add the import line — no toggle needed.

- [ ] **Step 5: Rewrite `machines/pc/monitors.nix` self-contained**

```bash
cp modules/home/monitors.nix machines/pc/_monitors-lib.nix
```
Rewrite `machines/pc/monitors.nix`: header `{ vars, ... }`; `imports = [ ./_monitors-lib.nix ]`; `osConfig.mySystem.desktop == "niri"` → `true`. Keep `fallbackAllOn = true;` and the (empty/example) `profiles` list unchanged.

- [ ] **Step 6: Rewrite `machines/pc/default.nix`**

```nix
# Main PC — NixOS host. Self-contained: imports this machine's hardware +
# profiles + home-manager glue. `vars` comes from flake.nix via specialArgs.
{ config, inputs, vars, ... }:
{
  disabledModules = [
    "${inputs.stylix}/modules/kmscon/nixos.nix"
  ];

  imports = [
    ./hardware.nix
    ./profiles/core/nixos.nix
    ./profiles/shell/nixos.nix
    ./profiles/theming/nixos.nix
    ./profiles/desktop/niri/nixos.nix
  ];

  networking.hostName = vars.hostname;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = { inherit inputs vars; };
    users.${vars.user} = import ./home.nix;
  };
}
```

> Import only the profiles whose features the PC currently runs (`core`, `shell`, `theming`, `desktop/niri`). `gaming`, `ai`, `local-ai`, `storage` `nixos.nix` files exist in the tree but are not imported (they were toggle-disabled). Any identity/locale/kernel/user-account wiring that previously lived in `users/nixos.nix` or the `mySystem` core profile must be carried into `core/nixos.nix` (or here) using `vars.*` — read `users/nixos.nix` and `profiles/core/nixos.nix` and fold their settings in. Verify nothing still references `config.mySystem`.

- [ ] **Step 7: Flip the PC half of `flake.nix`**

Add to the `let` bindings:
```nix
pcVars = import ./machines/pc/vars.nix;
```
Remove `cfg = system.config.mySystem;`. Rewrite the `system` / `nixosConfigurations` / `checks` parts:

```nix
system = lib.nixosSystem {
  system = "x86_64-linux";
  specialArgs = { inherit inputs; vars = pcVars; };
  modules = [
    { nixpkgs.overlays = [ inputs.nur.overlays.default ]; }
    home-manager.nixosModules.home-manager
    stylix.nixosModules.stylix
    ./machines/pc/default.nix
  ];
};
```
```nix
nixosConfigurations.${pcVars.hostname} = system;
```
For `checks.x86_64-linux`, replace `cfg.desktop == "niri"` gating and `cfg.user.name` with `pcVars`:
```nix
checks.x86_64-linux.niri-config =
  let
    kdl = system.config.home-manager.users.${pcVars.user}
            .xdg.configFile."niri/config.kdl".text;
  in
  pkgs.runCommand "niri-config-check" { buildInputs = [ pkgs.niri ]; } ''
    echo ${pkgs.lib.escapeShellArg kdl} > config.kdl
    niri validate --config config.kdl
    touch $out
  '';
```
(Drop the `lib.optionalAttrs (cfg.desktop == "niri")` wrapper — the PC always runs niri now.)

- [ ] **Step 8: Verify both machines build off the new trees**

```bash
nix flake check 2>&1 | tail -30
nix build .#nixosConfigurations.nixos.config.system.build.toplevel --no-link 2>&1 | tail -20
nix build .#homeConfigurations.niklas.activationPackage --no-link 2>&1 | tail -20
```
Expected: `nix flake check` passes (niri kdl validates); both builds succeed. If an evaluation error names `config.mySystem` or a missing `settings`/`osConfig`, a moved file still has an unmapped reference — fix it and re-run.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "refactor: move PC onto self-contained per-machine tree

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Delete dead tree + rewrite docs

Now that nothing imports the old shared tree, remove it and update the docs.

**Files:**
- Delete: `profiles/`, `settings.nix`, `modules/`, `users/`, `template/`, root `wallpaper.png`
- Rewrite: `README.md` (root)
- Create: `machines/laptop/README.md` (from `template/README.md` content, updated)

- [ ] **Step 1: Delete the dead shared tree**

```bash
git rm -r profiles settings.nix modules users template wallpaper.png
```

> `template/README.md` is needed for Step 3 — before deleting `template/`, copy it out: `git mv template/README.md machines/laptop/README.md` first, then `git rm -r template`. (`git mv` keeps history.)

- [ ] **Step 2: Verify nothing referenced the deleted paths**

```bash
nix flake check 2>&1 | tail -30
nix build .#nixosConfigurations.nixos.config.system.build.toplevel --no-link 2>&1 | tail -20
nix build .#homeConfigurations.niklas.activationPackage --no-link 2>&1 | tail -20
grep -rn -e "\.\./\.\./profiles" -e "settings.nix" -e "modules/home" -e "modules/options" -e "/template/" -e "mySystem" --include="*.nix" . || echo "no stale references"
```
Expected: both builds + flake check green; grep prints `no stale references` (or only matches inside `machines/*/README.md`/comments — fix any real `.nix` code matches).

- [ ] **Step 3: Rewrite `machines/laptop/README.md`**

Update the moved README so paths point at `machines/laptop/` instead of `template/`/`portable/`: the profiles table refers to `machines/laptop/profiles/*`; "device file" becomes `machines/laptop/vars.nix`; drop references to shared `settings.nix` and the `mySystem` toggle table (there are no toggles — a profile runs iff imported in `machines/laptop/home.nix`); the npm/plugin version pin note points at `machines/laptop/profiles/ai.nix`. Keep all the post-install guidance (locale, nixGL, niri session sudoers) unchanged.

- [ ] **Step 4: Rewrite root `README.md`**

Replace the "shared settings vs per-device" description with the new model: two fully independent machines under `machines/pc` (NixOS) and `machines/laptop` (standalone home-manager), sharing only the flake inputs. Document the two build commands:
```
sudo nixos-rebuild switch --flake .#nixos          # PC
home-manager switch --flake .#niklas               # laptop
```
State that each machine owns its own `vars.nix`, profiles, and helper copies, and that there are no feature toggles — a feature runs iff its profile is imported in that machine's entry file.

- [ ] **Step 5: Final verification**

```bash
nix flake check 2>&1 | tail -30
git status
```
Expected: flake check green; `git status` shows the old tree deleted and the two machine trees present.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor: delete shared profile tree + options; rewrite docs

Removes profiles/, settings.nix, modules/, users/, template/ and the
mySystem options schema. The PC and laptop are now developed independently.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review notes

- **Spec coverage:** layout (Tasks 1–3), per-machine `vars.nix` (T1S1, T2S1), wiring/threading `vars` (T1S6, T2S6–7), flake simplification incl. removed `evalModules`/`hmSettings`/`optionalAttrs` (T1S6) and `cfg`/checks (T2S7), gnome drop (no gnome in any import list; deleted in T3S1), duplication of niri/nixgl/firefox/monitors/wallpaper (T1S2/4, T2S2/5), migration via `git mv` (throughout), verification commands (every task), README moves (T3). All spec sections map to a task.
- **No-placeholder check:** new small files given in full (`vars.nix`, `home.nix`, `default.nix`, monitors rewrites, flake snippets); large moved profiles specified by exact `git mv` + an exact substitution table rather than re-pasting 200-line bodies (the content already exists in-repo and moves intact — re-pasting would risk drift).
- **Storage/automount + gamescope/rocm:** kept in PC `vars.nix` but unimported (matches today's disabled state); noted explicitly so a reviewer isn't surprised they're inert.
- **Open item for the implementer:** `profiles/core/nixos.nix` + `users/nixos.nix` hold the system identity/locale/kernel/account wiring that this plan folds into `machines/pc/{core/nixos.nix,default.nix}` via `vars.*` (T2S3/S6). Read those two files first and carry every `config.mySystem` consumer over; the Step 8 `grep`/build gate catches any miss.
```
