{ pkgs, ... }:
{
  home.packages = with pkgs; [
    mangohud
    goverlay
    heroic
    discord
    gpu-screen-recorder
    gpu-screen-recorder-ui
    protonplus
  ];
}
