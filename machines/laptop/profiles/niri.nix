{
  config,
  lib,
  pkgs,
  inputs,
  vars,
  ...
}:
let
  colors = config.lib.stylix.colors;
  c = colors.withHashtag; # base00..base0F as "#rrggbb"
  renderedKdl =
    lib.replaceStrings
      [ "@XKB_LAYOUT@" "@XKB_VARIANT@" "@BORDER_ACTIVE@" "@BORDER_INACTIVE@" ]
      [ vars.xkbLayout vars.xkbVariant "#${colors.base0D}" "#${colors.base01}" ]
      (builtins.readFile ./niri/config.kdl);

  # wiremix has no stylix target; generate a base16 theme (inherits the built-in
  # "default" so any unset field falls back). foot is already stylix-themed, so
  # wiremix renders on a matching terminal background.
  wiremixToml = ''
    theme = "stylix"

    [themes.stylix]
    inherit = "default"
    default_device = { fg = "${c.base0D}" }
    default_stream = { fg = "${c.base0D}" }
    selector = { fg = "${c.base0E}" }
    tab = { fg = "${c.base04}" }
    tab_selected = { fg = "${c.base0D}", add_modifier = "BOLD" }
    tab_marker = { fg = "${c.base09}" }
    list_more = { fg = "${c.base04}" }
    node_title = { fg = "${c.base05}" }
    node_target = { fg = "${c.base0C}" }
    volume = { fg = "${c.base05}" }
    volume_empty = { fg = "${c.base03}" }
    volume_filled = { fg = "${c.base0B}" }
    meter_inactive = { fg = "${c.base03}" }
    meter_active = { fg = "${c.base0B}" }
    meter_overload = { fg = "${c.base08}" }
    meter_center_inactive = { fg = "${c.base03}" }
    meter_center_active = { fg = "${c.base0A}" }
    config_device = { fg = "${c.base05}" }
    config_profile = { fg = "${c.base0C}" }
    dropdown_icon = { fg = "${c.base0C}" }
    dropdown_border = { fg = "${c.base0D}" }
    dropdown_item = { fg = "${c.base05}" }
    dropdown_selected = { fg = "${c.base0D}", add_modifier = "BOLD" }
    dropdown_more = { fg = "${c.base04}" }
    help_border = { fg = "${c.base0D}" }
    help_item = { fg = "${c.base05}" }
    help_more = { fg = "${c.base04}" }
  '';

  # GPU-vendor-aware nixGL wrappers (Mesa vs NVIDIA), shared with gpu.nix.
  # Non-NixOS has no /run/opengl-driver, so nix GPU apps can't find the system
  # driver; these wrap a program with the right libs.
  nixgl = import ../nixgl.nix { inherit pkgs inputs vars; };

  # Run niri under both shims so its GL + Vulkan renderers find the GPU.
  # niri.service (below) uses this as ExecStart; niri-session itself needs no
  # GPU, so the session entry runs the plain niri-session from the profile.
  niriWrapped = pkgs.writeShellScriptBin "niri-nixgl" ''
    exec ${nixgl.glExe} ${nixgl.vulkanExe} \
      ${pkgs.niri}/bin/niri "$@"
  '';

  # niri runs under nixGL (above), which injects an older gcc libstdc++ via
  # LD_LIBRARY_PATH. That shadows waybar 0.15's own (newer) RPATH libstdc++ and
  # breaks it: `GLIBCXX_3.4.34 not found`. The fallback apt waybar 0.9.24 has no
  # niri modules, so workspaces/window break too. Clear LD_LIBRARY_PATH so the
  # nix waybar uses its RPATH, and pin the explicit nix path so the apt binary
  # never wins. spawn-at-startup in config.kdl launches "waybar-portable".
  waybarWrapped = pkgs.writeShellScriptBin "waybar-portable" ''
    exec env -u LD_LIBRARY_PATH ${pkgs.waybar}/bin/waybar "$@"
  '';

  # The session entry must land in a root-owned dir the greeter scans.
  # home-manager runs as the user, so it calls `sudo` for exactly this one
  # install command. A passwordless-sudo rule (installed once, see below) lets
  # that run silently on every switch — install is pinned to fixed args so the
  # grant is narrow.
  sessionSrc = "${vars.homeDirectory}/.local/share/wayland-sessions/niri.desktop";
  sessionDst = "/usr/share/wayland-sessions/niri.desktop";
  installCmd = "/usr/bin/install -Dm644 ${sessionSrc} ${sessionDst}";
  sudoersPath = "${vars.homeDirectory}/.config/niri-portable/niri-session.sudoers";
