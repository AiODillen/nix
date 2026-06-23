# Laptop (standalone home-manager)

Self-contained home-manager configuration for the laptop. Everything this
machine needs lives under `machines/laptop/` — profiles, helpers, vars. It
shares only the flake inputs (nixpkgs, home-manager, stylix, nur) with the PC.

Machine-specific values live in `vars.nix` (identity, gpu, flakePath, theme,
locale) and `monitors.nix`; profiles are imported directly in `home.nix`.
There are no feature toggles — a feature runs iff its profile is imported in
`machines/laptop/home.nix`.

Built via the `niklas` home-manager output in the root `flake.nix`:

```sh
home-manager switch --flake ~/Documents/nix#niklas   # alias: rebuild
```

## What this machine includes

- **`monitors.nix` — automatic single-monitor switching (kanshi).**
  When an external monitor is connected, only the external is shown; with no
  external connected, only the laptop panel is shown.

  niri implements `wlr-output-management`, so [kanshi](https://sr.ht/~emersion/kanshi/)
  drives niri's outputs at runtime. Monitor config is **device-specific**, so it
  lives in this per-device file. The kanshi build comes from the monitors helper
  in this tree; this file only supplies this machine's `profiles` and enables
  them when the desktop is niri (kanshi can't drive GNOME). The main PC has its
  own equivalent at `machines/pc/monitors.nix`.

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
  niri service drives, so it starts inside the niri session. Check it with
  `systemctl --user status kanshi`.

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

---

## Post-install notes

- **Locale:** home-manager only *exports* the env vars. The glibc locales named
  in `vars.nix` must already exist on the distro — check `locale -a`, and
  generate them with your distro's tooling (e.g. `sudo locale-gen` /
  `sudo dpkg-reconfigure locales` on Debian/Mint) if missing.

- **AI tooling is skip-if-exists.** `~/.claude/CLAUDE.md`, `RTK.md`, and
  `settings.json` are written **only if they don't already exist** — an existing
  Claude Code setup is left untouched. Delete a file and `rebuild` to regenerate
  it. `codegraph` + `repomix` install to `~/.npm-global` (added to PATH);
  first run needs network.

- **GPU apps need nixGL.** A non-NixOS box has no `/run/opengl-driver`, so
  nix-built GL/Vulkan apps can't find the system driver. The wrapper pair is
  selected by `vars.gpu`:

  - `mesa` (default) — Intel **and** AMD (the "Intel" name is a misnomer).
  - `nvidia` — proprietary driver.

  niri itself runs through the matching wrappers automatically (its session
  unit's `ExecStart` is the wrapped `niri-nixgl`), as does the `gram` launcher.

- **niri session:** the greeter only scans `/usr/share/wayland-sessions`, which
  home-manager can't write. An activation step installs the entry there via
  `sudo`. To keep switches hands-off, install the sudoers rule **once**:

  ```sh
  sudo install -m440 ~/.config/niri-portable/niri-session.sudoers /etc/sudoers.d/niri-session
  ```

  After that, every `home-manager switch` places/updates the entry silently.

- **Steam / gamescope** are not included (system-level). Install Steam via your
  distro; the gaming profile only carries the user-space helpers.

---

## Updating

```sh
nix flake update                              # bump pinned inputs
home-manager switch --flake ~/Documents/nix#niklas
```

The Claude plugin/npm versions are pinned in `machines/laptop/profiles/ai.nix`
(outside `flake.lock`) — bump the version strings + hashes there manually.
