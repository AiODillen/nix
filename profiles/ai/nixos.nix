{ config, lib, pkgs, ... }:
lib.mkIf config.mySystem.ai.enable {
  environment.systemPackages = with pkgs; [
    claude-code
    rtk
    nodejs
  ];
}
