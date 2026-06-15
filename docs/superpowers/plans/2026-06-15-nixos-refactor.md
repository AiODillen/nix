# NixOS host/profile refactor — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reorganize the existing NixOS configuration into a host/profile layout where each profile owns both the system and home sides of a feature, gated by a single `mySystem.*` options layer.

**Architecture:** A single `modules/options.nix` declares the toggle surface (`mySystem.desktop`, `mySystem.gaming.enable`, `mySystem.theming.enable`, `mySystem.storage.automount.enable`). Every profile lives under `profiles/<feature>/` and contains a `nixos.nix` and/or `home.nix` self-gated with `lib.mkIf`. Hosts compose all profiles and decide what is on. Behavior is preserved exactly; the system configuration after refactor must be functionally identical.

**Tech Stack:** Nix flakes, NixOS 26.05, home-manager 26.05, stylix 26.05.

**Spec:** `docs/superpowers/specs/2026-06-15-nixos-refactor-design.md`

**Validation primitive:** Throughout the plan, "rebuild check" means:

```bash
cd /home/dillen/nixos-config
nix flake check 2>&1 | tail -40
sudo nixos-rebuild build --flake .#nixos 2>&1 | tail -40
```

The first runs the `niri-config-check` derivation. The second performs a full evaluation and build with no activation. Both must succeed before declaring a task done.

---

## Task 0: Working state baseline

**Files:** none (verification only)

- [ ] **Step 1: Confirm current rebuild succeeds before any change**

```bash
cd /home/dillen/nixos-config
nix flake check 2>&1 | tail -20
sudo nixos-rebuild build --flake .#nixos 2>&1 | tail -20
```

Expected: `nix flake check` exits 0, `nixos-rebuild build` exits 0 and prints a `result` symlink. If either fails, STOP — diagnose before refactoring.

- [ ] **Step 2: Note current generation for rollback reference**

```bash
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system | tail -1
```

Record the number printed; if anything goes wrong during execution, `sudo nixos-rebuild switch --rollback` returns to it.

- [ ] **Step 3: Confirm clean working tree (apart from the design doc commit just made)**

```bash
git status --short
```

Expected: only files that were already shown as untracked/modified before this plan started (e.g., `M home/dillen/default.nix`, `M modules/home/niri.nix`, etc., plus `?? result`). No surprises.

---

## Task 1: Scaffold the new directory layout

**Files:**
- Create: `profiles/core/`, `profiles/desktop/niri/`, `profiles/desktop/gnome/`, `profiles/gaming/`, `profiles/theming/`, `profiles/shell/`, `profiles/storage/`
- Create: `users/dillen/`
- Create: empty `.keep` markers so git tracks the new dirs

- [ ] **Step 1: Create directories**

```bash
cd /home/dillen/nixos-config
mkdir -p profiles/core
mkdir -p profiles/desktop/niri
mkdir -p profiles/desktop/gnome
mkdir -p profiles/gaming
mkdir -p profiles/theming
mkdir -p profiles/shell
mkdir -p profiles/storage
mkdir -p users/dillen
```

- [ ] **Step 2: Verify**

```bash
find profiles users -type d | sort
```

Expected output:
```
profiles
profiles/core
profiles/desktop
profiles/desktop/gnome
profiles/desktop/niri
profiles/gaming
profiles/shell
profiles/storage
profiles/theming
users
users/dillen
```

- [ ] **Step 3: Commit (no .nix files yet — commit comes after Task 2 to keep history meaningful)**

Skip the commit for this task. Directory creation alone is not commit-worthy; the next task adds the options file and commits both together.

---

## Task 2: Move and extend `options.nix`

**Files:**
- Create: `modules/options.nix`
- Delete: `modules/nixos/options.nix`

- [ ] **Step 1: Write the new options module**

Write to `modules/options.nix`:

