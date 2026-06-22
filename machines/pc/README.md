# Main PC (NixOS) — per-device config

The PC is a NixOS host (built via `nixosConfigurations`, driven by
`hosts/default/default.nix`), not a standalone home-manager target. This folder
holds its **device-specific** config that doesn't belong in the shared
`mySystem` options.

- **`monitors.nix` — output switching (kanshi, niri only).** Imports the shared
  `modules/home/monitors.nix` and supplies this machine's kanshi `profiles`. It
  is imported by the NixOS user's home-manager config (`users/home.nix`) and
  enabled only when `mySystem.desktop == "niri"` — on GNOME it is inert and
  GNOME manages displays itself.

  No profiles are set yet, so with `fallbackAllOn` (default) every connected
  output is simply enabled. To pin modes/refresh/VRR/layout, run
  `niri msg outputs` on the PC and fill in `profiles` (same schema and per-output
  keys as `machines/laptop/monitors.nix` — `connector`, `status`, `mode` with
  `@<rate>Hz`, `scale`, `position`, `transform`, `adaptiveSync`).

Monitor data is intentionally per-device: editing the PC's monitors here never
touches the laptop's `machines/laptop/monitors.nix`, and neither lands in the
shared `mySystem` block.
