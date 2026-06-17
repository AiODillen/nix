{ ... }:
{
  # System-level fish so it is a valid login shell and gets /etc/shells +
  # completion integration. User-level config lives in shell/home.nix.
  programs.fish.enable = true;
}
