{ pkgs, ... }:
{
  programs.mangohud.enable = true;
  programs.vesktop.enable = true;

  # Steam + the gamescope wrapper need system-level config; install Steam via
  # the distro. Only the portable home apps are included here.
  home.packages = with pkgs; [
    faugus-launcher
    goverlay
    heroic
    lact
    protonplus
    r2modman
  ];
}
