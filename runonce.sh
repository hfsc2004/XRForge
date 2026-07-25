#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

printf 'runonce.sh has been renamed to start.sh; forwarding to ./start.sh.\n' >&2
exec "${SCRIPT_DIR}/start.sh" "$@"
