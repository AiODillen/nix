{ lib, pkgs, settings, ... }:
lib.mkIf settings.theming {
  stylix = {
    enable = true;
    polarity = settings.polarity;
    image = settings.wallpaper;

    base16Scheme = "${pkgs.base16-schemes}/share/themes/${settings.scheme}.yaml";

    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font Mono";
      };
      sansSerif = {
        package = pkgs.inter;
        name = "Inter";
      };
      serif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Serif";
      };
      sizes = {
        applications = 12;
        terminal = 13;
        desktop = 11;
        popups = 11;
      };
    };

    targets.fish.enable = true;
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
