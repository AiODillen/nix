{ config, lib, ... }:
lib.mkIf config.mySystem.gaming.enable {
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = false;
    gamescopeSession = {
      enable = true;
      args = [
        "-W" "3440" "-H" "1440"
        "-r" "175"
        "-f"
        "--adaptive-sync"
        "-F" "fsr"
        "--sharpness" "5"
        "--rt"
        "--expose-wayland"
        "--xwayland-count" "2"
        "--mangoapp"
      ];
    };
  };

  programs.gamescope = {
    enable = true;
    capSysNice = true;
    env = {
      XKB_DEFAULT_LAYOUT = "de";
    };
  };

  hardware.steam-hardware.enable = true;
}
