{ lib, ... }:
{
  options.mySystem = {
    desktop = lib.mkOption {
      type = lib.types.enum [
        "niri"
        "gnome"
      ];
      default = "niri";
      description = "Which desktop environment to enable. Change and run nixos-rebuild switch.";
    };

    gaming.enable = lib.mkEnableOption "gaming profile (Steam, gamescope, gaming home apps)";

    theming.enable = lib.mkEnableOption "stylix theming profile (system + home)";

    storage.automount.enable = lib.mkEnableOption "automount profile (extra filesystems under /home/dillen)";
  };
}
