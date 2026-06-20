{ config, lib, ... }:
let
  cfg = config.mySystem;
  user = cfg.user.name;
in
lib.mkIf cfg.storage.automount.enable {
  fileSystems = lib.listToAttrs (map (m: {
    name = "/home/${user}/${m.path}";
    value = {
      device = "/dev/disk/by-uuid/${m.uuid}";
      fsType = m.fsType;
      options = [ "nofail" "x-systemd.automount" "x-systemd.idle-timeout=600" ];
    };
  }) cfg.storage.automount.mounts);
}
