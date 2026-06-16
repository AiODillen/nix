# Gamescope + Steam Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Configure gamescope defaults and German keyboard so every Steam game automatically runs inside gamescope when launched via `steam-gamescope`.

**Architecture:** Expand the existing `programs.steam.gamescopeSession` block in `profiles/gaming/nixos.nix` with display/performance args, enable `capSysNice` on `programs.gamescope`, and bake `XKB_DEFAULT_LAYOUT=de` into the gamescope wrapper env. Add an XDG desktop entry in `profiles/gaming/home.nix` so `steam-gamescope` is discoverable in the niri app launcher.

**Tech Stack:** NixOS 26.05, home-manager, gamescope 3.x, Steam (gamescopeSession module)

---

## File Map

| File | Change |
|------|--------|
| `profiles/gaming/nixos.nix` | Expand `gamescopeSession.args`, add `gamescope.capSysNice` and `gamescope.env` |
| `profiles/gaming/home.nix` | Add `xdg.desktopEntries.steam-gamescope` |

---

### Task 1: Expand gamescope NixOS config

**Files:**
- Modify: `profiles/gaming/nixos.nix`

- [ ] **Step 1: Replace the file contents**

```nix
{ config, lib, ... }:
lib.mkIf config.mySystem.gaming.enable {
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = false;
    gamescopeSession = {
      enable = true;
      args = [
        "-W" "3440" "-H" "1440"
        "-r" "175"
        "-f"
        "--adaptive-sync"
        "-F" "fsr"
        "--sharpness" "5"
        "--rt"
        "--expose-wayland"
        "--xwayland-count" "2"
        "--mangoapp"
      ];
    };
  };

  programs.gamescope = {
    enable = true;
    capSysNice = true;
    env = {
      XKB_DEFAULT_LAYOUT = "de";
    };
  };

  hardware.steam-hardware.enable = true;
}
```

- [ ] **Step 2: Verify the config evaluates**

```bash
nix build .#nixosConfigurations.nixos.config.system.build.toplevel --dry-run 2>&1 | tail -5
```

Expected: exits 0, prints `these derivations will be built:` or `these paths will be fetched:` (no eval errors).

- [ ] **Step 3: Verify the generated steam-gamescope script contains the args**

```bash
nix build .#nixosConfigurations.nixos.config.system.build.toplevel --no-link 2>/dev/null; \
grep -r "adaptive-sync\|xwayland-count\|XKB_DEFAULT_LAYOUT" \
  $(nix eval --raw .#nixosConfigurations.nixos.config.programs.steam.package)/bin/steam-gamescope 2>/dev/null \
  || cat $(nix eval --raw .#nixosConfigurations.nixos.config.environment.systemPackages \
    --apply 'pkgs: builtins.toString (builtins.map (p: p.outPath) pkgs)' 2>/dev/null) 2>/dev/null \
  || echo "check manually after nixos-rebuild switch"
```

If the nix eval path is awkward, just proceed to the commit and verify after `nixos-rebuild switch` by running `which steam-gamescope && cat $(which steam-gamescope)` to confirm the flags appear.

- [ ] **Step 4: Commit**

```bash
git add profiles/gaming/nixos.nix
git commit -m "feat(gaming): configure gamescope defaults and German keyboard for Steam session"
```

---

### Task 2: Add steam-gamescope desktop entry

**Files:**
- Modify: `profiles/gaming/home.nix`

- [ ] **Step 1: Add the desktop entry**

Replace the file contents with:

```nix
{ lib, osConfig, pkgs, ... }:
lib.mkIf osConfig.mySystem.gaming.enable {
  programs.mangohud.enable = true;
  programs.vesktop.enable = true;

  home.packages = with pkgs; [
    faugus-launcher
    goverlay
    heroic
    protonplus
    r2modman
  ];

  xdg.desktopEntries.steam-gamescope = {
    name = "Steam (Gamescope)";
    exec = "steam-gamescope";
    icon = "steam";
    comment = "Steam via Gamescope — all games run inside gamescope";
    categories = [ "Game" ];
  };
}
```

- [ ] **Step 2: Verify the config evaluates**

```bash
nix build .#nixosConfigurations.nixos.config.system.build.toplevel --dry-run 2>&1 | tail -5
```

Expected: exits 0, no eval errors.

- [ ] **Step 3: Commit**

```bash
git add profiles/gaming/home.nix
git commit -m "feat(gaming): add steam-gamescope desktop entry for niri app launcher"
```

---

### Task 3: Apply and smoke-test

- [ ] **Step 1: Switch to the new config**

```bash
sudo nixos-rebuild switch --flake .#nixos
```

Expected: build completes, switch succeeds with no activation errors.

- [ ] **Step 2: Confirm steam-gamescope wrapper contains the flags**

```bash
cat $(which steam-gamescope)
```

Expected output contains all of these strings:
- `3440`
- `adaptive-sync`
- `xwayland-count`
- `mangoapp`

- [ ] **Step 3: Confirm German keyboard env is baked into gamescope binary**

```bash
cat $(which gamescope) 2>/dev/null || strings $(which gamescope) | grep XKB
```

Expected: `XKB_DEFAULT_LAYOUT` and `de` visible in the wrapper script or binary.

- [ ] **Step 4: Confirm desktop entry appears**

```bash
ls ~/.local/share/applications/ | grep steam-gamescope
cat ~/.local/share/applications/steam-gamescope.desktop 2>/dev/null || \
  ls /run/current-system/sw/share/applications/ | grep steam 2>/dev/null
```

Expected: a `steam-gamescope.desktop` file is present somewhere on the XDG application search path.

- [ ] **Step 5: Launch steam-gamescope and verify**

Run `steam-gamescope` from terminal or app launcher. Confirm:
- Steam opens in a fullscreen gamescope window within niri
- Launch any game; verify it runs (MangoHUD overlay optional but should appear)
- Open a text field in-game and type an umlaut (`ä`, `ö`, `ü`) to confirm German keyboard layout is active
