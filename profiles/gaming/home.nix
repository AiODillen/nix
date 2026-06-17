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

  xdg.desktopEntries.steam-gamescope = {
    name = "Steam (Gamescope)";
    exec = "${pkgs.libcap}/bin/capsh --clear=a -- -c steam-gamescope";
    icon = "steam";
    comment = "Steam via Gamescope — all games run inside gamescope";
    categories = [ "Game" ];
  };
}
