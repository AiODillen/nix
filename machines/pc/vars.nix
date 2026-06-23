# Main PC (NixOS) — all config values for this machine. Plain attrset, imported
# by flake.nix and threaded to system + home modules as `vars`.
{
  hostname = "nixos";
  user = "dillen";
  fullName = "dillen";
  extraGroups = [ "networkmanager" "wheel" ];

  # ── Theme ────────────────────────────────────────────────────────────────
  # scheme: any base16 scheme name from the base16-schemes package (the file
  #   ${pkgs.base16-schemes}/share/themes/<scheme>.yaml). Examples: monokai,
  #   gruvbox-dark-medium, catppuccin-mocha, dracula, nord, tokyo-night-dark,
  #   solarized-dark, everforest, rose-pine, onedark. Full list:
  #   https://github.com/tinted-theming/schemes/tree/spec-0.11/base16
  scheme = "monokai";
  polarity = "dark"; # "dark" | "light" | "either"
  wallpaper = ./wallpaper.png;
  # Font packages are nixpkgs attribute paths (resolved against pkgs in
  # profiles/theming/nixos.nix); names are the family names stylix writes.
  fonts = {
    monospace = { package = "nerd-fonts.jetbrains-mono"; name = "JetBrainsMono Nerd Font Mono"; };
    sansSerif = { package = "inter"; name = "Inter"; };
    serif = { package = "dejavu_fonts"; name = "DejaVu Serif"; };
    sizes = { applications = 12; terminal = 13; desktop = 11; popups = 11; };
  };

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
