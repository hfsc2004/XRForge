#!/usr/bin/env bash

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
