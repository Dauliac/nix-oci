#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -x

cleanup() {
  if [[ -n ${PODMAN_PID:-} ]]; then
    kill "${PODMAN_PID}" || true
  fi
  if [[ -n ${PODMAN_SOCKET_DIR:-} && -d ${PODMAN_SOCKET_DIR} ]]; then
    rm -rf "${PODMAN_SOCKET_DIR}"
  fi
}
trap cleanup EXIT

main() {
  local -r command="$*"

  PODMAN_SOCKET_DIR=$(mktemp -d)
  declare -rgx PODMAN_SOCKET_DIR
  DOCKER_HOST="unix://${PODMAN_SOCKET_DIR}/podman.sock"
  declare -rgx DOCKER_HOST
  podman system service --time=0 "${DOCKER_HOST}" &
  PODMAN_PID=$!
  declare -rgx PODMAN_PID
  if ! podman info >/dev/null 2>&1; then
    echo "Podman service failed to start" >&2
    exit 1
  fi
  exec "$command"
}

main "$@"
