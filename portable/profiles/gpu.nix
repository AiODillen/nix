{ pkgs, inputs, ... }:
let
  # nixGL Mesa shims — non-NixOS has no /run/opengl-driver, so nix GL/Vulkan
  # apps can't find the system driver. "Intel" is a misnomer: these are the
  # Mesa wrappers and cover AMD/Intel.
  nixgl = inputs.nixgl.packages.${pkgs.stdenv.hostPlatform.system};
  nixGLIntel = nixgl.nixGLIntel;
  nixVulkanIntel = nixgl.nixVulkanIntel;
in
{
  home.packages = [
    nixGLIntel       # run nix OpenGL apps as `nixGLIntel <app>`
    nixVulkanIntel   # run nix Vulkan apps as `nixVulkanIntel <app>`
  ];

  # gram is a Zed-based editor (GPUI → Vulkan). Its own .desktop runs `gram`
  # unwrapped, which panics with "no suitable graphics adapter" on non-NixOS.
  # Override the entry (same id → shadows the package one) to launch wrapped.
  xdg.desktopEntries."app.liten.Gram" = {
    name = "Gram";
    genericName = "Text Editor";
    comment = "A code editor for humanoid apes and grumpy toads";
    exec = "${nixVulkanIntel}/bin/nixVulkanIntel gram %U";
    icon = "app.liten.Gram";
    terminal = false;
    startupNotify = true;
    categories = [ "Utility" "TextEditor" "Development" "IDE" ];
    mimeType = [ "text/plain" "application/x-zerosize" "x-scheme-handler/gram" ];
    settings.StartupWMClass = "app.liten.Gram";
  };

  # Terminal convenience: `gram` from a shell also goes through the shim.
  programs.fish.shellAliases.gram = "${nixVulkanIntel}/bin/nixVulkanIntel gram";
}
