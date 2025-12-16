# systemd Units

This directory contains the systemd units responsible for running the Yottamaster watchdog automatically.

These units integrate the watchdog script into the operating system lifecycle using a safe, timer-based execution model.

---

## Files overview

### `yottamaster-watchdog.service`

This is a systemd service responsible for executing the watchdog script once.

Key characteristics:

- Uses `Type=oneshot`
- Executes the watchdog script and exits
- Does not remain running in the background
- Can be safely triggered multiple times

The service **does not contain any loop logic**. All repetition is controlled externally by the timer.

---

### `yottamaster-watchdog.timer`

This is a systemd timer that periodically triggers the service.

Key characteristics:

- Runs every 2 minutes
- Starts shortly after system boot
- Uses systemd scheduling instead of background daemons
- Prevents execution drift and race conditions

The timer is the only component responsible for scheduling executions.

---

## Execution model

The execution flow is:

1. systemd timer wakes up
2. systemd starts `yottamaster-watchdog.service`
3. The service executes `yottamaster-watchdog.sh`
4. The script checks storage health
5. The script exits immediately if storage is healthy
6. Recovery actions are taken only if required

This model ensures predictable behavior and avoids infinite loops.

---

## Why use a timer instead of a daemon

This project intentionally avoids a long-running daemon because:

- Timers are easier to debug
- systemd provides better scheduling guarantees
- Crashes do not accumulate state
- Each execution starts from a clean environment
- Logs are easier to reason about

---

## Dependencies

- systemd
- bash
- The watchdog script located at `/usr/local/bin/yottamaster-watchdog.sh`

---

## Summary

The combination of a oneshot service and a periodic timer provides a safe, reliable, and production-grade execution model for storage monitoring.
