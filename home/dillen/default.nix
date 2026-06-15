{ ... }:
{
  imports = [
    ../../profiles/core/home.nix
    ../../profiles/desktop/niri/home.nix
    ../../modules/home/gnome.nix
  ];

  home.username = "dillen";
  home.homeDirectory = "/home/dillen";
  home.stateVersion = "26.05";
}
