# Register container integration check helpers in flake-parts nix-lib.
#
# Provides `config.lib.oci.checks.{parsePortInt,extractPrivilegedPorts,...}`.
# Pure library: nix/lib/container-checks.nix
{ ... }:
let
  checksLib = import ../../../lib/container-checks.nix;
in
{
  config.perSystem =
    { lib, ... }:
    let
      checks = checksLib { inherit lib; };
    in
    {
      nix-lib.lib.oci.checks = {
        parsePortInt = {
          type = lib.types.functionTo lib.types.int;
          description = ''
            Extract the container port as integer from a port mapping spec.
            Delegates to `oci.parseContainerPortInt`.

            - `"8080:8080"` → `8080`
            - `"443:443/udp"` → `443`
          '';
          file = "nix/lib/container-checks.nix";
          fn = checks.parsePortInt;
          tests = {
            "parses host:container port" = {
              args = "8080:8080";
              expected = 8080;
            };
            "strips protocol" = {
              args = "443:443/udp";
              expected = 443;
            };
            "handles port-only" = {
              args = "8080";
              expected = 8080;
            };
          };
        };

        extractPrivilegedPorts = {
          type = lib.types.functionTo (lib.types.listOf lib.types.int);
          description = ''
            Filter a list of port integers to only those below 1024 (privileged).

            Example: `[80 8080 443 3000]` → `[80 443]`
          '';
          file = "nix/lib/container-checks.nix";
          fn = checks.extractPrivilegedPorts;
          tests = {
            "filters privileged ports" = {
              args = [
                80
                8080
                443
                3000
              ];
              expected = [
                80
                443
              ];
            };
            "returns empty for high ports" = {
              args = [
                8080
                3000
              ];
              expected = [ ];
            };
          };
        };

        forkingServices = {
          type = lib.types.listOf lib.types.str;
          description = ''
            List of NixOS services known to fork worker processes.
            These need clone/wait4 syscalls and are incompatible with strict seccomp.
          '';
          file = "nix/lib/container-checks.nix";
          fn = checks.forkingServices;
        };

        healthcheckPort = {
          type = lib.types.functionTo (lib.types.nullOr lib.types.int);
          description = ''
            Extract port from a healthcheck command's URL targeting localhost or 127.0.0.1.
            Returns the port as int, or null if no port can be extracted.

            Example: `["curl" "-f" "http://localhost:8080/health"]` → `8080`
          '';
          file = "nix/lib/container-checks.nix";
          fn = checks.healthcheckPort;
          tests = {
            "extracts port from localhost URL" = {
              args = [
                "curl"
                "-f"
                "http://localhost:8080/health"
              ];
              expected = 8080;
            };
            "extracts port from 127.0.0.1 URL" = {
              args = [
                "curl"
                "-f"
                "http://127.0.0.1:3000/"
              ];
              expected = 3000;
            };
            "returns null for no URL" = {
              args = [
                "redis-cli"
                "ping"
              ];
              expected = null;
            };
          };
        };

        healthcheckHasHttps = {
          type = lib.types.functionTo lib.types.bool;
          description = ''
            Check if any healthcheck command argument contains an HTTPS URL.
          '';
          file = "nix/lib/container-checks.nix";
          fn = checks.healthcheckHasHttps;
          tests = {
            "detects https" = {
              args = [
                "curl"
                "-f"
                "https://localhost:443/"
              ];
              expected = true;
            };
            "false for http" = {
              args = [
                "curl"
                "-f"
                "http://localhost:80/"
              ];
              expected = false;
            };
          };
        };

        healthcheckHasInsecureFlag = {
          type = lib.types.functionTo lib.types.bool;
          description = ''
            Check if healthcheck command includes -k or --insecure flag.
          '';
          file = "nix/lib/container-checks.nix";
          fn = checks.healthcheckHasInsecureFlag;
          tests = {
            "detects -k flag" = {
              args = [
                "curl"
                "-k"
                "https://localhost/"
              ];
              expected = true;
            };
            "detects --insecure flag" = {
              args = [
                "curl"
                "--insecure"
                "https://localhost/"
              ];
              expected = true;
            };
            "false when absent" = {
              args = [
                "curl"
                "-f"
                "http://localhost/"
              ];
              expected = false;
            };
          };
        };

        healthcheckUsesHostname = {
          type = lib.types.functionTo lib.types.bool;
          description = ''
            Check if healthcheck URLs reference a hostname (not localhost/127.0.0.1/[::1]).
            Returns true if URLs exist but none target local addresses.
          '';
          file = "nix/lib/container-checks.nix";
          fn = checks.healthcheckUsesHostname;
          tests = {
            "true for hostname URL" = {
              args = [
                "curl"
                "-f"
                "http://myservice:8080/"
              ];
              expected = true;
            };
            "false for localhost" = {
              args = [
                "curl"
                "-f"
                "http://localhost:8080/"
              ];
              expected = false;
            };
            "false for no URLs" = {
              args = [
                "redis-cli"
                "ping"
              ];
              expected = false;
            };
          };
        };

        writableDirs = {
          type = lib.types.functionTo (lib.types.listOf lib.types.str);
          description = ''
            Derive absolute writable directory paths from systemd service data.
            Maps RuntimeDirectory → /run/*, StateDirectory → /var/lib/*,
            CacheDirectory → /var/cache/*, LogsDirectory → /var/log/*.
            Returns empty list when serviceData is null.
          '';
          file = "nix/lib/container-checks.nix";
          fn = checks.writableDirs;
          tests = {
            "maps runtime dirs" = {
              args = {
                runtimeDirs = [ "myapp" ];
                stateDirs = [ ];
                cacheDirs = [ ];
                logDirs = [ ];
              };
              expected = [ "/run/myapp" ];
            };
            "maps all dir types" = {
              args = {
                runtimeDirs = [ "myapp" ];
                stateDirs = [ "myapp" ];
                cacheDirs = [ "myapp" ];
                logDirs = [ "myapp" ];
              };
              expected = [
                "/run/myapp"
                "/var/lib/myapp"
                "/var/cache/myapp"
                "/var/log/myapp"
              ];
            };
            "returns empty for null" = {
              args = null;
              expected = [ ];
            };
          };
        };

        runChecks = {
          type = lib.types.functionTo lib.types.str;
          description = ''
            Run all integration checks for a container.
            Returns "" on success, throws on errors, traces on warnings.

            Arguments (attrset):
              name            - container attribute name
              containerConfig - resolved container options
              evalOutput      - NixOS eval _output (or null)
              mainService     - nixosConfig.mainService (or null)
              enabled         - whether nixosConfig is active
          '';
          file = "nix/lib/container-checks.nix";
          fn = checks.runChecks;
        };
      };
    };
}
