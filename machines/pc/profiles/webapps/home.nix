# Firefox web apps (Teams, Outlook) on the pc. Dedicated Firefox profile +
# chromeless window + distinct niri app-id per app; see machines/_webapps-lib.nix.
#
# Exec the NixOS SYSTEM Firefox by absolute path, NOT bare `firefox` and NOT
# the HM finalPackage: on pc the extension policies (uBlock, Proton Pass) are
# defined at the NixOS level (core/nixos.nix), so only the system Firefox at
# /run/current-system/sw/bin/firefox carries them. The HM `programs.firefox`
# here (theming/home.nix) has no policies and would shadow `firefox` on PATH,
# giving app windows with no extensions. Both binaries read the same
# HM-managed profiles in ~/.mozilla/firefox, so pinning the system one is safe.
{ lib, ... }:
(import ../../../_webapps-lib.nix { inherit lib; }).hmConfig {
  firefoxBin = "/run/current-system/sw/bin/firefox";
}
