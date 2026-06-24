# swaylock on lid close (laptop) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lock the laptop screen with swaylock when the lid closes (and the machine suspends).

**Architecture:** A `swayidle` user service holds a systemd sleep inhibitor and runs `swaylock` on the `before-sleep` event, so the lock surface is up before Mint's logind suspends on lid close. The same `lock` event serves `loginctl lock-session` and a manual keybind. All user-space, no root, no change to Mint's logind policy.

**Tech Stack:** Nix (standalone Home Manager), niri (Wayland), swayidle, swaylock, stylix, systemd user units.

## Global Constraints

- Target host: `machines/laptop` — **standalone Home Manager on Linux Mint** (not NixOS). Do **not** add NixOS-module options; use Home Manager options only.
- System `logind` / lid policy is owned by Mint and is **out of scope** — do not touch it.
- Hand-roll systemd **user** units (this codebase has no `systemd.packages`; see the existing `systemd.user.services.niri` in `machines/laptop/profiles/niri.nix`). Mirror its `graphical-session.target` wiring.
- **No nixGL wrapper for swaylock** (it is a Wayland shm+cairo client; the swayidle service runs in the clean HM user env). Fallback only if it misbehaves: wrap in `nixgl.glExe` like niri/waybar.
- Rebuild command: `home-manager switch --flake ~/Documents/nix#niklas` (shell alias `rebuild`).
- Spec: `docs/superpowers/specs/2026-06-24-swaylock-lid-close-design.md`.

---

### Task 1: Lock mechanism — swaylock + stylix theme + swayidle service

Installs the locker, themes it, and wires the swayidle service that locks before suspend. Deliverable: after rebuild, `swayidle` runs as a user service and `loginctl lock-session` shows a themed swaylock.

**Files:**
- Modify: `machines/laptop/profiles/niri.nix` (add `swayidle` package, `programs.swaylock`, `systemd.user.services.swayidle`)
- Modify: `machines/laptop/profiles/theming.nix` (add `targets.swaylock.enable`)

**Interfaces:**
- Consumes: existing `pkgs`, `config`, the `systemd.user.services.niri` pattern, the `stylix.targets.*` block.
- Produces: `swaylock` binary on PATH; a running `swayidle.service` that runs `swaylock -f` on the `lock` and `before-sleep` events. Later tasks invoke locking via `loginctl lock-session`.

- [ ] **Step 1: Enable swaylock and add the swayidle package**

In `machines/laptop/profiles/niri.nix`, add `swayidle` to `home.packages` (the `swaylock` binary comes from `programs.swaylock` below):

```nix
  home.packages = with pkgs; [
    niri
    niriWrapped # `niri-nixgl` — nixGL-wrapped niri (ExecStart of niri.service)
    waybarWrapped # `waybar-portable` — waybar with LD_LIBRARY_PATH cleared
    wiremix # pipewire TUI mixer (opened from waybar audio module)
    xwayland-satellite # on-demand XWayland; niri exports $DISPLAY when present
    nautilus
    gnome-disk-utility
    pavucontrol
    swayidle # idle/sleep manager — runs swaylock on before-sleep (lid close)
  ];
```

- [ ] **Step 2: Enable programs.swaylock**

In the same file, near the other `programs.*` enables (e.g. `programs.foot.enable`), add:

```nix
  # Screen locker. Config written to ~/.config/swaylock/config; swaylock reads
  # it however launched (swayidle service or manual keybind). No nixGL wrapper:
  # swaylock is a Wayland shm+cairo client and the swayidle service runs in the
  # clean HM user env, not niri's LD_LIBRARY_PATH-polluted one.
  programs.swaylock.enable = true;
```

- [ ] **Step 3: Add the swayidle user service**

In the same file, after the `systemd.user.services.niri` / `systemd.user.targets.niri-shutdown` block, add:

