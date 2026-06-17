# Storage UUID Bindings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace raw device names in `profiles/storage/nixos.nix` with stable UUID-based paths so mounts survive drive enumeration changes.

**Architecture:** Single file edit — two `device` field replacements. Paths follow the `/dev/disk/by-uuid/` convention already used in `hosts/nixos/hardware.nix`.

**Tech Stack:** NixOS module system, systemd automount

---

### Task 1: Replace device bindings with UUID paths

**Files:**
- Modify: `profiles/storage/nixos.nix`

- [ ] **Step 1: Edit the file**

Replace the contents of `profiles/storage/nixos.nix` with:

```nix
{ config, lib, ... }:
lib.mkIf config.mySystem.storage.automount.enable {
  fileSystems."/home/dillen/Grab" = {
    device = "/dev/disk/by-uuid/b7139bdc-09fd-4008-9ab2-243eb5aacc05";
    fsType = "ext4";
    options = [ "nofail" "x-systemd.automount" "x-systemd.idle-timeout=600" ];
  };

  fileSystems."/home/dillen/Games_Part" = {
    device = "/dev/disk/by-uuid/9171c17f-e154-41f4-87ac-69a020fbebbd";
    fsType = "ext4";
    options = [ "nofail" "x-systemd.automount" "x-systemd.idle-timeout=600" ];
  };
}
```

- [ ] **Step 2: Verify the symlinks exist on disk**

```bash
ls -la /dev/disk/by-uuid/b7139bdc-09fd-4008-9ab2-243eb5aacc05
ls -la /dev/disk/by-uuid/9171c17f-e154-41f4-87ac-69a020fbebbd
```

Expected: both lines resolve to a block device (e.g. `-> ../../sda1`, `-> ../../nvme0n1p3`)

- [ ] **Step 3: Build to check for Nix syntax errors**

```bash
nixos-rebuild build --flake ~/nixos-config#nixos 2>&1 | tail -20
```

Expected: build succeeds with no errors.

- [ ] **Step 4: Apply the config**

```bash
sudo nixos-rebuild switch --flake ~/nixos-config#nixos
```

- [ ] **Step 5: Verify mounts**

```bash
systemctl status home-dillen-Grab.mount
systemctl status home-dillen-Games_Part.mount
```

Expected: both units show `active (mounted)` or `inactive (dead)` with automount waiting — neither should show `failed`.

- [ ] **Step 6: Commit**

```bash
git add profiles/storage/nixos.nix
git commit -m "fix: use UUID-based device paths for storage mounts"
```
