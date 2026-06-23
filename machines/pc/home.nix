# NixOS user's home-manager config. Self-contained: imports this machine's home
# profiles + helper modules. Receives `vars` via home-manager.extraSpecialArgs.
{ vars, ... }:
{
  imports = [
    ./firefox-profile.nix
    ./profiles/core/home.nix
    ./profiles/theming/home.nix
    ./profiles/desktop/niri/home.nix
    ./profiles/shell/home.nix
    ./monitors.nix
  ];

  home.username = vars.user;
  home.homeDirectory = "/home/${vars.user}";
  home.stateVersion = "26.05";
}
