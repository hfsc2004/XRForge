#!/usr/bin/env bash

XRFORGE_VERSION="${XRFORGE_VERSION:-0.2.1}"
MONADO_DIR="${ROOT_DIR}/monado-source"
BUILD_DIR="${MONADO_DIR}/build-steamvr-minimal"
OPENXR_JSON="${BUILD_DIR}/openxr_monado-dev.json"
STEAMVR_DRIVER_DIR="${BUILD_DIR}/steamvr-monado"
STEAMVR_DRIVER_SO="${STEAMVR_DRIVER_DIR}/bin/linux64/driver_monado.so"
STEAMVR_DIR="${HOME}/.local/share/Steam/steamapps/common/SteamVR"
STEAMVR_CONFIG_DIR="${HOME}/.local/share/Steam/config"
STEAMVR_CHAPERONE_FILE="${STEAMVR_CONFIG_DIR}/chaperone_info.vrchap"

LEFT_CONTROLLER_MAC="${XRFORGE_LEFT_CONTROLLER_MAC:-D8:C4:97:C9:12:38}"
RIGHT_CONTROLLER_MAC="${XRFORGE_RIGHT_CONTROLLER_MAC:-D8:C4:97:C9:18:94}"
X11_HEADSET_OUTPUT_CACHE="${XRFORGE_X11_HEADSET_OUTPUT_CACHE:-${ROOT_DIR}/.xrforge-headset-output}"
WMR_CONTROLLER_FALLBACK_X="${WMR_CONTROLLER_FALLBACK_X:-0.14}"
WMR_CONTROLLER_FALLBACK_Y="${WMR_CONTROLLER_FALLBACK_Y:--0.28}"
WMR_CONTROLLER_FALLBACK_Z="${WMR_CONTROLLER_FALLBACK_Z:--0.10}"
WMR_CONTROLLER_FALLBACK_FOLLOW_HMD="${WMR_CONTROLLER_FALLBACK_FOLLOW_HMD:-true}"
WMR_CONTROLLER_AIM_YAW_DEGREES="${WMR_CONTROLLER_AIM_YAW_DEGREES:-65}"
WMR_CONTROLLER_AIM_YAW_DEGREES_LEFT="${WMR_CONTROLLER_AIM_YAW_DEGREES_LEFT:-${WMR_CONTROLLER_AIM_YAW_DEGREES}}"
WMR_CONTROLLER_AIM_YAW_DEGREES_RIGHT="${WMR_CONTROLLER_AIM_YAW_DEGREES_RIGHT:-${WMR_CONTROLLER_AIM_YAW_DEGREES}}"
STEAMVR_EMULATE_INDEX_CONTROLLER="${STEAMVR_EMULATE_INDEX_CONTROLLER:-true}"
WMR_CONTROLLER_BLOB_PIXEL_THRESHOLD="${WMR_CONTROLLER_BLOB_PIXEL_THRESHOLD:-220}"
WMR_CONTROLLER_BLOB_REQUIRED_THRESHOLD="${WMR_CONTROLLER_BLOB_REQUIRED_THRESHOLD:-240}"
WMR_CONTROLLER_BLOB_MAX_WIDTH="${WMR_CONTROLLER_BLOB_MAX_WIDTH:-12}"
WMR_CONTROLLER_BLOB_ALLOW_SINGLE_PIXEL="${WMR_CONTROLLER_BLOB_ALLOW_SINGLE_PIXEL:-false}"
WMR_CONTROLLER_USE_SLAM_FRAMES="${WMR_CONTROLLER_USE_SLAM_FRAMES:-true}"
WMR_CONTROLLER_MAX_BRIGHT_FRACTION="${WMR_CONTROLLER_MAX_BRIGHT_FRACTION:-0.08}"
WMR_CONTROLLER_MIN_BRIGHT_PIXELS="${WMR_CONTROLLER_MIN_BRIGHT_PIXELS:-0}"
WMR_CONTROLLER_MAX_BRIGHT_PIXELS="${WMR_CONTROLLER_MAX_BRIGHT_PIXELS:-0}"
WMR_CONTROLLER_ZERO_COMMAND="${WMR_CONTROLLER_ZERO_COMMAND:-false}"
WMR_CONTROLLER_TASK_RESTART="${WMR_CONTROLLER_TASK_RESTART:-false}"
WMR_CONTROLLER_ENABLE_REPORT_COMMANDS="${WMR_CONTROLLER_ENABLE_REPORT_COMMANDS:-false}"
WMR_CONTROLLER_MIN_MATCHED_BLOBS="${WMR_CONTROLLER_MIN_MATCHED_BLOBS:-4}"
WMR_CONTROLLER_MAX_REPROJECTION_ERROR="${WMR_CONTROLLER_MAX_REPROJECTION_ERROR:-35}"
WMR_CONTROLLER_MAX_POSITION_JUMP="${WMR_CONTROLLER_MAX_POSITION_JUMP:-0.18}"
WMR_CONTROLLER_OPTICAL_POSITION_ALPHA="${WMR_CONTROLLER_OPTICAL_POSITION_ALPHA:-0.25}"
WMR_CONTROLLER_REACQUIRE_AFTER_REJECTS="${WMR_CONTROLLER_REACQUIRE_AFTER_REJECTS:-8}"
WMR_CONTROLLER_DUMP_FRAMES="${WMR_CONTROLLER_DUMP_FRAMES:-0}"
WMR_CONTROLLER_DUMP_SKIP_FRAMES="${WMR_CONTROLLER_DUMP_SKIP_FRAMES:-300}"
WMR_CONTROLLER_DUMP_INTERVAL="${WMR_CONTROLLER_DUMP_INTERVAL:-180}"

