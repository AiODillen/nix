{ ... }:
{
  imports = [
    ../../profiles/core/home.nix
    ../../profiles/desktop/niri/home.nix
    ../../profiles/desktop/gnome/home.nix
    ../../profiles/gaming/home.nix
  ];

  home.username = "dillen";
  home.homeDirectory = "/home/dillen";
  home.stateVersion = "26.05";
}
