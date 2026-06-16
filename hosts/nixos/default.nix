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
    ../../profiles/theming/nixos.nix
    ../../profiles/desktop/niri/nixos.nix
    ../../profiles/desktop/gnome/nixos.nix
    ../../profiles/gaming/nixos.nix
    ../../profiles/storage/nixos.nix
    ../../profiles/ai/nixos.nix
  ];

  # ── DE SWITCH ──────────────────────────────────────────────
  # Change to "gnome" and run: sudo nixos-rebuild switch --flake ~/nixos-config#nixos
  mySystem = {
    desktop = "niri";
    ai.enable = true;
    gaming.enable = true;
    theming.enable = true;
    storage.automount.enable = true;
  };
  # ───────────────────────────────────────────────────────────

  # wallpaper.png is at the flake root; path resolves correctly from this file
  stylix.image = ../../wallpaper.png;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = { inherit inputs; };
    users.dillen = import ../../users/dillen/default.nix;
  };
}
