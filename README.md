# nix-config

Personal Nix flake managing two fully independent machines:

- **`machines/pc/`** — NixOS desktop (full system + home-manager)
- **`machines/laptop/`** — standalone home-manager on Linux Mint

The two machines share only the flake inputs (nixpkgs, home-manager, stylix,
nur — all pinned to release-26.05). Each machine owns its own `vars.nix`,
profiles, and helper files. There are no feature toggles — a feature runs iff
its profile is imported in that machine's entry file.

---

## First-time install

```sh
./install.sh                # pick a machine from a menu, confirm, install
./install.sh nixos          # or name it directly (skips the menu)
./install.sh -y niklas      # ...and skip the confirmation prompt
```

`install.sh` is pure bash with no runtime deps beyond `nix`. It discovers the
machines from `flake.nix`, shows an arrow-key menu, enables the required
experimental features (`nix-command`, `flakes`) for every nix call it makes, and
runs the right activation: `nixos-rebuild switch` for NixOS hosts, or
`home-manager switch` for standalone Home Manager users (bootstrapping the HM
CLI via `nix run` when it isn't installed yet).

## Build commands

```sh
sudo nixos-rebuild switch --flake .#nixos     # PC (NixOS)
home-manager switch --flake .#niklas          # laptop (standalone HM)
```

---

## Fresh NixOS install (PC)

1. Boot the NixOS installer ISO. Partition, format, mount `/mnt`.
2. Generate hardware config:

   ```sh
   nixos-generate-config --root /mnt
   ```

3. Clone this repo:

   ```sh
   nix-shell -p git --run 'git clone https://github.com/<you>/nix-config /mnt/etc/nixos'
   ```

4. Replace hardware file with the generated one:

   ```sh
   cp /mnt/etc/nixos/hardware-configuration.nix /mnt/etc/nixos/machines/pc/hardware.nix
   rm /mnt/etc/nixos/hardware-configuration.nix /mnt/etc/nixos/configuration.nix
   ```

5. Edit `machines/pc/vars.nix` (identity, locale, theme) and
   `machines/pc/default.nix` (hardware, imports). Find storage UUIDs with
   `lsblk -f`.

6. Install:

   ```sh
   nixos-install --flake /mnt/etc/nixos#nixos
   ```

7. Reboot. Set user password during install or via `passwd` in the chroot.

---

## Standalone laptop setup

See `machines/laptop/README.md` for prerequisites, first apply, post-install
notes (locale, nixGL, niri session), and updating.

---

## Repo layout

```
flake.nix                   # PC nixosConfiguration + laptop homeConfiguration
machines/
  pc/                       # NixOS PC: default.nix, home.nix, vars.nix,
                            #   hardware.nix, monitors.nix, wallpaper.png,
                            #   profiles/{core,shell,theming,desktop/niri}
  laptop/                   # Mint laptop: home.nix, vars.nix, monitors.nix,
                            #   wallpaper.png, profiles/{core,shell,theming,
                            #   desktop/niri,ai,gaming,locale}
```

---

## Common changes

**Change theme** — edit `vars.nix` in the target machine:

```nix
theme = {
  scheme = "gruvbox-dark-hard";
  polarity = "dark";
};
```

Any name from `pkgs.base16-schemes` works.

**Swap desktop** — change which desktop profile is imported in the machine's
entry file (`default.nix` for PC, `home.nix` for laptop), then rebuild.

---

## Notes

- **niri config:** `machines/pc/profiles/desktop/niri/config.kdl` (PC) /
  `machines/laptop/profiles/desktop/niri/config.kdl` (laptop).
- **Claude plugins:** `machines/*/profiles/ai/claude-plugins.nix` (PC) /
  `machines/laptop/profiles/ai.nix` (laptop) pin plugin commits and npm tools.
  Bump versions/hashes manually; they're outside `flake.lock`.
- **Stylix kmscon workaround:** disabled in `machines/pc/default.nix` until
  upstream stylix release-26.05 ships a fix.
- **`nix flake check`** validates the niri KDL config.
