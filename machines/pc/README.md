# Main PC (NixOS) — per-device config

The PC is a NixOS host (built via `nixosConfigurations`, assembled by
`machines/pc/default.nix`), not a standalone home-manager target. This tree is
self-contained — it shares only the flake inputs with the laptop. All config
values live in **`vars.nix`** (there is no shared `settings.nix`).

## Where things live

- **`vars.nix` — the one file you edit per machine.** Identity (`user`,
  `hostname`, `fullName`), locale, theme, kernel, gamescope/ROCm targets,
  `storageMounts`, and the **`modules` toggle block**. `user` must match the
  account you create at install — a matching name *adopts* it, it does not
  create a second user.

- **`modules` toggles.** `core` + `shell` are always imported. Every other
  profile is gated by a bool in `vars.modules` (`theming`, `desktop`, `webapps`,
  `gaming`, `ai`, `localAi`, `storage`). Flipping a flag imports/drops that
  profile's `nixos.nix` + `home.nix` halves in `default.nix` + `home.nix` — no
  other edits. Profiles read their values from the `vars` specialArg only.

- **Hardware is read live, not committed.** `default.nix` imports
  `/etc/nixos/hardware-configuration.nix` (the scan `nixos-generate-config`
  leaves on the box) so a fresh install boots its own disks. This makes eval
  impure — build with `--impure`. When that file is absent (evaluating from
  another machine, or `nix flake check` on a non-NixOS box) it falls back to
  `hardware-fallback.nix`, a placeholder that only satisfies module eval and
  never boots anything.

- **`monitors.nix` — output switching (kanshi, niri only).** Imports the shared
  HM monitors module and supplies this machine's kanshi `profiles`. Imported by
  the user's home config only when `modules.desktop = true`. No profiles set yet,
  so `fallbackAllOn` simply enables every connected output. To pin
  modes/refresh/VRR/layout, run `niri msg outputs` and fill in `profiles` (same
  schema as `machines/laptop/monitors.nix`).

Monitor data is intentionally per-device: editing the PC's monitors here never
touches the laptop's `machines/laptop/monitors.nix`.
