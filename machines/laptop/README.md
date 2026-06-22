# Laptop machine overlay

Thin standalone home-manager overlay for this laptop. It imports the shared base
in `../../template` (profiles, theming — all driven by `settings`, which the
root flake derives from the shared `../../settings.nix` plus this machine's
`device.nix`) and adds only what is specific to this machine.

Device-specific values live in `device.nix` (standalone identity, gpu,
flakePath) and `monitors.nix`; shared values live in `../../settings.nix`.

Built via the `niklas` home-manager output in the root `flake.nix`:

```sh
home-manager switch --flake ~/Documents/nix#niklas   # alias: rebuild
```

## What this overlay adds

- **`monitors.nix` — automatic single-monitor switching (kanshi).**
  When an external monitor is connected, only the external is shown; with no
  external connected, only the laptop panel is shown.

  niri implements `wlr-output-management`, so [kanshi](https://sr.ht/~emersion/kanshi/)
  drives niri's outputs at runtime. Monitor config is **device-specific**, so it
  lives in this per-device file — *not* in the shared `mySystem` options. The
  schema and kanshi build come from the shared module
  `modules/home/monitors.nix`; this file only supplies this machine's `profiles`
  and enables them when the desktop is niri (kanshi can't drive GNOME). The main
  PC has its own equivalent at `machines/pc/monitors.nix`.

  kanshi applies the **first** profile whose listed outputs are all connected,
  so order matters: list multi-monitor docks before the bare-laptop fallback.
  To show only externals, list the panel with `status = "disable"` in that
  profile (otherwise the compositor keeps it on). This generalizes to any number
  of monitors — add a profile per dock/topology you care about. Per-output keys:
  `connector`, `status` (`enable`/`disable`), `scale`, `position` (`"x,y"`),
  `mode` (`"3440x1440@100Hz"` — refresh rate is the `@<rate>Hz` part),
  `transform`, `adaptiveSync` (VRR). Connector names: `niri msg outputs`.

  This laptop's profiles: `docked` (panel `eDP-1` off, external `HDMI-A-1` on at
  scale 1.0) and `mobile` (panel `eDP-1` on at scale 1.25). Edit them right here
  in `monitors.nix`.

  kanshi runs as a user service bound to `graphical-session.target`, which the
  template's niri service drives, so it starts inside the niri session. Check it
  with `systemctl --user status kanshi`.

  **Fallback:** with `monitors.fallbackAllOn = true` (default) a catch-all
  `output "*" enable` profile is appended automatically, so if no configured
  profile matches the connected set, every output is simply turned on (extended
  desktop). This is "all on", **not** mirroring — niri/kanshi cannot clone
  outputs declaratively (that would need `wl-mirror`). Set it `false` to leave
  unmatched topologies to niri's own defaults.

  Known limitation: on hotplug niri briefly applies its own output defaults
  before kanshi corrects them, so a momentary flicker is possible
  ([niri #676](https://github.com/niri-wm/niri/issues/676)). If only some of a
  profile's outputs are connected that profile won't match — it falls through to
  the catch-all (all on); add an explicit profile for each partial-dock case you
  want handled differently.

## Adding another machine

1. Copy `machines/laptop/` to `machines/<name>/`.
2. Edit that machine's `monitors.nix` for its outputs (it imports the shared
   `modules/home/monitors.nix`), or drop the file if it needs no output
   switching. Monitor data is per-device and stays in this file.
3. Expose it: either repoint the `niklas` output in the root `flake.nix` to the
   new `home.nix`, or add a second `homeConfigurations.<name>` entry.

A NixOS machine instead reuses the same shared module from its home-manager
config — see `machines/pc/monitors.nix`, imported by `users/home.nix`.
