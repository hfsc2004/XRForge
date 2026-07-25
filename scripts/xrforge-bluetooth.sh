#!/usr/bin/env bash

print_controller_info() {
  local info_file="$1"

  grep -E 'Name:|Alias:|Paired:|Bonded:|Trusted:|Connected:' "${info_file}" || true
}

controller_field() {
  local field="$1"
  local info_file="$2"

  sed -n "s/^[[:space:]]*${field}:[[:space:]]*//p" "${info_file}" | tail -n 1
}

check_controller_bluetooth() {
  local mac="$1"
  local info_file="/tmp/xrforge-bt-info-${mac//:/}.txt"
  local connect_file="/tmp/xrforge-bt-connect-${mac//:/}.txt"
  local paired=""
  local trusted=""
  local connected=""

  printf '\nController %s\n' "${mac}"

  if ! bluetoothctl info "${mac}" >"${info_file}" 2>&1; then
    warn "bluetoothctl has no info for ${mac}; pair/trust it manually if this is first setup"
    rm -f "${info_file}"
    return 0
  fi

  print_controller_info "${info_file}"
  paired="$(controller_field "Paired" "${info_file}")"
  trusted="$(controller_field "Trusted" "${info_file}")"
  connected="$(controller_field "Connected" "${info_file}")"

  if [[ "${connected}" == "yes" || "${CONNECT_BLUETOOTH}" -eq 0 ]]; then
    rm -f "${info_file}"
    return 0
  fi

  if [[ "${paired}" == "yes" && "${trusted}" == "yes" ]]; then
    printf 'Attempting Bluetooth reconnect for %s\n' "${mac}"
    if ! bluetoothctl connect "${mac}" 2>&1 | tee "${connect_file}"; then
      if grep -q 'br-connection-create-socket' "${connect_file}"; then
        warn "${mac} failed at BlueZ socket creation; power-cycle or wake the controller, then retry"
        warn "if only one WMR controller connects at a time, suspect Bluetooth adapter capacity/reliability"
      fi
    fi
    sleep 2

    if bluetoothctl info "${mac}" >"${info_file}" 2>&1; then
      print_controller_info "${info_file}"
      connected="$(controller_field "Connected" "${info_file}")"
      [[ "${connected}" == "yes" ]] || warn "${mac} is still not connected; wake the controller and rerun ./start.sh"
    fi
    rm -f "${connect_file}"
  else
    warn "${mac} is not paired/trusted; pair and trust it once with bluetoothctl"
  fi

  rm -f "${info_file}"
}
