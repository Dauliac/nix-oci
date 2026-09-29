# Shared type for option test specifications.
#
# Imported by:
# - perContainer.nix  → internal _tests collection (type-checks contributions)
# - option-tests.nix  → public oci.optionTests catalog (readOnly, documented)
#
# Prefixed with _ so import-tree does not auto-import this as a module.
{ lib }:
let
  inherit (lib) mkOption types;

  # Subtype for commands that must succeed
  succeedsEntryType = types.submodule {
    options = {
      command = mkOption {
        type = types.str;
        description = "Binary to run as entrypoint.";
      };
      args = mkOption {
        type = types.str;
        default = "";
        description = "Arguments passed to the command.";
      };
      stdout = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "If set, assert stdout contains this string.";
      };
    };
  };

  # Subtype for commands that must fail
  failsEntryType = types.submodule {
    options = {
      command = mkOption {
        type = types.str;
        description = "Binary to run as entrypoint.";
      };
      args = mkOption {
        type = types.str;
        default = "";
        description = "Arguments passed to the command.";
      };
      exitCode = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "If set, assert this specific exit code. Otherwise any non-zero.";
      };
    };
  };

  # Subtype for HTTP endpoint checks
  httpRespondsType = types.submodule {
    options = {
      port = mkOption {
        type = types.port;
        description = "Port to check.";
      };
      path = mkOption {
        type = types.str;
        default = "/";
        description = "HTTP path to request.";
      };
      contains = mkOption {
        type = types.str;
        default = "";
        description = "If set, assert response body contains this string.";
      };
    };
  };

  # Subtype for syscall-blocked (seccomp / capability) probes.
  syscallBlockedType = types.submodule {
    options = {
      probe = mkOption {
        type = types.str;
        description = ''
          Binary or script inside the container that attempts the syscall.
          Must exit nonzero (typically EPERM) when the syscall is blocked.
        '';
      };
      args = mkOption {
        type = types.str;
        default = "";
        description = "Arguments passed to the probe.";
      };
      syscall = mkOption {
        type = types.str;
        description = ''
          Name of the blocked syscall (documentation only, rendered in the
          failure message so operators know which surface failed).
        '';
      };
      expectedErrno = mkOption {
        type = types.nullOr types.str;
        default = "EPERM";
        description = ''
          Expected errno string if the probe emits one on stderr. Checked
          only when the probe writes recognisable "errno = FOO" text.
          Set to null to skip the errno check.
        '';
      };
    };
  };

  # Subtype for filesystem-write-blocked (read-only-rootfs / apparmor) checks.
  fsWriteBlockedType = types.submodule {
    options = {
      path = mkOption {
        type = types.str;
        description = "Path inside the container that must NOT be writable.";
      };
      expectedErrno = mkOption {
        type = types.nullOr types.str;
        default = "EROFS";
        description = ''
          Expected errno for the write failure (EROFS for read-only rootfs,
          EACCES for AppArmor deny, etc). Set to null to accept any nonzero.
        '';
      };
    };
  };

  # Subtype for DNS-resolution-fails check.
  dnsResolutionFailsType = types.submodule {
    options = {
      hostname = mkOption {
        type = types.str;
        default = "example.com";
        description = "Hostname whose resolution must fail.";
      };
    };
  };

  # Subtype for TLS-handshake-fails check.
  tlsHandshakeFailsType = types.submodule {
    options = {
      url = mkOption {
        type = types.str;
        default = "https://example.com";
        description = "HTTPS URL whose TLS handshake must fail.";
      };
    };
  };

  # Subtype for SOCI zTOC-present check on a pushed image.
  sociZtocPresentType = types.submodule {
    options = {
      registry = mkOption {
        type = types.str;
        default = "localhost:5000";
        description = "Registry host:port hosting the image.";
      };
      repository = mkOption {
        type = types.str;
        description = "Repository (name) of the pushed image.";
      };
      tag = mkOption {
        type = types.str;
        default = "latest";
        description = "Image tag under which the SOCI-indexed image was pushed.";
      };
      spanSize = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          If set, assert the generated zTOC honours this SOCI span size
          (e.g. `"1MiB"`). Compared against the span-size field decoded
          by the `soci` CLI.
        '';
      };
    };
  };

  # Subtype for reproducibility: manifest digest match across two builds.
  manifestDigestMatchesType = types.submodule {
    options = {
      firstPath = mkOption {
        type = types.str;
        description = ''
          Store path (or file path inside the VM) of the manifest JSON
          from the first build.
        '';
      };
      secondPath = mkOption {
        type = types.str;
        description = ''
          Store path (or file path inside the VM) of the manifest JSON
          from the second build. Must have the same digest as
          `firstPath` for the assertion to pass.
        '';
      };
    };
  };

  # Subtype for firewall-port-open (host-visible listen port) check.
  firewallPortOpenType = types.submodule {
    options = {
      port = mkOption {
        type = types.port;
        description = "TCP port that MUST be accepted on the host input chain.";
      };
      protocol = mkOption {
        type = types.enum [
          "tcp"
          "udp"
        ];
        default = "tcp";
        description = "Protocol of the firewall rule to inspect.";
      };
    };
  };
