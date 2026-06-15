{ config, lib, ... }:
lib.mkIf (config.mySystem.desktop == "gnome") {
  services.xserver = {
    enable = true;
    xkb = {
      layout = "de";
      variant = "nodeadkeys";
    };
    desktopManager.gnome.enable = true;
    displayManager.gdm.enable = true;
  };
}
