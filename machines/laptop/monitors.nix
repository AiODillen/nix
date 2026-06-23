# Per-device monitor config for the Mint laptop (standalone home-manager).
#
# Device-specific data lives here, not in the shared mySystem options. The
# schema + kanshi build come from the shared module; this file only supplies
# this machine's profiles and enables them when the desktop is niri (kanshi
# can't drive GNOME). Connector names from `niri msg outputs`.
{
  vars,
  ...
}:
{
  imports = [ ./_monitors-lib.nix ];

  monitors = {
    enable = true;
    fallbackAllOn = true;
    profiles = [
      {
        name = "docked";
        outputs = [
          {
            connector = "eDP-1";
            status = "disable";
          }
          {
            connector = "HDMI-A-1";
            status = "enable";
            position = "0,0";
            scale = 1.0;
            mode = "3440x1440@100Hz"; # set refresh rate here
            # adaptiveSync = true;       # VRR
          }
        ];
      }
      {
        name = "mobile";
        outputs = [
          {
            connector = "eDP-1";
            status = "enable";
            position = "0,0";
            scale = 1.25;
          }
        ];
      }
    ];
  };
}
