{ pkgs, lib, themeMenu, mode }:
let
  namesLine = lib.concatMapStringsSep " " (t: t.name) themeMenu;
  activation =
    if mode == "hm" then ''
      gens="$(home-manager generations)"
      gen="$(printf '%s\n' "$gens" | head -n1 | grep -oE '/nix/store/[^ ]+')"
      if [ "$choice" = default ]; then
        "$gen/activate"
      else
        "$gen/specialisation/$choice/activate"
      fi
    '' else ''
      if [ "$choice" = default ]; then
        sudo /run/current-system/bin/switch-to-configuration switch
      else
        sudo "/run/current-system/specialisation/$choice/bin/switch-to-configuration" switch
      fi
    '';
in
pkgs.writeShellApplication {
  name = "theme-switch";
  runtimeInputs = with pkgs; [ fuzzel coreutils gnugrep gawk ]
    ++ lib.optional (mode == "hm") home-manager;
  text = ''
    state="''${XDG_STATE_HOME:-$HOME/.local/state}/theme-switch"
    mkdir -p "$state"
    current="$(cat "$state/current" 2>/dev/null || echo default)"

    choice="$(
      { echo default; for t in ${namesLine}; do echo "$t"; done; } \
        | while read -r t; do
            if [ "$t" = "$current" ]; then echo "$t ●"; else echo "$t"; fi
          done \
        | fuzzel --dmenu --prompt 'theme> ' \
        | awk '{print $1}'
    )"
    [ -z "$choice" ] && exit 0

    ${activation}
    echo "$choice" > "$state/current"
  '';
}