```nix
{ lib, ... }:
{
  options.mySystem = {
    desktop = lib.mkOption {
      type = lib.types.enum [
        "niri"
        "gnome"
      ];
      default = "niri";
      description = "Which desktop environment to enable. Change and run nixos-rebuild switch.";
    };

    gaming.enable = lib.mkEnableOption "gaming profile (Steam, gamescope, gaming home apps)";

    theming.enable = lib.mkEnableOption "stylix theming profile (system + home)";

    storage.automount.enable = lib.mkEnableOption "automount profile (extra filesystems under /home/dillen)";
  };
}
```

- [ ] **Step 2: Delete the old options file**

```bash
git rm modules/nixos/options.nix
```

- [ ] **Step 3: Update the host import path to point at the new options file**

Edit `hosts/nixos/default.nix`: change the line

```
    ../../modules/nixos/options.nix
```

to

```
    ../../modules/options.nix
```

Leave the rest of the host file untouched for now (later tasks will fully rewrite it).

- [ ] **Step 4: Add temporary defaults so the new options don't break the build**

Append to `hosts/nixos/default.nix` (just before the closing `}` of the attrset, after the existing `mySystem.desktop = "niri";` line):

```nix
  mySystem.gaming.enable = true;
  mySystem.theming.enable = true;
  mySystem.storage.automount.enable = true;
```

These three lines are temporary — they will be folded into a single `mySystem = { ... };` block in Task 10. For now they exist to keep behavior identical while later tasks gate profile bodies with `mkIf`.

- [ ] **Step 5: Rebuild check**

```bash
cd /home/dillen/nixos-config
nix flake check 2>&1 | tail -20
sudo nixos-rebuild build --flake .#nixos 2>&1 | tail -20
```

Expected: both succeed. Behavior unchanged because the new `enable` options are not yet read by any module.

- [ ] **Step 6: Commit**

```bash
git add modules/options.nix hosts/nixos/default.nix
git rm modules/nixos/options.nix 2>/dev/null || true
git commit -m "refactor: move options to modules/options.nix and add feature toggles

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 3: Move hardware config under host

**Files:**
- Create: `hosts/nixos/hardware.nix` (content of root `hardware-configuration.nix`)
- Delete: `hardware-configuration.nix`
- Modify: `hosts/nixos/default.nix` (one import path)

- [ ] **Step 1: Move file with git**

```bash
cd /home/dillen/nixos-config
git mv hardware-configuration.nix hosts/nixos/hardware.nix
```

- [ ] **Step 2: Update import in `hosts/nixos/default.nix`**

Change the line

```
    ../../hardware-configuration.nix
```

to

```
    ./hardware.nix
```

- [ ] **Step 3: Rebuild check**

```bash
cd /home/dillen/nixos-config
nix flake check 2>&1 | tail -20
sudo nixos-rebuild build --flake .#nixos 2>&1 | tail -20
```

Expected: both succeed.

- [ ] **Step 4: Commit**

```bash
git add hosts/nixos/hardware.nix hosts/nixos/default.nix
git commit -m "refactor: move hardware-configuration.nix into hosts/nixos

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 4: Create core profile

**Files:**
- Create: `profiles/core/nixos.nix` (from `modules/nixos/common.nix`)
- Create: `profiles/core/home.nix` (from `modules/home/common.nix`)
- Modify: `hosts/nixos/default.nix` (swap import)
- Modify: `home/dillen/default.nix` (swap import)

- [ ] **Step 1: Copy common nixos into the profile (content unchanged)**

```bash
cd /home/dillen/nixos-config
cp modules/nixos/common.nix profiles/core/nixos.nix
```

- [ ] **Step 2: Copy common home into the profile**

```bash
cp modules/home/common.nix profiles/core/home.nix
```

- [ ] **Step 3: Swap imports in `hosts/nixos/default.nix`**

Change `../../modules/nixos/common.nix` to `../../profiles/core/nixos.nix`.

- [ ] **Step 4: Swap imports in `home/dillen/default.nix`**

Change `../../modules/home/common.nix` to `../../profiles/core/home.nix`.

- [ ] **Step 5: Delete the old common files**

```bash
git rm modules/nixos/common.nix modules/home/common.nix
```

- [ ] **Step 6: Rebuild check**

