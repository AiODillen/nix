{ lib, ... }:
{
  options.mySystem.desktop = lib.mkOption {
    type = lib.types.enum [
      "niri"
      "gnome"
    ];
    default = "niri";
    description = "Which desktop environment to enable. Change and run nixos-rebuild switch.";
  };
}
