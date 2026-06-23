# Template folder + laptop machine overlay with monitor switching

**Date:** 2026-06-22
**Status:** Approved

## Goal

1. Rename the standalone home-manager config `portable/` to `template/` so it
   reads as a reusable base rather than one machine's config.
2. Add a thin, machine-specific overlay for the current laptop that reuses the
   template and is activatable with home-manager.
3. The laptop overlay drives niri outputs so that, when an external monitor is
   connected, only the external is shown; with no external, only the laptop
   panel is shown.

## Context

- `flake.nix` exposes one `homeConfigurations.<user>` (user = `niklas`,
  from `mySystem.standalone`) built from `portable/home.nix`.
- `portable/home.nix` imports `portable/profiles/*.nix`; identity and feature
  toggles come from the shared `settings` set assembled in `flake.nix` out of
  `hosts/default/default.nix` (`mySystem`).
- `portable/profiles/niri.nix` renders the shared niri config from
  `profiles/desktop/niri/config.kdl` (used by the NixOS side too) and recreates
  niri's systemd user units, wrapping niri in nixGL. It binds the graphical
  session via `graphical-session.target`.
- Live outputs on this laptop: `eDP-1` (laptop panel, 1920x1200, scale 1.25),
  `HDMI-A-1` (external Philips 34", 3440x1440, scale 1.0).
- niri implements `wlr-output-management` since v0.1.8, so kanshi can configure
  its outputs. nixpkgs 26.05 niri is well past that.

## Design

### 1. Rename `portable/` -> `template/`

`git mv portable template`. Relative imports are unaffected:
`template/profiles/niri.nix` still reaches the repo-root shared config via
`../../profiles/desktop/niri/config.kdl` (same directory depth). `template/`
becomes a base that is imported, not built directly.

### 2. `machines/laptop/` thin overlay

```
machines/laptop/
  home.nix       # imports = [ ../../template/home.nix ./monitors.nix ];
  monitors.nix   # services.kanshi monitor switching
  README.md
```

`home.nix` imports the whole template (identity/profiles unchanged, still
driven by `settings`) plus `monitors.nix`. No profile files are duplicated; an
edit to a template profile flows to the laptop automatically.

### 3. `monitors.nix` — kanshi switching

```nix
{ ... }:
{
  services.kanshi = {
    enable = true;
    settings = [
      # docked FIRST: matches when external present; disables laptop panel.
      { profile.name = "docked"; profile.outputs = [
          { criteria = "eDP-1"; status = "disable"; }
          { criteria = "HDMI-A-1"; status = "enable"; position = "0,0"; scale = 1.0; }
        ]; }
      # mobile: only the laptop panel is connected.
      { profile.name = "mobile"; profile.outputs = [
          { criteria = "eDP-1"; status = "enable"; position = "0,0"; scale = 1.25; }
        ]; }
    ];
  };
}
```

Notes:
- kanshi applies the first profile whose listed outputs are all connected, so
  `docked` (requires both outputs) must precede `mobile` (requires only eDP-1),
  otherwise `mobile` would also match while docked.
- External is keyed by connector name `HDMI-A-1`.
- Scales mirror the current live setup (eDP-1 1.25, HDMI-A-1 1.0).
- kanshi binds to `config.wayland.systemd.target` (= `graphical-session.target`
  by default), which the template's niri.service already drives, so the kanshi
  user service starts inside the niri session. `services.kanshi.enable` pulls
  in the kanshi package.

### 4. flake.nix

Repoint the `homeConfigurations.${hmSettings.username}` module list entry from
`./portable/home.nix` to `./machines/laptop/home.nix`. The output name stays
`niklas`; apply unchanged with `home-manager switch --flake .#niklas`. The
`checks.niri-config` derivation is unrelated (it validates the NixOS
home-manager user's config.kdl) and stays as-is.

### 5. Docs

- `template/README.md`: reworded to describe a generic base.
- `machines/laptop/README.md`: short note documenting the monitor behavior and
  how to add another machine (copy the laptop folder, adjust kanshi outputs,
  add a flake output or repoint).
- Update any references to `portable/` in the repo-root `README.md`.

## Known limitations

- Hotplug race (niri issue #676): niri applies its own output defaults on
  connect, then kanshi corrects, so a brief flicker / momentary wrong layout is
  possible. Accepted; no custom workaround.

## Out of scope (YAGNI)

- DisplayPort or other dock connectors (only HDMI-A-1 handled).
- Mirroring mode.
- Per-workspace output pinning.

## Verification

- `nix flake check` passes (niri-config check still validates).
- `home-manager switch --flake .#niklas` builds and activates.
- `systemctl --user status kanshi` is active inside the niri session.
- Unplug external -> laptop panel comes on; replug -> laptop panel off, only
  external shown.
