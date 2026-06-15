{ lib, osConfig, pkgs, ... }:
lib.mkIf osConfig.mySystem.gaming.enable {
  programs.mangohud.enable = true;
  programs.vesktop.enable = true;

  home.packages = with pkgs; [
    faugus-launcher
    goverlay
    heroic
    protonplus
    r2modman
  ];
}
