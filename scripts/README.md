# Watchdog Scripts

This directory contains the main watchdog responsible for monitoring:

- USB enclosure presence
- Backend disk mounts
- mergerfs health
- Docker dependency consistency

## Main Script

### `yottamaster-watchdog.sh`

Responsibilities:

- Detect Yottamaster USB presence
- Verify storage health using real filesystem calls
- Reset only the affected USB device
- Remount storage volumes
- Restart Docker when storage recovers
- Prevent infinite recovery loops using cooldowns and locks

This script is designed to be executed periodically via a systemd timer.

- Refer to [systemd/README.md](../systemd/README.md) for details on the timer-based execution model.
