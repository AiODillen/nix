{ config, lib, pkgs, ... }:
lib.mkIf config.mySystem.gaming.enable {
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = false;
  };

  programs.gamescope = {
    enable = true;
    capSysNice = true;
    env = {
      XKB_DEFAULT_LAYOUT = config.mySystem.locale.xkbLayout;
    };
  };

  # bubblewrap 0.11+ dropped setuid support; user namespaces work fine here.
  # The steam FHS wrapper hardcodes /run/wrappers/bin/bwrap so the wrapper
  # must exist, but it must NOT be setuid or bwrap refuses to run.
  security.wrappers.bwrap = lib.mkForce {
    owner = "root";
    group = "root";
    source = "${pkgs.bubblewrap}/bin/bwrap";
    setuid = false;
  };

  hardware.steam-hardware.enable = true;
  hardware.xone.enable = true;

  services.lact.enable = true;
  hardware.amdgpu.overdrive.enable = true;

  programs.coolercontrol.enable = true;
}
