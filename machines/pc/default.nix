# Main PC — NixOS host.
#
# Assembles the system: the shared schema (modules/options.nix), the shared
# settings (../../settings.nix), the shared profiles, this machine's hardware,
# and the home-manager glue. Everything below `mySystem` here is
# DEVICE-SPECIFIC; shared values come from ../../settings.nix.
{ config, inputs, ... }:
{
  disabledModules = [
    # Stylix's kmscon module is incompatible with nixpkgs 26.05.
    # TODO: drop once upstream stylix release-26.05 ships the fix.
    "${inputs.stylix}/modules/kmscon/nixos.nix"
  ];

  imports = [
    ./hardware.nix
    ../../settings.nix
    ../../modules/options.nix
    ../../profiles/core/nixos.nix
    ../../profiles/shell/nixos.nix
    ../../profiles/theming/nixos.nix
    ../../profiles/desktop/niri/nixos.nix
    ../../profiles/desktop/gnome/nixos.nix
    ../../profiles/gaming/nixos.nix
    ../../profiles/storage/nixos.nix
    ../../profiles/ai/nixos.nix
    ../../profiles/local-ai/nixos.nix
    ../../users/nixos.nix
  ];

  # ── Device-specific (this machine only) ────────────────────────────────────
  mySystem = {
    user = {
      name = "dillen";
      fullName = "dillen";
      extraGroups = [
        "networkmanager"
        "wheel"
      ];
    };
    hostname = "nixos";

    desktop = "niri"; # "niri" | "gnome" — this machine's compositor (config is shared)

    kernel = "default"; # "default" | "latest" | "zen"

    gaming.gamescope = {
      width = 3440;
      height = 1440;
    };

    localAi = {
      enable = false;
      rocmGfx = "11.0.0"; # 7900 XTX=11.0.0, 7800/7700 XT=11.0.1, 6900 XT=10.3.0
    };

    storage.automount = {
      enable = false;
      mounts = [
        {
          path = "Grab";
          uuid = "b7139bdc-09fd-4008-9ab2-243eb5aacc05";
        }
        {
          path = "Games_Part";
          uuid = "9171c17f-e154-41f4-87ac-69a020fbebbd";
        }
      ];
    };
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = { inherit inputs; };
    users.${config.mySystem.user.name} = import ../../users/home.nix;
  };
}
