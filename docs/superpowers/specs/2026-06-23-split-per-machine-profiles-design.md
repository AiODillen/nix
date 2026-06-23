# Split into per-machine profiles (drop shared profiles + toggles)

**Date:** 2026-06-23
**Branch:** feat/portable-home-manager
**Status:** Approved (design)

## Goal

Stop sharing profiles between the NixOS PC and the standalone (non-NixOS) laptop.
Each machine becomes fully self-contained and is developed independently going
forward. The shared `mySystem` options schema and its feature toggles are
removed: a machine runs a feature by importing its profile, and omits a feature
by not importing it. No runtime `enable` flags, no `osConfig`/`settings`
bridging.

Only the flake inputs (pinned nixpkgs / home-manager / stylix / nur / nixgl) stay
shared.

## Non-goals

- No behavioural change to what either machine actually installs/themes today.
  This is a restructure: the PC keeps its current packages/theming, the laptop
  keeps its current portable setup. Values are preserved, not changed.
- Not keeping the gnome desktop profile: neither machine uses it (both run niri).
  It is dropped and recoverable from git history.

## Target layout

```
flake.nix / flake.lock          # ONLY shared content (inputs)
machines/
  pc/                           # NixOS host — self-contained
    vars.nix                    # plain attrset: identity + theming + locale + kernel + gamescope...
    default.nix                 # system entry: hardware + profiles + HM glue
    hardware.nix
    monitors.nix                # kanshi schema + this machine's monitor profiles (HM)
    firefox-profile.nix         # own copy of the first-activation adoption script
    home.nix                    # HM user entry (imports the home.nix profiles + monitors)
    profiles/
      core/        { nixos.nix, home.nix }
      shell/       { nixos.nix, home.nix }
      theming/     { nixos.nix, home.nix }
      gaming/      { nixos.nix, home.nix }
      ai/          { nixos.nix, home.nix, claude-plugins.nix }
      local-ai/    nixos.nix
      storage/     nixos.nix
      desktop/niri/{ nixos.nix, home.nix, config.kdl, waybar.nix }
  laptop/                       # standalone home-manager — self-contained
    vars.nix                    # plain attrset: user, homeDirectory, gpu, flakePath, theming, locale...
    home.nix                    # HM entry (imports its profiles + monitors)
    monitors.nix                # kanshi schema + this machine's monitor profiles
    nixgl.nix                   # own copy of the nixGL wrapper selector
    firefox-profile.nix         # own copy of the adoption script
    README.md                   # moved from template/README.md, rewritten
    profiles/
      core.nix  shell.nix  locale.nix  theming.nix  ai.nix
      gaming.nix  gpu.nix  niri.nix
      niri/config.kdl           # own copy
```

### Deleted