```nix
  # Lock on lid close: Mint logind suspends on lid close (its default); this
  # swayidle service holds a sleep inhibitor and runs swaylock on before-sleep,
  # so the lock surface is up before suspend completes. The `lock` event covers
  # `loginctl lock-session` and the manual keybind. -w waits for swaylock to
  # fork before releasing the inhibitor (critical — else a brief unlocked
  # window on resume). Wired to graphical-session.target so it inherits
  # WAYLAND_DISPLAY (niri --session imports the env into the user manager).
  systemd.user.services.swayidle = {
    Unit = {
      Description = "Idle manager — lock screen before sleep (lid close)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = ''
        ${pkgs.swayidle}/bin/swayidle -w \
          lock '${pkgs.swaylock}/bin/swaylock -f' \
          before-sleep '${pkgs.swaylock}/bin/swaylock -f'
      '';
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
```

- [ ] **Step 4: Add the stylix swaylock target**

In `machines/laptop/profiles/theming.nix`, inside the `stylix` block alongside the other `targets.*` lines, add:

```nix
    targets.swaylock.enable = true;
```

- [ ] **Step 5: Rebuild**

Run: `home-manager switch --flake ~/Documents/nix#niklas`
Expected: build succeeds, generation activates with no eval/build errors.

- [ ] **Step 6: Verify the service is running**

Run: `systemctl --user status swayidle`
Expected: `active (running)`. If `inactive`, run `systemctl --user start swayidle` and re-check; confirm `WAYLAND_DISPLAY` is set in its environment with `systemctl --user show-environment | grep WAYLAND_DISPLAY`.

- [ ] **Step 7: Verify manual lock works**

Run: `loginctl lock-session`
Expected: a themed swaylock screen appears; typing the password unlocks it. (If swaylock fails to render, apply the nixGL fallback from Global Constraints: wrap `${pkgs.swaylock}/bin/swaylock` as `${nixgl.glExe} ${pkgs.swaylock}/bin/swaylock` in the service, rebuild, retry.)

- [ ] **Step 8: Verify lock on suspend**

Close the lid (or run `systemctl suspend`); reopen / resume.
Expected: on resume the swaylock screen is shown, not the desktop.

- [ ] **Step 9: Commit**

```bash
git add machines/laptop/profiles/niri.nix machines/laptop/profiles/theming.nix
git commit -m "feat(laptop): lock with swaylock on lid close

Add a swayidle user service that holds a sleep inhibitor and runs
swaylock on before-sleep, plus stylix theming for the lock screen."
```

---

### Task 2: Manual lock keybind

Adds a niri keybind that locks on demand through the same swayidle `lock` path. Independently rejectable (some users prefer no extra bind).

**Files:**
- Modify: `machines/laptop/profiles/niri/config.kdl` (add a bind in the `binds { ... }` block)

**Interfaces:**
- Consumes: the running `swayidle.service` `lock` handler from Task 1.
- Produces: `Mod+Escape` → `loginctl lock-session` → swaylock.

- [ ] **Step 1: Add the keybind**

In `machines/laptop/profiles/niri/config.kdl`, inside `binds {` (e.g. after the `Mod+V { toggle-window-floating; }` line), add:

```kdl
    Mod+Escape { spawn "loginctl" "lock-session"; }
```

- [ ] **Step 2: Rebuild**

Run: `home-manager switch --flake ~/Documents/nix#niklas`
Expected: build succeeds (config.kdl is read at eval via `builtins.readFile`, so the new bind is baked into the generation).

- [ ] **Step 3: Verify the keybind**

Press `Mod+Escape`.
Expected: swaylock appears immediately; password unlocks.

- [ ] **Step 4: Commit**

```bash
git add machines/laptop/profiles/niri/config.kdl
git commit -m "feat(laptop): add Mod+Escape manual lock keybind

Routes through loginctl lock-session into the swayidle lock handler."
```

---

## Self-Review

- **Spec coverage:** programs.swaylock (Task 1.2), stylix target (Task 1.4), swayidle service with `-w` + `lock`/`before-sleep` (Task 1.3), manual keybind (Task 2.1), graphical-session wiring (Task 1.3), nixGL decision + fallback (Global Constraints + Task 1.7), verification (Task 1.6–1.8, 2.3). All spec sections mapped. Out-of-scope items (idle timeout, logind policy, lock-without-suspend) correctly absent.
- **Placeholders:** none — all edits show exact code; fallback is concrete.
- **Consistency:** `${pkgs.swaylock}/bin/swaylock -f` used identically in `lock` and `before-sleep`; `swayidle.service` name consistent across tasks; rebuild command identical everywhere.
