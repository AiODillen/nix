# Firefox PWAs (Teams, Outlook) on the laptop (standalone HM, non-NixOS).
# - firefoxpwa on PATH (connector + CLI; runtime is baked into the package).
# - Native-messaging host manifest hand-placed in the per-user dir, because a
#   non-NixOS Firefox has no nativeMessagingHosts wrapper. Every Firefox build
#   scans ~/.mozilla/native-messaging-hosts/.
# - Browser extension force-installed via Firefox policy (merges with the
#   policies in profiles/theming.nix).
# - Idempotent site install on activation (see machines/_webapps-lib.nix).
{ config, lib, pkgs, ... }:
let
  webappsLib = import ../../_webapps-lib.nix { inherit lib; };
  addons = pkgs.nur.repos.rycee.firefox-addons;
in
{
  home.packages = [ pkgs.firefoxpwa ];

  home.file.".mozilla/native-messaging-hosts/firefoxpwa.json".source =
    "${pkgs.firefoxpwa}/lib/mozilla/native-messaging-hosts/firefoxpwa.json";

  programs.firefox.policies.ExtensionSettings."firefoxpwa@filips.si" = {
    installation_mode = "force_installed";
    install_url = "file://${addons.pwas-for-firefox}/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}/firefoxpwa@filips.si.xpi";
  };

  home.activation.installWebapps =
    lib.hm.dag.entryAfter [ "installPackages" ]
      (webappsLib.installScript { firefoxpwa = pkgs.firefoxpwa; });
}
