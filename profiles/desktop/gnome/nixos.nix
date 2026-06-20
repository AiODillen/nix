{ config, lib, ... }:
lib.mkIf (config.mySystem.desktop == "gnome") {
  services.xserver = {
    enable = true;
    xkb = {
      layout = config.mySystem.locale.xkbLayout;
      variant = config.mySystem.locale.xkbVariant;
    };
    desktopManager.gnome.enable = true;
    displayManager.gdm.enable = true;
  };
}