```bash
nix flake check 2>&1 | tail -20
sudo nixos-rebuild build --flake .#nixos 2>&1 | tail -20
```

Expected: both succeed.

- [ ] **Step 7: Commit**

```bash
git add profiles/core/ hosts/nixos/default.nix home/dillen/default.nix
git commit -m "refactor: move common modules into profiles/core

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 5: Create desktop/niri profile (with KDL + waybar split)

**Files:**
- Create: `profiles/desktop/niri/nixos.nix` (from `modules/nixos/niri.nix`)
- Create: `profiles/desktop/niri/config.kdl` (KDL extracted from `modules/home/niri.nix`)
- Create: `profiles/desktop/niri/waybar.nix` (waybar bits extracted)
- Create: `profiles/desktop/niri/home.nix` (foot, fuzzel, mako, plus xdg.configFile pointing at config.kdl)
- Modify: imports in host and user files
- Delete: `modules/nixos/niri.nix`, `modules/home/niri.nix`

- [ ] **Step 1: Copy nixos side unchanged**

```bash
cd /home/dillen/nixos-config
cp modules/nixos/niri.nix profiles/desktop/niri/nixos.nix
```

- [ ] **Step 2: Write `profiles/desktop/niri/config.kdl`**

```kdl
prefer-no-csd

output "*" {
    variable-refresh-rate on-demand=true
}

input {
    keyboard {
        xkb {
            layout "de"
            variant "nodeadkeys"
        }
    }
    touchpad {
        tap
        natural-scroll
    }
    focus-follows-mouse
    warp-mouse-to-focus
}

layout {
    gaps 8

    focus-ring {
        width 2
        active-color "#cba6f7"
        inactive-color "#313244"
    }
}

spawn-at-startup "waybar"
spawn-at-startup "mako"

