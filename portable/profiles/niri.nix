{ config, lib, pkgs, settings, ... }:
let
  colors = config.lib.stylix.colors;
  renderedKdl = lib.replaceStrings
    [ "@XKB_LAYOUT@" "@XKB_VARIANT@" "@BORDER_ACTIVE@" "@BORDER_INACTIVE@" ]
    [ settings.xkbLayout settings.xkbVariant "#${colors.base0E}" "#${colors.base01}" ]
    (builtins.readFile ../../profiles/desktop/niri/config.kdl);
in
{
  home.packages = with pkgs; [
    niri
    xwayland-satellite   # on-demand XWayland; niri exports $DISPLAY when present
    nautilus
    gnome-disk-utility
    pavucontrol
  ];

  xdg.configFile."niri/config.kdl".text = renderedKdl;

  # Wayland daemons (stylix themes these via its default targets).
  programs.foot.enable = true;
  programs.fuzzel.enable = true;
  services.mako.enable = true;

  programs.waybar = {
    enable = true;
    settings = [
      {
        layer = "top";
        position = "top";
        height = 30;
        spacing = 4;
        "modules-left" = [ "niri/workspaces" ];
        "modules-center" = [ "clock" ];
        "modules-right" = [ "pulseaudio" "cpu" "memory" "tray" ];
        "niri/workspaces" = { };
        clock = {
          format = "{:%H:%M  %a %d}";
          tooltip = false;
        };
        cpu = { format = "CPU {usage}%"; interval = 5; };
        memory = { format = "RAM {}%"; interval = 10; };
        tray = { spacing = 8; };
        pulseaudio = {
          format = "VOL {volume}%";
          format-muted = "MUTE";
          on-click = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        };
      }
    ];
  };

  # Make niri selectable in a distro display manager (greetd/portal/flatpak
  # are NixOS-only and provided by the distro on a non-NixOS box).
  xdg.dataFile."wayland-sessions/niri.desktop".text = ''
    [Desktop Entry]
    Name=Niri
    Comment=A scrollable-tiling Wayland compositor
    Exec=${pkgs.niri}/bin/niri-session
    Type=Application
  '';
}
