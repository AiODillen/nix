# nixos-config

Personal NixOS + home-manager flake. Shared knobs live in **one file**:
`settings.nix` (the `mySystem` block). Device-specific config (identity,
hostname, hardware, gpu, monitors, mounts) lives per machine under `machines/`:
`machines/pc/` (the NixOS PC) and `machines/laptop/` (the standalone Mint laptop).

---

## Fresh machine install

1. Boot the NixOS installer ISO. Partition, format, mount `/mnt`.
2. Generate hardware config (root + boot UUIDs):

   ```sh
   nixos-generate-config --root /mnt
   ```

3. Clone this repo into the new system:

   ```sh
   nix-shell -p git --run 'git clone https://github.com/<you>/nixos-config /mnt/etc/nixos'
   ```

4. Replace hardware file with the generated one:

   ```sh
   cp /mnt/etc/nixos/hardware-configuration.nix /mnt/etc/nixos/machines/pc/hardware.nix
   rm /mnt/etc/nixos/hardware-configuration.nix /mnt/etc/nixos/configuration.nix
   ```

5. **Edit `settings.nix`** (shared: locale, theme, desktop, toggles) and
   **`machines/pc/default.nix`** (this machine: username, hostname, kernel,
   mounts, etc.). Find storage UUIDs with `lsblk -f`.

6. Install:

   ```sh
   nixos-install --flake /mnt/etc/nixos#<hostname>
   ```

7. Reboot. Set user password during install or via `passwd` in the install chroot.

---

## Daily use

```sh
rebuild            # alias: sudo nixos-rebuild switch --flake ~/nixos-config
nix flake update   # bump pinned inputs (nixpkgs, home-manager, stylix)
```

---

## Non-NixOS machine (standalone home-manager)

This flake also exposes a standalone home-manager config for a box that has only
the Nix package manager (no NixOS). The reusable base lives in `template/`; each
machine is a thin overlay under `machines/<name>/` that imports the template and
adds only machine-specific bits. The `niklas` output builds `machines/laptop/`.
It ports packages, stylix theming, fish, AI tooling, gaming home apps, and the
niri/gnome desktop config. System-level pieces (boot, kernel, networking,
pipewire, Steam/gamescope, greetd/portals/flatpak, system locale generation) are
NOT included — the distro provides those.

Prerequisite: home-manager available standalone, e.g.

```sh
nix run home-manager/release-26.05 -- switch --flake ~/Documents/nix#niklas
```

or, once installed:

```sh
home-manager switch --flake ~/Documents/nix#niklas   # alias: rebuild
```

Shared settings come from the same `settings.nix` (`mySystem`) the NixOS build
uses — theming, locale, desktop, and feature toggles. Device-specific values
live in `machines/laptop/` (`device.nix` for identity/gpu/flakePath,
`monitors.nix` for outputs). See `template/README.md` and
`machines/laptop/README.md` for details. Notes:

- The glibc locale named in `localeMain`/`localeRegional` must already exist on
  the distro (`locale -a`) — home-manager only exports the env vars.
- The AI profile writes `~/.claude/{CLAUDE.md,RTK.md,settings.json}` only if they
  do not already exist; an existing Claude setup is left untouched.
- niri appears in your display manager's session list; XWayland apps work via
  `xwayland-satellite`.

---

## Repo layout

```
flake.nix                 # PC nixosConfiguration + laptop homeConfiguration
settings.nix              # ← SHARED settings (mySystem): theme, locale, desktop, toggles
modules/
  options.nix             # mySystem option declarations (schema, shared)
  home/monitors.nix       # shared HM module: kanshi output switching
profiles/                 # toggleable feature bundles (shared)
  core/      shell/       # base system + fish
  theming/                # stylix
  desktop/{niri,gnome}/   # wayland compositors (+ niri config.kdl keybinds)
  gaming/                 # Steam + gamescope
  ai/                     # Claude Code, codegraph, plugins
  local-ai/               # Ollama ROCm + Open WebUI
  storage/                # automount user-home filesystems
users/                    # user account + home-manager glue
  nixos.nix  home.nix     # both parameterized by mySystem.user.name
template/                 # standalone home-manager base (non-NixOS)
  home.nix  profiles/     # imported by the laptop overlay
machines/                 # per-device config (the part that differs per machine)
  pc/                     # NixOS PC: default.nix, hardware.nix, monitors.nix
  laptop/                 # Mint laptop: device.nix, home.nix, monitors.nix
wallpaper.png             # default stylix wallpaper
```

