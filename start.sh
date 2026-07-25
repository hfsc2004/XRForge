#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/xrforge-env.sh
source "${ROOT_DIR}/scripts/xrforge-env.sh"
# shellcheck source=scripts/xrforge-build.sh
source "${ROOT_DIR}/scripts/xrforge-build.sh"
# shellcheck source=scripts/xrforge-bluetooth.sh
source "${ROOT_DIR}/scripts/xrforge-bluetooth.sh"
# shellcheck source=scripts/xrforge-chaperone.sh
source "${ROOT_DIR}/scripts/xrforge-chaperone.sh"
# shellcheck source=scripts/xrforge-x11.sh
source "${ROOT_DIR}/scripts/xrforge-x11.sh"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-build) SKIP_BUILD=1 ;;
    --check-only)
      REGISTER_STEAMVR=0
      LAUNCH_STEAMVR=0
      ;;
    --register-steamvr) REGISTER_STEAMVR=1 ;;
    --launch-steamvr) LAUNCH_STEAMVR=1 ;;
    --no-register-steamvr) REGISTER_STEAMVR=0 ;;
    --no-launch-steamvr) LAUNCH_STEAMVR=0 ;;
    --no-bluetooth) CHECK_BLUETOOTH=0 ;;
    --no-bluetooth-connect) CONNECT_BLUETOOTH=0 ;;
    --no-x11-non-desktop) SET_X11_NON_DESKTOP=0 ;;
    --wmr-3dof) WMR_3DOF_ONLY=1 ;;
    -h|--help)
      usage
      exit 0
      ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

ensure_not_root
[[ -d "${MONADO_DIR}" ]] || die "Monado source tree not found: ${MONADO_DIR}"
mkdir -p "${BUILD_DIR}"
ensure_monado_patch_queue

log "Checking required tools"
for tool in lsusb grep sed readelf awk; do
  if have "${tool}"; then
    printf 'ok: %s\n' "${tool}"
  else
    warn "${tool} not found"
  fi
done

if [[ "${SKIP_BUILD}" -eq 0 ]]; then
  ensure_monado_build_config
  log "Building Monado SteamVR target"
  ninja -C "${BUILD_DIR}" driver_monado
else
  log "Skipping build"
fi

[[ -f "${OPENXR_JSON}" ]] || die "OpenXR runtime manifest missing: ${OPENXR_JSON}"
[[ -f "${STEAMVR_DRIVER_SO}" ]] || die "SteamVR Monado driver missing: ${STEAMVR_DRIVER_SO}"
ensure_steamvr_driver_runpath
export_runtime_environment
print_runtime_summary

log "WMR-compatible XR USB check"
if have lsusb; then
  if lsusb | grep -iE 'Quanta|QHMD|HoloLens|Mixed Reality|HP' >/dev/null; then
    lsusb | grep -iE 'Quanta|QHMD|HoloLens|Mixed Reality|HP'
  else
    warn "WMR-compatible XR USB devices were not obvious in lsusb output"
  fi
else
  warn "lsusb unavailable; skipping USB detection"
fi

if [[ "${CHECK_BLUETOOTH}" -eq 1 ]]; then
  log "Controller Bluetooth check"
  if have bluetoothctl; then
    for mac in "${LEFT_CONTROLLER_MAC}" "${RIGHT_CONTROLLER_MAC}"; do
      check_controller_bluetooth "${mac}"
    done
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
  VRPATHREG="$(find_vrpathreg || true)"
  [[ -n "${VRPATHREG}" ]] || die "vrpathreg not found. Install SteamVR or register ${STEAMVR_DRIVER_DIR} manually."
  repair_steamvr_driver_registration "${VRPATHREG}"
  unblock_steamvr_safe_mode
else
  log "SteamVR driver registration"
  printf 'Skipped by option. To register the local driver later, run:\n'
  printf '  %q --register-steamvr --no-launch-steamvr\n' "${ROOT_DIR}/start.sh"
fi

check_display_session
set_x11_headset_non_desktop
write_steamvr_chaperone

if [[ "${WMR_3DOF_ONLY}" -eq 1 ]]; then
  log "WMR tracking mode"
  export WMR_SLAM=false
  printf 'WMR_SLAM=false; using IMU-only 3DoF HMD tracking for this launch.\n'
  if pgrep -x steam >/dev/null 2>&1; then
    warn "Steam is already running; close Steam completely before this test if the rolling continues"
  fi
fi

if [[ "${LAUNCH_STEAMVR}" -eq 1 ]]; then
  log "Launching SteamVR"
  if have steam; then
    prepare_steamvr_launch_environment
    if [[ "${XDG_SESSION_TYPE:-}" == "x11" && "${SET_X11_NON_DESKTOP}" -eq 1 ]]; then
      watch_x11_headset_non_desktop &
    fi
    if pgrep -x steam >/dev/null 2>&1; then
      warn "Steam is already running; if SteamVR reports missing Qt libraries, fully exit Steam and rerun ./start.sh"
    fi
    steam steam://rungameid/250820
  else
    die "steam command not found"
  fi
else
  log "Launch"
  printf 'Skipped by option. To launch SteamVR after checks, run:\n'
  printf '  %q --launch-steamvr --no-register-steamvr\n' "${ROOT_DIR}/start.sh"
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