in
{
  home.packages = with pkgs; [
    niri
    niriWrapped # `niri-nixgl` — nixGL-wrapped niri (ExecStart of niri.service)
    waybarWrapped # `waybar-portable` — waybar with LD_LIBRARY_PATH cleared
    wiremix # pipewire TUI mixer (opened from waybar audio module)
    xwayland-satellite # on-demand XWayland; niri exports $DISPLAY when present
    nautilus
    gnome-disk-utility
    pavucontrol
    swayidle # idle/sleep manager — runs swaylock on before-sleep (lid close)
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
      Before = [
        "graphical-session.target"
        "xdg-desktop-autostart.target"
      ];
      Wants = [
        "graphical-session-pre.target"
        "xdg-desktop-autostart.target"
      ];
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
      Conflicts = [
        "graphical-session.target"
        "graphical-session-pre.target"
      ];
      After = [
        "graphical-session.target"
        "graphical-session-pre.target"
      ];
    };
  };

  # Lock on lid close: Mint logind suspends on lid close (its default); this
  # swayidle service holds a sleep inhibitor and runs swaylock on before-sleep,
  # so the lock surface is up before suspend completes. The `lock` event covers
  # `loginctl lock-session` and the manual keybind. -w waits for swaylock to
  # fork before releasing the inhibitor (critical — else a brief unlocked
  # window on resume). Wired to graphical-session.target so it inherits
  # WAYLAND_DISPLAY (niri --session imports the env into the user manager).
  systemd.user.services.swayidle = {
    Unit = {
      Description = "Idle manager — lock screen before sleep (lid close)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = ''
        ${pkgs.swayidle}/bin/swayidle -w \
          lock '${pkgs.swaylock}/bin/swaylock -f' \
          before-sleep '${pkgs.swaylock}/bin/swaylock -f'
      '';
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # Screen sharing on niri: the portal backends are apt-provided on this Mint
  # host (xdg-desktop-portal{,-gnome,-gtk} + pipewire, all already running).
  # niri's session sets XDG_CURRENT_DESKTOP=niri, so the portal frontend reads
  # niri-portals.conf. Pin ScreenCast/RemoteDesktop to the gnome backend (the
  # only one niri's screencast works with) and leave everything else to gtk
  # (native Mint file dialogs etc).
  xdg.configFile."xdg-desktop-portal/niri-portals.conf".text = ''
    [preferred]
    default=gtk
    org.freedesktop.impl.portal.ScreenCast=gnome
    org.freedesktop.impl.portal.RemoteDesktop=gnome
  '';

  xdg.configFile."wiremix/wiremix.toml".text = wiremixToml;

  # Wayland daemons (stylix themes these via its default targets).
  # Screen locker. Config written to ~/.config/swaylock/config; swaylock reads
  # it however launched (swayidle service or manual keybind). No nixGL wrapper:
  # swaylock is a Wayland shm+cairo client and the swayidle service runs in the
  # clean HM user env, not niri's LD_LIBRARY_PATH-polluted one.
  programs.swaylock.enable = true;

  programs.foot.enable = true;
  programs.fuzzel.enable = true;
  services.mako.enable = true;
  # Merges with stylix's color settings. Rounded corners + auto-dismiss.
  services.mako.settings = {
    default-timeout = 5000; # ms; notifications auto-dismiss after 5s
    border-radius = 12;
    border-size = 2;
    padding = "10";
    margin = "10";
  };
  # mako is spawn-at-startup'd by niri (not a HM systemd service), so a theme
  # rebuild rewrites ~/.config/mako/config but the running daemon keeps the old
  # colors. Reload it on activation. (|| true: no-op outside a live session.)
  home.activation.reloadMako = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.mako}/bin/makoctl reload 2>/dev/null || true
  '';

  programs.waybar = {
    enable = true;
    settings = [
      {
        layer = "top";
        position = "top";
        height = 36;
        spacing = 4;

        "modules-left" = [
          "niri/workspaces"
          "custom/separator"
          "niri/window"
        ];
        # niri exposes only ext-foreign-toplevel-list (read-only), not the
        # wlr-foreign-toplevel-management protocol wlr/taskbar needs, so a real
        # taskbar is impossible. niri/window shows the focused window title.
        "modules-center" = [ "clock" ];
        "modules-right" = [
          "network"
          "custom/separator"
          "pulseaudio"
          "custom/separator"
          "battery"
          "custom/separator"
          "power-profiles-daemon"
          "custom/separator"
          "cpu"
          "custom/separator"
          "memory"
          "custom/separator"
          "tray"
        ];
        "niri/workspaces" = { };
        "niri/window" = {
          format = "{title}";
          max-length = 50;
          tooltip = false;
        };
        "custom/separator" = {
          format = "|";
          interval = "once";
          tooltip = false;
        };
        clock = {
          format = "{:%H:%M  %a %d}";
          tooltip = false;
        };
        network = {
          format-wifi = "{essid} {signalStrength}%";
          format-ethernet = "ETH";
          format-disconnected = "no net";
          tooltip-format = "{ifname}: {ipaddr}";
          on-click = "nm-connection-editor";
        };
        battery = {
          format = "BAT {capacity}%";
          format-charging = "CHG {capacity}%";
          format-plugged = "AC {capacity}%";
          states = {
            warning = 30;
            critical = 15;
          };
        };
        power-profiles-daemon = {
          format = "{profile}";
          tooltip-format = "Power profile: {profile}\nDriver: {driver}";
        };
        cpu = {
          format = "CPU {usage}%";
          interval = 5;
        };
        memory = {
          format = "RAM {}%";
          interval = 10;
        };
        tray = {
          spacing = 8;
        };
        pulseaudio = {
          format = "VOL {volume}%";
          format-muted = "MUTE";
          # Left-click: open the wiremix TUI in a floating foot (app-id matched
          # by a niri window-rule). Right-click: mute toggle.
          on-click = "foot --app-id=audio-tui --window-size-chars=100x30 wiremix";
          on-click-right = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
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
    Exec=${vars.homeDirectory}/.nix-profile/bin/niri-session
    Type=Application
  '';

  # Ready-to-install passwordless-sudo rule for the one install command above.
  # Install it ONCE (the activation prints this command until it is in place):
  #   sudo install -m440 ~/.config/niri-portable/niri-session.sudoers \
  #        /etc/sudoers.d/niri-session
  home.file.".config/niri-portable/niri-session.sudoers".text = ''
    # Lets `home-manager switch` place the niri session entry without a password.
    # Pinned to exact arguments, so it grants nothing else.
    ${vars.user} ALL=(root) NOPASSWD: ${installCmd}
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
