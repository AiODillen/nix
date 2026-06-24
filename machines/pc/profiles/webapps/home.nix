# Firefox web apps (Teams, Outlook) on the pc. Dedicated Firefox profile +
# chromeless window + distinct niri app-id per app; see machines/_webapps-lib.nix.
# Extensions come from the global Firefox policies (core/nixos.nix), which apply
# to all profiles. The launcher execs `firefox` from PATH (the NixOS system
# Firefox), which reads the HM-managed profile in ~/.mozilla/firefox.
{ lib, ... }:
(import ../../../_webapps-lib.nix { inherit lib; }).hmConfig {
  firefoxBin = "firefox";
}
