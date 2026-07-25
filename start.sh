#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
  XRFORGE_STEAMVR_CHAPERONE
                                Write a centered SteamVR chaperone before launch;
                                default true.
  XRFORGE_STEAMVR_PLAY_AREA     Centered play-area size in meters; default 3.0.
  XRFORGE_STEAMVR_STANDING_X/Y/Z/YAW
                                Standing transform override. By default XRForge
                                preserves the existing SteamVR transform.
  WMR_CONTROLLER_FALLBACK_X/Y/Z Simulated controller offset from HMD position.
  WMR_CONTROLLER_FALLBACK_FOLLOW_HMD
                                Keep fallback controllers attached to HMD position.
  WMR_CONTROLLER_AIM_YAW_DEGREES
                                Aim-pose yaw correction; default 65.
  WMR_CONTROLLER_BLOB_PIXEL_THRESHOLD
  WMR_CONTROLLER_BLOB_REQUIRED_THRESHOLD
  WMR_CONTROLLER_BLOB_MAX_WIDTH
  WMR_CONTROLLER_BLOB_ALLOW_SINGLE_PIXEL
                                Optical controller LED blob detector tuning.
  WMR_CONTROLLER_USE_SLAM_FRAMES
                                Also feed normal headset SLAM frames to optical
                                controller tracking; default true.
  WMR_CONTROLLER_MAX_BRIGHT_FRACTION
                                Drop optical-controller candidate frames when too
                                much of the image is bright; default 0.08.
  WMR_CONTROLLER_MIN_BRIGHT_PIXELS
  WMR_CONTROLLER_MAX_BRIGHT_PIXELS
                                Drop dark/no-signal and flooded candidate frames;
                                disabled by default; set nonzero to enable.
  WMR_CONTROLLER_TASK_RESTART   Send controller task restart init command; default false.
  WMR_CONTROLLER_ZERO_COMMAND   Send controller zero/reinit init command; default false.
  WMR_CONTROLLER_MIN_MATCHED_BLOBS
  WMR_CONTROLLER_MAX_REPROJECTION_ERROR
  WMR_CONTROLLER_MAX_POSITION_JUMP
  WMR_CONTROLLER_OPTICAL_POSITION_ALPHA
  WMR_CONTROLLER_REACQUIRE_AFTER_REJECTS
                                Optical controller pose quality gates and smoothing.
  WMR_CONTROLLER_DUMP_FRAMES    Dump this many bright controller camera frames per
                                camera to /tmp/xrforge-wmr-controller-cam*.pgm.
  WMR_CONTROLLER_DUMP_SKIP_FRAMES
  WMR_CONTROLLER_DUMP_INTERVAL  Skip startup frames, then dump one frame per
                                interval while WMR_CONTROLLER_DUMP_FRAMES is set.

By default this script prepares the local Monado build, registers the SteamVR
driver, checks the WMR-compatible XR hardware state, and launches SteamVR. It
does not pair Bluetooth devices for the first time. Pair and trust controllers
once with bluetoothctl; after that XRForge can reconnect them automatically.
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

ensure_not_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    die "do not run this script with sudo; SteamVR driver registration and config belong to your user account"
  fi
}

configure_monado_build() {
  have cmake || die "cmake is required to configure ${BUILD_DIR}"
  have ninja || die "ninja is required to build ${BUILD_DIR}"

  cmake --fresh \
    -S "${MONADO_DIR}" \
    -B "${BUILD_DIR}" \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DXRT_FEATURE_STEAMVR_PLUGIN=ON \
    -DXRT_BUILD_DRIVER_WMR=ON \
    -DXRT_FEATURE_SERVICE=ON \
    -DCMAKE_DISABLE_FIND_PACKAGE_OpenCV=ON
}

ensure_monado_build_config() {
  local cache_file="${BUILD_DIR}/CMakeCache.txt"
  local cached_source=""
  local cached_build=""

  if [[ ! -f "${cache_file}" ]]; then
    log "Configuring Monado build"
    configure_monado_build
    return
  fi

  cached_source="$(sed -n 's/^CMAKE_HOME_DIRECTORY:INTERNAL=//p' "${cache_file}" | tail -n 1)"
  cached_build="$(sed -n 's/^CMAKE_CACHEFILE_DIR:INTERNAL=//p' "${cache_file}" | tail -n 1)"

  if [[ "${cached_source}" != "${MONADO_DIR}" || "${cached_build}" != "${BUILD_DIR}" ]]; then
    log "Refreshing moved Monado build"
    printf 'Previous source: %s\n' "${cached_source:-unknown}"
    printf 'Current source:  %s\n' "${MONADO_DIR}"
    configure_monado_build
  fi
}

