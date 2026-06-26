# AI tooling (claude-code, rtk, node + nix-ld for native addons). Imported only
# when vars.modules.ai = true (gated in machines/pc/default.nix), no guard here.
{ pkgs, ... }:
{
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
