# nix-config

Personal Nix flake managing two fully independent machines:

- **`machines/pc/`** — NixOS desktop (full system + home-manager)
- **`machines/laptop/`** — standalone home-manager on Linux Mint

The two machines share only the flake inputs (nixpkgs, home-manager, stylix,
nur — all pinned to release-26.05). Each machine owns its own `vars.nix`,
profiles, and helper files. There are no feature toggles — a feature runs iff
its profile is imported in that machine's entry file.

---

## Build commands

```sh
sudo nixos-rebuild switch --flake .#nixos --impure   # PC (NixOS)
home-manager switch --flake .#niklas                 # laptop (standalone HM)
```

`--impure` is required on the PC: hardware is read live from
`/etc/nixos/hardware-configuration.nix` (never committed), so a fresh install
boots its own disks instead of a stale committed UUID. Without `--impure` the
build silently falls back to a non-booting placeholder. Alias it if you like:
`alias nrs='sudo nixos-rebuild switch --flake .#nixos --impure'`.

---

## Fresh NixOS install (PC)

Nothing per-machine needs hand-editing except identity in `vars.nix`. Hardware
is read live (no copying UUIDs); the user/hostname are declared from `vars.nix`.

1. Boot the NixOS installer ISO. Partition, format, mount `/mnt`. Create your
   user account during/after install (`passwd` to set its password).
2. Generate the hardware scan — left in place, **read live**, never committed:

   ```sh
   nixos-generate-config --root /mnt          # writes /mnt/etc/nixos/hardware-configuration.nix
   ```

3. Clone this repo:

   ```sh
   nix-shell -p git --run 'git clone https://github.com/<you>/nix-config /mnt/etc/nixos/config'
   ```

4. Set identity in `machines/pc/vars.nix`: `user` **must equal the account you
   created** (matching name adopts it, it does not create a second user), plus
   `hostname`, locale, theme. Toggle optional features in the `modules` block.
   Storage automounts (if `modules.storage = true`) go in `storageMounts`
   (`lsblk -f` for UUIDs).

5. Install (`--impure` so the live hardware scan is read):

   ```sh
   nixos-install --impure --flake /mnt/etc/nixos/config#nixos
   ```

6. Reboot. Rebuild thereafter with `sudo nixos-rebuild switch --flake .#nixos --impure`.

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
                            #   hardware-fallback.nix (live scan read at build),
                            #   monitors.nix, wallpaper.png,
                            #   profiles/{core,shell,theming,desktop/niri,
                            #            gaming,ai,local-ai,storage,webapps}
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

**Enable/disable a feature (PC)** — flip a flag in the `modules` block of
`machines/pc/vars.nix` (`gaming`, `ai`, `localAi`, `storage`, `theming`,
`desktop`, `webapps`) and rebuild. Each flag gates that profile's import in
`default.nix` + `home.nix`; `core` + `shell` are always on.

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
