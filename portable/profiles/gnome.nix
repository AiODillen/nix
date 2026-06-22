{ lib, settings, ... }:
lib.mkIf (settings.desktop == "gnome") {
  # GNOME itself is a full DE installed via the distro, not home-manager.
  # This only sets the dark-mode preference; harmless when gnome is absent.
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };
}
