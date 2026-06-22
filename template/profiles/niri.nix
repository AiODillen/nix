{ config, lib, pkgs, inputs, settings, ... }:
let
  colors = config.lib.stylix.colors;
  renderedKdl = lib.replaceStrings
    [ "@XKB_LAYOUT@" "@XKB_VARIANT@" "@BORDER_ACTIVE@" "@BORDER_INACTIVE@" ]
    [ settings.xkbLayout settings.xkbVariant "#${colors.base0E}" "#${colors.base01}" ]
    (builtins.readFile ../../profiles/desktop/niri/config.kdl);

  # GPU-vendor-aware nixGL wrappers (Mesa vs NVIDIA), shared with gpu.nix.
  # Non-NixOS has no /run/opengl-driver, so nix GPU apps can't find the system
  # driver; these wrap a program with the right libs.
  nixgl = import ./nixgl.nix { inherit pkgs inputs settings; };

  # Run niri under both shims so its GL + Vulkan renderers find the GPU.
  # niri.service (below) uses this as ExecStart; niri-session itself needs no
  # GPU, so the session entry runs the plain niri-session from the profile.
  niriWrapped = pkgs.writeShellScriptBin "niri-nixgl" ''
    exec ${nixgl.glExe} ${nixgl.vulkanExe} \
      ${pkgs.niri}/bin/niri "$@"
  '';

  # The session entry must land in a root-owned dir the greeter scans.
  # home-manager runs as the user, so it calls `sudo` for exactly this one
  # install command. A passwordless-sudo rule (installed once, see below) lets
  # that run silently on every switch — install is pinned to fixed args so the
  # grant is narrow.
  sessionSrc = "${settings.homeDirectory}/.local/share/wayland-sessions/niri.desktop";
  sessionDst = "/usr/share/wayland-sessions/niri.desktop";
  installCmd = "/usr/bin/install -Dm644 ${sessionSrc} ${sessionDst}";
  sudoersPath = "${settings.homeDirectory}/.config/niri-portable/niri-session.sudoers";
in
lib.mkIf (settings.desktop == "niri") {
  home.packages = with pkgs; [
    niri
    niriWrapped          # `niri-nixgl` — nixGL-wrapped niri (ExecStart of niri.service)
    xwayland-satellite   # on-demand XWayland; niri exports $DISPLAY when present
    nautilus
    gnome-disk-utility
    pavucontrol
  ];

  xdg.configFile."niri/config.kdl".text = renderedKdl;

  # niri ships systemd user units (niri.service, niri-shutdown.target), but the
  # NixOS module exposes them via `systemd.packages`, which standalone HM has no
  # equivalent for — so niri-session fails with "unit not found". Recreate them
  # as HM user units (HM handles daemon-reload). niri.service's ExecStart is the
  # nixGL-wrapped niri so the compositor finds the GPU. Unit metadata mirrors the
  # upstream units (graphical-session wiring).
  systemd.user.services.niri = {
    Unit = {
      Description = "A scrollable-tiling Wayland compositor";
      BindsTo = [ "graphical-session.target" ];
      Before = [ "graphical-session.target" "xdg-desktop-autostart.target" ];
      Wants = [ "graphical-session-pre.target" "xdg-desktop-autostart.target" ];
      After = [ "graphical-session-pre.target" ];
    };
    Service = {
      Slice = "session.slice";
      Type = "notify";
      ExecStart = "${niriWrapped}/bin/niri-nixgl --session";
    };
  };

  systemd.user.targets.niri-shutdown = {
    Unit = {
      Description = "Shutdown running niri session";
      DefaultDependencies = false;
      StopWhenUnneeded = true;
      Conflicts = [ "graphical-session.target" "graphical-session-pre.target" ];
      After = [ "graphical-session.target" "graphical-session-pre.target" ];
    };
  };

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
  # Exec runs the plain niri-session (stable ~/.nix-profile path); it starts the
  # nixGL-wrapped niri.service defined above, which is where the GPU is needed.
  xdg.dataFile."wayland-sessions/niri.desktop".text = ''
    [Desktop Entry]
    Name=Niri (nix)
    Comment=A scrollable-tiling Wayland compositor
    Exec=${settings.homeDirectory}/.nix-profile/bin/niri-session
    Type=Application
  '';

  # Ready-to-install passwordless-sudo rule for the one install command above.
  # Install it ONCE (the activation prints this command until it is in place):
  #   sudo install -m440 ~/.config/niri-portable/niri-session.sudoers \
  #        /etc/sudoers.d/niri-session
  home.file.".config/niri-portable/niri-session.sudoers".text = ''
    # Lets `home-manager switch` place the niri session entry without a password.
    # Pinned to exact arguments, so it grants nothing else.
    ${settings.username} ALL=(root) NOPASSWD: ${installCmd}
  '';

  # Place the session entry into the system dir (root). Uses `sudo -n` so it
  # never hangs on a prompt during a non-interactive switch: with the rule
  # above it runs silently; without it, it prints the one-time setup command.
  # cmp guard means it only acts when the entry actually changed.
  # NB: home-manager's activation PATH does not include the system bin dirs, so
  # a bare `sudo` is not found — locate it across the common locations (distros
  # vary: /usr/bin, /run/wrappers/bin, /bin, /usr/local/bin). If no sudo exists
  # at all (e.g. a doas-only distro), fall back to printing manual instructions.
  # Anchor after linkGeneration so the source file already holds the new content
  # (else cmp sees no change and skips the copy).
  home.activation.installNiriSession = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if [ -f "${sessionSrc}" ] && ! cmp -s "${sessionSrc}" "${sessionDst}"; then
      _sudo=$(PATH=/run/wrappers/bin:/usr/bin:/usr/local/bin:/bin command -v sudo 2>/dev/null || true)
      if [ -n "$_sudo" ] && $DRY_RUN_CMD "$_sudo" -n ${installCmd} 2>/dev/null; then
        :
      elif [ -n "$_sudo" ]; then
        echo "niri session entry needs a one-time passwordless-sudo rule. Run once:"
        echo "  sudo install -m440 ${sudoersPath} /etc/sudoers.d/niri-session"
        echo "Then re-run 'home-manager switch' — it installs the entry silently after that."
      else
        echo "niri session entry not installed: no 'sudo' found on PATH."
        echo "Install it manually as root (the greeter only scans the system dir):"
        echo "  install -Dm644 ${sessionSrc} ${sessionDst}"
      fi
    fi
  '';
}
