{ inputs, ... }:
{
  disabledModules = [
    # Stylix's kmscon module is incompatible with nixpkgs 26.05
    # services.kmscon.config was removed
    "${inputs.stylix}/modules/kmscon/nixos.nix"
  ];

  imports = [
    ./hardware.nix
    ../../modules/options.nix
    ../../profiles/core/nixos.nix
    ../../modules/nixos/disable-kmscon.nix
    ../../modules/nixos/stylix.nix
    ../../profiles/desktop/niri/nixos.nix
    ../../modules/nixos/gnome.nix
    ../../modules/nixos/gaming.nix
    ../../modules/nixos/storage.nix
  ];

  # ── DE SWITCH ──────────────────────────────────────────────
  # Change to "gnome" and run: sudo nixos-rebuild switch --flake ~/nixos-config#nixos
  mySystem.desktop = "niri";
  mySystem.gaming.enable = true;
  mySystem.theming.enable = true;
  mySystem.storage.automount.enable = true;
  # ───────────────────────────────────────────────────────────

  # wallpaper.png is at the flake root; path resolves correctly from this file
  stylix.image = ../../wallpaper.png;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    users.dillen = import ../../home/dillen/default.nix;
  };
}
