# Dynamic output switching for the laptop, via kanshi.
#
# Goal: when an external monitor is connected, show only the external; with no
# external connected, show only the laptop panel.
#
# niri implements wlr-output-management (since v0.1.8), so kanshi can drive its
# outputs at runtime. kanshi applies the FIRST profile whose listed outputs are
# all connected, so `docked` (needs both) must come before `mobile` (needs only
# the panel) — otherwise `mobile` would also match while docked.
#
# Outputs on this machine:
#   eDP-1     laptop panel    (1920x1200, scale 1.25)
#   HDMI-A-1  external 34"     (3440x1440, scale 1.0)
#
# Scales mirror the current live setup. kanshi binds to graphical-session.target
# (config.wayland.systemd.target), which the template's niri.service drives, so
# the kanshi user service starts inside the niri session.
{ ... }:
{
  services.kanshi = {
    enable = true;
    settings = [
      {
        profile.name = "docked";
        profile.outputs = [
          {
            criteria = "eDP-1";
            status = "disable";
          }
          {
            criteria = "HDMI-A-1";
            status = "enable";
            position = "0,0";
            scale = 1.0;
          }
        ];
      }
      {
        profile.name = "mobile";
        profile.outputs = [
          {
            criteria = "eDP-1";
            status = "enable";
            position = "0,0";
            scale = 1.25;
          }
        ];
      }
    ];
  };
}
