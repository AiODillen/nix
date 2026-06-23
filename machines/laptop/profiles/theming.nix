{ pkgs, lib, vars, ... }:
let
  # Resolve a "foo.bar" nixpkgs attr path (from vars.fonts) to the package.
  font = f: { package = lib.getAttrFromPath (lib.splitString "." f.package) pkgs; inherit (f) name; };
in
{
  stylix = {
    enable = true;
    polarity = vars.polarity;
    image = vars.wallpaper;

    base16Scheme = "${pkgs.base16-schemes}/share/themes/${vars.scheme}.yaml";

    fonts = {
      monospace = font vars.fonts.monospace;
      sansSerif = font vars.fonts.sansSerif;
      serif = font vars.fonts.serif;
      sizes = vars.fonts.sizes;
    };

    targets.fish.enable = true;
    targets.mako.enable = true;
    targets.firefox = {
      enable = true;
      profileNames = [ "default" ];
      colorTheme.enable = true;
    };
    targets.mangohud.enable = true;
    targets.qt.enable = true;
    targets.vesktop.enable = true;
  };

  programs.firefox = {
    enable = true;
    # HM 26.05 defaults firefox config to the XDG path
    # ($XDG_CONFIG_HOME/mozilla/firefox) for stateVersion >= 26.05, but Firefox
    # itself still reads ~/.mozilla/firefox — so the default would write profile
    # data (theming, prefs) to a dir Firefox ignores. Pin the legacy path so HM
    # manages the real profile dir. (Also silences the 26.05 migration warning.)
    configPath = ".mozilla/firefox";
    # Profile dir is the fixed name "default" (HM default = attr name) on every
    # machine, so this is portable — no per-device random profile id. Installed
    # extensions come from policies.ExtensionSettings below (same on all
    # machines); HM only manages a profile's extensions/ dir when
    # `extensions.packages` is set (it isn't here), so it never prunes manually-
    # installed add-ons. `extensions.force` is required because stylix's
    # colorTheme injects an `extensions.settings` entry (FirefoxColor); force
    # only lets HM overwrite that one extension's browser-extension-data — it
    # does not touch logins or other extensions' state (e.g. Proton Pass vault,
    # which lives under storage/default/). The real wipe risk — HM repointing
    # Firefox at an empty "default" dir on a machine whose data is in a random-
    # named profile — is handled by ../firefox-profile.nix,
    # which adopts the existing profile on first activation.
    profiles.default = {
      isDefault = true;
      extensions.force = true;
      settings = {
        "extensions.autoDisableScopes" = 0;
      };
    };
    # Merged from the NixOS core + theming firefox policies.
    policies.ExtensionSettings =
      let
        addons = pkgs.nur.repos.rycee.firefox-addons;
        wj = "{ec8030f7-c20a-464f-9b0e-13a3a9e97384}";
      in
      {
        "FirefoxColor@mozilla.com" = {
          installation_mode = "force_installed";
          install_url = "file://${addons.firefox-color}/share/mozilla/extensions/${wj}/FirefoxColor@mozilla.com.xpi";
        };
        "uBlock0@raymondhill.net" = {
          installation_mode = "force_installed";
          install_url = "file://${addons.ublock-origin}/share/mozilla/extensions/${wj}/uBlock0@raymondhill.net.xpi";
        };
        "78272b6fa58f4a1abaac99321d503a20@proton.me" = {
          installation_mode = "force_installed";
          install_url = "file://${addons.proton-pass}/share/mozilla/extensions/${wj}/78272b6fa58f4a1abaac99321d503a20@proton.me.xpi";
        };
      };
  };
}
