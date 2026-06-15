{ lib, osConfig, ... }:
lib.mkIf (osConfig.mySystem.desktop == "gnome") {
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };
}
