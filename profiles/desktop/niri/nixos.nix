{ config, lib, pkgs, ... }:
lib.mkIf (config.mySystem.desktop == "niri") {
  programs.niri = {
    enable = true;
    useNautilus = true;
  };

  # xwayland-satellite provides on-demand XWayland support for niri (>= 25.08).
  # Niri detects it in $PATH and automatically exports $DISPLAY, which is
  # required for X11 apps such as Steam to start correctly.
  environment.systemPackages = [
    pkgs.xwayland-satellite
    pkgs.nautilus
    pkgs.gnome-disk-utility
    pkgs.pavucontrol
  ];

  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${config.programs.niri.package}/bin/niri-session";
      user = config.mySystem.user.name;
    };
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
    config.niri.default = [ "gnome" "gtk" ];
  };

  services.flatpak.enable = true;

  programs.appimage = {
    enable = true;
    binfmt = true;
    package = pkgs.appimage-run.override {
      extraPkgs = p: [ p.icu ];
    };
  };
}