binds {
    Mod+T { spawn "foot"; }
    Mod+Space { spawn "fuzzel"; }
    Mod+Q { close-window; }
    Mod+Shift+E { quit; }
    Mod+F { maximize-column; }
    Mod+Shift+F { toggle-window-floating; }

    Mod+H { focus-column-left; }
    Mod+L { focus-column-right; }
    Mod+Shift+H { move-column-left; }
    Mod+Shift+L { move-column-right; }
    Mod+J { focus-window-down; }
    Mod+K { focus-window-up; }
    Mod+Shift+J { move-window-down; }
    Mod+Shift+K { move-window-up; }

    Mod+1 { focus-workspace 1; }
    Mod+2 { focus-workspace 2; }
    Mod+3 { focus-workspace 3; }
    Mod+4 { focus-workspace 4; }
    Mod+5 { focus-workspace 5; }
    Mod+6 { focus-workspace 6; }
    Mod+7 { focus-workspace 7; }
    Mod+8 { focus-workspace 8; }
    Mod+9 { focus-workspace 9; }

    Mod+Shift+1 { move-window-to-workspace 1; }
    Mod+Shift+2 { move-window-to-workspace 2; }
    Mod+Shift+3 { move-window-to-workspace 3; }
    Mod+Shift+4 { move-window-to-workspace 4; }
    Mod+Shift+5 { move-window-to-workspace 5; }
    Mod+Shift+6 { move-window-to-workspace 6; }
    Mod+Shift+7 { move-window-to-workspace 7; }
    Mod+Shift+8 { move-window-to-workspace 8; }
    Mod+Shift+9 { move-window-to-workspace 9; }

    XF86AudioRaiseVolume allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+"; }
    XF86AudioLowerVolume allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }
    XF86AudioMute allow-when-locked=true { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }

    Mod+WheelScrollDown { focus-column-right; }
    Mod+WheelScrollUp { focus-column-left; }
    Mod+D { focus-column-right; }
    Mod+A { focus-column-left; }
}
```

This is verbatim the KDL block currently inside the multi-line string in `modules/home/niri.nix`. The contents must match byte-for-byte (whitespace included) so the niri-config-check produces an identical input. Re-check against `modules/home/niri.nix` lines 4–85 before saving.

- [ ] **Step 3: Write `profiles/desktop/niri/waybar.nix`**

```nix
{ lib, osConfig, ... }:
lib.mkIf (osConfig.mySystem.desktop == "niri") {
  programs.waybar = {
    enable = true;
    settings = [
      {
        layer = "top";
        position = "top";
        height = 30;
        spacing = 4;
        "modules-left" = [ "niri/workspaces" ];
        "modules-center" = [ "clock" ];
        "modules-right" = [
          "pulseaudio"
          "cpu"
          "memory"
          "tray"
        ];
        "niri/workspaces" = { };
        clock = {
          format = "{:%H:%M  %a %d}";
          tooltip = false;
        };
        cpu = {
          format = "CPU {usage}%";
          interval = 5;
        };
        memory = {
          format = "RAM {}%";
          interval = 10;
        };
        tray = {
          spacing = 8;
        };
        pulseaudio = {
          format = "VOL {volume}%";
          format-muted = "MUTE";
          on-click = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        };
      }
    ];
  };
}
```

- [ ] **Step 4: Write `profiles/desktop/niri/home.nix`**

```nix
{ lib, osConfig, ... }:
lib.mkIf (osConfig.mySystem.desktop == "niri") {
  imports = [ ./waybar.nix ];

  xdg.configFile."niri/config.kdl".text = builtins.readFile ./config.kdl;

  programs.foot.enable = true;
  programs.fuzzel.enable = true;
  services.mako.enable = true;
}
```

`builtins.readFile ./config.kdl` (not `.source = ./config.kdl`) is required: the niri-config-check in `flake.nix` reads `xdg.configFile."niri/config.kdl".text` at evaluation time. Using `.source` would leave `.text` as `null` and break the check.

- [ ] **Step 5: Update imports in `hosts/nixos/default.nix`**

Change `../../modules/nixos/niri.nix` to `../../profiles/desktop/niri/nixos.nix`.

- [ ] **Step 6: Update imports in `home/dillen/default.nix`**

Change `../../modules/home/niri.nix` to `../../profiles/desktop/niri/home.nix`.

- [ ] **Step 7: Delete the old niri module files**

```bash
git rm modules/nixos/niri.nix modules/home/niri.nix
```

- [ ] **Step 8: Rebuild check**

```bash
cd /home/dillen/nixos-config
nix flake check 2>&1 | tail -30
sudo nixos-rebuild build --flake .#nixos 2>&1 | tail -20
```

Expected: both succeed. The niri-config-check derivation specifically validates the KDL content; if the byte-for-byte copy in Step 2 was correct, the check is green.

- [ ] **Step 9: Commit**

```bash
git add profiles/desktop/niri/ hosts/nixos/default.nix home/dillen/default.nix
git commit -m "refactor: move niri into profiles/desktop/niri, split waybar and extract KDL

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 6: Create desktop/gnome profile

**Files:**
- Create: `profiles/desktop/gnome/nixos.nix`
- Create: `profiles/desktop/gnome/home.nix`
- Modify: host + user imports
- Delete: `modules/nixos/gnome.nix`, `modules/home/gnome.nix`

- [ ] **Step 1: Write `profiles/desktop/gnome/nixos.nix`**

This intentionally drops `stylix.targets.gnome.enable = true;` because that line moves to the theming profile in Task 8.

```nix
{ config, lib, ... }:
lib.mkIf (config.mySystem.desktop == "gnome") {
  services.xserver = {
    enable = true;
    xkb = {
      layout = "de";
      variant = "nodeadkeys";
    };
    desktopManager.gnome.enable = true;
    displayManager.gdm.enable = true;
  };
}
```

- [ ] **Step 2: Write `profiles/desktop/gnome/home.nix`**

```nix
{ lib, osConfig, ... }:
lib.mkIf (osConfig.mySystem.desktop == "gnome") {
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };
}
```

- [ ] **Step 3: Swap imports**

In `hosts/nixos/default.nix`: change `../../modules/nixos/gnome.nix` to `../../profiles/desktop/gnome/nixos.nix`.
In `home/dillen/default.nix`: change `../../modules/home/gnome.nix` to `../../profiles/desktop/gnome/home.nix`.

