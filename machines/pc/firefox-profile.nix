# Safe, one-time adoption of an existing Firefox profile on first activation.
#
# Problem: programs.firefox manages a profile named "default" (dir
# ~/.mozilla/firefox/default) and rewrites profiles.ini to point at it. On a
# machine where Firefox already created its own randomly-named profile
# (e.g. "gunej092.default-release"), the first `home-manager switch` would
# repoint Firefox at an empty "default" dir — all settings, logins, and
# extension state (e.g. Proton Pass vault) would appear wiped (data still on
# disk, but orphaned), or the switch would fail trying to clobber profiles.ini.
#
# Fix: before HM links its files (entryBefore "writeBoundary"), detect the
# existing default profile and RENAME its directory to "default", then step the
# Firefox-owned profiles.ini aside so HM writes its own. This preserves all
# data (the dir is renamed, not recreated) and makes the layout identical and
# portable across every machine — config never hardcodes a per-device profile
# id. Idempotent: once "default" exists it does nothing on later switches.
{ config, lib, pkgs, ... }:
let
  cfg = config.programs.firefox;
  managed = cfg.enable && (cfg.profiles ? default);
in
lib.mkIf managed {
  home.activation.adoptFirefoxDefaultProfile = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
    # NOTE: HM concatenates all activation blocks into ONE bash script, so a bare
    # `exit` here would abort the entire activation (linkGeneration, installPackages,
    # …). Run the whole adoption in a subshell so its `exit`s are local; `|| exit 1`
    # still lets the Firefox-running guard (real exit 1) abort the switch.
    (
    # Same dir HM writes profiles.ini / profile data to (programs.firefox.configPath).
    mozdir="${config.home.homeDirectory}/${cfg.configPath}"

    # Fresh machine (Firefox never run): nothing to adopt, HM creates "default".
    [ -d "$mozdir" ] || exit 0
    # Already adopted (or HM already owns it): leave it alone. Idempotent.
    [ -e "$mozdir/default" ] && exit 0
    ini="$mozdir/profiles.ini"
    # No profiles.ini yet: let HM create the default profile cleanly.
    [ -f "$ini" ] || exit 0

    # Find the path of the current default profile: prefer the [Install*]
    # Default= entry (the per-install default Firefox actually launches), else
    # fall back to the [Profile*] flagged Default=1.
    default_path="$(${pkgs.gawk}/bin/awk -F= '
      /^\[Install/ { ininstall=1; next }
      /^\[/        { ininstall=0 }
      ininstall && $1=="Default" { print $2; exit }
    ' "$ini")"
    if [ -z "$default_path" ]; then
      default_path="$(${pkgs.gawk}/bin/awk -F= '
        /^\[Profile/ { p="" }
        $1=="Path"   { p=$2 }
        $1=="Default" && $2=="1" { print p; exit }
      ' "$ini")"
    fi

    # Could not identify it, or it is already "default": let HM proceed.
    [ -n "$default_path" ] || exit 0
    [ "$default_path" = "default" ] && exit 0
    realdir="$mozdir/$default_path"
    [ -d "$realdir" ] || exit 0

    # Never rename a profile while Firefox is running — that corrupts the live
    # session. Fail the activation with guidance instead of risking data. This
    # can only trigger on the one switch where adoption is pending.
    if ${pkgs.procps}/bin/pgrep -f firefox >/dev/null 2>&1; then
      echo "ERROR: Firefox is running. Close it and re-run 'home-manager switch'" >&2
      echo "       so the existing profile '$default_path' can be adopted as" >&2
      echo "       'default' without losing settings/logins/extension data." >&2
      exit 1
    fi

    echo "Adopting existing Firefox profile '$default_path' as 'default' (one-time, data preserved)…"
    $DRY_RUN_CMD cp -a "$ini" "$ini.pre-hm.bak"
    [ -f "$mozdir/installs.ini" ] && $DRY_RUN_CMD cp -a "$mozdir/installs.ini" "$mozdir/installs.ini.pre-hm.bak"
    # If the existing profile already has a real user.js, keep it out of HM's
    # way (HM writes its own user.js symlink into the profile).
    if [ -f "$realdir/user.js" ] && [ ! -L "$realdir/user.js" ]; then
      $DRY_RUN_CMD mv "$realdir/user.js" "$realdir/user.js.pre-hm.bak"
    fi
    $DRY_RUN_CMD mv "$realdir" "$mozdir/default"
    $DRY_RUN_CMD mv "$ini" "$ini.firefox-orig"
    ) || exit 1
  '';
}
