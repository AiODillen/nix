# Firefox web apps (Teams, Outlook) on the pc. Dedicated Firefox profile +
# chromeless window + distinct niri app-id per app; see machines/_webapps-lib.nix.
# Firefox is HM-managed (package + policies + profiles), same as the laptop, so
# exec the HM finalPackage — it carries the extension policies, so the app
# windows get uBlock / Proton Pass like every other profile.
{ config, lib, ... }:
(import ../../../_webapps-lib.nix { inherit lib; }).hmConfig {
  firefoxBin = "${config.programs.firefox.finalPackage}/bin/firefox";
}