- `profiles/` (shared profile tree)
- `settings.nix` (shared values — folded into each machine's `vars.nix`)
- `modules/options.nix` (the `mySystem` schema + toggles)
- `modules/home/firefox-profile.nix`, `modules/home/monitors.nix` (copied into each machine instead)
- `template/` (entire standalone base — content moves under `machines/laptop/`)
- `users/` (NixOS user glue — folds into `machines/pc/`)
- gnome profiles (`profiles/desktop/gnome/*`, `template/profiles/gnome.nix`)

## Per-machine values (`vars.nix`)

Each machine has one plain attrset, imported and threaded to its profiles. No
option types/validation — just a value bag. Replaces today's
`settings.nix` + `options.nix` defaults + device file.

`machines/pc/vars.nix` (NixOS), values preserved from today:

```nix
{
  hostname = "nixos";
  user = "dillen";
  fullName = "dillen";
  extraGroups = [ "networkmanager" "wheel" ];

  scheme = "monokai";
  polarity = "dark";
  # wallpaper = ./wallpaper.png;

  timezone = "Europe/Berlin";
  localeMain = "en_US.UTF-8";
  localeRegional = "de_DE.UTF-8";
  consoleKeymap = "de-latin1-nodeadkeys";
  xkbLayout = "de";
  xkbVariant = "nodeadkeys";

  kernel = "default";

  gamescope = { width = 3440; height = 1440; };
  rocmGfx = "11.0.0";        # only if local-ai stays imported
  # storage automount entries inlined in storage profile or here as needed
}
```

`machines/laptop/vars.nix` (standalone), values preserved from today:

```nix
{
  user = "niklas";
  homeDirectory = "/home/niklas";
  gpu = "mesa";
  flakePath = "~/Documents/nix";

  scheme = "monokai";
  polarity = "dark";
  # wallpaper = ./wallpaper.png;

  localeMain = "en_US.UTF-8";
  localeRegional = "de_DE.UTF-8";
  xkbLayout = "de";
  xkbVariant = "nodeadkeys";
}
```

(Theming/locale values are duplicated across the two `vars.nix` files on
purpose — the machines are independent now and may drift.)

## Wiring

### PC (NixOS)

`flake.nix` imports the attrset for output naming and threads `vars` through
both module systems:

```nix
pcVars = import ./machines/pc/vars.nix;

nixosConfigurations.${pcVars.hostname} = lib.nixosSystem {
  system = "x86_64-linux";
  specialArgs = { inherit inputs; vars = pcVars; };
  modules = [
    { nixpkgs.overlays = [ inputs.nur.overlays.default ]; }
    home-manager.nixosModules.home-manager
    stylix.nixosModules.stylix
    ./machines/pc/default.nix
  ];
};
```

`machines/pc/default.nix` sets `home-manager.extraSpecialArgs = { inherit inputs; vars = pcVars; }`
(it receives `vars` as a module arg and forwards it). Every PC profile — system
*and* home — then takes `{ vars, ... }`:

- system profiles: `config.mySystem.X` → `vars.X`
- home profiles: `osConfig.mySystem.X` → `vars.X` (the `osConfig` dependency is
  removed)
- all `lib.mkIf <toggle>` guards are deleted; the profile is unconditionally
  active because it is only imported when wanted.

### Laptop (standalone HM)

`flake.nix` builds the HM config directly — no `evalModules`, no `laptopCfg`, no
`hmSettings` reshaping:

```nix
laptopVars = import ./machines/laptop/vars.nix;

homeConfigurations.${laptopVars.user} = home-manager.lib.homeManagerConfiguration {
  pkgs = hmPkgs;   # import nixpkgs with allowUnfree + nur overlay, as today
  extraSpecialArgs = { inherit inputs; vars = laptopVars; };
  modules = [ inputs.stylix.homeModules.stylix ./machines/laptop/home.nix ];
};
```

Laptop profiles take `{ vars, ... }` (today's `settings.*` → `vars.*`), all
unconditional. `nixgl.nix` takes `vars.gpu`. The `homeConfigurations` output is
now defined unconditionally (today's `standalone.enable` `optionalAttrs` guard is
removed).

### flake.nix net change

Removed: `laptopCfg` evalModules block, `cfg = system.config.mySystem`,
`hmSettings`, `lib.optionalAttrs laptopCfg.standalone.enable`. The niri
`checks.x86_64-linux.niri-config` is kept but reads the kdl from the PC config /
path directly rather than gating on `cfg.desktop`.

## Migration mechanics

- `git mv` where a file moves mostly intact, so history follows
  (`profiles/desktop/niri/config.kdl`, `waybar.nix`, niri unit logic,
  `modules/home/monitors.nix`, `template/README.md`). A second copy is then made
  for the other machine where both need it.
- Rewrite where files merge or split: each `vars.nix` (from `settings.nix` +
  `options.nix` defaults + device file), and every profile (strip `mkIf` /
  `osConfig` / `settings` plumbing, point at `vars`).
- `firefox-profile.nix` and `nixgl.nix` copied into each machine that uses them.
- Root `README.md` rewritten to describe the two-independent-machines model;
  `machines/laptop/README.md` carries the standalone setup docs.

## Verification

Both must pass before the work is considered done:

- `nix flake check` — evaluates outputs and runs the niri `config.kdl` validate
  check.
- `nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel`
  (PC) evaluates and builds.
- `nix build .#homeConfigurations.<user>.activationPackage` (laptop) evaluates
  and builds.

No behavioural diff is expected versus the current tree for either machine
(same packages, theming, desktop).

## Risks / notes

- **Duplication is now load-bearing.** niri config, nixgl, firefox adoption, the
  monitors module, and theming/locale values exist twice. This is the intended
  trade for independent development; a change wanted on both machines must be
  applied twice.
- **firefox profile adoption** is kept on both machines to preserve current
  first-activation safety (rename existing random-named profile → `default`).
- **storage automount** values currently live in `mySystem.storage.automount`.
  They fold into the PC's storage profile (inlined or via `pcVars`); the laptop
  has no storage profile.
