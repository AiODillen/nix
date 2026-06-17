{ config, lib, pkgs, ... }:
lib.mkIf config.mySystem.localAi.enable {
  # ROCm OpenCL runtime — exposes GPU to compute workloads (llama.cpp, ollama, etc.)
  hardware.graphics.extraPackages = [ pkgs.rocmPackages.clr ];

  # GPU device nodes require membership in these groups
  users.users.dillen.extraGroups = [ "render" "video" ];

  # Ollama: LLM inference server with ROCm acceleration.
  # 7900 XTX = NAVI31 = gfx1100 — officially supported, override ensures detection.
  services.ollama = {
    enable = true;
    package = pkgs.ollama-rocm;
    rocmOverrideGfx = "11.0.0";
    host = "127.0.0.1";
    port = 11434;
  };

  # Open WebUI: full-featured chat UI over ollama's API, served locally.
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
    rocmPackages.rocminfo  # verify GPU is detected by ROCm
    rocmPackages.rocm-smi  # monitor GPU utilisation during inference
  ];
}
