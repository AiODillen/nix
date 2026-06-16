{ config, lib, pkgs, ... }:
lib.mkIf config.mySystem.ai.enable {
  programs.nix-ld.enable = true;

  environment.systemPackages = with pkgs; [
    claude-code
    rtk
    nodejs
  ];
}
