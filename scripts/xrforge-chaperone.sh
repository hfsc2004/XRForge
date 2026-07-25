#!/usr/bin/env bash

parse_steamvr_standing_transform() {
  local source_chaperone="$1"

  awk '
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
  ' "${source_chaperone}"
}

resolve_steamvr_standing_transform() {
  local source_chaperone="$1"
  local parsed_transform=""
  standing_x="${XRFORGE_STEAMVR_STANDING_X}"
  standing_y="${XRFORGE_STEAMVR_STANDING_Y}"
  standing_z="${XRFORGE_STEAMVR_STANDING_Z}"
  standing_yaw="${XRFORGE_STEAMVR_STANDING_YAW}"

  if [[ -f "${source_chaperone}" ]]; then
    parsed_transform="$(parse_steamvr_standing_transform "${source_chaperone}")"
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
}

write_steamvr_chaperone_file() {
  local area="$1"
  local half="$2"
  local now="$3"

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

write_steamvr_chaperone() {
  [[ "${XRFORGE_STEAMVR_CHAPERONE}" == "true" ]] || {
    log "SteamVR chaperone"
    printf 'Skipped by XRFORGE_STEAMVR_CHAPERONE=%s.\n' "${XRFORGE_STEAMVR_CHAPERONE}"
    return 0
  }

  mkdir -p "${STEAMVR_CONFIG_DIR}"
  local area="${XRFORGE_STEAMVR_PLAY_AREA}"
  local half
  local now
  local source_chaperone="${STEAMVR_CHAPERONE_FILE}.xrforge-backup"

  half="$(awk -v area="${area}" 'BEGIN { printf "%.6f", area / 2.0 }')"
  now="$(date '+%a %b %d %H:%M:%S %Y')"
  if [[ -f "${STEAMVR_CHAPERONE_FILE}" && ! -f "${STEAMVR_CHAPERONE_FILE}.xrforge-backup" ]]; then
    cp "${STEAMVR_CHAPERONE_FILE}" "${STEAMVR_CHAPERONE_FILE}.xrforge-backup"
  fi
  [[ -f "${source_chaperone}" ]] || source_chaperone="${STEAMVR_CHAPERONE_FILE}"

  resolve_steamvr_standing_transform "${source_chaperone}"
  log "SteamVR chaperone"
  printf 'Writing centered %.1fm x %.1fm play area to %s\n' "${area}" "${area}" "${STEAMVR_CHAPERONE_FILE}"
  printf 'SteamVR standing transform: translation=[%s, %s, %s] yaw=%s\n' \
    "${standing_x}" "${standing_y}" "${standing_z}" "${standing_yaw}"
  write_steamvr_chaperone_file "${area}" "${half}" "${now}"
}
