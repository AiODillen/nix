# Firefox PWAs on the pc (NixOS). System Firefox is enabled in core/nixos.nix,
# so use the blessed NixOS mechanism: put firefoxpwa in PATH AND register it as
# a native-messaging host so the browser extension can detect the connector.
# The baked runtime is the nix Firefox (no download). Site install itself runs
# as the user in webapps/home.nix.
{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.firefoxpwa ];
  programs.firefox.nativeMessagingHosts.packages = [ pkgs.firefoxpwa ];

  programs.firefox.policies.ExtensionSettings."firefoxpwa@filips.si" = {
    installation_mode = "force_installed";
    install_url = "file://${pkgs.nur.repos.rycee.firefox-addons.pwas-for-firefox}/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}/firefoxpwa@filips.si.xpi";
  };
}
