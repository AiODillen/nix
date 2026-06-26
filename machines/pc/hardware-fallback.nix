# Fallback hardware module — used ONLY when /etc/nixos/hardware-configuration.nix
# is absent (evaluating this config from another machine, or `nix flake check` on
# a non-NixOS dev box). It provides the bare minimum to satisfy NixOS module eval
# (a root + boot filesystem) and is NEVER used to boot a real machine. The actual
# PC reads its live hardware scan via --impure — see machines/pc/default.nix.
{ lib, ... }:
{
  fileSystems."/" = {
    device = "/dev/disk/by-label/PLACEHOLDER-ROOT";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/PLACEHOLDER-BOOT";
    fsType = "vfat";
  };
  boot.initrd.availableKernelModules = lib.mkDefault [ ];
}
