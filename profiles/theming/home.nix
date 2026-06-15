{ lib, osConfig, ... }:
lib.mkIf osConfig.mySystem.theming.enable {
  programs.firefox.enable = true;
  stylix.targets.firefox.enable = true;
  stylix.targets.mangohud.enable = true;
  stylix.targets.qt.enable = true;
  stylix.targets.vesktop.enable = true;
}
