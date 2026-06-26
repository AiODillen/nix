# Gaming home profile. Imported only when vars.modules.gaming = true (gated in
# machines/pc/home.nix), so no enable guard here.
{
  pkgs,
  vars,
  ...
}:
let
  res = vars.gamescope;
  # The gamescope security wrapper (capSysNice=true) injects cap_sys_nice into
  # the inheritable set. bwrap 0.11+ rejects any non-zero capability sets.
  # Fix: pass capsh as the "steam" command after gamescope's --, so caps are
  # cleared right before bwrap runs, inside the gamescope session.
  # `-r` is intentionally omitted: it locks gamescope to a fixed refresh and
  # disables --adaptive-sync (gamescope issue #975). VRR adapts naturally; cap
  # fps in-game or via MangoHud if needed.
  steam-gamescope = pkgs.writeShellScriptBin "steam-gamescope" ''
    exec gamescope --steam \
      -W ${toString res.width} -H ${toString res.height} \
      -f \
      --adaptive-sync \
      --force-grab-cursor \
      --expose-wayland \
      --xwayland-count 2 \
      --mangoapp \
      -- \
      ${pkgs.libcap}/bin/capsh --inh= --noamb -- -c \
        "exec steam -tenfoot -pipewire-dmabuf"
  '';
in
{
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
