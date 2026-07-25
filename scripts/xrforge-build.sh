#!/usr/bin/env bash

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
