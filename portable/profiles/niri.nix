{ config, lib, pkgs, inputs, settings, ... }:
let
  colors = config.lib.stylix.colors;
  renderedKdl = lib.replaceStrings
    [ "@XKB_LAYOUT@" "@XKB_VARIANT@" "@BORDER_ACTIVE@" "@BORDER_INACTIVE@" ]
    [ settings.xkbLayout settings.xkbVariant "#${colors.base0E}" "#${colors.base01}" ]
    (builtins.readFile ../../profiles/desktop/niri/config.kdl);

  # nixGL Mesa shims — non-NixOS has no /run/opengl-driver, so nix GPU apps
  # can't find the system driver. These wrap a program with the right libs.
  # "Intel" is a misnomer: these are the Mesa wrappers (cover AMD/Intel).
  nixgl = inputs.nixgl.packages.${pkgs.stdenv.hostPlatform.system};
  nixGLIntel = nixgl.nixGLIntel;
  nixVulkanIntel = nixgl.nixVulkanIntel;

  # Launch niri under both shims so its GL + Vulkan renderers find the GPU.
  # Stable profile path is referenced by the system session entry below.
  niriSessionWrapped = pkgs.writeShellScriptBin "niri-session-nixgl" ''
    exec ${nixGLIntel}/bin/nixGLIntel ${nixVulkanIntel}/bin/nixVulkanIntel \
      ${pkgs.niri}/bin/niri-session "$@"
  '';
in
lib.mkIf (settings.desktop == "niri") {
  home.packages = with pkgs; [
    niri
    niriSessionWrapped   # nixGL-wrapped niri-session (used by the session entry)
    nixGLIntel           # run other nix GPU apps as `nixGLIntel <app>`
    nixVulkanIntel       # ...or `nixVulkanIntel <app>` for Vulkan apps (e.g. gram)
    xwayland-satellite   # on-demand XWayland; niri exports $DISPLAY when present
    nautilus
    gnome-disk-utility
    pavucontrol
  ];

  xdg.configFile."niri/config.kdl".text = renderedKdl;

  # Wayland daemons (stylix themes these via its default targets).
  programs.foot.enable = true;
  programs.fuzzel.enable = true;
  services.mako.enable = true;

  programs.waybar = {
    enable = true;
    settings = [
      {
        layer = "top";
        position = "top";
        height = 30;
        spacing = 4;
        "modules-left" = [ "niri/workspaces" ];
        "modules-center" = [ "clock" ];
        "modules-right" = [ "pulseaudio" "cpu" "memory" "tray" ];
        "niri/workspaces" = { };
        clock = {
          format = "{:%H:%M  %a %d}";
          tooltip = false;
        };
        cpu = { format = "CPU {usage}%"; interval = 5; };
        memory = { format = "RAM {}%"; interval = 10; };
        tray = { spacing = 8; };
        pulseaudio = {
          format = "VOL {volume}%";
          format-muted = "MUTE";
          on-click = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        };
      }
    ];
  };

  # Wayland session entry. The greeter (LightDM/GDM/SDDM) only scans the system
  # dir /usr/share/wayland-sessions, which home-manager cannot write. So this
  # file is generated here and must be copied there once with root:
  #
  #   sudo cp ~/.local/share/wayland-sessions/niri.desktop /usr/share/wayland-sessions/
  #
  # Exec uses the stable ~/.nix-profile path (valid across rebuilds), and runs
  # the nixGL-wrapped launcher so the compositor finds the GPU driver.
  xdg.dataFile."wayland-sessions/niri.desktop".text = ''
    [Desktop Entry]
    Name=Niri (nix)
    Comment=A scrollable-tiling Wayland compositor
    Exec=${settings.homeDirectory}/.nix-profile/bin/niri-session-nixgl
    Type=Application
  '';
}
