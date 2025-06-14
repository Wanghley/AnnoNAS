#!/usr/bin/env bash
#
# /usr/local/bin/button-action.sh
# Reliable single vs. double click on GPIO25 with WiringOP
#   GND → button → GPIO25 (pulled up)
# Single press → reboot
# Double press → reconnect Wi-Fi

PIN=22
CLICK_TIMEOUT=0.5    # seconds to wait for 2nd click
POLL_INTERVAL=0.02   # poll every 20 ms

# LED pins (WiringOP / BCM)
RED_PIN=27    # D21 / GPIOD1
GREEN_PIN=5   # D17 / GPIO3_C6

# 1) Enable pull-up + input
gpio mode $PIN up
gpio mode $PIN in

# Initialize LEDs off
gpio mode $RED_PIN out
gpio mode $GREEN_PIN out
#gpio write $RED_PIN 0
#gpio write $GREEN_PIN 0
#sleep 2

reboot_system() {
  pre_led_states
  logger -t button-action "single click → rebooting"
  # Alternate RED/GREEN three times (200ms each)
  for i in {1..3}; do
    gpio write $RED_PIN 1
    sleep 0.2
    gpio write $RED_PIN 0
    gpio write $GREEN_PIN 1
    sleep 0.2
    gpio write $GREEN_PIN 0
  done

  # Short pause
  sleep 0.2

  # Finally, both LEDs solid to indicate reboot in progress
  gpio write $RED_PIN 1
  gpio write $GREEN_PIN 1
  sleep 3
  /sbin/reboot
}

wifi_reconnect() {
  pre_led_states
  sleep 3
  logger -t button-action "double click → toggling network"
  # Pre-reconnect: three rapid green blips
  for i in {1..3}; do
    gpio write $GREEN_PIN 1
    sleep 0.1
    gpio write $GREEN_PIN 0
    sleep 0.1
  done
  nmcli networking off
  sleep 1
  nmcli networking on
  # Post-reconnect: slow “heartbeat” of three green pulses
  for i in {1..3}; do
    gpio write $GREEN_PIN 1
    sleep 0.5
    gpio write $GREEN_PIN 0
    sleep 0.5
  done
  # Leave solid green to show success
  gpio write $GREEN_PIN 1
  sleep 3
  back_led_states
}

pre_led_states(){
  gpio write $RED_PIN 0
  gpio write $GREEN_PIN 0
}

back_led_states(){
 gpio write $RED_PIN 1
 gpio write $GREEN_PIN 1
}

prev_state=1
while true; do
  state=$(gpio read $PIN)
  # 2) First falling edge?
  if [[ $prev_state -eq 1 && $state -eq 0 ]]; then
    # wait for **release** of the first click
    while [[ $(gpio read $PIN) -eq 0 ]]; do sleep $POLL_INTERVAL; done

    # 3) Now start timeout window
    start=$(date +%s.%N)
    double=false

    # 4) Spin watching for a 2nd falling edge
    while (( $(echo "$(date +%s.%N) - $start < $CLICK_TIMEOUT" | bc -l) )); do
      if [[ $(gpio read $PIN) -eq 0 ]]; then
        double=true
        break
      fi
      sleep $POLL_INTERVAL
    done

    # 5) Act on single vs double
    if $double; then
      # ensure that second click is released before proceeding
      while [[ $(gpio read $PIN) -eq 0 ]]; do sleep $POLL_INTERVAL; done
      wifi_reconnect
    else
      reboot_system
    fi
  fi

  prev_state=$state
  sleep $POLL_INTERVAL
done