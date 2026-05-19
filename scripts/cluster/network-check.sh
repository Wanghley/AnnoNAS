#!/usr/bin/env bash
#
# /usr/local/bin/network-check.sh
#
# Description:
#   This script checks network connectivity on boot and periodically.
#   It uses GPIO LEDs to indicate state and can trigger a reboot after N failures.
#   Logs are written to /var/log/network-check.log.
#
# Author: <Your Name>
# Updated: 2025-06-14

set -euo pipefail

# ─── CONFIGURATION ─────────────────────────────────────────────────────────────
MAX_TRIALS=3
PING_TARGET="1.1.1.1"
PING_RETRIES=5
PING_INTERVAL=1

TRIAL_FILE="/var/tmp/network_trials.txt"
ERROR_FLAG="/var/tmp/network_error.flag"
BOOT_FLAG="/run/network-check.first_run_done"
LOG_FILE="/var/log/network-check.log"
GPIO_BIN="/usr/local/bin/gpio"

# WiringOP pin numbers (use `gpio readall` to confirm)
RED_PIN=27     # D21 (GPIOD1)
GREEN_PIN=5    # D17 (GPIO3_C6)
# ─────────────────────────────────────────────────────────────────────────────

# ─── FUNCTIONS ────────────────────────────────────────────────────────────────

log() {
  printf '%s - %s\n' "$(date '+%F %T')" "$*" >> "$LOG_FILE"
}

initialize_gpio_pin() {
  local pin=$1
  local state=$2
  "$GPIO_BIN" mode "$pin" out
  "$GPIO_BIN" write "$pin" "$state"
}

blink_led() {
  local pin=$1
  local count=$2
  local delay=${3:-0.5}
  for ((i = 0; i < count; i++)); do
    "$GPIO_BIN" write "$pin" 0
    sleep "$delay"
    "$GPIO_BIN" write "$pin" 1
    sleep "$delay"
  done
}

blink_green_led_sequence() {
  initialize_gpio_pin "$GREEN_PIN" 0
  for ((i = 0; i < 90; i++)); do
    "$GPIO_BIN" write "$GREEN_PIN" 1
    usleep 166000
    "$GPIO_BIN" write "$GREEN_PIN" 0
    usleep 166000
  done
}

# ─── PERMISSIONS CHECK ────────────────────────────────────────────────────────

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Use sudo." >&2
  exit 1
fi

# ─── LOG FILE SETUP ───────────────────────────────────────────────────────────

touch "$LOG_FILE"
chmod 666 "$LOG_FILE"

log "###########################################################################"
log "Script start: Network check initiated."

# ─── FIRST BOOT DETECTION ─────────────────────────────────────────────────────

if [[ ! -f "$BOOT_FLAG" ]]; then
  log "First run after boot: clearing previous error flag."
  rm -f "$ERROR_FLAG"
  touch "$BOOT_FLAG"
fi

# ─── INDICATOR LED SETUP ──────────────────────────────────────────────────────

initialize_gpio_pin "$RED_PIN" 1
log "RED LED turned ON to indicate script ran."

log "Blinking GREEN LED to indicate initialization..."
blink_green_led_sequence
log "Completed GREEN LED blink sequence."

# ─── ERROR MODE CHECK ─────────────────────────────────────────────────────────

if [[ -f "$ERROR_FLAG" ]]; then
  log "In persistent error state. Blinking RED and exiting."
  blink_led "$RED_PIN" 10 0.5
  exit 0
fi

# ─── TRIAL COUNT SETUP ────────────────────────────────────────────────────────

if [[ -f "$TRIAL_FILE" ]]; then
  TRIALS=$(<"$TRIAL_FILE")
  if ! [[ "$TRIALS" =~ ^[0-9]+$ ]]; then
    log "Invalid trial count: '$TRIALS'. Resetting to 0."
    TRIALS=0
  fi
else
  TRIALS=0
fi

log "Current network failure trial count: $TRIALS / $MAX_TRIALS"

# ─── NETWORK CHECK ────────────────────────────────────────────────────────────

PING_SUCCESS=0
for ((i = 1; i <= PING_RETRIES; i++)); do
  if ping -c1 -W1 "$PING_TARGET" &>/dev/null; then
    PING_SUCCESS=1
    break
  fi
  sleep "$PING_INTERVAL"
done

if (( PING_SUCCESS == 1 )); then
  log "Network is UP. Turning GREEN LED ON, clearing trial counter."
  initialize_gpio_pin "$GREEN_PIN" 1
  rm -f "$TRIAL_FILE"
  exit 0
fi

# ─── NETWORK IS DOWN ──────────────────────────────────────────────────────────

TRIALS=$((TRIALS + 1))
echo "$TRIALS" > "$TRIAL_FILE"
log "Network is DOWN. Incremented trial count: $TRIALS / $MAX_TRIALS."

if (( TRIALS < MAX_TRIALS )); then
  log "Rebooting system (attempt $TRIALS)..."
  if ! systemctl reboot; then
    log "systemctl reboot failed. Trying fallback..."
    reboot || log "Fallback reboot also failed. Manual intervention required."
  fi
  exit 0
fi

# ─── MAX TRIALS REACHED ───────────────────────────────────────────────────────

log "Max trials ($MAX_TRIALS) reached. Entering persistent ERROR MODE."

# Turn off GREEN LED
initialize_gpio_pin "$GREEN_PIN" 0

# Blink RED LED then leave ON
blink_led "$RED_PIN" 5 0.5
initialize_gpio_pin "$RED_PIN" 1

# Set error state
if touch "$ERROR_FLAG"; then
  log "Error flag created at $ERROR_FLAG."
else
  log "Failed to create error flag. Exiting with error."
  exit 1
fi

# Cleanup
if rm -f "$TRIAL_FILE"; then
  log "Trial counter reset for next boot."
else
  log "Could not remove trial file. Manual cleanup may be required."
fi

exit 0
