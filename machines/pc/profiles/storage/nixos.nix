# Automounts under /home/<user> from vars.storageMounts. Imported only when
# vars.modules.storage = true (gated in machines/pc/default.nix), so no enable
# guard here. Each mount: { path, uuid, fsType }.
{ lib, vars, ... }:
{
  fileSystems = lib.listToAttrs (map (m: {
    name = "/home/${vars.user}/${m.path}";
    value = {
      device = "/dev/disk/by-uuid/${m.uuid}";
      fsType = m.fsType;
      options = [ "nofail" "x-systemd.automount" "x-systemd.idle-timeout=600" ];
    };
  }) vars.storageMounts);
}
