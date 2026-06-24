# Firefox web apps (Teams, Outlook) on the laptop. Each is a dedicated Firefox
# profile + chromeless window + distinct niri app-id; see machines/_webapps-lib.nix.
# Extensions come from the global policies in profiles/theming.nix (apply to all
# profiles). Firefox here is the HM-managed package (finalPackage).
{ config, lib, ... }:
(import ../../_webapps-lib.nix { inherit lib; }).hmConfig {
  firefoxBin = "${config.programs.firefox.finalPackage}/bin/firefox";
}
