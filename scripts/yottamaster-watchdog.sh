#!/usr/bin/env bash

YOTTA_USB_ID="152d:9561"
BACKENDS=("/mnt/hdd1tb" "/mnt/hdd2tb")
STORAGE="/mnt/storage"
LOG="/var/log/yottamaster-watchdog.log"
LOCK="/run/yottamaster-reboot.lock"
COOLDOWN_FILE="/run/yottamaster-cooldown.lock"
COOLDOWN_SECONDS=300
MAX_RETRIES=2
TESTFILE=".healthcheck"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"
}

in_cooldown() {
  [[ -f "$COOLDOWN_FILE" ]] &&
  (( $(date +%s) - $(stat -c %Y "$COOLDOWN_FILE") < COOLDOWN_SECONDS ))
}

usb_present() {
  lsusb | grep -qi "$YOTTA_USB_ID"
}

block_devices_present() {
  lsblk -o NAME | grep -qE 'sdb|sdc'
}

backend_accessible() {
  for m in "${BACKENDS[@]}"; do
    stat "$m" >/dev/null 2>&1 || return 1
  done
  return 0
}

storage_io_ok() {
  local test="$STORAGE/$TESTFILE"
  rm -f "$test" 2>/dev/null
  touch "$test" 2>/dev/null && rm -f "$test"
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

restart_docker_if_running() {
  systemctl is-active --quiet docker && {
    log "Restarting Docker service"
    systemctl restart docker
  }
}

main() {
  # Fast path, everything OK
  if backend_accessible && storage_io_ok; then
    log "Storage healthy"
    exit 0
  fi

  if in_cooldown; then
    log "Cooldown active, skipping recovery"
    exit 0
  fi

  if ! usb_present; then
    log "USB device not detected, rescanning SCSI"
    rescan_scsi
    exit 0
  fi

  if ! block_devices_present; then
    log "Block devices missing, starting recovery"
    touch "$COOLDOWN_FILE"

    for ((i=1;i<=MAX_RETRIES;i++)); do
      log "Recovery attempt $i"
      reset_usb_device
      sleep 5
      rescan_scsi
      sleep 5

      if backend_accessible && storage_io_ok; then
        log "Storage recovered"
        restart_docker_if_running
        exit 0
      fi
    done
  fi

  if [[ ! -f "$LOCK" ]]; then
    log "Critical failure, rebooting"
    touch "$LOCK"
    reboot
  fi
}

main
