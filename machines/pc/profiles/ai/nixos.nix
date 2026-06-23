# UNIMPORTED: still uses the old mySystem schema. Not imported by this machine
# (feature off). Convert config.mySystem / osConfig.mySystem refs to `vars` before
# re-importing — vars.nix already carries gamescope / rocmGfx / storageMounts.
{ config, lib, pkgs, ... }:
lib.mkIf config.mySystem.ai.enable {
  programs.nix-ld.enable = true;
  # codegraph ships prebuilt native node addons (tree-sitter, better-sqlite3)
  # that dynamically link against these at runtime under nix-ld.
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    openssl
  ];

  environment.systemPackages = with pkgs; [
    claude-code
    rtk
    nodejs
  ];
}
