{ config, pkgs, ... }:
let
  u = config.mySystem.user;
in
{
  users.users.${u.name} = {
    isNormalUser = true;
    description = u.fullName;
    shell = pkgs.fish;
    extraGroups = u.extraGroups;
  };
}
