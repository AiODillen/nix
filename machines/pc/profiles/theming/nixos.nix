{ pkgs, lib, vars, ... }:
let
  # Resolve a "foo.bar" nixpkgs attr path (from vars.fonts) to the package.
  font = f: { package = lib.getAttrFromPath (lib.splitString "." f.package) pkgs; inherit (f) name; };
  themeMenu = import ../../../../modules/theme-menu.nix;
in
{
  # Disable kmscon entirely to avoid conflicts with Stylix in nixpkgs 26.05.
  # Stylix's kmscon module sets services.kmscon.config which no longer exists;
  # matching disabledModules entry is in machines/pc/default.nix.
  # TODO: drop both once stylix release ≥ 26.05 ships the fix upstream.
  services.kmscon.enable = false;

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
    # This machine runs niri, not gnome.
    targets.gnome.enable = false;
  };

  # Prebuilt theme variants for the on-the-fly switcher (theme-switch / Mod+Shift+T).
  # NixOS specialisations inherit the parent config (inheritParentConfig defaults
  # true) and rebuild HM too, so coverage is full. Runtime-only: reverts to
  # vars.scheme on the next nixos-rebuild switch.
  specialisation = lib.listToAttrs (map (t: {
    inherit (t) name;
    value.configuration.stylix = {
      base16Scheme = lib.mkForce "${pkgs.base16-schemes}/share/themes/${t.name}.yaml";
      polarity = lib.mkForce t.polarity;
    };
  }) themeMenu);

  # Passwordless activation for theme-switch, scoped to switch-to-configuration
  # test only. Lets the picker activate a prebuilt specialisation without a
  # password; it cannot change what those configs contain without a (privileged)
  # rebuild. Using "test" (not "switch") keeps the system profile
  # /nix/var/nix/profiles/system stable (updated only on switch/boot), which
  # is the anchor used here so the specialisation tree is always populated.
  security.sudo.extraRules = [{
    users = [ vars.user ];
    commands = [
      { command = "/nix/var/nix/profiles/system/bin/switch-to-configuration test"; options = [ "NOPASSWD" ]; }
      { command = "/nix/var/nix/profiles/system/specialisation/*/bin/switch-to-configuration test"; options = [ "NOPASSWD" ]; }
    ];
  }];

  programs.firefox.policies.ExtensionSettings = {
    "FirefoxColor@mozilla.com" = {
      installation_mode = "force_installed";
      install_url = "file://${pkgs.nur.repos.rycee.firefox-addons.firefox-color}/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}/FirefoxColor@mozilla.com.xpi";
    };
  };
}
