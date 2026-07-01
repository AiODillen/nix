{ pkgs, lib, themeMenu, mode }:
let
  namesLine = lib.concatMapStringsSep " " (t: t.name) themeMenu;
  activation =
    if mode == "hm" then ''
      gens="$(home-manager generations)"
      base=""
      while read -r line; do
        g="$(printf '%s' "$line" | grep -oE '/nix/store/[^ ]+' || true)"
        [ -n "$g" ] || continue
        if [ -n "$(ls -A "$g/specialisation" 2>/dev/null)" ]; then base="$g"; break; fi
      done <<< "$gens"
      [ -n "$base" ] || { echo "theme-switch: no base home-manager generation found" >&2; exit 1; }
      if [ "$choice" = default ]; then
        "$base/activate"
      else
        "$base/specialisation/$choice/activate"
      fi
    '' else ''
      if [ "$choice" = default ]; then
        sudo /run/current-system/bin/switch-to-configuration test
      else
        sudo "/run/current-system/specialisation/$choice/bin/switch-to-configuration" test
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
    )" || true
    [ -z "$choice" ] && exit 0

    ${activation}
    echo "$choice" > "$state/current"
  '';
}
