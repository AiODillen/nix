# Per-device monitor config for the main PC (NixOS).
#
# Device-specific data lives here, not in the shared mySystem options. The
# schema + kanshi build come from the shared module; this file only supplies
# this machine's profiles. Imported by the NixOS user's home-manager config
# (users/home.nix).
#
# kanshi only works under niri (GNOME/mutter has no wlr-output-management), so
# `enable` is gated on the niri desktop — on GNOME this is inert and GNOME
# manages displays itself.
#
# No profiles are defined yet: with fallbackAllOn (default) every connected
# output is simply enabled. To pin modes/refresh/VRR/layout, run
# `niri msg outputs` on the PC and fill in `profiles` like the laptop's file.
{
  lib,
  osConfig,
  ...
}:
{
  imports = [ ../../modules/home/monitors.nix ];

  monitors = {
    enable = osConfig.mySystem.desktop == "niri";
    fallbackAllOn = true;
    profiles = [
      # Example (replace connectors with `niri msg outputs` on the PC):
      # {
      #   name = "desk";
      #   outputs = [
      #     {
      #       connector = "DP-1";
      #       status = "enable";
      #       position = "0,0";
      #       mode = "3440x1440@100Hz";  # refresh rate is the @<rate>Hz part
      #       adaptiveSync = true;       # VRR
      #     }
      #   ];
      # }
    ];
  };
}
