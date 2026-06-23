# Laptop (Mint, standalone home-manager) — all config values for this machine.
# Plain attrset, imported by flake.nix and threaded to profiles as `vars`.
{
  user = "niklas";
  homeDirectory = "/home/niklas";
  gpu = "mesa";                 # "mesa" (Intel/AMD) | "nvidia" — picks the nixGL wrapper
  flakePath = "~/Documents/nix";

  scheme = "monokai";
  polarity = "dark";
  wallpaper = ./wallpaper.png;

  localeMain = "en_US.UTF-8";
  localeRegional = "de_DE.UTF-8";
  xkbLayout = "de";
  xkbVariant = "nodeadkeys";
}