- [ ] **Step 4: Delete old files**

```bash
git rm modules/nixos/gnome.nix modules/home/gnome.nix
```

- [ ] **Step 5: Rebuild check**

```bash
nix flake check 2>&1 | tail -20
sudo nixos-rebuild build --flake .#nixos 2>&1 | tail -20
```

Expected: both succeed. With `desktop = "niri"`, the gnome profile evaluates to `{}` on both sides, so removing the stylix-gnome line has no observable effect until Task 8 reintroduces it under the theming profile (where it will only be active when `desktop == "gnome"`).

- [ ] **Step 6: Commit**

```bash
git add profiles/desktop/gnome/ hosts/nixos/default.nix home/dillen/default.nix
git commit -m "refactor: move gnome into profiles/desktop/gnome

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 7: Create gaming profile

**Files:**
- Create: `profiles/gaming/nixos.nix` (gated by `mySystem.gaming.enable`)
- Create: `profiles/gaming/home.nix` (gated by `osConfig.mySystem.gaming.enable`; does NOT include stylix targets)
- Modify: host + user imports
- Delete: `modules/nixos/gaming.nix`, `modules/home/packages.nix`

- [ ] **Step 1: Write `profiles/gaming/nixos.nix`**

```nix
{ config, lib, ... }:
lib.mkIf config.mySystem.gaming.enable {
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = false;
    gamescopeSession.enable = true;
  };

  programs.gamescope.enable = true;

  hardware.steam-hardware.enable = true;
}
```

- [ ] **Step 2: Write `profiles/gaming/home.nix`**

This intentionally OMITS `stylix.targets.mangohud.enable`, `stylix.targets.qt.enable`, and `stylix.targets.vesktop.enable`. Those move to `profiles/theming/home.nix` in Task 8.

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
  ];
}
```

- [ ] **Step 3: Swap imports**

In `hosts/nixos/default.nix`: change `../../modules/nixos/gaming.nix` to `../../profiles/gaming/nixos.nix`.
In `home/dillen/default.nix`: change `../../modules/home/packages.nix` to `../../profiles/gaming/home.nix`.

- [ ] **Step 4: Delete old files**

```bash
git rm modules/nixos/gaming.nix modules/home/packages.nix
```

- [ ] **Step 5: Rebuild check**

```bash
nix flake check 2>&1 | tail -20
sudo nixos-rebuild build --flake .#nixos 2>&1 | tail -20
```

Expected: both succeed. Stylix-mangohud/qt/vesktop targets are currently absent from the home config — this is a *temporary* visible difference because Task 8 reintroduces them in the theming profile. The build still succeeds; the only difference until Task 8 runs is that theming for those specific apps is briefly missing. Tasks 7 and 8 are tightly coupled — do not stop between them.

- [ ] **Step 6: Commit**

