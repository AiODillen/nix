{ pkgs, ... }:
{
  # Stylix theming for home apps
  stylix.targets.mangohud.enable = true;
  stylix.targets.qt.enable = true;

  programs.mangohud.enable = true;

  programs.vesktop.enable = true;
  stylix.targets.vesktop.enable = true;

  home.packages = with pkgs; [
    goverlay
    heroic
    gpu-screen-recorder
    gpu-screen-recorder-overlay
    protonplus
  ];
}
