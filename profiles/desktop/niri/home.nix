{ lib, osConfig, ... }:
{
  imports = [ ./waybar.nix ];

  config = lib.mkIf (osConfig.mySystem.desktop == "niri") {
    xdg.configFile."niri/config.kdl".text = builtins.readFile ./config.kdl;

    programs.foot.enable = true;
    programs.fuzzel.enable = true;
    services.mako.enable = true;
  };
}
