#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONADO_DIR="${ROOT_DIR}/monado-source"
BUILD_DIR="${MONADO_DIR}/build-steamvr-minimal"
OPENXR_JSON="${BUILD_DIR}/openxr_monado-dev.json"
STEAMVR_DRIVER_DIR="${BUILD_DIR}/steamvr-monado"
STEAMVR_DRIVER_SO="${STEAMVR_DRIVER_DIR}/bin/linux64/driver_monado.so"

LEFT_CONTROLLER_MAC="${XRFORGE_LEFT_CONTROLLER_MAC:-D8:C4:97:C9:12:38}"
RIGHT_CONTROLLER_MAC="${XRFORGE_RIGHT_CONTROLLER_MAC:-D8:C4:97:C9:18:94}"

SKIP_BUILD=0
REGISTER_STEAMVR=0
LAUNCH_STEAMVR=0
CHECK_BLUETOOTH=1

usage() {
  cat <<EOF
XRForge HP Reverb one-shot Linux session helper

Usage:
  ./runonce.sh [options]

Options:
  --skip-build         Do not run ninja before startup checks.
  --register-steamvr  Register the local Monado SteamVR driver with vrpathreg.
  --launch-steamvr    Launch SteamVR through Steam after checks.
  --no-bluetooth      Skip Bluetooth controller status checks.
  -h, --help          Show this help.

Environment:
  XRFORGE_LEFT_CONTROLLER_MAC   Defaults to ${LEFT_CONTROLLER_MAC}
  XRFORGE_RIGHT_CONTROLLER_MAC  Defaults to ${RIGHT_CONTROLLER_MAC}

This script prepares the local Monado build used by XRForge for one SteamVR
session and reports the hardware state needed for the HP Reverb/WMR setup. It
does not pair Bluetooth devices automatically; use bluetoothctl for first-time
pairing/trust.
EOF
}

log() {
  printf '\n==> %s\n' "$*"
}

warn() {
  printf 'warning: %s\n' "$*" >&2
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

have() {
  command -v "$1" >/dev/null 2>&1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-build)
      SKIP_BUILD=1
      ;;
    --register-steamvr)
      REGISTER_STEAMVR=1
      ;;
    --launch-steamvr)
      LAUNCH_STEAMVR=1
      ;;
    --no-bluetooth)
      CHECK_BLUETOOTH=0
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
  shift
done

[[ -d "${MONADO_DIR}" ]] || die "Monado source tree not found: ${MONADO_DIR}"
[[ -d "${BUILD_DIR}" ]] || die "Monado build directory not found: ${BUILD_DIR}"

log "Checking required tools"
for tool in lsusb grep; do
  if have "${tool}"; then
    printf 'ok: %s\n' "${tool}"
  else
    warn "${tool} not found"
  fi
done

if [[ "${SKIP_BUILD}" -eq 0 ]]; then
  have ninja || die "ninja is required to build ${BUILD_DIR}"
  log "Building Monado SteamVR target"
  ninja -C "${BUILD_DIR}"
else
  log "Skipping build"
fi

[[ -f "${OPENXR_JSON}" ]] || die "OpenXR runtime manifest missing: ${OPENXR_JSON}"
[[ -f "${STEAMVR_DRIVER_SO}" ]] || die "SteamVR Monado driver missing: ${STEAMVR_DRIVER_SO}"

export XR_RUNTIME_JSON="${OPENXR_JSON}"

log "Runtime paths"
printf 'XR_RUNTIME_JSON=%s\n' "${XR_RUNTIME_JSON}"
printf 'SteamVR driver=%s\n' "${STEAMVR_DRIVER_DIR}"

log "HP Reverb USB check"
if have lsusb; then
  if lsusb | grep -iE 'Quanta|QHMD|HoloLens|Mixed Reality|HP' >/dev/null; then
    lsusb | grep -iE 'Quanta|QHMD|HoloLens|Mixed Reality|HP'
  else
    warn "HP Reverb/WMR USB devices were not obvious in lsusb output"
  fi
else
  warn "lsusb unavailable; skipping USB detection"
fi

if [[ "${CHECK_BLUETOOTH}" -eq 1 ]]; then
  log "WMR controller Bluetooth check"
  if have bluetoothctl; then
    for mac in "${LEFT_CONTROLLER_MAC}" "${RIGHT_CONTROLLER_MAC}"; do
      printf '\nController %s\n' "${mac}"
      if bluetoothctl info "${mac}" >/tmp/xrforge-bt-info.txt 2>&1; then
        grep -E 'Name:|Alias:|Paired:|Bonded:|Trusted:|Connected:' /tmp/xrforge-bt-info.txt || true
      else
        warn "bluetoothctl has no info for ${mac}; pair/trust it manually if this is first setup"
      fi
    done
    rm -f /tmp/xrforge-bt-info.txt
  else
    warn "bluetoothctl unavailable; skipping controller checks"
  fi

  if have hcitool; then
    printf '\nActive Bluetooth links:\n'
    hcitool con || true
  fi
fi

if [[ "${REGISTER_STEAMVR}" -eq 1 ]]; then
  log "Registering SteamVR driver"
  VRPATHREG=""
  for candidate in \
    "${HOME}/.steam/steam/steamapps/common/SteamVR/bin/linux64/vrpathreg" \
    "${HOME}/.local/share/Steam/steamapps/common/SteamVR/bin/linux64/vrpathreg"; do
    if [[ -x "${candidate}" ]]; then
      VRPATHREG="${candidate}"
      break
    fi
  done

  [[ -n "${VRPATHREG}" ]] || die "vrpathreg not found. Install SteamVR or register ${STEAMVR_DRIVER_DIR} manually."
  "${VRPATHREG}" adddriver "${STEAMVR_DRIVER_DIR}"
else
  log "SteamVR driver registration"
  printf 'To register the local driver, run:\n'
  printf '  %q --register-steamvr\n' "${ROOT_DIR}/runonce.sh"
fi

if [[ "${LAUNCH_STEAMVR}" -eq 1 ]]; then
  log "Launching SteamVR"
  if have steam; then
    steam steam://rungameid/250820
  else
    die "steam command not found"
  fi
else
  log "Launch"
  printf 'To launch SteamVR after checks, run:\n'
  printf '  %q --launch-steamvr\n' "${ROOT_DIR}/runonce.sh"
fi

log "Monado process model"
printf 'SteamVR loads Monado through driver_monado.so inside SteamVR, typically vrserver.\n'
printf 'A separate monado-service process is not expected for this SteamVR driver flow.\n'
if pgrep -af 'monado-service|vrserver|vrcompositor' >/dev/null 2>&1; then
  pgrep -af 'monado-service|vrserver|vrcompositor'
else
  printf 'No monado-service/SteamVR runtime processes are currently visible.\n'
fi

log "Ready"
printf 'Use XR_RUNTIME_JSON above for OpenXR clients launched from this shell; SteamVR uses the registered driver path.\n'
