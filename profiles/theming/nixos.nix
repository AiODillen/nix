{ config, lib, pkgs, ... }:
lib.mkIf config.mySystem.theming.enable {
  # Disable kmscon entirely to avoid conflicts with Stylix in nixpkgs 26.05.
  # Stylix's kmscon module tries to set services.kmscon.config which no longer
  # exists; the matching disabledModules entry lives in hosts/nixos/default.nix.
  services.kmscon.enable = false;

  stylix = {
    enable = true;
    polarity = "dark";

    base16Scheme = {
      system = "base16";
      name = "Catppuccin Mocha";
      author = "https://github.com/catppuccin/catppuccin";
      variant = "dark";
      palette = {
        base00 = "1e1e2e";
        base01 = "181825";
        base02 = "313244";
        base03 = "45475a";
        base04 = "585b70";
        base05 = "cdd6f4";
        base06 = "f5c2e7";
        base07 = "b4befe";
        base08 = "f38ba8";
        base09 = "fab387";
        base0A = "f9e2af";
        base0B = "a6e3a1";
        base0C = "94e2d5";
        base0D = "89b4fa";
        base0E = "cba6f7";
        base0F = "f2cdcd";
      };
    };

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
    targets.gnome.enable = config.mySystem.desktop == "gnome";
  };
}
