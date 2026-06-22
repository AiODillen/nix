# Laptop machine overlay

Thin standalone home-manager overlay for this laptop. It imports the shared base
in `../../template` (identity, profiles, theming — all driven by the `settings`
the root flake assembles from `hosts/default/default.nix`) and adds only what is
specific to this machine.

Built via the `niklas` home-manager output in the root `flake.nix`:

```sh
home-manager switch --flake ~/Documents/nix#niklas   # alias: rebuild
```

## What this overlay adds

- **`monitors.nix` — automatic single-monitor switching (kanshi).**
  When an external monitor is connected, only the external is shown; with no
  external connected, only the laptop panel is shown.

  niri implements `wlr-output-management`, so [kanshi](https://sr.ht/~emersion/kanshi/)
  drives niri's outputs at runtime. **`monitors.nix` hardcodes nothing** — it
  maps the profile list from the one config file
  (`mySystem.standalone.monitors` in `hosts/default/default.nix`) straight onto
  kanshi profiles.

  kanshi applies the **first** profile whose listed outputs are all connected,
  so order matters: list multi-monitor docks before the bare-laptop fallback.
  To show only externals, list the panel with `status = "disable"` in that
  profile (otherwise the compositor keeps it on). This generalizes to any number
  of monitors — add a profile per dock/topology you care about. Per-output keys:
  `connector`, `status` (`enable`/`disable`), `scale`, `position` (`"x,y"`),
  `mode` (`"3440x1440@60Hz"`), `transform`. Connector names: `niri msg outputs`.

  This laptop's default profiles: `docked` (panel `eDP-1` off, external
  `HDMI-A-1` on at scale 1.0) and `mobile` (panel `eDP-1` on at scale 1.25).
  Change monitors by editing the `monitors` block in the one config file, not
  this overlay.

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
2. Set that machine's outputs in `mySystem.standalone.monitors` (the one config
   file) — `monitors.nix` reads them, so leave it as-is (or drop it + the
   `monitors.enable` toggle if the machine needs no output switching).
3. Expose it: either repoint the `niklas` output in the root `flake.nix` to the
   new `home.nix`, or add a second `homeConfigurations.<name>` entry.
