# Main PC (NixOS) — all config values for this machine. Plain attrset, imported
# by flake.nix and threaded to system + home modules as `vars`.
{
  hostname = "nixos";
  user = "dillen";
  fullName = "dillen";
  extraGroups = [ "networkmanager" "wheel" ];

  scheme = "monokai";
  polarity = "dark";
  wallpaper = ./wallpaper.png;

  timezone = "Europe/Berlin";
  localeMain = "en_US.UTF-8";
  localeRegional = "de_DE.UTF-8";
  consoleKeymap = "de-latin1-nodeadkeys";
  xkbLayout = "de";
  xkbVariant = "nodeadkeys";

  kernel = "default";

  gamescope = { width = 3440; height = 1440; };
  rocmGfx = "11.0.0";

  # Automounts under /home/<user>. Empty = none (matches current PC config).
  storageMounts = [ ];
}
