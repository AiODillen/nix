#!/usr/bin/env bash
#
# install.sh — first-time bootstrap for this Nix flake.
#
# Presents the machines defined in flake.nix in a small terminal menu, asks for
# confirmation, then builds/activates the one you pick:
#
#   • NixOS hosts        →  sudo nixos-rebuild switch --flake .#<name>
#   • Home Manager users →  home-manager switch --flake .#<name>   (bootstraps
#                            via `nix run` when the HM CLI isn't installed yet)
#
# The required experimental features (nix-command, flakes) are enabled for every
# nix invocation this script makes, so a fresh box needs nothing pre-configured.
#
# Usage:
#   ./install.sh            # interactive menu
#   ./install.sh <name>     # skip the menu, install <name> (e.g. nixos / niklas)
#   ./install.sh -y <name>  # also skip the confirmation prompt
#   ./install.sh -h         # help
#
# Pure bash — no runtime dependencies beyond a working `nix` (and `sudo` for the
# NixOS path).

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Home Manager release, kept in step with the home-manager input in flake.nix.
HM_CHANNEL="github:nix-community/home-manager/release-26.05"

# Enable the flake features for *every* nix process we spawn (nix, home-manager,
# nixos-rebuild all read NIX_CONFIG). No edits to the user's nix.conf needed.
export NIX_CONFIG="experimental-features = nix-command flakes"

ASSUME_YES=false

# ── pretty output ────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  C_RST=$'\033[0m'; C_RED=$'\033[31m'; C_GRN=$'\033[32m'
  C_BLU=$'\033[34m'; C_DIM=$'\033[2m'; C_INV=$'\033[7m'
else
  C_RST=; C_RED=; C_GRN=; C_BLU=; C_DIM=; C_INV=
fi

die()  { printf '%serror:%s %s\n' "$C_RED" "$C_RST" "$*" >&2; exit 1; }
info() { printf '%s::%s %s\n'     "$C_BLU" "$C_RST" "$*" >&2; }
ok()   { printf '%s✓%s %s\n'      "$C_GRN" "$C_RST" "$*" >&2; }

usage() {
  sed -n '3,22p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

# ── machine discovery ────────────────────────────────────────────────────────
# Parallel arrays describing every installable target found in the flake.
declare -a M_NAME M_TYPE M_LABEL

# nix eval prints a JSON array of attr names, e.g. ["nixos"]. Names are simple
# identifiers (no commas/quotes), so a tr/sed split is enough — no jq required.
attr_names() {
  nix eval --json "$REPO_DIR#$1" --apply builtins.attrNames 2>/dev/null \
    | tr -d '[]"' | tr ',' '\n' | sed '/^[[:space:]]*$/d'
}

discover() {
  local name
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    M_NAME+=("$name"); M_TYPE+=("nixos")
    M_LABEL+=("$name   ${C_DIM}— NixOS (full system rebuild)${C_RST}")
  done < <(attr_names nixosConfigurations)

  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    M_NAME+=("$name"); M_TYPE+=("hm")
    M_LABEL+=("$name   ${C_DIM}— Home Manager (standalone)${C_RST}")
  done < <(attr_names homeConfigurations)

  ((${#M_NAME[@]})) || die "no nixosConfigurations or homeConfigurations found in $REPO_DIR"
}

# Resolve an explicit name argument to an index in the M_* arrays.
find_machine() {
  local want="$1" i
  for i in "${!M_NAME[@]}"; do
    [[ "${M_NAME[i]}" == "$want" ]] && { SELECTED=$i; return 0; }
  done
  die "unknown machine '$want'. Available: ${M_NAME[*]}"
}

# ── terminal menu ────────────────────────────────────────────────────────────
# Sets the global SELECTED to the chosen index. Arrow-key driven on a TTY, with
# a plain numbered prompt as the fallback for non-interactive shells.
SELECTED=-1
tui_select() {
  local prompt="$1"; shift
  local options=("$@") n=${#options[@]} sel=0 i key rest

  if [[ ! -t 0 || ! -t 1 ]]; then
    printf '%s\n' "$prompt" >&2
    for ((i = 0; i < n; i++)); do printf '  %d) %s\n' "$((i + 1))" "${options[i]}" >&2; done
    printf 'Selection [1-%d]: ' "$n" >&2
    local ans; read -r ans
    [[ "$ans" =~ ^[0-9]+$ ]] && ((ans >= 1 && ans <= n)) || die "invalid selection"
    SELECTED=$((ans - 1)); return
  fi

  printf '%s\n%s(↑/↓ to move · Enter to select · q to quit)%s\n\n' \
    "$prompt" "$C_DIM" "$C_RST" >&2

  printf '\033[?25l' >&2                       # hide cursor
  trap 'printf "\033[?25h" >&2' RETURN         # restore on return

  _render() {
    for ((i = 0; i < n; i++)); do
      if ((i == sel)); then
        printf '%s> %s%s\n' "$C_INV" "${options[i]}" "$C_RST" >&2
      else
        printf '  %s\n' "${options[i]}" >&2
      fi
    done
  }

  _render
  while true; do
    IFS= read -rsn1 key
    case "$key" in
      $'\x1b')                                 # escape sequence (arrow keys)
        read -rsn2 -t 0.01 rest || true
        case "$rest" in
          '[A') ((sel > 0)) && ((sel--)) ;;    # up
          '[B') ((sel < n - 1)) && ((sel++)) ;;# down
        esac ;;
      '') break ;;                             # Enter
      q | Q) die "cancelled" ;;
    esac
    printf '\033[%dA' "$n" >&2                  # cursor up n lines, redraw
    _render
  done
  SELECTED=$sel
}