```bash
git add profiles/gaming/ hosts/nixos/default.nix home/dillen/default.nix
git commit -m "refactor: rename home/packages.nix to gaming and gate with mySystem.gaming.enable

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 8: Create theming profile

**Files:**
- Create: `profiles/theming/nixos.nix` (palette + fonts + cursor + gnome target + kmscon workaround, all gated by `mySystem.theming.enable`)
- Create: `profiles/theming/home.nix` (all home-side stylix targets, gated by `osConfig.mySystem.theming.enable`)
- Modify: host + user imports
- Delete: `modules/nixos/stylix.nix`, `modules/nixos/disable-kmscon.nix`, `modules/home/stylix.nix`

- [ ] **Step 1: Write `profiles/theming/nixos.nix`**

```nix
{ config, lib, pkgs, ... }:
lib.mkIf config.mySystem.theming.enable {
  # Disable kmscon entirely to avoid conflicts with Stylix in nixpkgs 26.05.
  # Stylix's kmscon module tries to set services.kmscon.config which no longer
  # exists; the matching disabledModules entry lives in hosts/nixos/default.nix.
  services.kmscon.enable = false;

  stylix = {
    enable = true;
    polarity = "dark";

    base16Scheme = {
      system = "base16";
      name = "Catppuccin Mocha";
      author = "https://github.com/catppuccin/catppuccin";
      variant = "dark";
      palette = {
        base00 = "1e1e2e";
        base01 = "181825";
        base02 = "313244";
        base03 = "45475a";
        base04 = "585b70";
        base05 = "cdd6f4";
        base06 = "f5c2e7";
        base07 = "b4befe";
        base08 = "f38ba8";
        base09 = "fab387";
        base0A = "f9e2af";
        base0B = "a6e3a1";
        base0C = "94e2d5";
        base0D = "89b4fa";
        base0E = "cba6f7";
        base0F = "f2cdcd";
      };
    };

    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font Mono";
      };
      sansSerif = {
        package = pkgs.inter;
        name = "Inter";
      };
      serif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Serif";
      };
      sizes = {
        applications = 12;
        terminal = 13;
        desktop = 11;
        popups = 11;
      };
    };

    cursor = {
      package = pkgs.catppuccin-cursors.mochaMauve;
      name = "catppuccin-mocha-mauve-cursors";
      size = 24;
    };

    targets.fish.enable = true;
    targets.gnome.enable = config.mySystem.desktop == "gnome";
  };
}
```

- [ ] **Step 2: Write `profiles/theming/home.nix`**

```nix
{ lib, osConfig, ... }:
lib.mkIf osConfig.mySystem.theming.enable {
  stylix.targets.firefox.enable = true;
  stylix.targets.mangohud.enable = true;
  stylix.targets.qt.enable = true;
  stylix.targets.vesktop.enable = true;
}
```

- [ ] **Step 3: Swap imports**

In `hosts/nixos/default.nix`:
- Change `../../modules/nixos/stylix.nix` to `../../profiles/theming/nixos.nix`.
- Delete the `../../modules/nixos/disable-kmscon.nix` import line.

In `home/dillen/default.nix`:
- Change `../../modules/home/stylix.nix` to `../../profiles/theming/home.nix`.

- [ ] **Step 4: Delete the old stylix and kmscon files**

```bash
git rm modules/nixos/stylix.nix modules/nixos/disable-kmscon.nix modules/home/stylix.nix
```

- [ ] **Step 5: Rebuild check**

```bash
nix flake check 2>&1 | tail -20
sudo nixos-rebuild build --flake .#nixos 2>&1 | tail -20
```

Expected: both succeed. Stylix targets restored to parity with pre-refactor state (firefox + mangohud + qt + vesktop on home; fish + gnome on system).

- [ ] **Step 6: Verify firefox is still enabled (was previously duplicated in core + home)**

```bash
grep -rn "programs.firefox.enable" profiles/ hosts/ users/ home/ modules/ 2>/dev/null
```

Expected: exactly one match — `profiles/core/nixos.nix`. The previous `programs.firefox.enable = true;` from the old `modules/home/stylix.nix` is now gone (the home-manager one was redundant since the system-level setting already covers it).

- [ ] **Step 7: Commit**

```bash
git add profiles/theming/ hosts/nixos/default.nix home/dillen/default.nix
git commit -m "refactor: consolidate stylix into profiles/theming and drop firefox dup

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 9: Create shell and storage profiles

**Files:**
- Create: `profiles/shell/fish.nix` (from `modules/home/fish.nix`)
- Create: `profiles/storage/nixos.nix` (from `modules/nixos/storage.nix`, gated by `mySystem.storage.automount.enable`)
- Modify: user + host imports
- Delete: `modules/home/fish.nix`, `modules/nixos/storage.nix`

- [ ] **Step 1: Write `profiles/shell/fish.nix`**

```nix
{ ... }:
{
  programs.fish = {
    enable = true;
    shellAliases = {
      rebuild = "sudo nixos-rebuild switch --flake ~/nixos-config/.#nixos";
    };
  };
}
```

- [ ] **Step 2: Write `profiles/storage/nixos.nix`**

