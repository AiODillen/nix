{ settings, ... }:
{
  imports = [
    ./profiles/core.nix
    ./profiles/shell.nix
    ./profiles/locale.nix
    ./profiles/theming.nix
    ./profiles/ai.nix
    ./profiles/gaming.nix
  ];

  home.username = settings.username;
  home.homeDirectory = settings.homeDirectory;
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;
}
