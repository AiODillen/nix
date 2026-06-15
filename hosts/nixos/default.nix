{ inputs, ... }:
{
  disabledModules = [
    # Stylix's kmscon module is incompatible with nixpkgs 26.05
    # services.kmscon.config was removed
    "${inputs.stylix}/modules/kmscon/nixos.nix"
  ];

  imports = [
    ../../hardware-configuration.nix
    ../../modules/nixos/options.nix
    ../../modules/nixos/common.nix
    ../../modules/nixos/disable-kmscon.nix
    ../../modules/nixos/stylix.nix
    ../../modules/nixos/niri.nix
    ../../modules/nixos/gnome.nix
  ];

  # ── DE SWITCH ──────────────────────────────────────────────
  # Change to "gnome" and run: sudo nixos-rebuild switch --flake ~/nixos-config#nixos
  mySystem.desktop = "niri";
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
