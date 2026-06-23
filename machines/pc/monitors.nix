# Per-device monitor config for the main PC (NixOS).
#
# Device-specific data lives here. The schema + kanshi build come from the
# helper module (./_monitors-lib.nix); this file only supplies this machine's
# profiles. Imported by the NixOS user's home-manager config (home.nix).
#
# kanshi only works under niri (GNOME/mutter has no wlr-output-management).
# This machine always runs niri, so monitors are always enabled.
#
# No profiles are defined yet: with fallbackAllOn (default) every connected
# output is simply enabled. To pin modes/refresh/VRR/layout, run
# `niri msg outputs` on the PC and fill in `profiles` like the laptop's file.
{ ... }:
{
  imports = [ ./_monitors-lib.nix ];

  monitors = {
    enable = true;
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