ensure_steamvr_driver_runpath() {
  [[ -f "${STEAMVR_DRIVER_SO}" ]] || return

  if readelf -d "${STEAMVR_DRIVER_SO}" | grep -q 'RUNPATH.*\[$ORIGIN\]'; then
    return
  fi

  have patchelf || die "patchelf is required to make SteamVR load bundled Monado driver libraries"
  patchelf --set-rpath '$ORIGIN' "${STEAMVR_DRIVER_SO}"
}

find_vrpathreg() {
  for candidate in \
    "${STEAMVR_DIR}/bin/linux64/vrpathreg" \
    "${HOME}/.steam/steam/steamapps/common/SteamVR/bin/linux64/vrpathreg" \
    "${HOME}/.local/share/Steam/steamapps/common/SteamVR/bin/linux64/vrpathreg"; do
    if [[ -x "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  return 1
}

run_vrpathreg() {
  local vrpathreg="$1"
  shift

  LD_LIBRARY_PATH="$(dirname "${vrpathreg}"):${STEAMVR_DIR}/bin:${LD_LIBRARY_PATH:-}" "${vrpathreg}" "$@"
}

unblock_steamvr_safe_mode() {
  local changed=0
  local settings_file

  for settings_file in \
    "${STEAMVR_CONFIG_DIR}/steamvr.vrsettings" \
    "${HOME}/.steam/steam/config/steamvr.vrsettings"; do
    [[ -f "${settings_file}" ]] || continue

    if grep -q '"blocked_by_safe_mode"[[:space:]]*:[[:space:]]*true' "${settings_file}"; then
      perl -0pi -e 's/"blocked_by_safe_mode"\s*:\s*true/"blocked_by_safe_mode" : false/g' "${settings_file}"
      printf 'Unblocked Monado safe mode flag in %s\n' "${settings_file}"
      changed=1
    fi
  done

  [[ "${changed}" -eq 1 ]] || printf 'No Monado safe mode block found.\n'
}

repair_steamvr_driver_registration() {
  local vrpathreg="$1"
  local registered_path
  local show_output

  show_output="$(run_vrpathreg "${vrpathreg}" show)"

  while IFS= read -r registered_path; do
    [[ -n "${registered_path}" ]] || continue
    [[ "${registered_path}" == "${STEAMVR_DRIVER_DIR}" ]] && continue
    [[ "${registered_path}" == *monado* ]] || continue

    printf 'Removing stale Monado SteamVR driver path: %s\n' "${registered_path}"
    run_vrpathreg "${vrpathreg}" removedriver "${registered_path}" || true
  done < <(printf '%s\n' "${show_output}" | sed -n 's/^[[:space:]]*.* : //p')

  run_vrpathreg "${vrpathreg}" adddriver "${STEAMVR_DRIVER_DIR}"
}

check_display_session() {
  log "Desktop display session"
  printf 'XDG_SESSION_TYPE=%s\n' "${XDG_SESSION_TYPE:-unknown}"
  printf 'DISPLAY=%s\n' "${DISPLAY:-unset}"
  printf 'WAYLAND_DISPLAY=%s\n' "${WAYLAND_DISPLAY:-unset}"

  if [[ "${XDG_SESSION_TYPE:-}" == "x11" ]]; then
    printf 'X11 detected; XRForge will mark the detected headset output non-desktop before SteamVR launch.\n'
  fi
}

prepare_steamvr_launch_environment() {
  local steamvr_bin="${STEAMVR_DIR}/bin/linux64"
  local steamvr_qt="${steamvr_bin}/qt/lib"

  if [[ -d "${steamvr_bin}" && -d "${steamvr_qt}" ]]; then
    export LD_LIBRARY_PATH="${steamvr_bin}:${steamvr_qt}:${LD_LIBRARY_PATH:-}"
  fi
}

write_steamvr_chaperone() {
  [[ "${XRFORGE_STEAMVR_CHAPERONE}" == "true" ]] || {
    log "SteamVR chaperone"
    printf 'Skipped by XRFORGE_STEAMVR_CHAPERONE=%s.\n' "${XRFORGE_STEAMVR_CHAPERONE}"
    return 0
  }

  mkdir -p "${STEAMVR_CONFIG_DIR}"

  local area="${XRFORGE_STEAMVR_PLAY_AREA}"
  local half
  half="$(awk -v area="${area}" 'BEGIN { printf "%.6f", area / 2.0 }')"
  local now
  now="$(date '+%a %b %d %H:%M:%S %Y')"

  if [[ -f "${STEAMVR_CHAPERONE_FILE}" && ! -f "${STEAMVR_CHAPERONE_FILE}.xrforge-backup" ]]; then
    cp "${STEAMVR_CHAPERONE_FILE}" "${STEAMVR_CHAPERONE_FILE}.xrforge-backup"
  fi

  local source_chaperone="${STEAMVR_CHAPERONE_FILE}.xrforge-backup"
  if [[ ! -f "${source_chaperone}" ]]; then
    source_chaperone="${STEAMVR_CHAPERONE_FILE}"
  fi

  local standing_x="${XRFORGE_STEAMVR_STANDING_X}"
  local standing_y="${XRFORGE_STEAMVR_STANDING_Y}"
  local standing_z="${XRFORGE_STEAMVR_STANDING_Z}"
  local standing_yaw="${XRFORGE_STEAMVR_STANDING_YAW}"

  if [[ -f "${source_chaperone}" ]]; then
    local parsed_transform
    parsed_transform="$(awk '
      /"standing"[[:space:]]*:/ { in_standing = 1 }
      in_standing && /"translation"[[:space:]]*:/ {
        line = $0
        gsub(/[][,"\t]/, " ", line)
        fields = split(line, parts, /[[:space:]]+/)
        for (i = 1; i <= fields; i++) {
          if (parts[i] ~ /^-?[0-9]+(\.[0-9]+)?$/) {
            values[++count] = parts[i]
          }
        }
      }
      in_standing && /"yaw"[[:space:]]*:/ {
        yaw = $0
        gsub(/[][,"\t]/, " ", yaw)
        fields = split(yaw, parts, /[[:space:]]+/)
        for (i = 1; i <= fields; i++) {
          if (parts[i] ~ /^-?[0-9]+(\.[0-9]+)?$/) {
            values[++count] = parts[i]
          }
        }
        if (count >= 4) {
          printf "%s %s %s %s\n", values[1], values[2], values[3], values[4]
        }
        exit
      }
    ' "${source_chaperone}")"

    if [[ -n "${parsed_transform}" ]]; then
      read -r parsed_x parsed_y parsed_z parsed_yaw <<<"${parsed_transform}"
      standing_x="${standing_x:-${parsed_x}}"
      standing_y="${standing_y:-${parsed_y}}"
      standing_z="${standing_z:-${parsed_z}}"
      standing_yaw="${standing_yaw:-${parsed_yaw}}"
    fi
  fi

  standing_x="${standing_x:-0}"
  standing_y="${standing_y:--0.77}"
  standing_z="${standing_z:-0}"
  standing_yaw="${standing_yaw:-0}"

  log "SteamVR chaperone"
  printf 'Writing centered %.1fm x %.1fm play area to %s\n' "${area}" "${area}" "${STEAMVR_CHAPERONE_FILE}"
  printf 'SteamVR standing transform: translation=[%s, %s, %s] yaw=%s\n' \
    "${standing_x}" "${standing_y}" "${standing_z}" "${standing_yaw}"

  cat >"${STEAMVR_CHAPERONE_FILE}" <<EOF
{
   "jsonid" : "chaperone_info",
   "universes" : [
      {
         "collision_bounds" : [
            [
               [ -${half}, 0, -${half} ],
               [ -${half}, 2.43000007, -${half} ],
               [ -${half}, 2.43000007, ${half} ],
               [ -${half}, 0, ${half} ]
            ],
            [
               [ -${half}, 0, ${half} ],
               [ -${half}, 2.43000007, ${half} ],
               [ ${half}, 2.43000007, ${half} ],
               [ ${half}, 0, ${half} ]
            ],
            [
               [ ${half}, 0, ${half} ],
               [ ${half}, 2.43000007, ${half} ],
               [ ${half}, 2.43000007, -${half} ],
               [ ${half}, 0, -${half} ]
            ],
            [
               [ ${half}, 0, -${half} ],
               [ ${half}, 2.43000007, -${half} ],
               [ -${half}, 2.43000007, -${half} ],
               [ -${half}, 0, -${half} ]
            ]
         ],
         "play_area" : [ ${area}, ${area} ],
         "setup_standing2" : {
            "translation" : [ ${standing_x}, ${standing_y}, ${standing_z} ],
            "yaw" : ${standing_yaw}
         },
         "standing" : {
            "translation" : [ ${standing_x}, ${standing_y}, ${standing_z} ],
            "yaw" : ${standing_yaw}
         },
         "time" : "${now}",
         "universeID" : "2"
      }
   ],
   "version" : 5
}
EOF
}

x11_output_exists() {
  local output="$1"

  xrandr --query | awk -v output="${output}" '$1 == output { found = 1 } END { exit found ? 0 : 1 }'
}

read_cached_x11_headset_output() {
  local output=""

  [[ -f "${X11_HEADSET_OUTPUT_CACHE}" ]] || return 1
  output="$(sed -n '1p' "${X11_HEADSET_OUTPUT_CACHE}")"
  [[ "${output}" =~ ^[A-Za-z0-9._:-]+$ ]] || return 1
  x11_output_exists "${output}" || return 1

  printf '%s\n' "${output}"
}

cache_x11_headset_output() {
  local output="$1"

  printf '%s\n' "${output}" >"${X11_HEADSET_OUTPUT_CACHE}"
}

find_x11_headset_output() {
  local output=""

  if [[ -n "${XRFORGE_X11_HEADSET_OUTPUT:-}" ]]; then
    printf '%s\n' "${XRFORGE_X11_HEADSET_OUTPUT}"
    return 0
  fi

  output="$(read_cached_x11_headset_output || true)"
  if [[ -n "${output}" ]]; then
    printf '%s\n' "${output}"
    return 0
  fi

  xrandr --verbose | awk '
    function finish() {
      if ((connected || non_desktop_one) && non_desktop_seen && score >= 60) {
        printf "%03d %s\n", score, output
      }
    }

    /^[^[:space:]].* (connected|disconnected)/ {
      finish()
      output = $1
      connected = ($2 == "connected")
      score = 0
      non_desktop_seen = 0
      non_desktop_one = 0

      if (connected) {
        for (i = 1; i <= NF; i++) {
          if ($i == "x" && $(i - 1) ~ /^[0-9]+mm$/ && $(i + 1) ~ /^[0-9]+mm$/) {
            width = $(i - 1)
            height = $(i + 1)
            sub("mm", "", width)
            sub("mm", "", height)
            if (width > 0 && height > 0 && width <= 180 && height <= 120) {
              score += 40
            }
          }
        }
      }
      next
    }

    /^[[:space:]]+non-desktop:/ {
      non_desktop_seen = 1
      score += 20
      if ($2 == "1") {
        non_desktop_one = 1
        score += 40
      }
      next
    }

    /^[[:space:]]+[0-9]+x[0-9]+/ {
      if ($1 == "4320x2160") {
        score += 35
      } else if ($1 == "2880x1440") {
        score += 25
      } else if ($1 == "2160x2160") {
        score += 15
      }
      if ($0 ~ /\*current/ || $0 ~ /\+preferred/) {
        score += 5
      }
      next
    }

    END {
      finish()
    }
  ' | sort -k1,1nr -k2,2 | sed -n '1s/^[0-9][0-9][0-9] //p'
}

apply_x11_headset_direct_mode() {
  local output="$1"

  cache_x11_headset_output "${output}"

  if xrandr --output "${output}" --set non-desktop 1; then
    printf 'Set %s non-desktop=1 for SteamVR direct mode.\n' "${output}"
  else
    warn "failed to set ${output} non-desktop=1"
  fi

  if xrandr --output "${output}" --off; then
    printf 'Removed %s from the X11 desktop layout.\n' "${output}"
  else
    warn "failed to remove ${output} from the X11 desktop layout"
  fi
}

set_x11_headset_non_desktop() {
  local output=""

  [[ "${XDG_SESSION_TYPE:-}" == "x11" ]] || return 0

  log "X11 headset display mode"

  if [[ "${SET_X11_NON_DESKTOP}" -eq 0 ]]; then
    printf 'Skipped by option.\n'
    return 0
  fi

  if ! have xrandr; then
    warn "xrandr unavailable; cannot mark the headset output non-desktop"
    return 0
  fi

  output="$(find_x11_headset_output || true)"
  if [[ -z "${output}" ]]; then
    warn "could not identify a connected XR headset display output from xrandr"
    warn "if the headset display is visible in xrandr, rerun with XRFORGE_X11_HEADSET_OUTPUT=<output>"
    warn "example: XRFORGE_X11_HEADSET_OUTPUT=DP-0 ./start.sh"
    return 0
  fi

  printf 'Detected X11 headset output: %s\n' "${output}"
  apply_x11_headset_direct_mode "${output}"
}

watch_x11_headset_non_desktop() {
  local deadline=$((SECONDS + X11_NON_DESKTOP_WATCH_SECONDS))
  local output=""

  [[ "${XDG_SESSION_TYPE:-}" == "x11" ]] || return 0
  [[ "${SET_X11_NON_DESKTOP}" -eq 1 ]] || return 0
  have xrandr || return 0

  while [[ "${SECONDS}" -lt "${deadline}" ]]; do
    output="$(find_x11_headset_output || true)"
    if [[ -n "${output}" ]]; then
      printf 'Detected X11 headset output during SteamVR launch: %s\n' "${output}"
      apply_x11_headset_direct_mode "${output}"
      return 0
    fi
    sleep 1
  done
}

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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-build)
      SKIP_BUILD=1
      ;;
    --check-only)
      REGISTER_STEAMVR=0
      LAUNCH_STEAMVR=0
      ;;
    --register-steamvr)
      REGISTER_STEAMVR=1
      ;;
    --launch-steamvr)
      LAUNCH_STEAMVR=1
      ;;
    --no-register-steamvr)
      REGISTER_STEAMVR=0
      ;;
    --no-launch-steamvr)
      LAUNCH_STEAMVR=0
      ;;
    --no-bluetooth)
      CHECK_BLUETOOTH=0
      ;;
    --no-bluetooth-connect)
      CONNECT_BLUETOOTH=0
      ;;
    --no-x11-non-desktop)
      SET_X11_NON_DESKTOP=0
      ;;
    --wmr-3dof)
      WMR_3DOF_ONLY=1
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

