{ lib, osConfig, ... }:
lib.mkIf osConfig.mySystem.theming.enable {
  stylix.targets.firefox.enable = true;
  stylix.targets.mangohud.enable = true;
  stylix.targets.qt.enable = true;
  stylix.targets.vesktop.enable = true;
}
