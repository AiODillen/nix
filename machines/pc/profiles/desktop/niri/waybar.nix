{ ... }:
{
  programs.waybar = {
    enable = true;
    settings = [
      {
        layer = "top";
        position = "top";
        height = 36;
        spacing = 4;
        "modules-left" = [ "niri/workspaces" ];
        # niri exposes only ext-foreign-toplevel-list (read-only), not the
        # wlr-foreign-toplevel-management protocol wlr/taskbar needs, so a real
        # taskbar is impossible. niri/window shows the focused window title.
        "modules-center" = [
          "niri/window"
          "clock"
        ];
        "modules-right" = [
          "pulseaudio"
          "power-profiles-daemon"
          "cpu"
          "memory"
          "tray"
        ];
        "niri/workspaces" = { };
        "niri/window" = {
          format = "{title}";
          max-length = 50;
          tooltip = false;
        };
        power-profiles-daemon = {
          format = "{profile}";
          tooltip-format = "Power profile: {profile}\nDriver: {driver}";
        };
        clock = {
          format = "{:%H:%M  %a %d}";
          tooltip = false;
        };
        cpu = {
          format = "CPU {usage}%";
          interval = 5;
        };
        memory = {
          format = "RAM {}%";
          interval = 10;
        };
        tray = {
          spacing = 8;
        };
        pulseaudio = {
          format = "VOL {volume}%";
          format-muted = "MUTE";
          # Left-click: open the wiremix TUI in a floating foot (app-id matched
          # by a niri window-rule). Right-click: mute toggle.
          on-click = "foot --app-id=audio-tui --window-size-chars=100x30 wiremix";
          on-click-right = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        };
      }
    ];
  };
}
