# Chromium web apps (Teams, Outlook) on the laptop. Each is an app-mode
# Chromium window sharing the default profile + Proton Pass; see
# machines/_webapps-lib.nix.
#
# Proton Pass is installed via HM's External Extensions mechanism
# (creates ~/.config/chromium/External Extensions/<id>.json) — this is the
# only user-level extension install that standard Chromium respects on Linux.
{ config, pkgs, lib, ... }:
{
  programs.chromium = {
    enable = true;
    extensions = [
      { id = "ghmbeldphafepmbegfdlkpapadhbakde"; }   # Proton Pass
    ];
  };
}
// (import ../../_webapps-lib.nix { inherit lib; }).hmConfig {
  chromiumBin = "${config.programs.chromium.package}/bin/chromium";
}
