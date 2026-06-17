{ lib, ... }:
{
  options.mySystem = {
    desktop = lib.mkOption {
      type = lib.types.enum [
        "niri"
        "gnome"
      ];
      default = "niri";
      description = "Which desktop environment to enable. Change and run nixos-rebuild switch.";
    };

    ai.enable = lib.mkEnableOption "AI profile (Claude Code, rtk, codegraph, caveman, repomix)";

    gaming.enable = lib.mkEnableOption "gaming profile (Steam, gamescope, gaming home apps)";

    localAi.enable = lib.mkEnableOption "local AI profile (Ollama ROCm, Open WebUI, ROCm tools)";

    theming.enable = lib.mkEnableOption "stylix theming profile (system + home)";

    storage.automount.enable = lib.mkEnableOption "automount profile (extra filesystems under /home/dillen)";
  };
}
