# Register port parsing functions in flake-parts nix-lib.
#
# Provides `config.lib.oci.{parseContainerPort,mkExposedPorts,parseHostPort}`.
{ ... }:
{
  config.perSystem =
    { lib, ... }:
    {
      nix-lib.lib.oci = {
        parseContainerPort = {
          type = lib.types.functionTo lib.types.str;
          description = ''
            Extract the container port from a port mapping string and
            normalize to OCI `ExposedPorts` format (`"port/proto"`).

            - `"8080:8080"` → `"8080/tcp"`
            - `"443:443/udp"` → `"443/udp"`
            - `"8080"` → `"8080/tcp"` (no host mapping)
          '';
          fn =
            portSpec:
            let
              parts = lib.splitString ":" portSpec;
              raw = if builtins.length parts >= 2 then builtins.elemAt parts 1 else builtins.head parts;
              hasProto = lib.hasInfix "/" raw;
            in
            if hasProto then raw else "${raw}/tcp";
        };

        mkExposedPorts = {
          type = lib.types.functionTo lib.types.attrs;
          description = ''
            Convert a list of port mapping strings to an OCI `ExposedPorts` attrset.

            Example: `["8080:8080" "443:443"]` → `{ "8080/tcp" = {}; "443/tcp" = {}; }`
          '';
          fn =
            ports:
            builtins.listToAttrs (
              map (
                p:
                let
                  parts = lib.splitString ":" p;
                  raw = if builtins.length parts >= 2 then builtins.elemAt parts 1 else builtins.head parts;
                  normalized = if lib.hasInfix "/" raw then raw else "${raw}/tcp";
                in
                lib.nameValuePair normalized { }
              ) ports
            );
        };

        parseHostPort = {
          type = lib.types.functionTo lib.types.int;
          description = ''
            Extract the host port (as integer) from a port mapping string.

            - `"8080:8080"` → `8080`
            - `"9090:8080"` → `9090`
            - `"8080"` → `8080` (same as container port)
          '';
          fn =
            portSpec:
            let
              parts = lib.splitString ":" portSpec;
              raw = builtins.head parts;
              # Strip protocol suffix if present
              clean = builtins.head (lib.splitString "/" raw);
            in
            lib.toInt clean;
        };
      };
    };
}
