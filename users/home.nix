{ osConfig, ... }:
let
  u = osConfig.mySystem.user.name;
in
{
  imports = [
    ../profiles/core/home.nix
    ../profiles/theming/home.nix
    ../profiles/desktop/niri/home.nix
    ../profiles/desktop/gnome/home.nix
    ../profiles/gaming/home.nix
    ../profiles/ai/home.nix
    ../profiles/shell/home.nix
    ../machines/pc/monitors.nix
  ];

  home.username = u;
  home.homeDirectory = "/home/${u}";
  home.stateVersion = "26.05";
}
