# Shared nixGL wrapper selection for the standalone (non-NixOS) profiles.
#
# A non-NixOS box has no /run/opengl-driver, so nix-built GL/Vulkan apps can't
# find the system driver ("no suitable graphics adapter"). nixGL wraps a program
# with the right libs. The wrapper pair depends on the machine's GPU vendor
# (settings.gpu), so both gpu.nix and niri.nix import this to stay in sync.
#
#   "mesa"   -> nixGLIntel / nixVulkanIntel  (Intel + AMD; "Intel" is a misnomer)
#   "nvidia" -> nixGLNvidia / nixVulkanNvidia (proprietary driver; unfree, pinned
#               to the host driver version)
#
# Returns the two wrapper packages plus their executable paths/names (the bin
# is named after the attr, which differs per vendor).
{ pkgs, inputs, settings }:
let
  nixgl = inputs.nixgl.packages.${pkgs.stdenv.hostPlatform.system};
  glName = if settings.gpu == "nvidia" then "nixGLNvidia" else "nixGLIntel";
  vulkanName = if settings.gpu == "nvidia" then "nixVulkanNvidia" else "nixVulkanIntel";
  gl = nixgl.${glName};
  vulkan = nixgl.${vulkanName};
in
{
  inherit gl vulkan glName vulkanName;
  glExe = "${gl}/bin/${glName}";
  vulkanExe = "${vulkan}/bin/${vulkanName}";
}
