# Laptop standalone home-manager entry. Self-contained: imports this machine's
# own profiles + helper modules. Built via the `niklas` homeConfigurations
# output in the root flake.nix.
{ vars, ... }:
{
  imports = [
    ./firefox-profile.nix
    ./profiles/core.nix
    ./profiles/shell.nix
    ./profiles/locale.nix
    ./profiles/theming.nix
    ./profiles/ai.nix
    ./profiles/gaming.nix
    ./profiles/gpu.nix
    ./profiles/niri.nix
    ./monitors.nix
  ];

  home.username = vars.user;
  home.homeDirectory = vars.homeDirectory;
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;
}
