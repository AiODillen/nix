# Mint laptop — standalone home-manager, device-specific settings.
#
# Only this machine's device-specific values live here; everything shared
# (theming, locale, desktop, toggles) comes from ../../settings.nix. The flake
# evaluates the shared schema + settings + this file to derive the standalone
# home-manager settings — no NixOS system is built for the laptop.
{ ... }:
{
  # This machine's compositor choice. The desktop config (niri keybinds, gnome,
  # waybar) is shared in profiles/desktop/ — only the choice is per-device.
  mySystem.desktop = "niri"; # "niri" | "gnome"

  # Feature toggles for this machine.
  mySystem.ai.enable = false; # Claude Code, rtk, codegraph
  mySystem.gaming.enable = false; # gaming home apps (vesktop, heroic, ...)

  mySystem.standalone = {
    enable = true;
    user = "niklas";
    gpu = "mesa"; # "mesa" (Intel/AMD) | "nvidia" (proprietary driver) — picks the nixGL wrapper
    flakePath = "~/Documents/nix"; # repo location on this machine (used by the `rebuild` alias)
    # homeDirectory defaults to /home/<user>
  };
}
