# Niri Theme Switcher — Design

**Date:** 2026-07-01
**Status:** Approved, pending implementation plan

## Goal

A fuzzel-based GUI picker to switch the system theme on the fly on both
machines (PC + laptop), with **full-system coverage** (GTK/Qt/Firefox/cursors/
console, not just terminals).

## Background / Constraints

Stylix themes at **build time** only — it writes colors into each app's config
during a rebuild. There is no runtime switch (confirmed:
[stylix discussion #521](https://github.com/nix-community/stylix/discussions/521)
has no runtime story).

Three properties cannot coexist:

```
  full-system coverage  +  live / no-rebuild  +  entire ~250 base16 list
        pick two
```

- Runtime engines (tinty/matugen) give the full list live, but **cannot** theme
  GTK/Qt/Firefox/cursors/console — verified against
  [tinted-theming/home](https://github.com/tinted-theming/home). Ruled out:
  requirement is full-system.
- Full list + full coverage = stylix rebuild each time (status quo, no picker).

Chosen resolution: **NixOS/HM specialisations** — prebuild a curated subset of
full stylix themes, switch between them at runtime. Keeps stylix at 100%
coverage. Home Manager supports specialisations, so this works on both machines.

Machine integration (from `flake.nix`):
- **PC** — Home Manager is a **NixOS module** (`home-manager.nixosModules`), and
  stylix base is NixOS-level (`machines/pc/profiles/theming/nixos.nix`).
  A NixOS specialisation therefore rebuilds HM apps too → full coverage.
  Activation needs root.
- **laptop** — **standalone** Home Manager (`homeConfigurations`), stylix base is
  HM-level (`machines/laptop/profiles/theming.nix`). HM specialisation, user
  activation, no root.

## Theme menu

Curated top-5 (all dark), plus the per-machine default kept as the base (boot)
theme — not a specialisation.

| entry | scheme (base16-schemes attr) | polarity | notes |
|-------|------------------------------|----------|-------|
| default | `vars.scheme` (laptop `everforest` / PC `monokai`) | current | base, no specialisation |
| 1 | `catppuccin-mocha` | dark | |
| 2 | `tokyo-night-dark` | dark | |
| 3 | `gruvbox-dark-medium` | dark | |
| 4 | `nord` | dark | |
| 5 | `dracula` | dark | |

All five confirmed present in the pinned `base16-schemes`
(`0-unstable-2026-01-15`). Fuzzel menu = 6 entries, identical on both machines.

## Components

### 1. Shared theme menu (data)

New `modules/theme-menu.nix` returning a plain list — imported by both the PC
NixOS module and the laptop HM module via `import` (no option-system coupling):

```nix
[ { name = "catppuccin-mocha";    polarity = "dark"; }
  { name = "tokyo-night-dark";    polarity = "dark"; }
  { name = "gruvbox-dark-medium"; polarity = "dark"; }
  { name = "nord";                polarity = "dark"; }
  { name = "dracula";             polarity = "dark"; } ]
```

`name` doubles as the base16-schemes attribute name.

### 2. Specialisation generation (two levels, one data source)

Both consumers map the shared list into specialisations that override only the
stylix scheme + polarity (wallpaper and fonts inherited unchanged):

- **PC** — `machines/pc/profiles/theming/nixos.nix`:
  ```nix
  specialisation = lib.listToAttrs (map (t: {
    inherit (t) name;
    value.configuration.stylix = {
      base16Scheme = "${pkgs.base16-schemes}/share/themes/${t.name}.yaml";
      polarity = t.polarity;
    };
  }) themeMenu);
  ```
  `inheritParentConfig = true` is the default → only stylix is overridden.

- **laptop** — `machines/laptop/profiles/theming.nix`: same mapping against the
  HM `specialisation.<name>.configuration.stylix` option.

### 3. Picker: `theme-switch`

A `pkgs.writeShellApplication` named `theme-switch`, built per machine with the
menu names and a **mode flag** (`nixos` on PC, `hm` on laptop) baked in.

Behaviour:
- No args → present `fuzzel --dmenu` over `[default, catppuccin-mocha,
  tokyo-night-dark, gruvbox-dark-medium, nord, dracula]`; on selection, activate.
- Marks the currently-active entry by reading
  `$XDG_STATE_HOME/theme-switch/current`; writes the new selection there after
  activating.

Activation:
- **hm mode:** resolve the latest generation store path
  (`home-manager generations | head -1`), then run
  `<gen>/specialisation/<name>/activate` for a named theme, or `<gen>/activate`
  for `default`. No root.
- **nixos mode:**
  - named: `sudo /run/current-system/specialisation/<name>/bin/switch-to-configuration switch`
  - default: `sudo /run/current-system/bin/switch-to-configuration switch`

### 4. PC privilege escalation (security)

The NixOS activation requires root. Default approach: a **scoped**
`security.sudo.extraRules` NOPASSWD entry limited to the `switch-to-configuration`
binaries under `/run/current-system` (base + `specialisation/*`). This lets the
picker switch between already-built configs without a password prompt.

Tradeoff: a local process could re-activate any prebuilt specialisation. It
**cannot** change what those configs contain without a rebuild (which is
already privileged). Acceptable on a single-user machine.

Alternative (not chosen by default): `pkexec` graphical auth on each switch —
requires a polkit agent running in the niri session, which is not currently
present and would need to be added.

The laptop path needs no escalation.

### 5. Keybind

Both `config.kdl` files, in the `binds` block:

```
Mod+Shift+T { spawn "theme-switch"; }
```

`Mod+T` already spawns foot; `Mod+Shift+T` is free.

## Known limitations (accepted)

- **Runtime-only:** the next `nixos-rebuild switch` / `home-manager switch`
  reverts to the `vars.scheme` default. Reactivate after a rebuild, or promote a
  scheme to the default by editing `vars`.
- **Fixed menu:** adding/removing a scheme edits `modules/theme-menu.nix` and
  requires a rebuild (new specialisation must be built).
- **niri borders:** niri has no `config.kdl` include directive, and the config
  is HM-rendered, so the focus-ring border colors are not live-switched — they
  follow the base theme until the next rebuild. Everything else (terminals, bar,
  notifications, launcher, GTK, Qt, Firefox, cursors) recolors on switch.
- **Build cost:** five extra full closures per machine. Incremental — the
  closures share most store paths — but a first build after adding the feature
  will build all five.

## Files touched

- `modules/theme-menu.nix` — new, shared data.
- `theme-switch` package — new `writeShellApplication`.
- `machines/pc/profiles/theming/nixos.nix` — specialisation generation +
  scoped sudoers rule.
- `machines/laptop/profiles/theming.nix` — specialisation generation.
- `machines/pc/profiles/desktop/niri/config.kdl` — keybind only.
- `machines/laptop/profiles/niri/config.kdl` — keybind only.
- `theme-switch` added to `home.packages` in the theming/niri HM module of each
  machine (PC `theming/home.nix` or `desktop/niri/home.nix`; laptop
  `theming.nix` or `niri.nix`) — exact module chosen during planning.
