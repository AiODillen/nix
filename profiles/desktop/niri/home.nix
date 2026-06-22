{ lib, config, osConfig, ... }:
let
  loc = osConfig.mySystem.locale;
  colors = config.lib.stylix.colors;
  renderedKdl = lib.replaceStrings
    [ "@XKB_LAYOUT@" "@XKB_VARIANT@" "@BORDER_ACTIVE@" "@BORDER_INACTIVE@" ]
    [ loc.xkbLayout loc.xkbVariant "#${colors.base0E}" "#${colors.base01}" ]
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
