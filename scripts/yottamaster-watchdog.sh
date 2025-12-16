#!/usr/bin/env bash

YOTTA_USB_ID="152d:9561"
MOUNTS=("/mnt/hdd1tb" "/mnt/hdd2tb")
STORAGE="/mnt/storage"
LOG="/var/log/yottamaster-watchdog.log"
LOCK="/run/yottamaster-reboot.lock"
COOLDOWN_FILE="/run/yottamaster-cooldown.lock"
COOLDOWN_SECONDS=300
MAX_RETRIES=3

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"
}

in_cooldown() {
  [[ -f "$COOLDOWN_FILE" ]] && \
  (( $(date +%s) - $(stat -c %Y "$COOLDOWN_FILE") < COOLDOWN_SECONDS ))
}

usb_present() {
  lsusb | grep -qi "$YOTTA_USB_ID"
}

storage_healthy() {
  mountpoint -q "$STORAGE" && stat "$STORAGE" >/dev/null 2>&1
}

mount_backends_ok() {
  for m in "${MOUNTS[@]}"; do
    mountpoint -q "$m" || return 1
  done
  return 0
}

find_usb_path() {
  for d in /sys/bus/usb/devices/*; do
    [[ -f "$d/idVendor" && -f "$d/idProduct" ]] || continue
    [[ "$(cat "$d/idVendor")":"$(cat "$d/idProduct")" == "$YOTTA_USB_ID" ]] && echo "$d" && return 0
  done
  return 1
}

rescan_scsi() {
  log "Rescanning SCSI bus"
  for h in /sys/class/scsi_host/host*; do
    echo "- - -" > "$h/scan"
  done
}

reset_usb_device() {
  usb_path=$(find_usb_path) || return 1
  log "Resetting USB device at $usb_path"
  echo 0 > "$usb_path/authorized"
  sleep 3
  echo 1 > "$usb_path/authorized"
}

mount_volumes() {
  log "Mounting backend volumes"
  mount /mnt/hdd1tb 2>/dev/null
  mount /mnt/hdd2tb 2>/dev/null
  mount "$STORAGE" 2>/dev/null
}

restart_docker_if_running() {
  systemctl is-active --quiet docker && {
    log "Restarting Docker service"
    systemctl restart docker
  }
}

main() {
  if storage_healthy; then
    log "Storage is healthy, no action required"
    exit 0
  fi

  if in_cooldown; then
    log "Cooldown active, skipping recovery cycle"
    exit 0
  fi

  if ! usb_present; then
    log "Yottamaster USB device not detected"
    rescan_scsi
    exit 0
  fi

  log "Storage unhealthy, starting recovery"
  touch "$COOLDOWN_FILE"

  for ((i=1;i<=MAX_RETRIES;i++)); do
    log "Recovery attempt $i"
    reset_usb_device
    sleep 5
    rescan_scsi
    sleep 3
    mount_volumes
    sleep 3

    if storage_healthy; then
      log "Storage recovered successfully"
      restart_docker_if_running
      exit 0
    fi
  done

  if [[ ! -f "$LOCK" ]]; then
    log "Critical failure, rebooting system"
    touch "$LOCK"
    reboot
  fi
}

main
