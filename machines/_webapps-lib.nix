# Shared definition of the Firefox-backed web apps (Teams, Outlook) and the
# Home Manager config that turns each into a site-specific "app":
#
#   - a dedicated Firefox profile per app (own cookies/login), chromeless via
#     userChrome (no tab strip, no nav toolbar) for an app-like window;
#   - a .desktop launcher that runs Firefox on that profile with a distinct
#     Wayland app-id (--class/--name = the app id), so niri sees each app as
#     its own window (verified: `firefox --class X` => niri App ID "X").
#
# Extensions (uBlock, Proton Pass, …) come from the GLOBAL
# `programs.firefox.policies.ExtensionSettings` already set on each machine —
# policies apply to every profile, so these app profiles get them for free.
# You log into each app once in its profile (separate session from the main
# Firefox profile — that is the trade-off for a clean app window).
#
# `hmConfig { firefoxBin }` returns the HM config (profiles + desktop entries);
# `firefoxBin` is the absolute firefox to exec (defaults to PATH `firefox`).
{ lib }:
let
  webapps = [
    { id = "teams"; name = "Microsoft Teams"; url = "https://teams.microsoft.com/"; profileId = 1; }
    { id = "outlook"; name = "Outlook"; url = "https://outlook.office.com/mail/"; profileId = 2; }
  ];

  # Hide the tab strip and the navigation toolbar for the app feel. Requires
  # the legacy stylesheet pref (set per-profile below).
  userChrome = ''
    #TabsToolbar { visibility: collapse !important; }
    #nav-bar { visibility: collapse !important; }
  '';

  mkProfile = app: lib.nameValuePair app.id {
    id = app.profileId;
    isDefault = false;
    settings = {
      "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
    };
    userChrome = userChrome;
  };

  mkDesktop = firefoxBin: app: lib.nameValuePair "webapp-${app.id}" {
    name = app.name;
    genericName = "Web App";
    # --no-remote forces a separate instance on this app's profile (not a new
    # window in the main Firefox); --class/--name set the Wayland app-id.
    exec = "${firefoxBin} -P ${app.id} --class ${app.id} --name ${app.id} --no-remote ${app.url}";
    terminal = false;
    startupNotify = true;
    settings.StartupWMClass = app.id;
    categories = [ "Network" ];
  };

  hmConfig = { firefoxBin ? "firefox" }: {
    programs.firefox.profiles = lib.listToAttrs (map mkProfile webapps);
    xdg.desktopEntries = lib.listToAttrs (map (mkDesktop firefoxBin) webapps);
  };
in
{
  inherit webapps userChrome hmConfig;
}