```nix
{ config, lib, ... }:
lib.mkIf config.mySystem.storage.automount.enable {
  fileSystems."/home/dillen/Grab" = {
    device = "/dev/sdb1";
    fsType = "ext4";
    options = [ "nofail" "x-systemd.automount" "x-systemd.idle-timeout=600" ];
  };

  fileSystems."/home/dillen/Games_Part" = {
    device = "/dev/nvme0n1p3";
    fsType = "ext4";
    options = [ "nofail" "x-systemd.automount" "x-systemd.idle-timeout=600" ];
  };
}
```

- [ ] **Step 3: Swap imports**

In `home/dillen/default.nix`: change `../../modules/home/fish.nix` to `../../profiles/shell/fish.nix`.
In `hosts/nixos/default.nix`: change `../../modules/nixos/storage.nix` to `../../profiles/storage/nixos.nix`.

- [ ] **Step 4: Delete old files**

```bash
git rm modules/home/fish.nix modules/nixos/storage.nix
```

- [ ] **Step 5: Rebuild check**

```bash
nix flake check 2>&1 | tail -20
sudo nixos-rebuild build --flake .#nixos 2>&1 | tail -20
```

Expected: both succeed.

- [ ] **Step 6: Commit**

```bash
git add profiles/shell/ profiles/storage/ hosts/nixos/default.nix home/dillen/default.nix
git commit -m "refactor: move fish and storage into their own profiles

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 10: Relocate user entry to `users/dillen/` and tidy host file

**Files:**
- Create: `users/dillen/default.nix` (from `home/dillen/default.nix`)
- Modify: `hosts/nixos/default.nix` (point at new user path; consolidate `mySystem` block)
- Delete: `home/dillen/default.nix`

- [ ] **Step 1: Move user file with git**

```bash
cd /home/dillen/nixos-config
git mv home/dillen/default.nix users/dillen/default.nix
```

- [ ] **Step 2: Remove now-empty `home/` directory if present**

```bash
rmdir home/dillen 2>/dev/null || true
rmdir home 2>/dev/null || true
```

If `home/` still has untracked or non-tracked files (e.g., orphan tooling), inspect with `ls -la home/` instead of deleting blindly.

- [ ] **Step 3: Update `hosts/nixos/default.nix` to import the new user path**

Find the line:

```nix
        users.dillen = import ../../home/dillen/default.nix;
```

Replace with:

```nix
        users.dillen = import ../../users/dillen/default.nix;
```

- [ ] **Step 4: Consolidate the `mySystem` toggles into one block**

In `hosts/nixos/default.nix`, find the four scattered settings:

```nix
  mySystem.desktop = "niri";
  ...
  mySystem.gaming.enable = true;
  mySystem.theming.enable = true;
  mySystem.storage.automount.enable = true;
```

Replace with a single block in the same location:

```nix
  mySystem = {
    desktop = "niri";
    gaming.enable = true;
    theming.enable = true;
    storage.automount.enable = true;
  };
```

- [ ] **Step 5: Rebuild check**

```bash
nix flake check 2>&1 | tail -20
sudo nixos-rebuild build --flake .#nixos 2>&1 | tail -20
```

Expected: both succeed.

- [ ] **Step 6: Commit**

```bash
git add hosts/nixos/default.nix users/dillen/default.nix
git rm home/dillen/default.nix 2>/dev/null || true
git commit -m "refactor: move user config to users/dillen and consolidate mySystem block

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 11: Remove the empty `modules/nixos/` and `modules/home/` directories

**Files:**
- Delete: empty leftover subdirectories under `modules/`

- [ ] **Step 1: Verify they are empty**

```bash
cd /home/dillen/nixos-config
find modules/nixos modules/home -type f 2>/dev/null
```

Expected: no output. If anything remains, STOP — investigate the leftover before removing the directories.

- [ ] **Step 2: Remove empty directories**

```bash
rmdir modules/nixos modules/home
ls modules/
```

Expected `ls modules/` output:

```
options.nix
```

- [ ] **Step 3: Rebuild check**

