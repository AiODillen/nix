{ ... }:
{
  programs.firefox = {
    enable = true;
    # Pin legacy path: HM 26.05 would otherwise write to
    # ~/.config/mozilla/firefox, which Firefox ignores. See
    # machines/laptop/profiles/theming.nix for the full rationale.
    configPath = ".mozilla/firefox";
    # See machines/laptop/profiles/theming.nix for the rationale. `extensions.force` is
    # required by stylix colorTheme and is safe (it only overwrites FirefoxColor
    # data, not installed extensions or logins). The profile-repoint wipe risk is
    # handled by ../../firefox-profile.nix.
    profiles.default = {
      isDefault = true;
      extensions.force = true;
      settings = {
        "extensions.autoDisableScopes" = 0;
      };
    };
  };
  stylix.targets.waybar.enable = true;
  stylix.targets.firefox = {
    enable = true;
    profileNames = [ "default" ];
    colorTheme.enable = true;
  };
  stylix.targets.mangohud.enable = true;
  stylix.targets.qt.enable = true;
  # No KDE Plasma / KDE-framework apps here (niri session) — disable the KDE
  # target so stylix stops pulling stylix-kde-{config,theme},
  # plasma-apply-theme and kwindowsystem. (auto-enables by default.)
  stylix.targets.kde.enable = false;
  stylix.targets.vesktop.enable = true;
}
