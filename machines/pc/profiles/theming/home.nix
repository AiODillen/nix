{ pkgs, ... }:
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
    # Force-installed extensions. Defined here (HM) — not at the NixOS level —
    # so the single HM-managed Firefox carries them on every profile, including
    # the webapp profiles (Teams/Outlook). Policies apply to all profiles.
    policies.ExtensionSettings = {
      "uBlock0@raymondhill.net" = {
        installation_mode = "force_installed";
        install_url = "file://${pkgs.nur.repos.rycee.firefox-addons.ublock-origin}/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}/uBlock0@raymondhill.net.xpi";
      };
      "78272b6fa58f4a1abaac99321d503a20@proton.me" = {
        installation_mode = "force_installed";
        install_url = "file://${pkgs.nur.repos.rycee.firefox-addons.proton-pass}/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}/78272b6fa58f4a1abaac99321d503a20@proton.me.xpi";
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