```bash
nix flake check 2>&1 | tail -20
sudo nixos-rebuild build --flake .#nixos 2>&1 | tail -20
```

Expected: both succeed.

- [ ] **Step 4: Commit (only if there is something to commit — empty dirs aren't tracked, so usually nothing here)**

```bash
git status --short
```

If empty, skip. If not, commit normally.

---

## Task 12: Final verification

**Files:** none (verification only)

- [ ] **Step 1: Sanity-check the final file tree**

```bash
find . -type f -name "*.nix" -not -path "./result/*" -not -path "./.git/*" | sort
```

Expected output:

```
./flake.nix
./hosts/nixos/default.nix
./hosts/nixos/hardware.nix
./modules/options.nix
./profiles/core/home.nix
./profiles/core/nixos.nix
./profiles/desktop/gnome/home.nix
./profiles/desktop/gnome/nixos.nix
./profiles/desktop/niri/home.nix
./profiles/desktop/niri/nixos.nix
./profiles/desktop/niri/waybar.nix
./profiles/gaming/home.nix
./profiles/gaming/nixos.nix
./profiles/shell/fish.nix
./profiles/storage/nixos.nix
./profiles/theming/home.nix
./profiles/theming/nixos.nix
./users/dillen/default.nix
```

Plus `./profiles/desktop/niri/config.kdl` (not a .nix file).

- [ ] **Step 2: Confirm no lingering references to removed paths**

```bash
grep -rn "modules/nixos\|modules/home\|home/dillen\|hardware-configuration" \
  --include='*.nix' . 2>/dev/null
```

Expected: only the one allowed reference to `modules/options.nix` (which is the kept file, *not* a removed path), and nothing else. If `modules/nixos`, `modules/home`, `home/dillen`, or root-level `hardware-configuration` appears anywhere, fix the offending file.

- [ ] **Step 3: Final rebuild check**

```bash
cd /home/dillen/nixos-config
nix flake check 2>&1 | tail -20
sudo nixos-rebuild build --flake .#nixos 2>&1 | tail -20
```

Expected: both succeed.

- [ ] **Step 4: Diff the realized store path against the pre-refactor build (semantic equivalence)**

```bash
cd /home/dillen/nixos-config
sudo nixos-rebuild build --flake .#nixos
PRE_REFACTOR_GENERATION=$(sudo nix-env --list-generations --profile /nix/var/nix/profiles/system | tail -1 | awk '{print $1}')
echo "Built result symlink:"
readlink -f ./result
echo "Current system generation: $PRE_REFACTOR_GENERATION"
nix store diff-closures /run/current-system $(readlink -f ./result) 2>&1 | head -40
```

Expected: `nix store diff-closures` shows zero meaningful differences (or only trivial closure-size deltas from nixpkgs re-eval ordering). If there are real package additions/removals, investigate before declaring success — something migrated incorrectly.

- [ ] **Step 5: Verify clean git state**

```bash
git status --short
git log --oneline -15
```

Expected: working tree clean (modulo the `result` symlink, which is gitignored or left untracked as it was before). The log shows the sequence of refactor commits in order.

---

## Self-review checklist (already applied — recorded here for reference)

- Spec coverage: every section of the design doc maps to a task. Core → Task 4. Desktop niri → Task 5. Desktop gnome → Task 6. Gaming → Task 7. Theming → Task 8. Shell + storage → Task 9. User relocation → Task 10. Options surface → Task 2. Hardware move → Task 3.
- The kmscon workaround merge into theming is in Task 8.
- The firefox duplicate removal is in Task 8 step 6.
- The KDL extraction strategy explicitly uses `builtins.readFile` (not `.source`) to keep the niri-config-check working — addressed in Task 5 step 4.
- The mangohud/qt/vesktop stylix-target relocation from gaming → theming is paired in Tasks 7 and 8 with a note about the brief gap; rebuild succeeds in both intermediate states.
- Toggle naming is consistent throughout: `mySystem.gaming.enable`, `mySystem.theming.enable`, `mySystem.storage.automount.enable`, `mySystem.desktop`.
