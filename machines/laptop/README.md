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
  drives niri's outputs at runtime. kanshi applies the first profile whose
  listed outputs are all connected, so the two-output `docked` profile is listed
  before the panel-only `mobile` profile.

  | Output    | Role        | Mode      | Scale |
  |-----------|-------------|-----------|-------|
  | `eDP-1`   | laptop panel | 1920x1200 | 1.25  |
  | `HDMI-A-1`| external 34" | 3440x1440 | 1.0   |

  kanshi runs as a user service bound to `graphical-session.target`, which the
  template's niri service drives, so it starts inside the niri session. Check it
  with `systemctl --user status kanshi`.

  Known limitation: on hotplug niri briefly applies its own output defaults
  before kanshi corrects them, so a momentary flicker is possible
  ([niri #676](https://github.com/niri-wm/niri/issues/676)).

  To target a different external connector, edit the `HDMI-A-1` criteria in
  `monitors.nix` (run `niri msg outputs` to list connector names).

## Adding another machine

1. Copy `machines/laptop/` to `machines/<name>/`.
2. Adjust `monitors.nix` (or drop it) for that machine's outputs.
3. Expose it: either repoint the `niklas` output in the root `flake.nix` to the
   new `home.nix`, or add a second `homeConfigurations.<name>` entry.
