# Register port parsing functions in flake-parts nix-lib.
#
# Provides `config.lib.oci.{parseContainerPort,mkExposedPorts,parseContainerPortInt,parseHostPort}`.
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
          file = "nix/modules/oci/lib/ports.nix";
          fn =
            portSpec:
            let
              parts = lib.splitString ":" portSpec;
              raw = if builtins.length parts >= 2 then builtins.elemAt parts 1 else builtins.head parts;
            in
            if lib.hasInfix "/" raw then raw else "${raw}/tcp";
          tests = {
            "parses host:container port" = {
              args = "8080:8080";
              expected = "8080/tcp";
            };
            "preserves protocol" = {
              args = "443:443/udp";
              expected = "443/udp";
            };
            "handles port-only" = {
              args = "8080";
              expected = "8080/tcp";
            };
          };
        };

        mkExposedPorts = {
          type = lib.types.functionTo lib.types.attrs;
          description = ''
            Convert a list of port mapping strings to an OCI `ExposedPorts` attrset.

            Example: `["8080:8080" "443:443"]` → `{ "8080/tcp" = {}; "443/tcp" = {}; }`
          '';
          file = "nix/modules/oci/lib/ports.nix";
          fn =
            ports:
            let
              parseContainerPort =
                portSpec:
                let
                  parts = lib.splitString ":" portSpec;
                  raw = if builtins.length parts >= 2 then builtins.elemAt parts 1 else builtins.head parts;
                in
                if lib.hasInfix "/" raw then raw else "${raw}/tcp";
            in
            builtins.listToAttrs (map (p: lib.nameValuePair (parseContainerPort p) { }) ports);
          tests = {
            "creates ExposedPorts from list" = {
              args = [
                "8080:8080"
                "443:443"
              ];
              expected = {
                "8080/tcp" = { };
                "443/tcp" = { };
              };
            };
          };
        };

        parseContainerPortInt = {
          type = lib.types.functionTo lib.types.int;
          description = ''
            Extract the container port as an integer from a port mapping string.

            - `"8080:8080"` → `8080`
            - `"443:443/udp"` → `443`
            - `"8080"` → `8080` (no host mapping)
          '';
          file = "nix/modules/oci/lib/ports.nix";
          fn =
            portSpec:
            let
              parts = lib.splitString ":" portSpec;
              raw = if builtins.length parts >= 2 then builtins.elemAt parts 1 else builtins.head parts;
              clean = builtins.head (lib.splitString "/" raw);
            in
            lib.toInt clean;
          tests = {
            "parses container port as int" = {
              args = "8080:8080";
              expected = 8080;
            };
            "strips protocol" = {
              args = "443:443/udp";
              expected = 443;
            };
          };
        };

        parseHostPort = {
          type = lib.types.functionTo lib.types.int;
          description = ''
            Extract the host port (as integer) from a port mapping string.

            - `"8080:8080"` → `8080`
            - `"9090:8080"` → `9090`
            - `"8080"` → `8080` (same as container port)
          '';
          file = "nix/modules/oci/lib/ports.nix";
          fn =
            portSpec:
            let
              raw = builtins.head (lib.splitString ":" portSpec);
              clean = builtins.head (lib.splitString "/" raw);
            in
            lib.toInt clean;
          tests = {
            "parses host port" = {
              args = "9090:8080";
              expected = 9090;
            };
            "handles port-only" = {
              args = "8080";
              expected = 8080;
            };
          };
        };
      };
    };
}
