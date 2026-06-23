# UNIMPORTED: still uses the old mySystem schema. Not imported by this machine
# (feature off). Convert config.mySystem / osConfig.mySystem refs to `vars` before
# re-importing — vars.nix already carries gamescope / rocmGfx / storageMounts.
{ config, lib, pkgs, ... }:
let
  cfg = config.mySystem;
in
lib.mkIf cfg.localAi.enable {
  hardware.graphics.extraPackages = [ pkgs.rocmPackages.clr ];

  users.users.${cfg.user.name}.extraGroups = [ "render" "video" ];

  services.ollama = {
    enable = true;
    package = pkgs.ollama-rocm;
    rocmOverrideGfx = cfg.localAi.rocmGfx;
    host = "127.0.0.1";
    port = 11434;
  };

  services.open-webui = {
    enable = true;
    host = "127.0.0.1";
    port = 8080;
    environment = {
      OLLAMA_BASE_URL = "http://127.0.0.1:11434";
      WEBUI_AUTH = "False";
    };
  };

  environment.systemPackages = with pkgs; [
    rocmPackages.rocminfo
    rocmPackages.rocm-smi
  ];
}
