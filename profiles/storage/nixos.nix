{ config, lib, ... }:
lib.mkIf config.mySystem.storage.automount.enable {
  fileSystems."/home/dillen/Grab" = {
    device = "/dev/sda1";
    fsType = "ext4";
    options = [ "nofail" "x-systemd.automount" "x-systemd.idle-timeout=600" ];
  };

  fileSystems."/home/dillen/Games_Part" = {
    device = "/dev/nvme0n1p3";
    fsType = "ext4";
    options = [ "nofail" "x-systemd.automount" "x-systemd.idle-timeout=600" ];
  };
}
