# NixOS config refactor — host/profile abstraction

## Goal

Reorganize the NixOS configuration around composable **profiles** that span
system (NixOS) and home (home-manager) concerns, controlled by a single
`mySystem.*` options layer. Toggling a feature like `gaming` from the host
file must flip both the system and home sides at once.

## Current state (before)

```
flake.nix
hardware-configuration.nix
hosts/nixos/default.nix
home/dillen/default.nix
modules/
  nixos/
    options.nix          # mySystem.desktop
    common.nix
    disable-kmscon.nix   # 6-line stylix workaround
    stylix.nix
    niri.nix
    gnome.nix
    gaming.nix
    storage.nix
  home/
    common.nix           # 4 lines (xdg)
    packages.nix         # misnamed — actually gaming home apps
    niri.nix             # 133 lines: kdl + waybar + helpers
    gnome.nix
    fish.nix
    stylix.nix           # 3 lines (firefox theming)
```

### Problems

1. `modules/home/packages.nix` is misnamed — its contents are gaming-related,
   while a `modules/nixos/gaming.nix` already exists. Toggling "gaming"
   requires editing two unrelated files.
2. Stylix theming is scattered across four files
   (`nixos/stylix.nix`, `nixos/gnome.nix`, `home/packages.nix`,
   `home/stylix.nix`).
3. `disable-kmscon.nix` is a 6-line stylix workaround sitting alone.
4. `programs.firefox.enable = true` is set in two places
   (`nixos/common.nix` and `home/stylix.nix`).
5. `modules/home/niri.nix` is 133 lines mixing a KDL config string,
   waybar settings, and helper program toggles.
6. Several near-empty files (`home/common.nix`, `home/stylix.nix`,
   `home/gnome.nix`) without clear grouping.
7. Hardware config lives at the repo root rather than next to the host
   that owns it.

## Target state (after)

```
nixos-config/
├── flake.nix
├── flake.lock
├── wallpaper.png
├── hosts/
│   └── nixos/
│       ├── default.nix              # composes profiles, sets toggles
│       └── hardware.nix             # moved from root
├── users/
│   └── dillen/
│       └── default.nix              # home-manager entry for the user
├── modules/
│   └── options.nix                  # mySystem.* options
└── profiles/
    ├── core/
    │   ├── nixos.nix
    │   └── home.nix
    ├── desktop/
    │   ├── niri/
    │   │   ├── nixos.nix
    │   │   ├── home.nix
    │   │   ├── config.kdl           # extracted KDL
    │   │   └── waybar.nix
    │   └── gnome/
    │       ├── nixos.nix
    │       └── home.nix
    ├── gaming/
    │   ├── nixos.nix
    │   └── home.nix
    ├── theming/
    │   ├── nixos.nix
    │   └── home.nix
    ├── shell/
    │   └── fish.nix
    └── storage/
        └── nixos.nix
```

## Toggle model

`modules/options.nix` declares the full `mySystem.*` surface:

```nix
options.mySystem = {
  desktop = lib.mkOption {
    type = lib.types.enum [ "niri" "gnome" ];
    default = "niri";
  };
  gaming.enable          = lib.mkEnableOption "gaming profile";
  theming.enable         = lib.mkEnableOption "stylix theming profile";
  storage.automount.enable = lib.mkEnableOption "automount profile";
};
```

- `desktop` stays an enum because the two desktops are mutually exclusive.
- Other features use `enable` toggles. Each profile module wraps its body
  in `lib.mkIf cfg.<feature>.enable`.
- Home-side modules read `osConfig.mySystem.*` for the matching toggle,
  the same pattern already in use in `modules/home/niri.nix`.

## Composition

`hosts/nixos/default.nix` imports every system-side profile and sets the
toggles in one place:

```nix
{ inputs, ... }:
{
  disabledModules = [
    "${inputs.stylix}/modules/kmscon/nixos.nix"
  ];

  imports = [
    ./hardware.nix
    ../../modules/options.nix
    ../../profiles/core/nixos.nix
    ../../profiles/desktop/niri/nixos.nix
    ../../profiles/desktop/gnome/nixos.nix
    ../../profiles/theming/nixos.nix
    ../../profiles/gaming/nixos.nix
    ../../profiles/storage/nixos.nix
  ];

  mySystem = {
    desktop = "niri";
    gaming.enable = true;
    theming.enable = true;
    storage.automount.enable = true;
  };

  stylix.image = ../../wallpaper.png;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    users.dillen = import ../../users/dillen/default.nix;
  };
}
```

