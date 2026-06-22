{ settings, ... }:
{
  imports = [
    ../modules/home/firefox-profile.nix
    ./profiles/core.nix
    ./profiles/shell.nix
    ./profiles/locale.nix
    ./profiles/theming.nix
    ./profiles/ai.nix
    ./profiles/gaming.nix
    ./profiles/gpu.nix
    ./profiles/niri.nix
    ./profiles/gnome.nix
  ];

  home.username = settings.username;
  home.homeDirectory = settings.homeDirectory;
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;
}
