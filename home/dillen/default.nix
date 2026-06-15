{ ... }:
{
  imports = [
    ../../modules/home/common.nix
    ../../modules/home/niri.nix
    ../../modules/home/gnome.nix
  ];

  home.username = "dillen";
  home.homeDirectory = "/home/dillen";
  home.stateVersion = "26.05";
}