`users/dillen/default.nix` imports every home-side profile:

```nix
{ ... }:
{
  imports = [
    ../../profiles/core/home.nix
    ../../profiles/desktop/niri/home.nix
    ../../profiles/desktop/gnome/home.nix
    ../../profiles/gaming/home.nix
    ../../profiles/theming/home.nix
    ../../profiles/shell/fish.nix
  ];

  home.username = "dillen";
  home.homeDirectory = "/home/dillen";
  home.stateVersion = "26.05";
}
```

## Per-file migration map

| From | To | Notes |
|---|---|---|
| `hardware-configuration.nix` | `hosts/nixos/hardware.nix` | Pure move. |
| `hosts/nixos/default.nix` | `hosts/nixos/default.nix` | Rewritten as profile composition + toggles. |
| `home/dillen/default.nix` | `users/dillen/default.nix` | Moved + imports updated. |
| `modules/nixos/options.nix` | `modules/options.nix` | Extended with `gaming.enable`, `theming.enable`, `storage.automount.enable`. |
| `modules/nixos/common.nix` | `profiles/core/nixos.nix` | Content preserved. |
| `modules/home/common.nix` | `profiles/core/home.nix` | Content preserved (`xdg.enable`). |
| `modules/nixos/niri.nix` | `profiles/desktop/niri/nixos.nix` | Existing `mkIf` guard preserved. |
| `modules/home/niri.nix` | split → `profiles/desktop/niri/home.nix`, `config.kdl`, `waybar.nix` | KDL extracted to file, read via `builtins.readFile`. Waybar config moved to its own module. |
| `modules/nixos/gnome.nix` | `profiles/desktop/gnome/nixos.nix` | Stylix gnome target moves to theming profile. |
| `modules/home/gnome.nix` | `profiles/desktop/gnome/home.nix` | Content preserved. |
| `modules/nixos/gaming.nix` | `profiles/gaming/nixos.nix` | Wrapped in `lib.mkIf cfg.gaming.enable`. |
| `modules/home/packages.nix` | `profiles/gaming/home.nix` | Renamed correctly. Stylix targets (`mangohud`, `vesktop`, `qt`) move to theming. Wrapped in `lib.mkIf osConfig.mySystem.gaming.enable`. |
| `modules/nixos/stylix.nix` | `profiles/theming/nixos.nix` | Wrapped in `lib.mkIf cfg.theming.enable`. Absorbs `disable-kmscon.nix`. Holds gnome target gated by `desktop == "gnome"`. |
| `modules/nixos/disable-kmscon.nix` | deleted | Merged into theming. |
| `modules/home/stylix.nix` | merged into `profiles/theming/home.nix` | Holds all home-side stylix targets in one place. |
| `modules/home/fish.nix` | `profiles/shell/fish.nix` | Content preserved. |
| `modules/nixos/storage.nix` | `profiles/storage/nixos.nix` | Wrapped in `lib.mkIf cfg.storage.automount.enable`. |

## Content cleanups along the way

- **Drop duplicate `programs.firefox.enable`** — keep in
  `profiles/core/nixos.nix` only; remove from the old `home/stylix.nix`
  content during migration.
- **Stylix targets centralized.** `mangohud`/`vesktop`/`qt`/`firefox`
  targets all live in `profiles/theming/home.nix`. The *programs*
  themselves (`programs.mangohud.enable`, `programs.vesktop.enable`)
  remain in `profiles/gaming/home.nix`.

## Niri config validation

`flake.nix` reads
`config.home-manager.users.dillen.xdg.configFile."niri/config.kdl".text`
and pipes it to `niri validate`. After the refactor `profiles/desktop/niri/home.nix`
will still set this attribute, using `builtins.readFile ./config.kdl` instead
of an inline multi-line string. The check therefore keeps working unchanged.

## Validation plan

1. `nix flake check` — runs the niri config-check.
2. `sudo nixos-rebuild build --flake .#nixos` — dry build, no activation.
3. User runs their `rebuild` fish alias at their discretion to activate.

## Non-goals

- Multi-host abstraction beyond keeping the path structure ready for it.
- Multi-user parameterization. `dillen` stays referenced directly.
- Behavioral changes. The refactor must produce an equivalent system.