SKIP_BUILD=0
REGISTER_STEAMVR=1
LAUNCH_STEAMVR=1
CHECK_BLUETOOTH=1
CONNECT_BLUETOOTH=1
SET_X11_NON_DESKTOP=1
WMR_3DOF_ONLY=0
X11_NON_DESKTOP_WATCH_SECONDS="${XRFORGE_X11_NON_DESKTOP_WATCH_SECONDS:-30}"
XRFORGE_STEAMVR_CHAPERONE="${XRFORGE_STEAMVR_CHAPERONE:-true}"
XRFORGE_STEAMVR_PLAY_AREA="${XRFORGE_STEAMVR_PLAY_AREA:-3.0}"
XRFORGE_STEAMVR_STANDING_X="${XRFORGE_STEAMVR_STANDING_X:-}"
XRFORGE_STEAMVR_STANDING_Y="${XRFORGE_STEAMVR_STANDING_Y:-}"
XRFORGE_STEAMVR_STANDING_Z="${XRFORGE_STEAMVR_STANDING_Z:-}"
XRFORGE_STEAMVR_STANDING_YAW="${XRFORGE_STEAMVR_STANDING_YAW:-}"

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

ensure_not_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    die "do not run this script with sudo; SteamVR driver registration and config belong to your user account"
  fi
}

usage() {
  cat <<EOF
XRForge ${XRFORGE_VERSION} WMR-compatible XR SteamVR session starter

Usage:
  ./start.sh [options]

Options:
  --check-only             Run checks, but do not register SteamVR or launch it.
  --skip-build             Do not run ninja before startup checks.
  --no-register-steamvr    Do not register the local Monado SteamVR driver.
  --no-launch-steamvr      Do not launch SteamVR after checks.
  --no-bluetooth           Skip Bluetooth controller status checks.
  --no-bluetooth-connect   Check Bluetooth status, but do not reconnect controllers.
  --no-x11-non-desktop     Do not mark the detected X11 headset output non-desktop.
  --wmr-3dof               Disable WMR SLAM and use IMU-only 3DoF HMD tracking.
  --register-steamvr       Explicitly enable SteamVR driver registration.
  --launch-steamvr         Explicitly enable SteamVR launch.
  -h, --help               Show this help.

Environment:
  XRFORGE_LEFT_CONTROLLER_MAC   Defaults to ${LEFT_CONTROLLER_MAC}
  XRFORGE_RIGHT_CONTROLLER_MAC  Defaults to ${RIGHT_CONTROLLER_MAC}
  XRFORGE_X11_HEADSET_OUTPUT    Override detected X11 headset output.
  XRFORGE_X11_HEADSET_OUTPUT_CACHE
                                Defaults to ${X11_HEADSET_OUTPUT_CACHE}
  XRFORGE_X11_NON_DESKTOP_WATCH_SECONDS
                                Seconds to watch for WMR display hotplug during launch.
  XRFORGE_STEAMVR_CHAPERONE     Write a centered SteamVR chaperone; default true.
  XRFORGE_STEAMVR_PLAY_AREA     Centered play-area size in meters; default 3.0.
  XRFORGE_STEAMVR_STANDING_X/Y/Z/YAW
                                Standing transform override; default preserves SteamVR.
  WMR_CONTROLLER_FALLBACK_X/Y/Z Simulated controller offset from HMD position.
  WMR_CONTROLLER_FALLBACK_FOLLOW_HMD
                                Keep fallback controllers attached to HMD position.
  WMR_CONTROLLER_AIM_YAW_DEGREES
  WMR_CONTROLLER_AIM_YAW_DEGREES_LEFT/RIGHT
                                Shared or per-hand aim-pose yaw correction.
  STEAMVR_EMULATE_INDEX_CONTROLLER
                                Present controllers as Index controllers; default true.
  WMR_CONTROLLER_BLOB_*         Optical controller LED blob detector tuning.
  WMR_CONTROLLER_USE_SLAM_FRAMES
                                Feed normal SLAM frames to controller tracking; default true.
  WMR_CONTROLLER_MIN/MAX_BRIGHT_PIXELS
  WMR_CONTROLLER_MAX_BRIGHT_FRACTION
                                Optical-controller frame gates.
  WMR_CONTROLLER_TASK_RESTART   Send controller task restart init command; default false.
  WMR_CONTROLLER_ZERO_COMMAND   Send controller zero/reinit init command; default false.
  WMR_CONTROLLER_ENABLE_REPORT_COMMANDS
                                Send startup status/IMU report enable commands; default false.
  WMR_CONTROLLER_MIN_MATCHED_BLOBS
  WMR_CONTROLLER_MAX_REPROJECTION_ERROR
  WMR_CONTROLLER_MAX_POSITION_JUMP
  WMR_CONTROLLER_OPTICAL_POSITION_ALPHA
  WMR_CONTROLLER_REACQUIRE_AFTER_REJECTS
                                Optical pose quality gates and smoothing.
  WMR_CONTROLLER_DUMP_FRAMES    Dump controller camera frames to /tmp.

Pair and trust controllers once with bluetoothctl; after that XRForge can
reconnect them automatically.
EOF
}

