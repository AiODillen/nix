# Portable standalone home-manager config (non-NixOS)

**Date:** 2026-06-22
**Status:** Approved, pre-implementation

## Goal

Port as much of this NixOS flake as possible to a **standalone home-manager**
configuration usable on a non-NixOS Linux box (the user's Linux Mint machine)
that has only the Nix package manager. Focus: packages, theming, and
home-manager-level config. System-level NixOS modules are out of scope by
necessity.

## Why this is needed

The existing flake exposes only `nixosConfigurations` and wires home-manager as
a NixOS module (`home-manager.nixosModules.home-manager`). `users/home.nix`
reads `osConfig.mySystem.*`, so the home config cannot evaluate without a full
NixOS system build. On non-NixOS there is no `nixos-rebuild`. A standalone
`homeConfigurations` output, decoupled from `osConfig`, is required.

## Architecture

- **Shared root flake.** Add a `homeConfigurations."<user>"` output to the
  existing root `flake.nix`, reusing its current inputs (nixpkgs 26.05,
  home-manager release-26.05, stylix release-26.05, nur). No second flake, no
  second lockfile.
- Built with `home-manager.lib.homeManagerConfiguration`.
- `pkgs` constructed for `x86_64-linux` with `config.allowUnfree = true` and the
  nur overlay (`inputs.nur.overlays.default`) so `pkgs.nur.repos.rycee.*` and
  unfree packages (vesktop, heroic, steam-adjacent) resolve.
- **Settings via a plain `let` block** threaded into modules with
  `extraSpecialArgs = { inherit settings; }`. No `mySystem` option-type
  machinery. Modules take `settings` as a function arg instead of reading
  `osConfig.mySystem.*`.

```nix
settings = {
  username       = "niklas";
  homeDirectory  = "/home/niklas";
  scheme         = "catppuccin-mocha";   # base16-schemes name
  polarity       = "dark";
  wallpaper      = ./wallpaper.png;       # repo root wallpaper
  localeMain     = "en_US.UTF-8";
  localeRegional = "de_DE.UTF-8";
  xkbLayout      = "de";
  xkbVariant     = "nodeadkeys";
};
```

Apply with:

```sh
home-manager switch --flake .#niklas
```

## Module layout

```
portable/
  home.nix              # entry: imports all profiles; home.username/homeDirectory/stateVersion
  profiles/
    core.nix            # xdg.enable + portable CLI packages
    shell.nix           # programs.fish (HM-appropriate alias, not nixos-rebuild)
    locale.nix          # session env: LANG / LC_* / XKB_DEFAULT_*
    theming.nix         # stylix standalone home module + firefox + targets
    ai.nix              # ~/.claude files + npm/plugin activation (skip-if-exists)
    gaming.nix          # portable home apps only
    niri.nix            # niri compositor + wayland daemons + config.kdl
    gnome.nix           # dconf prefer-dark (harmless if gnome absent)
  config.kdl            # copied/symlinked source for niri (templated at eval)
```

Each profile is **unconditional** — the standalone config imports exactly the
set chosen here; no `lib.mkIf enable` gates. `settings` supplies all
parameterization.

## Profile specifications

### core.nix
- `xdg.enable = true;`
- `home.packages`: `git micro gram nil playerctl brightnessctl`
  (portable subset of the NixOS `environment.systemPackages`).

### shell.nix
- `programs.fish.enable = true;`
- Replace the `rebuild = sudo nixos-rebuild ...` alias with a home-manager
  equivalent: `rebuild = "home-manager switch --flake ~/Documents/nix#niklas";`
  (path may be adjusted by the user).

### locale.nix
- `home.sessionVariables`:
  - `LANG = settings.localeMain`
  - `LC_ADDRESS LC_IDENTIFICATION LC_MEASUREMENT LC_MONETARY LC_NAME
    LC_NUMERIC LC_PAPER LC_TELEPHONE LC_TIME` = `settings.localeRegional`
  - `XKB_DEFAULT_LAYOUT = settings.xkbLayout`
  - `XKB_DEFAULT_VARIANT = settings.xkbVariant`
- XKB vars are read by **both** niri (Wayland) and X11 — single source covers
  both, satisfying "set the x11 locale env too".
- **Caveat:** the glibc locale must already exist on the distro (`locale -a`).
  HM only exports the variables; it cannot run `locale-gen` on non-NixOS.

### theming.nix
- Use the **standalone stylix home module** (`stylix.homeModules.stylix`;
  verify exact attribute name against the pinned stylix release at
  implementation time — may be `homeManagerModules.stylix`).
- `stylix.enable = true;`
- `stylix.polarity = settings.polarity;`
- `stylix.image = settings.wallpaper;`
- `stylix.base16Scheme =
  "${pkgs.base16-schemes}/share/themes/${settings.scheme}.yaml";`
- Fonts: identical to the NixOS theming module — JetBrainsMono Nerd Font Mono,
  Inter, DejaVu Serif, sizes {applications 12, terminal 13, desktop 11,
  popups 11}.
- Targets: `fish`, `firefox` (profileNames `["default"]`, colorTheme),
  `mangohud`, `qt`, `vesktop`. **Drop** `targets.gnome` (NixOS desktop only)
  and the kmscon workaround (NixOS only). GTK theming via stylix default.
- Firefox (HM module installs + themes the browser itself, works on non-NixOS):
  - `programs.firefox.enable`, `profiles.default { isDefault; extensions.force;
    settings."extensions.autoDisableScopes" = 0; }`
  - `policies.ExtensionSettings`: force-install firefox-color, uBlock Origin,
    proton-pass from `pkgs.nur.repos.rycee.firefox-addons.*` (merge of the
    addons currently split across core/nixos.nix and theming/nixos.nix).

### ai.nix
- Port the activation scripts from `profiles/ai/claude-plugins.nix` essentially
  verbatim: `home.sessionPath` += `~/.npm-global/bin`; npm install of
  `@colbymchenry/codegraph` + `repomix`; codegraph MCP registration;
  superpowers + caveman plugin copy + registration; marketplace registration.
  These already self-skip via `[ ! -f ]` guards.
- The three declarative `~/.claude` files (`CLAUDE.md`, `RTK.md`,
  `settings.json`) — currently `home.file.*` (HM symlinks, would clobber an
  existing setup) — become **activation scripts that write the content only if
  the target file does not already exist**. Honors "if ai already exists it
  should skip".
- Drop the `osConfig.mySystem.ai.enable` guard (always on in this config).

### gaming.nix
- `programs.mangohud.enable`, `programs.vesktop.enable`.
- `home.packages`: `faugus-launcher goverlay heroic lact protonplus r2modman`.
- **Exclude** `steam-gamescope` wrapper and the `steam-gamescope` desktop entry
  — gamescope wrapper + Steam need system-level config; on non-NixOS install
  Steam via the distro.

### niri.nix
- `home.packages`: `niri xwayland-satellite nautilus gnome-disk-utility
  pavucontrol`.
- `xdg.configFile."niri/config.kdl".text` = `config.kdl` with `@XKB_LAYOUT@` /
  `@XKB_VARIANT@` replaced from `settings.xkbLayout` / `settings.xkbVariant`
  (same `lib.replaceStrings` pattern as the NixOS niri home module).
- Wayland daemons via HM: `programs.waybar` (port the existing waybar settings
  verbatim), `programs.foot.enable`, `programs.fuzzel.enable`,
  `services.mako.enable`.
- Add `~/.local/share/wayland-sessions/niri.desktop` (via
  `xdg.dataFile`) so a distro display manager can offer a niri session.
- **Can't port** (distro provides): `greetd`, `xdg.portal`, `flatpak`,
  `programs.appimage` binfmt.

### gnome.nix
- `dconf.settings."org/gnome/desktop/interface".color-scheme =
  "prefer-dark";` — harmless when gnome is not running.
- Note: GNOME itself is a full DE, installed via the distro, not home-manager.

## Out of scope (cannot port — NixOS system modules)

boot/loader/kernel, networking (hostname, NetworkManager), pipewire/rtkit,
system i18n + console keymap (only env vars are portable), storage automounts,
Steam program module + gamescope security wrapper, greetd/portal/flatpak/
appimage, system firefox enable, nix-ld.

## Testing / verification

- `nix flake check` must still pass (existing niri KDL check unaffected).
- `nix build .#homeConfigurations.niklas.activationPackage` must evaluate and
  build without a NixOS system.
- Manual: on the Mint box, `home-manager switch --flake .#niklas`, then confirm
  fish theme, firefox theme, `codegraph`/`repomix` on PATH, niri launchable
  from the greeter, and that an existing `~/.claude` setup is left untouched.

## Open risk

- Exact stylix standalone home-module attribute name for the pinned release —
  verify before writing theming.nix.
- `home-manager` must be installed standalone on the target (via `nix profile`
  or `nix run home-manager`); documented in README addendum.
</content>
</invoke>
