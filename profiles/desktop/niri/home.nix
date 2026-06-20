{ lib, osConfig, ... }:
let
  loc = osConfig.mySystem.locale;
  renderedKdl = lib.replaceStrings
    [ "@XKB_LAYOUT@" "@XKB_VARIANT@" ]
    [ loc.xkbLayout loc.xkbVariant ]
    (builtins.readFile ./config.kdl);
in
{
  imports = [ ./waybar.nix ];

  config = lib.mkIf (osConfig.mySystem.desktop == "niri") {
    xdg.configFile."niri/config.kdl".text = renderedKdl;

    programs.foot.enable = true;
    programs.fuzzel.enable = true;
    services.mako.enable = true;
  };
}
