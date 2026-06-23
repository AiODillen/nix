{ pkgs, inputs, vars, ... }:
let
  # GPU-vendor-aware nixGL wrappers (Mesa vs NVIDIA), shared with niri.nix.
  nixgl = import ../nixgl.nix { inherit pkgs inputs vars; };
in
{
  home.packages = [
    nixgl.gl         # run nix OpenGL apps as `${nixgl.glName} <app>`
    nixgl.vulkan     # run nix Vulkan apps as `${nixgl.vulkanName} <app>`
  ];

  # gram is a Zed-based editor (GPUI → Vulkan). Its own .desktop runs `gram`
  # unwrapped, which panics with "no suitable graphics adapter" on non-NixOS.
  # Override the entry (same id → shadows the package one) to launch wrapped.
  xdg.desktopEntries."app.liten.Gram" = {
    name = "Gram";
    genericName = "Text Editor";
    comment = "A code editor for humanoid apes and grumpy toads";
    exec = "${nixgl.vulkanExe} gram %U";
    icon = "app.liten.Gram";
    terminal = false;
    startupNotify = true;
    categories = [ "Utility" "TextEditor" "Development" "IDE" ];
    mimeType = [ "text/plain" "application/x-zerosize" "x-scheme-handler/gram" ];
    settings.StartupWMClass = "app.liten.Gram";
  };

  # Terminal convenience: `gram` from a shell also goes through the shim.
  programs.fish.shellAliases.gram = "${nixgl.vulkanExe} gram";
}
