# NixOS user's home-manager config. Self-contained: imports this machine's home
# profiles + helper modules. Receives `vars` via home-manager.extraSpecialArgs.
{ vars, lib, ... }:
let
  m = vars.modules;
in
{
  # Base profiles always imported; optional ones gated by vars.modules
  # (must mirror the system-side gating in machines/pc/default.nix).
  imports =
    [
      ./firefox-profile.nix
      ./profiles/core/home.nix
      ./profiles/shell/home.nix
    ]
    ++ lib.optionals m.theming [ ./profiles/theming/home.nix ./profiles/theming/gram.nix ]
    ++ lib.optionals m.desktop [ ./profiles/desktop/niri/home.nix ./monitors.nix ]
    ++ lib.optional m.webapps ./profiles/webapps/home.nix
    ++ lib.optional m.gaming ./profiles/gaming/home.nix
    ++ lib.optional m.ai ./profiles/ai/home.nix;

  home.username = vars.user;
  home.homeDirectory = "/home/${vars.user}";
  home.stateVersion = "26.05";
}
