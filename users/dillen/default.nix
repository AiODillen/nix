{ ... }:
{
  imports = [
    ../../profiles/core/home.nix
    ../../profiles/theming/home.nix
    ../../profiles/desktop/niri/home.nix
    ../../profiles/desktop/gnome/home.nix
    ../../profiles/gaming/home.nix
    ../../profiles/ai/home.nix
    ../../profiles/shell/fish.nix
  ];

  home.username = "dillen";
  home.homeDirectory = "/home/dillen";
  home.stateVersion = "26.05";
}
