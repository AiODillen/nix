---
title: Storage UUID Bindings
date: 2026-06-17
status: approved
---

## Problem

`profiles/storage/nixos.nix` binds mounts to raw device names (`/dev/sdb1`, `/dev/nvme0n1p3`). Device names shift when drives connect/disconnect — the Grab HDD was mapped to `/dev/sdb1` but that slot is currently occupied by a Windows drive's EFI partition. UUIDs are stable across enumeration order changes.

## Scope

Single file: `profiles/storage/nixos.nix`. Two `device` field replacements only.

## Changes

| Mount | Old device | New device |
|-------|-----------|-----------|
| `/home/dillen/Grab` | `/dev/sdb1` | `/dev/disk/by-uuid/b7139bdc-09fd-4008-9ab2-243eb5aacc05` |
| `/home/dillen/Games_Part` | `/dev/nvme0n1p3` | `/dev/disk/by-uuid/9171c17f-e154-41f4-87ac-69a020fbebbd` |

`fsType` and `options` unchanged. No other files modified.

## UUID Source

Verified live via `lsblk`:
- `sda1` (3.6TB ext4, label "Grab") → `b7139bdc-09fd-4008-9ab2-243eb5aacc05`
- `nvme0n1p3` (326GB ext4, label "Games") → `9171c17f-e154-41f4-87ac-69a020fbebbd`

## Approach

Use `/dev/disk/by-uuid/` symlink paths — consistent with `hosts/nixos/hardware.nix` which already uses this format for root and boot.

## Verification

After `nixos-rebuild switch`, confirm mounts resolve correctly:
```
systemctl status home-dillen-Grab.mount
systemctl status home-dillen-Games_Part.mount
```
