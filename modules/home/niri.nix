{ lib, osConfig, ... }:
lib.mkIf (osConfig.mySystem.desktop == "niri") {

  xdg.configFile."niri/config.kdl".text = ''
    prefer-no-csd

    output "*" {
        variable-refresh-rate on-demand=true
    }

    input {
        keyboard {
            xkb {
                layout "de"
                variant "nodeadkeys"
            }
        }
        touchpad {
            tap
            natural-scroll
        }
        focus-follows-mouse
        warp-mouse-to-focus
    }

    layout {
        gaps 8

        focus-ring {
            width 2
            active-color "#cba6f7"
            inactive-color "#313244"
        }
    }

    spawn-at-startup "waybar"
    spawn-at-startup "mako"

    binds {
        Mod+T { spawn "foot"; }
        Mod+Space { spawn "fuzzel"; }
        Mod+Q { close-window; }
        Mod+Shift+E { quit; }
        Mod+F { maximize-column; }
        Mod+Shift+F { toggle-window-floating; }

        Mod+H { focus-column-left; }
        Mod+L { focus-column-right; }
        Mod+Shift+H { move-column-left; }
        Mod+Shift+L { move-column-right; }
        Mod+J { focus-window-down; }
        Mod+K { focus-window-up; }
        Mod+Shift+J { move-window-down; }
        Mod+Shift+K { move-window-up; }

        Mod+1 { focus-workspace 1; }
        Mod+2 { focus-workspace 2; }
        Mod+3 { focus-workspace 3; }
        Mod+4 { focus-workspace 4; }
        Mod+5 { focus-workspace 5; }
        Mod+6 { focus-workspace 6; }
        Mod+7 { focus-workspace 7; }
        Mod+8 { focus-workspace 8; }
        Mod+9 { focus-workspace 9; }

        Mod+Shift+1 { move-window-to-workspace 1; }
        Mod+Shift+2 { move-window-to-workspace 2; }
        Mod+Shift+3 { move-window-to-workspace 3; }
        Mod+Shift+4 { move-window-to-workspace 4; }
        Mod+Shift+5 { move-window-to-workspace 5; }
        Mod+Shift+6 { move-window-to-workspace 6; }
        Mod+Shift+7 { move-window-to-workspace 7; }
        Mod+Shift+8 { move-window-to-workspace 8; }
        Mod+Shift+9 { move-window-to-workspace 9; }

        XF86AudioRaiseVolume allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+"; }
        XF86AudioLowerVolume allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }
        XF86AudioMute allow-when-locked=true { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }

        Mod+WheelScrollDown { focus-column-right; }
        Mod+WheelScrollUp { focus-column-left; }
    }
  '';

  programs.foot.enable = true;

  programs.fuzzel.enable = true;

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
        "modules-right" = [
          "pulseaudio"
          "cpu"
          "memory"
          "tray"
        ];
        "niri/workspaces" = { };
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
          on-click = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        };
      }
    ];
  };

  services.mako.enable = true;
}
