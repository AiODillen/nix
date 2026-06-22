# ═══════════════════════════════════════════════════════════════════════════
#                       ⮞⮞  SHARED SETTINGS — EDIT HERE  ⮜⮜
#   The one file for everything that is NOT device-specific. Both machines
#   (the NixOS PC and the standalone laptop) read these values. Device-specific
#   config lives per machine under machines/<name>/.
#
#   Shared here:   theming, locale (incl. keyboard layout), timezone. The
#                  desktop *config* (niri keybinds/config.kdl, gnome, waybar) is
#                  also shared, in profiles/desktop/.
#   Per-device:    desktop *choice* (niri/gnome), ai/gaming feature toggles,
#                  identity, hostname, kernel, hardware, gpu, monitors, mounts,
#                  gamescope resolution, localAi GPU target — see machines/.
# ═══════════════════════════════════════════════════════════════════════════
{ ... }:
{
  mySystem = {
    timezone = "Europe/Berlin";

    locale = {
      main = "en_US.UTF-8";
      regional = "de_DE.UTF-8";
      consoleKeymap = "de-latin1-nodeadkeys";
      xkbLayout = "de";
      xkbVariant = "nodeadkeys";
    };

    theming = {
      enable = true;
      # ┌─ Available schemes (pkgs.base16-schemes) ───────────────────────────┐
      # │ scheme name                       │ polarity                        │
      # ├───────────────────────────────────┼─────────────────────────────────┤
      # │ catppuccin-mocha                  │ dark                            │
      # │ catppuccin-macchiato              │ dark                            │
      # │ catppuccin-frappe                 │ dark                            │
      # │ catppuccin-latte                  │ light                           │
      # │ gruvbox-dark-hard                 │ dark                            │
      # │ gruvbox-dark-medium               │ dark                            │
      # │ gruvbox-dark-soft                 │ dark                            │
      # │ gruvbox-material-dark-hard        │ dark                            │
      # │ gruvbox-light-hard                │ light                           │
      # │ gruvbox-light-medium              │ light                           │
      # │ nord                              │ dark                            │
      # │ nord-light                        │ light                           │
      # │ dracula                           │ dark                            │
      # │ tokyo-night-dark                  │ dark                            │
      # │ tokyo-night-storm                 │ dark                            │
      # │ tokyo-night-moon                  │ dark                            │
      # │ tokyo-night-light                 │ light                           │
      # │ rose-pine                         │ dark                            │
      # │ rose-pine-moon                    │ dark                            │
      # │ rose-pine-dawn                    │ light                           │
      # │ kanagawa                          │ dark                            │
      # │ kanagawa-dragon                   │ dark                            │
      # │ everforest                        │ dark                            │
      # │ everforest-dark-hard              │ dark                            │
      # │ everforest-dark-medium            │ dark                            │
      # │ everforest-dark-soft              │ dark                            │
      # │ onedark                           │ dark                            │
      # │ onedark-dark                      │ dark                            │
      # │ ayu-dark                          │ dark                            │
      # │ ayu-mirage                        │ dark                            │
      # │ ayu-light                         │ light                           │
      # │ solarized-dark                    │ dark                            │
      # │ solarized-light                   │ light                           │
      # │ material                          │ dark                            │
      # │ material-darker                   │ dark                            │
      # │ material-palenight                │ dark                            │
      # │ material-lighter                  │ light                           │
      # │ monokai                           │ dark                            │
      # │ gotham                            │ dark                            │
      # └───────────────────────────────────┴─────────────────────────────────┘
      # Full list: ls ${pkgs.base16-schemes}/share/themes/
      scheme = "monokai";
      polarity = "dark"; # "dark" | "light" | "either" — must match scheme
      # wallpaper = ./wallpaper.png;
    };
  };
}
