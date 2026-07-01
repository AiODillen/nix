# Niri Theme Switcher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A fuzzel picker (`theme-switch`, bound to `Mod+Shift+T`) that switches the full-system stylix theme on the fly on both machines by activating prebuilt specialisations.

**Architecture:** A shared theme list drives per-machine stylix specialisations — NixOS-level on the PC (rebuilds HM too), HM-level on the laptop. A shared `writeShellApplication` reads the list, shows it in `fuzzel --dmenu`, and activates the chosen specialisation (`switch-to-configuration switch` via scoped NOPASSWD sudo on PC; the generation's `activate` script on the laptop).

**Tech Stack:** Nix, stylix (release-26.05), home-manager (release-26.05), niri, fuzzel, bash (`writeShellApplication`).

## Global Constraints

- Menu = `default` + exactly these 5 schemes (all polarity `dark`), names are `base16-schemes` attribute names: `catppuccin-mocha`, `tokyo-night-dark`, `gruvbox-dark-medium`, `nord`, `dracula`.
- Specialisation stylix overrides MUST use `lib.mkForce` (base config already defines `stylix.base16Scheme` and `stylix.polarity`).
- Keybind: `Mod+Shift+T { spawn "theme-switch"; }` (Mod+T is foot; Shift+T free). Do not disturb existing binds.
- PC host = `nixos`, PC user = `dillen`. Laptop user = `niklas`. Current working machine is the laptop (Linux Mint, standalone HM).
- Keep stylix at full coverage — do NOT disable any stylix target.
- Full spec: `docs/superpowers/specs/2026-07-01-niri-theme-switcher-design.md`.

## File Structure

- `modules/theme-menu.nix` — NEW. Plain list of `{ name; polarity; }`; single source of truth for the menu. Imported by both machines and the package builder.
- `modules/theme-switch.nix` — NEW. Function `{ pkgs, lib, themeMenu, mode }` → `theme-switch` package. `mode` is `"nixos"` (PC) or `"hm"` (laptop).
- `machines/laptop/profiles/theming.nix` — MODIFY. Generate HM specialisations from the list.
- `machines/laptop/profiles/niri.nix` — MODIFY. Add `theme-switch` to `home.packages`.
- `machines/laptop/profiles/niri/config.kdl` — MODIFY. Add keybind.
- `machines/pc/profiles/theming/nixos.nix` — MODIFY. Generate NixOS specialisations + scoped NOPASSWD sudoers.
- `machines/pc/profiles/desktop/niri/home.nix` — MODIFY. Add `theme-switch` to `home.packages`.
- `machines/pc/profiles/desktop/niri/config.kdl` — MODIFY. Add keybind.

---

### Task 1: Shared theme menu data

**Files:**
- Create: `modules/theme-menu.nix`

**Interfaces:**
- Produces: a list of attrsets, each `{ name = <string, base16-schemes attr>; polarity = <"dark"|"light">; }`. Consumed by Tasks 2, 3, 4.

- [ ] **Step 1: Create the data file**

Create `modules/theme-menu.nix`:

```nix
# Shared theme menu for the on-the-fly theme switcher.
# See docs/superpowers/specs/2026-07-01-niri-theme-switcher-design.md
# `name` doubles as the base16-schemes attribute (…/share/themes/<name>.yaml).
[
  { name = "catppuccin-mocha"; polarity = "dark"; }
  { name = "tokyo-night-dark"; polarity = "dark"; }
  { name = "gruvbox-dark-medium"; polarity = "dark"; }
  { name = "nord"; polarity = "dark"; }
  { name = "dracula"; polarity = "dark"; }
]
```

- [ ] **Step 2: Verify it evaluates to the 5 names**

Run:
```bash
nix eval --impure --expr 'map (t: t.name) (import ./modules/theme-menu.nix)'
```
Expected: `[ "catppuccin-mocha" "tokyo-night-dark" "gruvbox-dark-medium" "nord" "dracula" ]`

- [ ] **Step 3: Verify every scheme file exists in base16-schemes**

Run:
```bash
d=$(nix eval --raw --impure --expr 'let p = (builtins.getFlake (toString ./.)).inputs.nixpkgs.legacyPackages.x86_64-linux; in "${p.base16-schemes}/share/themes"')
for n in catppuccin-mocha tokyo-night-dark gruvbox-dark-medium nord dracula; do test -f "$d/$n.yaml" && echo "ok $n" || echo "MISSING $n"; done
```
Expected: five `ok <name>` lines, no `MISSING`.

- [ ] **Step 4: Commit**

```bash
git add modules/theme-menu.nix
git commit -m "feat(theme): shared base16 theme menu for on-the-fly switcher"
```

---

### Task 2: theme-switch package builder

**Files:**
- Create: `modules/theme-switch.nix`

**Interfaces:**
- Consumes: `themeMenu` (from Task 1). Called as `import ./modules/theme-switch.nix { inherit pkgs lib; themeMenu = import ./modules/theme-menu.nix; mode = "hm"|"nixos"; }`.
- Produces: a package whose `bin/theme-switch`, run with no args, shows a fuzzel menu (`default` + the 5 names, active one marked `●`) and activates the choice. Consumed by Tasks 3 (mode `hm`) and 4 (mode `nixos`).

- [ ] **Step 1: Create the package builder**

Create `modules/theme-switch.nix`:

```nix
{ pkgs, lib, themeMenu, mode }:
let
  namesLine = lib.concatMapStringsSep " " (t: t.name) themeMenu;
  activation =
    if mode == "hm" then ''
      gens="$(home-manager generations)"
      gen="$(printf '%s\n' "$gens" | head -n1 | grep -oE '/nix/store/[^ ]+')"
      if [ "$choice" = default ]; then
        "$gen/activate"
      else
        "$gen/specialisation/$choice/activate"
      fi
    '' else ''
      if [ "$choice" = default ]; then
        sudo /run/current-system/bin/switch-to-configuration switch
      else
        sudo "/run/current-system/specialisation/$choice/bin/switch-to-configuration" switch
      fi
    '';
in
pkgs.writeShellApplication {
  name = "theme-switch";
  runtimeInputs = with pkgs; [ fuzzel coreutils gnugrep gawk ]
    ++ lib.optional (mode == "hm") home-manager;
  text = ''
    state="''${XDG_STATE_HOME:-$HOME/.local/state}/theme-switch"
    mkdir -p "$state"
    current="$(cat "$state/current" 2>/dev/null || echo default)"

    choice="$(
      { echo default; for t in ${namesLine}; do echo "$t"; done; } \
        | while read -r t; do
            if [ "$t" = "$current" ]; then echo "$t ●"; else echo "$t"; fi
          done \
        | fuzzel --dmenu --prompt 'theme> ' \
        | awk '{print $1}'
    )"
    [ -z "$choice" ] && exit 0

    ${activation}
    echo "$choice" > "$state/current"
  '';
}
```

Note: `${namesLine}` is interpolated by Nix into literal words (e.g. `for t in catppuccin-mocha tokyo-night-dark …`), so there is no shell word-split warning. `''${XDG_STATE_HOME…}` is the Nix escape for a literal `${…}` in the script.

- [ ] **Step 2: Build it standalone (this runs shellcheck)**

Run:
```bash
out=$(nix build --impure --no-link --print-out-paths --expr 'let f = builtins.getFlake (toString ./.); p = f.inputs.nixpkgs.legacyPackages.x86_64-linux; in import ./modules/theme-switch.nix { pkgs = p; lib = p.lib; themeMenu = import ./modules/theme-menu.nix; mode = "hm"; }')
echo "$out"
```
Expected: a `/nix/store/…-theme-switch` path, no build/shellcheck error.

- [ ] **Step 3: Eyeball the generated script**

Run:
```bash
cat "$out/bin/theme-switch"
```
Expected: the `for t in` line lists the five literal scheme names; the `hm` activation branch (`home-manager generations`) is present.

- [ ] **Step 4: Build the nixos variant too (shellcheck for the other branch)**

Run:
```bash
nix build --impure --no-link --print-out-paths --expr 'let f = builtins.getFlake (toString ./.); p = f.inputs.nixpkgs.legacyPackages.x86_64-linux; in import ./modules/theme-switch.nix { pkgs = p; lib = p.lib; themeMenu = import ./modules/theme-menu.nix; mode = "nixos"; }'
```
Expected: a store path, no error.

- [ ] **Step 5: Commit**

```bash
git add modules/theme-switch.nix
git commit -m "feat(theme): theme-switch fuzzel picker package (hm + nixos modes)"
```

---

### Task 3: Laptop wiring (HM specialisations + package + keybind)

**Files:**
- Modify: `machines/laptop/profiles/theming.nix`
- Modify: `machines/laptop/profiles/niri.nix`
- Modify: `machines/laptop/profiles/niri/config.kdl`

**Interfaces:**
- Consumes: `modules/theme-menu.nix` (Task 1), `modules/theme-switch.nix` (Task 2).
- Produces: `homeConfigurations.niklas.config.specialisation` with the 5 named entries; `theme-switch` on PATH; `Mod+Shift+T` bound.

- [ ] **Step 1: Add specialisations in `machines/laptop/profiles/theming.nix`**

In the `let … in` block near the top, add:
```nix
  themeMenu = import ../../../modules/theme-menu.nix;
```
Then add this attribute to the top-level module attribute set (a sibling of the existing `stylix = { … };` block — NOT inside it):
```nix
  # Prebuilt theme variants for the on-the-fly switcher (theme-switch / Mod+Shift+T).
  # Runtime-only: reverts to vars.scheme on the next `home-manager switch`.
  specialisation = lib.listToAttrs (map (t: {
    inherit (t) name;
    value.configuration.stylix = {
      base16Scheme = lib.mkForce "${pkgs.base16-schemes}/share/themes/${t.name}.yaml";
      polarity = lib.mkForce t.polarity;
    };
  }) themeMenu);
```
Confirm the module's argument set includes `pkgs` and `lib` (it does; add them if somehow missing).

- [ ] **Step 2: Add the package in `machines/laptop/profiles/niri.nix`**

In the top `let … in` block (where `waybarWrapped` etc. are defined), add:
```nix
  themeSwitch = import ../../../modules/theme-switch.nix {
    inherit pkgs lib;
    themeMenu = import ../../../modules/theme-menu.nix;
    mode = "hm";
  };
```
Then add `themeSwitch` to the `home.packages = with pkgs; [ … ];` list (e.g. after `swayidle`):
```nix
    themeSwitch # `theme-switch` — fuzzel theme picker (Mod+Shift+T)
```
Confirm `lib` is in the module argument set (add it to the `{ … }:` header if missing).

- [ ] **Step 3: Add the keybind in `machines/laptop/profiles/niri/config.kdl`**

After the `Mod+Escape { spawn "loginctl" "lock-session"; }` line, add:
```
    Mod+Shift+T { spawn "theme-switch"; }
```

- [ ] **Step 4: Verify the specialisations evaluate**

Run:
```bash
nix eval .#homeConfigurations.niklas.config.specialisation --apply 'a: builtins.attrNames a'
```
Expected: `[ "catppuccin-mocha" "dracula" "gruvbox-dark-medium" "nord" "tokyo-night-dark" ]`

- [ ] **Step 5: Build the full home configuration**

Run:
```bash
nix build .#homeConfigurations.niklas.activationPackage --no-link
```
Expected: builds successfully (this builds the base + all 5 specialisation closures).

- [ ] **Step 6: Commit**

```bash
git add machines/laptop/profiles/theming.nix machines/laptop/profiles/niri.nix machines/laptop/profiles/niri/config.kdl
git commit -m "feat(laptop): on-the-fly theme switcher (HM specialisations + Mod+Shift+T)"
```

- [ ] **Step 7: Live smoke test (manual, on the laptop)**

Run `home-manager switch --flake .#niklas`, then in the niri session press `Mod+Shift+T`, pick `gruvbox-dark-medium`. Expected: terminal/waybar/mako/fuzzel/GTK recolor within a second or two; picking `default` restores everforest. (niri focus-ring border stays base — documented limitation.)

---

### Task 4: PC wiring (NixOS specialisations + scoped sudo + package + keybind)

**Files:**
- Modify: `machines/pc/profiles/theming/nixos.nix`
- Modify: `machines/pc/profiles/desktop/niri/home.nix`
- Modify: `machines/pc/profiles/desktop/niri/config.kdl`

**Interfaces:**
- Consumes: `modules/theme-menu.nix` (Task 1), `modules/theme-switch.nix` (Task 2).
- Produces: `nixosConfigurations.nixos.config.specialisation` with the 5 named entries; scoped NOPASSWD sudo for `switch-to-configuration`; `theme-switch` on PATH; `Mod+Shift+T` bound.

- [ ] **Step 1: Add specialisations + sudoers in `machines/pc/profiles/theming/nixos.nix`**

Change the header to bind `config`/keep existing args, and add the import in a `let`:
```nix
{ pkgs, lib, vars, ... }:
let
  # Resolve a "foo.bar" nixpkgs attr path (from vars.fonts) to the package.
  font = f: { package = lib.getAttrFromPath (lib.splitString "." f.package) pkgs; inherit (f) name; };
  themeMenu = import ../../../../modules/theme-menu.nix;
in
```
Then add these two attributes to the top-level module set (siblings of `stylix = { … };`):
```nix
  # Prebuilt theme variants for the on-the-fly switcher (theme-switch / Mod+Shift+T).
  # NixOS specialisations inherit the parent config (inheritParentConfig defaults
  # true) and rebuild HM too, so coverage is full. Runtime-only: reverts to
  # vars.scheme on the next nixos-rebuild switch.
  specialisation = lib.listToAttrs (map (t: {
    inherit (t) name;
    value.configuration.stylix = {
      base16Scheme = lib.mkForce "${pkgs.base16-schemes}/share/themes/${t.name}.yaml";
      polarity = lib.mkForce t.polarity;
    };
  }) themeMenu);

  # Passwordless activation for theme-switch, scoped to switch-to-configuration
  # only. Lets the picker activate a prebuilt specialisation without a password;
  # it cannot change what those configs contain without a (privileged) rebuild.
  security.sudo.extraRules = [{
    users = [ vars.user ];
    commands = [
      { command = "/run/current-system/bin/switch-to-configuration switch"; options = [ "NOPASSWD" ]; }
      { command = "/run/current-system/specialisation/*/bin/switch-to-configuration switch"; options = [ "NOPASSWD" ]; }
    ];
  }];
```

- [ ] **Step 2: Add the package in `machines/pc/profiles/desktop/niri/home.nix`**

In a `let … in` (add one if the file has none; it currently starts `colors = config.lib.stylix.colors;`), add:
```nix
  themeSwitch = import ../../../../../modules/theme-switch.nix {
    inherit pkgs lib;
    themeMenu = import ../../../../../modules/theme-menu.nix;
    mode = "nixos";
  };
```
Ensure the header includes `lib` (`{ lib, pkgs, config, vars, ... }:` — it does). Then change:
```nix
  home.packages = [ pkgs.wiremix ]; # pipewire TUI mixer (waybar audio module)
```
to:
```nix
  home.packages = [
    pkgs.wiremix # pipewire TUI mixer (waybar audio module)
    themeSwitch # `theme-switch` — fuzzel theme picker (Mod+Shift+T)
  ];
```

- [ ] **Step 3: Add the keybind in `machines/pc/profiles/desktop/niri/config.kdl`**

After the `Mod+Shift+F { toggle-window-floating; }` line, add:
```
    Mod+Shift+T { spawn "theme-switch"; }
```

- [ ] **Step 4: Verify the specialisations evaluate**

Run:
```bash
nix eval .#nixosConfigurations.nixos.config.specialisation --apply 'a: builtins.attrNames a'
```
Expected: `[ "catppuccin-mocha" "dracula" "gruvbox-dark-medium" "nord" "tokyo-night-dark" ]`

- [ ] **Step 5: Verify the sudoers rule is present**

Run:
```bash
nix eval .#nixosConfigurations.nixos.config.security.sudo.extraRules --apply 'r: builtins.length r'
```
Expected: a number `>= 1` (no evaluation error — confirms the rule type-checks).

- [ ] **Step 6: Build the PC system**

Run:
```bash
nix build .#nixosConfigurations.nixos.config.system.build.toplevel --no-link
```
Expected: builds successfully (base + 5 specialisation closures). This is heavy on first run; it may take a while.

- [ ] **Step 7: Commit**

```bash
git add machines/pc/profiles/theming/nixos.nix machines/pc/profiles/desktop/niri/home.nix machines/pc/profiles/desktop/niri/config.kdl
git commit -m "feat(pc): on-the-fly theme switcher (NixOS specialisations + scoped sudo + Mod+Shift+T)"
```

- [ ] **Step 8: Live smoke test (manual, on the PC)**

`sudo nixos-rebuild switch --flake .#nixos`, then in niri press `Mod+Shift+T`, pick `nord`. Expected: full recolor (incl GTK/Qt/Firefox) with no password prompt; `default` restores monokai.

---

## Self-Review

**Spec coverage:**
- Shared menu data → Task 1. ✓
- Curated top-5 (catppuccin-mocha, tokyo-night-dark, gruvbox-dark-medium, nord, dracula), all dark → Global Constraints + Task 1. ✓
- Picker `theme-switch`, fuzzel, marks current, hm+nixos activation → Task 2. ✓
- PC NixOS specialisation + scoped NOPASSWD sudo → Task 4. ✓
- Laptop HM specialisation, no sudo → Task 3. ✓
- `Mod+Shift+T` keybind both machines → Tasks 3 & 4. ✓
- `lib.mkForce` on base16Scheme/polarity (base already defines them) → Global Constraints + both wiring tasks. ✓
- Keep stylix full coverage (no targets disabled) → nothing disables targets. ✓
- Known limits (runtime-only revert, fixed menu, niri borders) → carried into commit messages/comments and smoke-test notes. ✓

**Placeholder scan:** No TBD/TODO left in new code; every step has concrete code or a concrete command with expected output.

**Type consistency:** `themeMenu` entries use `.name`/`.polarity` everywhere; `theme-switch.nix` called with identical arg names (`pkgs`, `lib`, `themeMenu`, `mode`) in Tasks 2/3/4; `mode` values `"hm"` (laptop) and `"nixos"` (PC) match the builder's branches; specialisation attr names come from `t.name` consistently.
