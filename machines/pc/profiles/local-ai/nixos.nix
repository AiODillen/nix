# ROCm Ollama + open-webui. Imported only when vars.modules.localAi = true
# (gated in machines/pc/default.nix), so no enable guard here.
{ pkgs, vars, ... }:
{
  hardware.graphics.extraPackages = [ pkgs.rocmPackages.clr ];

  users.users.${vars.user}.extraGroups = [ "render" "video" ];

  services.ollama = {
    enable = true;
    package = pkgs.ollama-rocm;
    rocmOverrideGfx = vars.rocmGfx;
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
