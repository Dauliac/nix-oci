# Image hardening test -- validates hardening features in a NixOS VM.
#
# Replaces CST tests for: hardeningDnsDisabled, hardeningNoTls, hardeningFull.
# Containers are built via the deploy module with hardening options, loaded
# into podman, and tested with `podman run --entrypoint` and `podman image inspect`.
#
# Validates:
#   - DNS disabled: resolv.conf marker, nsswitch files-only, no nameservers
#   - TLS removed: ca-bundle.crt neutered, no real certs, tiny file
#   - Labels: hardening.enabled, dns-disabled, tls-trust-store-removed,
#             capabilities, seccomp-profile, no-new-privileges, read-only-rootfs
#   - Busybox runs in all hardened containers
#
# Run: nix build .#checks.x86_64-linux.vm-hardening -L
{
  config,
  ...
}:
let
  nixosModule = config.flake.modules.nixos.nix-oci;
in
{
  perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    let
      testHelpers = import ../lib.nix { inherit pkgs lib; };
    in
    {
      checks = lib.optionalAttrs pkgs.stdenv.isLinux {
        vm-hardening = testHelpers.mkVMTest {
          name = "nix-oci-hardening";

          nodes.machine =
            { pkgs, ... }:
            {
              imports = [ nixosModule ];

              virtualisation.podman.enable = true;

              oci = {
                enable = true;
                backend = "podman";
                containers = {
                  hardening-dns-disabled = {
                    package = pkgs.busybox;
                    isRoot = true;
                    hardening = {
                      enable = true;
                      disableDns = true;
                    };
                  };
                  hardening-no-tls = {
                    package = pkgs.busybox;
                    isRoot = true;
                    hardening = {
                      enable = true;
                      noTlsTrustStore = true;
                    };
                  };
                  hardening-full = {
                    package = pkgs.busybox;
                    isRoot = true;
                    hardening = {
                      enable = true;
                      disableDns = true;
                      noTlsTrustStore = true;
                      seccomp = {
                        enable = true;
                        profile = "strict";
                      };
                      capabilities = {
                        drop = [ "ALL" ];
                        add = [ "NET_BIND_SERVICE" ];
                      };
                      readOnlyRootfs = true;
                      noNewPrivileges = true;
                    };
                  };
                };
              };
            };

          testScript = ''
            import json

            machine.wait_for_unit("multi-user.target")

            NS = "io.github.dauliac.nix-oci"


            def wait_for_load(name):
                machine.wait_for_unit(f"oci-load-{name}.service")


            def image_inspect(image_ref):
                raw = machine.succeed(f"podman image inspect {image_ref}")
                return json.loads(raw)[0]


            def assert_label(image_ref, key, value):
                """Assert an OCI label matches expected value."""
                info = image_inspect(image_ref)
                labels = info.get("Labels", {})
                actual = labels.get(key, None)
                assert actual == value, \
                    f"Expected label {key}={value} in {image_ref}, got: {actual}"


            def run_ep(image_ref, binary, args=""):
                """Run a binary as entrypoint in a throwaway container."""
                return machine.succeed(
                    f"podman run --rm --entrypoint " + "'" + binary + "'" + f" {image_ref} {args}"
                )


            def run_sh(image_ref, script):
                """Run a shell script inside the container via busybox sh."""
                # Escape single quotes in script by ending quote, adding escaped quote, reopening
                escaped = script.replace("'", "'" + "\\'" + "'" + "")
                return machine.succeed(
                    "podman run --rm --entrypoint " + "'" + "/bin/sh" + "'" + " " + image_ref + " -c " + "'" + escaped + "'"
                )


            def assert_file_contains(image_ref, path, expected):
                """Assert a file inside the image contains a string."""
                content = run_ep(image_ref, "/bin/cat", path)
                assert expected in content, \
                    f"Expected '{expected}' in {path}, got: {content[:200]}"


            def assert_file_not_contains(image_ref, path, excluded):
                """Assert a file inside the image does NOT contain a string."""
                content = run_ep(image_ref, "/bin/cat", path)
                assert excluded not in content, \
                    f"Did not expect '{excluded}' in {path}, got: {content[:200]}"


            # ===================================================================
            # Load all images
            # ===================================================================

            with subtest("load all hardening images"):
                for name in [
                    "hardening-dns-disabled",
                    "hardening-no-tls",
                    "hardening-full",
                ]:
                    wait_for_load(name)

            # ===================================================================
            # hardening-dns-disabled
            # ===================================================================

            with subtest("dns-disabled: hardening labels"):
                assert_label(
                    "hardening-dns-disabled:latest",
                    f"{NS}.hardening.enabled", "true",
                )
                assert_label(
                    "hardening-dns-disabled:latest",
                    f"{NS}.hardening.dns-disabled", "true",
                )

            with subtest("dns-disabled: resolv.conf has hardening marker"):
                assert_file_contains(
                    "hardening-dns-disabled:latest",
                    "/etc/resolv.conf",
                    "DNS disabled by nix-oci hardening",
                )

            with subtest("dns-disabled: resolv.conf has no nameservers"):
                # grep returns exit 1 when no match = no nameservers configured
                machine.succeed(
                    "podman run --rm --entrypoint '/bin/sh' "
                    "hardening-dns-disabled:latest -c "
                    "'! grep -q nameserver /etc/resolv.conf'"
                )

            with subtest("dns-disabled: nsswitch.conf has files-only hosts"):
                assert_file_contains(
                    "hardening-dns-disabled:latest",
                    "/etc/nsswitch.conf",
                    "hosts:",
                )
                assert_file_not_contains(
                    "hardening-dns-disabled:latest",
                    "/etc/nsswitch.conf",
                    "hosts:     files dns",
                )

            with subtest("dns-disabled: nsswitch hosts line has no dns backend"):
                machine.succeed(
                    "podman run --rm --entrypoint '/bin/sh' "
                    "hardening-dns-disabled:latest -c "
                    "'! grep \"^hosts:\" /etc/nsswitch.conf | grep -wq dns'"
                )

            with subtest("dns-disabled: busybox runs"):
                run_ep("hardening-dns-disabled:latest", "/bin/busybox", "--help")

            # ===================================================================
            # hardening-no-tls
            # ===================================================================

            with subtest("no-tls: hardening labels"):
                assert_label(
                    "hardening-no-tls:latest",
                    f"{NS}.hardening.enabled", "true",
                )
                assert_label(
                    "hardening-no-tls:latest",
                    f"{NS}.hardening.tls-trust-store-removed", "true",
                )

            with subtest("no-tls: ca-bundle.crt has removal marker"):
                assert_file_contains(
                    "hardening-no-tls:latest",
                    "/etc/ssl/certs/ca-bundle.crt",
                    "TLS trust store removed by nix-oci hardening",
                )

            with subtest("no-tls: ca-bundle.crt has no real certificates"):
                assert_file_not_contains(
                    "hardening-no-tls:latest",
                    "/etc/ssl/certs/ca-bundle.crt",
                    "BEGIN CERTIFICATE",
                )

            with subtest("no-tls: ca-bundle.crt is tiny"):
                run_sh(
                    "hardening-no-tls:latest",
                    "test $(wc -c < /etc/ssl/certs/ca-bundle.crt) -lt 200",
                )

            with subtest("no-tls: busybox runs"):
                run_ep("hardening-no-tls:latest", "/bin/busybox", "--help")

            # ===================================================================
            # hardening-full (DNS + TLS + seccomp + capabilities + rootfs)
            # ===================================================================

            with subtest("full: all hardening labels present"):
                img = "hardening-full:latest"
                assert_label(img, f"{NS}.hardening.enabled", "true")
                assert_label(img, f"{NS}.hardening.no-new-privileges", "true")
                assert_label(img, f"{NS}.hardening.read-only-rootfs", "true")
                assert_label(img, f"{NS}.hardening.capabilities-drop", "ALL")
                assert_label(img, f"{NS}.hardening.capabilities-add", "NET_BIND_SERVICE")
                assert_label(img, f"{NS}.hardening.seccomp-profile", "strict")
                assert_label(img, f"{NS}.hardening.dns-disabled", "true")
                assert_label(img, f"{NS}.hardening.tls-trust-store-removed", "true")

            with subtest("full: DNS hardening - resolv.conf marker"):
                assert_file_contains(
                    "hardening-full:latest",
                    "/etc/resolv.conf",
                    "DNS disabled by nix-oci hardening",
                )

            with subtest("full: DNS hardening - no nameservers"):
                machine.succeed(
                    "podman run --rm --entrypoint '/bin/sh' "
                    "hardening-full:latest -c "
                    "'! grep -q nameserver /etc/resolv.conf'"
                )

            with subtest("full: DNS hardening - nsswitch no dns backend"):
                machine.succeed(
                    "podman run --rm --entrypoint '/bin/sh' "
                    "hardening-full:latest -c "
                    "'! grep \"^hosts:\" /etc/nsswitch.conf | grep -wq dns'"
                )

            with subtest("full: TLS hardening - ca-bundle neutered"):
                assert_file_contains(
                    "hardening-full:latest",
                    "/etc/ssl/certs/ca-bundle.crt",
                    "TLS trust store removed by nix-oci hardening",
                )

            with subtest("full: TLS hardening - no real certificates"):
                assert_file_not_contains(
                    "hardening-full:latest",
                    "/etc/ssl/certs/ca-bundle.crt",
                    "BEGIN CERTIFICATE",
                )

            with subtest("full: TLS hardening - ca-bundle tiny"):
                run_sh(
                    "hardening-full:latest",
                    "test $(wc -c < /etc/ssl/certs/ca-bundle.crt) -lt 200",
                )

            with subtest("full: busybox runs"):
                run_ep("hardening-full:latest", "/bin/busybox", "--help")

            with subtest("full: passwd file has entries"):
                run_sh(
                    "hardening-full:latest",
                    "test $(wc -l < /etc/passwd) -gt 0",
                )
          '';
        };
      };
    };
}