confirm() {
  $ASSUME_YES && return 0
  printf '\n%s [y/N]: ' "$1" >&2
  local a; read -r a
  [[ "$a" =~ ^[Yy]$ ]]
}

# ── install actions ──────────────────────────────────────────────────────────
install_nixos() {
  local name="$1"
  info "Rebuilding NixOS configuration '$name' (sudo required)…"
  sudo nixos-rebuild switch --flake "$REPO_DIR#$name"
  ok "NixOS host '$name' is now active."
}

install_hm() {
  local name="$1"
  if command -v home-manager >/dev/null 2>&1; then
    info "Activating Home Manager configuration '$name'…"
    home-manager switch --flake "$REPO_DIR#$name" -b backup
  else
    info "Home Manager CLI not found — bootstrapping it via 'nix run'…"
    nix run "$HM_CHANNEL" -- switch --flake "$REPO_DIR#$name" -b backup
  fi
  ok "Home Manager configuration '$name' is now active."
}

# ── main ─────────────────────────────────────────────────────────────────────
main() {
  local arg_name=""
  while (($#)); do
    case "$1" in
      -h | --help) usage 0 ;;
      -y | --yes)  ASSUME_YES=true ;;
      -*)          die "unknown option '$1' (try -h)" ;;
      *)           arg_name="$1" ;;
    esac
    shift
  done

  [[ -f "$REPO_DIR/flake.nix" ]] || die "no flake.nix in $REPO_DIR"
  command -v nix >/dev/null 2>&1 || die \
    "nix is not installed. Install it first (https://nixos.org/download — multi-user, or the Determinate Systems installer) and re-run this script."

  info "Reading machines from ${REPO_DIR}/flake.nix…"
  discover

  if [[ -n "$arg_name" ]]; then
    find_machine "$arg_name"
  else
    tui_select "Select the machine to install:" "${M_LABEL[@]}"
  fi

  local name="${M_NAME[$SELECTED]}" type="${M_TYPE[$SELECTED]}"

  case "$type" in
    nixos) confirm "Install NixOS host '$name' via 'nixos-rebuild switch'?" \
             || die "cancelled"
           install_nixos "$name" ;;
    hm)    confirm "Install Home Manager config '$name' via 'home-manager switch'?" \
             || die "cancelled"
           install_hm "$name" ;;
  esac
}

main "$@"
