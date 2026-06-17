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