---

## `mySystem` options reference

| Path | Type | Description |
|---|---|---|
| `user.name` | string | Login name. Home dir derived as `/home/<name>`. |
| `user.fullName` | string | GECOS description. |
| `user.extraGroups` | [string] | Extra groups (default: `networkmanager`, `wheel`). |
| `hostname` | string | System hostname. |
| `timezone` | string | IANA timezone. |
| `locale.main` | string | `LANG`. |
| `locale.regional` | string | Regional locale for `LC_*`. |
| `locale.consoleKeymap` | string | TTY keymap. |
| `locale.xkbLayout` | string | Wayland/X layout. |
| `locale.xkbVariant` | string | Wayland/X variant. |
| `kernel` | `default`\|`latest`\|`zen` | Kernel package. |
| `desktop` | `niri`\|`gnome` | Compositor. |
| `ai.enable` | bool | Claude Code, rtk, codegraph, nix-ld. |
| `theming.enable` | bool | Stylix system + home. |
| `theming.polarity` | `dark`\|`light`\|`either` | Stylix polarity (match scheme). |
| `theming.scheme` | string | base16-schemes name (e.g. `catppuccin-mocha`, `gruvbox-dark-hard`, `nord`, `rose-pine`, `tokyo-night-storm`). |
| `theming.wallpaper` | path | Override default wallpaper. |
| `gaming.enable` | bool | Steam, gamescope, MangoHud, LACT. |
| `gaming.gamescope.{width,height}` | int | Gamescope render size (refresh dropped — conflicts with VRR, gamescope #975). |
| `localAi.enable` | bool | Ollama ROCm + Open WebUI. |
| `localAi.rocmGfx` | string | `HSA_OVERRIDE_GFX_VERSION` (7900 XTX=`11.0.0`). |
| `storage.automount.enable` | bool | Mount extra filesystems under home. |
| `storage.automount.mounts` | [{path,uuid,fsType?}] | List of mounts. |

---

## Common changes

**Swap desktop (niri ↔ gnome)**

```nix
mySystem.desktop = "gnome";
```

Rebuild. Log out, pick the other session.

**Add an automount**

```nix
mySystem.storage.automount.mounts = [
  { path = "Data"; uuid = "<uuid>"; fsType = "ext4"; }
];
```

**Change theme**

```nix
mySystem.theming = {
  scheme = "gruvbox-dark-hard";
  polarity = "dark";
};
```

Any name from `pkgs.base16-schemes` works (see `ls ${pkgs.base16-schemes}/share/themes/`).

Dark picks: `catppuccin-mocha`, `gruvbox-dark-hard`, `gruvbox-material-dark-hard`, `nord`, `dracula`, `tokyo-night-storm`, `tokyo-night-moon`, `rose-pine`, `rose-pine-moon`, `kanagawa`, `kanagawa-dragon`, `everforest-dark-hard`, `onedark`, `ayu-mirage`, `solarized-dark`, `material-darker`, `monokai`, `gotham`.

Light picks: `catppuccin-latte`, `gruvbox-light-hard`, `rose-pine-dawn`, `tokyo-night-light`, `solarized-light`, `ayu-light`, `nord-light`, `material-lighter`. Remember to set `polarity = "light"`.

---

## Notes

- **niri config:** `profiles/desktop/niri/config.kdl`. Keyboard layout and variant are templated from `mySystem.locale.xkbLayout/xkbVariant`. Edit + rebuild to apply.
- **Claude plugins:** `profiles/ai/claude-plugins.nix` pins caveman + superpowers commits and npm tools (codegraph, repomix). Bump versions/hashes manually; they're outside flake.lock.
- **Stylix kmscon workaround:** disabled in `machines/pc/default.nix` until upstream stylix release-26.05 ships a fix.
- **`flake check`** validates the niri KDL config (`nix flake check`) when `desktop = "niri"`.
