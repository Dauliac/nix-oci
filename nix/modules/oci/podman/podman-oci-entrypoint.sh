#!/bin/sh
set -e

# Start podman socket in background if not running
if ! podman system service --timeout 0 & then
  echo "Warning: Failed to start podman socket"
fi

# Execute the main command
exec "$@"
