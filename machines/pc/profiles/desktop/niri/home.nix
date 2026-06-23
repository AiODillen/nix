{ lib, config, vars, ... }:
let
  colors = config.lib.stylix.colors;
  renderedKdl = lib.replaceStrings
    [ "@XKB_LAYOUT@" "@XKB_VARIANT@" "@BORDER_ACTIVE@" "@BORDER_INACTIVE@" ]
    [ vars.xkbLayout vars.xkbVariant "#${colors.base0E}" "#${colors.base01}" ]
    (builtins.readFile ./config.kdl);
in
{
  imports = [ ./waybar.nix ];

  xdg.configFile."niri/config.kdl".text = renderedKdl;

  programs.foot.enable = true;
  programs.fuzzel.enable = true;
  services.mako.enable = true;
}
