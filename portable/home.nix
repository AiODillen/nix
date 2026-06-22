{ settings, ... }:
{
  imports = [
    ./profiles/core.nix
    ./profiles/shell.nix
  ];

  home.username = settings.username;
  home.homeDirectory = settings.homeDirectory;
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;
}
