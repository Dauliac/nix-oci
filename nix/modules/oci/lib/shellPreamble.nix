# Shared shell script preambles for security/testing scripts.
#
# shellPreamble: strict bash error handling
# archivePreamble: shellPreamble + DOCKER_CONFIG + tmpdir with trap
{ ... }:
{
  config.perSystem =
    { lib, ... }:
    {
      nix-lib.lib.oci = {
        shellPreamble = {
          type = lib.types.str;
          description = "Strict bash error handling preamble (errexit, pipefail, nounset).";
          file = "nix/modules/oci/lib/shellPreamble.nix";
          fn = ''
            set -o errexit
            set -o pipefail
            set -o nounset
          '';
        };

        archivePreamble = {
          type = lib.types.str;
          description = "Shell preamble for archive-based tools: strict mode + empty DOCKER_CONFIG + WORK tmpdir with trap.";
          file = "nix/modules/oci/lib/shellPreamble.nix";
          fn = ''
            set -o errexit
            set -o pipefail
            set -o nounset
            # Use empty docker config to avoid credentials helper issues
            export DOCKER_CONFIG="$(mktemp -d)"
            WORK="$(mktemp -d)"
            trap 'rm -rf "$WORK"' EXIT
            cd "$WORK"
          '';
        };
      };
    };
}
