# swaylock on lid close (laptop) — design

**Date:** 2026-06-24
**Status:** approved
**Scope:** `machines/laptop` (standalone Home Manager on Linux Mint, niri session)

## Goal

When the laptop lid closes, the machine suspends (Mint logind default) and the
screen is locked with `swaylock`, so resuming requires the password.

## Constraints / context

- Laptop is **standalone Home Manager on Linux Mint** (not NixOS). System-level
  `logind` (the lid switch policy) is owned by Mint and is **not** managed by
  Nix. We do not touch it.
- Compositor is **niri**, run via a hand-rolled `systemd.user.services.niri`
  unit (standalone HM has no `systemd.packages` equivalent, so the upstream
  niri user units are recreated by hand in `machines/laptop/profiles/niri.nix`).
- niri runs under nixGL wrappers; `LD_LIBRARY_PATH` pollution from nixGL is a
  known hazard on this host (it broke waybar — see the `waybar-portable`
  wrapper). The lock screen must avoid that environment.
- niri started with `--session` imports the session environment (incl.
  `WAYLAND_DISPLAY`) into the systemd user manager and activates
  `graphical-session.target`, so user units wired to that target see Wayland.

## Mechanism

Pure user-space, **no root**:

1. Lid close → Mint logind suspends the machine (its existing default policy).
2. A `swayidle` user service holds a systemd sleep **inhibitor lock** and, on
   the `before-sleep` event, runs `swaylock`. `swayidle -w` makes it wait for
   swaylock to fork before releasing the inhibitor — so the lock surface is up
   *before* the system actually suspends. On resume, the lock screen is shown.
3. The same swayidle `lock` event handles `loginctl lock-session`, giving a
   manual lock path that reuses the identical locker invocation.

## Components

All in `machines/laptop/profiles/`.

### 1. `programs.swaylock` — `niri.nix`

```nix
programs.swaylock.enable = true;
```

Installs `swaylock` and writes `~/.config/swaylock/config`. swaylock reads that
config regardless of how it is launched, so both the swayidle service and the
manual keybind get the same appearance.

### 2. stylix target — `theming.nix`

```nix
targets.swaylock.enable = true;
```

Themes the lock screen with the existing base16 palette, consistent with the
already-enabled `waybar`/`mako`/`foot` targets.

### 3. swayidle user service — `niri.nix`

Hand-rolled `systemd.user.services.swayidle`, mirroring the existing
`systemd.user.services.niri` convention (this codebase hand-rolls user units):

- `Unit`: `PartOf` / `After` = `graphical-session.target` so it inherits
  `WAYLAND_DISPLAY`; `Description`.
- `Service`:
  `ExecStart = swayidle -w -d lock 'swaylock -f' before-sleep 'swaylock -f'`
  - `-w` — wait for the child (swaylock fork) to finish before releasing the
    sleep inhibitor. **Critical**: without it, the machine can suspend before
    the lock surface exists, leaving a brief unlocked window on resume.
  - `-d` — debug logging to the journal (drop later if noisy; optional).
  - `lock` event — covers `loginctl lock-session` and the manual keybind.
  - `before-sleep` event — the lid-close → suspend path.
  - `swaylock -f` — fork into the background after the lock surface is shown so
    swayidle's `-w` wait completes.
- `Install.WantedBy = [ "graphical-session.target" ]`.

`swayidle` package is pulled in by the service (add to `home.packages` if the
hand-rolled unit does not bring it transitively).

### 4. Manual lock keybind — `niri/config.kdl`

```kdl
Mod+Escape { spawn "loginctl" "lock-session"; }
```

Routes through the swayidle `lock` handler so the manual lock and the
suspend-time lock are identical. Optional — included by default.

## nixGL decision

**No nixGL wrapper for swaylock.** swaylock is a Wayland shm + cairo client (no
GL renderer), and the swayidle service runs in the clean HM systemd user
environment, not niri's `LD_LIBRARY_PATH`-polluted one. So the GLIBCXX hazard
that required `waybar-portable` does not apply.

**Risk / fallback:** if swaylock fails to render or crashes on this host, wrap
its binary in `nixgl.glExe` (the shared wrapper from `nixgl.nix`) the same way
niri and waybar are wrapped, and point both the service and keybind at the
wrapper. To be verified on rebuild.

## Verification

After `home-manager switch`:

1. `systemctl --user status swayidle` → active, running, env has
   `WAYLAND_DISPLAY`.
2. `loginctl lock-session` → swaylock appears, themed, password unlocks.
3. Close the lid → machine suspends; open lid → swaylock is shown, not the
   desktop.
4. `Mod+Escape` → swaylock appears.

## Out of scope

- Idle auto-lock timeout (user chose lock-on-lid + suspend only, no idle timer).
- Changing Mint's logind lid/suspend policy.
- Lock-without-suspend behavior (e.g. lid closed on external monitor).
