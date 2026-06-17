{ config, lib, ... }:
lib.mkIf config.mySystem.storage.automount.enable {
  fileSystems."/home/dillen/Grab" = {
    device = "/dev/disk/by-uuid/b7139bdc-09fd-4008-9ab2-243eb5aacc05";
    fsType = "ext4";
    options = [ "nofail" "x-systemd.automount" "x-systemd.idle-timeout=600" ];
  };

  fileSystems."/home/dillen/Games_Part" = {
    device = "/dev/disk/by-uuid/9171c17f-e154-41f4-87ac-69a020fbebbd";
    fsType = "ext4";
    options = [ "nofail" "x-systemd.automount" "x-systemd.idle-timeout=600" ];
  };
}