export_runtime_environment() {
  export XR_RUNTIME_JSON="${OPENXR_JSON}"
  export WMR_CONTROLLER_FALLBACK_X WMR_CONTROLLER_FALLBACK_Y WMR_CONTROLLER_FALLBACK_Z
  export WMR_CONTROLLER_FALLBACK_FOLLOW_HMD
  export WMR_CONTROLLER_AIM_YAW_DEGREES
  export WMR_CONTROLLER_AIM_YAW_DEGREES_LEFT WMR_CONTROLLER_AIM_YAW_DEGREES_RIGHT
  export STEAMVR_EMULATE_INDEX_CONTROLLER
  export WMR_CONTROLLER_BLOB_PIXEL_THRESHOLD WMR_CONTROLLER_BLOB_REQUIRED_THRESHOLD
  export WMR_CONTROLLER_BLOB_MAX_WIDTH WMR_CONTROLLER_BLOB_ALLOW_SINGLE_PIXEL
  export WMR_CONTROLLER_USE_SLAM_FRAMES WMR_CONTROLLER_MAX_BRIGHT_FRACTION
  export WMR_CONTROLLER_MIN_BRIGHT_PIXELS WMR_CONTROLLER_MAX_BRIGHT_PIXELS
  export WMR_CONTROLLER_ZERO_COMMAND WMR_CONTROLLER_TASK_RESTART
  export WMR_CONTROLLER_ENABLE_REPORT_COMMANDS
  export WMR_CONTROLLER_MIN_MATCHED_BLOBS WMR_CONTROLLER_MAX_REPROJECTION_ERROR
  export WMR_CONTROLLER_MAX_POSITION_JUMP WMR_CONTROLLER_OPTICAL_POSITION_ALPHA
  export WMR_CONTROLLER_REACQUIRE_AFTER_REJECTS
  export WMR_CONTROLLER_DUMP_FRAMES WMR_CONTROLLER_DUMP_SKIP_FRAMES WMR_CONTROLLER_DUMP_INTERVAL
}

print_runtime_summary() {
  log "Runtime paths"
  printf 'XRForge version=%s\n' "${XRFORGE_VERSION}"
  printf 'XR_RUNTIME_JSON=%s\n' "${XR_RUNTIME_JSON}"
  printf 'SteamVR driver=%s\n' "${STEAMVR_DRIVER_DIR}"
  printf 'WMR controller fallback offset: follow_hmd=%s +/-X=%s Y=%s Z=%s\n' \
    "${WMR_CONTROLLER_FALLBACK_FOLLOW_HMD}" \
    "${WMR_CONTROLLER_FALLBACK_X}" "${WMR_CONTROLLER_FALLBACK_Y}" "${WMR_CONTROLLER_FALLBACK_Z}"
  printf 'WMR controller aim yaw: left=%s right=%s\n' \
    "${WMR_CONTROLLER_AIM_YAW_DEGREES_LEFT}" "${WMR_CONTROLLER_AIM_YAW_DEGREES_RIGHT}"
  printf 'WMR controller init writes: zero=%s task_restart=%s report_enable=%s\n' \
    "${WMR_CONTROLLER_ZERO_COMMAND}" "${WMR_CONTROLLER_TASK_RESTART}" "${WMR_CONTROLLER_ENABLE_REPORT_COMMANDS}"
  printf 'SteamVR controller emulation: index=%s\n' "${STEAMVR_EMULATE_INDEX_CONTROLLER}"
  if [[ "${WMR_CONTROLLER_DUMP_FRAMES}" != "0" ]]; then
    printf 'WMR controller camera frame dumps: %s frames per camera to /tmp after skip=%s interval=%s\n' \
      "${WMR_CONTROLLER_DUMP_FRAMES}" "${WMR_CONTROLLER_DUMP_SKIP_FRAMES}" "${WMR_CONTROLLER_DUMP_INTERVAL}"
  fi
}
