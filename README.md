# Yottamaster Arch Linux Utils

Reliable utilities and watchdogs for running Yottamaster USB disk enclosures on Arch Linux and similar distributions.

This repository provides scripts, systemd units, and documentation to safely operate Yottamaster multi-bay USB enclosures in home servers, NAS setups, and self-hosted environments.

The main goal is to prevent boot hangs, automatically recover from USB or disk failures, and keep Docker and storage stacks consistent over time.

---

## Why this project exists

USB disk enclosures are convenient but unreliable under Linux when:

- Power outages occur
- USB bridges temporarily disconnect
- Disks fail to enumerate correctly
- Filesystems mount partially
- Docker containers depend on unstable storage

This project implements a **state-aware watchdog** that:

- Detects real storage health
- Safely resets only the affected USB device
- Avoids infinite recovery loops
- Automatically remounts volumes
- Restarts Docker only when necessary

All without requiring system reboot in most cases.

---

# Installation Guide

This guide explains how to install, configure, and enable the Yottamaster watchdog on an Arch Linux system.

The instructions below assume a clean and manual installation, with no hidden automation steps.

---

## Prerequisites

Before installing, ensure the following requirements are met:

### Operating System

- Arch Linux (recommended)
- Any other systemd-based Linux distribution may work

### Hardware

- A Yottamaster USB disk enclosure (JMicron JMS56x based)
- One or more SATA HDDs or SSDs installed in the enclosure
- Stable USB connection (avoid unpowered hubs)

### Software

- systemd
- bash
- usbutils (for `lsusb`)
- util-linux
- Optional:
  - mergerfs
  - Docker

You must have root or sudo access.

---

## Step 1: Clone the repository

Clone the repository to your local machine:

```bash
git clone https://github.com/brunos3d/yottamaster-arch-linux-utils.git
cd yottamaster-arch-linux-utils
```

---

## Step 2: Identify the Yottamaster USB device

Plug in and power on the Yottamaster enclosure, then run:

```bash
lsusb
```

Look for a line similar to:

```
Bus 001 Device 004: ID 152d:9561 JMicron Technology Corp. JMS56x Series
```

Take note of the **Vendor ID** and **Product ID**.

---

## Step 3: Install the watchdog script

Copy the watchdog script to a system-wide executable location:

```bash
sudo cp scripts/yottamaster-watchdog.sh /usr/local/bin/yottamaster-watchdog.sh
sudo chmod +x /usr/local/bin/yottamaster-watchdog.sh
```

---

## Step 4: Configure the watchdog script

Edit the script:

```bash
sudo nano /usr/local/bin/yottamaster-watchdog.sh
```

Verify or adjust the following variables:

- `YOTTA_USB_ID`  
  Must match the Vendor:Product ID found with `lsusb`

- `MOUNTS` and `STORAGE`  
  Must match your backend disk mount points and mergerfs mount

- Docker behavior  
  Docker is restarted **only if active** and **only after storage recovery**

Save and exit after making changes.

---

## Step 5: Configure filesystem mounts

Ensure your backend disks and mergerfs mounts are configured safely in `/etc/fstab`.

This project strongly recommends using **mergerfs** to aggregate multiple disks into a single logical storage mount while keeping backend disks independently mountable and recoverable.

### Required mount options

All backend disks and the mergerfs mount should include the following options:

- `nofail`  
  Prevents boot failure if a disk is missing

- `x-systemd.automount`  
  Enables lazy mounting on first access

- `x-systemd.device-timeout=5s`  
  Avoids indefinite waits during boot

---

### Backend disk mounts (example)

In this example, two NTFS-formatted disks are mounted independently:

```fstab
UUID=XXXX /mnt/hdd1tb ntfs-3g uid=1000,gid=1000,umask=000,nofail,x-systemd.device-timeout=5s,x-systemd.automount 0 0
UUID=YYYY /mnt/hdd2tb ntfs-3g uid=1000,gid=1000,umask=000,nofail,x-systemd.device-timeout=5s,x-systemd.automount 0 0
```

Key points:

- Each disk has its own mount point
- Disks can be mounted or recovered independently
- Failure of one disk does not block the other

---

### mergerfs mount (example)

The backend disks are then combined into a single logical mount:

```fstab
/mnt/hdd1tb:/mnt/hdd2tb /mnt/storage fuse.mergerfs defaults,allow_other,use_ino,category.create=epmfs,minfreespace=10G,nofail,x-systemd.automount 0 0
```

Explanation of key options:

- `allow_other`  
  Allows non-root processes to access the filesystem

- `use_ino`  
  Preserves inode numbers for better compatibility

- `category.create=epmfs`  
  Controls file creation policy across disks

- `minfreespace=10G`  
  Prevents writes when disks approach full capacity

---

### Why this layout is recommended

This layout provides several advantages:

- Backend disks remain individually mountable
- mergerfs can recover cleanly after USB resets
- Docker and applications see a single stable path
- Partial disk failures are easier to diagnose
- The watchdog can validate health reliably

---

## Step 6: Install systemd service

Copy the systemd service unit:

```bash
sudo cp systemd/yottamaster-watchdog.service /etc/systemd/system/
```

This service is defined as `Type=oneshot` and executes the watchdog script once per invocation.

---

## Step 7: Install systemd timer

Copy the systemd timer unit:

```bash
sudo cp systemd/yottamaster-watchdog.timer /etc/systemd/system/
```

The timer controls how often the watchdog runs.

---

## Step 8: Enable and start the timer

Reload systemd units:

```bash
sudo systemctl daemon-reload
```

Enable the timer so it starts automatically on boot:

```bash
sudo systemctl enable yottamaster-watchdog.timer
```

Start the timer immediately:

```bash
sudo systemctl start yottamaster-watchdog.timer
```

---

## Step 9: Verify installation

Check that the timer is active:

```bash
systemctl list-timers | grep yottamaster
```

Monitor watchdog logs:

```bash
tail -f /var/log/yottamaster-watchdog.log
```

Expected healthy output:

```
Storage is healthy, no action required
```

---

## Step 10: Test recovery behavior (optional but recommended)

To validate recovery:

1. Power off the Yottamaster enclosure
2. Wait for at least one timer cycle
3. Power the enclosure back on
4. Observe the logs

You should see recovery attempts followed by:

```
Storage recovered successfully
```

---

## Uninstallation

To completely remove the watchdog:

```bash
sudo systemctl stop yottamaster-watchdog.timer
sudo systemctl disable yottamaster-watchdog.timer
sudo rm /etc/systemd/system/yottamaster-watchdog.service
sudo rm /etc/systemd/system/yottamaster-watchdog.timer
sudo rm /usr/local/bin/yottamaster-watchdog.sh
sudo systemctl daemon-reload
```

---

## Summary

Once installed, the watchdog runs automatically in the background via a systemd timer.

No manual interaction is required during normal operation.
