{ lib, osConfig, pkgs, ... }:
let
  # The gamescope security wrapper (capSysNice=true) injects cap_sys_nice into
  # the inheritable set. bwrap 0.11+ rejects any non-zero capability sets.
  # Fix: pass capsh as the "steam" command after gamescope's --, so caps are
  # cleared right before bwrap runs, inside the gamescope session.
  steam-gamescope = pkgs.writeShellScriptBin "steam-gamescope" ''
    exec gamescope --steam \
      -W 3440 -H 1440 \
      -r 175 \
      -f \
      --adaptive-sync \
      --rt \
      --expose-wayland \
      --xwayland-count 2 \
      --mangoapp \
      -- \
      ${pkgs.libcap}/bin/capsh --inh= --noamb -- -c \
        "exec steam -tenfoot -pipewire-dmabuf"
  '';
in
lib.mkIf osConfig.mySystem.gaming.enable {
  programs.mangohud.enable = true;
  programs.vesktop.enable = true;

  home.packages = with pkgs; [
    faugus-launcher
    goverlay
    heroic
    lact
    protonplus
    r2modman
    steam-gamescope
  ];

  xdg.desktopEntries.steam-gamescope = {
    name = "Steam (Gamescope)";
    exec = "steam-gamescope";
    icon = "steam";
    comment = "Steam via Gamescope — all games run inside gamescope";
    categories = [ "Game" ];
  };
}