ensure_not_root

[[ -d "${MONADO_DIR}" ]] || die "Monado source tree not found: ${MONADO_DIR}"
mkdir -p "${BUILD_DIR}"

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

export XR_RUNTIME_JSON="${OPENXR_JSON}"
export WMR_CONTROLLER_FALLBACK_X
export WMR_CONTROLLER_FALLBACK_Y
export WMR_CONTROLLER_FALLBACK_Z
export WMR_CONTROLLER_FALLBACK_FOLLOW_HMD
export WMR_CONTROLLER_AIM_YAW_DEGREES
export WMR_CONTROLLER_BLOB_PIXEL_THRESHOLD
export WMR_CONTROLLER_BLOB_REQUIRED_THRESHOLD
export WMR_CONTROLLER_BLOB_MAX_WIDTH
export WMR_CONTROLLER_BLOB_ALLOW_SINGLE_PIXEL
export WMR_CONTROLLER_USE_SLAM_FRAMES
export WMR_CONTROLLER_MAX_BRIGHT_FRACTION
export WMR_CONTROLLER_MIN_BRIGHT_PIXELS
export WMR_CONTROLLER_MAX_BRIGHT_PIXELS
export WMR_CONTROLLER_ZERO_COMMAND
export WMR_CONTROLLER_TASK_RESTART
export WMR_CONTROLLER_MIN_MATCHED_BLOBS
export WMR_CONTROLLER_MAX_REPROJECTION_ERROR
export WMR_CONTROLLER_MAX_POSITION_JUMP
export WMR_CONTROLLER_OPTICAL_POSITION_ALPHA
export WMR_CONTROLLER_REACQUIRE_AFTER_REJECTS
export WMR_CONTROLLER_DUMP_FRAMES
export WMR_CONTROLLER_DUMP_SKIP_FRAMES
export WMR_CONTROLLER_DUMP_INTERVAL

log "Runtime paths"
printf 'XRForge version=%s\n' "${XRFORGE_VERSION}"
printf 'XR_RUNTIME_JSON=%s\n' "${XR_RUNTIME_JSON}"
printf 'SteamVR driver=%s\n' "${STEAMVR_DRIVER_DIR}"
printf 'WMR controller fallback offset: follow_hmd=%s +/-X=%s Y=%s Z=%s\n' \
  "${WMR_CONTROLLER_FALLBACK_FOLLOW_HMD}" \
  "${WMR_CONTROLLER_FALLBACK_X}" "${WMR_CONTROLLER_FALLBACK_Y}" "${WMR_CONTROLLER_FALLBACK_Z}"
if [[ "${WMR_CONTROLLER_DUMP_FRAMES}" != "0" ]]; then
  printf 'WMR controller camera frame dumps: %s frames per camera to /tmp/xrforge-wmr-controller-cam*.pgm after skip=%s interval=%s\n' \
    "${WMR_CONTROLLER_DUMP_FRAMES}" "${WMR_CONTROLLER_DUMP_SKIP_FRAMES}" "${WMR_CONTROLLER_DUMP_INTERVAL}"
fi

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
