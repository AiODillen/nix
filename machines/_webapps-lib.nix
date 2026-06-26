# Shared definition of the Chromium-backed web apps (Teams, Outlook) and the
# Home Manager config that turns each into a site-specific "app":
#
#   - Chromium launches each app in app mode (`--app=<url>`) which removes all
#     browser chrome (tab strip, nav bar, address bar) for a native window.
#     All webapps share the default Chromium profile so they see the same
#     extensions (Proton Pass) and cookies.
#   - A .desktop launcher per app with a distinct Wayland app-id
#     (--class/--name = the app id), so niri sees each as its own window.
#
# Proton Pass is installed via the consumer's `programs.chromium.extensions`
# (External Extensions mechanism), **not** via policies — Chromium does not
# read user-level policies on Linux (only /etc/chromium/policies/managed/).
#
# `hmConfig { chromiumBin }` returns the HM config (desktop entries);
# `chromiumBin` defaults to PATH `chromium`.
{ lib }:
let
  webapps = [
    { id = "teams"; name = "Microsoft Teams"; url = "https://teams.microsoft.com/"; }
    { id = "outlook"; name = "Outlook"; url = "https://outlook.office.com/mail/"; }
  ];

  mkDesktop = chromiumBin: app: lib.nameValuePair "webapp-${app.id}" {
    name = app.name;
    genericName = "Web App";
    exec = "${chromiumBin} --app=${app.url} --class=${app.id} --name=${app.id}";
    terminal = false;
    startupNotify = true;
    settings.StartupWMClass = app.id;
    categories = [ "Network" ];
  };

  hmConfig = { chromiumBin ? "chromium" }: {
    xdg.desktopEntries = lib.listToAttrs (map (mkDesktop chromiumBin) webapps);
  };
in
{
  inherit webapps hmConfig;
}
