{ lib, osConfig, ... }:
lib.mkIf osConfig.mySystem.theming.enable {
  programs.firefox = {
    enable = true;
    # Pin legacy path: HM 26.05 would otherwise write to
    # ~/.config/mozilla/firefox, which Firefox ignores. See
    # template/profiles/theming.nix for the full rationale.
    configPath = ".mozilla/firefox";
    # See template/profiles/theming.nix for the rationale. `extensions.force` is
    # required by stylix colorTheme and is safe (it only overwrites FirefoxColor
    # data, not installed extensions or logins). The profile-repoint wipe risk is
    # handled by ../../modules/home/firefox-profile.nix.
    profiles.default = {
      isDefault = true;
      extensions.force = true;
      settings = {
        "extensions.autoDisableScopes" = 0;
      };
    };
  };
  stylix.targets.firefox = {
    enable = true;
    profileNames = [ "default" ];
    colorTheme.enable = true;
  };
  stylix.targets.mangohud.enable = true;
  stylix.targets.qt.enable = true;
  stylix.targets.vesktop.enable = true;
}
