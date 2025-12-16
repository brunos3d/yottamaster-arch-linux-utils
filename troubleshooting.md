# Troubleshooting Guide

This document lists common issues, log messages, and recovery strategies when running the Yottamaster Arch Linux Utils watchdog.

The goal is to help users quickly understand what is happening and decide whether the issue is recoverable automatically or requires manual intervention.

---

## How to read the logs

The watchdog writes logs to:

```
/var/log/yottamaster-watchdog.log
```

Each execution is timestamped and represents one run triggered by the systemd timer.

Example:

```
[2025-12-16 03:47:34] Storage is healthy, no action required
```

This means the watchdog checked the system and exited without performing any recovery.

---

## Common log messages and meanings

### "Storage is healthy, no action required"

**Meaning**
- The mergerfs mount exists
- The filesystem responds to system calls
- No USB or storage action was required

**Action**
- None
- This is the expected steady-state behavior

---

### "Yottamaster USB device not detected"

**Meaning**
- The USB enclosure is not visible on the USB bus
- Possible power loss or physical disconnect

**Automatic behavior**
- The watchdog triggers a SCSI rescan
- No USB reset is attempted

**Recommended checks**
- Verify the enclosure is powered on
- Check USB cable and power supply
- Run `lsusb` manually

---

### "Storage unhealthy, starting recovery"

**Meaning**
- The merged storage mount is not responding
- Backend mounts may be missing or unresponsive

**Automatic behavior**
- Cooldown lock is created
- Recovery sequence begins

**Recommended checks**
- Inspect `/mnt/hdd*` mount points
- Run `mount` or `lsblk`

---

### "Resetting USB device at /sys/bus/usb/devices/X-Y.Z"

**Meaning**
- The watchdog is performing a targeted USB reset
- Only the Yottamaster enclosure is affected

**Automatic behavior**
- Logical USB disconnect
- USB re-enumeration
- SCSI devices are recreated

**Recommended checks**
- This is expected during recovery
- No action required unless repeated excessively

---

### "Rescanning SCSI bus"

**Meaning**
- Kernel is being instructed to detect new disk devices

**Automatic behavior**
- `/dev/sdX` nodes are recreated

**Recommended checks**
- None unless disks fail to appear

---

### "Mounting backend volumes"

**Meaning**
- The watchdog is attempting to mount individual disks
- mergerfs will be mounted afterward

**Automatic behavior**
- Uses `/etc/fstab` definitions
- Ignores mount failures temporarily

---

### "Storage recovered successfully"

**Meaning**
- Storage became healthy again
- Filesystem is responsive

**Automatic behavior**
- Docker is restarted if running

**Recommended checks**
- Confirm containers resumed normal operation

---

### "Restarting Docker service"

**Meaning**
- Docker was active and storage transitioned from unhealthy to healthy
- Restart ensures containers see consistent storage

**Automatic behavior**
- One-time restart only
- Not repeated if storage remains healthy

---

### "Cooldown active, skipping recovery cycle"

**Meaning**
- A recovery recently occurred
- The watchdog is intentionally not acting

**Automatic behavior**
- Prevents USB flapping and infinite loops

**Recommended checks**
- None
- This is protective behavior

---

### "Critical failure, rebooting system"

**Meaning**
- Multiple recovery attempts failed
- Storage could not be stabilized

**Automatic behavior**
- Single controlled reboot
- Lock file prevents reboot loops

**Recommended checks**
- Inspect hardware
- Check power, cables, disks, enclosure firmware

---

## Common problems and solutions

### Problem: Watchdog keeps recovering every cycle

**Possible causes**
- Faulty USB cable
- Insufficient power supply
- Unstable USB controller
- Failing disk inside enclosure

**Suggested actions**
- Replace USB cable
- Use a different USB port
- Avoid USB hubs
- Check SMART data if possible

---

### Problem: Storage never recovers

**Possible causes**
- Dead disk
- Firmware bug in enclosure
- Unsupported filesystem

**Suggested actions**
- Test disks individually
- Mount backend disks manually
- Remove mergerfs temporarily

---

### Problem: Docker containers crash or restart unexpectedly

**Possible causes**
- Containers depend on unstable storage
- Storage recovery triggered Docker restart

**Suggested actions**
- Ensure containers tolerate restarts
- Add application-level health checks
- Use persistent volumes correctly

---

### Problem: System reboots unexpectedly

**Possible causes**
- Repeated failed recovery cycles
- Severe hardware instability

**Suggested actions**
- Check `/run/yottamaster-reboot.lock`
- Inspect logs before reboot
- Disable watchdog temporarily for debugging

---

## Manual debugging commands

Useful commands when diagnosing issues:

```bash
lsusb
lsblk
mount
df -h
journalctl -u yottamaster-watchdog.service
journalctl -u yottamaster-watchdog.timer
```

---

## When NOT to use this watchdog

This project is not suitable for:

- Mission-critical enterprise storage
- Environments requiring zero downtime
- Enclosures without stable USB bridges
- Systems without systemd

---

## Summary

The watchdog is designed to solve **transient and recoverable failures**.

If problems are frequent or persistent, they are usually hardware-related and should be addressed at the physical level rather than through automation.