in
types.submodule {
  options = {
    # ── BDD metadata (rendered in NDG docs) ────────────────
    given = mkOption {
      type = types.str;
      default = "";
      description = "BDD precondition / context (rendered in test coverage docs).";
    };

    "when" = mkOption {
      type = types.str;
      default = "";
      description = "BDD action or trigger (rendered in test coverage docs).";
    };

    "then" = mkOption {
      type = types.str;
      default = "";
      description = "BDD expected outcome (rendered in test coverage docs).";
    };

    target = mkOption {
      type = types.enum [
        "oci"
        "nixos-oci"
        "home-manager-oci"
        "deploy-nixos"
        "deploy-home-manager"
      ];
      default = "oci";
      description = ''
        Which test harness to use:
        - `"oci"` — flake-parts container (podman run).
        - `"nixos-oci"` — NixOS container eval + systemd.
        - `"home-manager-oci"` — home-manager activation.
        - `"deploy-nixos"` — full NixOS deployment.
        - `"deploy-home-manager"` — home-manager deployment.
      '';
    };

    # ── Existing fields ────────────────────────────────────

    level = mkOption {
      type = types.enum [
        "eval"
        "build"
        "inspect"
        "runtime"
        "deploy"
      ];
      default = "eval";
      description = ''
        Test depth — determines what kind of check is generated:

        - `"eval"` — container config evaluates without error (cheapest).
        - `"build"` — OCI image builds successfully.
        - `"inspect"` — image metadata / file contents (VM, no container run).
        - `"runtime"` — oneshot `podman run --rm`, check output / exit code.
        - `"deploy"` — long-running daemon via systemd, check HTTP / env / lifecycle.
      '';
    };

    mode = mkOption {
      type = types.enum [
        "oneshot"
        "daemon"
      ];
      default = "oneshot";
      description = ''
        Container run mode (only relevant for runtime/deploy levels):

        - `"oneshot"` — `podman run --rm`, runs command and exits.
        - `"daemon"` — deployed via systemd, stays running for interaction.
      '';
    };

    container = mkOption {
      type = types.raw;
      default = { };
      description = ''
        Container config for this BDD test scenario.
        Used by the new .test.nix BDD system.
      '';
    };

    default = mkOption {
      type = types.raw;
      default = { };
      description = ''
        Container config using only defaults.
        Tests that the option's default value produces a valid container.
        (Legacy _tests system — use `container` for new BDD specs.)
      '';
    };

    override = mkOption {
      type = types.raw;
      default = { };
      description = ''
        Container config with the example value applied.
        Tests that overriding the option with its documented example works.
        (Legacy _tests system — use `container` for new BDD specs.)
      '';
    };

    testDependencies = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = ''
        Extra packages injected into the test container for testing purposes.
        These are NOT part of the option being tested — they are test harness
        dependencies (e.g., a C binary that probes io_uring for seccomp tests).
      '';
    };

    stateDirectories = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        Container paths that require writable state at runtime (needed by
        stateful services like PostgreSQL, BIND, httpd caches). The VM
        harness backs each entry with a per-spec tmpfs on the host and
        bind-mounts it into the container.

        Example: `[ "/var/lib/postgresql" "/run/postgresql" ]`.
      '';
    };

    assertions = mkOption {
      type = types.submodule {
        options = {
          # ── Image-level (inspect, no runtime needed) ─────────────

          imageConfig = mkOption {
            type = types.attrsOf types.raw;
            default = { };
            description = ''
              Expected OCI image Config fields.
              Checked via `podman image inspect → .Config.<key>`.

              Example: `{ User = "nobody"; ExposedPorts."8080/tcp" = {}; }`
            '';
          };

          labels = mkOption {
            type = types.attrsOf types.str;
            default = { };
            description = ''
              Expected OCI labels.
              Checked via `podman image inspect → .Labels.<key>`.

              Example: `{ "org.opencontainers.image.title" = "my-app"; }`
            '';
          };

          fileContains = mkOption {
            type = types.attrsOf types.str;
            default = { };
            description = ''
              Files in the image that must contain a string.
              Uses `podman create + cp` to read from image layers directly
              (bypasses runtime bind-mounts like resolv.conf).

              Example: `{ "/etc/nsswitch.conf" = "files"; }`
            '';
          };

          fileNotContains = mkOption {
            type = types.attrsOf types.str;
            default = { };
            description = ''
              Files in the image that must NOT contain a string.

              Example: `{ "/etc/ssl/certs/ca-bundle.crt" = "BEGIN CERTIFICATE"; }`
            '';
          };

          # ── Oneshot (runtime, podman run --rm) ───────────────────

          succeeds = mkOption {
            type = types.listOf succeedsEntryType;
            default = [ ];
            description = ''
              Commands that must succeed (exit 0) when run via
              `podman run --rm --entrypoint <command> <image>`.
              Optionally check stdout contains a string.
            '';
          };

          fails = mkOption {
            type = types.listOf failsEntryType;
            default = [ ];
            description = ''
              Commands that must fail (exit != 0) when run via
              `podman run --rm --entrypoint <command> <image>`.
              Used for testing seccomp blocks, capability drops, etc.
              Optionally assert a specific exit code.
            '';
          };

          # ── Daemon (deploy, long-running) ────────────────────────

          httpResponds = mkOption {
            type = types.nullOr httpRespondsType;
            default = null;
            description = ''
              HTTP endpoint check with built-in wait/retry.
              Uses `wait_for_open_port` + `wait_until_succeeds` + `curl`.
            '';
          };

          processEnv = mkOption {
            type = types.attrsOf types.str;
            default = { };
            description = ''
              Expected process environment variables.
              Read from `/proc/1/environ` inside the running container
              (captures OCI-configured env vars that `env` may not show).

              Example: `{ LD_PRELOAD = "jemalloc"; }`
            '';
          };

          containerInspect = mkOption {
            type = types.attrsOf types.raw;
            default = { };
            description = ''
              Expected `podman inspect` fields (dot-path notation).

              Example: `{ "HostConfig.LogConfig.Type" = "passthrough"; }`
            '';
          };

          systemdProps = mkOption {
            type = types.attrsOf types.str;
            default = { };
            description = ''
              Expected systemd service properties.
              Checked via `systemctl show <service> --property=<keys>`.

              Example: `{ Type = "notify"; NotifyAccess = "all"; }`
            '';
          };

          # ── Hardening / runtime blocked-behaviour assertions ─────

          syscallBlocked = mkOption {
            type = types.listOf syscallBlockedType;
            default = [ ];
            description = ''
              Assert that a specific syscall is blocked (typically by
              seccomp or a dropped capability). A probe binary attempts
              the syscall and must exit nonzero; failure message names
              the syscall for operator clarity.
            '';
          };

          fsWriteBlocked = mkOption {
            type = types.listOf fsWriteBlockedType;
            default = [ ];
            description = ''
              Assert that a filesystem write to `path` fails inside the
              running container (used for read-only-rootfs and AppArmor
              deny scenarios). Optionally checks the errno.
            '';
          };

          dnsResolutionFails = mkOption {
            type = types.listOf dnsResolutionFailsType;
            default = [ ];
            description = ''
              Assert that `getaddrinfo(hostname)` from inside the
              running container fails. Used to verify
              `hardening.disableDns = true`.
            '';
          };

          tlsHandshakeFails = mkOption {
            type = types.listOf tlsHandshakeFailsType;
            default = [ ];
            description = ''
              Assert that a TLS handshake to `url` fails inside the
              running container. Used to verify
              `hardening.noTlsTrustStore = true`.
            '';
          };

          # ── Performance / env visibility assertions ──────────────

          envVarSet = mkOption {
            type = types.attrsOf types.str;
            default = { };
            description = ''
              Assert an environment variable is present in the
              container's built image OCI `Config.Env` (checked via
              `podman image inspect`). Complements `processEnv` which
              reads /proc/1/environ at runtime.

              Example: `{ GLIBC_TUNABLES = "glibc.malloc.trim_threshold=131072"; }`
            '';
          };

          # ── SOCI / manifest / firewall structural assertions ─────

          sociZtocPresent = mkOption {
            type = types.nullOr sociZtocPresentType;
            default = null;
            description = ''
              Assert the given repository:tag in a local registry has
              a SOCI zTOC referrer manifest attached (uses ORAS or
              curl on the referrers API). Optionally verifies the
              zTOC span size.
            '';
          };

          manifestDigestMatches = mkOption {
            type = types.nullOr manifestDigestMatchesType;
            default = null;
            description = ''
              Assert two manifest JSON files (typically the outputs of
              two independent `nix build` invocations) share the same
              SHA-256 digest. Used for the reproducibility check.
            '';
          };

          firewallPortOpen = mkOption {
            type = types.listOf firewallPortOpenType;
            default = [ ];
            description = ''
              Assert `nft list ruleset` (or `iptables -S`) contains an
              accept rule for the given port and protocol. Used to
              verify the ports triple-write reaches the NixOS firewall.
            '';
          };

          # ── Escape hatch ─────────────────────────────────────────

          runtime = mkOption {
            type = types.lines;
            default = "";
            description = ''
              Raw Python test script (escape hatch). In the pytest
              context, this becomes a standalone test function body
              with `client` (docker SDK) available.
            '';
          };
        };
      };
      default = { };
      description = "Assertions to verify after building/running the container.";
    };

    exampleFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Link to an `examples/` file for documentation cross-reference.";
    };
  };
}
