# Laptop machine overlay.
#
# Thin layer over the shared standalone base in ../../template: it pulls the
# entire template (identity, profiles, theming — all still driven by `settings`
# from the root flake) and adds only what is specific to this machine. Right
# now that is the monitor switching in ./monitors.nix.
#
# Built via the `niklas` home-manager output in the root flake.nix:
#   home-manager switch --flake .#niklas
{ ... }:
{
  imports = [
    ../../template/home.nix
    ./monitors.nix
  ];
}
