{ pkgs, vars, ... }:
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
    # This machine runs niri, not gnome.
    targets.gnome.enable = false;
  };

  programs.firefox.policies.ExtensionSettings = {
    "FirefoxColor@mozilla.com" = {
      installation_mode = "force_installed";
      install_url = "file://${pkgs.nur.repos.rycee.firefox-addons.firefox-color}/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}/FirefoxColor@mozilla.com.xpi";
    };
  };
}
