# NixOS config: vulnerability DB env vars for offline testing.
#
# Users who need pinned DBs can set these env vars directly:
#   environment.sessionVariables.TRIVY_DB_PATH = "/path/to/db";
#   environment.sessionVariables.GRYPE_DB_PATH = "/path/to/db";
#
# This file is a no-op by default (no DB paths configured).
{ ... }:
{ }
