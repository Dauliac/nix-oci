#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

main() {
  local -r entrypoint="$*"
  set -x
  # TODO: look at glow to improve output ?
  time $entrypoint
  (
    printf "Entrypoint command terminated\n: %s return: %s\n" "$entrypoint" "$?"
    sleep infinity
  )
}

main "$@"
